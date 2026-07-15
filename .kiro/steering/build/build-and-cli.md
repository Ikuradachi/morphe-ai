# Build & CLI Usage

## Prerequisites
- JDK 17 (development), JRE 11+ (runtime)
- GitHub PAT with `read:packages` scope
- `~/.gradle/gradle.properties`:
  ```properties
  gpr.user = <GitHub username>
  gpr.key = <PAT token>
  ```

## Building Patches

```bash
cd morphe-patches-template   # or morphe-patches
./gradlew buildAndroid        # Produces patches/build/libs/patches-<version>.mpp
```

## Building CLI

```bash
cd morphe-desktop
./gradlew build               # Produces build/libs/morphe-desktop-<version>-all.jar
```

## Patching an APK (CLI)

```bash
# Basic patch with all defaults
java -jar morphe-cli.jar patch --patches patches.mpp input.apk

# With output and install
java -jar morphe-cli.jar patch --patches patches.mpp --out morphe.apk input.apk --install

# Enable/disable specific patches
java -jar morphe-cli.jar patch --patches patches.mpp -e "Patch Name" -d "Other Patch" input.apk

# Exclusive mode (only specified patches)
java -jar morphe-cli.jar patch --patches patches.mpp --exclusive -e "Patch Name" input.apk

# By index
java -jar morphe-cli.jar patch --patches patches.mpp --ei 123 --di 456 input.apk

# With patch options
java -jar morphe-cli.jar patch --patches patches.mpp -e "Patch" -Okey=value input.apk

# With options JSON file
java -jar morphe-cli.jar options-create --patches patches.mpp --out options.json
java -jar morphe-cli.jar patch --patches patches.mpp --options-file options.json input.apk
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `patch` | Patch an APK |
| `list-patches` | List available patches |
| `list-compatible-versions` | Show compatible app versions |
| `options-create` | Generate options JSON template |
| `utility install` | Install APK via ADB |
| `utility uninstall` | Uninstall app |

## Quick Dev Script

```bash
#!/bin/sh
cd morphe-desktop && ./gradlew build && cd ..
cd morphe-patches-template && ./gradlew buildAndroid && cd ..
java -Xms152m -jar morphe-desktop/build/libs/morphe-desktop-*-all.jar \
  patch --patches morphe-patches-template/build/libs/patches*.mpp \
  --out morphe.apk $1 --install
```

Run: `./patch input.apk`

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
plugins { id("app.morphe.patches") version "<check gradle/libs.versions.toml>" }
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
dependencies { implementation(libs.gson) }
```

## Version Catalog (`gradle/libs.versions.toml`)
Check actual versions in `paresh-patches/gradle/libs.versions.toml` — don't hardcode here.

## Local Development with Composite Builds
If `morphe-patcher` exists as sibling directory, it's auto-included as composite build via `settings.gradle.kts`.
