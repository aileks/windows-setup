#!/usr/bin/env bash
set -euo pipefail

linux_user="$1"
repo_path="$2"
relay_path="$3"
home_dir="$(getent passwd "$linux_user" | cut -d: -f6)"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  bat build-essential ca-certificates curl eza fastfetch fd-find fzf git iproute2 jq \
  openssh-client ripgrep socat starship unzip zoxide zsh

install -d -m 0755 -o "$linux_user" -g "$linux_user" \
  "$home_dir/.config" "$home_dir/.config/bat/themes" "$home_dir/.config/win-setup" \
  "$home_dir/.local/bin" "$home_dir/projects"

backup_and_link() {
  local source="$1"
  local destination="$2"
  if [[ -L "$destination" ]] && [[ "$(readlink "$destination")" == "$source" ]]; then
    return
  fi
  if [[ -e "$destination" || -L "$destination" ]]; then
    mv "$destination" "$destination.bak-$(date +%Y%m%d-%H%M%S)"
  fi
  ln -s "$source" "$destination"
}

backup_and_link "$repo_path/configs/wsl/zshrc" "$home_dir/.zshrc"
backup_and_link "$repo_path/configs/wsl/bitwarden-ssh-agent.zsh" "$home_dir/.config/win-setup/bitwarden-ssh-agent.zsh"
backup_and_link "$repo_path/configs/starship/starship.toml" "$home_dir/.config/starship.toml"
backup_and_link "$repo_path/configs/bat/config" "$home_dir/.config/bat/config"
backup_and_link "$repo_path/configs/bat/ashen.tmTheme" "$home_dir/.config/bat/themes/ashen.tmTheme"

if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  ln -sfn /usr/bin/batcat "$home_dir/.local/bin/bat"
fi
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  ln -sfn /usr/bin/fdfind "$home_dir/.local/bin/fd"
fi
if [[ ! -f "$relay_path" ]]; then
  echo "npiperelay executable not found: $relay_path" >&2
  exit 1
fi
ln -sfn "$relay_path" "$home_dir/.local/bin/npiperelay.exe"

if [[ -e /etc/wsl.conf ]] && ! cmp -s "$repo_path/configs/wsl/wsl.conf" /etc/wsl.conf; then
  cp -a /etc/wsl.conf "/etc/wsl.conf.bak-$(date +%Y%m%d-%H%M%S)"
fi
install -m 0644 "$repo_path/configs/wsl/wsl.conf" /etc/wsl.conf
chown -h "$linux_user:$linux_user" \
  "$home_dir/.zshrc" "$home_dir/.config/win-setup/bitwarden-ssh-agent.zsh" \
  "$home_dir/.config/starship.toml" "$home_dir/.config/bat/config" \
  "$home_dir/.config/bat/themes/ashen.tmTheme" "$home_dir/.local/bin"/* 2>/dev/null || true
chsh -s /usr/bin/zsh "$linux_user"

su - "$linux_user" -c 'git config --global init.defaultBranch main'
su - "$linux_user" -c 'git config --global core.autocrlf input'
su - "$linux_user" -c 'git config --global pull.rebase true'
su - "$linux_user" -c 'git config --global rebase.autoStash true'
su - "$linux_user" -c 'git config --global fetch.prune true'
su - "$linux_user" -c 'git config --global push.autoSetupRemote true'
su - "$linux_user" -c 'git config --global merge.conflictStyle zdiff3'
su - "$linux_user" -c 'git config --global diff.algorithm histogram'
su - "$linux_user" -c 'git config --global rerere.enabled true'
su - "$linux_user" -c 'git config --global commit.verbose true'
su - "$linux_user" -c 'git config --global branch.sort -committerdate'
su - "$linux_user" -c 'git config --global tag.sort version:refname'

bat_binary="$(command -v bat || command -v batcat || true)"
if [[ -n "$bat_binary" ]]; then
  su - "$linux_user" -c "'$bat_binary' cache --build" || true
fi
