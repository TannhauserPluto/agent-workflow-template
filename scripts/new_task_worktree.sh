#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: scripts/new_task_worktree.sh <branch-name> [worktree-dir]"
  echo
  echo "Example:"
  echo "  scripts/new_task_worktree.sh feat/auth-login ../wt-auth-login"
  exit 1
fi

BRANCH="$1"
SAFE_NAME="$(echo "$BRANCH" | sed 's#[^A-Za-z0-9._-]#-#g')"
DEFAULT_DIR="../wt-${SAFE_NAME}"
WORKTREE_DIR="${2:-$DEFAULT_DIR}"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [ -n "$(git status --porcelain)" ]; then
  echo "Current working tree is not clean. Commit or discard changes first."
  git status --short
  exit 1
fi

git fetch origin

if git worktree list --porcelain | grep -q "branch refs/heads/${BRANCH}$"; then
  echo "A worktree for branch already exists: ${BRANCH}"
  git worktree list
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  echo "Using existing local branch: ${BRANCH}"
  git worktree add "$WORKTREE_DIR" "$BRANCH"
elif git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}"; then
  echo "Creating local branch from origin/${BRANCH}"
  git worktree add "$WORKTREE_DIR" -b "$BRANCH" "origin/${BRANCH}"
else
  echo "Creating new branch from main: ${BRANCH}"
  git worktree add "$WORKTREE_DIR" -b "$BRANCH" main
fi

echo
echo "Created task worktree:"
echo "  branch: ${BRANCH}"
echo "  path:   ${WORKTREE_DIR}"
echo
echo "Next:"
echo "  cd ${WORKTREE_DIR}"
echo "  claude"
