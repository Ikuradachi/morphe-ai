# Agent Source Lineage and Maintenance

The Claude agents are self-contained adaptations of the existing Kiro roles:

| Claude agent | Kiro prompt | Kiro configuration |
|---|---|---|
| `apk-recon.md` | `.kiro/prompts/apk-recon.md` | `.kiro/agents/apk-recon.json` |
| `apk-decompiler.md` | `.kiro/prompts/apk-decompiler.md` | `.kiro/agents/apk-decompiler.json` |
| `target-hunter.md` | `.kiro/prompts/target-hunter.md` | `.kiro/agents/target-hunter.json` |
| `patch-writer.md` | `.kiro/prompts/patch-writer.md` | `.kiro/agents/patch-writer.json` |
| `patch-validator.md` | `.kiro/prompts/patch-deployer.md` | `.kiro/agents/patch-deployer.json` |

The root Kiro `morphe` router maps to the primary Claude `create-patch` skill instead of another subagent.

## Why agents do not import `.kiro` at runtime

Installed Claude plugins are copied/versioned as self-contained packages and may not have the Morphe source checkout. Raw Kiro prompts also contain Kiro tool names, manual agent-switch language, fixed workspace/package assumptions, and hooks that Claude plugin subagents cannot safely inherit.

## Maintenance strategy

For the initial implementation, preserve Kiro's proven scope, decision rules, output contracts, and failure handling in the Claude files while adapting only:

- YAML frontmatter and Claude tool names.
- Main-session automatic delegation instead of manual switching.
- `${CLAUDE_PROJECT_DIR}` and `${CLAUDE_PLUGIN_ROOT}` instead of absolute paths.
- Configured patch repositories instead of `paresh-patches`.
- Explicit validation instead of automatic post-write builds.
- Explicit-only remote, device, and Git actions.

After Claude behavioral evals stabilize, introduce a **build-time** adapter generator around canonical platform-neutral prompt bodies. The generator should emit both Kiro and Claude wrappers and fail if output contains forbidden absolute paths, unsupported tool names, or unsafe automatic side effects. Do not dynamically inject Kiro prompts at plugin runtime.

## Local adapter helper

Use the plugin helper to inject Claude frontmatter into a reviewed portable prompt body:

```bash
python3 plugins/morphe-patch-creator/scripts/agent-adapter.py create \
  --source /tmp/reviewed-apk-recon-body.md \
  --output /tmp/apk-recon.md \
  --name apk-recon \
  --description "Identify APK metadata for the Morphe recon stage." \
  --tools "Read, Glob, Grep, Bash, Write"
```

Verify one or all adapters locally:

```bash
python3 plugins/morphe-patch-creator/scripts/agent-adapter.py check \
  plugins/morphe-patch-creator/agents/{apk-recon,apk-decompiler,target-hunter,patch-writer,patch-validator}.md
claude plugin validate --strict plugins/morphe-patch-creator
```

The helper refuses machine-specific home paths, the fixed `paresh-patches` name, and Kiro-only tool names. Raw Kiro prompts may therefore need a small reviewed portability edit before generation; this is intentional and prevents silent contradictory instructions.
