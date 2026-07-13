# Windows Setup

Forced to use Windows so I might as well make it usable. Windows 11 24H2+ only.

> [!IMPORTANT]
> Keep this repository at its cloned path. Configs are symlinked where possible. Moving the repository leaves those links dangling.

## Usage

```powershell
irm https://aileks.dev/win | iex
```

Or manually:

```powershell
git clone https://codeberg.org/aileks/win-setup.git
cd win-setup

Set-ExecutionPolicy Bypass -Scope Process
.\setup.ps1
```

## Windows

- Enables long paths, four-way symlink evaluation, and Sudo for Windows in inline mode.
- Shows extensions and hidden files; hide recent/frequent files and sync-provider ads.
- Enables taskbar auto-hide and removes search and Task View icons.
- Disable Widgets, cloud/web search, consumer content, suggestions, tips, and tailored experiences.
- Disables telemetry, opt-in UI, extended logs/dumps, feedback prompts, advertising ID, activity upload, and speech/input personalization.
- Disables Recall snapshots through Windows policy.
- Keeps local clipboard history while disabling cross-device clipboard sync.
- Activates Ultimate Performance power profile.
- Installs Microsoft Coreutils and other CLI utilities.
- Installs Adwaita and JetBrains nerd fonts.

Before registry-backed setup actions run, the registry is backed up under `%USERPROFILE%\.win-setup\registry-backups\`.

## WSL

- Installs Ubuntu 26.04
- Installs build tools, curl, git, and unzip.
- Prompts for git setup.
- Sets zsh as default shell.
- Installs modern utilities: socat, ripgrep, fzf, fastfetch, bat, eza, zoxide, fd, jq, and Starship.
- `~/Projects` for Linux-hosted repositories.
- Copies managed configs through `\\wsl.localhost\Ubuntu\home\<user>` into Linux storage, then creates native Linux symlinks to that copy. Rerun setup after changing a checked-in WSL config.

## Configs and state

Existing files are timestamp-backed up before replacement. Checked-in configs are linked into Windows and WSL. Windows Terminal settings are backed up before their scheme/default profile merge.

State and logs:

- `%USERPROFILE%\.win-setup\state.json`
- `%USERPROFILE%\.win-setup\setup.log`
- `%USERPROFILE%\.win-setup\registry-backups\<timestamp>\**\*.reg`

Successful actions are skipped on rerun. Changing files under `data/` or `configs/`, or changing optional selections reapplies the setup. Delete `state.json` to force a complete rerun.

## Tests

```powershell
.\tests\run.ps1
```
