#!/usr/bin/env bash
# update-tools.sh — All-in-one updater for MorpheAI, patch repositories, RE tools, and REA MCP
set -euo pipefail

# ANSI color codes
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_FILE")" >/dev/null 2>&1 && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-$SCRIPT_DIR}"
REA_JADX_MCP_VERSION="0.7.1"

# Load local workspace environment if present
if [ -f "$WORKSPACE_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$WORKSPACE_DIR/.env"
  set +a
fi

mkdir -p "$HOME/.local/bin" "$HOME/.local/share"

step() {
  echo -e "\n${BOLD}${BLUE}==>${NC} ${BOLD}$1${NC}"
}

ok() {
  echo -e "  ${GREEN}✓${NC} $1"
}

info() {
  echo -e "  ${CYAN}ℹ${NC} $1"
}

warn() {
  echo -e "  ${YELLOW}⚠${NC} $1"
}

error() {
  echo -e "  ${RED}✗${NC} $1"
}

echo -e "${BOLD}${CYAN}==============================================${NC}"
echo -e "${BOLD}${CYAN}   MorpheAI & RE Toolchain Updater            ${NC}"
echo -e "${BOLD}${CYAN}==============================================${NC}"

# 1. Update MorpheAI Workspace
step "1. Updating MorpheAI Workspace Repository"
if [ -d "$WORKSPACE_DIR/.git" ]; then
  cd "$WORKSPACE_DIR"
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    warn "Uncommitted changes detected in MorpheAI workspace. Skipping pull to protect local work."
  else
    info "Pulling latest changes on branch: $CURRENT_BRANCH..."
    if GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" git pull --rebase origin "$CURRENT_BRANCH" 2>/dev/null; then
      ok "MorpheAI workspace is up to date."
    else
      warn "Failed to pull MorpheAI workspace cleanly (offline or credentials required). Continuing..."
    fi
  fi
else
  warn "MorpheAI workspace is not a git repository at $WORKSPACE_DIR"
fi

# 2. Update Patch Repositories
step "2. Updating Patch Repositories"
for dir in "$WORKSPACE_DIR"/*/; do
  if [ -d "$dir/.git" ] && [ -f "$dir/build.gradle.kts" -o -d "$dir/patches" ]; then
    REPO_NAME=$(basename "$dir")
    info "Updating patch repository: $REPO_NAME..."
    BRANCH=$(git -C "$dir" branch --show-current 2>/dev/null || echo "main")
    if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
      warn "Uncommitted changes in $REPO_NAME. Skipping pull to protect local work."
    else
      if GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" git -C "$dir" pull --rebase origin "$BRANCH" 2>/dev/null; then
        ok "$REPO_NAME is up to date."
      else
        warn "Could not update $REPO_NAME (offline or credentials required). Continuing..."
      fi
    fi
  fi
done

# 3. Update Morphe CLI (morphe-cli.jar)
step "3. Updating Morphe Desktop CLI (morphe-cli.jar)"
if [ -f "$WORKSPACE_DIR/setup-cli.sh" ]; then
  cd "$WORKSPACE_DIR"
  bash "$WORKSPACE_DIR/setup-cli.sh" download
  ok "Morphe CLI check completed."
else
  warn "setup-cli.sh not found in $WORKSPACE_DIR"
fi

# 4. Update JADX Decompiler
step "4. Checking for JADX Updates"
CURRENT_JADX=$(jadx --version 2>/dev/null | head -n1 || echo "none")
LATEST_TAG=$(python3 -c "import urllib.request, json; req=urllib.request.Request('https://api.github.com/repos/skylot/jadx/releases/latest', headers={'User-Agent':'morphe-updater'}); print(json.loads(urllib.request.urlopen(req, timeout=5).read())['tag_name'])" 2>/dev/null || echo "")
LATEST_JADX="${LATEST_TAG#v}"

if [ -n "$LATEST_JADX" ]; then
  if [ "$CURRENT_JADX" = "$LATEST_JADX" ]; then
    ok "JADX is up to date (v${CURRENT_JADX})."
  else
    info "Upgrading JADX from v${CURRENT_JADX} to v${LATEST_JADX}..."
    TMP_ZIP=$(mktemp /tmp/jadx-XXXXXX.zip)
    curl -sL "https://github.com/skylot/jadx/releases/download/v${LATEST_JADX}/jadx-${LATEST_JADX}.zip" -o "$TMP_ZIP"
    mkdir -p "$HOME/.local/share/jadx"
    unzip -qo "$TMP_ZIP" -d "$HOME/.local/share/jadx"
    ln -sf "$HOME/.local/share/jadx/bin/jadx" "$HOME/.local/bin/jadx"
    ln -sf "$HOME/.local/share/jadx/bin/jadx-gui" "$HOME/.local/bin/jadx-gui"
    rm -f "$TMP_ZIP"
    ok "JADX upgraded to v${LATEST_JADX}."
  fi
else
  warn "Unable to fetch latest JADX version from GitHub API. Keeping current (v${CURRENT_JADX})."
fi

# 5. Update REA (Reverse Engineer Anything)
step "5. Updating REA (Reverse Engineer Anything)"
CURRENT_REA=$(rea --version 2>/dev/null || echo "none")
info "Current REA version: $CURRENT_REA"
info "Running npm update for rea-agents..."
npm install -g rea-agents@latest --silent 2>/dev/null || npm install -g rea-agents@latest
NEW_REA=$(rea --version 2>/dev/null || echo "unknown")
ok "REA is ready at v${NEW_REA}."

# Ensure REA headless MCP jar exists
REA_JADX_INFO=$(python3 -c "
import os, re, subprocess
try:
    rea_bin = subprocess.check_output(['which', 'rea'], stderr=subprocess.DEVNULL).decode().strip()
    rea_real = os.path.realpath(rea_bin)
    rea_pkg_dir = os.path.dirname(os.path.dirname(rea_real))
    jadx_release_file = os.path.join(rea_pkg_dir, 'dist', 'android', 'JadxRelease.js')
    ver = '${REA_JADX_MCP_VERSION}'
    url = f'https://github.com/1013503897/jadx-headless-mcp/releases/download/v{ver}/jadx-headless-mcp-{ver}-all.jar'
    if os.path.exists(jadx_release_file):
        txt = open(jadx_release_file).read()
        m_ver = re.search(r'version:\s*\"([^\"]+)\"', txt)
        m_url = re.search(r'url:\s*\"([^\"]+)\"', txt)
        if m_ver: ver = m_ver.group(1)
        if m_url: url = m_url.group(1)
    print(f'{ver} {url}')
except Exception:
    print('${REA_JADX_MCP_VERSION} https://github.com/1013503897/jadx-headless-mcp/releases/download/v${REA_JADX_MCP_VERSION}/jadx-headless-mcp-${REA_JADX_MCP_VERSION}-all.jar')
" 2>/dev/null || echo "${REA_JADX_MCP_VERSION} https://github.com/1013503897/jadx-headless-mcp/releases/download/v${REA_JADX_MCP_VERSION}/jadx-headless-mcp-${REA_JADX_MCP_VERSION}-all.jar")

read -r DETECTED_REA_JADX_VER DETECTED_REA_JADX_URL <<< "$REA_JADX_INFO"

if [ -n "$DETECTED_REA_JADX_VER" ] && [ "$DETECTED_REA_JADX_VER" != "$REA_JADX_MCP_VERSION" ]; then
  info "Updating REA_JADX_MCP_VERSION in update-tools.sh ($REA_JADX_MCP_VERSION -> $DETECTED_REA_JADX_VER)..."
  sed -i "s/^REA_JADX_MCP_VERSION=.*/REA_JADX_MCP_VERSION=\"$DETECTED_REA_JADX_VER\"/" "$SCRIPT_FILE" 2>/dev/null || true
  REA_JADX_MCP_VERSION="$DETECTED_REA_JADX_VER"
fi

REA_JAR_PATH="$HOME/.local/share/rea/jadx-headless-mcp-${DETECTED_REA_JADX_VER}-all.jar"
if [ ! -f "$REA_JAR_PATH" ]; then
  info "Downloading missing jadx-headless-mcp-${DETECTED_REA_JADX_VER}-all.jar..."
  mkdir -p "$HOME/.local/share/rea"
  curl -sL "$DETECTED_REA_JADX_URL" -o "$REA_JAR_PATH"
  ok "Downloaded JADX headless MCP jar (v${DETECTED_REA_JADX_VER})."
else
  ok "JADX headless MCP jar is ready (v${DETECTED_REA_JADX_VER})."
fi

# 6. Update Native Binary Analysis Tools (Ghidra, Frida, patchelf, LIEF)
step "6. Updating Native Binary Tools (Ghidra, Frida, patchelf, LIEF)"

# Ghidra (version verified by REA)
DETECTED_GHIDRA_VER=$(python3 -c "
import os, re, subprocess
try:
    rea_bin = subprocess.check_output(['which', 'rea'], stderr=subprocess.DEVNULL).decode().strip()
    rea_real = os.path.realpath(rea_bin)
    rea_pkg_dir = os.path.dirname(os.path.dirname(rea_real))
    policy_file = os.path.join(rea_pkg_dir, 'dist', 'ghidra', 'GhidraReleasePolicy.js')
    if os.path.exists(policy_file):
        txt = open(policy_file).read()
        m = re.search(r'SUPPORTED_GHIDRA_VERSION\s*=\s*\"([^\"]+)\"', txt)
        if m: print(m.group(1))
except Exception:
    pass
" 2>/dev/null || echo "12.1.4")
GHIDRA_VER="${DETECTED_GHIDRA_VER:-12.1.4}"
GHIDRA_TARGET_DIR="$HOME/.local/share/ghidra_${GHIDRA_VER}_PUBLIC"

if [ -d "$GHIDRA_TARGET_DIR" ] && [ -x "$GHIDRA_TARGET_DIR/ghidraRun" ]; then
  ok "Ghidra is up to date (v${GHIDRA_VER})."
else
  info "Installing / Updating Ghidra to v${GHIDRA_VER}..."
  GHIDRA_URL=$(python3 -c "
import urllib.request, json
try:
    req = urllib.request.Request('https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/tags/Ghidra_${GHIDRA_VER}_build', headers={'User-Agent':'morphe-updater'})
    data = json.loads(urllib.request.urlopen(req, timeout=5).read())
    for asset in data.get('assets', []):
        if asset['name'].endswith('.zip'):
            print(asset['browser_download_url'])
            break
except Exception:
    pass
" 2>/dev/null || echo "")
  if [ -n "$GHIDRA_URL" ]; then
    TMP_GHIDRA_ZIP=$(mktemp /tmp/ghidra-XXXXXX.zip)
    curl -sL "$GHIDRA_URL" -o "$TMP_GHIDRA_ZIP"
    unzip -qo "$TMP_GHIDRA_ZIP" -d "$HOME/.local/share"
    rm -f "$TMP_GHIDRA_ZIP"
    ln -sfn "$GHIDRA_TARGET_DIR" "$HOME/.local/share/ghidra"
    ln -sfn "$GHIDRA_TARGET_DIR/ghidraRun" "$HOME/.local/bin/ghidraRun"
    ok "Ghidra v${GHIDRA_VER} installed."
  else
    warn "Failed to resolve Ghidra download URL for v${GHIDRA_VER}."
  fi
fi

export GHIDRA_INSTALL_DIR="${GHIDRA_TARGET_DIR}"
if ! grep -q "GHIDRA_INSTALL_DIR" "$WORKSPACE_DIR/.env" 2>/dev/null; then
  echo "GHIDRA_INSTALL_DIR=${GHIDRA_TARGET_DIR}" >> "$WORKSPACE_DIR/.env"
fi

# Frida & frida-tools
if command -v uv >/dev/null 2>&1; then
  info "Checking for Frida & frida-tools updates..."
  uv tool upgrade frida-tools --quiet 2>/dev/null || uv tool install frida-tools --quiet 2>/dev/null || true
  FRIDA_VER=$(frida --version 2>/dev/null || echo "none")
  ok "Frida is ready (v${FRIDA_VER})."
fi

# patchelf
CURRENT_PATCHELF=$(patchelf --version 2>/dev/null | awk '{print $2}' || echo "none")
LATEST_PATCHELF_INFO=$(python3 -c "
import urllib.request, json
try:
    req = urllib.request.Request('https://api.github.com/repos/NixOS/patchelf/releases/latest', headers={'User-Agent':'morphe-updater'})
    data = json.loads(urllib.request.urlopen(req, timeout=5).read())
    tag = data['tag_name']
    url = ''
    for asset in data.get('assets', []):
        if 'x86_64.tar.gz' in asset['name']:
            url = asset['browser_download_url']
            break
    print(f'{tag} {url}')
except Exception:
    pass
" 2>/dev/null || echo "")

read -r LATEST_PATCHELF_TAG LATEST_PATCHELF_URL <<< "$LATEST_PATCHELF_INFO"
if [ -n "$LATEST_PATCHELF_TAG" ] && [ -n "$LATEST_PATCHELF_URL" ]; then
  if [ "$CURRENT_PATCHELF" = "$LATEST_PATCHELF_TAG" ]; then
    ok "patchelf is up to date (v${CURRENT_PATCHELF})."
  else
    info "Installing / Updating patchelf (current: v${CURRENT_PATCHELF}, latest: v${LATEST_PATCHELF_TAG})..."
    TMP_DIR=$(mktemp -d /tmp/patchelf-XXXXXX)
    curl -sL "$LATEST_PATCHELF_URL" | tar -xz -C "$TMP_DIR"
    cp "$TMP_DIR/bin/patchelf" "$HOME/.local/bin/patchelf"
    chmod +x "$HOME/.local/bin/patchelf"
    rm -rf "$TMP_DIR"
    ok "patchelf updated to v${LATEST_PATCHELF_TAG}."
  fi
elif [ "$CURRENT_PATCHELF" != "none" ]; then
  ok "patchelf is present (v${CURRENT_PATCHELF})."
else
  warn "patchelf is not installed and latest release could not be resolved."
fi

# LIEF & pyelftools
if command -v uv >/dev/null 2>&1; then
  if [ ! -d "$HOME/.local/share/binanalysis" ]; then
    info "Initializing python environment for binary analysis at $HOME/.local/share/binanalysis..."
    uv venv "$HOME/.local/share/binanalysis" --quiet 2>/dev/null || true
  fi
  if [ -d "$HOME/.local/share/binanalysis" ]; then
    info "Updating LIEF and pyelftools..."
    uv pip install --python "$HOME/.local/share/binanalysis/bin/python" --upgrade lief pyelftools --quiet 2>/dev/null || true
    ok "LIEF and pyelftools are ready."
  fi
else
  warn "uv not found; skipping LIEF and pyelftools installation."
fi

# 7. Update Mise Managed Runtimes
step "7. Updating Mise Managed Tools (Java, ripgrep, uv)"
if command -v mise >/dev/null 2>&1; then
  mise upgrade
  ok "Mise runtimes updated."
elif [ -x "$HOME/.local/bin/mise" ]; then
  "$HOME/.local/bin/mise" upgrade
  ok "Mise runtimes updated."
else
  info "Mise not found, skipping runtime upgrade."
fi

# 8. Diagnostic Health Checks
step "8. Running Health Diagnostics"
echo -e "\n${BOLD}[1/2] Morphe Doctor Check:${NC}"
cd "$WORKSPACE_DIR"
bash plugins/morphe-patch-creator/scripts/doctor.sh

echo -e "\n${BOLD}[2/2] REA MCP Doctor Check:${NC}"
rea mcp doctor

echo -e "\n${BOLD}${GREEN}==============================================${NC}"
echo -e "${BOLD}${GREEN}   All Tools and Repositories are Up to Date! ${NC}"
echo -e "${BOLD}${GREEN}==============================================${NC}\n"
