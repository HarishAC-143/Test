#!/usr/bin/env python3
"""
trend_analysis.py — Historical trend analysis for FPGA regression metrics.

Tracks Fmax, resource usage, warning counts, and build times across
multiple regression runs. Detects regressions and generates trend reports.

Usage:
    python3 trend_analysis.py --data-dir <history_dir> --output <report.html>
    python3 trend_analysis.py --data-dir ./history --add <new_results.json>
    python3 trend_analysis.py --data-dir ./history --output trends.html --last 30

Data directory structure:
    history/
    ├── 20240101_120000.json
    ├── 20240102_120000.json
    └── ...
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional


def load_history(data_dir: str) -> List[Dict[str, Any]]:
    """Load all historical result files from the data directory."""
    history = []
    data_path = Path(data_dir)

    if not data_path.exists():
        return history

    for f in sorted(data_path.glob("*.json")):
        try:
            with open(f) as fh:
                data = json.load(fh)
                data["_source_file"] = f.name
                history.append(data)
        except (json.JSONDecodeError, IOError) as e:
            print(f"WARNING: Could not load {f}: {e}", file=sys.stderr)

    return history


def add_result(data_dir: str, result_file: str) -> None:
    """Add a new result file to the history directory."""
    data_path = Path(data_dir)
    data_path.mkdir(parents=True, exist_ok=True)

    with open(result_file) as f:
        data = json.load(f)

    timestamp = data.get("timestamp", datetime.now().strftime("%Y%m%d_%H%M%S"))
    ts_clean = timestamp.replace("-", "").replace(":", "").replace("T", "_")[:15]
    dest = data_path / f"{ts_clean}.json"

    with open(dest, "w") as f:
        json.dump(data, f, indent=2)

    print(f"Added result to history: {dest}")


def extract_trends(history: List[Dict[str, Any]]) -> Dict[str, List]:
    """Extract trend data from historical results."""
    trends = {
        "timestamps": [],
        "pass_rates": [],
        "total_tests": [],
        "build_times": [],
        "fmax_values": {},
        "alm_usage": [],
        "register_usage": [],
        "warning_counts": [],
    }

    for entry in history:
        ts = entry.get("timestamp", entry.get("_source_file", "unknown"))
        trends["timestamps"].append(ts)

        # Summary stats
        summary = entry.get("summary", {})
        total = summary.get("total", 0)
        passed = summary.get("passed", 0)
        trends["total_tests"].append(total)
        trends["pass_rates"].append(
            round(100.0 * passed / total, 1) if total > 0 else 0.0
        )
        trends["build_times"].append(summary.get("total_time_s", 0))

        # Resource usage (from nested metrics if available)
        resources = entry.get("resources", {})
        trends["alm_usage"].append(resources.get("alm_utilization_pct", 0))
        trends["register_usage"].append(resources.get("used_registers", 0))

        # Warning counts
        compilation = entry.get("compilation", {})
        trends["warning_counts"].append(compilation.get("warning_count", 0))

        # Fmax per clock
        for timing in entry.get("timing", []):
            clk = timing.get("clock_name", "unknown")
            if clk not in trends["fmax_values"]:
                trends["fmax_values"][clk] = []
            trends["fmax_values"][clk].append(timing.get("fmax_mhz", 0))

    return trends


def detect_regressions(
    trends: Dict[str, List],
    thresholds: Optional[Dict] = None
) -> List[Dict[str, Any]]:
    """Detect metric regressions by comparing the latest run to previous runs."""
    if thresholds is None:
        thresholds = {
            "pass_rate_drop_pct": 5.0,
            "fmax_drop_mhz": 5.0,
            "alm_increase_pct": 5.0,
            "warning_increase": 10,
            "build_time_increase_pct": 20.0,
        }

    alerts = []

    if len(trends["pass_rates"]) < 2:
        return alerts

    # Pass rate regression
    curr_pass = trends["pass_rates"][-1]
    prev_pass = trends["pass_rates"][-2]
    if prev_pass - curr_pass > thresholds["pass_rate_drop_pct"]:
        alerts.append({
            "type": "PASS_RATE_DROP",
            "severity": "HIGH",
            "message": f"Pass rate dropped from {prev_pass}% to {curr_pass}%",
            "previous": prev_pass,
            "current": curr_pass,
        })

    # ALM usage increase
    if len(trends["alm_usage"]) >= 2:
        curr_alm = trends["alm_usage"][-1]
        prev_alm = trends["alm_usage"][-2]
        if curr_alm - prev_alm > thresholds["alm_increase_pct"]:
            alerts.append({
                "type": "ALM_INCREASE",
                "severity": "MEDIUM",
                "message": f"ALM usage increased from {prev_alm}% to {curr_alm}%",
                "previous": prev_alm,
                "current": curr_alm,
            })

    # Warning count increase
    if len(trends["warning_counts"]) >= 2:
        curr_warn = trends["warning_counts"][-1]
        prev_warn = trends["warning_counts"][-2]
        if curr_warn - prev_warn > thresholds["warning_increase"]:
            alerts.append({
                "type": "WARNING_INCREASE",
                "severity": "LOW",
                "message": f"Warnings increased from {prev_warn} to {curr_warn}",
                "previous": prev_warn,
                "current": curr_warn,
            })

    # Fmax regression per clock
    for clk, values in trends["fmax_values"].items():
        if len(values) >= 2:
            curr_fmax = values[-1]
            prev_fmax = values[-2]
            if prev_fmax - curr_fmax > thresholds["fmax_drop_mhz"]:
                alerts.append({
                    "type": "FMAX_DROP",
                    "severity": "HIGH",
                    "message": (
                        f"Fmax for '{clk}' dropped from "
                        f"{prev_fmax} MHz to {curr_fmax} MHz"
                    ),
                    "clock": clk,
                    "previous": prev_fmax,
                    "current": curr_fmax,
                })

    # Build time increase
    if len(trends["build_times"]) >= 2:
        curr_time = trends["build_times"][-1]
        prev_time = trends["build_times"][-2]
        if prev_time > 0:
            increase_pct = 100.0 * (curr_time - prev_time) / prev_time
            if increase_pct > thresholds["build_time_increase_pct"]:
                alerts.append({
                    "type": "BUILD_TIME_INCREASE",
                    "severity": "LOW",
                    "message": (
                        f"Build time increased by {increase_pct:.1f}% "
                        f"({prev_time}s → {curr_time}s)"
                    ),
                    "previous": prev_time,
                    "current": curr_time,
                })

    return alerts


def generate_trend_report(
    trends: Dict[str, List],
    alerts: List[Dict[str, Any]],
    output_path: str,
) -> None:
    """Generate an HTML trend report with inline charts (ASCII-style)."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    n = len(trends["timestamps"])

    alert_html = ""
    if alerts:
        alert_html = '<div class="alerts"><h2>Regression Alerts</h2>'
        for alert in alerts:
            sev_color = {
                "HIGH": "#dc3545",
                "MEDIUM": "#ffc107",
                "LOW": "#17a2b8"
            }.get(alert["severity"], "#6c757d")
            alert_html += (
                f'<div class="alert" style="border-left: 4px solid {sev_color};">'
                f'<strong>[{alert["severity"]}]</strong> {alert["message"]}'
                f'</div>'
            )
        alert_html += '</div>'

    # Build pass rate sparkline
    sparkline_data = trends["pass_rates"][-20:] if n > 20 else trends["pass_rates"]

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>FPGA Regression Trends</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5; color: #333; margin: 0; padding: 20px;
        }}
        .container {{ max-width: 1000px; margin: 0 auto; }}
        h1 {{ color: #1a237e; }}
        h2 {{ color: #283593; margin-top: 24px; }}
        .alerts {{ margin: 20px 0; }}
        .alert {{
            background: white; padding: 12px 16px; margin: 8px 0;
            border-radius: 4px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}
        table {{
            width: 100%; border-collapse: collapse;
            background: white; border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin: 16px 0;
        }}
        th {{ background: #e8eaf6; padding: 10px 14px; text-align: left; }}
        td {{ padding: 10px 14px; border-bottom: 1px solid #f0f0f0; }}
        .metric-label {{ font-weight: 600; color: #1a237e; }}
        .trend-up {{ color: #dc3545; }}
        .trend-down {{ color: #28a745; }}
        .trend-stable {{ color: #6c757d; }}
        .footer {{ text-align: center; padding: 20px; color: #999; font-size: 13px; }}
    </style>
</head>
<body>
<div class="container">
    <h1>FPGA Regression Trend Analysis</h1>
    <p>Data points: {n} | Generated: {timestamp}</p>

    {alert_html}

    <h2>Summary Trends (Last {min(n, 10)} Runs)</h2>
    <table>
        <thead>
            <tr>
                <th>Run</th>
                <th>Pass Rate</th>
                <th>Tests</th>
                <th>Build Time</th>
                <th>Warnings</th>
            </tr>
        </thead>
        <tbody>
"""

    display_count = min(n, 10)
    for i in range(max(0, n - display_count), n):
        ts = trends["timestamps"][i] if i < len(trends["timestamps"]) else "—"
        pr = trends["pass_rates"][i] if i < len(trends["pass_rates"]) else 0
        tt = trends["total_tests"][i] if i < len(trends["total_tests"]) else 0
        bt = trends["build_times"][i] if i < len(trends["build_times"]) else 0
        wc = trends["warning_counts"][i] if i < len(trends["warning_counts"]) else 0

        pr_class = "trend-stable"
        if i > 0 and i < len(trends["pass_rates"]):
            prev = trends["pass_rates"][i - 1]
            if pr < prev:
                pr_class = "trend-up"
            elif pr > prev:
                pr_class = "trend-down"

        html += f"""            <tr>
                <td>{ts}</td>
                <td class="{pr_class}">{pr}%</td>
                <td>{tt}</td>
                <td>{bt}s</td>
                <td>{wc}</td>
            </tr>
"""

    html += f"""        </tbody>
    </table>

    <div class="footer">
        Altera FPGA Regression Trend Report &mdash; {timestamp}
    </div>
</div>
</body>
</html>
"""

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with open(output_path, "w") as f:
        f.write(html)
    print(f"Trend report generated: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="FPGA regression trend analysis"
    )
    parser.add_argument(
        "--data-dir", "-d", required=True,
        help="Directory containing historical result JSON files"
    )
    parser.add_argument(
        "--output", "-o", default="",
        help="Output trend report path (HTML)"
    )
    parser.add_argument(
        "--add", "-a", default="",
        help="Add a new result file to the history"
    )
    parser.add_argument(
        "--last", "-n", type=int, default=0,
        help="Only consider the last N data points"
    )
    parser.add_argument(
        "--check", action="store_true",
        help="Check for regressions and exit with non-zero on alerts"
    )
    args = parser.parse_args()

    if args.add:
        add_result(args.data_dir, args.add)

    history = load_history(args.data_dir)
    if args.last > 0:
        history = history[-args.last:]

    if not history:
        print("No historical data found.")
        sys.exit(0)

    trends = extract_trends(history)
    alerts = detect_regressions(trends)

    if alerts:
        print(f"Found {len(alerts)} regression alert(s):")
        for alert in alerts:
            print(f"  [{alert['severity']}] {alert['message']}")
    else:
        print("No regressions detected.")

    if args.output:
        generate_trend_report(trends, alerts, args.output)

    if args.check and alerts:
        high_alerts = [a for a in alerts if a["severity"] == "HIGH"]
        if high_alerts:
            sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
