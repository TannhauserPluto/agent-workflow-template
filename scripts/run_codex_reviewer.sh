#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: scripts/run_codex_reviewer.sh <feature-slug>"
  echo
  echo "Example:"
  echo "  scripts/run_codex_reviewer.sh auth-login"
  exit 1
fi

FEATURE="$1"
SPEC="specs/${FEATURE}.md"
PLAN="plans/${FEATURE}-plan.md"

if [ ! -f "$SPEC" ]; then
  echo "Missing spec: $SPEC"
  exit 1
fi

if [ ! -f "$PLAN" ]; then
  echo "Missing plan: $PLAN"
  exit 1
fi

if [ ! -f "prompts/codex_reviewer.md" ]; then
  echo "Missing reviewer prompt: prompts/codex_reviewer.md"
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found."
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

git status --short > "$TMP_DIR/status.txt"
git diff --stat > "$TMP_DIR/diffstat.txt"
git diff > "$TMP_DIR/diff.patch"

{
  echo "# Shell syntax checks"
  echo

  for script in \
    scripts/new_feature_spec.sh \
    scripts/run_codex_planner.sh \
    scripts/run_codex_reviewer.sh
  do
    if [ -f "$script" ]; then
      echo "## bash -n $script"
      if bash -n "$script"; then
        echo "PASS"
      else
        echo "FAIL"
      fi
      echo
    else
      echo "## bash -n $script"
      echo "SKIP: file not found"
      echo
    fi
  done

  echo "# just check output"
  echo
  just check
} > "$TMP_DIR/check-output.txt" 2>&1 || true

cat <<EOF_PROMPT | codex exec -C . -m "${CODEX_REVIEWER_MODEL:-gpt-5.4-mini}" -
$(cat prompts/codex_reviewer.md)

Active spec:
$(cat "$SPEC")

Active plan:
$(cat "$PLAN")

Git status:
$(cat "$TMP_DIR/status.txt")

Git diff stat:
$(cat "$TMP_DIR/diffstat.txt")

Git diff:
$(cat "$TMP_DIR/diff.patch")

Test output:
$(cat "$TMP_DIR/check-output.txt")

Return the review verdict.
EOF_PROMPT
