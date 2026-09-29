---
name: recon-apk
description: Inspect an authorized APK, APKM, APKS, or XAPK and create a structured Morphe reconnaissance report. Use for a new app before decompilation or patch target analysis.
context: fork
background: false
agent: apk-recon
argument-hint: [app-key] [apk-path]
---

# Recon an APK

Inspect the supplied package without modifying the original.

1. Resolve the analysis directory from project configuration.
2. Use `${CLAUDE_PLUGIN_ROOT}/scripts/init-analysis.sh` when the workspace is new.
3. Use `${CLAUDE_PLUGIN_ROOT}/scripts/inspect-apk.sh` for deterministic metadata evidence.
4. For split containers, inspect the base APK but preserve the original container as the future Morphe CLI input.
5. Write `analysis/<app>/notes/recon.md` with identity, SDK levels, format, DEX count, framework, architectures, protections, and tool limitations.
6. Mark recon complete only after the report exists and evidence is captured.
7. Return the report path and recommended next stage.

Do not decompile, hunt targets, write patches, install packages, or use a remote service.
