[CmdletBinding()]
param()

$Systems_ScheduledTasks = Get-ScheduledTask | Where-Object {$_.State -ne "Disabled"} | Select-Object TaskName, TaskPath, State

foreach($task in $Systems_ScheduledTasks) {
    foreach($action in $task.Actions) {
        $type = "Scheduled Task"
        $name = $tasks.TaskName
        $command = $tasks.TaskPath
        $State = $tasks.State
        #$results += [ScanFinding]::new() # this needs to be impelmented. This is not finished code.
    }
}