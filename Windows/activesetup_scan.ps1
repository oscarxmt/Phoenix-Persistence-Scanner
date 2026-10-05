[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")

$registryPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components"

try {
    if (Test-Path -LiteralPath $registryPath -ErrorAction Stop) {
        foreach ($key in Get-ChildItem -LiteralPath $registryPath -ErrorAction Stop) {
            try {
                $keyPath = $key.PSPath
                $stubPath = $key.GetValue("StubPath", $null)
                $version  = $key.GetValue("Version", $null)
                $name     = $key.GetValue("(LocalizedName)", $null)
                $installed = $key.GetValue("IsInstalled", $null)

                if (-not [string]::IsNullOrWhiteSpace([string]$stubPath)) {
                    $results += [ScanFinding]::new("active_setup", "StubPath", $keyPath, [string]$stubPath, $true,
                        @{
                            hive         = $keyPath
                            value_name   = "StubPath"
                            version      = [string]$version
                            localized_name = [string]$name
                            is_installed = $installed
                        }
                    )
                }
            }
            catch {
                $errors += [PSCustomObject]@{
                    location = $key.PSPath
                    message  = "Could not read Active Setup key: $($_.Exception.Message)"
                }
            }
        }
    }

} catch {
    $errors += [PSCustomObject]@{
        location = $registryPath
        message = "Could not enumerate Active Setup keys: $($_.Exception.Message)"
    }
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}
[PSCustomObject]@{
    check   = "Active_Setup"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5
