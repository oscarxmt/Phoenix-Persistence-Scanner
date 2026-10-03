[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")


$tasks = @()
try {
    $tasks = Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.State -ne "Disabled" }
} catch {
    $errors += [PSCustomObject]@{
        location = "Scheduled Tasks"
        message = "Could not enumerate scheduled tasks: $($_.Exception.Message)"
    }
}

foreach ($task in $tasks) {
    foreach ($action in $task.Actions) {
        try {
            $type = "Scheduled_Task"
            $name = $task.TaskName
            $location = $task.TaskPath
            $enabled=($task.State -ne "Disabled")
            $evidence=@{ state = $task.State }
            if ($null -ne $action.PSObject.Properties['ClassId']) {
                $command = [string]$action.ClassId
                $evidence.action_type = "ComHandler"
                $evidence.class_id = [string]$action.ClassId
                $evidence.data = [string]$action.Data
            } else {
                $command = "$($action.Execute) $($action.Arguments)"
                $evidence.action_type = "Exec"
            }
            $results += [ScanFinding]::new($type, $name, $location, $command, $enabled, $evidence)
        }
        catch {
            $errors += [PSCustomObject]@{
                location = "$($task.TaskPath)$($task.TaskName)"
                message = "Could not record scheduled task action: $($_.Exception.Message)"
            }
        }
    }
}

[PSCustomObject]@{
    check   = "Scheduled_Task"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 5
