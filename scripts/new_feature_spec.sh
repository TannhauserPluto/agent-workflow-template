#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: scripts/new_feature_spec.sh <feature-slug> <request>"
  echo
  echo "Example:"
  echo "  scripts/new_feature_spec.sh auth-login 'Build email login with FastAPI and React'"
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

BRANCH="$(git branch --show-current)"

if [ -z "$BRANCH" ]; then
  echo "Refusing to create spec/plan on a detached HEAD."
  exit 1
fi

if [ "$BRANCH" = "main" ]; then
  echo "Refusing to create spec/plan directly on main."
  echo "Create a task branch or worktree first, for example:"
  echo "  scripts/new_task_worktree.sh feat/<feature> ../wt-<feature>"
  exit 1
fi

FEATURE="$1"
REQUEST="$2"

SPEC="specs/${FEATURE}.md"
PLAN="plans/${FEATURE}-plan.md"

if [ -f "$SPEC" ] || [ -f "$PLAN" ]; then
  echo "Spec or plan already exists:"
  echo "  $SPEC"
  echo "  $PLAN"
  exit 1
fi

cat > "$SPEC" <<EOF_SPEC
# Goal

$REQUEST

# Non-goals

# User stories

# Acceptance criteria

# Constraints

# Risks

# Rollback plan
EOF_SPEC

cat > "$PLAN" <<EOF_PLAN
# Scope

# Milestones

# Files likely to change

# Test plan

# Risk checkpoints

# PR split plan
EOF_PLAN

echo "Created:"
echo "  $SPEC"
echo "  $PLAN"
echo
echo "Next:"
echo "  Use Codex Planner to refine these files."
