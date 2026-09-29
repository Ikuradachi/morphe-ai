#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <apk|apkm|apks|xapk|zip> [output-file]" >&2
  exit 2
}
[[ $# -ge 1 && $# -le 2 ]] || usage
INPUT=$1
OUTPUT=${2:-}
[[ -f $INPUT && -r $INPUT ]] || { echo "Input is not a readable file: $INPUT" >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "Missing required command: unzip" >&2; exit 1; }
unzip -tqq -- "$INPUT" >/dev/null || { echo "Input is not a valid ZIP-based Android package: $INPUT" >&2; exit 1; }

TMPDIR_LOCAL=$(mktemp -d "${TMPDIR:-/tmp}/morphe-inspect.XXXXXX")
trap 'rm -rf -- "$TMPDIR_LOCAL"' EXIT
SOURCE=$INPUT
MEMBER=
case ${INPUT##*.} in
  apk|APK) ;;
  *)
    MEMBER=$(unzip -Z1 -- "$INPUT" | awk 'tolower($0) ~ /(^|\/)base[^\/]*\.apk$/ { print; exit }')
    if [[ -z $MEMBER ]]; then
      echo "No base-named APK found in container. Candidates:" >&2
      unzip -Z1 -- "$INPUT" | awk 'tolower($0) ~ /\.apk$/ { print "  " $0 }' >&2
      exit 1
    fi
    SOURCE=$TMPDIR_LOCAL/base.apk
    unzip -p -- "$INPUT" "$MEMBER" > "$SOURCE"
    unzip -tqq -- "$SOURCE" >/dev/null || { echo "Selected base member is invalid: $MEMBER" >&2; exit 1; }
    ;;
esac

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum -- "$1" | awk '{print $1}'
  else shasum -a 256 -- "$1" | awk '{print $1}'; fi
}

report() {
  echo "# Morphe APK Inspection"
  echo "input: $INPUT"
  echo "sha256: $(hash_file "$INPUT")"
  echo "container-extension: ${INPUT##*.}"
  [[ -z $MEMBER ]] || echo "selected-base-member: $MEMBER"
  if command -v file >/dev/null 2>&1; then echo "file: $(file -b -- "$INPUT")"; fi

  echo
  echo "## DEX entries"
  unzip -Z1 -- "$SOURCE" | awk 'tolower($0) ~ /(^|\/)classes([0-9]+)?\.dex$/ { print }' || true

  echo
  echo "## Framework indicators"
  unzip -Z1 -- "$SOURCE" | awk 'tolower($0) ~ /(index\.android\.bundle|libflutter\.so|libapp\.so)$/ { print }' || true

  echo
  echo "## Native ABIs"
  unzip -Z1 -- "$SOURCE" | awk -F/ '$1 == "lib" && NF >= 3 { print $2 }' | sort -u || true

  if command -v aapt >/dev/null 2>&1; then
    echo
    echo "## AAPT badging"
    aapt dump badging "$SOURCE" 2>&1 | sed -n '1,20p' || true
    echo
    echo "## Split manifest evidence"
    aapt dump xmltree "$SOURCE" AndroidManifest.xml 2>/dev/null | awk 'tolower($0) ~ /(split|requiredsplit)/ { print }' | sed -n '1,40p' || true
  else
    echo
    echo "## AAPT badging"
    echo "unavailable: aapt is not installed"
  fi
}

if [[ -n $OUTPUT ]]; then
  mkdir -p -- "$(dirname -- "$OUTPUT")"
  report > "$OUTPUT"
  echo "$OUTPUT"
else
  report
fi
