#!/usr/bin/env bash
set -euo pipefail

FORCE=0

if [ "${1:-}" = "--force" ] || [ "${1:-}" = "-f" ]; then
  FORCE=1
  shift
fi

if [ $# -lt 1 ]; then
  echo "Usage: scripts/remove_task_worktree.sh [--force] <worktree-dir> [branch-name]"
  echo
  echo "Examples:"
  echo "  scripts/remove_task_worktree.sh ../wt-auth-login feat/auth-login"
  echo "  scripts/remove_task_worktree.sh --force ../wt-auth-login feat/auth-login"
  exit 1
fi

WORKTREE_DIR="$1"
BRANCH="${2:-}"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [ "$FORCE" = "1" ]; then
  echo "Force removing worktree: ${WORKTREE_DIR}"
  git worktree remove --force "$WORKTREE_DIR"
else
  echo "Removing worktree: ${WORKTREE_DIR}"
  git worktree remove "$WORKTREE_DIR"
fi

if [ -n "$BRANCH" ]; then
  if [ "$FORCE" = "1" ]; then
    echo "Force deleting local branch: ${BRANCH}"
    git branch -D "$BRANCH" || true
  else
    echo "Deleting local branch if fully merged: ${BRANCH}"
    git branch -d "$BRANCH" || {
      echo
      echo "Branch was not deleted safely."
      echo "If this was squash-merged or intentionally discarded, run:"
      echo "  scripts/remove_task_worktree.sh --force ${WORKTREE_DIR} ${BRANCH}"
      exit 1
    }
  fi
fi

git worktree prune

echo "Done."
