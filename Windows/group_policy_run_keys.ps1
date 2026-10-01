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
            $registryPoliciesRun = Get-Item -Path $item -ErrorAction Stop
            foreach ($property in $registryPoliciesRun.Property) {
                $commandValue = $registryPoliciesRun.GetValue($property)
                $results += [ScanFinding]::new("group_policy_run_key", $property, $item, [string]$commandValue, $true, @{ hive = $item })
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
            message = "Registry group policy Run key was not found."
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