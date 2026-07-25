# Morphe AI

AI-powered Android APK patching workspace. Multi-agent pipeline that automates: APK analysis → decompilation → target hunting → patch writing → build & deploy.

Built with [Kiro CLI](https://kiro.dev), but the prompts, skills, and steering context are **model-agnostic** — adapt them to any AI coding assistant (Cursor, Copilot, Cline, Aider, Claude Code, etc.).

**Author:** [Paresh Maheshwari](https://github.com/Paresh-Maheshwari)
**Repository:** [morphe-ai](https://github.com/Paresh-Maheshwari/morphe-ai)

## Using with Other AI Models

The real value is in `.kiro/steering/` and `.kiro/prompts/` — portable markdown files you can use with any AI tool:

| Directory | Content |
|-----------|---------|
| `steering/core/` | Project overview, workspace layout |
| `steering/patching/` | Patch writing guides, APIs, extension development |
| `steering/bytecode/` | Smali cheat sheet, fingerprinting, obfuscation guide |
| `steering/patterns/` | Billing bypass, ad blocking, protection bypass patterns |
| `steering/community/` | Patterns learned from 10+ community patch repos |
| `steering/build/` | Build commands, CLI reference, troubleshooting |
| `prompts/` | Agent role prompts (recon, decompiler, hunter, writer, deployer) |
| `skills/` | On-demand knowledge (tool reference, FAQ, examples) |

**To use with your AI tool:**
1. Feed the relevant steering `.md` files as context/rules
2. Use the prompts as system instructions
3. Adapt the agent configs to your tool's format (e.g., `.cursorrules`, `.github/copilot-instructions.md`)

## Prerequisites

- **Kiro CLI** installed and configured
- **JDK 17** — `sudo apt install openjdk-17-jdk`
- **Android RE tools:**

| Tool | Purpose | Install |
|------|---------|---------|
| jadx | Decompile APK → Java source | `sudo apt install jadx` |
| baksmali / smali | Disassemble DEX → smali / Assemble smali → DEX | `sudo apt install libsmali-java` |
| apktool | Decode/rebuild APK resources | `sudo apt install apktool` |
| aapt | Read APK manifest/metadata | `sudo apt install aapt` |
| ripgrep (rg) | Fast regex search | `sudo apt install ripgrep` |
| adb | Install APKs on device | `sudo apt install adb` |
| dex2jar | Convert DEX → JAR | `sudo apt install dex2jar` |
| apkid | Detect obfuscators/packers | `uvx apkid` (no install needed) |
| kaggle | Remote decompilation API | `pip install kaggle` |

Quick install all:
```bash
sudo apt install -y openjdk-17-jdk jadx libsmali-java apktool aapt ripgrep adb dex2jar
pip install kaggle
```

## Quick Setup

```bash
# 1. Clone
git clone https://github.com/Paresh-Maheshwari/morphe-ai.git morphe && cd morphe

# 2. Create .env with your secrets
cp .env.example .env
# Edit .env — add your KAGGLE_API_TOKEN

# 3. Gradle auth (for morphe patcher dependencies)
mkdir -p ~/.gradle
cat >> ~/.gradle/gradle.properties << EOF
gpr.user = <your-github-username>
gpr.key = <github-pat-with-read:packages>
EOF

# 4. Clone your patches repo (folder must be named "paresh-patches")
#    If you use a different name, update all references in .kiro/agents/, .kiro/prompts/, and AGENTS.md
git clone <your-patches-repo> paresh-patches

# 5. Setup CLI (downloads latest from GitHub)
./setup-cli.sh

# 6. Start Kiro
kiro chat
```

## Environment Variables (.env)

| Variable | Required | Where to get |
|----------|----------|--------------|
| `KAGGLE_API_TOKEN` | Yes | https://kaggle.com/settings → API → Create New Token |
| `KAGGLE_KERNEL_ID` | Yes | Your Kaggle username + notebook name (e.g. `myuser/jadx-apk-decompiler`) |
| `GITHUB_TOKEN` | Yes (for gradle) | GitHub → Settings → Developer → PAT with `read:packages` |

## Kaggle Setup (Remote Decompilation)

The `jadx-decompile` script runs decompilation on Kaggle's free servers (4 cores, 28GB RAM) because jadx needs a lot of memory for large APKs.

### How it works
1. You provide a **direct download URL** of the APK (not a webpage link)
2. Script generates a Kaggle notebook that downloads the APK and runs jadx
3. Pushes notebook to Kaggle, waits for completion
4. Downloads the decompiled output (zip) to your local machine

### What it needs
- A **direct APK download link** — the URL must directly download the file when opened
  - ✅ `https://download.apkmirror.com/wp-content/themes/APKMirror/download.php?id=12345`
  - ❌ `https://www.apkmirror.com/apk/com.example/app-name/` (this is a page, not a download)
- APKMirror download links expire after ~1 hour — use fresh links

### Setup steps
1. Create a free Kaggle account: https://kaggle.com
2. Go to Settings → API → Create New Token (gives you `KGAT_...` token)
3. Create a **private** notebook: https://kaggle.com/notebooks → New Notebook
   - Name it exactly: `jadx-apk-decompiler`
   - Set to **private**
   - Enable **internet access** in notebook settings
4. Add to your `.env`:
   ```
   KAGGLE_API_TOKEN=KGAT_your_token_here
   KAGGLE_KERNEL_ID=your-kaggle-username/jadx-apk-decompiler
   ```

### Usage
```bash
.kiro/jadx-decompile "https://direct-download-url" analysis/<app>/
```

## Workspace Structure

```
morphe/
├── .env.example            # Template for secrets
├── .gitignore              # Ignores secrets, binaries, large folders
├── AGENTS.md               # Main orchestrator prompt
├── LICENSE                 # Proprietary license
├── README.md               # This file
├── setup-cli.sh            # CLI download/build script
└── .kiro/
    ├── agents/             # 6 agent configs
    ├── prompts/            # Agent prompt files
    ├── skills/             # 13 on-demand skills
    ├── steering/           # 31 always-loaded context files
    │   ├── core/           # Project overview (morphe agent)
    │   ├── build/          # Build/CLI reference (patch-deployer)
    │   ├── patching/       # Patch writing guides (patch-writer)
    │   ├── bytecode/       # Smali/fingerprinting (patch-writer + target-hunter)
    │   ├── patterns/       # Bypass patterns (target-hunter)
    │   └── community/      # Community patch analysis (target-hunter)
    ├── settings/           # LSP config
    └── jadx-decompile      # Remote decompiler script

# Created locally after setup (gitignored):
├── .env                    # Your secrets
├── Morphe.keystore         # APK signing key (export from Morphe Manager)
├── morphe-cli.jar          # CLI binary (created by setup-cli.sh)
├── paresh-patches/         # Your patches repo clone
└── analysis/               # APK analysis work (per-app folders)
    └── <app>/
        ├── apk/            # Original APK files (created by apk-recon)
        ├── notes/          # Analysis findings (created by apk-recon)
        ├── decompiled/     # Java source from jadx (created by apk-decompiler)
        ├── smali/          # Bytecode from baksmali (created by apk-decompiler)
        └── builds/         # Patched APKs (created by patch-deployer)
```

## Agents

### morphe (orchestrator)
- **Trigger:** Default agent — always active
- **What it does:** Checks pipeline state for any app and routes you to the correct specialist
- **Tools:** All (bash, grep, glob, code, web search, knowledge)
- **Context:** Core project overview
- **Handles directly:** Quick builds, status checks, code searches, file reads

### apk-recon
- **Trigger:** "Recon this APK" or give it a file path
- **What it does:** Identifies APK metadata — package name, version, protections, framework, APK type
- **Tools:** aapt, apkid, unzip, file
- **Input:** APK file path in project root
- **Output:** `analysis/<app>/notes/recon.md` + organized `apk/` folder
- **Context:** APK analysis skill, apktool skill

### apk-decompiler
- **Trigger:** "Decompile `<app>` — URL is `<url>`"
- **What it does:** Runs jadx remotely on Kaggle (28GB RAM), extracts smali from all DEX files
- **Tools:** jadx-decompile script, baksmali, unzip
- **Input:** App name + direct APK download URL
- **Output:** `analysis/<app>/decompiled/` (Java) + `analysis/<app>/smali/` (bytecode)
- **Context:** APK analysis skill, jadx skill, tool reference

### target-hunter
- **Trigger:** "Find targets for `<app>` — looking for `<premium/ads/gates>`"
- **What it does:** Searches decompiled code for billing SDKs, ads, feature gates. Verifies every finding against smali bytecode. Documents fingerprint strategies.
- **Tools:** rg (ripgrep), glob, code (LSP), thinking
- **Input:** App name + what to find
- **Output:** `analysis/<app>/notes/premium-bypass.md`, `ad-removal.md`, etc.
- **Context:** Billing/ad/protection bypass patterns, community patch analysis, smali/fingerprinting guides

### patch-writer
- **Trigger:** "Write patches for `<app>`"
- **What it does:** Reads target findings, cross-checks against smali, writes Kotlin fingerprints + patch code, builds and verifies
- **Tools:** rg, glob, code (LSP), gradle, thinking
- **Input:** App name (reads notes automatically)
- **Output:** `.kt` files in `paresh-patches/patches/src/.../`
- **Context:** Patch development guides, patcher APIs, bytecode utilities, real patch examples, advanced techniques

### patch-deployer
- **Trigger:** "Build and test `<app>`"
- **What it does:** Builds patches with gradle, patches APK with morphe-cli, installs via ADB, reports results
- **Tools:** gradle, morphe-cli, adb, git
- **Input:** App name + action (build/test/deploy)
- **Output:** `analysis/<app>/builds/<app>_patched.apk`
- **Context:** Build/CLI reference, troubleshooting guide

## Pipeline

```
1. RECON        → apk-recon identifies the APK
2. DECOMPILE    → apk-decompiler runs jadx + baksmali
3. HUNT         → target-hunter finds patchable targets
4. WRITE        → patch-writer creates Kotlin patches
5. BUILD+DEPLOY → patch-deployer builds, patches APK, installs
```

Just give the morphe agent an app name — it checks state and tells you which agent to switch to next.

## Usage Examples

```
# Start fresh with a new APK
> I have a new APK for truecaller

# Continue work on existing app
> truecaller

# Quick tasks (morphe handles directly)
> build patches
> list patches
> search for "isPremium" in truecaller
> what's the status of all apps?
```

## Customization

### Adding a new app
1. Download APK to project root
2. Tell morphe agent: "New APK for `<app>`"
3. Follow the pipeline

### Modifying agent behavior
- Edit prompts in `.kiro/prompts/`
- Edit configs in `.kiro/agents/`
- Add steering files to `.kiro/steering/<category>/`

### Adding new steering context
Place `.md` files in the appropriate category folder. They auto-load for agents that reference that folder.

### Updating the jadx-decompile script
If you change your Kaggle username, update `KAGGLE_KERNEL_ID` in your `.env` file.

## Signing Key

The `Morphe.keystore` is used to sign all patched APKs. Both the Morphe Manager app (phone) and CLI must use the **same keystore** so patched APKs can update each other.

### Export from Morphe Manager (recommended)
1. Open Morphe Manager on your phone
2. Go to Settings → Export keystore
3. Transfer the exported `.keystore` file to this project root
4. Rename to `Morphe.keystore`

This ensures phone-patched and CLI-patched APKs share the same signature — you can install updates from either without uninstalling.

### Generate new keystore (if starting fresh)
```bash
keytool -genkey -v -keystore Morphe.keystore -alias Morphe \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass morphe -keypass morphe
```

Then import this keystore into Morphe Manager: Settings → Import keystore.

### Usage
The CLI always uses this keystore:
```bash
java -jar morphe-cli.jar patch -p patches.mpp --keystore Morphe.keystore -f input.apk
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Gradle auth fails | Check `~/.gradle/gradle.properties` has `gpr.user` + `gpr.key` |
| jadx-decompile fails | Check `.env` has `KAGGLE_API_TOKEN`, verify with `kaggle kernels list` |
| Fingerprint doesn't match | App version changed — re-run target-hunter to verify smali |
| Build fails | Check error in patch-deployer output — it gives exact file + line |
| ADB not found | `sudo apt install adb` or connect device |
| Agent gives wrong answer | Check steering files are loading: `/context show` in Kiro |

## Community Patch Repos (Reference)

The steering files in `.kiro/steering/community/` contain patterns learned from these repos:

| Repo | Focus | Patterns |
|------|-------|----------|
| [morphe-patches (hoo-dles)](https://github.com/hoo-dles/morphe-patches) | Various apps | Method injection, signature spoof, extension-based ad skip |
| [De-ReVanced](https://github.com/RookieEnough/De-ReVanced) | YouTube/Music | Device ID spoofing, signature bypass |
| [revanced-patches (anddea)](https://github.com/anddea/revanced-patches) | Extended YouTube | Advanced ad blocking, SponsorBlock |
| [piko](https://github.com/crimera/piko) | Instagram | Entity patterns, JSON field replacement, feed filtering |
| [patcheddit](https://github.com/wchill/patcheddit) | Reddit | Client ID spoofing, OAuth override, matchAll() bulk replace |
| [adobo](https://github.com/jkennethcarino/adobo) | Universal ad blocking | Per-SDK ad removal (AdMob, Unity, AppLovin, IronSource) |
| [AmpleReVanced](https://github.com/AmpleReVanced/revanced-patches) | Spotify | Hex patching native libs, protocol spoofing |
| [morphe-meta-patches](https://github.com/MeridianFresco/morphe-meta-patches) | Facebook/Meta | Sponsored content removal, story filtering |
| [binarymend](https://github.com/binarymend/morphe-patches) | Various apps | Telemetry blocking, bulk analytics disable |

## Contributing

**PRs welcome!** This project benefits from community knowledge. You can help by:

- 🧠 **Improving prompts** — better instructions, fewer hallucinations, more accurate patches
- 📚 **Adding steering context** — document new bypass patterns, SDK techniques, or app architectures
- 🛠️ **Adding skills** — new on-demand knowledge files for specific tools or workflows
- 🤖 **Adapting to other AI tools** — configs for Cursor, Copilot, Cline, Aider, etc.
- 📝 **Documenting patterns** — analyzed a new app? Share the technique
- 🐛 **Fixing issues** — found a wrong instruction or bad fingerprint pattern? Fix it

### How to contribute

1. Fork this repo
2. Create a branch: `git checkout -b feat/your-improvement`
3. Make your changes (add/edit files in `.kiro/steering/`, `.kiro/prompts/`, `.kiro/skills/`)
4. Open a PR with a clear description of what you improved

### Contribution ideas

- Add patterns for new billing SDKs (Adapty, Qonversion, Glassfy)
- Add patterns for new ad SDKs (InMobi, IronSource, Chartboost)
- Improve fingerprint debugging guidance
- Add support files for other AI tools (`.cursorrules`, `.github/copilot-instructions.md`)
- Document Flutter/React Native patching techniques
- Add more real-world patch examples

## License

Copyright © 2026 Paresh Maheshwari. All rights reserved. See [LICENSE](LICENSE).
