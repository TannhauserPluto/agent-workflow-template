#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

CLEAN_UNTRACKED=0
if [ "${1:-}" = "--clean-untracked" ]; then
  CLEAN_UNTRACKED=1
fi

if [ ! -f .checkpoints/latest ]; then
  echo "No checkpoint found: .checkpoints/latest does not exist."
  exit 1
fi

BASE="$(cat .checkpoints/latest)"
PATCH="${BASE}.patch"
STAGED_PATCH="${BASE}.staged.patch"
UNTRACKED_TAR="${BASE}.untracked.tar"
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

echo "This will reset tracked working-tree changes and restore the latest checkpoint patches."
echo "By default, untracked files created after the checkpoint will NOT be deleted."
echo
echo "To also delete untracked files, run:"
echo "  bash scripts/restore_checkpoint.sh --clean-untracked"
echo
read -r -p "Continue? Type YES: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
  echo "Aborted."
  exit 0
fi

git restore --staged . || true
git restore . || true

if [ "$CLEAN_UNTRACKED" = "1" ]; then
  echo "Cleaning untracked files..."
  git clean -fd
fi

if [ -s "$PATCH" ]; then
  git apply "$PATCH"
  echo "Unstaged patch restored from: $PATCH"
else
  echo "Unstaged checkpoint patch was empty."
fi

if [ -f "$STAGED_PATCH" ] && [ -s "$STAGED_PATCH" ]; then
  git apply --cached "$STAGED_PATCH"
  echo "Staged patch restored from: $STAGED_PATCH"
else
  echo "Staged checkpoint patch was empty."
fi

if [ -f "$UNTRACKED_TAR" ] && [ -s "$UNTRACKED_TAR" ]; then
  tar -xf "$UNTRACKED_TAR"
  echo "Untracked files restored from: $UNTRACKED_TAR"
else
  echo "No untracked-file archive in this checkpoint."
fi

echo
git status --short
