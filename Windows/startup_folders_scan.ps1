[CmdletBinding()]
param()

$results = @()
$errors = @()

# Known folders respect redirected profiles and relocated ProgramData folders.
$startupPaths = @(
    [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup),
    [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonStartup)
)

foreach ($path in $startupPaths) {
    try {
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -ErrorAction Stop)) {
            throw "Startup folder not found."
        }
        foreach ($item in Get-ChildItem -LiteralPath $path -File -Force -ErrorAction Stop) {
            $results += [PSCustomObject]@{
                type     = "startup_folder"
                name     = $item.Name
                location = $item.FullName
                command  = $null
                enabled  = $true
                evidence = @{ extension = $item.Extension }
            }
        }
    } catch {
        $errors += [PSCustomObject]@{
            location = $path
            message = "Could not read startup folder: $($_.Exception.Message)"
        }
    }
}

[PSCustomObject]@{
    check   = "startup_folders"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5
