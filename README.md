# win-setup

Guided WSL-first setup script for a fresh Windows 11 24H2+ install.

## What it does

- Ensures `winget` is available before software installation
- Prompts for software by category, with skip support for every category
- Allows multiple selections except for Window Management, which accepts one choice
- Installs selected apps via exact package IDs with `winget`
- Installs Fastmail from the vendor Windows installer as the only direct-installer exception
- Prompts for global Git config when Git is already installed; Git is not installed by this script
- Prompts before running the personal WSL-first setup
- Enables WSL2 + Virtual Machine Platform
- Enables symlinks, long paths, and Sudo for Windows in normal mode when available
- Installs Ubuntu on WSL
- Applies Explorer power-user tweaks
- Applies mild privacy hardening
- Activates Ultimate Performance power plan
- Symlinks `.wslconfig`
- Symlinks komorebi config with workspace rules, status bar, and auto-start when komorebi is installed
- Merges the Ashen color scheme into Windows Terminal when Windows Terminal is installed
- Prompts for a reboot after personal setup.

Configs are deployed as symlinks pointing back into this repo where supported, so editing the linked files under `configs/` takes effect immediately with no need to re-run `setup.ps1`.

Windows PowerShell profile setup has been removed. Windows-side CLI customization should happen through WSL.

## Software Categories

- Code editor: VS Code, Neovim, Zed, JetBrains Toolbox
- Terminal: Windows Terminal, Rio, Tabby, Hyper
- Window Management: Komorebi, GlazeWM
- Browser: Zen Browser, Firefox, Brave Browser, Chrome, Helium
- Mail client: Thunderbird, Fastmail, Proton Mail, Tutanota
- Messengers: Discord, Signal, Telegram, Element, WhatsApp
- Utilities: PowerToys, 7-Zip, BCUninstaller, VLC, HWiNFO, NVCleanInstall, Ditto, Everything

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
