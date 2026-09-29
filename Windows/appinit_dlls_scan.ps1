[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")


$registry_content_item = @(
    "Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Windows",
    "Registry::HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Windows",
    "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\Windows"
)


foreach ($item in $registry_content_item) {
    try {
    if (Test-Path $item) {
        $dllValue = (Get-ItemProperty -Path $item -Name "AppInit_DLLs" -ErrorAction Stop).AppInit_DLLs
        if (-not [string]::IsNullOrWhiteSpace($dllValue)) {
            $results += [ScanFinding]::new("appinit_dlls", "AppInit_DLLs", $item, $dllValue, $true, @{ hive = $item })
        }
        else{
            $errors += [PSCustomObject]@{
                location = $item
                message = "AppInit_DLLs present but empty."
            }
        }
    }
    else {
        $errors += [PSCustomObject]@{
            location = $item
            message = "Registry key path not found."
        }
    }
    }
    catch {
        $errors += [PSCustomObject]@{
            location = $item
            message = "No DLLS set."
        }
    }
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

[PSCustomObject]@{
    check   = "appinit_dlls_scan"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5
