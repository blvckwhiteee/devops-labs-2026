<#
.SYNOPSIS
    Imports an Ubuntu cloud-image OVA, attaches a NoCloud seed ISO, and starts the VM.
    Idempotent: skips steps if VM already exists in the target state.
#>
param(
    [Parameter(Mandatory)][string]$VmName,
    [Parameter(Mandatory)][string]$OvaPath,
    [Parameter(Mandatory)][string]$BaseFolder,
    [Parameter(Mandatory)][string]$IsoPath,
    [Parameter(Mandatory)][string]$HostOnlyIf,
    [int]$Memory = 2048,
    [int]$Cpus   = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function vbm { & VBoxManage @args 2>&1 | Write-Host }

$existing = & VBoxManage list vms 2>&1
if ($existing -match [regex]::Escape("`"$VmName`"")) {
    Write-Host "VM '$VmName' already exists — skipping import."
} else {
    Write-Host "==> Importing OVA for $VmName..."
    if (-not (Test-Path $OvaPath)) { throw "OVA not found: $OvaPath" }

    & VBoxManage import $OvaPath `
        --vsys 0 `
        --vmname   $VmName `
        --basefolder $BaseFolder `
        --memory   $Memory `
        --cpus     $Cpus 2>&1 | Write-Host

    Write-Host "==> Configuring network for $VmName..."
    vbm modifyvm $VmName --nic1 nat
    vbm modifyvm $VmName --nic2 hostonly --hostonlyadapter2 $HostOnlyIf
    vbm modifyvm $VmName --nictype1 82540EM --nictype2 82540EM

    Write-Host "==> Attaching NoCloud ISO to $VmName..."
    if (-not (Test-Path $IsoPath)) { throw "ISO not found: $IsoPath" }

    vbm storagectl $VmName --name "IDE Controller" --add ide --controller PIIX4 2>&1 | Out-Null

    vbm storageattach $VmName `
        --storagectl "IDE Controller" `
        --port 1 --device 0 `
        --type dvddrive `
        --medium $IsoPath
}

$state = (& VBoxManage showvminfo $VmName --machinereadable 2>&1 | Select-String "^VMState=").ToString()
if ($state -match '"running"') {
    Write-Host "VM '$VmName' is already running."
} else {
    Write-Host "==> Starting $VmName..."
    vbm startvm $VmName --type headless
}

Write-Host "Done: $VmName"
