param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationPath,

    # Assume the volume is always the root of the source path (e.g., C: for C:\...)
    [Parameter(Mandatory=$true)]
    [string]$Volume
)

# Ensure the Volume variable ends with a colon
$Volume = "$($Volume.TrimEnd(':')):" 

# --- 1. Create the Shadow Copy ---
Write-Host "Creating Shadow Copy of Volume $Volume..."
$ShadowCopy = New-Object -ComObject WbemScripting.SWbemLocator
$Service = $ShadowCopy.ConnectServer($env:COMPUTERNAME, "root\cimv2")

# Create a new shadow copy
$ShadowResult = (Get-WmiObject -List Win32_ShadowCopy).Create($Volume + "\", $NULL)
if ($ShadowResult.ReturnValue -ne 0) {
    throw "Failed to create shadow copy. Return code: $($ShadowResult.ReturnValue)"
}
$ShadowCopyID = $ShadowResult.ShadowID
Write-Host "Shadow Copy created successfully. ID: $ShadowCopyID"

# --- 2. Mount the Shadow Copy and Copy Files ---
$ShadowCopyObject = Get-WmiObject -Class Win32_ShadowCopy -Filter "ID = '$ShadowCopyID'"
$ShadowCopyDevice = $ShadowCopyObject.DeviceObject + "\"

# Calculate the path inside the shadow copy (e.g., remove 'C:\' from source)
$PathInsideShadow = $SourcePath.Substring(3) 

# Ensure destination exists
if (-not (Test-Path $DestinationPath)) {
    New-Item -Path $DestinationPath -ItemType Directory | Out-Null
}

Write-Host "Starting file copy from Shadow Copy..."
# The copy operation reads from the static snapshot
Copy-Item -Path ($ShadowCopyDevice + $PathInsideShadow + "\*") -Destination $DestinationPath -Recurse -Force

Write-Host "File copy complete."

# --- 3. Delete the Shadow Copy ---
Write-Host "Deleting Shadow Copy..."
$ShadowCopyObject.Delete()
Write-Host "Shadow Copy deleted successfully."
