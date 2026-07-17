---
name: tool-reference
description: Select optimized command-line arguments for Android reverse-engineering tools. Use before running rg, JADX, baksmali, aapt, APKiD, unzip, or related APK-analysis commands.
---

# tool-reference

## Purpose

Select optimized command-line arguments for Android reverse-engineering tools.

## Triggers

Use before running rg, JADX, baksmali, aapt, APKiD, unzip, or related APK-analysis commands.

## Inputs

Tool, APK or analysis path, and search/decompile/disassembly goal.

## Outputs

Efficient, scoped command with suitable flags and expected result.

## Instructions

Read [Kiro reference](references/kiro-skill.md) completely before acting. Treat its YAML frontmatter as archived metadata; follow its Markdown body as skill guidance. Preserve exact technical names, commands, code templates, fingerprint rules, and failure handling. Adapt unavailable tool names to equivalent runtime capabilities. Never weaken Smali verification or repository safety rules.