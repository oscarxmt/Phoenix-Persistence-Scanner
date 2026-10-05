<div align="center">

# 🔥🐦‍🔥 Phoenix Persistence Scanner

**A lightweight, read-only Windows scanner for common persistence locations.**

Collect startup-related entries into structured JSON so they can be reviewed, parsed, and investigated.

![Platform](https://img.shields.io/badge/platform-Windows-0078D4?style=flat-square&logo=windows)
![Language](https://img.shields.io/badge/Python-3.7%2B-3776AB?style=flat-square&logo=python&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Mode](https://img.shields.io/badge/mode-read--only-2E8B57?style=flat-square)

</div>

---

## Contents

- [Overview](#overview)
- [What it scans](#what-it-scans)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Understanding the output](#understanding-the-output)
- [Project layout](#project-layout)
- [Current limitations](#current-limitations)
- [Contributing](#contributing)

## Overview

Phoenix runs a set of focused PowerShell checks and combines their findings into one JSON report. It is designed to make common Windows persistence locations easier to inspect and to provide structured input for future reporting or analysis tools.

Phoenix is **read-only**: it does not remove entries, change system settings, or execute discovered commands.

> A finding is an item to review, not a verdict. Many normal applications and Windows components register startup behavior.

## What it scans

| Check | Locations examined |
| --- | --- |
| Registry Run | Current-user and machine Run keys |
| Registry RunOnce | Current-user and machine RunOnce keys |
| Group Policy Run | Current-user and machine Explorer policy Run keys |
| Startup folders | Current-user and common Startup folders |
| Scheduled tasks | Enabled scheduled tasks and their actions |
| Services | Automatically-started Windows services |
| WMI subscriptions | Event filters, supported event consumers, and filter-to-consumer bindings in `root\subscription` |
| AppInit DLLs | Common machine, 32-bit machine, and current-user registry locations |
| Winlogon | Selected Winlogon registry values |
| Active Setup | Installed Components entries with a `StubPath` value |

Checks can be enabled or disabled individually in [`config.json`](config.json).

## Requirements

- Windows
- Python 3.9 or later
- Windows PowerShell available as `powershell`

The Python runner uses only the standard library. Several checks depend on Windows PowerShell modules and access to the relevant system locations. Run from an account with enough access for the locations you want to inspect; inaccessible checks should be reviewed in the report's `errors` array.

## Quick start

Clone the repository, open a terminal in its directory, and run:

```powershell
python3 .\main.py
```

You can also run the script from another working directory by providing its full path:

```powershell
python3 C:\path\to\Phoenix-Persistance-Scanner\main.py
```

The runner locates scripts and configuration relative to `main.py`, not the current directory. By default, the combined report is saved to `data/scan_results.json`.

To create the human-readable report, including Authenticode signature status for binary and script paths referenced by findings, run:

```powershell
python3 .\report_generator.py
```

Signature checks use Windows PowerShell's `Get-AuthenticodeSignature`.

## Configuration

`config.json` controls which checks run and where the combined report is written:

```json
{
  "checks": {
    "registry_run_keys": true,
    "registry_runonce_keys": true,
    "scheduled_tasks": true,
    "startup_folders": true,
    "services": true,
    "wmi_persistence": true,
    "group_policy_run_keys": true,
    "appinit_dlls_scan": true,
    "winlogon_scan": true,
    "activesetup_scan": true
  },
  "output": {
    "format": "json",
    "file": "./data/scan_results.json"
  }
}
```

Set a check to `false` to skip it. Relative output paths are resolved from the project directory; absolute paths are used as supplied. The current runner writes JSON output.

## Understanding the output

The report has two top-level arrays:

- `results` contains discovered entries.
- `errors` contains locations or checks that could not be read, plus other per-check issues.

A finding generally includes:

| Field | Meaning |
| --- | --- |
| `type` | Persistence category |
| `name` | Entry, task, service, or value name |
| `location` | Registry path, folder path, task path, or WMI location |
| `command` | Command or executable information when available |
| `enabled` | Whether the scanner considers the entry enabled |
| `evidence` | Additional details collected by that check |

Example finding:

```json
{
  "type": "registry_run_key",
  "name": "ExampleApp",
  "location": "Registry::HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run",
  "command": "C:\\Program Files\\Example\\example.exe --background",
  "enabled": true,
  "evidence": {
    "hive": "Registry::HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
  }
}
```

An `errors` entry does not always mean the entire scan failed. Some persistence locations may not exist or may not be readable on a particular computer. Review each message and consider it alongside the check's results.

## Project layout

```text
main.py                 Python runner
config.json             Check toggles and output path
Windows/                PowerShell checks and shared finding class
data/scan_results.json  Default combined report
report_generator.py     Human-readable report and Authenticode checks
```

## Current limitations

- Phoenix currently supports Windows only.
- Findings are collected, not classified as benign or suspicious.
- Recent-file filtering is not implemented.
- Startup-folder entries are listed as files; shortcut targets are not resolved.
- Results depend on the current account's permissions and Windows environment.

## Contributing

Bug reports and focused improvements are welcome. When adding a check, keep it read-only, emit the shared finding fields, include per-check errors in the JSON response, and document any platform or permission requirements.

---

<div align="center">

Made for defensive system inspection · Phoenix Persistence Scanner

</div>
