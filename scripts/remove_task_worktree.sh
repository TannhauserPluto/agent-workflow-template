#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: scripts/remove_task_worktree.sh <worktree-dir> [branch-name]"
  echo
  echo "Example:"
  echo "  scripts/remove_task_worktree.sh ../wt-auth-login feat/auth-login"
  exit 1
fi

WORKTREE_DIR="$1"
BRANCH="${2:-}"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "Removing worktree: ${WORKTREE_DIR}"
git worktree remove "$WORKTREE_DIR"

if [ -n "$BRANCH" ]; then
  echo "Deleting local branch: ${BRANCH}"
  git branch -D "$BRANCH" || true
fi

git worktree prune

echo "Done."
