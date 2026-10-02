#!/usr/bin/env bash
# validate-workspace.sh — inspect and validate the Morphe workspace and .morphe/config.json.
#
# Usage: validate-workspace.sh [project-dir]
#
#   project-dir  Absolute or relative project root (default: $CLAUDE_PROJECT_DIR or $PWD).
#
# Config is OPTIONAL — the workflow proceeds with defaults when no .morphe/config.json
# is present.  When the file exists every key and nested value is validated strictly
# against the schema documented in schemas/config.schema.json.

set -euo pipefail

PROJECT_DIR=${1:-${CLAUDE_PROJECT_DIR:-$PWD}}
CONFIG=${MORPHE_CONFIG:-$PROJECT_DIR/.morphe/config.json}

python3 - "$PROJECT_DIR" "$CONFIG" <<'PY'
import json
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Schema — mirrors schemas/config.schema.json; kept in sync manually.
# Config is OPTIONAL (may be entirely absent).  When present all supplied
# keys are validated; unknown keys are rejected.  Nested objects are
# validated recursively with their own required-field and value checks.
# ---------------------------------------------------------------------------
ALLOWED_TOP_KEYS = {"analysisDir", "patchesDir", "cliJar", "keystorePath", "decompiler"}
ALLOWED_DECOMPILER_KEYS = {"mode", "remoteProvider"}
ALLOWED_DECOMPILER_MODES = {"local", "remote"}
ALLOWED_REMOTE_PROVIDERS = {"jadx-decompiler-gui", None}

DEFAULTS = {
    "analysisDir": "analysis",
    "patchesDir": None,
    "cliJar": "morphe-cli.jar",
    "keystorePath": None,
    "decompiler": {"mode": "local", "remoteProvider": None},
}


def validate_config(supplied: dict) -> list[str]:
    """Return a list of human-readable validation errors (empty == valid)."""
    errors: list[str] = []

    # Unknown top-level keys.
    unknown = set(supplied) - ALLOWED_TOP_KEYS
    if unknown:
        errors.append(f"Unknown config keys: {', '.join(sorted(unknown))}")

    # analysisDir — required non-empty string when present.
    if "analysisDir" in supplied:
        v = supplied["analysisDir"]
        if not isinstance(v, str) or not v.strip():
            errors.append("analysisDir must be a non-empty string")

    # patchesDir — null or non-empty string when present.
    if "patchesDir" in supplied:
        v = supplied["patchesDir"]
        if v is not None and (not isinstance(v, str) or not v.strip()):
            errors.append("patchesDir must be null or a non-empty string")

    # cliJar — required non-empty string when present.
    if "cliJar" in supplied:
        v = supplied["cliJar"]
        if not isinstance(v, str) or not v.strip():
            errors.append("cliJar must be a non-empty string")

    # keystorePath — null or non-empty string when present.
    if "keystorePath" in supplied:
        v = supplied["keystorePath"]
        if v is not None and (not isinstance(v, str) or not v.strip()):
            errors.append("keystorePath must be null or a non-empty string")

    # decompiler — must be an object with exactly the allowed keys and values.
    if "decompiler" in supplied:
        d = supplied["decompiler"]
        if not isinstance(d, dict):
            errors.append("decompiler must be an object")
        else:
            unknown_d = set(d) - ALLOWED_DECOMPILER_KEYS
            if unknown_d:
                errors.append(
                    f"decompiler contains unknown keys: {', '.join(sorted(unknown_d))}"
                )
            if "mode" in d and d["mode"] not in ALLOWED_DECOMPILER_MODES:
                errors.append(
                    f"decompiler.mode must be one of "
                    f"{sorted(ALLOWED_DECOMPILER_MODES)}; got {d['mode']!r}"
                )
            if "remoteProvider" in d and d["remoteProvider"] not in ALLOWED_REMOTE_PROVIDERS:
                real_allowed = [x for x in sorted(ALLOWED_REMOTE_PROVIDERS, key=lambda x: (x is None, x or "")) if x is not None]
                errors.append(
                    f"decompiler.remoteProvider must be null or one of "
                    f"{real_allowed}; got {d['remoteProvider']!r}"
                )

            final_mode = d.get("mode", "local")
            final_provider = d.get("remoteProvider")
            if final_mode == "remote" and final_provider != "jadx-decompiler-gui":
                errors.append(
                    "decompiler.remoteProvider must be 'jadx-decompiler-gui' when mode is 'remote'"
                )
            if final_mode == "local" and final_provider is not None:
                errors.append(
                    "decompiler.remoteProvider must be null when mode is 'local'"
                )

    return errors


# ---------------------------------------------------------------------------
project_dir_raw = sys.argv[1]
config_path_raw = sys.argv[2]

project = Path(project_dir_raw).expanduser().resolve()
config_path = Path(config_path_raw).expanduser()
if not config_path.is_absolute():
    config_path = project / config_path

# Merge supplied config over defaults.
config = dict(DEFAULTS)
config["decompiler"] = dict(DEFAULTS["decompiler"])

config_source = "defaults/discovery"
if config_path.exists():
    config_source = str(config_path)
    try:
        supplied = json.loads(config_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid config JSON in {config_path}: {exc}")

    if not isinstance(supplied, dict):
        raise SystemExit(f"Config must be a JSON object: {config_path}")

    errors = validate_config(supplied)
    if errors:
        raise SystemExit(
            "Config validation failed:\n" + "\n".join(f"  {e}" for e in errors)
        )

    # Apply top-level scalars.
    for k in ALLOWED_TOP_KEYS - {"decompiler"}:
        if k in supplied:
            config[k] = supplied[k]

    # Deep-merge decompiler object.
    if "decompiler" in supplied:
        config["decompiler"].update(supplied["decompiler"])


def resolve(value):
    if value is None:
        return None
    path = Path(value).expanduser()
    return path if path.is_absolute() else project / path


print(f"project: {project}")
print(f"config: {config_source}")

analysis = resolve(config["analysisDir"])
print(f"analysis: {analysis} ({'exists' if analysis and analysis.exists() else 'will be created when initialized'})")

patches = resolve(config["patchesDir"])
print(f"patches: {patches or 'unresolved'}")
if patches is not None:
    print(f"patches-gradle-wrapper: {'yes' if (patches / 'gradlew').is_file() else 'no'}")

cli = resolve(config["cliJar"])
print(f"cli: {cli} ({'exists' if cli and cli.is_file() else 'missing'})")

keystore = resolve(config["keystorePath"])
print(f"keystore: {'configured' if keystore else 'not configured'}")

decompiler_mode = config["decompiler"].get("mode", "local")
decompiler_provider = config["decompiler"].get("remoteProvider")
if decompiler_mode == "remote" and decompiler_provider:
    print(f"decompiler: {decompiler_mode} ({decompiler_provider})")
else:
    print(f"decompiler: {decompiler_mode}")

states = sorted(analysis.glob('*/notes/morphe-workflow.json')) if (analysis and analysis.exists()) else []
print(f"workflow-states: {len(states)}")
for state_file in states:
    try:
        data = json.loads(state_file.read_text(encoding='utf-8'))
        stages_str = ', '.join(
            f"{name}={details.get('status', '?')}"
            for name, details in data.get('stages', {}).items()
        )
        print(f"  {data.get('app', state_file.parents[1].name)}: {stages_str}")
    except (OSError, json.JSONDecodeError) as exc:
        print(f"  INVALID {state_file}: {exc}")
PY
