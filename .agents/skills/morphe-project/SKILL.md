---
name: morphe-project
description: Operate the Morphe Android APK patching workspace across reconnaissance, decompilation, target hunting, patch writing, build, testing, and deployment. Use for any Morphe project task, APK pipeline status check, specialist workflow, fingerprinting, bypass-pattern analysis, or repository-specific question.
---

# Morphe Project

## Purpose

Apply complete migrated Morphe project knowledge without depending on Kiro runtime behavior.

## Triggers

Use for every Morphe workspace task involving APKs, analysis folders, Smali, fingerprints, patches, builds, CLI operations, or pipeline routing.

## Inputs

App name or APK path when known; requested pipeline action; current repository state; target behavior for analysis or patching.

## Outputs

State assessment, analysis artifacts, patch artifacts, builds, deployment results, or exact next-workflow handoff.

## Reference loading

Read only relevant files, but read each selected file completely before acting:

- Orchestration and repository basics: `references/steering/core/` and `references/legacy-root-AGENTS.md`.
- Recon: `references/prompts/apk-recon.md`, then relevant APK analysis/tool skills.
- Decompile: `references/prompts/apk-decompiler.md`, then JADX and tool-reference skills.
- Hunt: `references/prompts/target-hunter.md`; read relevant `steering/bytecode/`, `steering/patterns/`, and `steering/community/` references.
- Write: `references/prompts/patch-writer.md`; read all relevant `steering/patching/` and `steering/bytecode/` references.
- Build/deploy: `references/prompts/patch-deployer.md` and relevant `steering/build/` references.

Use `rg --files references` to discover files. Do not truncate selected documents. Preserve mandatory Smali verification, stable fingerprinting, obfuscation handling, build failure, and git safety rules.

## Runtime adaptation

Kiro-specific tool labels describe capabilities, not required product APIs. Map them to available shell, file, search, code-navigation, browser, planning, or delegation tools. If specialist agents are unavailable, current agent assumes selected specialist role. If delegation is available, use it only when host rules permit. Legacy `.kiro/jadx-decompile` maps to `../jadx/scripts/jadx-decompile` from this skill folder.