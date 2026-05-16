#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: scripts/start_agent_task.sh <feature-slug> <request>"
  echo
  echo "Example:"
  echo "  scripts/start_agent_task.sh auth-login 'Build email login with FastAPI and React'"
  exit 1
fi

FEATURE="$1"
REQUEST="$2"

BRANCH="feat/${FEATURE}"
WORKTREE_DIR="../wt-${FEATURE}"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CURRENT_BRANCH="$(git branch --show-current)"

if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "This script must be run from main."
  echo "Current branch: $CURRENT_BRANCH"
  exit 1
fi

git fetch origin

git pull --ff-only

if [ -n "$(git status --porcelain)" ]; then
  echo "Main is not clean. Commit or discard changes first."
  git status --short
  exit 1
fi

if [ -d "$WORKTREE_DIR" ]; then
  echo "Worktree directory already exists: $WORKTREE_DIR"
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Branch already exists: $BRANCH"
  exit 1
fi

echo "Creating task branch and worktree..."
scripts/new_task_worktree.sh "$BRANCH" "$WORKTREE_DIR"

echo
echo "Creating spec and plan inside worktree..."
cd "$WORKTREE_DIR"
scripts/new_feature_spec.sh "$FEATURE" "$REQUEST"

echo
echo "Task initialized."
echo
echo "Feature:"
echo "  $FEATURE"
echo
echo "Branch:"
echo "  $BRANCH"
echo
echo "Worktree:"
echo "  $WORKTREE_DIR"
echo
echo "Created files:"
echo "  specs/${FEATURE}.md"
echo "  plans/${FEATURE}-plan.md"
echo
echo "Next steps:"
echo "  cd $WORKTREE_DIR"
echo "  scripts/run_codex_planner.sh $FEATURE \"$REQUEST\""
echo "  claude"
echo
echo "Before PR:"
echo "  just check"
echo "  scripts/run_codex_reviewer.sh $FEATURE"
echo
