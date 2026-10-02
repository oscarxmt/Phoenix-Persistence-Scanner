[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")


foreach ($item in Get-ChildItem -Path "HKCU:\Software\Classes\CLSID" -Recurse | Where-Object {$_.Name -match 'InprocServer32|LocalServer32|TreatAs'} | Select-Object Name, @{n="PayloadPath";e={(Get-ItemProperty $_.PSPath).'(default)'}} | Format-List) {
    # Unfinished code snippet, will update it here no woories :3 just pls dont run it right now
}


if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}
[PSCustomObject]@{
    check   = "Active_Setup"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5