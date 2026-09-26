# ScanFinding.ps1 — save this once, in a shared location
class ScanFinding {
    [string]$type
    [string]$name
    [string]$location
    [string]$command
    [bool]$enabled
    [hashtable]$evidence

    ScanFinding([string]$type, [string]$name, [string]$location, [string]$command, [bool]$enabled, [hashtable]$evidence) {
        $this.type     = $type
        $this.name     = $name
        $this.location = $location
        $this.command  = $command
        $this.enabled  = $enabled
        $this.evidence = $evidence
    }
}