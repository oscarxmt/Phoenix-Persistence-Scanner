[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")

# NOTE FINISHED THIS WAS HARD :)
$registry_content = @()
try {
    $registry_content = @(Get-ChildItem -LiteralPath "HKCU:\Software\Classes\CLSID" -ErrorAction Stop)
} catch {
    $errors += [PSCustomObject]@{
        location = "HKCU:\Software\Classes\CLSID"
        message = "Could not enumerate COM keys: $($_.Exception.Message)"
    }
}
foreach ($guid in $registry_content){
    foreach ($serverType in "InprocServer32", "LocalServer32") {
        try {
            $serverPath = "$($guid.PSPath)\$serverType"
            if (Test-Path -LiteralPath $serverPath -ErrorAction Stop) {
                $server  = Get-Item -LiteralPath $serverPath -ErrorAction Stop
                $dllPath = $server.GetValue("")
                $filePath = [Environment]::ExpandEnvironmentVariables([string]$dllPath).Trim()
                if ($serverType -eq "LocalServer32") {
                    $serverExecutable = [string]$server.GetValue("ServerExecutable")
                    if (-not [string]::IsNullOrWhiteSpace($serverExecutable)) {
                        $filePath = [Environment]::ExpandEnvironmentVariables($serverExecutable).Trim().Trim('"')
                    } elseif ($filePath -match '^"([^"]+)"') {
                        $filePath = $Matches[1]
                    } elseif ($filePath -match '^(.*?\.exe)(?=\s|$)') {
                        $filePath = $Matches[1]
                    } elseif ($filePath -match '^(\S+)') {
                        $filePath = $Matches[1]
                    }
                } else {
                    $filePath = $filePath.Trim('"')
                }
                $results += [ScanFinding]::new("com_hijacking", $guid.PSChildName, $server.PSPath, $dllPath, $true, 
                    @{ 
                        hive = $server.PSPath 
                        value_name = "(default)"
                        server_type = $serverType
                        file_path = $filePath
                        file_exists = ([bool]$filePath -and (Test-Path -LiteralPath $filePath -PathType Leaf -ErrorAction Stop))
                        hklm_override = (Test-Path -LiteralPath "HKLM:\Software\Classes\CLSID\$($guid.PSChildName)" -ErrorAction Stop)
                    }
                )
            }
        }
        catch{
            $errors += [PSCustomObject]@{
                location = $guid.PSPath
                message = "Could not read COM key: $($_.Exception.Message)"
            }
        }
    }
}


if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}
[PSCustomObject]@{
    check   = "com_hijacking"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5
