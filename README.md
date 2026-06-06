# win-setup

Guided PowerShell setup script for a fresh Windows 11 24H2+ install.

## What it does

- Enables WSL2 + Virtual Machine Platform
- Enables symlinks, long paths, and sudo
- Installs apps via `winget import` from `apps.json`
- Installs Ubuntu on WSL
- Applies Explorer power-user tweaks
- Applies mild privacy hardening
- Activates Ultimate Performance power plan
- Symlinks komorebi config with workspace rules, status bar, and auto-start
- Adds app-launch hotkeys
- Symlinks a PowerShell 7 profile with Starship
- Symlinks bat config with the [Ashen](https://codeberg.org/ficd/ashen) theme and rebuilds the bat cache
- Merges the Ashen color scheme into Windows Terminal
- Interactive git setup.

Configs are deployed as symlinks pointing back into this repo, so editing any file under `configs/` takes effect immediately with no need to re-run `setup.ps1`.

## Usage

> [!NOTE]  
> The script will prompt for elevation if not running as admin.

```powershell
Set-ExecutionPolicy Bypass -Scope Process
.\setup.ps1
```

> [!IMPORTANT]
> Because configs are symlinked rather than copied, keep this repo at its cloned location. Moving or deleting it leaves the linked configs dangling. Any pre-existing real config the script replaces is backed up once to `<file>.bak`.

## Known Issues
- PowerToys must load after komorebi or PowerToys keybinds will take precedence.
