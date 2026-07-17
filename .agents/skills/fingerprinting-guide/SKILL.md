---
name: fingerprinting-guide
description: Create and debug stable Morphe fingerprints for locating obfuscated methods across app versions. Use when designing fingerprints, resolving match failures, choosing filters, or validating a target against Smali.
---

# fingerprinting-guide

## Purpose

Create and debug stable Morphe fingerprints for locating obfuscated methods across app versions.

## Triggers

Use when designing fingerprints, resolving match failures, choosing filters, or validating a target against Smali.

## Inputs

Verified Smali method, nearby instructions and literals, app versions, and any failed fingerprint diagnostics.

## Outputs

Minimal stable fingerprint strategy or corrected Kotlin fingerprint with Smali evidence.

## Instructions

Read [Kiro reference](references/kiro-skill.md) completely before acting. Treat its YAML frontmatter as archived metadata; follow its Markdown body as skill guidance. Preserve exact technical names, commands, code templates, fingerprint rules, and failure handling. Adapt unavailable tool names to equivalent runtime capabilities. Never weaken Smali verification or repository safety rules.