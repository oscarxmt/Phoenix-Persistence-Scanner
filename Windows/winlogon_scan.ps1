[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")

$paths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon",
    "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Winlogon"
)
foreach ($item in $paths) {
    try {
    if (Test-Path $item) {
        $winlogonValue = (Get-ItemProperty -Path $item -Name "AppInit_DLLs" -ErrorAction Stop).AppInit_DLLs
        if ($winlogonValue) {
            $results += [ScanFinding]::new("winlogon", "Winlogon_registry", $item, $winlogonValue, $true, @{ hive = $item })
        }
        else{
            $errors += [PSCustomObject]@{
                location = $item
                message = "Winlogon present but empty."
            }
        }
    }
    else {
        $errors += [PSCustomObject]@{
            location = $item
            message = "Registry key path not found."
        }
    }
    }
    catch {
        $errors += [PSCustomObject]@{
            location = $item
            message = "Could not read Winlogon values: $($_.Exception.Message)"
        }
    }
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

[PSCustomObject]@{
    check   = "winlogon_scan"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5
