#!/usr/bin/env bash
set -Eeuo pipefail

BIN_DIR="$HOME/.local/bin"
INSTALL_DIR="$HOME/.local/share/morphe-tools"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export DEBIAN_FRONTEND=noninteractive
export PATH="$BIN_DIR:$PATH"
mkdir -p "$BIN_DIR" "$INSTALL_DIR"

if [[ "$(uname -s)" != 'Linux' || ! -r /etc/os-release ]]; then
    echo 'Error: run this script inside Ubuntu/WSL, not PowerShell or Git Bash.' >&2
    exit 1
fi
command -v apt-get >/dev/null 2>&1 || { echo 'Error: apt-get missing; Ubuntu is required.' >&2; exit 1; }

# Make mise-provided Java visible when this script runs standalone.
MISE_BIN="$(command -v mise 2>/dev/null || true)"
if [[ -z "$MISE_BIN" && -x "$HOME/.local/bin/mise" ]]; then
    MISE_BIN="$HOME/.local/bin/mise"
fi
if [[ -n "$MISE_BIN" ]]; then
    eval "$("$MISE_BIN" env -s bash)"
fi

missing_packages=()
command -v curl >/dev/null 2>&1 || missing_packages+=(curl ca-certificates)
command -v jq >/dev/null 2>&1 || missing_packages+=(jq)
command -v unzip >/dev/null 2>&1 || missing_packages+=(unzip)
command -v java >/dev/null 2>&1 || missing_packages+=(default-jre-headless)

if ((${#missing_packages[@]})); then
    if ((EUID == 0)); then
        SUDO=()
    else
        command -v sudo >/dev/null 2>&1 || { echo 'Error: sudo is required to install dependencies.' >&2; exit 1; }
        sudo -v
        SUDO=(sudo)
    fi
    echo '==> Installing missing Ubuntu dependencies'
    "${SUDO[@]}" apt-get update
    "${SUDO[@]}" apt-get install -y "${missing_packages[@]}"
fi

CURL_ARGS=(--fail --silent --show-error --location --retry 3 --retry-all-errors)
GITHUB_TOKEN_VALUE="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
GITHUB_HEADERS=(-H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28')
if [[ -n "$GITHUB_TOKEN_VALUE" ]]; then
    GITHUB_HEADERS+=(-H "Authorization: Bearer $GITHUB_TOKEN_VALUE")
fi

fetch_release() {
    local repo="$1"
    local output="$2"
    curl "${CURL_ARGS[@]}" "${GITHUB_HEADERS[@]}" \
        "https://api.github.com/repos/$repo/releases/latest" -o "$output"
    jq -e '.tag_name and (.assets | type == "array")' "$output" >/dev/null
}

asset_url() {
    local release_json="$1"
    local regex="$2"
    jq -er --arg regex "$regex" \
        '[.assets[] | select(.name | test($regex)) | .browser_download_url][0] // empty' \
        "$release_json"
}

download() {
    local url="$1"
    local output="$2"
    curl "${CURL_ARGS[@]}" "$url" -o "$output"
}

install_tree() {
    local source_dir="$1"
    local name="$2"
    local next="$INSTALL_DIR/$name.next"
    local current="$INSTALL_DIR/$name"
    local previous="$INSTALL_DIR/$name.previous"

    rm -rf "$next" "$previous"
    mv "$source_dir" "$next"
    if [[ -e "$current" ]]; then
        mv "$current" "$previous"
    fi
    if mv "$next" "$current"; then
        rm -rf "$previous"
    else
        [[ ! -e "$previous" ]] || mv "$previous" "$current"
        return 1
    fi
}

JADX_JSON="$TMP_DIR/jadx.json"
APKTOOL_JSON="$TMP_DIR/apktool.json"
SMALI_JSON="$TMP_DIR/smali.json"
D2J_JSON="$TMP_DIR/dex2jar.json"

echo '==> Resolving latest official releases'
fetch_release 'skylot/jadx' "$JADX_JSON"
fetch_release 'iBotPeaches/Apktool' "$APKTOOL_JSON"
fetch_release 'baksmali/smali' "$SMALI_JSON"
fetch_release 'ThexXTURBOXx/dex2jar' "$D2J_JSON"

echo "    JADX:     $(jq -r .tag_name "$JADX_JSON")"
echo "    Apktool:  $(jq -r .tag_name "$APKTOOL_JSON")"
echo "    Smali:    $(jq -r .tag_name "$SMALI_JSON")"
echo "    Dex2Jar:  $(jq -r .tag_name "$D2J_JSON")"

echo '==> Installing JADX'
JADX_ZIP="$TMP_DIR/jadx.zip"
download "$(asset_url "$JADX_JSON" '^jadx-[0-9].*\.zip$')" "$JADX_ZIP"
unzip -tq "$JADX_ZIP" >/dev/null
mkdir "$TMP_DIR/jadx-extract"
unzip -q "$JADX_ZIP" -d "$TMP_DIR/jadx-extract"
JADX_EXEC="$(find "$TMP_DIR/jadx-extract" -type f -path '*/bin/jadx' -print -quit)"
[[ -n "$JADX_EXEC" ]] || { echo 'Error: JADX executable missing from release.' >&2; exit 1; }
JADX_ROOT="$(cd -- "$(dirname -- "$JADX_EXEC")/.." && pwd -P)"
chmod +x "$JADX_ROOT/bin/jadx" "$JADX_ROOT/bin/jadx-gui"
install_tree "$JADX_ROOT" 'jadx'
ln -sfn "$INSTALL_DIR/jadx/bin/jadx" "$BIN_DIR/jadx"
ln -sfn "$INSTALL_DIR/jadx/bin/jadx-gui" "$BIN_DIR/jadx-gui"

echo '==> Installing Apktool'
APKTOOL_JAR="$TMP_DIR/apktool.jar"
download "$(asset_url "$APKTOOL_JSON" '^apktool_[0-9].*\.jar$')" "$APKTOOL_JAR"
java -jar "$APKTOOL_JAR" --version >/dev/null
install -m 0644 "$APKTOOL_JAR" "$INSTALL_DIR/apktool.jar"
cat > "$BIN_DIR/apktool" <<'EOF'
#!/usr/bin/env bash
exec java -jar "$HOME/.local/share/morphe-tools/apktool.jar" "$@"
EOF
chmod +x "$BIN_DIR/apktool"

echo '==> Installing Smali and Baksmali'
SMALI_JAR="$TMP_DIR/smali.jar"
BAKSMALI_JAR="$TMP_DIR/baksmali.jar"
download "$(asset_url "$SMALI_JSON" '^smali-[0-9].*fat.*\.jar$')" "$SMALI_JAR"
download "$(asset_url "$SMALI_JSON" '^baksmali-[0-9].*fat.*\.jar$')" "$BAKSMALI_JAR"
java -jar "$SMALI_JAR" --version >/dev/null
java -jar "$BAKSMALI_JAR" --version >/dev/null
install -m 0644 "$SMALI_JAR" "$INSTALL_DIR/smali.jar"
install -m 0644 "$BAKSMALI_JAR" "$INSTALL_DIR/baksmali.jar"
cat > "$BIN_DIR/smali" <<'EOF'
#!/usr/bin/env bash
exec java -jar "$HOME/.local/share/morphe-tools/smali.jar" "$@"
EOF
cat > "$BIN_DIR/baksmali" <<'EOF'
#!/usr/bin/env bash
exec java -jar "$HOME/.local/share/morphe-tools/baksmali.jar" "$@"
EOF
chmod +x "$BIN_DIR/smali" "$BIN_DIR/baksmali"

echo '==> Installing Dex2Jar'
D2J_ZIP="$TMP_DIR/dex2jar.zip"
download "$(asset_url "$D2J_JSON" '\.zip$')" "$D2J_ZIP"
unzip -tq "$D2J_ZIP" >/dev/null
mkdir "$TMP_DIR/dex2jar-extract"
unzip -q "$D2J_ZIP" -d "$TMP_DIR/dex2jar-extract"
D2J_EXEC="$(find "$TMP_DIR/dex2jar-extract" -type f -name 'd2j-dex2jar.sh' -print -quit)"
[[ -n "$D2J_EXEC" ]] || { echo 'Error: d2j-dex2jar.sh missing from release.' >&2; exit 1; }
D2J_ROOT="$(dirname -- "$D2J_EXEC")"
find "$D2J_ROOT" -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} +
for old_link in "$BIN_DIR"/*; do
    [[ -L "$old_link" ]] || continue
    old_target="$(readlink -- "$old_link")"
    [[ "$old_target" == "$INSTALL_DIR/dex2jar/"* ]] || continue
    rm -f "$old_link"
done
install_tree "$D2J_ROOT" 'dex2jar'
while IFS= read -r script; do
    name="$(basename -- "$script" .sh)"
    ln -sfn "$script" "$BIN_DIR/$name"
done < <(find "$INSTALL_DIR/dex2jar" -maxdepth 1 -type f -name '*.sh' -print)

hash -r
echo "Reverse-engineering tools installed in $INSTALL_DIR; launchers in $BIN_DIR."
