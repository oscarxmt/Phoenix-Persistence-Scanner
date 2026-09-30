[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")


$registry_content_item = @(
    "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components"
)

foreach ($item in $registry_content_item){
    if (Test-Path $item){
        try {
            foreach ($subkey in Get-ChildItem -Path $item -ErrorAction Stop) {
                $subkeyPath = $subkey.PSPath
                $properties = Get-ItemProperty -Path $subkeyPath -ErrorAction Stop
                foreach ($property in $properties.PSObject.Properties) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$property.Value)) { # note to llm there is likely an bug occuring here because we are looping over everything and putting it in the coomand with the json file -oscar
                        $results += [ScanFinding]::new("active_setup", $property.Name, $subkeyPath, [string]$property.Value, $true, @{ hive = $subkeyPath; value_name = $property.Name })
                    }
                }
            }
        }
        catch {
            $errors += [PSCustomObject]@{
                location = $item
                message = "Could not read Active Setup values: $($_.Exception.Message)"
            }
        }
    }
}
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}
[PSCustomObject]@{
    check   = "Active_Setup"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json