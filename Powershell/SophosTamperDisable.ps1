<#
.SYNOPSIS
    A script to modify specific registry keys related to Sophos. It makes a backup of the registry before making any changes.

.DESCRIPTION
    This script makes a backup of the registry.
    It then modifies registry keys related to Sophos services to disable tamper protection. 

    You must reboot the server in recovery mode and rename the file 'C:\Windows\System32\drivers\SophosED.sys' before running this script.

    The steps are:
      1. Reboot the server in recovery mode.
      2. Launch the command prompt.
      3. Rename the file 'C:\Windows\System32\drivers\SophosED.sys' to 'C:\Windows\System32\drivers\SophosED.sys.old'.
          Note: The drive letter may be different, run diskpart to find the correct drive letter (list volume).
      4. Reboot back into Windows.
      5. Run this script as administrator.
      6. Uninstall Sophos.
      7. Reboot the server.

    -----
    Author:      Patrick Doyle (pdoyle@glaciermedia.ca)
    Version:     0.1.9
    Last Update: 2023-03-16

.PARAMETER Help
    When this switch is specified, the script will display a help message and exit.

.PARAMETER BackupFolder
Specifies the location where the backup file should be saved. The default is C:\RegistryBackup.

.EXAMPLE
    .\SophosTamperDisable.ps1 -Help
    Displays the help message and exits.

.LINK
    https://support.sophos.com/support/s/article/KB-000036125
#>

Param (
    [Parameter(Mandatory=$false)]
    [switch]$Help,

    [Parameter(Mandatory=$false)]
    [string]$BackupFolder = "C:\RegistryBackup"
)

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    exit
}

$filePath = 'C:\Windows\System32\drivers\SophosED.sys'

if (Test-Path $filePath) {
    Write-Host "The file '$filePath' exists. Please reboot the server in recovery mode and rename the file before changing the registry keys."
    Write-Host "For manual instructions, refer to the following Sophos help article: https://support.sophos.com/support/s/article/KB-000036125"
    exit
}

# Get the current date and time
$dateTime = Get-Date -Format "yyyyMMdd_HHmmss"

# Create the backup folder if it doesn't exist
if (-not (Test-Path $BackupFolder)) {
    New-Item -ItemType Directory -Path $BackupFolder | Out-Null
    Write-Host "Created backup folder: $BackupFolder"
}

# Set the backup filename
$backupFile = "$BackupFolder\$dateTime.reg"

# Try to backup the registry
try {
    Write-Host "Backing up registry to $backupFile..."
    reg export HKLM $backupFile | Out-Null
    Write-Host "Registry backup complete."
}
catch {
    Write-Error "An error occurred while backing up the registry: $($_.Exception.Message)"
}


# Define the registry keys and values to modify
$registryKeys = @(
    @{
        'Path' = 'HKLM:\SYSTEM\CurrentControlSet\Services\Sophos MCS Agent';
        'ValueName' = 'Start';
        'ValueData' = 4;
    },
    @{
        'Path' = 'HKLM:\SYSTEM\CurrentControlSet\Services\Sophos AutoUpdate Service';
        'ValueName' = 'Start';
        'ValueData' = 4;
    },
    @{
        'Path' = 'HKLM:\SYSTEM\CurrentControlSet\Services\Sophos Endpoint Defense\TamperProtection\Config';
        'ValueName' = 'SEDEnabled';
        'ValueData' = 0;
    }
)

# Modify the known registry keys
foreach ($key in $registryKeys) {
    try {
        if (Test-Path $key.Path) {
            Set-ItemProperty -Path $key.Path -Name $key.ValueName -Value $key.ValueData -ErrorAction Stop
            Write-Host "Changed registry key: $($key.Path) - Set $($key.ValueName) to $($key.ValueData)"
        }
    } catch {
        Write-Error "Failed to modify registry key: $($key.Path). Error: $($_.Exception.Message)"
    }
}

# Modify the subkeys for TamperProtection\Services
$servicesPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Sophos Endpoint Defense\TamperProtection\Services'
if (Test-Path $servicesPath) {
    try {
        Get-ChildItem $servicesPath -ErrorAction Stop | ForEach-Object {
            $subkeyPath = $servicesPath + '\' + $_.PSChildName
            Set-ItemProperty -Path $subkeyPath -Name "Protected" -Value 0 -ErrorAction Stop
            Write-Host "Changed subkey under TamperProtection\Services: $subkeyPath - Set Protected to 0"
        }
    } catch {
        Write-Error "Failed to modify subkeys under TamperProtection\Services. Error: $($_.Exception.Message)"
    }
}

Write-Host "Script Completed."
