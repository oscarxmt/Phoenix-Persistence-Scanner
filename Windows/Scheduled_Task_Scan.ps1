[CmdletBinding()]
param()

$Systems_ScheduledTasks = Get-ScheduledTask | Where-Object {$_.State -ne "Disabled"} | Select-Object TaskName, TaskPath, State

if ($Systems_ScheduledTasks = ""){
    write-host "[!] There are no current scheduled tasks on this system. There was likely an error."
}

foreach($line in $Systems_ScheduledTasks) {
    
}