---
name: test-on-device
description: Install and test an already validated Morphe-patched APK on a user-selected Android device and collect relevant logs. Use only when the user explicitly asks for device testing.
disable-model-invocation: true
---

# Test on an Android Device

This skill changes a connected device. Never invoke it automatically.

1. Require a locally validated patched artifact.
2. Run a read-only device listing and show the selected serial and planned commands.
3. Explain whether installation may replace an app, require uninstalling, change signatures, or affect local app data.
4. Obtain explicit confirmation immediately before install, uninstall, clear-data, mount, or link-routing actions.
5. Prefer non-destructive installation. Never uninstall or clear data merely to recover from an error.
6. Capture focused logs without exposing unrelated device or user data.
7. Report exactly what changed and how to reverse it.

Do not perform Git or release operations.
