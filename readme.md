# Phoenix Persistence Scanner

Phoenix is a Windows persistence-scanning project. It currently keeps the
existing PowerShell checks and uses Python to load configuration and run them.

## Current status

Currently wired checks:

- Registry Run and RunOnce locations
- Windows startup folders

The scheduled-task, service, and WMI checks in `config.json` are planned but
are not wired up yet.

## Usage

Run from any directory with:

```text
python C:\path\to\Phoenix-Persistance-Scanner\main.py
```

Phoenix resolves its configuration and PowerShell scripts relative to the
project, so the current working directory does not matter.

## Project structure

```text
main.py                 Compatibility entry point
Windows/                PowerShell scanner checks
config.json             Check configuration
```

Phoenix is currently read-only. It does not delete, disable, or execute any
discovered persistence entries.
