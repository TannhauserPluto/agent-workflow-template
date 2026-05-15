#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

if [ ! -f .checkpoints/latest ]; then
  echo "No checkpoint found: .checkpoints/latest does not exist."
  exit 1
fi

BASE="$(cat .checkpoints/latest)"
PATCH="${BASE}.patch"
META="${BASE}.meta.txt"

echo "Latest checkpoint:"
echo "$BASE"
echo

if [ -f "$META" ]; then
  echo "===== checkpoint metadata ====="
  cat "$META"
  echo
fi

if [ ! -f "$PATCH" ]; then
  echo "Patch file not found: $PATCH"
  exit 1
fi

echo "This script will restore the latest checkpoint patch."
echo "Current uncommitted changes will be reset."
echo
read -r -p "Continue? Type YES: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
  echo "Aborted."
  exit 0
fi

git restore .
git clean -fd

if [ -s "$PATCH" ]; then
  git apply "$PATCH"
  echo "Patch restored from: $PATCH"
else
  echo "Checkpoint patch was empty. Working tree restored to clean HEAD."
fi

git status --short
