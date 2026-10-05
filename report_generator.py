import json
import re
import subprocess
from pathlib import Path
from collections import defaultdict
from main import json_config, output_path

BASE_DIR = Path(__file__).resolve().parent
REPORT_PATH = BASE_DIR / "data" / "report.txt"

EXTENSIONS = "exe|dll|sys|ocx|scr|cpl|drv|efi|cat|ps1|psm1|psd1|msi|msp"
PATH_PATTERN = re.compile(
    rf"""["'](?P<quoted>(?:[A-Za-z]:\\|\\\\|%[^%]+%\\)[^"']+?\.(?:{EXTENSIONS}))["']"""
    rf"""|(?P<unquoted>(?:[A-Za-z]:\\|\\\\|%[^%]+%\\)[^"'<>|\r\n]*?\.(?:{EXTENSIONS}))(?=$|[\s"',;])""",
    re.IGNORECASE,
)


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


def verify_binaries(data=None):
    if data is None:
        with output_path(json_config()).open("r", encoding="utf-8") as f:
            data = json.load(f)

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
    for text in strings_in(data.get("results", [])):
        for match in PATH_PATTERN.finditer(text):
            path = match.group("quoted") or match.group("unquoted")
            binary_paths.setdefault(path.casefold(), path)

    if not binary_paths:
        return []

    powershell_script = r"""
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$securityModule = Join-Path $PSHOME "Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1"
Import-Module -Name $securityModule -ErrorAction Stop
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
            [PSCustomObject]@{ original_path = $path; path = $resolvedPath; error = "File does not exist" }
            continue
        }
        $signature = Get-AuthenticodeSignature -LiteralPath $resolvedPath -ErrorAction Stop
        [PSCustomObject]@{
            original_path = $path
            path = $resolvedPath
            status = $signature.Status.ToString()
            signer = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
            message = $signature.StatusMessage
        }
    } catch {
        [PSCustomObject]@{ original_path = $path; path = $resolvedPath; error = $_.Exception.Message }
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
    with output_path(json_config()).open("r", encoding="utf-8") as f:
        data = json.load(f)

    findings = data["results"]

    grouped = defaultdict(list)
    for finding in findings:
        grouped[finding["type"]].append(finding)

    try:
        binary_signatures = verify_binaries(data)
    except (OSError, RuntimeError) as error:
        binary_signatures = []
        data.setdefault("errors", []).append({"check": "binary_signatures", "message": str(error)})

    report_lines = []
    for scan_type, items in grouped.items():
        report_lines.append(f"\n=== {scan_type} ({len(items)} findings) ===\n")
        for finding in items:
            report_lines.append(f"  - {format_finding(finding)}\n")
            if finding.get("risk") and finding["risk"].get("verdict") == "suspicious":
                risk = finding["risk"]
                report_lines.append(f"    Risk: {risk['verdict']}\n")
                report_lines.extend(
                    f"      - {reason}\n"
                    for reason in risk.get("reasons", [])
                    if reason != "No binary signatures were checked"
                )

    if binary_signatures:
        report_lines.append(
            f"\n=== Binary signatures ({len(binary_signatures)} files) ===\n"
        )
        report_lines.extend(
            f"{format_signature(signature)}\n" for signature in binary_signatures
        )
    if data.get("errors"):
        report_lines.append(f"\n=== Scan errors ({len(data['errors'])}) ===\n")
        for error in data["errors"]:
            location = error.get("check") or error.get("location") or "Unknown check"
            report_lines.append(f"  - {location}: {error.get('message', 'Unknown error')}\n")
    print("[!] Writing report to file... This may take a while if there are many findings.")
    report = "".join(report_lines)    
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(report, encoding="utf-8")
    print(report, end="")
    print(f"Report written to {REPORT_PATH}")


if __name__ == "__main__":
    main()
