"""Read-only rules: importing this module never runs a scan or executes commands."""

import ntpath
import re
import argparse
import json
import sys
from pathlib import Path
from datetime import datetime


REPORT_PATH = Path(__file__).resolve().parent / "data" / "risk_report.txt"


# small list not everything from the lolbas project:
# https://lolbas-project.github.io/
LOLBINS = {
    "bitsadmin.exe", "certutil.exe", "cscript.exe", "mshta.exe",
    "msiexec.exe", "regsvr32.exe", "rundll32.exe", "wscript.exe",
}


def command_parts(finding):
    command = finding.get("command") or ""
    if not isinstance(command, str):
        return "", ""
    command = command.strip()
    if not command:
        return "", ""
    if command.startswith('"'):
        end = command.find('"', 1)
        if end == -1:
            return "", ""
        executable, arguments = command[1:end], command[end + 1:].strip()
    else:
        match = re.match(
            r"^((?:[a-z]:[\\/]|[\\/]|%[^%]+%[\\/]|\.[\\/]).+?\.exe)(?=\s|$)",
            command, re.IGNORECASE,
        )
        if match:
            executable, arguments = match.group(1), command[match.end():].strip()
        else:
            parts = command.split(maxsplit=1)
            executable, arguments = parts[0], parts[1] if len(parts) > 1 else ""
    return ntpath.basename(executable).casefold(), arguments


def check_lolbins(finding):
    executable, _ = command_parts(finding)
    if executable and not ntpath.splitext(executable)[1]:
        executable += ".exe"
    if executable in LOLBINS:
        return [f"LOLBin used by persistence entry: {executable}; review its arguments (legitimate use is possible)"]
    return []


def check_encoded_powershell(finding):
    executable, arguments = command_parts(finding)
    switches = re.findall(r"(?:^|\s)-([a-z]+)(?=\s|$)", arguments, re.IGNORECASE)
    if executable in {"powershell", "powershell.exe", "pwsh", "pwsh.exe"} and any(
        "encodedcommand".startswith(switch.casefold()) for switch in switches
    ):
        return ["PowerShell encoded command in persistence entry; review the decoded content"]
    return []

RULES = (check_lolbins, check_encoded_powershell)


def rules_checker(finding, signatures=()):
    verdict, reasons = evaluate(finding, signatures)
    return {"verdict": verdict, "reasons": reasons}


def evaluate(finding, signatures=()):
    reasons = [reason for rule in RULES for reason in rule(finding)]
    has_rule_match = bool(reasons)
    signatures = list(signatures)
    has_error = not signatures
    has_invalid_signature = False
    
    for sig in signatures:
        path = sig.get("original_path") or sig.get("path") or "(unknown path)"
        if "error" in sig:
            has_error = True
            reasons.append(f"signature check failed: {path}: {sig['error']}")
        elif not sig.get("status") or sig["status"] in ("Unknown", "UnknownError"):
            has_error = True
            reasons.append(f"signature status unknown: {path}")
        elif sig["status"] != "Valid":
            has_invalid_signature = True
            reasons.append(f"unsigned/invalid signature: {path}")

    verdict = "suspicious" if has_rule_match or has_invalid_signature else "unknown" if has_error else "clean"
    
    return verdict, reasons


def append_report(report_text, report_path):
    report_path.parent.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().astimezone().isoformat(timespec="seconds")
    with report_path.open("a", encoding="utf-8") as file:
        file.write(f"\n\n=== Risk rules ({timestamp}) ===\n")
        file.write(report_text + "\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Check saved persistence findings against risk rules.")
    parser.add_argument("--input", type=Path, help="Scan JSON to read (default: output.file in config.json)")
    parser.add_argument("--all", action="store_true", help="Also display findings without rule matches")
    parser.add_argument("--report", type=Path, default=REPORT_PATH,
                        help="Report to append to (default: data/risk_report.txt)")
    args = parser.parse_args(argv)

    try:
        input_path = args.input
        if input_path is None:
            from main import json_config, output_path
            input_path = output_path(json_config())
        if args.report.resolve() == input_path.resolve():
            raise ValueError("The report must be a different file from the scan JSON")
        with input_path.open("r", encoding="utf-8-sig") as file:
            data = json.load(file)
        if not isinstance(data, dict) or not isinstance(data.get("results"), list):
            raise ValueError("Scan JSON must contain a results array")
        if any(not isinstance(finding, dict) for finding in data["results"]):
            raise ValueError("Each result must be an object")
        if not isinstance(data.get("errors", []), list):
            raise ValueError("Scan errors must be an array")
    except (OSError, ValueError) as error:
        print(f"[X] Could not load saved scan: {error}", file=sys.stderr)
        print("Run py .\\main.py first, or use --input PATH.", file=sys.stderr)
        return 1

    assessments = [(finding, rules_checker(finding)) for finding in data["results"]]
    matched = sum(risk["verdict"] == "suspicious" for _, risk in assessments)
    lines = [
        f"[+] Checked {len(assessments)} findings from {input_path}",
        f"[!] {matched} findings flagged for review. Matches are not proof of malware.",
        "[i] This section uses command rules only; it does not recheck binary signatures.",
    ]
    if data.get("errors"):
        lines.append(f"[!] Saved scan contains {len(data['errors'])} errors; results may be incomplete.")
    for finding, risk in assessments:
        if not args.all and risk["verdict"] != "suspicious":
            continue
        lines.append(f"\n[{risk['verdict'].upper()}] {finding.get('name') or '(unnamed)'}")
        lines.append(f"  Type: {finding.get('type') or 'N/A'}")
        lines.append(f"  Location: {finding.get('location') or 'N/A'}")
        lines.append(f"  Command: {finding.get('command') or 'N/A'}")
        for reason in risk["reasons"]:
            lines.append(f"  - {reason}")
    if not matched and not args.all:
        lines.append("[i] No command rules matched. Use --all to display every finding.")
    report_text = "\n".join(lines)
    print(report_text)
    try:
        append_report(report_text, args.report)
    except OSError as error:
        print(f"[X] Could not append to report: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
