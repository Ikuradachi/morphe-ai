# MorpheApp Project Overview

Morphe is an Android app modification/patching ecosystem. It modifies APK bytecode and resources to add features, remove limitations, and customize apps.

## Repository Architecture

| Repo | Purpose | Language |
|------|---------|----------|
| morphe-patcher | Core patcher engine (bytecode/resource manipulation via Smali + Apktool) | Kotlin |
| morphe-patches | Official patches (YouTube/Music/Reddit) | Kotlin + Java |
| morphe-patches-template | Template repo for creating custom patch bundles | Kotlin |
| morphe-desktop | Terminal-based patching tool (formerly morphe-cli) | Kotlin |
| morphe-library | Shared utilities (APK signing, installation, ADB) | Kotlin (KMP) |
| morphe-patches-library | Shared code for patch bundles | Java |
| morphe-patches-gradle-plugin | Gradle plugin `app.morphe.patches` for building patches | Kotlin |

## Key Concepts
- **Patch**: Code that modifies an APK. Types: `BytecodePatch`, `ResourcePatch`, `RawResourcePatch`
- **Fingerprint**: Partial method description used to locate obfuscated methods across app updates
- **Extension**: Precompiled DEX file merged into the patched app (complex Java/Kotlin logic)
- **MPP file**: Morphe Patches Package — a JAR containing patches + DEX for Android execution
- **Compatibility**: Declares which app package/versions a patch targets

## Build System
- Gradle with Kotlin DSL
- Plugin: `app.morphe.patches` (settings plugin)
- Registry: `maven.pkg.github.com/MorpheApp/registry` (requires GitHub PAT with `read:packages`)
- Auth: `~/.gradle/gradle.properties` with `gpr.user` and `gpr.key`
- JDK 17 for development, JVM 11 target for compiled patches
- `./gradlew buildAndroid` compiles patches to MPP (JAR + DEX)

## Our Patches Repo
- `paresh-patches/` — custom patches for various apps
- Dev branch for work, main for releases
- Check existing apps: `find paresh-patches/patches/src/main/kotlin/app/paresh/patches/ -maxdepth 1 -type d`

## License
- GPLv3 with Section 7 restrictions: name "Morphe" cannot be used for derivative works
