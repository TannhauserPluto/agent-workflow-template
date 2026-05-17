#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/escalate_to_codex.sh [options]

Create an escalation bundle for Codex high review. Does NOT auto-invoke Codex.

Options:
  --feature <slug>        Feature slug for context (specs/<slug>.md,
                          plans/<slug>-plan.md).
  --stuck-report <path>   Use an existing stuck report instead of generating
                          a new one.
  --dry-run               Print what would be done without executing.

The bundle is written to .agent-escalation/escalation-<timestamp>/ and
contains everything Codex high needs to choose a recovery path.
USAGE
  exit 1
}

FEATURE=""
STUCK_REPORT=""
DRY_RUN=0

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
      shift 2
      ;;
    --stuck-report)
      STUCK_REPORT="${2:-}"
      if [ -z "$STUCK_REPORT" ]; then
        echo "Error: --stuck-report requires a path."
        usage
      fi
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
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

if [ -n "$FEATURE" ] && ! validate_feature_slug "$FEATURE"; then
  echo "Error: unsafe feature slug: $FEATURE"
  echo "Allowed characters: A-Z a-z 0-9 . _ -"
  exit 1
fi

# Resolve repo root.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  echo "Error: not inside a git repository."
  exit 1
fi
cd "$ROOT"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
ESC_DIR="$ROOT/.agent-escalation/escalation-${TIMESTAMP}"
SAFE_FEATURE=""
if [ -n "$FEATURE" ]; then
  SAFE_FEATURE="$(printf '%s' "$FEATURE" | tr -c 'A-Za-z0-9._-' '_')"
fi

newest_file() {
  local newest=""
  local candidate

  for candidate in "$@"; do
    [ -f "$candidate" ] || continue
    if [ -z "$newest" ] || [ "$candidate" -nt "$newest" ]; then
      newest="$candidate"
    fi
  done

  printf '%s\n' "$newest"
}

if [ "$DRY_RUN" = "1" ]; then
  echo "[dry-run] Would create escalation bundle at: $ESC_DIR"
fi

# Generate or copy stuck report.
STUCK_REPORT_PATH=""
if [ -n "$STUCK_REPORT" ]; then
  if [ ! -f "$STUCK_REPORT" ]; then
    echo "Error: stuck report not found: $STUCK_REPORT"
    exit 1
  fi
  STUCK_REPORT_PATH="$STUCK_REPORT"
  echo "Using existing stuck report: $STUCK_REPORT_PATH"
else
  echo "Generating stuck report..."
  DIAG_ARGS=()
  if [ -n "$FEATURE" ]; then
    DIAG_ARGS=(--feature "$FEATURE")
  fi
  if [ "$DRY_RUN" = "0" ]; then
    STUCK_REPORT_PATH="$(bash scripts/agent_diagnose_stuck.sh "${DIAG_ARGS[@]}")"
    echo "Stuck report: $STUCK_REPORT_PATH"
  else
    echo "[dry-run] Would run: scripts/agent_diagnose_stuck.sh ${DIAG_ARGS[*]}"
    STUCK_REPORT_PATH="[would-be-generated]"
  fi
fi

if [ "$DRY_RUN" = "1" ]; then
  echo
  echo "[dry-run] Bundle would contain:"
  echo "  escalation.md"
  echo "  stuck-report.md (from $STUCK_REPORT_PATH)"
  echo "  diff.patch"
  echo "  staged.diff.patch"
  echo "  status.txt"
  echo "  git-log.txt"
  echo "  checkpoints.txt"
  echo "  test-output.txt (if available)"
  echo "  reviewer-output.txt (latest reviewer output/review packet if available)"
  echo
  echo "[dry-run] No files written."
  exit 0
fi

mkdir -p "$ESC_DIR"

# --- Collect bundle artifacts ---

cd "$ROOT"

# diff.patch
git diff > "$ESC_DIR/diff.patch"

# staged.diff.patch
git diff --staged > "$ESC_DIR/staged.diff.patch"

# status.txt
git status --short --branch > "$ESC_DIR/status.txt"

# git-log.txt
git log --oneline --decorate -n 30 > "$ESC_DIR/git-log.txt"

# checkpoints.txt
{
  echo "Latest checkpoint:"
  if [ -f ".checkpoints/latest" ]; then
    cat .checkpoints/latest
    echo
    echo
    echo "Checkpoint files (newest first):"
    find .checkpoints -maxdepth 1 -type f ! -name 'latest' 2>/dev/null | sort -r | head -n 40 || true
  else
    echo "NONE"
  fi
} > "$ESC_DIR/checkpoints.txt"

# stuck-report.md
if [ -n "$STUCK_REPORT_PATH" ] && [ -f "$STUCK_REPORT_PATH" ]; then
  cp "$STUCK_REPORT_PATH" "$ESC_DIR/stuck-report.md"
else
  echo "Stuck report was not generated or not found." > "$ESC_DIR/stuck-report.md"
fi

# test-output.txt (best-effort discovery)
TEST_OUT=""
for candidate in \
  ".agent-logs/test-output.txt" \
  ".agent-logs/test.log" \
  "test-results.txt" \
  ".check-output.txt"; do
  if [ -f "$candidate" ]; then
    TEST_OUT="$candidate"
    break
  fi
done
if [ -n "$TEST_OUT" ]; then
  cp "$TEST_OUT" "$ESC_DIR/test-output.txt"
else
  echo "(no test output discovered)" > "$ESC_DIR/test-output.txt"
fi

# reviewer-output.txt (best-effort discovery)
REVIEWER_OUT=""
if [ -n "$SAFE_FEATURE" ]; then
  REVIEWER_OUT="$(newest_file \
    .agent-logs/codex-review-packet-"$SAFE_FEATURE"-*.md \
    .agent-logs/reviewer-output-"$SAFE_FEATURE"-*.txt \
    .agent-logs/reviewer-"$SAFE_FEATURE"-*.log)"
fi
if [ -z "$REVIEWER_OUT" ]; then
  REVIEWER_OUT="$(newest_file \
    .agent-logs/codex-review-packet-*.md \
    .agent-logs/reviewer-output*.txt \
    .agent-logs/reviewer*.log \
    review-results.txt)"
fi
if [ -n "$REVIEWER_OUT" ]; then
  cp "$REVIEWER_OUT" "$ESC_DIR/reviewer-output.txt"
else
  echo "(no reviewer output or codex review packet discovered in .agent-logs/)" > "$ESC_DIR/reviewer-output.txt"
fi

# --- Build escalation.md ---

# Read context from spec and plan if available.
SPEC_CONTENT=""
PLAN_CONTENT=""
SPEC_PATH=""
PLAN_PATH=""
if [ -n "$FEATURE" ]; then
  SPEC_PATH="specs/${FEATURE}.md"
  PLAN_PATH="plans/${FEATURE}-plan.md"
  [ -f "$SPEC_PATH" ] && SPEC_CONTENT="$(cat "$SPEC_PATH")"
  [ -f "$PLAN_PATH" ] && PLAN_CONTENT="$(cat "$PLAN_PATH")"
fi

CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo "detached")"
HEAD_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"

{
  echo "# Escalation Bundle"
  echo
  echo "## Context"
  echo
  echo "- **Escalation timestamp**: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- **Bundle ID**: escalation-${TIMESTAMP}"
  echo "- **Repo root**: $(git rev-parse --show-toplevel)"
  echo "- **Current branch**: $CURRENT_BRANCH"
  echo "- **HEAD**: $HEAD_SHORT"
  if [ -n "$FEATURE" ]; then
    echo "- **Feature slug**: $FEATURE"
  fi
  echo
  if [ -n "$SPEC_PATH" ] && [ -f "$SPEC_PATH" ]; then
    echo "### Active Spec"
    echo
    echo '```'
    echo "$SPEC_CONTENT"
    echo '```'
    echo
  fi
  if [ -n "$PLAN_PATH" ] && [ -f "$PLAN_PATH" ]; then
    echo "### Active Plan"
    echo
    echo '```'
    echo "$PLAN_CONTENT"
    echo '```'
    echo
  fi

  echo "## Stuck Summary"
  echo
  echo "<!-- CLAUDE CODE: fill in a concise description of what is stuck below -->"
  echo
  echo "**What is stuck**: [DESCRIBE]"
  echo
  echo "**What was attempted**: [DESCRIBE]"
  echo
  echo "**Why it cannot proceed without Codex high**: [DESCRIBE]"
  echo
  echo "<!-- END STUCK SUMMARY -->"
  echo

  echo "## Bundle Contents"
  echo
  for f in \
    escalation.md \
    stuck-report.md \
    diff.patch \
    staged.diff.patch \
    status.txt \
    git-log.txt \
    checkpoints.txt \
    test-output.txt \
    reviewer-output.txt; do
    if [ -f "$ESC_DIR/$f" ]; then
      SIZE="$(wc -c < "$ESC_DIR/$f")"
      echo "- \`$f\` ($SIZE bytes)"
    else
      echo "- \`$f\` (MISSING)"
    fi
  done
  echo

  echo "## Recovery Decision Menu for Codex High"
  echo
  echo "Codex high must choose ONE of the following recovery paths:"
  echo
  echo "### 1. Continue on current branch"
  echo
  echo "The current state is acceptable. Claude Code should continue implementation"
  echo "from the current HEAD. No recovery action needed."
  echo
  echo "Command: (none, resume execution)"
  echo
  echo "### 2. Recover to checkpoint"
  echo
  echo "Restore the latest checkpoint onto the current working tree."
  echo
  echo "Command:"
  echo '```bash'
  echo 'scripts/agent_recover_to_point.sh --checkpoint latest'
  echo '```'
  echo
  echo "### 3. Recover to a specific commit"
  echo
  echo "Create a rescue branch from a known-stable commit without modifying the"
  echo "current branch (safe, preferred)."
  echo
  echo "Command:"
  echo '```bash'
  echo 'scripts/agent_recover_to_point.sh --commit <sha> --new-branch rescue/<name>'
  echo '```'
  echo
  echo "### 4. Reset current branch to a commit (DESTRUCTIVE)"
  echo
  echo "WARNING: This modifies the current branch. Requires Codex high explicit"
  echo "approval and the --confirm-reset-current flag. Will NOT be used on main."
  echo
  echo "Command:"
  echo '```bash'
  echo 'scripts/agent_recover_to_point.sh --commit <sha> --reset-current --confirm-reset-current'
  echo '```'
  echo
  echo "### 5. Escalate to direct Codex fix"
  echo
  echo "The situation requires Codex to take over and implement fixes directly."
  echo
  echo "Action: Codex high takes ownership of this branch and implements the fix."
  echo
  echo "## Safety Rules (Non-Negotiable)"
  echo
  echo "- Do not use destructive recovery by default."
  echo "- Do not use \`git reset --hard\`."
  echo "- Do not use \`git clean -fd\` by default."
  echo "- Always save failure state before any recovery action."
  echo "- Prefer creating rescue branches/worktrees over rewriting the current branch."
  echo "- Never delete, reset, or rewrite \`main\`."
  echo "- Never auto-merge PRs."
  echo "- Claude Code + DeepSeek must not independently decide major rollback or rescue-branch strategy."
  echo
  echo "## Suggested Prompt for Codex High"
  echo
  echo '```text'
  echo "I am Claude Code, stuck while implementing feature '${FEATURE:-unknown}' on branch '${CURRENT_BRANCH}'."
  echo
  echo "The stuck report, full diff, git log, checkpoints, and available test/reviewer"
  echo "output are attached in this escalation bundle."
  echo
  echo "Please review the evidence and choose ONE recovery path from the decision menu"
  echo "in escalation.md. Reply with the option number and any parameters (e.g., the"
  echo "target commit SHA for options 3 or 4)."
  echo
  echo "Bundle path: .agent-escalation/escalation-${TIMESTAMP}/"
  echo '```'

} > "$ESC_DIR/escalation.md"

echo
echo "Escalation bundle created: $ESC_DIR"
echo
echo "Bundle files:"
for f in "$ESC_DIR"/*; do
  echo "  $(basename "$f")"
done
echo
echo "Next step: present escalation.md to Codex high for recovery decision."
echo "  cat $ESC_DIR/escalation.md"
