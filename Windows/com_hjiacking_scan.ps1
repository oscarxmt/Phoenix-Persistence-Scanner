[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")

# NOTE FINISHED THIS WAS HARD :)
$registry_content = Get-ChildItem -Path "HKCU:\Software\Classes\CLSID"
foreach ($guid in $registry_content){
    foreach ($serverType in "InprocServer32", "LocalServer32") {
        try {
            $serverPath = "$($guid.PSPath)\$serverType"
            if (Test-Path $serverPath) { 
                $server  = Get-Item $serverPath
                $dllPath = $server.GetValue("")
                $results += [ScanFinding]::new("com_hijacking", $guid.PSChildName, $server.PSPath, $dllPath, $true, 
                    @{ 
                        hive = $server.PSPath 
                        value_name = "(default)"
                        server_type = $serverType
                        file_exists = ([bool]$dllPath -and (Test-Path $dllPath))
                        hklm_override = (Test-Path "HKLM:\Software\Classes\CLSID\$($guid.PSChildName)")        
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