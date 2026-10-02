[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")

# NOTE UNFINISHED WILL NEED TO ADD MORE STUFF :3
#Get-ChildItem -Path "HKCU:\Software\Classes\CLSID"


if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}
[PSCustomObject]@{
    check   = "com_hjiacking"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5