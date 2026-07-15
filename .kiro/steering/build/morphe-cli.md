# Morphe CLI v1.11.0 — Complete Reference

- Upstream repo: `MorpheApp/morphe-desktop` (formerly morphe-cli)
- CLI jar: `morphe-cli.jar` (project root, run `./setup-cli.sh` to download)
- Keystore: `Morphe.keystore` (project root — use `--keystore Morphe.keystore` for all patches)
- Output: always save patched APKs to `analysis/<app>/builds/`

## Commands

### patch — Patch an APK

```bash
java -jar morphe-cli.jar patch -p patches.mpp [options] input.apk
```

| Flag | Short | Description |
|------|-------|-------------|
| `--patches` | `-p` | Path to MPP file OR GitHub/GitLab repo URL (required, repeatable) |
| `--out` | `-o` | Output APK path (if omitted, saved next to input in app-named subfolder) |
| `--install` | `-i` | Install via ADB after patching (optional device serial) |
| `--enable` | `-e` | Enable patch by name |
| `--disable` | `-d` | Disable patch by name |
| `--ei` | | Enable patch by index |
| `--di` | | Disable patch by index |
| `--exclusive` | | Disable all except enabled patches |
| `--options` | `-O` | Set patch option: `-Okey=value` |
| `--options-file` | | Path to options JSON file |
| `--options-update` | | Auto-update options JSON after patching |
| `--force` | `-f` | Skip version compatibility check |
| `--mount` | | Install by mounting (root required) |
| `--unsigned` | | Don't sign the output APK |
| `--keystore` | | Custom keystore file path |
| `--keystore-password` | | Keystore password (empty by default) |
| `--keystore-entry-alias` | | Key alias (default: Morphe) |
| `--keystore-entry-password` | | Key entry password |
| `--signer` | | Signer name (default: Morphe) |
| `--striplibs` | | Keep only specified architectures (comma-separated, e.g. `arm64-v8a,x86`) |
| `--temporary-files-path` | `-t` | Custom temp directory |
| `--result-file` | `-r` | Save JSON patching report to file |
| `--disable-purge` | | Keep scratch files after patching (default is to purge) |
| `--continue-on-error` | | Don't stop on first patch failure |
| `--bytecode-mode` | | DEX processing: FULL, STRIP_SAFE, or STRIP_FAST (default) |
| `--prerelease` | | Fetch dev pre-release from repo URL (use with `--patches <repo-url>`) |
| `--verify-with-sdk` | | Verify patched DEX/APK with Android SDK tools |

#### Examples

```bash
# Basic patch
java -jar morphe-cli.jar patch -p patches.mpp input.apk

# Patch + output + install
java -jar morphe-cli.jar patch -p patches.mpp -o patched.apk -i input.apk

# Exclusive mode (only specific patches)
java -jar morphe-cli.jar patch -p patches.mpp --exclusive -e "Premium Unlock" -e "Remove Ads" input.apk

# With options
java -jar morphe-cli.jar patch -p patches.mpp -e "Patch Name" -Okey=value input.apk

# Force version + strip to arm64 only
java -jar morphe-cli.jar patch -p patches.mpp -f --striplibs=arm64-v8a input.apk

# Use GitHub repo URL directly (downloads MPP automatically)
java -jar morphe-cli.jar patch -p https://github.com/user/patches input.apk

# Use GitLab repo URL
java -jar morphe-cli.jar patch -p https://gitlab.com/user/patches input.apk

# Use pre-release from repo
java -jar morphe-cli.jar patch -p https://github.com/user/patches --prerelease input.apk

# Custom keystore
java -jar morphe-cli.jar patch -p patches.mpp --keystore my.keystore --keystore-password pass input.apk

# Save to analysis builds folder
java -jar morphe-cli.jar patch -p patches.mpp -o analysis/app/builds/app_patched.apk input.apk

# Keep temp files for debugging
java -jar morphe-cli.jar patch -p patches.mpp --disable-purge -f input.apk
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
| `--index` | `-i` | Show patch index (default: true) |
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

### utility install — Install APK via ADB

```bash
java -jar morphe-cli.jar utility install -a app.apk [options] [deviceSerials...]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--apk` | `-a` | APK file to install (required) |
| `--mount` | `-m` | Mount over existing app (provide package name) |
| `--route-links` | | Route app's supported web links to it ("open with") |
| `--disable-stock` | | With --route-links: stop stock package from handling links |

#### Examples

```bash
# Standard install
java -jar morphe-cli.jar utility install -a analysis/app/builds/app_patched.apk

# Install on specific device
java -jar morphe-cli.jar utility install -a app_patched.apk ABC123DEF

# Mount install (root)
java -jar morphe-cli.jar utility install -a app_patched.apk -m com.example.app

# Install + route links
java -jar morphe-cli.jar utility install -a app_patched.apk --route-links --disable-stock com.example.app
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

```bash
java -jar morphe-cli.jar utility clear-cache [options]
```

| Flag | Description |
|------|-------------|
| `--info` | Show per-category breakdown of what was cleared and space freed |

#### Examples

```bash
java -jar morphe-cli.jar utility clear-cache
java -jar morphe-cli.jar utility clear-cache --info
```

## Quick Workflow

```bash
# 1. Build patches
cd paresh-patches && ./gradlew buildAndroid && cd ..

# 2. Get MPP path
VER=$(grep "^version" paresh-patches/gradle.properties | cut -d= -f2 | tr -d ' ')
MPP="paresh-patches/patches/build/libs/patches-${VER}.mpp"

# 3. List what's available
java -jar morphe-cli.jar list-patches --patches "$MPP" -pvo

# 4. Patch an APK (always use Morphe.keystore, output to builds/)
java -jar morphe-cli.jar patch \
  -p "$MPP" \
  --keystore Morphe.keystore \
  -o analysis/app/builds/app_patched.apk \
  -f analysis/app/apk/app_version.apk

# 5. Install
java -jar morphe-cli.jar utility install -a analysis/app/builds/app_patched.apk

# 6. Clear cache when done
java -jar morphe-cli.jar utility clear-cache --info
```
