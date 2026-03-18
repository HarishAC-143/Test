#!/usr/bin/env python3
"""
parse_results.py — Parse Quartus report files and extract key metrics.

Extracts resource usage, timing information, and compilation statistics
from Quartus .rpt files and outputs structured JSON data.

Usage:
    python3 parse_results.py --input <report_dir> --output <output.json>
    python3 parse_results.py --input build/output_files --output metrics.json --verbose

Example:
    python3 parse_results.py --input ./output_files --output results.json
"""

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from datetime import datetime
from pathlib import Path
from typing import Optional


@dataclass
class ResourceUsage:
    """FPGA resource utilization metrics."""
    total_alms: int = 0
    used_alms: int = 0
    alm_utilization_pct: float = 0.0
    total_registers: int = 0
    used_registers: int = 0
    total_memory_bits: int = 0
    used_memory_bits: int = 0
    total_dsps: int = 0
    used_dsps: int = 0
    total_pins: int = 0
    used_pins: int = 0


@dataclass
class TimingResult:
    """Timing analysis results for a single clock domain."""
    clock_name: str = ""
    period_ns: float = 0.0
    setup_slack_ns: float = 0.0
    hold_slack_ns: float = 0.0
    fmax_mhz: float = 0.0
    setup_met: bool = True
    hold_met: bool = True


@dataclass
class CompilationMetrics:
    """Per-stage compilation metrics."""
    synthesis_time_s: float = 0.0
    fitter_time_s: float = 0.0
    timing_time_s: float = 0.0
    assembler_time_s: float = 0.0
    total_time_s: float = 0.0
    warning_count: int = 0
    error_count: int = 0
    critical_warning_count: int = 0


@dataclass
class DesignMetrics:
    """Complete set of metrics for a single build."""
    project_name: str = ""
    device: str = ""
    family: str = ""
    timestamp: str = ""
    resources: ResourceUsage = field(default_factory=ResourceUsage)
    timing: list = field(default_factory=list)
    compilation: CompilationMetrics = field(default_factory=CompilationMetrics)
    overall_status: str = "UNKNOWN"


class QuartusReportParser:
    """Parser for Quartus Prime report files (.rpt)."""

    def __init__(self, report_dir: str, verbose: bool = False):
        self.report_dir = Path(report_dir)
        self.verbose = verbose
        self.metrics = DesignMetrics()

    def log(self, msg: str):
        if self.verbose:
            print(f"  [PARSE] {msg}")

    def parse_all(self) -> DesignMetrics:
        """Parse all available report files and return combined metrics."""
        self.metrics.timestamp = datetime.now().isoformat()

        self._parse_map_report()
        self._parse_fit_report()
        self._parse_sta_report()

        self._determine_status()
        return self.metrics

    def _parse_map_report(self):
        """Parse Analysis & Synthesis report (.map.rpt)."""
        rpt_files = list(self.report_dir.glob("*.map.rpt"))
        if not rpt_files:
            self.log("No .map.rpt found")
            return

        rpt_file = rpt_files[0]
        self.log(f"Parsing {rpt_file.name}")
        content = rpt_file.read_text(errors="replace")

        # Extract project name
        match = re.search(r"Project Name\s*:\s*(\S+)", content)
        if match:
            self.metrics.project_name = match.group(1)

        # Extract device family
        match = re.search(r"Device Family\s*:\s*(.+)", content)
        if match:
            self.metrics.family = match.group(1).strip()

        # Extract device
        match = re.search(r"Device\s*:\s*(\S+)", content)
        if match:
            self.metrics.device = match.group(1)

        # Count warnings and errors
        self.metrics.compilation.warning_count += len(
            re.findall(r"^Warning\s*\(", content, re.MULTILINE)
        )
        self.metrics.compilation.critical_warning_count += len(
            re.findall(r"^Critical Warning\s*\(", content, re.MULTILINE)
        )
        self.metrics.compilation.error_count += len(
            re.findall(r"^Error\s*\(", content, re.MULTILINE)
        )

        # Extract synthesis time
        match = re.search(
            r"Analysis & Synthesis.*?Elapsed Time\s*:\s*(\d+):(\d+):(\d+)",
            content, re.DOTALL
        )
        if match:
            h, m, s = int(match.group(1)), int(match.group(2)), int(match.group(3))
            self.metrics.compilation.synthesis_time_s = h * 3600 + m * 60 + s

    def _parse_fit_report(self):
        """Parse Fitter report (.fit.rpt)."""
        rpt_files = list(self.report_dir.glob("*.fit.rpt"))
        if not rpt_files:
            self.log("No .fit.rpt found")
            return

        rpt_file = rpt_files[0]
        self.log(f"Parsing {rpt_file.name}")
        content = rpt_file.read_text(errors="replace")

        res = self.metrics.resources

        # ALMs / Logic Elements
        match = re.search(
            r"(?:Adaptive )?Logic (?:Modules?|Elements?)\s*[;:]\s*([\d,]+)\s*/\s*([\d,]+)",
            content
        )
        if match:
            res.used_alms = int(match.group(1).replace(",", ""))
            res.total_alms = int(match.group(2).replace(",", ""))
            if res.total_alms > 0:
                res.alm_utilization_pct = round(
                    100.0 * res.used_alms / res.total_alms, 2
                )

        # Registers
        match = re.search(
            r"(?:Dedicated )?(?:Logic )?Registers?\s*[;:]\s*([\d,]+)\s*/\s*([\d,]+)",
            content
        )
        if match:
            res.used_registers = int(match.group(1).replace(",", ""))
            res.total_registers = int(match.group(2).replace(",", ""))

        # Memory bits
        match = re.search(
            r"(?:Total )?[Mm]emory [Bb]its\s*[;:]\s*([\d,]+)\s*/\s*([\d,]+)",
            content
        )
        if match:
            res.used_memory_bits = int(match.group(1).replace(",", ""))
            res.total_memory_bits = int(match.group(2).replace(",", ""))

        # DSP blocks
        match = re.search(
            r"DSP [Bb]lock(?:s| 18-bit element)\s*[;:]\s*([\d,]+)\s*/\s*([\d,]+)",
            content
        )
        if match:
            res.used_dsps = int(match.group(1).replace(",", ""))
            res.total_dsps = int(match.group(2).replace(",", ""))

        # Pins
        match = re.search(
            r"(?:Total )?[Pp]ins?\s*[;:]\s*([\d,]+)\s*/\s*([\d,]+)",
            content
        )
        if match:
            res.used_pins = int(match.group(1).replace(",", ""))
            res.total_pins = int(match.group(2).replace(",", ""))

        # Fitter time
        match = re.search(
            r"Fitter.*?Elapsed Time\s*:\s*(\d+):(\d+):(\d+)",
            content, re.DOTALL
        )
        if match:
            h, m, s = int(match.group(1)), int(match.group(2)), int(match.group(3))
            self.metrics.compilation.fitter_time_s = h * 3600 + m * 60 + s

    def _parse_sta_report(self):
        """Parse Timing Analysis report (.sta.rpt)."""
        rpt_files = list(self.report_dir.glob("*.sta.rpt"))
        if not rpt_files:
            self.log("No .sta.rpt found")
            return

        rpt_file = rpt_files[0]
        self.log(f"Parsing {rpt_file.name}")
        content = rpt_file.read_text(errors="replace")

        # Extract clock-specific timing results
        # Pattern: "Clock Name ; Slack ; ..."
        clock_pattern = re.compile(
            r";\s*(\S+)\s*;\s*([-\d.]+)\s*;\s*(?:Setup|Hold)",
            re.MULTILINE
        )

        seen_clocks = set()
        for match in clock_pattern.finditer(content):
            clock_name = match.group(1)
            slack = float(match.group(2))

            if clock_name not in seen_clocks:
                seen_clocks.add(clock_name)
                timing = TimingResult(clock_name=clock_name)
                timing.setup_slack_ns = slack
                timing.setup_met = slack >= 0
                self.metrics.timing.append(timing)

        # Extract Fmax
        fmax_pattern = re.compile(
            r";\s*(\S+)\s*;\s*([\d.]+)\s*MHz",
            re.MULTILINE
        )
        for match in fmax_pattern.finditer(content):
            clock_name = match.group(1)
            fmax = float(match.group(2))
            for t in self.metrics.timing:
                if t.clock_name == clock_name:
                    t.fmax_mhz = fmax
                    break

        # Timing analysis time
        match = re.search(
            r"Timing Analyzer.*?Elapsed Time\s*:\s*(\d+):(\d+):(\d+)",
            content, re.DOTALL
        )
        if match:
            h, m, s = int(match.group(1)), int(match.group(2)), int(match.group(3))
            self.metrics.compilation.timing_time_s = h * 3600 + m * 60 + s

    def _determine_status(self):
        """Determine overall pass/fail status."""
        comp = self.metrics.compilation

        if comp.error_count > 0:
            self.metrics.overall_status = "FAIL"
            return

        timing_failed = any(
            not t.setup_met or not t.hold_met
            for t in self.metrics.timing
        )
        if timing_failed:
            self.metrics.overall_status = "TIMING_FAIL"
            return

        if comp.critical_warning_count > 0:
            self.metrics.overall_status = "WARN"
            return

        self.metrics.overall_status = "PASS"


def serialize_metrics(metrics: DesignMetrics) -> dict:
    """Convert DesignMetrics to a JSON-serializable dict."""
    d = asdict(metrics)
    return d


def main():
    parser = argparse.ArgumentParser(
        description="Parse Quartus report files and extract metrics"
    )
    parser.add_argument(
        "--input", "-i", required=True,
        help="Directory containing Quartus report files"
    )
    parser.add_argument(
        "--output", "-o", default="metrics.json",
        help="Output JSON file (default: metrics.json)"
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true",
        help="Enable verbose output"
    )
    args = parser.parse_args()

    if not os.path.isdir(args.input):
        print(f"ERROR: Directory not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    report_parser = QuartusReportParser(args.input, verbose=args.verbose)
    metrics = report_parser.parse_all()

    result = serialize_metrics(metrics)

    with open(args.output, "w") as f:
        json.dump(result, f, indent=2)

    print(f"Metrics written to: {args.output}")
    print(f"Status: {metrics.overall_status}")

    if args.verbose:
        print(json.dumps(result, indent=2))

    sys.exit(0 if metrics.overall_status in ("PASS", "WARN") else 1)


if __name__ == "__main__":
    main()
