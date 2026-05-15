#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

mkdir -p .agent-logs

{
  echo "===== $(date '+%F %T') STOP ====="
  git status --short || true
  git diff --stat || true
} >> .agent-logs/stop_gate.log

# Do not block for now. We only log.
exit 0
