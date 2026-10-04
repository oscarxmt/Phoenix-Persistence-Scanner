import json
from pathlib import Path
from collections import defaultdict

BASE_DIR = Path(__file__).resolve().parent
RESULTS_DIR = BASE_DIR / "data" / "scan_results.json"
REPORT_PATH = BASE_DIR / "data" / "report.txt"


def format_finding(finding):
    ftype = finding['type']
    name = finding.get('name') or '(unnamed)'
    command = finding.get('command') or 'N/A'
    evidence = finding.get('evidence', {})

    base = f"{name}: {command}"

    if ftype == 'Service':
        base += f" [{evidence.get('active', '?')}]"
    elif ftype == 'active_setup':
        base += f" (installed={evidence.get('is_installed', '?')})"
    elif ftype == 'com_hijacking':
        base += f" ({evidence.get('server_type', '?')}, exists={evidence.get('file_exists', '?')})"

    return base

def main():
    with open(RESULTS_DIR, "r") as f:
        data = json.load(f)

    findings = data["results"]

    grouped = defaultdict(list)
    for finding in findings:
        grouped[finding["type"]].append(finding)

    with open(REPORT_PATH, "w") as out:
        for scan_type, items in grouped.items():
            out.write(f"\n=== {scan_type} ({len(items)} findings) ===\n")
            for finding in items:
                out.write(f"  - {format_finding(finding)}\n")

    print(f"Report written to {REPORT_PATH}")


if __name__ == "__main__":
    main()