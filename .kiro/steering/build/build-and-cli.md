# Build & CLI Usage

## Prerequisites

- **JDK 21** recommended for development (aligns with template CI). The desktop source
  documents JDK 17 as a minimum; using JDK 21 gives you a unified toolchain.
- **JRE 21+** required at runtime by the CLI.
- GitHub PAT with `read:packages` scope
- `~/.gradle/gradle.properties`:
  ```properties
  gpr.user = <GitHub username>
  gpr.key = <PAT token>
  ```

## Building Patches

```bash
PATCHES_DIR="${MORPHE_PATCHES_DIR:-morphe-patches}"
cd "${PATCHES_DIR}" && ./gradlew buildAndroid
# → patches/build/libs/patches-<version>.mpp
```

The template uses:
- Gradle plugin `app.morphe.patches` **1.3.4**
- Patcher **1.14.1**
- Gradle **9.7.1**
- Java 21 CI target

## Patching an APK (CLI)

```bash
# Basic patch (uses default keystore in morphe-data/)
java -jar morphe-cli.jar patch --patches patches.mpp input.apk

# With output and install
java -jar morphe-cli.jar patch --patches patches.mpp --out patched.apk -i input.apk

# Mount install (root) — --mount is a boolean flag combined with -i
java -jar morphe-cli.jar patch --patches patches.mpp --out patched.apk -i --mount input.apk

# Enable/disable specific patches
java -jar morphe-cli.jar patch --patches patches.mpp -e "Patch Name" -d "Other Patch" input.apk

# Exclusive mode (only specified patches)
java -jar morphe-cli.jar patch --patches patches.mpp --exclusive -e "Patch Name" input.apk

# By index (index spans combined list when multiple bundles are loaded)
java -jar morphe-cli.jar patch --patches patches.mpp --ei 123 --di 456 input.apk

# With patch options
java -jar morphe-cli.jar patch --patches patches.mpp -e "Patch" -Okey=value input.apk

# With options JSON file (auto-generated from MPP if file doesn't exist)
java -jar morphe-cli.jar options-create --patches patches.mpp --out options.json
java -jar morphe-cli.jar patch --patches patches.mpp --options-file options.json input.apk

# Multiple bundles — name/option flags follow the bundle they follow; indexes use the combined list
java -jar morphe-cli.jar patch \
  --patches https://github.com/user/bundle-a -e "Patch A" \
  --patches local.mpp -e "Patch B" \
  input.apk
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `patch` | Patch an APK |
| `list-patches` | List available patches |
| `list-versions` | Show recommended app versions |
| `options-create` | Generate options JSON template (`--out` required) |
| `utility install` | Install APK via ADB |
| `utility uninstall` | Uninstall app |

`utility clear-cache` is a **mutating, explicit-only** command — do not include it in
routine workflows. Inspect its flags with `--help` before running.

## Gradle Plugin Config

`settings.gradle.kts`:
```kotlin
pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        maven {
            name = "GitHubPackages"
            url = uri("https://maven.pkg.github.com/MorpheApp/registry")
            credentials {
                username = providers.gradleProperty("gpr.user").orNull ?: System.getenv("GITHUB_ACTOR")
                password = providers.gradleProperty("gpr.key").orNull ?: System.getenv("GITHUB_TOKEN")
            }
        }
        maven { url = uri("https://jitpack.io") }
    }
}
plugins { id("app.morphe.patches") version "1.3.4" }
```

`patches/build.gradle.kts`:
```kotlin
group = "app.mypatches"
patches {
    about {
        name = "My Patches"
        description = "Custom patches"
        source = "git@github.com:user/repo.git"
        author = "Author"
        contact = "na"
        website = "na"
        license = "GPLv3"
    }
}
```

The current template keeps Gson on a dedicated patch-list generator classpath instead of bundling
it into patched apps; copy that configuration from the template rather than adding a normal
`implementation(libs.gson)` dependency.

## Version Catalog (`gradle/libs.versions.toml`)
Check actual versions in `${MORPHE_PATCHES_DIR:-morphe-patches}/gradle/libs.versions.toml` — the
pinned versions above reflect the template at the recorded baseline; always prefer the repo's own
catalog file.

## Local Development with Composite Builds
If `morphe-patcher` exists as sibling directory, it's auto-included as composite build via `settings.gradle.kts`.
