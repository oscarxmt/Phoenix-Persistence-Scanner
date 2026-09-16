#!/usr/bin/env python3

import platform
import os
import argparse
import json
import subprocess

def json_config():
    config_path = "config.json"
    
    if not os.path.exists(config_path):
        print(f"[X] Error: {config_path} not found. Please check if the configuration file is in the correct location.")
        exit()
    
    with open(config_path, 'r') as f:
        return json.load(f)


def windows():
    print("[!] Started scanning...")
    scripts_path = "Windows"
    
    if not os.path.exists(scripts_path):
        print(f"[X] Error: {scripts_path} not found. Please ensure the Windows folder within this repo, is in the correct location.")
        exit()
    config = json_config()
    if config is None:
        return
    checks = {
        "registry_run_keys": "Windows/reg_startup_scan.ps1",
        "startup_folders": "Windows/startup_folders_scan.ps1",
    }

    for check_name, script in checks.items():
        if config["checks"].get(check_name):
            subprocess.run(["powershell", "-ExecutionPolicy", "Bypass", "-File", script])
def main():
    parser = argparse.ArgumentParser(description="Persistence Scanner")
    args = parser.parse_args()

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
    raise SystemExit(main())