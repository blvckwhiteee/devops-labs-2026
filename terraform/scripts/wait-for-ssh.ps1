<#
.SYNOPSIS
    Waits until TCP port 22 is reachable on the given host.
#>
param(
    [Parameter(Mandatory)][string]$Host,
    [int]$Port        = 22,
    [int]$TimeoutSec  = 300,
    [int]$IntervalSec = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "==> Waiting for SSH on ${Host}:${Port} (timeout=${TimeoutSec}s)..."
$deadline = (Get-Date).AddSeconds($TimeoutSec)

while ((Get-Date) -lt $deadline) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect($Host, $Port)
        $tcp.Close()
        Write-Host "SSH is available on ${Host}:${Port}"
        exit 0
    } catch {
        Write-Host "  Not ready yet, retrying in ${IntervalSec}s..."
        Start-Sleep -Seconds $IntervalSec
    }
}

throw "Timeout: SSH on ${Host}:${Port} did not become available within ${TimeoutSec}s"
