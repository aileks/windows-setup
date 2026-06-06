# win-setup

Guided PowerShell setup script for a fresh Windows 11 24H2+ install.

## What it does

- Enables WSL2 + Virtual Machine Platform
- Enables symlinks, long paths, developer mode
- Installs apps via `winget import` from `apps.json`
- Installs Ubuntu on WSL
- Applies Explorer power-user tweaks
- Applies mild privacy hardening
- Activates Ultimate Performance power plan
- Deploys komorebi config with workspace rules, status bar, and auto-start
- Adds app-launch hotkeys
- Deploys a PowerShell 7 profile with Starship
- Deploys bat config with the [Ashen](https://codeberg.org/ficd/ashen) theme and rebuilds the bat cache
- Deploys color scheme for Windows Terminal
- Interactive git setup.

## Usage

> [!NOTE]  
> The script will prompt for elevation if not running as admin.

```powershell
Set-ExecutionPolicy Bypass -Scope Process
.\setup.ps1
```

## Known Issues
- PowerToys must load after komorebi or PowerToys keybinds will take precedence.
