[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")

$Services_List = Get-CimInstance -ClassName Win32_Service | Where-Object { $_.StartMode -eq "Auto" } | Select-Object Name, PathName, StartMode, State

if(-not (Test-Path $outputDir)) {
    Write-Host "[!] Could not find output directory. "
}

foreach($svc in $Services_List) {
    try {
        $type = "Service"
        $name = $svc.Name
        $location = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)"
        $command = $svc.PathName
        $enabled = $svc.StartMode -eq "Auto"
        $evidence = @{ active = $svc.State }
        $results += [ScanFinding]::new($type, $name, $location, $command, $enabled, $evidence)
    }
    catch {
            write-host $_.Exception.Message
    }
}


[PSCustomObject]@{
    check   = "services"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5