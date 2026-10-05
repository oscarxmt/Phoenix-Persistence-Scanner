#!/usr/bin/env python3
# Coded by OscarXMT


import platform
import argparse
import base64
import json
import subprocess
import sys
from pathlib import Path
import risk_rules
BASE_DIR = Path(__file__).resolve().parent


def json_config():
    config_path = BASE_DIR / "config.json"
    
    if not config_path.exists():
        print(f"[X] Error: {config_path} not found. Please check if the configuration file is in the correct location.")
        raise FileNotFoundError(config_path)
    
    with config_path.open('r', encoding='utf-8') as f:
        config = json.load(f)
    if not isinstance(config, dict) or not isinstance(config.get("checks"), dict):
        raise ValueError("Configuration must contain a checks object")
    if any(not isinstance(enabled, bool) for enabled in config["checks"].values()):
        raise ValueError("Each check must be true or false")
    output = config.get("output")
    if not isinstance(output, dict) or not isinstance(output.get("file"), str) or not output["file"].strip():
        raise ValueError("Configuration must contain a non-empty output.file path")
    return config


def output_path(config):
    path = Path(config["output"]["file"])
    return path if path.is_absolute() else BASE_DIR / path


def run_check(script):
    command = "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '" + str(script).replace("'", "''") + "'"
    return subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
         "-EncodedCommand", base64.b64encode(command.encode("utf-16-le")).decode("ascii")],
        capture_output=True,
        text=True,
        encoding="utf-8-sig",
        errors="replace",
    )


def windows():
    print("[!] Started scanning...")
    scripts_path = BASE_DIR / "Windows"
    
    if not scripts_path.exists():
        print(f"[X] Error: {scripts_path} not found. Please ensure the Windows folder within this repo, is in the correct location.")
        raise FileNotFoundError(scripts_path)
    config = json_config()
    if config is None:
        return
    # here we are listing all of the windows powershell scripts indeed :3
    checks = {
        "registry_run_keys": BASE_DIR / "Windows" / "reg_startup_scan.ps1",
        "registry_runonce_keys": BASE_DIR / "Windows" / "reg_runonce_scan.ps1",
        "scheduled_tasks": BASE_DIR / "Windows" / "Scheduled_Task_Scan.ps1",
        "startup_folders": BASE_DIR / "Windows" / "startup_folders_scan.ps1",
        "services": BASE_DIR / "Windows" / "services_scan.ps1",
        "wmi_persistence": BASE_DIR / "Windows" / "wmi_subscription_scan.ps1",
        "group_policy_run_keys": BASE_DIR / "Windows" / "group_policy_run_keys.ps1",
        "appinit_dlls_scan": BASE_DIR / "Windows" / "appinit_dlls_scan.ps1",
        "winlogon_scan": BASE_DIR / "Windows" / "winlogon_scan.ps1",
        "activesetup_scan": BASE_DIR / "Windows" / "activesetup_scan.ps1",
        "ifeo_scan": BASE_DIR / "Windows" / "ifeo_scan.ps1",
        "com_hijacking_scan": BASE_DIR / "Windows" / "com_hijacking_scan.ps1",
        "drivers": BASE_DIR / "Windows" / "drivers_scan.ps1",
    }

    scan_results = {
        "results": [],
        "errors": []
    }

    for check_name, script in checks.items():
        if not config["checks"].get(check_name):
            continue

        print(f"[*] Running {check_name}...")

        try:
            completed = run_check(script)
        except OSError as error:
            scan_results["errors"].append({"check": check_name, "message": str(error)})
            continue

        if completed.returncode != 0:
            scan_results["errors"].append({
                "check": check_name,
                "message": completed.stderr.strip() or "PowerShell script failed",
                "exit_code": completed.returncode
            })
            continue

        try:
            script_output = json.loads(completed.stdout)
            if not isinstance(script_output, dict) or any(
                not isinstance(script_output.get(field), list)
                or any(not isinstance(item, dict) for item in script_output[field])
                for field in ("results", "errors")
            ):
                raise ValueError("Expected results and errors arrays of objects")
            scan_results["results"].extend(script_output.get("results", []))
            scan_results["errors"].extend(script_output.get("errors", []))
        except ValueError as error:
            scan_results["errors"].append({
                "check": check_name,
                "message": "PowerShell returned invalid scan output",
                "details": str(error)
            })
    for finding in scan_results["results"]:
        finding["risk"] = risk_rules.rules_checker(finding)

    print("[+] Scan completed. Saving results to json file...")
    output_file = output_path(config)
    output_file.parent.mkdir(parents=True, exist_ok=True)

    with output_file.open("w", encoding="utf-8") as file:
        json.dump(scan_results, file, indent=2)

    print(f"[+] Scan results saved to {output_file}")
    return output_file


def finish_reports(results_file):
    report_file = BASE_DIR / "data" / "report.txt"
    risk_report_file = BASE_DIR / "data" / "risk_report.txt"
    if report_file.exists() and not risk_report_file.exists():
        existing = report_file.read_text(encoding="utf-8", errors="replace")
        if existing.lstrip().startswith("=== Risk rules"):
            risk_report_file.write_text(existing, encoding="utf-8")
            report_file.unlink()

    # Rebuild the complete human-readable report on every scan. Rule output is
    # kept separately in risk_report.txt, so this file can safely be refreshed.
    import report_generator
    report_generator.main()

    risk_exit = risk_rules.main([
        "--input", str(results_file),
        "--report", str(risk_report_file),
    ])
    if risk_exit:
        raise RuntimeError("Risk rules could not append to the report")
    print(f"[+] Human-readable report: {report_file}")
    print(f"[+] Risk-rule report: {risk_report_file}")
    return report_file

def main():
    parser = argparse.ArgumentParser(description="Persistence Scanner")
    parser.parse_args()

    current_os = platform.system()
    print("Made by OscarXMT!")
    print("Follow my socials: x.com/oscarxmt github.com/oscarxmt")
    print(f"[-] Detected operating system: {current_os}")
    print("<" + "=" * 40 + ">")
    
    if current_os == "Windows":
        try:
            results_file = windows()
            finish_reports(results_file)
        except (OSError, ValueError) as error:
            print(f"[X] {error}", file=sys.stderr)
            return 1
    elif current_os == "Linux":
        print("[!] Linux detected. Support is not coded yet.")
    elif current_os == "Darwin":
        print("[!] macOS detected. Support is not coded yet.")
    else:
        print("[X] Unknown operating system. Could not scan.")



if __name__ == "__main__":
    sys.exit(main())
