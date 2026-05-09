<#
.SYNOPSIS
    Creates a NoCloud seed ISO for cloud-init using the Windows IMAPI2FS COM object.
    No external tools or Windows ADK required.
.PARAMETER SourceDir
    Directory containing 'user-data' and 'meta-data' files.
.PARAMETER OutputIsoPath
    Full path to the output .iso file.
.PARAMETER VolumeLabel
    ISO volume label. Must be 'CIDATA' for cloud-init NoCloud datasource.
#>
param(
    [Parameter(Mandatory)][string]$SourceDir,
    [Parameter(Mandatory)][string]$OutputIsoPath,
    [string]$VolumeLabel = "CIDATA"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Validate inputs
if (-not (Test-Path $SourceDir)) {
    throw "Source directory not found: $SourceDir"
}
foreach ($f in @("user-data", "meta-data")) {
    if (-not (Test-Path (Join-Path $SourceDir $f))) {
        throw "Required file missing from source dir: $f"
    }
}

# Build ISO using IMAPI2FS (built into Windows Vista+)
$fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fsi.FileSystemsToCreate = 3      # FsiFileSystemISO9660(1) | FsiFileSystemJoliet(2)
$fsi.VolumeName           = $VolumeLabel
$fsi.Root.AddTree((Resolve-Path $SourceDir).Path, $false)

$imageStream = $fsi.CreateResultImage().ImageStream

# Write IStream to disk via ADODB.Stream (built into Windows)
$adoStream = New-Object -ComObject ADODB.Stream
$adoStream.Type = 1   # adTypeBinary
$adoStream.Open()
$adoStream.CopyFrom($imageStream)
$adoStream.SaveToFile($OutputIsoPath, 2)   # adSaveCreateOverWrite
$adoStream.Close()

Write-Host "NoCloud ISO created: $OutputIsoPath (label=$VolumeLabel)"
