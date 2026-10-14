# MorpheAI Workspace Guidelines for Antigravity & Codex

This workspace automates Android APK reverse engineering, target hunting, Morphe patch authoring, and deployment.

## Multi-Repository Management
- Multiple patch repositories are supported in this workspace.
- The active patches repository is tracked by `MORPHE_PATCHES_DIR` in `.env` and `.morphe/config.json`.
- The initial repository is `carbit-patches` (targeting the `carbit-link` app).
- To inspect or switch active patch repositories, run:
  ```bash
  ./select-repo.sh [repo_name]
  ```

## Available Reverse Engineering Toolchains
1. **Morphe Local Pipeline**:
   - `doctor.sh`: `bash plugins/morphe-patch-creator/scripts/doctor.sh`
   - APK inspection: `bash plugins/morphe-patch-creator/scripts/inspect-apk.sh <apk-path>`
   - Local decompilation: `bash plugins/morphe-patch-creator/scripts/decompile-local.sh <apk-path> analysis/<app>/decompiled`
   - Smali extraction: `bash plugins/morphe-patch-creator/scripts/extract-smali.sh <apk-path> analysis/<app>/smali`
   - Morphe CLI: `java -jar morphe-cli.jar`
   - Patches build: `cd ${MORPHE_PATCHES_DIR:-carbit-patches} && ./gradlew buildAndroid`

2. **REA (Reverse Engineer Anything)**:
   - Available via CLI (`rea ...`) and registered as an MCP server.
   - Use for semantic queries:
     - `rea inspect-android-package <apk-path>`
     - `rea search-android-classes <apk-path> [query]`
     - `rea inspect-android-class <apk-path> <class-name>`
     - `rea inspect-android-method <apk-path> <class> <method>`
     - `rea trace-android-references <apk-path> <class-or-method>`

## Pipeline Stages
```
1. RECON        → Extract APK metadata, permissions, ABIs
2. DECOMPILE    → JADX (Java) + Baksmali (Smali bytecode)
3. HUNT         → Search targets, billing/ad gates, verify with Smali & REA
4. WRITE        → Author Kotlin patches in ${MORPHE_PATCHES_DIR}/patches/src/
5. BUILD+DEPLOY → Build .mpp with Gradle, patch APK with morphe-cli.jar
```
