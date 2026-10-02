#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <app-key> <apk-or-container> <request> [analysis-dir]" >&2
  exit 2
}

[[ $# -ge 3 && $# -le 4 ]] || usage
APP=$1
INPUT=$2
REQUEST=$3
ANALYSIS_DIR=${4:-${MORPHE_ANALYSIS_DIR:-analysis}}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=${CLAUDE_PROJECT_DIR:-$PWD}

[[ $APP =~ ^[a-z0-9][a-z0-9._-]*$ ]] || {
  echo "Invalid app key: use lowercase letters, digits, dot, underscore, or hyphen" >&2
  exit 2
}
[[ -f $INPUT && -r $INPUT ]] || { echo "Input is not a readable file: $INPUT" >&2; exit 1; }

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$1" | awk '{print $1}'
  else
    echo "Neither sha256sum nor shasum is available" >&2
    return 1
  fi
}

canonical_path() {
  python3 - "$1" <<'PY'
import sys
from pathlib import Path
print(Path(sys.argv[1]).expanduser().resolve())
PY
}

APP_DIR=$ANALYSIS_DIR/$APP
APK_DIR=$APP_DIR/apk
NOTES_DIR=$APP_DIR/notes
STATE=$NOTES_DIR/morphe-workflow.json
DEST=$APK_DIR/$(basename -- "$INPUT")
SOURCE_HASH=$(hash_file "$INPUT")

# Reject a reused app key before copying a different package into its workspace.
if [[ -f $STATE ]]; then
  python3 - "$STATE" "$APP" "$SOURCE_HASH" <<'PY'
import json
import sys
from pathlib import Path
state_path, app, digest = sys.argv[1:]
try:
    state = json.loads(Path(state_path).read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    raise SystemExit(f"Cannot reuse invalid workflow state {state_path}: {exc}")
if state.get("app") != app:
    raise SystemExit(f"State belongs to app {state.get('app')!r}, not {app!r}")
if state.get("input", {}).get("sha256") != digest:
    raise SystemExit("Refusing to reuse an app workspace for a different input hash")
PY
fi

mkdir -p -- "$APK_DIR" "$NOTES_DIR" "$APP_DIR/builds"
if [[ -e $DEST ]]; then
  [[ -f $DEST ]] || { echo "Destination exists and is not a file: $DEST" >&2; exit 1; }
  [[ $(hash_file "$DEST") == "$SOURCE_HASH" ]] || {
    echo "Refusing to overwrite different existing input: $DEST" >&2
    exit 1
  }
elif [[ $(canonical_path "$INPUT") != $(canonical_path "$DEST") ]]; then
  cp -- "$INPUT" "$DEST"
fi

init_args=(
  "$SCRIPT_DIR/workflow-state.py" init
  --state "$STATE"
  --app "$APP"
  --request "$REQUEST"
  --input-path "$DEST"
  --sha256 "$SOURCE_HASH"
  --project-dir "$PROJECT_DIR"
  --analysis-dir "$ANALYSIS_DIR"
  --decompiler "${MORPHE_DECOMPILER:-local}"
)
[[ -n ${MORPHE_PATCHES_DIR:-} ]] && init_args+=(--patches-dir "$MORPHE_PATCHES_DIR")
python3 "${init_args[@]}"

SUMMARY=$NOTES_DIR/morphe-workflow.md
if [[ ! -e $SUMMARY ]]; then
  {
    printf '# Morphe Workflow: %s\n\n' "$APP"
    printf -- '- Request: %s\n' "$REQUEST"
    printf -- '- Input: `%s`\n' "$DEST"
    printf -- '- SHA-256: `%s`\n' "$SOURCE_HASH"
    printf -- '- State: `%s`\n' "$STATE"
  } > "$SUMMARY"
fi

printf 'Analysis directory: %s\nInput copy: %s\nState: %s\n' "$APP_DIR" "$DEST" "$STATE"
