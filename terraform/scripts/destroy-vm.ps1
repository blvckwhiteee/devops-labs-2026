<#
.SYNOPSIS
    Stops and permanently removes a VirtualBox VM.
#>
param(
    [Parameter(Mandatory)][string]$VmName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$existing = & VBoxManage list vms 2>&1
if ($existing -notmatch [regex]::Escape("`"$VmName`"")) {
    Write-Host "VM '$VmName' not found — nothing to destroy."
    exit 0
}

$state = (& VBoxManage showvminfo $VmName --machinereadable 2>&1 | Select-String "^VMState=").ToString()
if ($state -match '"running"') {
    Write-Host "==> Powering off $VmName..."
    & VBoxManage controlvm $VmName poweroff 2>&1 | Write-Host
    Start-Sleep -Seconds 3
}

Write-Host "==> Unregistering and deleting $VmName..."
& VBoxManage unregistervm $VmName --delete 2>&1 | Write-Host
Write-Host "Done: $VmName removed."
