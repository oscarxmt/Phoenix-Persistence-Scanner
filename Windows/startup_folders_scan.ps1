$currentdir = cmd.exe /C cd C:

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

# This not worky yet :(
[Json]$MyJsonVariable = "
{
    "type": "Current User Startup Folder",
    "location": "$Current_User_Startup",



}
