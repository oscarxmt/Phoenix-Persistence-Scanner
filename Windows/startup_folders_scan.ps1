$currentdir = (Get-Location).Path

Write-Host "`n[*] Checking Scheduled Tasks..."

$user = $env:username 

$finalfilename = $user + "_ScheduledTask"

Write-Host "`n[*] Checking Startup Folders..."


if(test-path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup")
{
  $Current_User_Startup = Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
}
else
{
  write-host "[!] Current user startup folder not found."
}
if(test-path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")
{
   $All_Users_Startup = Get-ChildItem "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
}
else
{
  write-host "[!] All users startup folder not found."
}
write-host "[*] Successfully scanned startup folders for current user and all users."

write-host "[*] Finding properties of startup elements."

$Current_User_Startup_Folder_details = @{
    type     = "Current User Startup Folder (Shell:startup)"
    location = $Current_User_Startup
    name     = "Example"
    command  = "C:\path\program.exe"
    evidence = @{}
}

$Current_User_Startup_Folder_JsonDetails = $Current_User_Startup_Folder_details | ConvertTo-Json -Depth 5


$All_User_Startup_Folder_details = @{
    type     = "Current User Startup Folder (Shell:Common Startup)"
    location = $All_Users_Startup
    name     = "Example"
    command  = "C:\path\program.exe"
    evidence = @{}
}

$All_User_Startup_Folder_JsonDetails = $All_User_Startup_Folder_details | ConvertTo-Json -Depth 5
