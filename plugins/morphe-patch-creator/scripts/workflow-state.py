#!/usr/bin/env python3
"""Manage Morphe workflow state without external dependencies."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

STAGES = ("recon", "decompile", "hunt", "write", "validate")
STATUSES = ("pending", "in_progress", "complete", "failed", "blocked")
APP_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
SHA256_RE = re.compile(r"^[a-f0-9]{64}$")
STAGE_ORDER = {stage: index for index, stage in enumerate(STAGES)}


def now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_value(value: str) -> str:
    normalized = value.strip().lower()
    if not SHA256_RE.fullmatch(normalized):
        raise argparse.ArgumentTypeError("expected exactly 64 hexadecimal characters")
    return normalized


def non_empty(value: str) -> str:
    if not value.strip():
        raise argparse.ArgumentTypeError("value must not be empty")
    return value


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_state(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"State file not found: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid workflow JSON in {path}: {exc}")
    if not isinstance(data, dict) or data.get("schemaVersion") != 1:
        raise SystemExit(f"Unsupported workflow schema in {path}")
    if not APP_RE.fullmatch(str(data.get("app", ""))):
        raise SystemExit(f"Invalid app key in {path}")
    stages = data.get("stages")
    if not isinstance(stages, dict) or any(name not in stages for name in STAGES):
        raise SystemExit(f"Workflow state is missing required stages: {path}")
    for name in STAGES:
        stage = stages[name]
        if not isinstance(stage, dict) or stage.get("status") not in STATUSES:
            raise SystemExit(f"Invalid {name} stage in {path}")
        if not isinstance(stage.get("evidence"), list):
            raise SystemExit(f"Invalid {name} evidence in {path}")
    return data


def atomic_write(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent, text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, path)
    except BaseException:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise


def new_stage() -> dict[str, Any]:
    return {"status": "pending", "evidence": [], "error": None, "updatedAt": None}


def project_root(state_path: Path, state: dict[str, Any]) -> Path:
    configured = state.get("configuration", {}).get("projectDir")
    if configured:
        return Path(configured).expanduser().resolve()

    analysis_value = state.get("configuration", {}).get("analysisDir", "analysis")
    analysis_path = Path(analysis_value).expanduser()
    if analysis_path.is_absolute():
        return analysis_path.resolve().parent

    # Backward-compatible inference for schema-v1 files without projectDir.
    resolved_state = state_path.expanduser().resolve()
    expected_tail = (*analysis_path.parts, state["app"], "notes", resolved_state.name)
    if tuple(resolved_state.parts[-len(expected_tail):]) == expected_tail:
        root = resolved_state
        for _ in expected_tail:
            root = root.parent
        return root
    return Path.cwd().resolve()


def resolve_recorded_path(value: str, root: Path) -> Path:
    path = Path(value).expanduser()
    return path.resolve() if path.is_absolute() else (root / path).resolve()


def require_existing_paths(values: list[str], root: Path, label: str) -> None:
    missing = [value for value in values if not resolve_recorded_path(value, root).exists()]
    if missing:
        lines = "\n".join(f"  {value}" for value in missing)
        raise SystemExit(f"{label} path(s) do not exist relative to {root}:\n{lines}")


def prior_incomplete(state: dict[str, Any], target: str) -> list[str]:
    target_index = STAGE_ORDER[target]
    return [
        name
        for name, index in STAGE_ORDER.items()
        if index < target_index and state["stages"][name]["status"] != "complete"
    ]


def has_approval(state: dict[str, Any], approval_type: str) -> bool:
    return any(item.get("type") == approval_type for item in state.get("approvals", []))


def cmd_init(args: argparse.Namespace) -> None:
    path = Path(args.state)
    if not APP_RE.fullmatch(args.app):
        raise SystemExit("App key must contain only lowercase letters, digits, dot, underscore, or hyphen")

    root = Path(args.project_dir).expanduser().resolve()
    input_path = resolve_recorded_path(args.input_path, root)
    if not input_path.is_file():
        raise SystemExit(f"Input path is not a file: {args.input_path}")
    actual_hash = file_sha256(input_path)
    if actual_hash != args.sha256:
        raise SystemExit(f"Input SHA-256 does not match {args.input_path}")

    if path.exists() and not args.force:
        existing = load_state(path)
        if existing["app"] != args.app:
            raise SystemExit(f"State already belongs to app {existing['app']!r}: {path}")
        if existing.get("input", {}).get("sha256") != args.sha256:
            raise SystemExit(f"State already exists with a different input hash: {path}")
        print(path)
        return

    state = {
        "schemaVersion": 1,
        "app": args.app,
        "request": args.request,
        "input": {"path": args.input_path, "sha256": args.sha256},
        "configuration": {
            "projectDir": str(root),
            "analysisDir": args.analysis_dir,
            "patchesDir": args.patches_dir,
            "decompiler": args.decompiler,
        },
        "stages": {stage: new_stage() for stage in STAGES},
        "approvals": [],
        "outputs": [],
        "updatedAt": now(),
    }
    atomic_write(path, state)
    print(path)


def cmd_set_stage(args: argparse.Namespace) -> None:
    path = Path(args.state)
    state = load_state(path)
    stage = state["stages"][args.stage]
    merged = list(dict.fromkeys([*stage.get("evidence", []), *(args.evidence or [])]))

    if args.status in {"in_progress", "complete"}:
        incomplete = prior_incomplete(state, args.stage)
        if incomplete:
            raise SystemExit(
                f"Cannot mark {args.stage} {args.status}: prior stage(s) are incomplete: "
                + ", ".join(incomplete)
            )
    if args.stage == "write" and args.status in {"in_progress", "complete"}:
        if not has_approval(state, "patch-source"):
            raise SystemExit("Cannot advance write stage without a recorded patch-source approval")
    if args.status == "complete":
        if not merged:
            raise SystemExit("A completed stage must have at least one evidence path")
        require_existing_paths(merged, project_root(path, state), "Evidence")
    if args.status in {"failed", "blocked"} and not args.error:
        raise SystemExit(f"Status {args.status} requires --error")

    stage["evidence"] = merged
    stage["status"] = args.status
    stage["error"] = None if args.status in {"pending", "in_progress", "complete"} else args.error
    stage["updatedAt"] = now()
    state["updatedAt"] = stage["updatedAt"]
    atomic_write(path, state)
    print(f"{args.stage}: {args.status}")


def cmd_approve(args: argparse.Namespace) -> None:
    path = Path(args.state)
    state = load_state(path)
    duplicate = any(
        item.get("type") == args.type and item.get("scope") == args.scope
        for item in state.get("approvals", [])
    )
    if duplicate:
        print(f"approval already recorded: {args.type}")
        return
    state["approvals"].append({"type": args.type, "recordedAt": now(), "scope": args.scope})
    state["updatedAt"] = now()
    atomic_write(path, state)
    print(f"approval recorded: {args.type}")


def cmd_add_output(args: argparse.Namespace) -> None:
    path = Path(args.state)
    state = load_state(path)
    require_existing_paths([args.output], project_root(path, state), "Output")
    if args.output not in state["outputs"]:
        state["outputs"].append(args.output)
    state["updatedAt"] = now()
    atomic_write(path, state)
    print(args.output)


def cmd_show(args: argparse.Namespace) -> None:
    state = load_state(Path(args.state))
    if args.json:
        print(json.dumps(state, indent=2, ensure_ascii=False))
        return
    print(f"App: {state['app']}")
    print(f"Request: {state['request']}")
    print(f"Input: {state['input']['path']}")
    for name in STAGES:
        stage = state["stages"][name]
        suffix = f" — {stage['error']}" if stage.get("error") else ""
        print(f"{name:10} {stage['status']}{suffix}")
        for evidence in stage.get("evidence", []):
            print(f"             evidence: {evidence}")
    for output in state.get("outputs", []):
        print(f"output: {output}")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    sub = root.add_subparsers(dest="command", required=True)

    init = sub.add_parser("init", help="Create or verify a workflow state file")
    init.add_argument("--state", required=True)
    init.add_argument("--app", required=True)
    init.add_argument("--request", required=True, type=non_empty)
    init.add_argument("--input-path", required=True)
    init.add_argument("--sha256", required=True, type=sha256_value)
    init.add_argument("--project-dir", default=str(Path.cwd()))
    init.add_argument("--analysis-dir", required=True)
    init.add_argument("--patches-dir")
    init.add_argument("--decompiler", choices=("local", "remote"), default="local")
    init.add_argument("--force", action="store_true")
    init.set_defaults(func=cmd_init)

    set_stage = sub.add_parser("set-stage", help="Update a workflow stage")
    set_stage.add_argument("--state", required=True)
    set_stage.add_argument("--stage", choices=STAGES, required=True)
    set_stage.add_argument("--status", choices=STATUSES, required=True)
    set_stage.add_argument("--evidence", action="append")
    set_stage.add_argument("--error")
    set_stage.set_defaults(func=cmd_set_stage)

    approve = sub.add_parser("approve", help="Record a scoped user approval")
    approve.add_argument("--state", required=True)
    approve.add_argument("--type", required=True, type=non_empty)
    approve.add_argument("--scope", required=True, type=non_empty)
    approve.set_defaults(func=cmd_approve)

    output = sub.add_parser("add-output", help="Record an existing generated output")
    output.add_argument("--state", required=True)
    output.add_argument("--output", required=True, type=non_empty)
    output.set_defaults(func=cmd_add_output)

    show = sub.add_parser("show", help="Display workflow state")
    show.add_argument("--state", required=True)
    show.add_argument("--json", action="store_true")
    show.set_defaults(func=cmd_show)
    return root


def main() -> int:
    args = parser().parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
