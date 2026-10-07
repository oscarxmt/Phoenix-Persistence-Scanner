<div align="center">

# 🐦‍🔥🔥Phoenix Persistence Scanner

**A lightweight, read-only Windows scanner for common persistence locations.**

Collect startup-related entries into structured JSON so they can be reviewed, parsed, and investigated.

![Platform](https://img.shields.io/badge/platform-Windows-0078D4?style=flat-square&logo=windows)
![Language](https://img.shields.io/badge/Python-3.9%2B-3776AB?style=flat-square&logo=python&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Mode](https://img.shields.io/badge/mode-read--only-2E8B57?style=flat-square)

**Scan → Review evidence → Analyze locally with llm**

[Get started](#quick-start) · [Local model setup](#setup-and-usage) · [Command examples](#command-examples) · [Troubleshooting](#troubleshooting)

</div>

---

## Contents

- [Overview](#overview)
- [What it scans](#what-it-scans)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Local model analysis](#local-model-analysis)
  - [Setup and usage](#setup-and-usage)
  - [Command examples](#command-examples)
  - [Options](#options)
  - [Performance and quality](#performance-and-quality)
  - [Full-report review and extended context](#full-report-review-and-extended-context)
  - [Stopping and saving output](#stopping-and-saving-output)
  - [Troubleshooting](#troubleshooting)
  - [Checking server downloads](#checking-server-downloads)
- [Configuration](#configuration)
- [Understanding the output](#understanding-the-output)
- [Project layout](#project-layout)
- [Current limitations](#current-limitations)
- [Contributing](#contributing)

## Overview

Phoenix runs focused PowerShell checks and produces structured JSON, a human-readable report, and rule-based review hints. Optional local model analysis uses llama.cpp and a user-provided GGUF model to help interpret the report.

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
| Image File Execution Options | Machine-level `Debugger` values |
| COM registrations | Current-user `InprocServer32` and `LocalServer32` registrations |
| Drivers | Boot, system, and automatically started system drivers |

Checks can be enabled or disabled individually in [`config.json`](config.json).

## Requirements

- Windows
- Python 3.9 or later
- Windows PowerShell available as `powershell`

All Python scripts use the standard library; no additional Python packages are required. Several checks depend on Windows PowerShell modules and access to the relevant system locations. Review inaccessible checks in the report's `errors` array.

Optional local model analysis also requires a llama.cpp server executable and a compatible chat/instruct `.gguf` model stored on your computer. Keep the executable's accompanying DLLs in its installation directory.

## Quick start

Clone the repository, open a terminal in its directory, and run:

```powershell
py .\main.py
```

For the complete scan-and-analysis workflow, run these commands in order. The
second command requires the optional server and model described under
[Local model analysis](#local-model-analysis):

```powershell
py .\main.py
py .\llm.py
```

The scanner can also be used on its own. Model analysis is optional and is never
started automatically by `main.py`.

This command runs the enabled checks and produces the following files:

| File | Contents | Behavior on each run |
| --- | --- | --- |
| `data/scan_results.json` | Structured findings, rule assessments, and scan errors | Replaced |
| `data/report.txt` | Human-readable findings and Authenticode signature results | Replaced |
| `data/risk_report.txt` | Timestamped command-rule results | Appended |

The JSON output path can be changed in `config.json`. Scripts and configuration are resolved relative to the project directory, so you can also run:

```powershell
py "C:\path\to\Phoenix-Persistance-Scanner\main.py"
```

Examples use the Windows Python launcher, `py`. If your installation provides `python` instead, substitute it in the commands below.

### Review an existing scan

To regenerate the human-readable report from saved scan results without running the scanner again:

```powershell
py .\report_generator.py
```

This reads the JSON file selected by `output.file` in `config.json` and checks referenced binary and script paths using PowerShell's `Get-AuthenticodeSignature`. Scan errors remain included even if signature verification fails.

To reassess saved findings using only the command rules:

```powershell
py .\risk_rules.py
```

This reads `output.file` from `config.json` without modifying the scan. Use
`--all` to include unmatched findings or `--input PATH` to check another scan JSON.
Results are appended to `data/risk_report.txt` under a timestamped heading.
Use `--report PATH` to append elsewhere. Each run adds a new section and leaves
`data/report.txt` unchanged.

<details>
<summary><strong>More command-rule examples</strong></summary>

Include entries that did not match a rule:

```powershell
py .\risk_rules.py --all
```

Assess a different scan and append results to a separate text file:

```powershell
py .\risk_rules.py --input "C:\Scans\scan_results.json" --report "C:\Scans\risk_report.txt"
```

The input must be a scan JSON file. The output must be a different file.

</details>

## Local model analysis

`llm.py` analyzes an existing report through a local llama.cpp server. It runs
separately from the scanner and does not change the scan reports. No API key or
cloud service is required, and the script does not download models.

> **Recommended starting point:** use `py .\llm.py` with the default batch mode.
> It reviews the entire report in smaller requests, uses an 8192-token context,
> and prints results after each batch. No Qwen-specific settings are required.

### Setup and usage

1. Prepare a Windows build of the [llama.cpp server](https://github.com/ggml-org/llama.cpp/tree/master/tools/server), including `llama-server.exe` and its accompanying DLLs.
2. Store a compatible chat/instruct `.gguf` model locally. Model size and context length must fit your available memory.
3. Generate a non-empty report with `py .\main.py`.
4. Start the analysis:

```powershell
py .\llm.py
```

Use a server build compatible with your Windows architecture and hardware. The
[official llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases)
provide downloadable packages. Extract the complete package to a permanent
folder; copying only the executable can leave required DLLs behind.

The model must support text chat in your server build. A `.gguf` extension alone
does not guarantee compatibility: embedding-only models and unsupported chat
templates cannot provide the expected report analysis.

Enter the model's file path when prompted. The script searches for
`llama-server.exe` beside `llm.py`, in the current directory, and on PATH. If it
cannot find the executable, it prompts for its path. The alternate filename
`lama-server.exe` is also recognized.

To provide both paths without prompts:

```powershell
py .\llm.py --server "C:\llama.cpp\llama-server.exe" --model "C:\Models\model.gguf"
```

Quote paths containing spaces. Relative paths supplied at the prompt or on the
command line are resolved from your current directory.

The script starts the server on `127.0.0.1:8080`, waits for the model to load,
and reviews the report in small batches. All report text is retained. Each batch's
analysis and elapsed time are printed as it finishes, so results are available
before the entire report has been processed. The server stays loaded between
batches. Repeated certificate descriptions within a batch are stored once in a
reference legend; paths, signature statuses, and certificate details remain
available to the model. These optimizations apply to all supported GGUF chat
models. It stops the server on completion, failure, or Ctrl+C. Server diagnostics are saved to
`data/llama-server.log`, which is replaced on each server launch.

### Command examples

The examples below prompt for model and server paths when they are not supplied.
You can add `--model PATH` and `--server PATH` to any of them.

| Goal | Command | What changes |
| --- | --- | --- |
| Standard review | `py .\llm.py` | Uses the default batch and context settings. |
| Shorter wait per batch | `py .\llm.py --batch-size 3000` | Sends less input per request; there will be more batches. |
| Longer answers | `py .\llm.py --max-tokens 2048` | Allows more output per batch and may take longer. |
| Extra model reasoning | `py .\llm.py --thinking --max-tokens 4096` | Enables thinking where supported and increases the response budget. |
| More time for slow hardware | `py .\llm.py --startup-timeout 600 --timeout 1200` | Allows 10 minutes to load and 20 minutes per analysis request. |
| A different local port | `py .\llm.py --port 8081` | Starts a new server on port 8081. |
| A saved text report | `py .\llm.py --report "C:\Scans\report.txt"` | Reviews the supplied report instead of the project's default. |

`--report` expects UTF-8 text, optionally with a byte-order mark. To review a
scan JSON file in the usual format, generate its human-readable report first.

### Options

| Option | Purpose | Default |
| --- | --- | --- |
| `-h`, `--help` | Show usage and available options without starting the server | — |
| `--model PATH` | Local chat/instruct GGUF model | Prompted |
| `--server PATH` | llama.cpp server executable | Detected or prompted |
| `--report PATH` | Text report to analyze | Project's `data/report.txt` |
| `--port N` | Local server port | `8080` |
| `--ctx-size N` | Context size in tokens | `8192` |
| `--max-tokens N` | Maximum response length per batch in tokens | `1024` |
| `--batch-size N` | Maximum UTF-8 report bytes per batch | `6000` |
| `--full-report` | Send the entire report in one request | Off |
| `--thinking` | Enable extra reasoning in models that support it | Off |
| `--yarn-orig-ctx N` | Enable YaRN extension from the model's native context size | Not overridden |
| `--startup-timeout N` | Model loading timeout in seconds | `300` |
| `--timeout N` | Analysis request timeout per batch in seconds | `600` |

`--max-tokens` must be smaller than `--ctx-size` to leave room for the report.
Run `py .\llm.py --help` to view the command-line reference.

In batch mode, leave at least 2048 tokens between `--ctx-size` and
`--max-tokens`. The script further reduces the requested batch size when necessary
to reserve space for instructions and the response. Port numbers must be between
1 and 65535; sizes and timeout values must be positive integers.

### Performance and quality

The default 8192-token context limits memory usage. Batches are capped further
when needed to reserve room for the prompt and response. Their byte size is a
conservative input budget, not an exact token count. Smaller batches can reduce
the wait for the first result; a complete review may still take several minutes.
Extra thinking is disabled through the model's chat template where supported.
Use `--thinking` when you prefer more reasoning at the cost of speed.

Batch reviews are independent: related commands and signatures may appear in
different batches, so results are not a combined verdict. Interrupted or failed
runs state how many batches completed and are marked incomplete. Earlier results
remain in the terminal.

#### Understand the three size settings

| Setting | Unit | What it controls |
| --- | --- | --- |
| `--batch-size` | UTF-8 bytes | How much original report text is included in each request. This is not a token count. |
| `--ctx-size` | Tokens | The space available for instructions, report input, and generated output. Larger values require more memory. |
| `--max-tokens` | Tokens | The upper limit on each response, including reasoning where the model counts it in the response budget. |

A character count is not a token count. Paths, punctuation, encoded commands,
and the model's tokenizer can all affect how many tokens a report needs.
Increasing `--max-tokens` does not fix an input-context error. Increasing
`--ctx-size` makes more text fit, but does not make that text faster to process.

#### What the faster workflow preserves

- Every part of the source report is submitted; entries are not removed because
  they appear ordinary or lack a rule match.
- The splitter prefers finding boundaries and then line boundaries. Unusually
  long entries can span batches, but their text is retained.
- Repeated certificate descriptions are replaced with references to exact text
  in the same request. This reduces repetition without dropping certificate details.
- The model receives the batch number and section context. Its instructions
  distinguish observations from guesses and warn against treating missing
  cross-batch information as evidence of safety or a missing signature.

The script does not automatically merge batch answers into a final assessment.
Check related findings against the original report, especially when a command
and its signature appear in different batches. Enabling `--thinking` requests
additional reasoning; its effect depends on the model and chat template and does
not guarantee a more accurate answer.

#### Read the progress log

| Log text | Meaning |
| --- | --- |
| `Loading ...` | The server is loading the selected model. |
| `Analyzing batch 3/16` | The third request is in progress. |
| `prompt processing ... progress = 0.44` | The server has processed about 44% of the current request's input; it has not necessarily started answering. |
| `n_gen` or `eval time` | The server is generating output or reporting generation timings. |
| `cancel task` | A request was cancelled. This line alone does not establish whether the cause was interruption, a disconnected client, or a timeout. |
| `review is incomplete` | The run stopped before every batch completed; earlier results cover only completed batches. |

Responses appear when each batch finishes, rather than token by token. To watch
the server's progress in a second PowerShell window, run this from the project
directory after the log has been created:

```powershell
Get-Content .\data\llama-server.log -Tail 25 -Wait
```

Pressing Ctrl+C in this second window stops the log viewer, not the analysis.

<details>
<summary><strong>Measured example: one batch of a large report</strong></summary>

During local validation, a 90,924-character report split into 16 batches.
Factoring repeated certificate descriptions reduced the combined report payload
from 90,929 to 76,626 UTF-8 bytes, excluding request instructions and batch labels.

With Qwen3-14B-Q4_K_M on an AMD Radeon RX 6800 XT, one 5901-character batch
completed in approximately 21 seconds after approximately 7 seconds of model
loading. That request processed 2081 input tokens and generated 632 output tokens.
The complete 16-batch run was not benchmarked. This is one observed result, not a
speed guarantee for other models, reports, or hardware.

</details>

### Full-report review and extended context

`--full-report` disables splitting and sends all report content in one request,
while retaining certificate compaction. This allows the model to consider the
report together, but can substantially increase memory usage and time to the
first answer. The context must fit the input, instructions, and desired response.

To review a large report in a single request with **Qwen3-14B**, use a larger
context and YaRN extension beyond its native 32,768 tokens:

```powershell
py .\llm.py --full-report --ctx-size 65536 --yarn-orig-ctx 32768 --max-tokens 8192
```

This passes a YaRN scaling factor of 2 to the server and uses more memory. A single
large prompt can take substantially longer to process before any answer appears.
Use this option only for models that support YaRN, with their correct native
context size. See the [Qwen model card](https://huggingface.co/Qwen/Qwen3-14B)
and [Qwen's llama.cpp guidance](https://qwen.readthedocs.io/en/latest/run_locally/llama.cpp.html).

This example is specific to Qwen3-14B. For another model, use its documented
context limits and extension settings. The ordinary batch workflow works across
supported chat models and usually does not require context extension.

### Stopping and saving output

Press **Ctrl+C in the terminal running `llm.py`** to cancel a review. The script
stops its server and reports the number of completed batches. It does not modify
the source report or model file. A new run starts from the beginning; automatic
resume is not implemented.

If the process is unresponsive, use Task Manager to end the specific
`llama-server.exe` process. Ending inference does not damage the GPU; the operating
system reclaims the process's GPU memory. The current response is lost, and
`llm.py` may report a connection error.

Analysis is printed to the terminal and is not automatically saved to a separate
file. To display it and save a copy, use PowerShell's `Tee-Object`:

```powershell
py -u .\llm.py --server "C:\llama.cpp\llama-server.exe" --model "C:\Models\model.gguf" 2>&1 | Tee-Object -FilePath .\data\llm_analysis.txt
```

This captures status messages, analysis, and errors. The destination is replaced
on each run; choose a different filename to preserve an earlier review. The
`data` directory must already exist, as it does after generating the scan report.
The server log is a separate diagnostic file and is also replaced on launch.

### Troubleshooting

| Issue | Action |
| --- | --- |
| Report missing or empty | Run `py .\main.py`, or supply an existing non-empty report with `--report PATH`. |
| Server executable not found | Supply its full path with `--server PATH` and keep its DLLs alongside it. |
| Startup exits with `3236495362` (`0xC0E90002`) | Windows Code Integrity blocked the executable or a DLL. Check event 3077 under Event Viewer → Applications and Services Logs → Microsoft → Windows → CodeIntegrity → Operational to identify the file. Use a trusted server distribution accepted by your Windows policy, or ask your administrator to review the package. The server log may be empty; changing the GGUF model or context size does not resolve this block. |
| Port unavailable | Select another port, for example `--port 8081`. |
| Model loading fails or times out | Review `data/llama-server.log`; check model compatibility and available memory. Increase `--startup-timeout` if loading is slow. |
| Report exceeds the context size | Increase `--ctx-size` within the model's supported limits and available memory, or supply a smaller report. |
| Long wait while processing the prompt | Use the default batch mode, reduce `--batch-size`, and leave `--thinking` off. Increasing the context size alone does not make processing faster. |
| Response reaches the token limit or generation times out | Increase `--max-tokens` within the context budget, or increase `--timeout`, as appropriate. |
| `py` or `python` is not recognized, or opens Microsoft Store | Check your Python installation and launcher. Try `py --version` or `python --version`, then use the working command consistently. |
| A path with spaces cannot be found | Quote the complete path. Confirm it points to the file, not its containing directory. |
| `--max-tokens` leaves too little context | Reduce the response limit or increase context within the model's limits. Batch mode requires at least 2048 tokens beyond the response budget. |
| `--yarn-orig-ctx` is rejected | The requested context must exceed the native context supplied for YaRN. For normal batch mode, omit the YaRN option. |
| Model returns no analysis or an invalid response | Confirm the GGUF is a supported chat/instruct model. For models with thinking enabled, allow enough response tokens for both reasoning and the answer, or retry without `--thinking`. |
| Unsupported server option, such as `--jinja` | Check that the executable is a compatible llama.cpp server build. Review its `--help` output and the server log. |
| Server exits or connection closes during analysis | Check the server log and whether the process was stopped. An interrupted request is not a completed review. |
| Scanner reports access errors | Review the `errors` entries and use an account with appropriate access to those locations. Other findings may still be available. |
| Log mentions a future default port change | Phoenix passes an explicit port, so that notice does not change its configured port. |

Treat the analysis as a review aid. Verify its claims against the report and the
system before drawing conclusions.

For details on Windows policy blocks, see Microsoft's
[App Control event reference](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/operations/event-id-explanations).

### Checking server downloads

A Windows signing-policy block is not, by itself, a malware verdict. Verify the
package's source before deciding whether to trust it. Prefer the project's
official releases, keep the package's executable and DLLs together, and compare
checksums with those published for the exact release when available.

To calculate a file's SHA-256 hash and inspect its Windows signing status:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath "C:\llama.cpp\ggml-base.dll"
Get-AuthenticodeSignature -LiteralPath "C:\llama.cpp\ggml-base.dll"
```

Compare like with like: a ZIP archive's hash will not match the hash of a DLL
inside it. Matching an official file confirms that the bytes match that release;
it does not guarantee the software is free of vulnerabilities or malware. An
unknown reputation result also does not establish safety.

For error `0xC0E90002`, event 3077 identifies the executable or DLL blocked by
Windows Code Integrity. Smart App Control has no per-app allow exception. A
trusted package accepted by the active policy, or administrator review of a
managed policy, is the preferred resolution. Turning Smart App Control off affects
protection across the PC and is not required by Phoenix. Microsoft documents the
available settings and re-enabling requirements in its
[Smart App Control FAQ](https://support.microsoft.com/en-us/windows/security/threat-malware-protection/smart-app-control-frequently-asked-questions).

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

Set a check to `false` to skip it. Relative output paths are resolved from the project directory; absolute paths are used as supplied. The current runner writes JSON output.
Use `drivers_scan` to control the driver check. Checks omitted from the configuration are skipped.

## Understanding the output

The report has two top-level arrays:

- `results` contains discovered entries.
- `errors` contains locations or checks that could not be read, plus other per-check issues.

Each finding also gets a `risk` object from `risk_rules.rules_checker(finding)`.
The starter rules flag known LOLBin executable names and PowerShell `-enc` /
`-EncodedCommand` switches for review. The LOLBin list is based on
[LOLBAS](https://lolbas-project.github.io/) and is intentionally small.
These are heuristics: legitimate commands can match, and no match does not prove
safety. The rules inspect the first executable; they do not parse nested shells,
resolve shortcut targets, or detect renamed binaries or obfuscation.

To add a rule, write a function in `risk_rules.py` that accepts one finding and
returns a list of reasons (or `[]` for no match), then add it to `RULES`.
`main.py` already calls the checker before saving. Importing the module alone
does not run the rules. Optional signature results can be supplied as the second
argument; they must belong to that finding. The scanner currently runs only the
command rules, so unmatched findings stay `unknown`. The report shows signature
results separately; even a `clean` signature-only assessment is not proof of safety.

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
main.py                 Scanner and report workflow
config.json             Check toggles and JSON output path
Windows/                PowerShell checks and shared finding class
report_generator.py     Human-readable report and Authenticode checks
risk_rules.py           Command-rule assessments
llm.py                  Optional local GGUF model analysis
requirements.txt        Python dependency notes
tests/                  Regression tests
data/scan_results.json  Structured scan results
data/report.txt         Human-readable scan report
data/risk_report.txt    Timestamped command-rule results
data/llama-server.log   Diagnostics from the latest local server launch
data/llm_analysis.txt   Optional terminal capture created with Tee-Object
```

## Current limitations

- Phoenix currently supports Windows only.
- Risk labels are heuristic review hints, not malware verdicts; signature checks remain a separate report step.
- Recent-file filtering is not implemented.
- Startup-folder entries are listed as files; shortcut targets are not resolved.
- Results depend on the current account's permissions and Windows environment.
- Local model analysis requires a compatible GGUF model and sufficient memory; large reports may exceed the configured context size.
- Batch analysis does not automatically combine findings across requests into a final assessment.
- Cancelled reviews cannot be resumed automatically; rerunning starts a new review.

## Contributing

Run the regression tests with `py -m unittest discover -s tests -v`. They are
not part of the scanner workflow; they are repeatable checks for developers.
PowerShell integration tests run on Windows and are skipped when PowerShell is unavailable.

Bug reports and focused improvements are welcome. When adding a check, keep it read-only, emit the shared finding fields, include per-check errors in the JSON response, and document any platform or permission requirements.

---

<div align="center">

Made for defensive system inspection · Phoenix Persistence Scanner

</div>
