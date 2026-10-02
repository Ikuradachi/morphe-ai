#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ANALYSIS_DIR=${MORPHE_ANALYSIS_DIR:-analysis}

show_state() {
  local state=$1
  printf '\n== %s ==\n' "$state"
  python3 "$SCRIPT_DIR/workflow-state.py" show --state "$state"
}

if [[ $# -eq 0 ]]; then
  found=0
  while IFS= read -r -d '' state; do
    found=1
    show_state "$state"
  done < <(find "$ANALYSIS_DIR" -type f -path '*/notes/morphe-workflow.json' -print0 2>/dev/null | sort -z)
  [[ $found -eq 1 ]] || { echo "No Morphe workflow state found under $ANALYSIS_DIR" >&2; exit 1; }
elif [[ $# -eq 1 ]]; then
  if [[ -f $1 ]]; then
    show_state "$1"
  else
    state=$ANALYSIS_DIR/$1/notes/morphe-workflow.json
    [[ -f $state ]] || { echo "State not found: $state" >&2; exit 1; }
    show_state "$state"
  fi
else
  echo "Usage: $0 [app-key|state-file]" >&2
  exit 2
fi
