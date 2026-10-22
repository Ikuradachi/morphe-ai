#!/usr/bin/env python3
"""
Port plugins/morphe-patch-creator (Claude Code plugin) to:
  1. OpenAI Codex (.codex/config.toml, .codex/agents/*.toml, .agents/skills/*)
  2. Google Antigravity (.agents/agents/{name}/agent.md, .agents/skills/*, .agents/plugins/morphe-patch-creator/)
"""

import argparse
import json
import re
import shutil
from pathlib import Path
from typing import Dict, List, Tuple

# Map Claude Code tool names -> Google Antigravity verified tool names
CLAUDE_TO_AGY_TOOLS = {
    "read": "view_file",
    "view": "view_file",
    "grep": "grep_search",
    "glob": "find_by_name",
    "bash": "run_command",
    "edit": "replace_file_content",
    "multiedit": "replace_file_content",
    "write": "write_to_file",
}

# Agents that should default to read-only sandboxing in Codex
READ_ONLY_AGENTS = {"recon", "apk-recon", "target-hunter", "target_hunter", "validator"}


def parse_frontmatter(md_text: str) -> Tuple[Dict[str, object], str]:
    """Parse basic YAML frontmatter without requiring PyYAML."""
    if not md_text.startswith("---"):
        return {}, md_text.strip()

    match = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n?(.*)$", md_text, re.DOTALL)
    if not match:
        return {}, md_text.strip()

    raw_yaml, body = match.group(1), match.group(2).strip()
    meta: Dict[str, object] = {}
    current_list_key = None

    for line in raw_yaml.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        # Handle YAML list items (- item)
        if stripped.startswith("- ") and current_list_key:
            val = stripped[2:].strip().strip("'\"")
            if isinstance(meta.get(current_list_key), list):
                meta[current_list_key].append(val)
            continue

        if ":" in stripped:
            key, val = stripped.split(":", 1)
            key = key.strip()
            val = val.strip()

            if not val:
                meta[key] = []
                current_list_key = key
            elif val.startswith("[") and val.endswith("]"):
                items = [x.strip().strip("'\"") for x in val[1:-1].split(",") if x.strip()]
                meta[key] = items
                current_list_key = None
            elif "," in val and key == "tools":
                items = [x.strip().strip("'\"") for x in val.split(",") if x.strip()]
                meta[key] = items
                current_list_key = None
            else:
                meta[key] = val.strip("'\"")
                current_list_key = None

    return meta, body


def sanitize_prompt_body(body: str, plugin_rel_path: str = "plugins/morphe-patch-creator") -> str:
    """Replace Claude-specific variables and tool references with portable equivalents."""
    # Replace Claude plugin root variable with workspace-relative path
    text = body.replace("${CLAUDE_PLUGIN_ROOT}", plugin_rel_path)
    text = text.replace("$CLAUDE_PLUGIN_ROOT", plugin_rel_path)

    # Make explicit Claude Task tool calls portable across Codex and Antigravity
    text = re.sub(
        r"\buse the Task tool\b",
        "delegate to the corresponding subagent (via `invoke_subagent` or subagent spawning)",
        text,
        flags=re.IGNORECASE,
    )
    return text


def format_toml_multiline(text: str) -> str:
    """Safely wrap markdown instructions in TOML multiline strings (preserving Smali/regex backslashes)."""
    if "'''" not in text:
        return f"'''\n{text}\n'''"
    # Fallback to escaped basic string if triple single-quotes exist in text
    escaped = json.dumps(text)[1:-1]
    return f'"""\n{escaped}\n"""'


def map_tools_for_antigravity(claude_tools: List[str], agent_name: str) -> List[str]:
    """Map Claude tool names to Antigravity tool names safely."""
    agy_tools = []
    for t in claude_tools:
        mapped = CLAUDE_TO_AGY_TOOLS.get(t.lower())
        if mapped and mapped not in agy_tools:
            agy_tools.append(mapped)

    if not agy_tools:
        # Sensible defaults based on agent role
        agy_tools = ["view_file", "grep_search", "run_command"]
        if agent_name not in READ_ONLY_AGENTS:
            agy_tools.extend(["replace_file_content", "write_to_file"])

    return agy_tools


def port_skills_and_commands(
    src_plugin: Path,
    shared_skills_dir: Path,
    agy_plugin_skills_dir: Path,
    plugin_rel_path: str,
) -> int:
    """Copy skills and convert any commands/*.md into SKILL.md bundles."""
    count = 0
    src_skills = src_plugin / "skills"
    if src_skills.is_dir():
        for skill_dir in sorted(src_skills.iterdir()):
            if not skill_dir.is_dir():
                continue
            for target_base in (shared_skills_dir, agy_plugin_skills_dir):
                dest = target_base / skill_dir.name
                if dest.exists():
                    shutil.rmtree(dest)
                shutil.copytree(skill_dir, dest)

                # Sanitize SKILL.md and any markdown references inside the skill
                for md_file in dest.rglob("*.md"):
                    raw = md_file.read_text(encoding="utf-8")
                    md_file.write_text(sanitize_prompt_body(raw, plugin_rel_path), encoding="utf-8")
            count += 1

    # Also convert commands/*.md (if present) into skills so Codex and Antigravity expose them
    src_commands = src_plugin / "commands"
    if src_commands.is_dir():
        for cmd_file in sorted(src_commands.glob("*.md")):
            meta, body = parse_frontmatter(cmd_file.read_text(encoding="utf-8"))
            cmd_name = str(meta.get("name", cmd_file.stem)).lower().replace(" ", "-")
            desc = str(meta.get("description", f"Morphe command workflow for {cmd_name}."))
            clean_body = sanitize_prompt_body(body, plugin_rel_path)

            skill_md = (
                f"---\n"
                f"name: {cmd_name}\n"
                f"description: {json.dumps(desc)}\n"
                f"---\n\n"
                f"{clean_body}\n"
            )
            for target_base in (shared_skills_dir, agy_plugin_skills_dir):
                dest_dir = target_base / cmd_name
                dest_dir.mkdir(parents=True, exist_ok=True)
                (dest_dir / "SKILL.md").write_text(skill_md, encoding="utf-8")
            count += 1

    return count


def port_agents(
    src_plugin: Path,
    codex_agents_dir: Path,
    agy_workspace_agents_dir: Path,
    agy_plugin_agents_dir: Path,
    plugin_rel_path: str,
    omit_agy_tools: bool = False,
) -> int:
    """Convert agents/*.md to Codex .toml files and Antigravity .md files."""
    src_agents = src_plugin / "agents"
    if not src_agents.is_dir():
        return 0

    codex_agents_dir.mkdir(parents=True, exist_ok=True)
    agy_workspace_agents_dir.mkdir(parents=True, exist_ok=True)
    agy_plugin_agents_dir.mkdir(parents=True, exist_ok=True)

    count = 0
    for agent_file in sorted(src_agents.glob("*.md")):
        raw_text = agent_file.read_text(encoding="utf-8")
        meta, body = parse_frontmatter(raw_text)

        raw_name = str(meta.get("name", agent_file.stem))
        desc = str(
            meta.get(
                "description",
                f"Morphe specialist subagent for {raw_name}.",
            )
        )
        clean_body = sanitize_prompt_body(body, plugin_rel_path)

        # 1. Generate OpenAI Codex TOML agent (.codex/agents/<name>.toml)
        sandbox_mode = "read-only" if raw_name in READ_ONLY_AGENTS else "workspace-write"
        toml_content = (
            f"# Auto-generated from {agent_file.as_posix()}\n"
            f'name = {json.dumps(raw_name)}\n'
            f'description = {json.dumps(desc)}\n'
            f'sandbox_mode = "{sandbox_mode}"\n'
            f'model_reasoning_effort = "high"\n'
            f"developer_instructions = {format_toml_multiline(clean_body)}\n"
        )
        (codex_agents_dir / f"{agent_file.stem}.toml").write_text(toml_content, encoding="utf-8")

        # 2. Generate Google Antigravity Markdown agent
        claude_tools = meta.get("tools", []) if isinstance(meta.get("tools"), list) else []
        agy_tools = map_tools_for_antigravity(claude_tools, raw_name)

        tools_yaml = ""
        if not omit_agy_tools and agy_tools:
            tools_lines = "\n".join(f"  - {t}" for t in agy_tools)
            tools_yaml = f"tools:\n{tools_lines}\n"

        agy_md_content = (
            f"---\n"
            f"name: {raw_name}\n"
            f"description: {json.dumps(desc)}\n"
            f"{tools_yaml}"
            f"subagent: true\n"
            f"mainAgent: false\n"
            f"model: inherit\n"
            f"commandExecutionPolicy: sandbox\n"
            f"---\n\n"
            f"{clean_body}\n"
        )

        # Workspace subagents follow the standard structure: .agents/agents/<name>/agent.md
        workspace_agent_dir = agy_workspace_agents_dir / agent_file.stem
        workspace_agent_dir.mkdir(parents=True, exist_ok=True)
        (workspace_agent_dir / "agent.md").write_text(agy_md_content, encoding="utf-8")

        # Clean up legacy flat file if present
        legacy_flat_file = agy_workspace_agents_dir / f"{agent_file.stem}.md"
        if legacy_flat_file.is_file():
            legacy_flat_file.unlink()

        (agy_plugin_agents_dir / f"{agent_file.stem}.md").write_text(agy_md_content, encoding="utf-8")
        count += 1

    return count


def ensure_codex_config(codex_dir: Path) -> None:
    """Create or update .codex/config.toml with multi-agent support enabled."""
    codex_dir.mkdir(parents=True, exist_ok=True)
    config_file = codex_dir / "config.toml"

    if config_file.exists():
        existing = config_file.read_text(encoding="utf-8")
        if "[agents]" in existing:
            return
        with config_file.open("a", encoding="utf-8") as f:
            f.write("\n[agents]\nenabled = true\nmax_concurrent_threads_per_session = 6\n")
    else:
        config_file.write_text(
            "# OpenAI Codex workspace configuration for morphe-ai\n"
            "[agents]\n"
            "enabled = true\n"
            "max_concurrent_threads_per_session = 6\n",
            encoding="utf-8",
        )


def write_antigravity_manifests(src_plugin: Path, agy_plugin_dir: Path) -> None:
    """Write Antigravity plugin.json both in .agents/plugins/ and in the source plugin root."""
    claude_manifest_path = src_plugin / ".claude-plugin" / "plugin.json"
    plugin_name = "morphe-patch-creator"
    plugin_desc = (
        "Morphe's AI-powered Android APK patching pipeline — multi-agent "
        "recon, decompilation, target hunting, patch writing, and validation."
    )

    if claude_manifest_path.exists():
        try:
            data = json.loads(claude_manifest_path.read_text(encoding="utf-8"))
            plugin_name = data.get("name", plugin_name)
            plugin_desc = data.get("description", plugin_desc)
        except json.JSONDecodeError:
            pass

    agy_manifest = {
        "$schema": "https://antigravity.google/schemas/v1/plugin.json",
        "name": plugin_name,
        "description": plugin_desc,
    }

    agy_plugin_dir.mkdir(parents=True, exist_ok=True)
    manifest_json = json.dumps(agy_manifest, indent=2) + "\n"
    (agy_plugin_dir / "plugin.json").write_text(manifest_json, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Port plugins/morphe-patch-creator to OpenAI Codex and Google Antigravity."
    )
    parser.add_argument(
        "--plugin-dir",
        default="plugins/morphe-patch-creator",
        help="Path to the Claude plugin directory (default: plugins/morphe-patch-creator)",
    )
    parser.add_argument(
        "--omit-agy-tools",
        action="store_true",
        help="Omit explicit 'tools:' list in Antigravity subagents so they inherit all parent tools",
    )
    args = parser.parse_args()

    repo_root = Path.cwd()
    src_plugin = (repo_root / args.plugin_dir).resolve()

    if not src_plugin.is_dir():
        raise SystemExit(f"Error: Plugin directory not found at {src_plugin}")

    plugin_rel_path = src_plugin.relative_to(repo_root).as_posix()

    # Target directories
    shared_skills_dir = repo_root / ".agents" / "skills"
    agy_workspace_agents_dir = repo_root / ".agents" / "agents"
    agy_plugin_dir = repo_root / ".agents" / "plugins" / "morphe-patch-creator"
    codex_dir = repo_root / ".codex"
    codex_agents_dir = codex_dir / "agents"

    # 1. Port Skills & Commands
    skills_count = port_skills_and_commands(
        src_plugin=src_plugin,
        shared_skills_dir=shared_skills_dir,
        agy_plugin_skills_dir=agy_plugin_dir / "skills",
        plugin_rel_path=plugin_rel_path,
    )

    # 2. Port Subagents
    agents_count = port_agents(
        src_plugin=src_plugin,
        codex_agents_dir=codex_agents_dir,
        agy_workspace_agents_dir=agy_workspace_agents_dir,
        agy_plugin_agents_dir=agy_plugin_dir / "agents",
        plugin_rel_path=plugin_rel_path,
        omit_agy_tools=args.omit_agy_tools,
    )

    # 3. Write Codex & Antigravity Manifests/Configs
    ensure_codex_config(codex_dir)
    write_antigravity_manifests(src_plugin, agy_plugin_dir)

    print(f"Port complete from '{plugin_rel_path}':")
    print(f"  - Skills/Commands ported : {skills_count} -> .agents/skills/")
    print(f"  - Codex TOML subagents   : {agents_count} -> .codex/agents/*.toml")
    print(f"  - Codex config           : .codex/config.toml")
    print(f"  - Antigravity subagents  : {agents_count} -> .agents/agents/<name>/agent.md")
    print(f"  - Antigravity plugin pkg : .agents/plugins/morphe-patch-creator/")


if __name__ == "__main__":
    main()