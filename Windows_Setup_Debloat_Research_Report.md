# Windows Setup/Debloat Research Report

## Executive Summary

This research provides a comprehensive analysis of Windows setup/debloat scripts and utilities, focusing on "sane defaults" rather than aggressive debloating. The goal is to understand best practices while avoiding duplication with CTT's WinUtil, which users run after our script.

## 1. CTT's WinUtil Analysis

### What WinUtil Does
ChrisTitusTech's WinUtil is a comprehensive Windows utility that performs four main categories of operations:

**Installation Management**
- Package installation via winget, chocolatey
- Application management with UI-based selection
- System feature installations (Net Framework 3.5, PowerShell 7, etc.)
- ISO mounting and USB preparation tools

**Debloating Operations**
- Removes pre-installed Microsoft bloatware (3D Builder, Get Started, etc.)
- Uninstalls OneDrive (optional)
- Removes Xbox and gaming-related packages
- Clears Edge shortcuts and favorites

**System Tweaks**
- Privacy settings (telemetry, Cortana, search)
- Performance optimizations (visual effects, services)
- UI customizations (taskbar, Explorer, context menus)
- Network and DNS configurations

**Troubleshooting & Repair**
- Windows update fixes
- System repair tools
- Backup and restore functionality
- Preset configurations

### Key Areas Covered by WinUtil
- **Registry Tweaks**: 100+ registry modifications across privacy, performance, and UI
- **Service Management**: Disables/enables Windows services
- **Package Management**: Integrates with winget and chocolatey
- **Feature Control**: Installs/disables Windows optional features
- **Application Management**: Bulk install/remove with user selection

### Avoidance Checklist for Our Script
Since users run WinUtil AFTER our script, we should avoid:
- Package installations (handled by winget integration in WinUtil)
- Major service modifications
- Windows feature management
- Application removal/debloating
- Network/DNS configuration changes

## 2. Popular Windows Setup Scripts Analysis

### Sycnex/Windows10Debloater
**Focus**: Aggressive debloating approach
**Key Features**:
- Individual modular scripts for specific tasks
- Removes Microsoft bloatware
- Disables Cortana
- Privacy protection settings
- Includes revert functionality

**Approach**: More aggressive than "sane defaults" - removes applications and modifies core behaviors

### Disassembler0/Win10-Initial-Setup-Script
**Focus**: Streamlined initial setup
**Key Features**:
- Single script approach
- Default preset configuration
- Clean and simple interface
- Focus on essential tweaks

**Approach**: Balanced between debloating and maintenance of system functionality

### memstechtips/UnattendedWinstall
**Focus**: Unattended Windows installation
**Key Features**:
- Autounattend.xml configuration
- Installation automation
- Minimal customizations
- OEM deployment focus

**Approach**: Installation-time configuration, not post-install tweaking

### Raphire/Win11Debloat
**Focus**: Windows 11-specific optimizations
**Key Features**:
- GUI-based interface
- Registry files for specific tweaks
- App management system
- Feature control

**Approach**: Modern Windows 11 focus with extensive registry modifications

### Common Themes from Popular Scripts
1. **Privacy Focus**: All scripts emphasize telemetry and data collection control
2. **UI Customization**: Taskbar, Explorer, and Start menu modifications
3. **Performance Tweaks**: Service management and visual effects optimization
4. **Backup Capabilities**: Most include revert functionality
5. **Modular Design**: Individual components for specific tasks

## 3. Microsoft Best Practices

### Winget Package Manager
**Official Recommendations**:
- Use winget for package management in Windows 10/11
- Leverage winget install with --id for precise package targeting
- Use winget list --accept-source-agreements for batch operations
- Implement package signing verification for security

**Best Practices**:
- Use winget source add to add trusted sources
- Implement winget upgrade --all for regular updates
- Use winget export/import for configuration management

### WSL Setup Best Practices
**Microsoft Recommendations**:
- Use WSL 2 for better performance
- Install Linux distributions from Microsoft Store
- Set up proper file sharing between Windows and Linux
- Configure systemd for service management
- Use VSCode with WSL extension for development

**Performance Optimizations**:
- Configure .wslconfig for memory and CPU limits
- Use --mount flag for automatic drive mounting
- Implement proper PATH configuration
- Set up X11 forwarding for GUI applications

## 4. Registry Tweaks for Sane Defaults

### Privacy-Related Tweaks (Safe for Sane Defaults)
```powershell
# Telemetry
Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 1
Write-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Camera" -Name "LoopbackAllowed" -Value 0

# Cortana
Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0
Write-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaEnabled" -Value 0

# Advertising
Write-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
```

### Performance Tweaks (Safe for Sane Defaults)
```powershell
# Visual Effects
Write-RegistryValue -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value 0
Write-RegistryValue -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 200

# Power Settings
Write-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\381b4222-f694-41f0-9685-ff5bb260df2e" -Name "Attributes" -Value 2

# Search
Write-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchInBackground" -Value 0
```

### UI Customizations (Safe for Sane Defaults)
```powershell
# Taskbar
Write-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0

# Explorer
Write-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
Write-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowHiddenFiles" -Value 1

# Context Menu
Write-RegistryValue -Path "HKCU:\Software\Classes\*\shell\runas" -Name "HasLUAShield" -Value ""
```

### Windows Update Control (Safe for Sane Defaults)
```powershell
# Update Delivery Optimization
Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 1

# Automatic Updates
Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 0
Write-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 4
```

## 5. Group Policy Registry Equivalents

For Windows Pro/Enterprise editions, many Group Policy settings can be applied via registry:

### Privacy Settings
```powershell
# Allow Telemetry (GP: Computer Configuration > Administrative Templates > Windows Components > Data Collection)
HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\AllowTelemetry

# Let apps use advertising ID (GP: Computer Configuration > Administrative Templates > Windows Components > Advertising Info)
HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo\Enabled

# Let websites provide locally relevant content by accessing language list
HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Camera\Declined\{7F5D3F8C-6277-477C-87F5-6D5C4A05BF36}
```

### Security Settings
```powershell
# Turn off Microsoft consumer experiences
HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableSoftLanding

# Allow Microsoft accounts to be optional
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE\AllowMicrosoftAccount
```

## 6. PowerShell Profile for Data Analytics

### Recommended Profile Setup
```powershell
# Profile Location: $PROFILE or %USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1

# Import modules
Import-Module posh-git
Import-Module oh-my-posh
Import-Module PSReadLine

# Set up aliases
Set-Alias -Name ll -Value Get-ChildItem -Option AllScope
Set-Alias -Name g -Value git -Option AllScope
Set-Alias -Name v -Value code -Option AllScope

# Configuration
$PSStyle.FileInfo.Extension = $true
$PSStyle.PromptLocation = 'CurrentPath'

# Data analytics specific
Import-Module Microsoft.PowerShell.Utility
Set-PSReadLine -HistorySavePath $env:USERPROFILE\.ps_history
Set-PSReadLine -HistorySaveStyle SaveIncrementally
```

### Essential Modules for Data Analytics
1. **posh-git**: Git integration
2. **oh-my-posh**: Themeable prompt
3. **PSReadLine**: Enhanced command line editing
4. **ImportExcel**: Excel file operations
5. **PSSQLite**: SQLite database operations
6. **Zip**: File compression utilities

## 7. Package Manager Comparison

### Winget vs Scoop vs Chocolatey

| Feature | Winget | Scoop | Chocolatey |
|---------|--------|-------|------------|
| **Vendor** | Microsoft | Community | Community |
| **Enterprise Ready** | ★★★★★ | ★☆☆☆☆ | ★★★★★ |
| **Security** | Built-in signing | Basic | Multiple layers |
| **Management** | Group Policy | User-level | Enterprise |
| **Package Count** | 5000+ | 4000+ | 8000+ |
| **Installation** | System-wide | User-specific | System-wide |
| **Updates** | Automatic | Manual/Automatic | Automatic |

### Why Winget is Preferred for Enterprise
1. **Microsoft Integration**: Native Windows support, group policies
2. **Security**: Built-in package signing and verification
3. **Active Development**: Microsoft-backed with regular updates
4. **Compatibility**: Works with Microsoft Endpoint Manager
5. **Standardization**: Becoming the de facto standard

### Use Case Recommendations
- **Enterprise Deployment**: Winget (with chocolatey as backup for legacy)
- **Developer Workstations**: Winget + Scoop for user-specific tools
- **High Security**: Chocolatey Business with private repositories
- **Mixed Environments**: Winget as primary, with selective tool additions

## 8. Safe vs Risky Registry Tweaks

### Safe Tweaks (Recommended for Sane Defaults)
- Privacy settings (telemetry, advertising)
- UI customizations (taskbar, Explorer)
- Performance optimizations (visual effects)
- Search and indexing controls
- Update delivery settings

### Risky Tweaks (Avoid for Sane Defaults)
- System service modifications (can break functionality)
- Security policy changes (potential security implications)
- Network stack modifications (connectivity issues)
- File association overrides (application instability)
- Driver-related changes (hardware compatibility)

## 9. Best Practices Summary

### For "Sane Defaults" Approach
1. **Focus on Configuration, Not Removal**: Modify settings rather than removing components
2. **Preserve System Stability**: Avoid changes that could break Windows functionality
3. **User Choice**: Provide options where possible rather than making permanent changes
4. **Reversible Changes**: Ensure all tweaks can be easily reverted
5. **Documentation**: Keep clear records of all modifications made

### Implementation Guidelines
1. **Test Changes**: Always test in a safe environment first
2. **Create Backups**: System restore points before applying changes
3. **Use PowerShell**: Scripted changes are more reliable than manual edits
4. **Group Policy First**: Use GPO for enterprise deployments where possible
5. **Regular Review**: Periodically review and update configuration as needed

## 10. Configuration Recommendations

### Priority 1: Must-Have Tweaks
- Privacy controls (telemetry, advertising)
- Basic UI customizations (file extensions, hidden files)
- Performance optimizations (visual effects)
- PowerShell profile setup

### Priority 2: Recommended Tweaks
- Update management settings
- Explorer navigation improvements
- Taskbar customizations
- Search indexing controls

### Priority 3: Optional Tweaks
- Advanced performance settings
- Network optimizations
- Theme customizations
- Developer-specific settings

This research provides a comprehensive foundation for creating a Windows setup script that focuses on "sane defaults" while avoiding duplication with WinUtil and other comprehensive utilities.
