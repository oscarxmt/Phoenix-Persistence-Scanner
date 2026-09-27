[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")


$tasks = Get-ScheduledTask | Where-Object {$_.State -ne "Disabled"}

foreach($task in $tasks) {
    foreach($action in $task.Actions) {
        try {
            $type = "Scheduled_Task"
            $name = $task.TaskName
            $location = $task.TaskPath
            $command = "$($action.Execute) $($action.Arguments)"
            $enabled=($task.State -ne "Disabled")
            $evidence=@{ state = $task.State }
            $results += [ScanFinding]::new($type, $name, $location, $command, $enabled, $evidence) # this needs to be impelmented. This is not finished code.
        }
        catch {
            write-host $_.Exception.Message
        }
    }
}

[PSCustomObject]@{
    check   = "Scheduled_Task"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5