# win-setup

Guided WSL-first setup script for a fresh Windows 11 24H2+ install.

## What it does

- Guides category-based software installs through `winget`
- Optionally enables WSL2, symlinks, long paths, and related Windows developer settings
- Applies Explorer, privacy, power, Windows Terminal, and komorebi config tweaks
- Prompts for reboot when setup changes require it

## Usage

> [!NOTE]
> The script will prompt for elevation if not running as admin.

> [!IMPORTANT]
> Configs are deployed as symlinks pointing back into this repo where supported, so editing the linked files under `configs/` takes effect immediately with no need to re-run `setup.ps1`.

```powershell
Set-ExecutionPolicy Bypass -Scope Process
.\setup.ps1
```

> Because configs are symlinked rather than copied, keep this repo at its cloned location. Moving or deleting it leaves the linked configs dangling. Any pre-existing real config the script replaces is backed up once to `<file>.bak`.
