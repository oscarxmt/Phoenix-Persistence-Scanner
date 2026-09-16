$currentdir = cmd.exe /C cd C:

Write-Host "`n[*] Checking Scheduled Tasks..."

$user = $env:username 

$finalfilename = $user + "_ScheduledTask"

Write-Host "`n[*] Checking Startup Folders..."
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
Get-ChildItem "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"

# This not worky yet :(
#[Json]$MyJsonVariable = "
#{
#    ""Startup_Folders"": {
#        ""User_Startup_Folder"": ""$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"",
#        ""All_Users_Startup_Folder"": ""C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup""
#    }
#
#
#}
#"