import json
import re
import subprocess
from pathlib import Path
from collections import defaultdict

BASE_DIR = Path(__file__).resolve().parent
RESULTS_DIR = BASE_DIR / "data" / "scan_results.json"
REPORT_PATH = BASE_DIR / "data" / "report.txt"


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
$paths = @(ConvertFrom-Json -InputObject ([Console]::In.ReadToEnd()))
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
        input=json.dumps(list(binary_paths.values())),
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
    with open(RESULTS_DIR, "r") as f:
        data = json.load(f)

    findings = data["results"]

    grouped = defaultdict(list)
    for finding in findings:
        grouped[finding["type"]].append(finding)

    binary_signatures = verify_binaries()

    with open(REPORT_PATH, "w") as out:
        for scan_type, items in grouped.items():
            out.write(f"\n=== {scan_type} ({len(items)} findings) ===\n")
            for finding in items:
                out.write(f"  - {format_finding(finding)}\n")

        if binary_signatures:
            out.write(f"\n=== Binary signatures ({len(binary_signatures)} files) ===\n")
            for signature in binary_signatures:
                if "error" in signature:
                    out.write(f"  - {signature['path']}: ERROR - {signature['error']}\n")
                else:
                    signer = signature.get("signer") or "no signer certificate"
                    out.write(
                        f"  - {signature['path']}: {signature['status']} "
                        f"({signer}) - {signature['message']}\n"
                    )

    print(f"Report written to {REPORT_PATH}")


if __name__ == "__main__":
    main()