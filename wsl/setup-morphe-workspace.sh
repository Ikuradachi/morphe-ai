#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-35}"
ANDROID_BUILD_TOOLS_VERSION="${ANDROID_BUILD_TOOLS_VERSION:-35.0.0}"

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

echo '=================================================='
echo ' Morphe AI Environment Automation Setup'
echo '=================================================='

echo '==> Installing Ubuntu dependencies'
"${SUDO[@]}" apt-get update
"${SUDO[@]}" apt-get install -y ca-certificates curl git jq unzip zip

MISE_BIN="$(command -v mise 2>/dev/null || true)"
if [[ -z "$MISE_BIN" && -x "$HOME/.local/bin/mise" ]]; then
    MISE_BIN="$HOME/.local/bin/mise"
fi
if [[ -z "$MISE_BIN" ]]; then
    echo '==> Installing mise'
    curl --fail --silent --show-error --location --retry 3 https://mise.run | sh
    MISE_BIN="$HOME/.local/bin/mise"
fi

echo '==> Installing runtimes and Android SDK'
"$MISE_BIN" use --global \
    java@temurin-17 \
    ripgrep@latest \
    uv@latest \
    android-sdk@latest

# Load global mise environment in this process. `activate` alone needs a prompt hook.
eval "$("$MISE_BIN" env -s bash)"
hash -r

ANDROID_HOME="$("$MISE_BIN" where android-sdk)"
export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/build-tools/$ANDROID_BUILD_TOOLS_VERSION:$PATH"

echo '==> Accepting Android SDK licenses'
# `yes` normally exits 141 after sdkmanager closes its pipe; use last command status.
run_sdkmanager_yes() {
    (set +o pipefail; yes | "$MISE_BIN" exec android-sdk -- sdkmanager --sdk_root="$ANDROID_HOME" "$@")
}

if ! run_sdkmanager_yes --licenses; then
    echo 'Error: Android license acceptance failed.' >&2
    exit 1
fi

echo '==> Installing Android SDK packages'
run_sdkmanager_yes \
    'platform-tools' \
    "platforms;android-$ANDROID_API_LEVEL" \
    "build-tools;$ANDROID_BUILD_TOOLS_VERSION"

echo '==> Installing isolated Python tools'
"$MISE_BIN" exec -- uv tool install --upgrade kaggle
"$MISE_BIN" exec -- uv tool install --upgrade apkid --python 3.12

echo '==> Configuring Bash auto-activation'
BASHRC="$HOME/.bashrc"
touch "$BASHRC"
START_MARKER='# >>> morphe environment >>>'
END_MARKER='# <<< morphe environment <<<'
TMP_BASHRC="$(mktemp)"
trap 'rm -f "$TMP_BASHRC"' EXIT

awk -v start="$START_MARKER" -v end="$END_MARKER" '
    $0 == start { skip = 1; next }
    $0 == end   { skip = 0; next }
    !skip       { print }
' "$BASHRC" > "$TMP_BASHRC"

cat >> "$TMP_BASHRC" <<EOF

$START_MARKER
export PATH="\$HOME/.local/bin:\$PATH"
export ANDROID_BUILD_TOOLS_VERSION="$ANDROID_BUILD_TOOLS_VERSION"
export ANDROID_HOME="\$("\$HOME/.local/bin/mise" where android-sdk 2>/dev/null)"
export ANDROID_SDK_ROOT="\$ANDROID_HOME"
export PATH="\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/build-tools/\$ANDROID_BUILD_TOOLS_VERSION:\$PATH"
eval "\$("\$HOME/.local/bin/mise" activate bash)"
$END_MARKER
EOF
mv "$TMP_BASHRC" "$BASHRC"
trap - EXIT

echo '==> Installing reverse-engineering tools'
bash "$SCRIPT_DIR/reverse-tools.sh"

eval "$("$MISE_BIN" env -s bash)"
hash -r

echo '==> Running diagnostics'
if ! bash "$SCRIPT_DIR/check-version.sh"; then
    echo 'Error: setup finished with failed diagnostics.' >&2
    exit 1
fi

echo '=================================================='
echo ' Setup complete. Current run refreshed; new Bash shells auto-load mise.'
echo '=================================================='
