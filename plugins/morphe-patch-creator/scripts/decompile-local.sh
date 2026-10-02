#!/usr/bin/env bash
# decompile-local.sh — run jadx on a local APK or split container.
#
# Usage: decompile-local.sh <apk|container> <output-directory>
#
# On success prints:
#   jadx-exit-status: <N>
#   java-files: <count>
#   sources-root: <absolute path of the jadx sources sub-directory>
#   output: <absolute path of the output directory>
#
# Exits non-zero when jadx produced zero Java/Kotlin source files.

set -euo pipefail

usage() {
  echo "Usage: $0 <apk|container> <output-directory>" >&2
  exit 2
}
[[ $# -eq 2 ]] || usage
INPUT=$1
OUTPUT=$2
[[ -f $INPUT && -r $INPUT ]] || { echo "Input is not a readable file: $INPUT" >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "Missing required command: unzip" >&2; exit 1; }
command -v jadx >/dev/null 2>&1  || { echo "Missing required command: jadx" >&2; exit 1; }

if [[ -d $OUTPUT && -n $(find "$OUTPUT" -mindepth 1 -print -quit 2>/dev/null) ]]; then
  echo "Refusing to overwrite non-empty decompile directory: $OUTPUT" >&2
  exit 1
fi

TMPDIR_LOCAL=$(mktemp -d "${TMPDIR:-/tmp}/morphe-jadx.XXXXXX")
trap 'rm -rf -- "$TMPDIR_LOCAL"' EXIT

SOURCE=$INPUT
case ${INPUT##*.} in
  apk|APK) ;;
  *)
    MEMBER=$(unzip -Z1 -- "$INPUT" | awk 'tolower($0) ~ /(^|\/)base[^\/]*\.apk$/ { print; exit }')
    [[ -n $MEMBER ]] || { echo "No base-named APK found in container" >&2; exit 1; }
    SOURCE=$TMPDIR_LOCAL/base.apk
    unzip -p -- "$INPUT" "$MEMBER" > "$SOURCE"
    ;;
esac

mkdir -p -- "$OUTPUT"
set +e
jadx --deobf --show-bad-code --no-res -d "$OUTPUT" "$SOURCE"
STATUS=$?
set -e

# Locate the sources sub-directory jadx uses (typically <output>/sources/).
# jadx may also place .java files directly under the output root.
SOURCES_ROOT="$OUTPUT"
if [[ -d "$OUTPUT/sources" ]]; then
  SOURCES_ROOT="$OUTPUT/sources"
fi

absolute_path() {
  python3 - "$1" <<'PY'
import sys
from pathlib import Path
print(Path(sys.argv[1]).expanduser().resolve())
PY
}

COUNT=$(find "$OUTPUT" -type f -name '*.java' | wc -l)
printf 'jadx-exit-status: %s\njava-files: %s\nsources-root: %s\noutput: %s\n' \
  "$STATUS" "$COUNT" "$(absolute_path "$SOURCES_ROOT")" "$(absolute_path "$OUTPUT")"

[[ $COUNT -gt 0 ]] || { echo "jadx produced no Java source files" >&2; exit 1; }

if [[ $STATUS -ne 0 ]]; then
  echo "warning: jadx returned $STATUS but produced usable source; preserve this warning in stage evidence" >&2
fi
exit 0
