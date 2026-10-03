[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")

$registry_content = Get-CimInstance -ClassName Win32_SystemDriver | Format-Table Name, StartMode, PathName, State

foreach($item in $registry_content) {
    write-host $item
}