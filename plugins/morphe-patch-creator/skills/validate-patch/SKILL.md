---
name: validate-patch
description: Build, list, and locally apply Morphe patches to verify registration and fingerprint matching. Use after patch source exists or when diagnosing build and match failures.
context: fork
background: false
agent: patch-validator
argument-hint: [app-key]
---

# Validate a Morphe Patch

Read `${CLAUDE_PLUGIN_ROOT}/references/upstream-baseline.md` before running any CLI command.
Detect the installed CLI version (non-mutating) before any version-sensitive invocation:

```bash
CLI_VERSION=$(java -jar "$MORPHE_CLI" -V 2>/dev/null \
              || java -jar "$MORPHE_CLI" --version 2>/dev/null \
              || echo "unknown")
echo "CLI version: $CLI_VERSION"
```

If the jar is absent, report it and stop.

Perform these gates in order:

1. Resolve the patch repository, Morphe CLI, original input package, and output directory.
2. Build the patch bundle using the repository's documented Gradle task.
3. Resolve the bundle from project version metadata rather than an ambiguous glob.
4. Run `list-patches` and confirm the expected patch name and compatibility.
5. Apply the intended patch to the original APK/APKM/APKS/XAPK and write a new artifact under `analysis/<app>/builds/`.
6. Capture command, exit status, relevant output, and resulting artifact.

A compilation failure is a writer handoff. A fingerprint match failure is a target-hunter handoff. Do not install the artifact, alter a device, commit, push, or publish.
