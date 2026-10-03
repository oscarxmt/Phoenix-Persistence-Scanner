[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")

$registryPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"


try {
    if (Test-Path -LiteralPath $registryPath -ErrorAction Stop) {
        foreach ($key in @(Get-ChildItem -LiteralPath $registryPath -ErrorAction Stop)) {
        try {
            $keyPath = $key.PSPath
            $debugger = $key.GetValue("Debugger", $null)
            if ($null -ne $debugger -and $debugger -ne "") {
                $results += [ScanFinding]::new("ifeo", "Debugger", $keyPath, $debugger, $true,
                    @{
                        hive       = $keyPath
                        value_name = "Debugger"
                    }
                )
            }
        }
        catch {
            $errors += [PSCustomObject]@{
                location = $key.PSPath
                message  = "Could not read IFEO key: $($_.Exception.Message)"
            }
        }
        }
    }
} catch {
    $errors += [PSCustomObject]@{
        location = $registryPath
        message = "Could not enumerate IFEO keys: $($_.Exception.Message)"
    }
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

[PSCustomObject]@{
    check   = "image_file_execution_options"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5
