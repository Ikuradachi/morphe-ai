# Morphe Patch Creator for Claude Code

An evidence-backed Claude Code workflow for authorized Android package analysis and Morphe patch development.

## What it provides

- One primary `/morphe-patch-creator:create-patch` workflow.
- Resumable recon, decompilation, target hunting, patch writing, and local validation stages.
- Five focused plugin subagents with least-necessary tool sets.
- Atomic, project-local workflow state and deterministic helper scripts.
- User-only device testing and Git/GitHub submission commands.
- No mandatory MCP server, global hook, package installation, or remote service.

## Requirements and supported platforms

The helper scripts are tested on Linux with Bash 4+, Python 3, `file`, `unzip`, `rg`, `aapt`, `jadx`, `baksmali`, and **Java 21 or later**. WSL2 is expected to work with the same Linux tools. macOS can work with Bash 4+ and equivalent Android tooling, but is not currently covered by CI. Native Windows is not supported; use WSL2.

**Java/JRE 21 or later is required** to run the Morphe CLI. JDK 21 is recommended for patch
builds because it matches the current template CI. The desktop source documentation separately
lists JDK 17 as the minimum for building Morphe Desktop itself.

Run the read-only prerequisite check from the repository root:

```bash
plugins/morphe-patch-creator/scripts/doctor.sh
```

The doctor checks that Java major version is 21 or greater and reports the installed Morphe CLI version (using `-V`) when the jar exists. ADB, `gh`, `uv`/`uvx`, APKiD, and `jadx-decompiler-gui` are optional. The plugin reports missing dependencies; it never installs them or uses `sudo` automatically.

## Load during development

From the repository root:

```bash
claude --plugin-dir ./plugins/morphe-patch-creator
```

This loads the plugin for that session; it does not install it. Validate first when developing:

```bash
claude plugin validate --strict ./plugins/morphe-patch-creator
claude plugin validate --strict .
```

## Install from this repository marketplace

Inside Claude Code:

```text
/plugin marketplace add Paresh-Maheshwari/morphe-ai
/plugin install morphe-patch-creator@morphe-ai
```

Equivalent shell commands, with an explicit installation scope:

```bash
claude plugin marketplace add Paresh-Maheshwari/morphe-ai --scope user
claude plugin install morphe-patch-creator@morphe-ai --scope user
```

Use `--scope project` to share enablement through the project, or `--scope local` for an uncommitted project-local install. Merely cloning a repository that contains `marketplace.json` does not register or install its plugins.

## Start or resume a patch

```text
/morphe-patch-creator:create-patch ./path/to/app.apk "describe the authorized change"
```

The main session validates the workspace, checks persisted artifacts, and delegates sequential stages without requiring manual agent switching:

```text
create-patch
├── apk-recon
├── apk-decompiler
├── target-hunter
├── patch-writer
└── patch-validator
```

Direct stage commands are also available:

```text
/morphe-patch-creator:recon-apk <app-key> <package-path>
/morphe-patch-creator:decompile-apk <app-key>
/morphe-patch-creator:find-patch-targets <app-key> <requested-change>
/morphe-patch-creator:write-patch <app-key>
/morphe-patch-creator:validate-patch <app-key>
```

Consequential stages are user-only and cannot be model-invoked:

```text
/morphe-patch-creator:test-on-device
/morphe-patch-creator:submit-patch
```

## Configuration

Configuration is optional. Create `.morphe/config.json` in the project where the plugin runs when discovery would be ambiguous:

```bash
mkdir -p .morphe
cp plugins/morphe-patch-creator/config.example.json .morphe/config.json
```

When the plugin is installed rather than loaded from this checkout, create the file from the example below instead of trying to use `${CLAUDE_PLUGIN_ROOT}` in your shell:

```json
{
  "analysisDir": "analysis",
  "patchesDir": null,
  "cliJar": "morphe-cli.jar",
  "keystorePath": null,
  "decompiler": {
    "mode": "local",
    "remoteProvider": null
  }
}
```

The file may contain only the fields that differ from defaults. Relative paths resolve from `${CLAUDE_PROJECT_DIR}`. Credentials do not belong in this file. Environment overrides used by helpers include `MORPHE_ANALYSIS_DIR`, `MORPHE_PATCHES_DIR`, `MORPHE_DECOMPILER`, and `MORPHE_CONFIG`.

`${CLAUDE_PLUGIN_ROOT}` is a Claude Code substitution in plugin skill and agent content, not a user-shell environment variable.

## Workflow state

State is stored beside the analysis evidence:

```text
analysis/<app>/notes/morphe-workflow.json
```

Inspect it from a checkout with:

```bash
plugins/morphe-patch-creator/scripts/workflow-status.sh [app-key]
```

Stages can complete only with existing evidence paths, in pipeline order. State never stores credentials or keystore contents.

## Local and remote decompilation

Local jadx is the default. The optional `jadx-decompiler-gui` provider uses Kaggle and is considered a remote data transfer. Claude must explain which APK or URL leaves the machine and obtain explicit user approval before invoking it. Tokens remain in the provider's environment or private settings and are never copied into workflow state.

## Safety boundaries

- Use only with software you are authorized to analyze and modify.
- No server-side payment, account, credential, entitlement, or attestation compromise.
- No APK, source, URL, or log upload without explicit approval.
- No dependency installation or `sudo` without approval.
- Patch-source changes require approval of a smali-backed design.
- No device changes, commits, pushes, PRs, or releases from the normal workflow.
- No success claim without the file and command evidence required for that stage.

## Tests

Deterministic script and synthetic DEX tests:

```bash
plugins/morphe-patch-creator/tests/test-scripts.sh
```

Native behavioral evals use the current `claude plugin eval` case-directory format:

```bash
cd plugins/morphe-patch-creator
claude plugin eval . --runs 1 --ablation none --no-publish
```

The native suite is distinct from `evals/evals.json`, which remains optional input for Anthropic's separate `skill-creator` workflow. See [`evals/README.md`](evals/README.md) for cases, cost controls, baseline runs, and CI guidance. Generated `evals/results/` are ignored.

## Manage an installed plugin

```bash
# Update, then restart Claude Code to apply it.
claude plugin update morphe-patch-creator@morphe-ai --scope user

# Uninstall. Persistent plugin data is removed by default after the last install.
claude plugin uninstall morphe-patch-creator@morphe-ai --scope user

# Preserve persistent plugin data when uninstalling.
claude plugin uninstall morphe-patch-creator@morphe-ai --scope user --keep-data
```

During in-place development, use `/reload-plugins` after changes; if Claude warns that reloading would invalidate cached context, use `/reload-plugins --force`.

## Current limitations

- A configured patch repository and compatible Morphe tooling are required for app-specific write/validation stages; they are intentionally not bundled.
- Synthetic tests prove helper behavior and DEX round trips, not a real third-party app patch.
- Flutter AOT, packed/encrypted applications, dynamic feature DEX, and server-validated behavior can require unsupported or app-specific analysis.
- Runtime behavior on a device remains unproven until the user explicitly runs the device-test skill.
- Public release still requires maintainer review of provenance and an end-to-end authorized fixture or app run.

See [`PROVENANCE.md`](PROVENANCE.md) for source lineage and third-party tool attribution.