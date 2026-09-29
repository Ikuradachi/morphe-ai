# Morphe CLI v1.17.0 — Complete Reference

- Upstream repo: `MorpheApp/morphe-desktop`
- CLI jar: `morphe-cli.jar` (project root, run `./setup-cli.sh` to download)
- Runtime requirement: **JRE 21+**
- Data root: normally `morphe-data/` beside the real jar; writable `MORPHE_DATA_DIR` wins,
  with the documented home/XDG fallback if jar-adjacent storage is unavailable.
  Contains: `patches/`, `logs/`, `tmp/`, and the default keystore `morphe.keystore`.
- Output: always save patched APKs to `analysis/<app>/builds/`

## Signing Key

The CLI signs by default with `morphe.keystore` in the resolved data root. It remains stable
across desktop runs, but it is not automatically the same key stored by Morphe Manager on a
phone. Export/import the key, or configure the same custom `--keystore`, when both environments
must share a signing identity.

**Custom keystore (optional):** Pass `--keystore <path>` for BKS, PKCS12, or JKS. The CLI
byte-sniffs the format; PKCS12/JKS are converted to a separate BKS working copy and the source
file is never modified.

```bash
# Use the stable desktop default key
java -jar morphe-cli.jar patch -p patches.mpp -o out.apk input.apk

# Use an explicitly shared/custom key
java -jar morphe-cli.jar patch -p patches.mpp \
  --keystore my.keystore --keystore-password secret \
  -o out.apk input.apk
```

## Split APK Support

The CLI merges complete split containers before patching:

| Format | Extension | Notes |
|--------|-----------|-------|
| Standard APK | `.apk` | Single complete APK |
| XAPK bundle | `.xapk` | APKPure container |
| APKM bundle | `.apkm` | APKMirror container |
| APKS bundle | `.apks` | Bundletool container |

Pass the complete bundle when one exists. An extracted base APK can be inspected during analysis,
but it cannot provide resources, code, or native libraries that exist only in omitted splits.

## Commands

### patch — Patch an APK

```bash
java -jar morphe-cli.jar patch -p <mpp-or-url> [options] input.apk
```

| Flag | Short | Description |
|------|-------|-------------|
| `--patches` | `-p` | Path to MPP file OR GitHub/GitLab/release URL (required, repeatable) |
| `--out` | `-o` | Output APK path (if omitted, saved next to input in app-named subfolder) |
| `--install` | `-i` | Install via ADB after patching (optional device serial follows) |
| `--enable` | `-e` | Enable patch by name (name flags are scoped to the preceding `--patches`) |
| `--disable` | `-d` | Disable patch by name |
| `--ei` | | Enable patch by index (index is position in the combined list across all bundles) |
| `--di` | | Disable patch by index |
| `--exclusive` | | Disable all except enabled patches |
| `--options` | `-O` | Set patch option: `-Okey=value` |
| `--options-file` | | Path to options JSON file (auto-generated if missing) |
| `--options-update` | | Auto-update options JSON after patching |
| `--force` | `-f` | Skip version compatibility check |
| `--mount` | | Boolean flag — when combined with `-i`, install by mounting (root required) |
| `--unsigned` | | Don't sign the output APK |
| `--keystore` | | Custom keystore file path (BKS, PKCS12, or JKS; byte-sniffed, original unchanged) |
| `--keystore-password` | | Keystore password (empty by default) |
| `--keystore-entry-alias` | | Key alias (default: Morphe) |
| `--keystore-entry-password` | | Key entry password |
| `--signer` | | Signer name (default: Morphe) |
| `--striplibs` | | Keep only specified architectures (comma-separated, e.g. `arm64-v8a,x86`) |
| `--temporary-files-path` | `-t` | Custom temp directory |
| `--result-file` | `-r` | Save JSON patching report to file |
| `--disable-purge` | | Keep scratch files after patching (default is to purge) |
| `--continue-on-error` | | Don't stop on first patch failure |
| `--bytecode-mode` | | DEX processing: FULL, STRIP_SAFE, or STRIP_FAST (default: STRIP_FAST) |
| `--prerelease` | | Fetch dev pre-release from repo URL (use with `--patches <repo-url>`) |
| `--verify-with-sdk` | | Verify patched DEX/APK with Android SDK tools |

#### Examples

```bash
# Basic patch (uses default keystore in morphe-data/)
java -jar morphe-cli.jar patch -p patches.mpp input.apk

# Patch + output + install
java -jar morphe-cli.jar patch -p patches.mpp -o patched.apk -i input.apk

# Patch + mount-install (root) — --mount is a boolean flag combined with -i
java -jar morphe-cli.jar patch -p patches.mpp -o patched.apk -i --mount input.apk

# Exclusive mode (only specific patches)
java -jar morphe-cli.jar patch -p patches.mpp --exclusive -e "Premium Unlock" -e "Remove Ads" \
  -o analysis/app/builds/app_patched.apk -f input.apk

# With options
java -jar morphe-cli.jar patch -p patches.mpp -e "Patch Name" -Okey=value input.apk

# Force version + strip to arm64 only
java -jar morphe-cli.jar patch -p patches.mpp -f --striplibs=arm64-v8a input.apk

# Use GitHub repo URL directly (downloads latest stable release MPP)
java -jar morphe-cli.jar patch -p https://github.com/user/patches input.apk

# Use GitLab repo URL
java -jar morphe-cli.jar patch -p https://gitlab.com/user/patches input.apk

# Use dev pre-release from repo
java -jar morphe-cli.jar patch -p https://github.com/user/patches --prerelease input.apk

# Multiple bundles — name flags apply to the bundle that preceded them
java -jar morphe-cli.jar patch \
  -p https://github.com/user/bundle-a -e "Patch A" \
  -p local-bundle.mpp -e "Patch B" \
  input.apk

# Save patching result report
java -jar morphe-cli.jar patch -p patches.mpp -r result.json input.apk

# Keep temp files for debugging
java -jar morphe-cli.jar patch -p patches.mpp --disable-purge -f input.apk

# Save to analysis builds folder
java -jar morphe-cli.jar patch -p patches.mpp -o analysis/app/builds/app_patched.apk input.apk
```

### list-patches — List available patches

```bash
java -jar morphe-cli.jar list-patches --patches patches.mpp [options]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--patches` | | Path to MPP file (required, repeatable) |
| `--with-packages` | `-p` | Show compatible packages |
| `--with-versions` | `-v` | Show compatible versions |
| `--with-options` | `-o` | Show patch options |
| `--with-descriptions` | `-d` | Show descriptions (default: true) |
| `--with-universal-patches` | `-u` | Show universal patches (default: true) |
| `--index` | `-i` | Show patch index (default: true; index is position in combined list) |
| `--include-experimental` | `-x` | Include experimental app versions |
| `--filter-package-name` | `-f` | Filter by package name |
| `--prerelease` | | Fetch dev pre-release from repo URL |
| `--out` | | Write to file instead of stdout |

#### Examples

```bash
# Full listing
java -jar morphe-cli.jar list-patches --patches patches.mpp -pvo

# Filter by app
java -jar morphe-cli.jar list-patches --patches patches.mpp -f com.truecaller -pvo

# Include experimental versions
java -jar morphe-cli.jar list-patches --patches patches.mpp -pvox

# Save to file
java -jar morphe-cli.jar list-patches --patches patches.mpp -pvo --out patches.txt
```

### list-versions — Show recommended versions

```bash
java -jar morphe-cli.jar list-versions --patches patches.mpp [options]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--patches` | | Path to MPP file (required, repeatable) |
| `--filter-package-names` | `-f` | Filter by package name (repeatable) |
| `--count-unused-patches` | `-u` | Include non-default patches in count |
| `--include-experimental` | `-x` | Include experimental versions |
| `--prerelease` | | Fetch dev pre-release from repo URL |

#### Examples

```bash
java -jar morphe-cli.jar list-versions --patches patches.mpp
java -jar morphe-cli.jar list-versions --patches patches.mpp -f com.truecaller
java -jar morphe-cli.jar list-versions --patches patches.mpp -ux
```

### options-create — Generate options JSON

```bash
java -jar morphe-cli.jar options-create -p patches.mpp -o options.json
```

| Flag | Short | Description |
|------|-------|-------------|
| `--patches` | `-p` | Path to MPP file (required) |
| `--out` | `-o` | Output JSON file path (required) |
| `--filter-package-name` | `-f` | Filter by package name |
| `--prerelease` | | Fetch dev pre-release from repo URL |

Note: If `--options-file` is passed to `patch` but the file doesn't exist, it is auto-generated
from the MPP before patching begins.

### utility install — Install APK via ADB

```bash
java -jar morphe-cli.jar utility install -a app.apk [options] [deviceSerials...]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--apk` | `-a` | APK file to install (required) |
| `--mount` | `-m` | Mount over existing app; takes package name as argument |
| `--route-links` | | Route app's supported web links to it ("open with") |
| `--disable-stock` | | With --route-links: takes stock package name; stops it from handling those links |

#### Examples

```bash
# Standard install
java -jar morphe-cli.jar utility install -a analysis/app/builds/app_patched.apk

# Install on specific device
java -jar morphe-cli.jar utility install -a app_patched.apk ABC123DEF

# Mount install (root) — -m takes the package name
java -jar morphe-cli.jar utility install -a app_patched.apk -m com.example.app

# Install + route links (--disable-stock takes the stock package name)
java -jar morphe-cli.jar utility install -a app_patched.apk \
  --route-links --disable-stock com.example.app
```

### utility uninstall — Uninstall app

```bash
java -jar morphe-cli.jar utility uninstall -p com.example.app [options] [deviceSerials...]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--package-name` | `-p` | Package name (required) |
| `--unmount` | `-u` | Unmount instead of uninstall |

### utility clear-cache — Delete cached files

⚠ **Mutating command — run only when explicitly requested.** It deletes cached files
immediately with no confirmation prompt. Use `--help` to inspect flags safely:

```bash
java -jar morphe-cli.jar utility clear-cache --help
```

| Flag | Description |
|------|-------------|
| `--info` | Show per-category breakdown of what was cleared and space freed |

## Quick Workflow

```bash
# 1. Build patches
PATCHES_DIR="${MORPHE_PATCHES_DIR:-morphe-patches}"
cd "${PATCHES_DIR}" && ./gradlew buildAndroid && cd ..

# 2. Get MPP path
VER=$(grep "^version" "${PATCHES_DIR}/gradle.properties" | cut -d= -f2 | tr -d ' ')
MPP="${PATCHES_DIR}/patches/build/libs/patches-${VER}.mpp"

# 3. List what's available
java -jar morphe-cli.jar list-patches --patches "$MPP" -pvo

# 4. Patch an APK (output to builds/, default keystore)
java -jar morphe-cli.jar patch \
  -p "$MPP" \
  -o analysis/app/builds/app_patched.apk \
  -f analysis/app/apk/app_version.apk

# 5. Install
java -jar morphe-cli.jar utility install -a analysis/app/builds/app_patched.apk
```
