#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export PATH="$HOME/.local/bin:$PATH"

if [[ "$(uname -s)" != 'Linux' || ! -r /etc/os-release ]]; then
    echo 'Error: run this script inside Ubuntu/WSL, not PowerShell or Git Bash.' >&2
    exit 1
fi
command -v apt-get >/dev/null 2>&1 || { echo 'Error: apt-get missing; Ubuntu is required.' >&2; exit 1; }

if ((EUID == 0)); then
    SUDO=()
else
    command -v sudo >/dev/null 2>&1 || { echo 'Error: sudo is required.' >&2; exit 1; }
    sudo -v
    SUDO=(sudo)
fi

echo '==> Updating Ubuntu packages'
"${SUDO[@]}" apt-get update
"${SUDO[@]}" apt-get dist-upgrade -y
"${SUDO[@]}" apt-get autoremove --purge -y
"${SUDO[@]}" apt-get clean

"${SUDO[@]}" apt-get install -y ca-certificates curl

MISE_BIN="$(command -v mise 2>/dev/null || true)"
if [[ -z "$MISE_BIN" && -x "$HOME/.local/bin/mise" ]]; then
    MISE_BIN="$HOME/.local/bin/mise"
fi

if [[ -z "$MISE_BIN" ]]; then
    echo '==> Installing mise'
    curl --fail --silent --show-error --location --retry 3 https://mise.run | sh
    MISE_BIN="$HOME/.local/bin/mise"
fi

BASHRC="$HOME/.bashrc"
touch "$BASHRC"
MISE_ACTIVATION='eval "$("$HOME/.local/bin/mise" activate bash)"'
if ! grep -Fqx "$MISE_ACTIVATION" "$BASHRC"; then
    printf '\n%s\n' "$MISE_ACTIVATION" >> "$BASHRC"
fi

# Refresh this noninteractive process now; future Bash shells auto-activate via .bashrc.
eval "$("$MISE_BIN" env -s bash)"
hash -r

echo '==> Updating mise and managed tools'
if ! "$MISE_BIN" self-update --yes; then
    echo 'Warning: mise self-update unavailable; OS package manager may own this install.' >&2
fi
"$MISE_BIN" upgrade --bump
eval "$("$MISE_BIN" env -s bash)"

echo 'System and mise update complete. New Bash shells auto-load mise.'
