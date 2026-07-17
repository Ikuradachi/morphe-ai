# Morphe Patch Development — Quick Reference

Always-loaded context for the morphe workspace.

## Workspace Layout

```
morphe/
├── paresh-patches/              # Our patches repo (dev branch for work, main for releases)
├── analysis/<app>/              # APK analysis folders
│   ├── apk/                     # Original APKs (any format)
│   ├── decompiled/              # Java sources (from jadx)
│   ├── smali/                   # baksmali output
│   ├── builds/                  # Patched APKs
│   └── notes/                   # Analysis docs (recon.md, premium-bypass.md, etc.)
├── MorpheApp/                   # Official repos + community repos (gitignored)
├── morphe-cli.jar               # CLI symlink
├── Morphe.keystore              # Shared signing key
├── AGENTS.md                    # Root agent prompt
└── .kiro/
    ├── agents/                  # Agent configs
    ├── prompts/                 # Agent prompt files
    ├── skills/                  # Skills (on-demand)
    ├── steering/                # Steering files (always loaded per agent)
    └── jadx-decompile           # Remote decompiler script (Kaggle)
```

## Agents (6)

| Agent | Job |
|-------|-----|
| morphe | Root orchestrator — routes to correct agent |
| apk-recon | Quick APK identification (aapt, apkid) |
| apk-decompiler | Remote decompile via Kaggle |
| target-hunter | Search decompiled code + verify smali |
| patch-writer | Write Kotlin patches |
| patch-deployer | Build, test, deploy |

## Key Commands

```bash
# Build
cd paresh-patches && ./gradlew buildAndroid && cd ..

# Get MPP
VER=$(grep "^version" paresh-patches/gradle.properties | cut -d= -f2 | tr -d ' ')
MPP="paresh-patches/patches/build/libs/patches-${VER}.mpp"

# List patches
java -jar morphe-cli.jar list-patches -p "$MPP" -pvo

# Patch APK (always use original from apk/ folder)
java -jar morphe-cli.jar patch -p "$MPP" --keystore Morphe.keystore \
  -o analysis/<app>/builds/<app>_patched.apk -f analysis/<app>/apk/<app>_<version>.<ext>

# Decompile (Kaggle)
.kiro/jadx-decompile "<direct-download-url>" analysis/<app>/
```

## Git Workflow

- **All development on `dev` branch** — never commit to main directly
- `feat:` → minor release, `fix:` → patch release, `docs:`/`chore:` → no release
- Always `git pull` after push (CI auto-updates CHANGELOG, gradle.properties)
- Merge dev → main only after verified and tested

## Patch Conventions

- Patches in: `paresh-patches/patches/src/main/kotlin/app/paresh/patches/<app>/<category>/`
- Each app: `shared/Constants.kt`, `<category>/Fingerprints.kt`, `<category>/*Patch.kt`
- Always `bytecodePatch` (fastest), `@Suppress("unused")` on vals
- Verify fingerprints against smali, never use obfuscated names
- Use `returnEarly(true)` for simple premium bypasses
- Use `BytecodeUtils` from `app.morphe.util` for advanced operations
