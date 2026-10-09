<div align="center">

# 🐦‍🔥 Phoenix Persistence Scanner

**Inspect common Windows persistence locations, review the evidence, and optionally analyze it with a local model.**

![Platform](https://img.shields.io/badge/platform-Windows-0078D4?style=flat-square&logo=windows)
![Language](https://img.shields.io/badge/Python-3.9%2B-3776AB?style=flat-square&logo=python&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Mode](https://img.shields.io/badge/scanning-read--only-2E8B57?style=flat-square)

**Scan → Review evidence → Analyze locally → Read the consolidated assessment**

[Quick start](#quick-start) · [Local model setup](#setup-and-usage) · [Options](#options) · [Troubleshooting](#troubleshooting)

</div>

## Overview

Phoenix runs focused PowerShell checks and saves structured JSON, a human-readable report with Authenticode signature results, and command-rule review hints. Optional analysis through a local llama.cpp server reviews the text report in batches and combines the results into one prioritized assessment.

Scanning is **read-only**: Phoenix does not remove persistence entries, change system settings, or execute discovered commands. It writes reports and, when model analysis is requested, starts and stops its own local server.

> A finding is an item to review, not a malware verdict. Normal applications and Windows components also register startup behavior.

## Contents

- [Quick start](#quick-start)
- [What it scans](#what-it-scans)
- [Reports and saved scans](#reports-and-saved-scans)
- [Local model analysis](#local-model-analysis)
- [Configuration](#configuration)
- [Understanding findings](#understanding-findings)
- [Troubleshooting](#troubleshooting)
- [Project layout](#project-layout)
- [Current limitations](#current-limitations)
- [Contributing](#contributing)

## Quick start

You need **Windows**, **Python 3.9 or later**, and **Windows PowerShell 5.1 or later**, available as `powershell`. The Python scripts use only the standard library; no additional Python packages are required.

Download or clone this repository, open PowerShell in its directory, and run:

```powershell
py .\main.py
```

This runs every enabled check and generates the three scan reports listed below. Review `data/report.txt` first, including its scan errors. Access to some locations depends on the account running the scan.

For optional model analysis, complete the [local model setup](#setup-and-usage), then run:

```powershell
py .\llm.py
```

Analysis is a separate step; `main.py` does not start it automatically. When analysis finishes successfully, the consolidated assessment is saved to `data/llm_final_report.txt`.

Examples use the Windows Python launcher, `py`. If your installation provides `python` instead, substitute it throughout. Configuration and scanner scripts are located relative to the project, so running `main.py` by its full path also works:

```powershell
py "C:\path\to\Phoenix-Persistance-Scanner\main.py"
```

## What it scans

| Check | Locations examined |
| --- | --- |
| Registry Run | Current-user and machine Run keys, including the 32-bit machine location on 64-bit Windows |
| Registry RunOnce | Current-user and machine RunOnce keys |
| Group Policy Run | Current-user and machine Explorer policy Run keys |
| Startup folders | Current-user and common Startup folders |
| Scheduled tasks | Enabled scheduled tasks and their actions, including COM handlers |
| Services | Automatically started Windows services |
| WMI subscriptions | Event filters, supported event consumers, and filter-to-consumer bindings in `root\subscription` |
| AppInit DLLs | Machine, 32-bit machine, and current-user registry locations |
| Winlogon | Selected values, including `Shell`, `Userinit`, and `Taskman` |
| Active Setup | Installed Components entries with a `StubPath` value |
| Image File Execution Options | Machine-level `Debugger` values |
| COM registrations | Current-user `InprocServer32` and `LocalServer32` registrations |
| Drivers | Boot, system, and automatically started system drivers |

Enable or disable checks individually in [`config.json`](config.json). Coverage is limited to the implemented checks; it is not an exhaustive scan of every Windows persistence mechanism.

## Reports and saved scans

| File | Contents | Write behavior |
| --- | --- | --- |
| `data/scan_results.json` | Findings, command-rule assessments, and scan errors | Replaced by each scan; path configurable |
| `data/report.txt` | Findings grouped by type, signature results, and errors | Replaced when the text report is generated |
| `data/risk_report.txt` | Command-rule review results with timestamped headings | Appended after a scan or standalone rule review |
| `data/llm_final_report.txt` | Consolidated model assessment and source report path | Replaced only after a new assessment is successfully written |
| `data/llama-server.log` | Diagnostics from the local model server | Replaced on each server launch |

The last two files are created by `llm.py`. Changing `output.file` in the configuration changes only the scan JSON path. Use `llm.py --output PATH` to change the final model report destination.

### Review an existing scan

Regenerate the human-readable report from the configured JSON file without collecting persistence entries again:

```powershell
py .\report_generator.py
```

This rechecks recognized binary and script paths with PowerShell's `Get-AuthenticodeSignature`. Signature results describe files available at report-generation time. They appear in the text report, not in the saved scan JSON.

Reassess saved findings using only the command rules:

```powershell
py .\risk_rules.py
```

By default, this reads `output.file` from `config.json`, displays matched findings, and appends results to `data/risk_report.txt`. It does not modify the scan JSON or `data/report.txt` and does not recheck signatures.

To include unmatched findings or use different files:

```powershell
py .\risk_rules.py --all
py .\risk_rules.py --input "C:\Scans\scan_results.json" --report "C:\Scans\risk_report.txt"
```

The input must be scan JSON, and the report destination must be a different file.

## Local model analysis

`llm.py` sends an existing text report to a llama.cpp server bound to `127.0.0.1`. It requires no API key or cloud service and does not download models. Supply a compatible chat/instruct GGUF model and a server build that fits your hardware and available memory.

### Setup and usage

1. Obtain a Windows server package from the [official llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases). Extract the complete package and keep `llama-server.exe` with its accompanying DLLs.
2. Store a compatible chat/instruct `.gguf` model on your computer.
3. Generate a fresh report with `py .\main.py`.
4. Run `py .\llm.py` and enter the model path when prompted, or supply both paths directly:

```powershell
py .\llm.py --server "C:\llama.cpp\llama-server.exe" --model "C:\Models\model.gguf"
```

The script looks for the server beside `llm.py`, in the current directory, and on PATH, then prompts if necessary. It recognizes `llama-server.exe`, `lama-server.exe`, and `llama-server`. Quote paths containing spaces; relative paths supplied as arguments or at prompts resolve from your current directory.

Phoenix starts its own server on port `8080`, waits for the model to load, and keeps it loaded throughout the review. Each batch's answer and elapsed time appear when that request finishes. A final pass combines the batch reviews into a deduplicated, prioritized assessment, prints it, and saves it to `data/llm_final_report.txt`. The server is stopped on completion, failure, or Ctrl+C.

Use a server build supporting `--jinja`, `/v1/chat/completions`, `/apply-template`, and `/tokenize`. The last two endpoints are used to check the consolidation prompt's context budget. A `.gguf` extension alone does not establish chat compatibility.

### Command examples

Add `--model PATH` and `--server PATH` to any example to avoid path prompts.

| Goal | Command |
| --- | --- |
| Standard batch review | `py .\llm.py` |
| Less report input per batch | `py .\llm.py --batch-size 3000` |
| Longer batch answers | `py .\llm.py --max-tokens 2048` |
| Longer final assessment | `py .\llm.py --final-max-tokens 4096` |
| Save the final assessment elsewhere | `py .\llm.py --output "C:\Scans\final.txt"` |
| Request extra reasoning where supported | `py .\llm.py --thinking --max-tokens 4096` |
| Allow slower loading and analysis | `py .\llm.py --startup-timeout 600 --timeout 1200` |
| Use a different local port | `py .\llm.py --port 8081` |
| Review a saved text report | `py .\llm.py --report "C:\Scans\report.txt"` |

`--report` expects non-empty UTF-8 text, optionally with a byte-order mark. Generate a human-readable report before analyzing scan JSON through this workflow.

### Options

| Option | Purpose | Default |
| --- | --- | --- |
| `-h`, `--help` | Show usage without starting the server | — |
| `--model PATH` | Local chat/instruct GGUF model | Prompted |
| `--server PATH` | llama.cpp server executable | Detected or prompted |
| `--report PATH` | Text report to analyze | Project's `data/report.txt` |
| `--port N` | Local server port | `8080` |
| `--ctx-size N` | Context size in tokens | `8192` |
| `--max-tokens N` | Maximum response tokens per batch | `1024` |
| `--final-max-tokens N` | Maximum response tokens for the consolidated assessment | `3072` |
| `--output PATH` | Final assessment destination | Project's `data/llm_final_report.txt` |
| `--batch-size N` | Maximum UTF-8 report bytes per batch, subject to the context budget | `6000` |
| `--full-report` | Review the source as one batch before consolidation | Off |
| `--thinking` | Request extra reasoning where the chat template supports it | Off |
| `--yarn-orig-ctx N` | Enable YaRN extension using this native context size | Not overridden |
| `--startup-timeout N` | Model loading timeout in seconds | `300` |
| `--timeout N` | Timeout per analysis or consolidation request in seconds | `600` |

All numeric values must be positive integers; ports must be between `1` and `65535`. `--max-tokens` must be smaller than `--ctx-size`. Batch mode requires at least 2048 context tokens beyond `--max-tokens`, and all modes require at least 2048 beyond `--final-max-tokens`.

### Context, performance, and consolidation

Start with the default batch mode. It uses an 8192-token context and limits each batch to 6000 UTF-8 bytes, reducing that byte limit further when the response budget requires it. Bytes and tokens are different units: the batch limit is a conservative input estimate, not an exact token count.

Every part of the source text is included in the batch requests. The splitter prefers finding and line boundaries, but long entries can span batches. Repeated certificate descriptions are factored into an exact-text legend within each request. Batch labels include the report section at the start of the batch.

Batch reviews are independent. The final pass combines their assessments and is instructed to correlate evidence, retain batch references, and remove duplicates. If they exceed the available context, Phoenix summarizes smaller groups and checks again, for up to eight reduction passes. It counts the formatted consolidation prompt and reserves the final response budget plus 256 tokens of slack.

**The final assessment is based on model summaries.** Details can be lost during analysis or consolidation even though all source text was submitted. Token-limited responses are flagged, and batch or intermediate truncation is noted in the final report. Verify conclusions against the original JSON and text report.

Smaller batches can shorten the wait for the first answer while increasing the number of requests. More response tokens or `--thinking` can increase generation time. A larger context may reduce consolidation passes but requires more memory; it does not inherently make inference faster. Thinking support and its effect depend on the model and chat template.

#### Full-report review and extended context

`--full-report` sends all source text as one batch, retaining certificate compaction, and then consolidates that review. The context must fit the report, instructions, and response. For a model that supports the chosen context size, for example:

```powershell
py .\llm.py --full-report --ctx-size 32768 --max-tokens 2048
```

Use the model's documented context limits. If the model supports YaRN extension, `--yarn-orig-ctx N` supplies its native context size; `--ctx-size` must be greater than that value. Context extension is optional and is not needed for the default workflow.

### Stopping and saving output

Press **Ctrl+C in the terminal running `llm.py`** to cancel. Phoenix stops its server and reports how many batches completed. Interrupted or failed reviews cannot resume automatically; rerunning starts again.

The final assessment is written through a temporary file and replaces the destination only after the new file has been fully written. If a run fails before replacement, an earlier assessment may still be present: look for `Final AI report saved to ...` to confirm success. Parent directories for `--output` are created automatically. The destination cannot be the source report, model, server executable, or server log.

Individual batch reviews are printed to the terminal. To retain them along with status messages and errors, run this after generating the scan report:

```powershell
py -u .\llm.py --server "C:\llama.cpp\llama-server.exe" --model "C:\Models\model.gguf" 2>&1 | Tee-Object -FilePath .\data\llm_analysis.txt
```

This terminal capture is separate from the final assessment and is replaced on each run. Choose another filename to preserve a previous capture.

To watch server diagnostics in a second PowerShell window after the log exists:

```powershell
Get-Content .\data\llama-server.log -Tail 25 -Wait
```

Ctrl+C in the second window stops only the log viewer. Batch responses appear when each request finishes; they are not streamed token by token.

## Configuration

[`config.json`](config.json) controls the checks and scan JSON destination:

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
    "activesetup_scan": true,
    "ifeo_scan": true,
    "com_hijacking_scan": true,
    "drivers_scan": true
  },
  "output": {
    "format": "json",
    "file": "./data/scan_results.json"
  }
}
```

Set a check to `false` to skip it. Omitted checks are also skipped. Values in `checks` must be booleans, and `output.file` must be a non-empty path. Relative output paths resolve from the project directory; absolute paths are used as supplied. The runner always writes JSON; changing `output.format` does not enable other formats.

## Understanding findings

The scan JSON has two top-level arrays: `results` for discovered entries and `errors` for unreadable locations, missing locations, or other check issues. Each result also receives a `risk` object.

| Field | Meaning |
| --- | --- |
| `type` | Persistence category |
| `name` | Entry, task, service, or registry value name |
| `location` | Registry path, folder, task path, or WMI location |
| `command` | Command or executable information, when available |
| `enabled` | The check's indication of whether the entry is enabled; not proof it executes |
| `evidence` | Additional details collected by that check |
| `risk` | Rule verdict and supporting reasons |

Example saved finding:

```json
{
  "type": "registry_run_key",
  "name": "ExampleApp",
  "location": "Registry::HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run",
  "command": "\"C:\\Program Files\\Example\\example.exe\" --background",
  "enabled": true,
  "evidence": {
    "hive": "Registry::HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
  },
  "risk": {
    "verdict": "unknown",
    "reasons": []
  }
}
```

The command rules flag a small set of executable names drawn from [LOLBAS](https://lolbas-project.github.io/) and PowerShell encoded-command switches for review. A rule match produces `suspicious`; unmatched scan findings remain `unknown`. Legitimate commands can match, and an unmatched finding is not proof of safety.

The rules inspect the first executable. They do not parse nested shells, resolve shortcut targets, or detect renamed executables and general obfuscation. Signature results are shown separately in the text report. The rule API can accept signatures belonging to a finding, but the scanner does not currently supply them; even a signature-only `clean` verdict is not proof of safety.

An `errors` entry does not necessarily mean the whole scan failed. Some checks report missing keys or empty values there. Read each message alongside the available findings.

## Troubleshooting

| Issue | Action |
| --- | --- |
| `py` or `python` is unavailable or opens Microsoft Store | Check the Python installation and launcher. Use the command that successfully returns a Python version. |
| Scanner reports access errors | Review the JSON `errors` and text report. Run under an account with access to the required locations; other checks may still return findings. |
| Report is missing or empty | Run `py .\main.py`, or pass an existing non-empty text report with `--report PATH`. |
| Server executable is not found | Provide its full path with `--server PATH`; keep its accompanying DLLs in the extracted directory. |
| A path with spaces cannot be found | Quote the full file path, including the filename. |
| Port is unavailable | Select another port, such as `--port 8081`. Phoenix starts its own server instead of attaching to an existing one. |
| Model loading fails or times out | Check `data/llama-server.log`, model compatibility, and available memory. Increase `--startup-timeout` if loading is slow. |
| Startup reports `0xC0E90002` | Phoenix identifies this as a Windows Code Integrity block. Follow the script's guidance to inspect CodeIntegrity event 3077 for the blocked executable or DLL, then obtain a package accepted by the active policy or ask your administrator to review it. |
| A server option or token-count endpoint is unsupported | Use a compatible llama.cpp build supporting the options and endpoints listed under setup. Batch answers remain in the terminal if consolidation fails. |
| Input exceeds the context size | Reduce `--batch-size`, leave full-report mode, or increase `--ctx-size` within the model's supported limits and available memory. |
| Analysis takes too long | Try smaller batches and leave `--thinking` off. Increase `--timeout` when requests need more time. |
| A response reaches its token limit | Increase `--max-tokens` for batches or `--final-max-tokens` for the final assessment, leaving sufficient input space. Intermediate-summary warnings identify `--ctx-size`. |
| Context-budget validation fails | Leave at least 2048 tokens beyond each applicable response budget. Increasing response limits reduces the room available for input. |
| `--yarn-orig-ctx` is rejected | The requested context must exceed the supplied native context. Omit YaRN for the default batch workflow. |
| Model returns no analysis | Check chat/instruct model compatibility and allow enough response tokens, especially when thinking is enabled. |
| Review is incomplete or the final file appears unchanged | Read the terminal error and server log. Earlier final reports survive failed runs; only the save-completion message confirms a new final report. |
| `--output` is rejected | Choose a destination distinct from the source report, model, server executable, and server log. |

## Project layout

```text
main.py                    Scanner and report workflow
config.json                Check toggles and scan JSON path
Windows/                   PowerShell checks and shared finding class
report_generator.py        Human-readable report and Authenticode checks
risk_rules.py              Command-rule assessments
llm.py                     Optional local model analysis and consolidation
requirements.txt           Python dependency notes
data/scan_results.json     Structured scan results
data/report.txt            Human-readable scan report
data/risk_report.txt       Timestamped command-rule results
data/llama-server.log      Latest local server diagnostics
data/llm_final_report.txt  Final model assessment
data/llm_analysis.txt      Optional terminal capture using Tee-Object
```

## Current limitations

- Windows only; results depend on the current account, permissions, and environment. Current-user checks do not cover every user profile.
- Coverage is limited to the implemented checks. There is no recent-file filter, automatic remediation, or guarantee that all persistence is detected.
- Startup-folder shortcuts are listed as files; their targets are not resolved. Finding an entry or marking it enabled does not prove it will execute.
- Signature extraction recognizes supported path patterns and extensions; it is not a complete command-line parser. Signature checks and rule assessments remain separate steps.
- Local model quality depends on the model, context, and response budgets. Consolidation combines reviews but can lose details or make mistakes.
- Interrupted reviews cannot resume automatically. Batch answers are retained only in the terminal unless you capture them.

## Contributing

Bug reports and focused improvements are welcome. Include the command used, relevant error output, and enough environment information to reproduce the issue. Remove personal paths and other sensitive report details before sharing.

When adding a check, keep it read-only, emit the shared finding fields, return `results` and `errors` arrays, and document its platform and permission requirements. To add a command rule, define a function in `risk_rules.py` that returns reasons for a finding (or `[]`), then add it to `RULES`.

No regression tests are currently tracked in this repository. Changes should include appropriate validation and clear reproduction steps.

---

<div align="center">

Made for defensive system inspection · Phoenix Persistence Scanner

</div>
