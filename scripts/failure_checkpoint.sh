#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

mkdir -p .checkpoints

TS="$(date '+%Y%m%d-%H%M%S')"
BRANCH="$(git branch --show-current 2>/dev/null || echo unknown)"
HEAD_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
BASE=".checkpoints/${TS}_${BRANCH}_${HEAD_COMMIT}"

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
} > "${BASE}.meta.txt"

git diff > "${BASE}.patch" || true

echo "${BASE}" > .checkpoints/latest

echo "Checkpoint created: ${BASE}"
