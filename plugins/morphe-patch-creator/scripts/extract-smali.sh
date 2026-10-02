#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <apk|container> <smali-output-directory>" >&2
  exit 2
}
[[ $# -eq 2 ]] || usage
INPUT=$1
OUTPUT=$2
[[ -f $INPUT && -r $INPUT ]] || { echo "Input is not a readable file: $INPUT" >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "Missing required command: unzip" >&2; exit 1; }
command -v baksmali >/dev/null 2>&1 || { echo "Missing required command: baksmali" >&2; exit 1; }
if [[ -d $OUTPUT && -n $(find "$OUTPUT" -mindepth 1 -print -quit 2>/dev/null) ]]; then
  echo "Refusing to overwrite non-empty smali directory: $OUTPUT" >&2
  exit 1
fi

TMPDIR_LOCAL=$(mktemp -d "${TMPDIR:-/tmp}/morphe-smali.XXXXXX")
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

mapfile -t DEX_ENTRIES < <(unzip -Z1 -- "$SOURCE" | awk 'tolower($0) ~ /(^|\/)classes([0-9]+)?\.dex$/ { print }')
[[ ${#DEX_ENTRIES[@]} -gt 0 ]] || { echo "No classes*.dex entries found" >&2; exit 1; }
STAGED=$TMPDIR_LOCAL/smali
mkdir -p -- "$STAGED"
for dex in "${DEX_ENTRIES[@]}"; do
  base=$(basename -- "$dex")
  name=${base%.dex}
  dex_file=$TMPDIR_LOCAL/$base
  unzip -p -- "$SOURCE" "$dex" > "$dex_file"
  baksmali d "$dex_file" -o "$STAGED/$name"
  printf 'disassembled: %s -> %s\n' "$dex" "$name"
done

COUNT=$(find "$STAGED" -type f -name '*.smali' | wc -l)
[[ $COUNT -gt 0 ]] || { echo "baksmali produced no smali files" >&2; exit 1; }
if [[ -d $OUTPUT ]]; then rmdir -- "$OUTPUT" 2>/dev/null || true; fi
mkdir -p -- "$(dirname -- "$OUTPUT")"
mv -- "$STAGED" "$OUTPUT"
printf 'dex-count: %s\nsmali-files: %s\noutput: %s\n' "${#DEX_ENTRIES[@]}" "$COUNT" "$OUTPUT"
