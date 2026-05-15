#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

mkdir -p .agent-logs

{
  echo "===== $(date '+%F %T') ====="
  echo "[git status]"
  git status --short || true
  echo
  echo "[git diff stat]"
  git diff --stat || true
  echo
} >> .agent-logs/post_tool_use.log
