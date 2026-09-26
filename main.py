#!/usr/bin/env python3

import platform
import os
import argparse
import json
import subprocess
from pathlib import Path

BASE_DIR = Path(__name__).resolve().parent


def json_config():
    config_path = BASE_DIR / "config.json"
    
    if not config_path.exists():
        print(f"[X] Error: {config_path} not found. Please check if the configuration file is in the correct location.")
        exit()
    
    with config_path.open('r', encoding='utf-8') as f:
        return json.load(f)


def windows():
    print("[!] Started scanning...")
    scripts_path = BASE_DIR / "Windows"
    
    if not scripts_path.exists():
        print(f"[X] Error: {scripts_path} not found. Please ensure the Windows folder within this repo, is in the correct location.")
        exit()
    config = json_config()
    if config is None:
        return
    checks = {
        "registry_run_keys": BASE_DIR / "Windows" / "reg_startup_scan.ps1",
        "scheduled_tasks": BASE_DIR / "Windows" / "Scheduled_Task_Scan.ps1",
        "startup_folders": BASE_DIR / "Windows" / "startup_folders_scan.ps1",
    }

    scan_results = {
        "results": [],
        "errors": []
    }

    for check_name, script in checks.items():
        if not config["checks"].get(check_name):
            continue

        print(f"[*] Running {check_name}...")

        completed = subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(script)
            ],
            capture_output=True,
            text=True
        )

        if completed.returncode != 0:
            scan_results["errors"].append({
                "check": check_name,
                "message": completed.stderr.strip() or "PowerShell script failed",
                "exit_code": completed.returncode
            })
            continue

        try:
            script_output = json.loads(completed.stdout)
            scan_results["results"].extend(script_output.get("results", []))
            scan_results["errors"].extend(script_output.get("errors", []))
        except json.JSONDecodeError as error:
            scan_results["errors"].append({
                "check": check_name,
                "message": "PowerShell returned invalid JSON",
                "details": str(error)
            })

    output_file = Path(config["output"]["file"])
    if not output_file.is_absolute():
        output_file = BASE_DIR / output_file
    output_file.parent.mkdir(parents=True, exist_ok=True)

    with output_file.open("w", encoding="utf-8") as file:
        json.dump(scan_results, file, indent=2)

    print(f"[+] Scan results saved to {output_file}")


def main():
    parser = argparse.ArgumentParser(description="Persistence Scanner")
    parser.parse_args()

    current_os = platform.system()

    print(f"[-] Detected operating system: {current_os}")
    print("=" * 40)
    
    if current_os == "Windows":
        windows()
    elif current_os == "Linux":
        print("[!] Linux detected. Support is not coded yet.")
    elif current_os == "Darwin":
        print("[!] macOS detected. Support is not coded yet.")
    else:
        print("[X] Unknown operating system. Could not scan")



if __name__ == "__main__":
    main()