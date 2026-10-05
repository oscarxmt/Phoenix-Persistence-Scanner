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
    try {
        if (Test-Path -LiteralPath $item -ErrorAction Stop) {
            $key = Get-Item -LiteralPath $item -ErrorAction Stop
            foreach ($property in $key.Property) {
                try {
                    $commandValue = $key.GetValue($property)
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
    } catch {
        $errors += [PSCustomObject]@{
            location = $item
            message = $_.Exception.Message
        }
    }
}

[PSCustomObject]@{
    check   = "registry_run_once_key"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5

