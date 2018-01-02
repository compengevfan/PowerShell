[CmdletBinding()]
Param(
    [Parameter()] [string] $Object
)

Get-Stat Solitude -Realtime -MaxSamples 1 -Stat cpu.usage.average,cpu.ready.summation,mem.vmmemctl.average,virtualDisk.totalReadLatency.average,virtualDisk.totalWriteLatency.average | Sort-Object MetricID,Instance