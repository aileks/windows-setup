# Windows Setup

Opinionated setup for Windows 11 24H2+. Use at your own risk.

## Usage

```powershell
irm https://aileks.dev/win | iex
```

Or manually:

```powershell
git clone https://codeberg.org/aileks/windots.git "$env:USERPROFILE\.dotfiles"
Set-Location "$env:USERPROFILE\.dotfiles"

Set-ExecutionPolicy Bypass -Scope Process
.\setup.ps1
```

The setup prompts separately for WSL and Ubuntu. Decline that prompt to continue with Windows setup only.
