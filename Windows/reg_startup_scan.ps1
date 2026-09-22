# note this is unfinished code DEBUGGING WILL BE NEED DO NOT RUN!
# todo fix bugs.



[CmdletBinding()]
param()

$results = @()
$errors = @()

$Registry_Startup_RunKeys = @(
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run",
    "Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run"
)

foreach ($item in $Registry_Startup_RunKeys) {
    if (Test-Path $item) {
        try {
            $registry_content_item = Get-Item -Path $item
            if ($registry_content_item.Property.Count -gt 0) {
                foreach ($property in $registry_content_item.Property) {
                    $commandValue = $registry_content_item.GetValue($property)
                    $results += [PSCustomObject]@{
                        type     = "registry_run_key"
                        name     = $property
                        location = $item
                        command  = $commandValue
                        enabled  = $true
                        evidence = @{
                            hive = $item
                        }
                    }
                }
            }
        }
        catch {
            $errors += [PSCustomObject]@{
                location = $item
                message  = $_.Exception.Message
            }
        }
    }
    else {
        $errors += [PSCustomObject]@{
            location = $item
            message  = "Registry path not found."
        }
    }
}

[PSCustomObject]@{
    check   = "registry_run_keys"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5

$outputDir = "/../data" # bad practice uwu but attmepting to save results to dir
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$outputPath = "$outputDir/scan_results.json"

[PSCustomObject]@{
    check   = "registry_run_keys"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5 | Set-Content -Path $outputPath

Write-Host "Results successfully saved to $outputPath" -ForegroundColor Green