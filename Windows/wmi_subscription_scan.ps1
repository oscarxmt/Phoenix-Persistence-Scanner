[CmdletBinding()]
param()

$results = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")


$classes = "__EventFilter", "__EventConsumer", "__FilterToConsumerBinding"
$type = "Wmi_Subscription"
foreach ($class in $classes) {
    try {
        $instances = Get-CimInstance -Namespace root\subscription -ClassName $class -ErrorAction Stop
        foreach ($item in $instances) {
            $location = "root\subscription:$class"
            $command = $null
            $findingName = [string]$item.Name
            $evidence = @{ class = $class }
            $includeFinding = $true

            if ($class -eq "__EventConsumer") {
                switch ($item.CimClass.CimClassName) {
                    "CommandLineEventConsumer" {
                        $location = [string]$item.ExecutablePath
                        $command = [string]$item.CommandLineTemplate
                    }
                    "ActiveScriptEventConsumer" {
                        $evidence = @{
                            class = $item.CimClass.CimClassName
                            script_text = [string]$item.ScriptText
                            script_file = [string]$item.ScriptFileName
                        }
                        if ($item.ScriptFileName) { $location = [string]$item.ScriptFileName }
                    }
                    default { $includeFinding = $false }
                }
            } elseif ($class -eq "__EventFilter") {
                $evidence.query = [string]$item.Query
                $evidence.query_language = [string]$item.QueryLanguage
                $evidence.event_namespace = [string]$item.EventNamespace
            } elseif ($class -eq "__FilterToConsumerBinding") {
                $evidence.filter = [string]$item.Filter
                $evidence.consumer = [string]$item.Consumer
            }

            if (-not $includeFinding) { continue }
            if ([string]::IsNullOrWhiteSpace($findingName)) { $findingName = [string]$item.CimInstanceId }
            $results += [ScanFinding]::new($type, $findingName, $location, $command, $true, $evidence)
        }
    } catch {
        $errors += [PSCustomObject]@{
            location = "root\subscription:$class"
            message = "Could not read WMI subscription class: $($_.Exception.Message)"
        }
    }
}

[PSCustomObject]@{
    check   = "Wmi_Subscription"
    results = @($results)
    errors  = @($errors)
} | ConvertTo-Json -Depth 8