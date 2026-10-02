#!/usr/bin/env python3
"""Create or verify self-contained Claude agent Markdown adapters."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
FORBIDDEN = {
    r"/home/(?:kali|paresh)(?:/|\b)": "machine-specific home path",
    r"\bparesh-patches(?:/|\b)": "fixed personal patch repository",
    r"\b(?:fs_read|fs_write|execute_bash|use_subagent|delegate)\b": "Kiro-specific tool name",
}
REQUIRED = ("name", "description")


def split_frontmatter(text: str) -> tuple[dict[str, str], str]:
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end < 0:
        raise ValueError("frontmatter is not terminated")
    values: dict[str, str] = {}
    for raw in text[4:end].splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if ":" not in raw:
            raise ValueError(f"invalid frontmatter line: {raw}")
        key, value = raw.split(":", 1)
        values[key.strip()] = value.strip()
    return values, text[end + 5 :]


def portability_errors(text: str) -> list[str]:
    errors = []
    for pattern, label in FORBIDDEN.items():
        for match in re.finditer(pattern, text):
            line = text.count("\n", 0, match.start()) + 1
            errors.append(f"line {line}: {label}: {match.group(0)!r}")
    return errors


def verify(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
        metadata, body = split_frontmatter(text)
    except (OSError, UnicodeError, ValueError) as exc:
        return [str(exc)]
    errors = []
    for field in REQUIRED:
        if not metadata.get(field):
            errors.append(f"missing frontmatter field: {field}")
    name = metadata.get("name", "")
    if name and not NAME_RE.fullmatch(name):
        errors.append(f"invalid agent name: {name}")
    if not body.strip():
        errors.append("empty agent prompt body")
    errors.extend(portability_errors(text))
    return errors


def cmd_check(args: argparse.Namespace) -> int:
    failed = False
    for value in args.files:
        path = Path(value)
        errors = verify(path)
        if errors:
            failed = True
            print(f"FAIL {path}", file=sys.stderr)
            for error in errors:
                print(f"  {error}", file=sys.stderr)
        else:
            print(f"OK {path}")
    return int(failed)


def cmd_create(args: argparse.Namespace) -> int:
    source = Path(args.source)
    output = Path(args.output)
    if output.exists() and not args.force:
        print(f"Refusing to overwrite existing output: {output}", file=sys.stderr)
        return 1
    text = source.read_text(encoding="utf-8")
    _, body = split_frontmatter(text)
    errors = portability_errors(body)
    if errors:
        print("Source body is not portable; review it before generating:", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1
    if not NAME_RE.fullmatch(args.name):
        print(f"Invalid agent name: {args.name}", file=sys.stderr)
        return 1
    metadata = [
        "---",
        f"name: {args.name}",
        f"description: {json.dumps(args.description, ensure_ascii=False)}",
        f"tools: {args.tools}",
        f"model: {args.model}",
        "---",
        "",
        f"<!-- Adapted from {source.as_posix()}; review platform-specific behavior before committing. -->",
        "",
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(metadata) + body.lstrip(), encoding="utf-8")
    errors = verify(output)
    if errors:
        output.unlink(missing_ok=True)
        print("Generated agent failed verification:", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1
    print(output)
    return 0


def build_parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    sub = root.add_subparsers(dest="command", required=True)
    check = sub.add_parser("check", help="Verify existing Claude agent Markdown")
    check.add_argument("files", nargs="+")
    check.set_defaults(func=cmd_check)
    create = sub.add_parser("create", help="Inject Claude frontmatter into a reviewed prompt body")
    create.add_argument("--source", required=True)
    create.add_argument("--output", required=True)
    create.add_argument("--name", required=True)
    create.add_argument("--description", required=True)
    create.add_argument("--tools", default="Read, Glob, Grep")
    create.add_argument("--model", default="inherit")
    create.add_argument("--force", action="store_true")
    create.set_defaults(func=cmd_create)
    return root


def main() -> int:
    args = build_parser().parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
