---
name: build-deploy
description: Build, test, package, install, and troubleshoot Morphe patches while enforcing repository and release rules. Use for Gradle builds, Morphe CLI tests, APK deployment, ADB installation, build failures, or release preparation.
---

# build-deploy

## Purpose

Build, test, package, install, and troubleshoot Morphe patches while enforcing repository and release rules.

## Triggers

Use for Gradle builds, Morphe CLI tests, APK deployment, ADB installation, build failures, or release preparation.

## Inputs

App name; patch repository state; source APK; requested build, test, install, or deployment action.

## Outputs

MPP artifact, patched APK, installation result, or actionable failure report.

## Instructions

Read [Kiro reference](references/kiro-skill.md) completely before acting. Treat its YAML frontmatter as archived metadata; follow its Markdown body as skill guidance. Preserve exact technical names, commands, code templates, fingerprint rules, and failure handling. Adapt unavailable tool names to equivalent runtime capabilities. Never weaken Smali verification or repository safety rules.