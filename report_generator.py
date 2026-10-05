import json
import re
import subprocess
from pathlib import Path
from collections import defaultdict

BASE_DIR = Path(__file__).resolve().parent
RESULTS_DIR = BASE_DIR / "data" / "scan_results.json"
REPORT_PATH = BASE_DIR / "data" / "report.txt"

# CODE DOESNT WORK DO NOT RUN CURRENTLY
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


def format_signature(signature):
    path = signature["path"]
    if "error" in signature:
        return f"  - ERROR: {path} - {signature['error']}"

    status = signature.get("status", "Unknown")
    if status == "Valid":
        label = "SIGNED"
    elif status == "NotSigned":
        label = "UNSIGNED"
    else:
        label = status.upper()

    signer = signature.get("signer") or "no signer certificate"
    message = signature.get("message") or ""
    details = f" ({signer})"
    if message:
        details += f" - {message}"
    return f"  - {label} ({status}): {path}{details}"


def verify_binaries():
    with RESULTS_DIR.open("r", encoding="utf-8") as f:
        data = json.load(f)

    extensions = "exe|dll|sys|ocx|scr|cpl|drv|efi|cat|ps1|psm1|psd1|msi|msp"
    path_pattern = re.compile(
        rf"""["'](?P<quoted>(?:[A-Za-z]:\\|\\\\|%[^%]+%\\)[^"']+?\.(?:{extensions}))["']"""
        rf"""|(?P<unquoted>(?:[A-Za-z]:\\|\\\\|%[^%]+%\\)[^"'<>|\r\n]*?\.(?:{extensions}))""",
        re.IGNORECASE,
    )

    def strings_in(value):
        if isinstance(value, str):
            yield value
        elif isinstance(value, dict):
            for nested_value in value.values():
                yield from strings_in(nested_value)
        elif isinstance(value, list):
            for nested_value in value:
                yield from strings_in(nested_value)

    binary_paths = {}
    for text in strings_in(data):
        for match in path_pattern.finditer(text):
            path = match.group("quoted") or match.group("unquoted")
            binary_paths.setdefault(path.casefold(), path)

    if not binary_paths:
        return []

    powershell_script = r"""
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Import-Module Microsoft.PowerShell.Security -ErrorAction Stop
    $paths = @(
    foreach ($line in ([Console]::In.ReadToEnd() -split "`r?`n")) {
        if ($line) {
            ConvertFrom-Json -InputObject $line
        }
    }
)
$results = foreach ($path in $paths) {
    $resolvedPath = [Environment]::ExpandEnvironmentVariables([string]$path)
    try {
        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf -ErrorAction Stop)) {
            [PSCustomObject]@{ path = $path; error = "File does not exist" }
            continue
        }
        $signature = Get-AuthenticodeSignature -LiteralPath $resolvedPath -ErrorAction Stop
        [PSCustomObject]@{
            path = $resolvedPath
            status = $signature.Status.ToString()
            signer = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
            message = $signature.StatusMessage
        }
    } catch {
        [PSCustomObject]@{ path = $resolvedPath; error = $_.Exception.Message }
    }
}
ConvertTo-Json -InputObject @($results) -Depth 3 -Compress
"""
    completed = subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command", powershell_script],
        input="\n".join(json.dumps(path) for path in binary_paths.values()),
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            f"PowerShell signature check failed: {completed.stderr.strip() or completed.stdout.strip()}"
        )
    try:
        return json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("PowerShell returned invalid signature-check JSON") from error


def main():
    print("[!] Generating report...")
    with open(RESULTS_DIR, "r") as f:
        data = json.load(f)

    findings = data["results"]

    grouped = defaultdict(list)
    for finding in findings:
        grouped[finding["type"]].append(finding)

    binary_signatures = verify_binaries()

    report_lines = []
    for scan_type, items in grouped.items():
        report_lines.append(f"\n=== {scan_type} ({len(items)} findings) ===\n")
        for finding in items:
            report_lines.append(f"  - {format_finding(finding)}\n")

    if binary_signatures:
        report_lines.append(
            f"\n=== Binary signatures ({len(binary_signatures)} files) ===\n"
        )
        report_lines.extend(
            f"{format_signature(signature)}\n" for signature in binary_signatures
        )
    print("[!] Writing report to file... This may take a while if there are many findings.")
    report = "".join(report_lines)    
    REPORT_PATH.write_text(report, encoding="utf-8")
    print(report, end="")
    print(f"Report written to {REPORT_PATH}")


if __name__ == "__main__":
    main()