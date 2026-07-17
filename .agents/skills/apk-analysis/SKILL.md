---
name: apk-analysis
description: Run Morphe APK analysis from workspace setup through metadata inspection, decompilation, target search, Smali verification, and findings documentation. Use for new APK reconnaissance, end-to-end APK analysis, protection detection, target hunting, or analysis-folder setup.
---

# apk-analysis

## Purpose

Run Morphe APK analysis from workspace setup through metadata inspection, decompilation, target search, Smali verification, and findings documentation.

## Triggers

Use for new APK reconnaissance, end-to-end APK analysis, protection detection, target hunting, or analysis-folder setup.

## Inputs

App name; APK or bundle path; optional direct download URL; desired patch target such as premium, ads, telemetry, or protection checks.

## Outputs

Organized analysis/<app>/ content, decompiled Java, Smali, and evidence-backed notes for patch writing.

## Instructions

Read [Kiro reference](references/kiro-skill.md) completely before acting. Treat its YAML frontmatter as archived metadata; follow its Markdown body as skill guidance. Preserve exact technical names, commands, code templates, fingerprint rules, and failure handling. Adapt unavailable tool names to equivalent runtime capabilities. Never weaken Smali verification or repository safety rules.