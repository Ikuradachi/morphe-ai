---
name: find-patch-targets
description: Find Morphe patch targets in decompiled Android source and verify each target against exact smali bytecode. Use after decompiled source and smali exist.
context: fork
background: false
agent: target-hunter
argument-hint: [app-key] [requested-change]
---

# Find Patch Targets

Search in this order unless the requested behavior requires a narrower route:

1. Relevant app architecture and SDKs.
2. Requested feature or behavior call chain.
3. Local feature gates and stable strings.
4. Protections that directly prevent an authorized modification.
5. Related ads, analytics, or configuration only when in scope.

For every candidate, verify the exact smali method and record:

- DEX and class path.
- Full method signature, access flags, return type, and parameters.
- Register count and ordered instruction evidence.
- Stable fingerprint fields that avoid obfuscated app identifiers.
- Proposed patch behavior and limitations.

Write one findings file per target type under `analysis/<app>/notes/`. A Java-only finding is incomplete and must not be handed to `patch-writer`.
