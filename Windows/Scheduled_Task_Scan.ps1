[CmdletBinding()]
param()

$Systems_ScheduledTaks = Get-ScheduledTask | Where-Object {$_.State -ne "Disabled"} | Select-Object TaskName, TaskPath, State