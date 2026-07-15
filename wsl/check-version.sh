#!/usr/bin/env bash
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"
ANDROID_BUILD_TOOLS_VERSION="${ANDROID_BUILD_TOOLS_VERSION:-35.0.0}"

# `mise activate` needs an interactive prompt hook. `mise env` works in scripts.
MISE_BIN="$(command -v mise 2>/dev/null || true)"
if [[ -z "$MISE_BIN" && -x "$HOME/.local/bin/mise" ]]; then
    MISE_BIN="$HOME/.local/bin/mise"
fi
if [[ -n "$MISE_BIN" ]]; then
    eval "$("$MISE_BIN" env -s bash)"
fi

if [[ -z "${ANDROID_HOME:-}" && -n "$MISE_BIN" ]]; then
    ANDROID_HOME="$("$MISE_BIN" where android-sdk 2>/dev/null || true)"
    export ANDROID_HOME
fi

if [[ -n "${ANDROID_HOME:-}" ]]; then
    export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
    export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/build-tools/$ANDROID_BUILD_TOOLS_VERSION:$PATH"
fi

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN=''
    RED=''
    BOLD=''
    NC=''
fi

failures=0

check_tool() {
    local label="$1"
    local command_name="$2"
    shift 2

    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[  %bX%b  ] %b%-28s%b %s\n' "$RED" "$NC" "$BOLD" "${label}:" "$NC" 'Not found in PATH'
        failures=$((failures + 1))
        return
    fi

    local output status=0 first_line
    output=$("$@" 2>&1) || status=$?
    first_line=${output%%$'\n'*}
    first_line=${first_line#version }

    if ((status == 0)); then
        printf '[  %bOK%b ] %b%-28s%b %s\n' "$GREEN" "$NC" "$BOLD" "${label}:" "$NC" "${first_line:-installed}"
    else
        printf '[  %bX%b  ] %b%-28s%b %s\n' "$RED" "$NC" "$BOLD" "${label}:" "$NC" "check failed (exit $status)"
        failures=$((failures + 1))
    fi
}

printf '%b%s%b\n' "$BOLD" '==================================================' "$NC"
printf '%b%s%b\n' "$BOLD" '       Morphe AI Environment Diagnostic Check' "$NC"
printf '%b%s%b\n' "$BOLD" '==================================================' "$NC"

printf '\n%b::: Host :::%b\n' "$BOLD" "$NC"
printf '%-34s %s\n' 'Kernel:' "$(uname -srmo 2>/dev/null || uname -a)"
if grep -qi microsoft /proc/version 2>/dev/null; then
    printf '%-34s %s\n' 'WSL:' 'detected'
fi

printf '\n%b::: Core Engine & Runtimes :::%b\n' "$BOLD" "$NC"
check_tool 'Mise Manager' 'mise' mise --version
check_tool 'Java Runtime' 'java' java -version
check_tool 'Ripgrep (rg)' 'rg' rg --version
check_tool 'UV Engine' 'uv' uv --version

printf '\n%b::: Android Build Tools :::%b\n' "$BOLD" "$NC"
check_tool 'SDK Manager' 'sdkmanager' sdkmanager --version
check_tool 'Android Debugger (adb)' 'adb' adb --version
check_tool 'Asset Packaging (aapt)' 'aapt' aapt version
check_tool 'Asset Packaging 2 (aapt2)' 'aapt2' aapt2 version

printf '\n%b::: Python Tools :::%b\n' "$BOLD" "$NC"
check_tool 'Kaggle Automation' 'kaggle' kaggle --version
# APKiD 3.x has no --version flag; --help is its stable zero-exit smoke test.
check_tool 'APKiD Rule Scanner' 'apkid' apkid --help

printf '\n%b::: Decompilation Suite :::%b\n' "$BOLD" "$NC"
check_tool 'JADX Engine' 'jadx' jadx --version
check_tool 'Apktool Compiler' 'apktool' apktool --version
check_tool 'Smali Assembler' 'smali' smali --version
check_tool 'Baksmali Engine' 'baksmali' baksmali --version
check_tool 'Dex2Jar Pipeline' 'd2j-dex2jar' d2j-dex2jar --help

printf '\n%b%s%b\n' "$BOLD" '==================================================' "$NC"
if ((failures > 0)); then
    printf '%b%d check(s) failed.%b\n' "$RED" "$failures" "$NC" >&2
    exit 1
fi
printf '%bAll checks passed.%b\n' "$GREEN" "$NC"
