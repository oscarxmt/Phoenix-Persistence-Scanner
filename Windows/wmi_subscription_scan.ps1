[CmdletBinding()]
param()

$results_json = @()
$errors = @()

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$outputDir   = Join-Path -Path $projectRoot -ChildPath "data"
$outputPath  = Join-Path -Path $outputDir -ChildPath "scan_results.json"
. (Join-Path -Path $PSScriptRoot -ChildPath "ScanFinding.ps1")


$classes = "__EventFilter", "__EventConsumer", "__FilterToConsumerBinding"
$type = "Wmi_Subscription"
foreach ($class in $classes) {
    $results = Get-CimInstance -Namespace root\subscription -ClassName $class
    
    foreach ($item in $results) {
        if ($item.CimClass.CimClassName -eq "CommandLineEventConsumer") {
            $location = $item.ExecutablePath
            $command  = $item.CommandLineTemplate
            $evidence = $null
        } elseif ($item.CimClass.CimClassName -eq "ActiveScriptEventConsumer") {
            $location = $null
            $command  = $null
            $evidence = "$($item.ScriptText)$($item.ScriptFileName)"
        }
    }
}

[PSCustomObject]@{
    check   = "Wmi_Subscription"
    results = @($results_json)
    errors  = @($errors)
} | ConvertTo-Json