[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")


$registry_content_item = @(
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run",
    "Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"
)

foreach($item in $registry_content_item) {
    if (Test-Path $item) {
        try {
            $registry_policies_run = Get-Item -Path $item
            if ($registry_policies_run.Property.Count -gt 0){
                    foreach ($property in $registry_content_item.Property) {
                        $commandValue = $registry_content_item.GetValue($property)
                        $results += [ScanFinding]::new("registry_run_key", $property, $item, $commandValue, $true, @{ hive = $item })
                }

            }
        }
        catch{
            $errors += [PSCustomObject]@{
            location = $item
            message  = $_.Exception.Message
            }
        }
    }
    else {
        $errors += [PSCustomObject]@{
            location = $item
            message = "Registry group policy keys not found. You are likely not on a corporate computer!"
        }
    }
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

[PSCustomObject]@{
    check   = "group_policy_run_keys"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5