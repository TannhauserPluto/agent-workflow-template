#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

mkdir -p .checkpoints

TS="$(date '+%Y%m%d-%H%M%S')"
BRANCH="$(git branch --show-current 2>/dev/null || echo unknown)"
HEAD_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
SAFE_BRANCH="$(echo "$BRANCH" | tr '/ ' '__')"
BASE=".checkpoints/${TS}_${SAFE_BRANCH}_${HEAD_COMMIT}"

UNTRACKED_LIST="${BASE}.untracked.zlist"
UNTRACKED_TAR="${BASE}.untracked.tar"

git ls-files --others --exclude-standard -z > "$UNTRACKED_LIST"

{
  echo "timestamp: ${TS}"
  echo "branch: ${BRANCH}"
  echo "head: ${HEAD_COMMIT}"
  echo
  echo "[git status]"
  git status --short || true
  echo
  echo "[git diff --stat]"
  git diff --stat || true
  echo
  echo "[untracked files]"
  if [ -s "$UNTRACKED_LIST" ]; then
    tr '\0' '\n' < "$UNTRACKED_LIST"
  else
    echo "(none)"
  fi
} > "${BASE}.meta.txt"

git diff > "${BASE}.patch" || true
git diff --staged > "${BASE}.staged.patch" || true

if [ -s "$UNTRACKED_LIST" ]; then
  tar --null -T "$UNTRACKED_LIST" -cf "$UNTRACKED_TAR" 2>/dev/null || true
fi

echo "${BASE}" > .checkpoints/latest

echo "Checkpoint created: ${BASE}"
