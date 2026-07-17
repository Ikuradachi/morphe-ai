# AGENTS.md

## Project Overview

Morphe AI is an Android APK patching workspace. Pipeline: reconnaissance, decompilation, target hunting, patch writing, build, test, deployment. Core technologies: Kotlin, Java, Dalvik/Smali, Gradle, Morphe patcher DSL, JADX, baksmali, Apktool, Morphe CLI, ADB.

Repository roles:

- `analysis/<app>/`: APKs, decompiled Java, Smali, notes, builds.
- `paresh-patches/`: custom patch bundle; development normally occurs on `dev`.
- `.agents/skills/`: universal reusable skills and complete migrated references.
- `.kiro/`: frozen legacy source. Do not delete until user confirms migration.

For every Morphe task, use `.agents/skills/morphe-project/SKILL.md`. Load only task-relevant references, but read selected references completely. This progressive-loading design avoids runtime AGENTS.md byte limits while preserving every original instruction byte-for-byte.

## Core Operating Rules & Constraints

1. Check filesystem state before deciding pipeline stage. Never guess app state.
2. If app name missing, inspect root APK files and active `analysis/` work. Ask only when multiple active apps make intent ambiguous or no app/APK exists.
3. Pipeline stages: RECON, DECOMPILE, HUNT, WRITE, DEPLOY.
4. Current agent may execute any stage when runtime has no named specialist. Named roles are workflows, not Kiro dependencies.
5. Treat Kiro tool names as capability labels. Use available shell, search, read/write, code-navigation, browser, planning, or delegation equivalents.
6. Prefer `rg` and `rg --files`. Verify target logic in Smali before writing fingerprints. JADX is orientation, not bytecode ground truth.
7. Never use unstable obfuscated class/method names when stable structural fingerprint characteristics exist.
8. Preserve user work and unrelated dirty-tree changes. Never push without explicit user approval. Never commit directly to `main`. Merge `dev` to `main` only after verification.
9. Use `bytecodePatch` unless resource decoding is required. Keep patches minimal. Put complex runtime behavior in extensions.
10. Build after patch edits. Diagnose failures from full relevant output; report exact blockers after bounded repair attempts.
11. Server-validated behavior may be impossible to bypass locally. State limits honestly.
12. Legacy source `.kiro/` stays unchanged until final user confirmation.

Instruction precedence: user/system instructions; this universal section; selected workflow prompt; selected engineering references; archived legacy root prompt. Any legacy instruction to “switch” means activate that workflow locally unless runtime supports specialist switching. Any legacy `.kiro/jadx-decompile` command maps to `.agents/skills/jadx/scripts/jadx-decompile`.

## Engineering & Code Style Guidelines

- Confirm package, version, APK format, framework, DEX count, protections, and split requirements during recon.
- Search decompiled Java broadly, then trace call chains. Verify exact class descriptor, method signature, access flags, parameters, return type, register use, literals, instruction order, and control flow in Smali.
- Prefer stable fingerprint filters in ordered form. Use unordered strings only when order is irrelevant. Avoid needless constraints that make updates brittle.
- Fingerprints and patches live in app/category folders with shared compatibility/constants where appropriate. Follow existing repository patterns before inventing structure.
- Use Morphe utilities such as `returnEarly`, `returnLate`, instruction-index helpers, `FreeRegisterProvider`, resource mappings, and extension hooks when their preconditions fit.
- Preserve register correctness, wide-register pairs, move-result adjacency, branch labels, try/catch integrity, and return types.
- Choose least invasive patch point. Prefer single authoritative checks over scattered UI symptoms. Use multi-point or extension hooks only when behavior genuinely requires them.
- Build with `./gradlew buildAndroid`; resolve MPP version from `paresh-patches/gradle.properties`; patch original APK input; write builds under `analysis/<app>/builds/`.
- Exact APIs, templates, Smali rules, obfuscation guidance, bypass patterns, community examples, and troubleshooting instructions live in migrated references listed below. Read relevant files completely before implementation.

## Execution Workflows

State check:

```text
nothing for app             RECON
notes/recon.md only         DECOMPILE
decompiled/ and smali/      HUNT
target findings in notes/   WRITE
Kotlin patch files          DEPLOY
```

Workflow inputs and outputs:

- Recon: APK path. Produce `analysis/<app>/notes/recon.md` and organized APK input.
- Decompile: app name plus direct APK URL or usable local input. Produce Java under `decompiled/` and bytecode under `smali/`.
- Hunt: app name plus desired target. Produce evidence-backed notes such as premium, ads, gates, telemetry, or protection findings.
- Write: app name and findings. Produce Kotlin fingerprints/patches and extension code when needed; build-verify.
- Deploy: app name plus action. Build MPP, patch original APK, optionally install/test, report artifact and failures.

Canonical workflow prompts:

- `.agents/skills/morphe-project/references/prompts/apk-recon.md`
- `.agents/skills/morphe-project/references/prompts/apk-decompiler.md`
- `.agents/skills/morphe-project/references/prompts/target-hunter.md`
- `.agents/skills/morphe-project/references/prompts/patch-writer.md`
- `.agents/skills/morphe-project/references/prompts/patch-deployer.md`

Complete migrated steering/prompt source index:

<!-- sync-kiro:source-index:start -->
- .agents/skills/morphe-project/references/prompts/apk-decompiler.md
- .agents/skills/morphe-project/references/prompts/apk-recon.md
- .agents/skills/morphe-project/references/prompts/patch-deployer.md
- .agents/skills/morphe-project/references/prompts/patch-writer.md
- .agents/skills/morphe-project/references/prompts/target-hunter.md
- .agents/skills/morphe-project/references/steering/build/build-and-cli.md
- .agents/skills/morphe-project/references/steering/build/morphe-cli.md
- .agents/skills/morphe-project/references/steering/build/morphe-library-guide.md
- .agents/skills/morphe-project/references/steering/build/troubleshooting.md
- .agents/skills/morphe-project/references/steering/bytecode/fingerprint-debugging.md
- .agents/skills/morphe-project/references/steering/bytecode/fingerprinting.md
- .agents/skills/morphe-project/references/steering/bytecode/obfuscation-guide.md
- .agents/skills/morphe-project/references/steering/bytecode/smali-cheat-sheet.md
- .agents/skills/morphe-project/references/steering/community/ample-revanced-patterns.md
- .agents/skills/morphe-project/references/steering/community/community-patches-analysis.md
- .agents/skills/morphe-project/references/steering/community/de-revanced-patterns.md
- .agents/skills/morphe-project/references/steering/community/hoodles-patch-catalog.md
- .agents/skills/morphe-project/references/steering/community/official-morphe-patches-analysis.md
- .agents/skills/morphe-project/references/steering/community/patcheddit-reddit-patterns.md
- .agents/skills/morphe-project/references/steering/community/piko-instagram-patterns.md
- .agents/skills/morphe-project/references/steering/community/revanced-extended-patterns.md
- .agents/skills/morphe-project/references/steering/community/small-repos-patterns.md
- .agents/skills/morphe-project/references/steering/core/morphe-quick-reference.md
- .agents/skills/morphe-project/references/steering/core/project-overview.md
- .agents/skills/morphe-project/references/steering/patching/advanced-patching-techniques.md
- .agents/skills/morphe-project/references/steering/patching/extension-development.md
- .agents/skills/morphe-project/references/steering/patching/morphe-patch-development-guide.md
- .agents/skills/morphe-project/references/steering/patching/patch-development.md
- .agents/skills/morphe-project/references/steering/patching/patch-examples.md
- .agents/skills/morphe-project/references/steering/patching/patcher-apis.md
- .agents/skills/morphe-project/references/steering/patterns/app-architecture-patterns.md
- .agents/skills/morphe-project/references/steering/patterns/billing-bypass-patterns.md
- .agents/skills/morphe-project/references/steering/patterns/firebase-analytics-bypass.md
- .agents/skills/morphe-project/references/steering/patterns/protection-bypass-patterns.md
- .agents/skills/morphe-project/references/steering/patterns/universal-ad-blocking.md
- .agents/skills/morphe-project/references/steering/patterns/universal-patches.md
<!-- sync-kiro:source-index:end -->

## Standardized Skills

Canonical skills live under `.agents/skills/`. Each `SKILL.md` contains purpose, triggers, inputs, outputs, and loading instructions. Detailed Kiro skill text is preserved byte-for-byte at `references/kiro-skill.md`.

<!-- sync-kiro:skill-index:start -->
- `apk-analysis`
- `apktool`
- `build-deploy`
- `caveman`
- `cli-reference`
- `dev-setup`
- `fingerprinting-guide`
- `jadx`
- `morphe-faq`
- `morphe-library`
- `morphe-project`
- `patch-anatomy`
- `patch-examples`
- `patcher-apis`
- `tool-reference`
<!-- sync-kiro:skill-index:end -->

## MCP Server Definitions

<!-- sync-kiro:mcp:start -->
`.kiro/settings/mcp.json` is absent. No MCP server commands, arguments, or environment variables are discoverable. Copyable empty configuration:

```json
{
  "mcpServers": {}
}
```
<!-- sync-kiro:mcp:end -->

Do not infer MCP secrets or server definitions from `.env.example`; none are MCP declarations.

## Updating From Kiro

Run `./scripts/sync-kiro.ps1` after pulling upstream Kiro changes. Run `./scripts/sync-kiro.ps1 -Check` in CI or before committing. Sync never deletes stale migrated files; it reports them for manual review.
