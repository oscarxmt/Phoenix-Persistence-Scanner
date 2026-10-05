[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")

try {
    $drivers = Get-CimInstance -ClassName Win32_SystemDriver -ErrorAction Stop |
        Where-Object { $_.StartMode -in @("Boot", "System", "Auto") }
    foreach ($driver in $drivers) {
        $results += [ScanFinding]::new(
            "Driver", $driver.Name, "HKLM:\SYSTEM\CurrentControlSet\Services\$($driver.Name)",
            $driver.PathName, $true, @{ start_mode = $driver.StartMode; active = $driver.State }
        )
    }
} catch {
    $errors += [PSCustomObject]@{
        location = "Win32_SystemDriver"
        message = "Could not enumerate drivers: $($_.Exception.Message)"
    }
}

[PSCustomObject]@{
    check = "drivers"
    results = @($results)
    errors = @($errors)
} | ConvertTo-Json -Depth 5
