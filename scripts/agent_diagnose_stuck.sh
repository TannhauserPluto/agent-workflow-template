#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/agent_diagnose_stuck.sh [--feature <slug>]

Generate a stuck-agent diagnostic report under .agent-logs/.

Options:
  --feature <slug>   Use specs/<slug>.md and plans/<slug>-plan.md.
                     If not supplied, inferred from the current branch.

The report is written to .agent-logs/stuck-report-<timestamp>.md and its
path is printed to stdout.
USAGE
  exit 1
}

FEATURE=""
FEATURE_SUPPLIED=0

validate_feature_slug() {
  local slug="$1"
  case "$slug" in
    *[!A-Za-z0-9._-]*|"")
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --feature)
      FEATURE="${2:-}"
      if [ -z "$FEATURE" ]; then
        echo "Error: --feature requires a value."
        usage
      fi
      FEATURE_SUPPLIED=1
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

# Resolve repo root.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  echo "Error: not inside a git repository."
  exit 1
fi
cd "$ROOT"

CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo "detached")"
HEAD_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo "unknown")"
HEAD_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
WORKTREE_PATH="$(git rev-parse --show-toplevel)"

# Infer feature slug from branch when not supplied.
if [ -z "$FEATURE" ]; then
  if [[ "$CURRENT_BRANCH" =~ ^(feat|fix|rescue)/(.+)$ ]]; then
    FEATURE="${BASH_REMATCH[2]}"
  fi
fi

if [ -n "$FEATURE" ] && ! validate_feature_slug "$FEATURE"; then
  if [ "$FEATURE_SUPPLIED" = "1" ]; then
    echo "Error: unsafe feature slug: $FEATURE"
    echo "Allowed characters: A-Z a-z 0-9 . _ -"
    exit 1
  fi
  echo "Warning: inferred unsafe feature slug '$FEATURE'; spec/plan lookup disabled." >&2
  FEATURE=""
fi

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
LOGS_DIR="$ROOT/.agent-logs"
mkdir -p "$LOGS_DIR"

REPORT_PATH="${LOGS_DIR}/stuck-report-${TIMESTAMP}.md"

SPEC_PATH=""
PLAN_PATH=""

if [ -n "$FEATURE" ]; then
  SPEC_PATH="specs/${FEATURE}.md"
  PLAN_PATH="plans/${FEATURE}-plan.md"
fi

# Best-effort discovery for test and reviewer logs.
discover_logs() {
  local dir="$1"
  if [ -d "$dir" ]; then
    find "$dir" -maxdepth 1 -type f ! -name 'stuck-report-*' ! -name 'recovery-*' 2>/dev/null | sort | head -n 20 || true
  fi
}

discover_escalation_bundles() {
  local dir=".agent-escalation"
  if [ -d "$dir" ]; then
    find "$dir" -maxdepth 1 -type d -name 'escalation-*' 2>/dev/null | sort -r | head -n 3 || true
  fi
}

print_file_excerpt() {
  local path="$1"
  local lines="$2"

  if [ -f "$path" ]; then
    echo "#### $path"
    echo
    echo '```'
    head -n "$lines" "$path" 2>/dev/null || true
    echo '```'
    echo
  fi
}

ESC_BUNDLES="$(discover_escalation_bundles)"

{
  echo "# Stuck Agent Diagnostic Report"
  echo
  echo "## Summary"
  echo
  echo "- **Timestamp**: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- **Repo root**: $(git rev-parse --show-toplevel)"
  echo "- **Worktree path**: $WORKTREE_PATH"
  echo "- **Branch**: $CURRENT_BRANCH"
  echo "- **HEAD**: $HEAD_SHORT ($HEAD_COMMIT)"
  echo

  if [ -n "$FEATURE" ]; then
    echo "- **Inferred feature slug**: $FEATURE"
    echo
  fi

  echo "## Evidence Discovery Summary"
  echo
  echo "### Escalation bundles"
  echo
  if [ -n "$ESC_BUNDLES" ]; then
    echo '```'
    echo "$ESC_BUNDLES"
    echo '```'
    echo
    echo "Newest escalation bundle evidence is included later in this report when present:"
    echo
    echo "- escalation.md"
    echo "- reviewer-output.txt"
    echo "- test-output.txt"
    echo "- status.txt"
    echo "- git-log.txt"
    echo "- checkpoints.txt"
  else
    echo "(empty or missing)"
  fi
  echo

  echo "## Git Status"
  echo
  echo '```'
  git status --short --branch
  echo '```'
  echo

  echo "## Diff Stat"
  echo
  echo '```'
  git diff --stat
  echo '```'
  echo

  echo "## Unstaged Diff"
  echo
  echo '```diff'
  git diff
  echo '```'
  echo

  echo "## Staged Diff"
  echo
  echo '```diff'
  git diff --staged
  echo '```'
  echo

  echo "## Untracked Files"
  echo
  echo '```'
  git ls-files --others --exclude-standard
  echo '```'
  echo

  echo "## Recent Git Log"
  echo
  echo '```'
  git log --oneline --decorate -n 20
  echo '```'
  echo

  echo "## Recent Checkpoints"
  echo
  if [ -d ".checkpoints" ]; then
    if [ -f ".checkpoints/latest" ]; then
      LATEST_CHECKPOINT="$(cat .checkpoints/latest)"
      echo "- **Latest checkpoint**: $LATEST_CHECKPOINT"
      echo
      if [ -f "${LATEST_CHECKPOINT}.meta.txt" ]; then
        echo "### Latest checkpoint metadata"
        echo
        echo '```'
        cat "${LATEST_CHECKPOINT}.meta.txt"
        echo '```'
        echo
      fi
    else
      echo "- **Latest checkpoint**: NOT FOUND"
      echo
    fi

    echo "### Checkpoint files (newest first)"
    echo
    echo '```'
    find .checkpoints -maxdepth 1 -type f ! -name 'latest' 2>/dev/null | sort -r | head -n 40 || true
    echo '```'
  else
    echo "- **Checkpoints**: MISSING (no .checkpoints directory)"
  fi
  echo

  echo "## Recent Checks / Reviewer Logs"
  echo
  echo "### .agent-logs/"
  echo
  AGENT_LOG_FILES="$(discover_logs ".agent-logs")"
  if [ -n "$AGENT_LOG_FILES" ]; then
    echo '```'
    echo "$AGENT_LOG_FILES"
    echo '```'
    echo
    # Include contents of small log files (skip binary/large)
    while IFS= read -r logfile; do
      if [ -f "$logfile" ] && [ -s "$logfile" ]; then
        echo "#### $(basename "$logfile")"
        echo
        echo '```'
        head -n 100 "$logfile" 2>/dev/null || true
        echo '```'
        echo
      fi
    done <<< "$AGENT_LOG_FILES"
  else
    echo "(empty or missing)"
    echo
  fi

  echo "### .agent-escalation/"
  echo
  if [ -n "$ESC_BUNDLES" ]; then
    echo '```'
    echo "$ESC_BUNDLES"
    echo '```'
    echo

    while IFS= read -r bundle; do
      [ -n "$bundle" ] || continue
      [ -d "$bundle" ] || continue

      echo "### Escalation Bundle: $(basename "$bundle")"
      echo
      echo "#### Included evidence files"
      echo
      echo '```'
      find "$bundle" -maxdepth 1 -type f 2>/dev/null | sort || true
      echo '```'
      echo

      print_file_excerpt "$bundle/escalation.md" 160
      print_file_excerpt "$bundle/reviewer-output.txt" 120
      print_file_excerpt "$bundle/test-output.txt" 120
      print_file_excerpt "$bundle/status.txt" 80
      print_file_excerpt "$bundle/git-log.txt" 80
      print_file_excerpt "$bundle/checkpoints.txt" 80
    done <<< "$ESC_BUNDLES"
  else
    echo "(empty or missing)"
  fi
  echo

  echo "## Related Spec"
  echo
  if [ -n "$SPEC_PATH" ] && [ -f "$SPEC_PATH" ]; then
    echo "Path: $SPEC_PATH"
    echo
    echo '```'
    cat "$SPEC_PATH"
    echo '```'
  elif [ -n "$SPEC_PATH" ]; then
    echo "NOT FOUND: $SPEC_PATH"
  else
    echo "NOT FOUND: could not determine spec path (no feature slug available)"
  fi
  echo

  echo "## Related Plan"
  echo
  if [ -n "$PLAN_PATH" ] && [ -f "$PLAN_PATH" ]; then
    echo "Path: $PLAN_PATH"
    echo
    echo '```'
    cat "$PLAN_PATH"
    echo '```'
  elif [ -n "$PLAN_PATH" ]; then
    echo "NOT FOUND: $PLAN_PATH"
  else
    echo "NOT FOUND: could not determine plan path (no feature slug available)"
  fi
  echo

} > "$REPORT_PATH"

echo "$REPORT_PATH"
