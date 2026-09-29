---
name: write-patch
description: Implement an approved Morphe patch design from smali-verified findings. Use only after target evidence exists and the user has approved the proposed source changes.
context: fork
background: false
agent: patch-writer
argument-hint: [app-key]
---

# Write a Morphe Patch

Before editing, read `${CLAUDE_PLUGIN_ROOT}/references/upstream-baseline.md` and require:

- A recon report.
- Smali-verified findings.
- A named patch design with target files.
- Recorded user approval for source modification.
- A resolved patch repository.

Read existing app patches and project conventions before changing files. Add to existing structure rather than overwriting it. Never use obfuscated app class, method, or field names as fingerprint identity. Prefer stable SDK calls, signatures, strings, literals, and ordered filters verified against smali.

Extension artifacts use the `.mpe` suffix, not `.mpp`. Verify filter location API names and `instructionMatches` availability against the installed patcher version.

After editing, run the narrowest relevant compile/build validation. Return exact files changed, commands, exit results, and unresolved risks. Do not install to a device or perform Git write operations.
