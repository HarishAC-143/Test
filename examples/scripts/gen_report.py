#!/usr/bin/env python3
"""
gen_report.py — Generate HTML/JSON regression reports from build results.

Reads CSV or JSON result data and produces a self-contained HTML report
with summary dashboard, per-test detail, and resource charts.

Usage:
    python3 gen_report.py --input results.csv --output report.html --format html
    python3 gen_report.py --input results.csv --output report.json --format json

CSV format expected:
    test,device,part,type,status,elapsed_s
"""

import argparse
import csv
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any


def read_csv_results(csv_path: str) -> List[Dict[str, Any]]:
    """Read regression results from a CSV file."""
    results = []
    with open(csv_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if "elapsed_s" in row and row["elapsed_s"]:
                row["elapsed_s"] = int(row["elapsed_s"])
            results.append(row)
    return results


def compute_summary(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Compute summary statistics from results."""
    total = len(results)
    passed = sum(1 for r in results if r.get("status") == "PASS")
    failed = sum(1 for r in results if r.get("status") == "FAIL")
    timeout = sum(1 for r in results if r.get("status") == "TIMEOUT")
    total_time = sum(r.get("elapsed_s", 0) for r in results)

    return {
        "total": total,
        "passed": passed,
        "failed": failed,
        "timeout": timeout,
        "pass_rate": round(100.0 * passed / total, 1) if total > 0 else 0.0,
        "total_time_s": total_time,
        "overall_status": "PASS" if failed == 0 and timeout == 0 and total > 0 else "FAIL",
    }


def generate_html_report(
    results: List[Dict[str, Any]],
    output_path: str,
    title: str = "FPGA Regression Report",
) -> None:
    """Generate a self-contained HTML report."""
    summary = compute_summary(results)
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    status_color = "#28a745" if summary["overall_status"] == "PASS" else "#dc3545"

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            color: #333;
            line-height: 1.6;
        }}
        .container {{ max-width: 1200px; margin: 0 auto; padding: 20px; }}

        /* Header */
        .header {{
            background: linear-gradient(135deg, #1a237e, #283593);
            color: white;
            padding: 30px;
            border-radius: 8px;
            margin-bottom: 20px;
        }}
        .header h1 {{ font-size: 24px; margin-bottom: 8px; }}
        .header .timestamp {{ opacity: 0.8; font-size: 14px; }}

        /* Summary cards */
        .summary-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}
        .card {{
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            text-align: center;
        }}
        .card .value {{
            font-size: 36px;
            font-weight: bold;
            margin: 8px 0;
        }}
        .card .label {{
            font-size: 14px;
            color: #666;
            text-transform: uppercase;
        }}
        .card.pass .value {{ color: #28a745; }}
        .card.fail .value {{ color: #dc3545; }}
        .card.total .value {{ color: #1a237e; }}

        /* Status badge */
        .status-badge {{
            display: inline-block;
            padding: 6px 16px;
            border-radius: 20px;
            font-weight: bold;
            font-size: 18px;
            color: white;
            background: {status_color};
        }}

        /* Results table */
        .results-table {{
            width: 100%;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 24px;
        }}
        .results-table h2 {{
            padding: 16px 20px;
            background: #f8f9fa;
            border-bottom: 1px solid #dee2e6;
            font-size: 18px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
        }}
        th {{
            background: #e8eaf6;
            padding: 12px 16px;
            text-align: left;
            font-size: 13px;
            text-transform: uppercase;
            color: #555;
        }}
        td {{
            padding: 12px 16px;
            border-bottom: 1px solid #f0f0f0;
        }}
        tr:hover {{ background: #f8f9fa; }}

        /* Status pills */
        .status-pass {{
            background: #e8f5e9; color: #2e7d32;
            padding: 4px 12px; border-radius: 12px;
            font-weight: 600; font-size: 13px;
        }}
        .status-fail {{
            background: #ffebee; color: #c62828;
            padding: 4px 12px; border-radius: 12px;
            font-weight: 600; font-size: 13px;
        }}
        .status-timeout {{
            background: #fff3e0; color: #e65100;
            padding: 4px 12px; border-radius: 12px;
            font-weight: 600; font-size: 13px;
        }}

        /* Progress bar */
        .progress-bar {{
            width: 100%;
            height: 24px;
            background: #e0e0e0;
            border-radius: 12px;
            overflow: hidden;
            margin: 16px 0;
        }}
        .progress-fill {{
            height: 100%;
            background: linear-gradient(90deg, #28a745, #4caf50);
            border-radius: 12px;
            transition: width 0.5s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            font-size: 12px;
        }}

        .footer {{
            text-align: center;
            padding: 20px;
            color: #999;
            font-size: 13px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>{title}</h1>
            <div class="timestamp">Generated: {timestamp}</div>
            <div style="margin-top: 12px;">
                <span class="status-badge">{summary['overall_status']}</span>
            </div>
        </div>

        <div class="summary-grid">
            <div class="card total">
                <div class="label">Total Tests</div>
                <div class="value">{summary['total']}</div>
            </div>
            <div class="card pass">
                <div class="label">Passed</div>
                <div class="value">{summary['passed']}</div>
            </div>
            <div class="card fail">
                <div class="label">Failed</div>
                <div class="value">{summary['failed']}</div>
            </div>
            <div class="card">
                <div class="label">Pass Rate</div>
                <div class="value">{summary['pass_rate']}%</div>
            </div>
            <div class="card">
                <div class="label">Total Time</div>
                <div class="value">{summary['total_time_s']}s</div>
            </div>
        </div>

        <div class="progress-bar">
            <div class="progress-fill" style="width: {summary['pass_rate']}%">
                {summary['pass_rate']}%
            </div>
        </div>

        <div class="results-table">
            <h2>Test Results</h2>
            <table>
                <thead>
                    <tr>
                        <th>Test Name</th>
                        <th>Device</th>
                        <th>Part Number</th>
                        <th>Type</th>
                        <th>Status</th>
                        <th>Duration</th>
                    </tr>
                </thead>
                <tbody>
"""

    for r in results:
        status = r.get("status", "UNKNOWN")
        status_class = f"status-{status.lower()}"
        elapsed = r.get("elapsed_s", "—")
        elapsed_str = f"{elapsed}s" if isinstance(elapsed, int) else elapsed

        html += f"""                    <tr>
                        <td><strong>{r.get('test', '—')}</strong></td>
                        <td>{r.get('device', '—')}</td>
                        <td><code>{r.get('part', '—')}</code></td>
                        <td>{r.get('type', '—')}</td>
                        <td><span class="{status_class}">{status}</span></td>
                        <td>{elapsed_str}</td>
                    </tr>
"""

    html += f"""                </tbody>
            </table>
        </div>

        <div class="footer">
            Altera FPGA Regression Report &mdash; {timestamp}
        </div>
    </div>
</body>
</html>
"""

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with open(output_path, "w") as f:
        f.write(html)

    print(f"HTML report generated: {output_path}")


def generate_json_report(
    results: List[Dict[str, Any]],
    output_path: str,
) -> None:
    """Generate a JSON report."""
    summary = compute_summary(results)
    report = {
        "timestamp": datetime.now().isoformat(),
        "summary": summary,
        "results": results,
    }

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(report, f, indent=2)

    print(f"JSON report generated: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate regression reports from build results"
    )
    parser.add_argument(
        "--input", "-i", required=True,
        help="Input CSV or JSON file with test results"
    )
    parser.add_argument(
        "--output", "-o", required=True,
        help="Output report file path"
    )
    parser.add_argument(
        "--format", "-f", choices=["html", "json"], default="html",
        help="Report format (default: html)"
    )
    parser.add_argument(
        "--title", default="FPGA Regression Report",
        help="Report title"
    )
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"ERROR: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    ext = Path(args.input).suffix.lower()
    if ext == ".csv":
        results = read_csv_results(args.input)
    elif ext == ".json":
        with open(args.input) as f:
            data = json.load(f)
        results = data if isinstance(data, list) else data.get("results", [])
    else:
        print(f"ERROR: Unsupported input format: {ext}", file=sys.stderr)
        sys.exit(1)

    if args.format == "html":
        generate_html_report(results, args.output, title=args.title)
    elif args.format == "json":
        generate_json_report(results, args.output)

    summary = compute_summary(results)
    print(f"Overall: {summary['overall_status']} "
          f"({summary['passed']}/{summary['total']} passed)")


if __name__ == "__main__":
    main()
