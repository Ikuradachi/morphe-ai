# Provenance and Third-Party Tooling

## Scope

This record covers `plugins/morphe-patch-creator/` version `0.1.0`. It is a technical source inventory, not legal advice or a substitute for maintainer review before publication.

## Morphe upstream baseline (2026-09-29)

The plugin's reference files are synchronized to the following pinned Morphe repository SHAs.
The plugin does not require or bundle source code from these repositories.

| Repository | Pinned HEAD SHA | Version |
|-----------|----------------|---------|
| morphe-desktop (CLI) | `4eadc2dca5e5bcdfef3ae2671440eca411c30dea` | v1.17.0 |
| morphe-patcher | `6f189f9ffb448ae32ceaf6c136c9d84d9a7ed274` | 1.14.1 |
| morphe-patches (official) | `92dd0ef86d12e1806152b454486269983b8db139` | — |
| morphe-patches-template | `0bbf39c4ff24c7799104f510b165e67c55b9d9cf` | — |
| morphe-patches-gradle-plugin | `0a2c1971e2913a6ea5e8fd192d359765169a6a06` | 1.3.4 |
| morphe-patches-library | `6501aee56d423c409e2e50ab1d5606b3704c49ee` | — |
| morphe-library | `e06c58f7ab029d55750e60aa9dd17aadf83e82a9` | — |
| morphe-documentation | `cdedd95c227ed6e6a2249ef307c34df7606b087c` | — |

Runtime requirements recorded at this baseline: **JRE 21 or later** (CLI runtime), **JDK 21 recommended** for patch builds.

Full source precedence rules are in `references/upstream-baseline.md`.

## Source lineage

- Workflow, agent, fingerprinting, and patch-development guidance was adapted from this repository's existing `.kiro/` prompts, skills, and steering files.
- Claude-specific packaging, orchestration, state scripts, schemas, tests, and eval cases were created for GitHub issue #9.
- The plugin does not require `.kiro/` at runtime and contains no third-party APK, decompiled application source, keystore, credential, or generated patch artifact.
- Community repositories named in the root documentation informed general techniques. Their source files are not bundled in this plugin. Examples in the plugin are short generic API/smali illustrations and must be rechecked against the configured Morphe version.

## Repository license

The root `LICENSE` contains the GNU General Public License version 3 text. The plugin manifests therefore declare `GPL-3.0-only`. No separate Morphe naming restriction was found in the checked-in license text; documentation must not claim one unless the license is deliberately amended and reviewed.

## External tools invoked, not bundled

| Tool | Project | Reported upstream license |
|---|---|---|
| jadx | `skylot/jadx` | Apache-2.0 |
| smali / baksmali | `JesusFreke/smali` | BSD-3-Clause |
| Apktool | `iBotPeaches/Apktool` | Apache-2.0 |
| Android `aapt` | Android Open Source Project | Apache-2.0 |
| ripgrep | `BurntSushi/ripgrep` | MIT OR Unlicense |
| APKiD (optional) | `rednaga/APKiD` | GPL-3.0; upstream also advertises a commercial option |
| `jadx-decompiler-gui` (optional provider) | local repository component | Review its own metadata before separate distribution |

These tools are discovered on the user's system and invoked as separate processes. They are not copied into the plugin.

## Fixtures and generated data

`tests/test-scripts.sh` creates synthetic ZIP/DEX fixtures in a temporary directory and removes them after the run. Native plugin evals contain prompts and graders only. Generated eval results are ignored by Git.

## Release review status

Before a public release, a maintainer should:

1. Confirm authorship/permission for every adapted repository-owned file.
2. Recheck upstream tool license identifiers and notices.
3. Verify no APK, decompiled source, credential, key, analysis folder, or eval result is staged.
4. Run strict plugin/marketplace validation, deterministic tests, native behavioral evals, and an authorized end-to-end patch workflow.
5. Record the reviewer and release revision here or in the release checklist.
