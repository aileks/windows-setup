#!/usr/bin/env bash
set -euo pipefail

linux_user="$1"
config_root="$2"
relay_path="${3:-}"
home_dir="$(getent passwd "$linux_user" | cut -d: -f6)"

if [[ ! -d "$config_root" ]]; then
  echo "Copied config root not found: $config_root" >&2
  exit 1
fi
chown -R "$linux_user:$linux_user" "$config_root"
find "$config_root" -type d -exec chmod 0755 {} +
find "$config_root" -type f -exec chmod 0644 {} +

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  bat build-essential ca-certificates curl eza fastfetch fd-find fzf git iproute2 jq \
  neovim openssh-client ripgrep socat starship trash-cli unzip zoxide zsh

install -d -m 0755 -o "$linux_user" -g "$linux_user" \
  "$home_dir/.config" "$home_dir/.config/bat/themes" "$home_dir/.config/win-setup" \
  "$home_dir/.local/bin" "$home_dir/Projects"

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

backup_and_link "$config_root/wsl/zshrc" "$home_dir/.zshrc"
backup_and_link "$config_root/nvim" "$home_dir/.config/nvim"
backup_and_link "$config_root/starship/starship.toml" "$home_dir/.config/starship.toml"
backup_and_link "$config_root/bat/config" "$home_dir/.config/bat/config"
backup_and_link "$config_root/bat/ashen.tmTheme" "$home_dir/.config/bat/themes/ashen.tmTheme"

if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  ln -sfn /usr/bin/batcat "$home_dir/.local/bin/bat"
fi

antidote_dir="$home_dir/.antidote"
if [[ -d "$antidote_dir/.git" ]]; then
  echo "Updating antidote..."
  runuser -u "$linux_user" -- git -C "$antidote_dir" pull --ff-only --quiet
elif [[ -e "$antidote_dir" ]]; then
  echo "$antidote_dir exists but is not an Antidote git checkout" >&2
  exit 1
else
  echo "Installing antidote..."
  runuser -u "$linux_user" -- git clone --depth=1 \
    https://github.com/mattmc3/antidote.git "$antidote_dir"
fi

if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  ln -sfn /usr/bin/fdfind "$home_dir/.local/bin/fd"
fi
if [[ -n "$relay_path" ]]; then
  if [[ ! -f "$relay_path" ]]; then
    echo "npiperelay executable not found: $relay_path" >&2
    exit 1
  fi
  backup_and_link "$config_root/wsl/bitwarden-ssh-agent.zsh" \
    "$home_dir/.config/win-setup/bitwarden-ssh-agent.zsh"
  ln -sfn "$relay_path" "$home_dir/.local/bin/npiperelay.exe"
else
  echo "Bitwarden SSH relay unavailable; skipping its Ubuntu shell integration"
  if [[ -L "$home_dir/.config/win-setup/bitwarden-ssh-agent.zsh" ]] && \
     [[ "$(readlink "$home_dir/.config/win-setup/bitwarden-ssh-agent.zsh")" == \
        "$config_root/wsl/bitwarden-ssh-agent.zsh" ]]; then
    rm "$home_dir/.config/win-setup/bitwarden-ssh-agent.zsh"
  fi
  if [[ -L "$home_dir/.local/bin/npiperelay.exe" ]]; then
    existing_relay_target="$(readlink "$home_dir/.local/bin/npiperelay.exe")"
    if [[ "$existing_relay_target" == /mnt/?/*/AppData/Local/Programs/npiperelay/npiperelay.exe ]]; then
      rm "$home_dir/.local/bin/npiperelay.exe"
    fi
  fi
fi

if [[ -e /etc/wsl.conf ]] && ! cmp -s "$config_root/wsl/wsl.conf" /etc/wsl.conf; then
  cp -a /etc/wsl.conf "/etc/wsl.conf.bak-$(date +%Y%m%d-%H%M%S)"
fi
install -m 0644 "$config_root/wsl/wsl.conf" /etc/wsl.conf
chown -h "$linux_user:$linux_user" \
  "$home_dir/.zshrc" "$home_dir/.config/nvim" \
  "$home_dir/.config/win-setup/bitwarden-ssh-agent.zsh" \
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
