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

1. Relevant app architecture and entitlement/feature SDKs.
2. Requested feature or behavior call chain.
3. Local feature gates, SharedPreferences, and reactive state (StateFlow/Coroutines).
4. Environment and runtime attestations that directly affect the authorized modification.
5. Content filtering, layout components, analytics, or configuration only when in scope.
6. Native binary libraries (`.so`) via REA MCP or local disassemblers when logic resides in JNI, Flutter, or Unity code.

For every candidate, verify the exact smali method and record:

- DEX and class path.
- Full method signature, access flags, return type, and parameters.
- Register count and ordered instruction evidence.
- Stable fingerprint fields that avoid obfuscated app identifiers.
- Proposed patch behavior and limitations.

Write findings under `analysis/<app>/notes/` (`entitlement-analysis.md`, `content-filtering.md`, `environment-attestation.md`, `feature-gates.md`, or `native-findings.md`). A Java-only finding is incomplete and must not be handed to `patch-writer`.
