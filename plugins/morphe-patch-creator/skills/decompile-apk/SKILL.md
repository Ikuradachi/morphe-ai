---
name: decompile-apk
description: Decompile an authorized Android package and extract smali from all DEX files for Morphe analysis. Use after reconnaissance and before target hunting.
context: fork
background: false
agent: apk-decompiler
argument-hint: [app-key]
---

# Decompile an APK

1. Require an existing recon report and original package under the app analysis directory.
2. Check for existing non-empty `decompiled/` or `smali/` output; do not overwrite it without explicit approval.
3. Prefer `${CLAUDE_PLUGIN_ROOT}/scripts/decompile-local.sh`.
4. Extract all DEX files using `${CLAUDE_PLUGIN_ROOT}/scripts/extract-smali.sh`.
5. Verify non-zero Java/source and smali outputs and record counts.
6. If local jadx is unavailable or unsuitable, explain the optional remote data flow. Use `jadx-decompiler-gui` only when configured and explicitly approved.
7. Record exact failures and leave the stage failed or blocked rather than claiming partial success.

Do not search for patch targets or write patch code.
