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

case "$FEATURE" in
  *[!A-Za-z0-9._-]*|"")
    echo "Error: unsafe feature slug: $FEATURE"
    echo "Allowed characters: A-Z a-z 0-9 . _ -"
    exit 1
    ;;
esac

SPEC="specs/${FEATURE}.md"
PLAN="plans/${FEATURE}-plan.md"
VALIDATION_REPORT="docs/${FEATURE}-validation.md"

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

mkdir -p .agent-logs

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
PACKET=".agent-logs/codex-review-packet-${FEATURE}-${TIMESTAMP}.md"
PROMPT_FILE=".agent-logs/codex-review-prompt-${FEATURE}-${TIMESTAMP}.md"
MODEL="${CODEX_REVIEWER_MODEL:-gpt-5.4-mini}"

append_file() {
  local title="$1"
  local file="$2"

  echo
  echo "## $title"
  echo

  if [ -f "$file" ]; then
    echo "----- BEGIN $file -----"
    cat "$file"
    echo
    echo "----- END $file -----"
  else
    echo "NOT FOUND: $file"
  fi
}

append_cmd() {
  local title="$1"
  shift

  echo
  echo "## $title"
  echo
  echo "Command: $*"
  echo "----- BEGIN OUTPUT -----"

  set +e
  "$@" 2>&1
  local rc=$?
  set -e

  echo "----- END OUTPUT -----"
  echo "Exit code: $rc"
}

{
  echo "# Codex Review Packet"
  echo
  echo "Feature: $FEATURE"
  echo "Generated at: $TIMESTAMP"
  echo "Current branch: $(git branch --show-current 2>/dev/null || echo UNKNOWN)"
  echo "HEAD: $(git rev-parse --short HEAD 2>/dev/null || echo UNKNOWN)"
  echo
  echo "This packet is generated locally before invoking Codex."
  echo "Treat this packet as authoritative review evidence."
  echo "If Codex sandbox or bubblewrap shell reads fail, review from this packet instead of claiming missing diff or missing behavior evidence."
  echo

  append_file "Active spec" "$SPEC"
  append_file "Active plan" "$PLAN"

  if [ -f "$VALIDATION_REPORT" ]; then
    append_file "Validation report" "$VALIDATION_REPORT"
  fi

  if [ "$FEATURE" = "recovery-escalation" ] && [ -f "docs/recovery-escalation-validation.md" ]; then
    append_file "Recovery escalation validation report" "docs/recovery-escalation-validation.md"
  fi

  append_cmd "git status --short" git status --short
  append_cmd "git diff --cached --stat" git diff --cached --stat
  append_cmd "git diff --cached" git diff --cached
  append_cmd "git diff --stat" git diff --stat
  append_cmd "git diff" git diff

  echo
  echo "## Shell syntax checks"
  echo

  for script_file in \
    scripts/new_feature_spec.sh \
    scripts/run_codex_planner.sh \
    scripts/run_codex_reviewer.sh \
    scripts/agent_diagnose_stuck.sh \
    scripts/agent_recover_to_point.sh \
    scripts/escalate_to_codex.sh
  do
    if [ -f "$script_file" ]; then
      append_cmd "bash -n $script_file" bash -n "$script_file"
    else
      echo
      echo "## bash -n $script_file"
      echo
      echo "SKIP: file not found"
    fi
  done

  append_cmd "just check" just check

  echo
  echo "## Reviewer guidance"
  echo
  echo "- Review staged diff first."
  echo "- Review unstaged diff as a warning if present."
  echo "- Do not claim missing diff if git diff --cached is included above."
  echo "- Do not claim missing behavior evidence if it is documented in the validation report above."
  echo "- Still request changes for real safety bugs, scope drift, missing guards, or inconsistent docs."
} > "$PACKET"

{
  cat prompts/codex_reviewer.md
  echo
  echo "# Additional reviewer instruction"
  echo
  echo "Use the following locally generated review packet as the primary evidence."
  echo "If shell access fails inside Codex, do not discard the packet."
  echo "Return a clear verdict: APPROVE, REQUEST_CHANGES, or COMMENT."
  echo
  cat "$PACKET"
  echo
  echo "Return the review verdict."
} > "$PROMPT_FILE"

echo "Review packet: $PACKET"
echo "Prompt file:   $PROMPT_FILE"

codex exec -C . -m "$MODEL" - < "$PROMPT_FILE"
