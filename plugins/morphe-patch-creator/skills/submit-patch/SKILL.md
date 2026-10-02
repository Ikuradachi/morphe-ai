---
name: submit-patch
description: Prepare and optionally submit a validated Morphe patch through Git and GitHub. Use only when the user explicitly requests a commit, push, pull request, or release action.
disable-model-invocation: true
---

# Submit a Morphe Patch

This skill performs consequential repository or remote actions. Never invoke it automatically.

1. Require current validation evidence and review `git status`, branch, and diff.
2. Confirm generated APKs, decompiled source, analysis artifacts, credentials, and keystores are not being added.
3. Present the exact files and proposed conventional commit message.
4. Obtain explicit approval before creating a commit.
5. Obtain a separate explicit approval before pushing.
6. Obtain another explicit approval before opening a pull request or publishing a release.
7. Never push directly to `main` or `master` unless the user explicitly requests it.
8. Preserve hooks and use non-interactive commands.
9. Report remote URLs and resulting repository state.

Do not print authentication tokens or alter credential stores.
