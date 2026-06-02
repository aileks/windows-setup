# Registry Tweaks Quick Reference

## Safe Sane Defaults Registry Tweaks

### Privacy Settings
```powershell
# Telemetry (0=Off, 1=Basic, 2=Enhanced, 3=Full)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Access\Global\{E5F5E2D9-6D30-44C1-9ED4-1126B6E915F4}" -Name "Value" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 1 -Type DWord

# Advertising ID
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord

# Cortana
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Type DWord
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaEnabled" -Value 0 -Type DWord

# Location Services
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Location" -Name "Deny" -Value 0xFFFFFFFF -Type DWord
```

### Performance Tweaks
```powershell
# Visual Effects
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value 0 -Type String
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 200 -Type String
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value "2" -Type String

# Power Settings (Balanced)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\381b4222-f694-41f0-9685-ff5bb260df2e" -Name "Attributes" -Value 2 -Type DWord

# Search Background
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchInBackground" -Value 0 -Type DWord
```

### UI Customizations
```powershell
# File Explorer
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowHiddenFiles" -Value 1 -Type DWord
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "NavPaneExpandToCurrentFolder" -Value 1 -Type DWord

# Taskbar
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0 -Type DWord
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "TaskbarNoJumpList" -Value 0 -Type DWord

# Context Menu
Set-ItemProperty -Path "HKCU:\Software\Classes\*\shell\runas" -Name "HasLUAShield" -Value "" -Type String
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\Background\shell\cmd" -Name "icon" -Value "cmd.exe" -Type String
```

### Windows Update Control
```powershell
# Update Delivery (1=PCs on my local network only, 2= PCs on my local network and from other Microsoft servers)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 1 -Type DWord

# Automatic Updates (4=Notify for download and notify for install)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 4 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 0 -Type DWord
```

### WSL Optimizations
```powershell
# WSL 2 Memory Limit (in GB)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" -Name "DefaultMemoryLimit" -Value 8589934592 -Type DWord

# WSL 2 CPU Count
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" -Name "DefaultVcpuCount" -Value 2 -Type DWord
```

## Group Policy Registry Equivalents

### For Enterprise Environments
```powershell
# Disable Microsoft Consumer Experiences
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableSoftLanding" -Value 1 -Type DWord

# Allow Microsoft Account to be Optional
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "AllowMicrosoftAccount" -Value 0 -Type DWord

# Turn off Location Access
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableWindowsLocationProvider" -Value 1 -Type DWord
```

## PowerShell Commands for Registry Operations

### Safe Registry Modification Function
```powershell
function Set-RegistrySafe {
    param (
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "String",
        [bool]$Force = $false
    )
    
    if (-not (Test-Path $Path)) {
        if ($Force) {
            $parent = Split-Path $Path -Parent
            if (-not (Test-Path $parent)) {
                New-Item -Path $parent -Force | Out-Null
            }
            New-Item -Path $Path -Force | Out-Null
        } else {
            Write-Warning "Path does not exist: $Path"
            return $false
        }
    }
    
    try {
        $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -eq $existing) {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force | Out-Null
        } else {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        }
        return $true
    } catch {
        Write-Warning "Failed to set registry property: $_"
        return $false
    }
}
```

## Backup and Restore

### Create Registry Backup
```powershell
# Export specific keys
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" "$env:USERPROFILE\explorer_settings.reg"

# Export all user settings
reg export "HKCU" "$env:USERPROFILE\user_settings.reg"

# Create system restore point
Checkpoint-Computer -Description "Before Registry Tweaks" -RestorePointType "MODIFY_SETTINGS"
```

### Import Registry Settings
```powershell
# Import from file
reg import "$env:USERPROFILE\explorer_settings.reg"

# Restore from system restore
Restore-Computer -RestorePoint ((Get-ComputerRestorePoint | Where-Object {$_.Description -eq "Before Registry Tweaks"}).RestorePointId)
```

## Safety Guidelines

1. **Always backup** before making changes
2. **Test in isolated environment** first
3. **Use PowerShell** for reliable scripting
4. **Create system restore points** for major changes
5. **Document all changes** made
6. **Avoid** keys under HKLM\SYSTEM\CurrentControlSet\Services unless necessary
7. **Test on non-production systems** before deployment
