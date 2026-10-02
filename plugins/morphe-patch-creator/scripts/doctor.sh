#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=${1:-${CLAUDE_PROJECT_DIR:-$PWD}}
required=(python3 file unzip rg aapt jadx baksmali java)
optional=(adb gh uv uvx jadx-decompiler-gui)
missing=0

echo "Morphe Patch Creator doctor"
echo "project: $PROJECT_DIR"
echo

echo "Required for the complete local pipeline:"
for command_name in "${required[@]}"; do
  if path=$(command -v "$command_name" 2>/dev/null); then
    printf '  OK      %-24s %s\n' "$command_name" "$path"
  else
    printf '  MISSING %s\n' "$command_name"
    missing=1
  fi
done

echo
echo "Optional capabilities:"
for command_name in "${optional[@]}"; do
  if path=$(command -v "$command_name" 2>/dev/null); then
    printf '  OK      %-24s %s\n' "$command_name" "$path"
  else
    printf '  absent  %s\n' "$command_name"
  fi
done

echo
if [[ -f $PROJECT_DIR/.morphe/config.json ]]; then
  echo "config: $PROJECT_DIR/.morphe/config.json"
elif [[ -f $PROJECT_DIR/plugins/morphe-patch-creator/config.example.json ]]; then
  echo "config: not created (example available in repository plugin checkout)"
else
  echo "config: not created (optional; the workflow can discover or ask)"
fi

# Java version check — require major version >= 21
if command -v java >/dev/null 2>&1; then
  java_version_output=$(java -version 2>&1 | sed -n '1p')
  # Extract major version: handles "17.0.x", "21.0.x", "1.8.0_xxx" formats
  java_major=$(java -version 2>&1 \
    | sed -n '1p' \
    | sed 's/.*version "\([0-9]*\).*/\1/')
  # Handle legacy 1.x format (e.g. Java 8 reports "1.8")
  if [[ "$java_major" == "1" ]]; then
    java_major=$(java -version 2>&1 \
      | sed -n '1p' \
      | sed 's/.*version "1\.\([0-9]*\).*/\1/')
  fi
  printf 'java: %s\n' "$java_version_output"
  if [[ "$java_major" -ge 21 ]] 2>/dev/null; then
    printf '  java major: %s — OK (>=21 required for CLI runtime)\n' "$java_major"
  else
    printf '  java major: %s — INSUFFICIENT (>=21 required for Morphe CLI runtime)\n' \
      "${java_major:-unknown}" >&2
    missing=1
  fi
fi

# Morphe CLI detection — only report version when jar exists, using -V (non-mutating)
CLI_JAR="${MORPHE_CLI:-$PROJECT_DIR/morphe-cli.jar}"
if [[ -f "$CLI_JAR" ]]; then
  CLI_VERSION=$(java -jar "$CLI_JAR" -V 2>/dev/null \
                || java -jar "$CLI_JAR" --version 2>/dev/null \
                || echo "unknown")
  printf 'morphe-cli: %s (jar: %s)\n' "$CLI_VERSION" "$CLI_JAR"
else
  printf 'morphe-cli: jar not found at %s (optional for recon/decompile stages)\n' "$CLI_JAR"
fi

if [[ $missing -ne 0 ]]; then
  echo
  echo "One or more required tools are missing or Java is below version 21." >&2
  echo "This script never installs packages." >&2
  exit 1
fi
echo
echo "All required local-pipeline commands are available and Java >= 21."
