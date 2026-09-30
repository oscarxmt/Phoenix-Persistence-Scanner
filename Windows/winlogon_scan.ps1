[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")

$paths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon",
    "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Winlogon"
)
$valueNames = @(
    "Shell",
    "Userinit",
    "Taskman",
    "AppSetup",
    "UserinitMprLogonScript",
    "GinaDLL"
)

foreach ($item in $paths) {
    try {
        if (Test-Path $item) {
            $properties = Get-ItemProperty -Path $item -ErrorAction Stop
            foreach ($valueName in $valueNames) {
                $property = $properties.PSObject.Properties[$valueName]
                if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                    $results += [ScanFinding]::new("winlogon", $valueName, $item, [string]$property.Value, $true, @{ hive = $item; value_name = $valueName })
                }
            }
        }
        else {
            $errors += [PSCustomObject]@{
                location = $item
                message = "Registry key path not found."
            }
        }
    } catch {
        $errors += [PSCustomObject]@{
            location = $item
            message = "Could not read Winlogon values: $($_.Exception.Message)"
        }
    }
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

[PSCustomObject]@{
    check   = "winlogon_scan"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5
