[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")

$Registry_Startup_RunKeys = @(
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)
if ([Environment]::Is64BitOperatingSystem) {
    $Registry_Startup_RunKeys += "Registry::HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
}
foreach($item in $Registry_Startup_RunKeys) {
    
    if (Test-Path $item) {
        foreach ($property in (Get-Item -Path $item).Property) {
            try {
                $commandValue = (Get-Item -Path $item).GetValue($property)
                $results += [ScanFinding]::new("registry_run_once_key", $property, $item, $commandValue, $true, @{ hive = $item })

            }
            catch {
                $errors += [PSCustomObject]@{
                    location = $item
                    message  = $_.Exception.Message
                }
            }
        }
    }
    else {
        $errors += [PSCustomObject]@{
            location = $item
            message  = "Registry RunOnce paths not found."
        }
    }
}

[PSCustomObject]@{
    check   = "registry_run_once_key"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5

