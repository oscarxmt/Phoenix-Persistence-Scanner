[CmdletBinding()]
param()

$results = @()
$errors = @()

$currentUserStartupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$allUsersStartupPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"

if (Test-Path $currentUserStartupPath) {
    $Current_User_Startup = Get-ChildItem -Path $currentUserStartupPath
}
else {
    $Current_User_Startup = @()
    $errors += [PSCustomObject]@{
        location = $currentUserStartupPath
        message  = "Current user startup folder not found."
    }
}

if (Test-Path $allUsersStartupPath) {
    $All_Users_Startup = Get-ChildItem -Path $allUsersStartupPath
}
else {
    $All_Users_Startup = @()
    $errors += [PSCustomObject]@{
        location = $allUsersStartupPath
        message  = "All users startup folder not found."
    }
}

foreach ($item in $Current_User_Startup) {
    $results += [PSCustomObject]@{
        type     = "startup_folder"
        name     = $item.Name
        location = $item.FullName
        command  = $null
        enabled  = $true
        evidence = @{
            extension = $item.Extension
        }
    }
}

foreach ($item in $All_Users_Startup) {
    $results += [PSCustomObject]@{
        type     = "startup_folder"
        name     = $item.Name
        location = $item.FullName
        command  = $null
        enabled  = $true
        evidence = @{
            extension = $item.Extension
        }
    }
}

[PSCustomObject]@{
    check   = "startup_folders"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5