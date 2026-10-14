#!/usr/bin/env bash
# select-repo.sh [repo_name]
# Switch or list active patch repository

CONFIG_FILE="/home/ikura/morphe-ai/.morphe/config.json"
ENV_FILE="/home/ikura/morphe-ai/.env"

if [ -z "$1" ]; then
  CURRENT=$(grep "^MORPHE_PATCHES_DIR=" "$ENV_FILE" 2>/dev/null | cut -d= -f2)
  echo "Active repository: ${CURRENT:-unset}"
  echo "Available patch repositories in workspace:"
  for dir in /home/ikura/morphe-ai/*/; do
    b=$(basename "$dir")
    if [ -f "$dir/build.gradle.kts" ] || [ -d "$dir/patches" ]; then
      if [ "$b" = "$CURRENT" ]; then
        echo "  * $b (active)"
      else
        echo "    $b"
      fi
    fi
  done
  echo
  echo "Usage: ./select-repo.sh <repo_name>"
  exit 0
fi

TARGET="$1"
if [ ! -d "/home/ikura/morphe-ai/$TARGET" ]; then
  echo "Error: Directory /home/ikura/morphe-ai/$TARGET does not exist."
  echo "To add a new repository, clone it into /home/ikura/morphe-ai/<name>"
  exit 1
fi

if grep -q "^MORPHE_PATCHES_DIR=" "$ENV_FILE"; then
  sed -i "s|^MORPHE_PATCHES_DIR=.*|MORPHE_PATCHES_DIR=$TARGET|" "$ENV_FILE"
else
  echo "MORPHE_PATCHES_DIR=$TARGET" >> "$ENV_FILE"
fi

if [ -f "$CONFIG_FILE" ]; then
  python3 -c "import json; p='$CONFIG_FILE'; d=json.load(open(p)); d['patchesDir']='$TARGET'; json.dump(d, open(p,'w'), indent=2)"
fi

echo "Successfully switched active repository to: $TARGET"
