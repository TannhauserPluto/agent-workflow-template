#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/agent_recover_to_point.sh <form>

Safe recovery from a known commit or checkpoint. Saves failure state before
any recovery action. Never uses git reset --hard and never runs git clean -fd by default.

Forms:
  --checkpoint latest
      Restore the latest checkpoint patches onto the current working tree.
      Does not delete untracked files unless --clean-untracked is also given
      (explicit opt-in only).

  --commit <sha> --new-branch <branch>
      Create a new branch (and worktree when possible) from <sha> without
      modifying the current branch.

  --commit <sha> --reset-current --confirm-reset-current
      Restore tracked files in the current branch to <sha>. Saves rescue
      artifacts first. Refuses without --confirm-reset-current.

Options:
  --clean-untracked   Only valid with --checkpoint latest. Explicit opt-in to
                      clean untracked files after restore.
  --dry-run           Print what would be done without executing.

Safety rules:
  - Never operates destructively on main.
  - Saves failure state before any recovery action.
  - Prefers rescue branches over rewriting current branches.
  - Does not use git reset --hard. Does not use git clean -fd by default.
USAGE
  exit 1
}

MODE=""
CHECKPOINT_VAL=""
COMMIT_SHA=""
NEW_BRANCH=""
DRY_RUN=0
CLEAN_UNTRACKED=0
CONFIRM_RESET=0
RESET_CURRENT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --checkpoint)
      CHECKPOINT_VAL="${2:-}"
      if [ "$CHECKPOINT_VAL" != "latest" ]; then
        echo "Error: --checkpoint only supports 'latest'."
        usage
      fi
      shift 2
      ;;
    --commit)
      if [ -n "$COMMIT_SHA" ]; then
        echo "Error: --commit may only be specified once."
        usage
      fi
      COMMIT_SHA="${2:-}"
      if [ -z "$COMMIT_SHA" ]; then
        echo "Error: --commit requires a commit SHA."
        usage
      fi
      shift 2
      ;;
    --new-branch)
      if [ -n "$NEW_BRANCH" ]; then
        echo "Error: --new-branch may only be specified once."
        usage
      fi
      NEW_BRANCH="${2:-}"
      if [ -z "$NEW_BRANCH" ]; then
        echo "Error: --new-branch requires a branch name."
        usage
      fi
      shift 2
      ;;
    --reset-current)
      if [ "$RESET_CURRENT" = "1" ]; then
        echo "Error: --reset-current may only be specified once."
        usage
      fi
      RESET_CURRENT=1
      shift
      ;;
    --confirm-reset-current)
      CONFIRM_RESET=1
      shift
      ;;
    --clean-untracked)
      CLEAN_UNTRACKED=1
      shift
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

validate_args() {
  # Global invalid flag checks must run before mode-specific early returns.
  if [ "$CONFIRM_RESET" = "1" ] && [ "$RESET_CURRENT" != "1" ]; then
    echo "Error: --confirm-reset-current is only valid with --reset-current."
    usage
  fi

  if [ -n "$CHECKPOINT_VAL" ]; then
    if [ -n "$COMMIT_SHA" ] || [ -n "$NEW_BRANCH" ] || [ "$RESET_CURRENT" = "1" ]; then
      echo "Error: --checkpoint latest cannot be combined with --commit, --new-branch, or --reset-current."
      usage
    fi
    MODE="checkpoint"
    return
  fi

  if [ "$CLEAN_UNTRACKED" = "1" ]; then
    echo "Error: --clean-untracked is only valid with --checkpoint latest."
    usage
  fi

  if [ "$CONFIRM_RESET" = "1" ] && [ "$RESET_CURRENT" != "1" ]; then
    echo "Error: --confirm-reset-current is only valid with --reset-current."
    usage
  fi

  if [ -n "$NEW_BRANCH" ] && [ "$RESET_CURRENT" = "1" ]; then
    echo "Error: --new-branch and --reset-current are mutually exclusive."
    usage
  fi

  if [ -n "$NEW_BRANCH" ] && [ -z "$COMMIT_SHA" ]; then
    echo "Error: --new-branch is only valid with --commit <sha>."
    usage
  fi

  if [ "$RESET_CURRENT" = "1" ] && [ -z "$COMMIT_SHA" ]; then
    echo "Error: --reset-current is only valid with --commit <sha>."
    usage
  fi

  if [ -n "$COMMIT_SHA" ] && [ -z "$NEW_BRANCH" ] && [ "$RESET_CURRENT" != "1" ]; then
    echo "Error: --commit <sha> requires either --new-branch <branch> or --reset-current."
    usage
  fi

  if [ -n "$NEW_BRANCH" ]; then
    MODE="new-branch"
    return
  fi

  if [ "$RESET_CURRENT" = "1" ]; then
    MODE="reset-current"
    return
  fi
}

validate_args

if [ -z "$MODE" ]; then
  echo "Error: no recovery form specified."
  echo
  usage
fi

# Resolve repo root.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  echo "Error: not inside a git repository."
  exit 1
fi
cd "$ROOT"

CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo "detached")"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
LOGS_DIR="$ROOT/.agent-logs"
mkdir -p "$LOGS_DIR"

ACTION_LOG="${LOGS_DIR}/recovery-action-${TIMESTAMP}.md"
RESCUE_PATCH="${LOGS_DIR}/recovery-rescue-${TIMESTAMP}.patch"
RESCUE_STAGED="${LOGS_DIR}/recovery-rescue-${TIMESTAMP}.staged.patch"
RESCUE_STATUS="${LOGS_DIR}/recovery-rescue-${TIMESTAMP}.status.txt"
RESCUE_UNTRACKED_LIST="${LOGS_DIR}/recovery-rescue-${TIMESTAMP}.untracked.zlist"
RESCUE_UNTRACKED_TAR="${LOGS_DIR}/recovery-rescue-${TIMESTAMP}.untracked.tar"
FULL_SHA=""
BASE=""
RESCUE_DIR=""
PARTIAL_STATE=""

# ---------------------------------------------------------------------------
# Rescue artifact helpers
# ---------------------------------------------------------------------------

save_rescue_artifacts() {
  local tag="$1"
  echo "Saving rescue artifacts..."

  RESCUE_PATCH="${LOGS_DIR}/recovery-rescue-${tag}.patch"
  RESCUE_STAGED="${LOGS_DIR}/recovery-rescue-${tag}.staged.patch"
  RESCUE_STATUS="${LOGS_DIR}/recovery-rescue-${tag}.status.txt"
  RESCUE_UNTRACKED_LIST="${LOGS_DIR}/recovery-rescue-${tag}.untracked.zlist"
  RESCUE_UNTRACKED_TAR="${LOGS_DIR}/recovery-rescue-${tag}.untracked.tar"

  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] Would save rescue patch to $RESCUE_PATCH"
    echo "[dry-run] Would save rescue staged patch to $RESCUE_STAGED"
    echo "[dry-run] Would save rescue status to $RESCUE_STATUS"
    echo "[dry-run] Would list untracked files in $RESCUE_UNTRACKED_LIST"
    echo "[dry-run] Would archive untracked files in $RESCUE_UNTRACKED_TAR when present"
  else
    git diff > "$RESCUE_PATCH" || true
    git diff --staged > "$RESCUE_STAGED" || true
    git status --short --branch > "$RESCUE_STATUS" || true
    git ls-files --others --exclude-standard -z > "$RESCUE_UNTRACKED_LIST" || true
    if [ -s "$RESCUE_UNTRACKED_LIST" ]; then
      tar --null -T "$RESCUE_UNTRACKED_LIST" -cf "$RESCUE_UNTRACKED_TAR" 2>/dev/null || true
    fi

    echo "  $RESCUE_PATCH"
    echo "  $RESCUE_STAGED"
    echo "  $RESCUE_STATUS"
    echo "  $RESCUE_UNTRACKED_LIST"
    if [ -f "$RESCUE_UNTRACKED_TAR" ]; then
      echo "  $RESCUE_UNTRACKED_TAR"
    fi
  fi

  # Run failure_checkpoint.sh when available.
  if [ "$DRY_RUN" = "0" ] && [ -x "scripts/failure_checkpoint.sh" ]; then
    echo "Running scripts/failure_checkpoint.sh..."
    bash scripts/failure_checkpoint.sh || echo "Warning: failure_checkpoint.sh exited non-zero (continuing)"
  fi
}

record_recovery_attempt() {
  local status="$1"
  local reason="${2:-}"
  local detail="${3:-}"
  local branch_now
  local head_now

  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] Would record recovery attempt: $status"
    return
  fi

  branch_now="$(git branch --show-current 2>/dev/null || echo "detached")"
  head_now="$(git rev-parse HEAD 2>/dev/null || echo "unknown")"

  {
    echo "# Recovery Attempt"
    echo
    echo "- **Timestamp**: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- **Mode**: ${MODE:-unknown}"
    echo "- **Status**: $status"
    echo "- **Branch before recovery**: $CURRENT_BRANCH"
    echo "- **Current branch**: $branch_now"
    echo "- **HEAD**: $head_now"
    if [ -n "$COMMIT_SHA" ] || [ -n "$FULL_SHA" ]; then
      echo "- **Target commit**: ${FULL_SHA:-$COMMIT_SHA}"
    fi
    if [ -n "$CHECKPOINT_VAL" ] || [ -n "$BASE" ]; then
      echo "- **Target checkpoint**: ${BASE:-$CHECKPOINT_VAL}"
    fi
    if [ -n "$NEW_BRANCH" ]; then
      echo "- **New branch**: $NEW_BRANCH"
    fi
    if [ -n "$RESCUE_DIR" ]; then
      echo "- **Rescue worktree path**: $RESCUE_DIR"
    fi
    if [ -n "$PARTIAL_STATE" ]; then
      echo "- **Partial state**: $PARTIAL_STATE"
    fi
    if [ -n "$detail" ]; then
      echo "- **Detail**: $detail"
    fi
    if [ -n "$reason" ]; then
      echo "- **Failure reason**: $reason"
    else
      echo "- **Failure reason**: n/a"
    fi
    echo "- **Rescue patch**: ${RESCUE_PATCH#$ROOT/}"
    if [ -f "$RESCUE_PATCH" ]; then
      echo "- **Rescue patch exists**: yes"
    else
      echo "- **Rescue patch exists**: no"
    fi
    echo "- **Rescue staged**: ${RESCUE_STAGED#$ROOT/}"
    if [ -f "$RESCUE_STAGED" ]; then
      echo "- **Rescue staged exists**: yes"
    else
      echo "- **Rescue staged exists**: no"
    fi
    echo "- **Rescue status**: ${RESCUE_STATUS#$ROOT/}"
    if [ -f "$RESCUE_STATUS" ]; then
      echo "- **Rescue status exists**: yes"
    else
      echo "- **Rescue status exists**: no"
    fi
    echo "- **Rescue untracked list**: ${RESCUE_UNTRACKED_LIST#$ROOT/}"
    if [ -f "$RESCUE_UNTRACKED_LIST" ]; then
      echo "- **Rescue untracked list exists**: yes"
    else
      echo "- **Rescue untracked list exists**: no"
    fi
    echo "- **Rescue untracked archive**: ${RESCUE_UNTRACKED_TAR#$ROOT/}"
    if [ -f "$RESCUE_UNTRACKED_TAR" ]; then
      echo "- **Rescue untracked archive exists**: yes"
    else
      echo "- **Rescue untracked archive exists**: no"
    fi
    echo
    echo "## Git Status"
    echo
    echo '```'
    git status --short --branch || true
    echo '```'
  } > "$ACTION_LOG"

  echo "Recovery attempt recorded: $ACTION_LOG"
}

fail_recovery() {
  local reason="$1"
  echo "ERROR: $reason"
  record_recovery_attempt "failed" "$reason"
  exit 1
}

restore_staged_worktree_files() {
  local path

  while IFS= read -r -d '' path; do
    if ! git checkout-index -f -- "$path"; then
      return 1
    fi
  done < <(git diff --cached --diff-filter=ACMRT --name-only -z)

  while IFS= read -r -d '' path; do
    if ! rm -f -- "$path"; then
      return 1
    fi
  done < <(git diff --cached --diff-filter=D --name-only -z)
}

# ---------------------------------------------------------------------------
# Mode: checkpoint latest
# ---------------------------------------------------------------------------

do_checkpoint_recover() {
  echo "=== Recovery mode: checkpoint latest ==="

  if [ ! -f ".checkpoints/latest" ]; then
    fail_recovery "no checkpoint found (.checkpoints/latest does not exist)."
  fi

  BASE="$(cat .checkpoints/latest)"
  PATCH="${BASE}.patch"
  STAGED_PATCH="${BASE}.staged.patch"
  META="${BASE}.meta.txt"
  UNTRACKED_TAR="${BASE}.untracked.tar"

  echo "Latest checkpoint: $BASE"
  echo

  if [ -f "$META" ]; then
    echo "===== checkpoint metadata ====="
    cat "$META"
    echo
  fi

  if [ ! -f "$PATCH" ]; then
    fail_recovery "checkpoint patch file not found: $PATCH"
  fi

  # failure_checkpoint.sh uses second-resolution names. Avoid clobbering the
  # checkpoint selected above when recovery is invoked immediately after one.
  if [ "$DRY_RUN" = "0" ]; then
    sleep 1
  fi

  # Save rescue artifacts before recovery.
  save_rescue_artifacts "$TIMESTAMP"

  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] Would restore tracked files from checkpoint: $BASE"
    if [ "$CLEAN_UNTRACKED" = "1" ]; then
      echo "[dry-run] Would clean untracked files (--clean-untracked set)."
    else
      echo "[dry-run] Untracked files would NOT be cleaned (default safe behavior)."
    fi
    return
  fi

  echo "Restoring tracked working-tree to checkpoint state..."

  # Restore tracked files using git restore (not reset --hard).
  if ! git restore --staged .; then
    echo "Rescue artifacts were saved before recovery. Current status:"
    git status --short --branch || true
    fail_recovery "failed to restore staged tracked files before applying checkpoint patch."
  fi

  if ! git restore .; then
    echo "Rescue artifacts were saved before recovery. Current status:"
    git status --short --branch || true
    fail_recovery "failed to restore tracked working-tree files before applying checkpoint patch."
  fi

  # Only clean untracked files with explicit opt-in.
  if [ "$CLEAN_UNTRACKED" = "1" ]; then
    echo "Explicit --clean-untracked: cleaning untracked files..."
    if ! git clean -fd -- .; then
      fail_recovery "explicit untracked cleanup failed after checkpoint tracked restore."
    fi
  else
    echo "Leaving untracked files intact (safe default)."
    echo "To clean untracked files, re-run with: --clean-untracked"
  fi

  # Apply staged checkpoint state first, then write those index entries to the
  # worktree before applying unstaged changes on top.
  if [ -f "$STAGED_PATCH" ] && [ -s "$STAGED_PATCH" ]; then
    if ! git apply --cached "$STAGED_PATCH"; then
      fail_recovery "failed to apply staged checkpoint patch: $STAGED_PATCH"
    fi
    if ! restore_staged_worktree_files; then
      fail_recovery "failed to restore staged checkpoint files into the worktree."
    fi
    echo "Staged patch restored from: $STAGED_PATCH"
  else
    echo "Staged checkpoint patch was empty."
  fi

  if [ -s "$PATCH" ]; then
    if ! git apply "$PATCH"; then
      fail_recovery "failed to apply checkpoint patch: $PATCH"
    fi
    echo "Unstaged patch restored from: $PATCH"
  else
    echo "Unstaged checkpoint patch was empty."
  fi

  # Leave current untracked files untouched by default. The checkpoint archive
  # is evidence for manual inspection, not something to overwrite automatically.
  if [ -f "$UNTRACKED_TAR" ] && [ -s "$UNTRACKED_TAR" ]; then
    echo "Untracked checkpoint archive available but NOT restored by default: $UNTRACKED_TAR"
  else
    echo "No untracked-file archive in this checkpoint."
  fi

  record_recovery_attempt "success" "" "Checkpoint base: $BASE"
}

# ---------------------------------------------------------------------------
# Mode: new-branch (--commit <sha> --new-branch <branch>)
# ---------------------------------------------------------------------------

do_new_branch() {
  echo "=== Recovery mode: new-branch ==="
  echo "Commit:    $COMMIT_SHA"
  echo "New branch: $NEW_BRANCH"
  echo

  # Validate commit.
  if ! git rev-parse --verify "${COMMIT_SHA}^{commit}" >/dev/null 2>&1; then
    fail_recovery "invalid commit: $COMMIT_SHA"
  fi

  FULL_SHA="$(git rev-parse "${COMMIT_SHA}^{commit}")"

  # Validate target branch does not already exist.
  if git show-ref --verify --quiet "refs/heads/$NEW_BRANCH"; then
    echo "Error: branch already exists: $NEW_BRANCH"
    echo "Remove it first or choose a different branch name."
    fail_recovery "branch already exists: $NEW_BRANCH"
  fi

  if git worktree list --porcelain 2>/dev/null | grep -q "branch refs/heads/${NEW_BRANCH}$"; then
    echo "Error: a worktree for branch '$NEW_BRANCH' already exists."
    git worktree list
    fail_recovery "worktree already exists for branch: $NEW_BRANCH"
  fi

  # Save rescue artifacts before recovery.
  save_rescue_artifacts "$TIMESTAMP"

  SAFE_NEW_BRANCH="$(printf '%s' "$NEW_BRANCH" | tr '/ ' '__')"
  RESCUE_DIR="../wt-${SAFE_NEW_BRANCH}"

  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] Would create branch: $NEW_BRANCH"
    echo "[dry-run] From commit: $FULL_SHA"
    echo "[dry-run] Would create worktree at: $RESCUE_DIR"
    return
  fi

  # Create the rescue branch.
  if ! git branch "$NEW_BRANCH" "$FULL_SHA"; then
    fail_recovery "failed to create branch $NEW_BRANCH at $FULL_SHA"
  fi
  PARTIAL_STATE="branch-created"

  echo "Created branch: $NEW_BRANCH at $FULL_SHA"

  # Try to create a worktree for the rescue branch.
  if [ -d "$RESCUE_DIR" ]; then
    PARTIAL_STATE="branch-created/worktree-directory-exists"
    echo
    echo "Branch-only recovery succeeded."
    echo "Worktree creation failed: directory already exists: $RESCUE_DIR"
    echo "Created branch: $NEW_BRANCH"
    echo "Current branch ($CURRENT_BRANCH) remains unchanged."
    echo
    echo "Manual next commands:"
    echo "  git switch $NEW_BRANCH"
    echo "  git worktree add <alternate-path> $NEW_BRANCH"
    record_recovery_attempt "branch-only" "" "Branch: $NEW_BRANCH, Commit: $FULL_SHA, Worktree path already existed: $RESCUE_DIR"
    return
  else
    if ! git worktree add "$RESCUE_DIR" "$NEW_BRANCH"; then
      PARTIAL_STATE="branch-created/worktree-failed"
      echo
      echo "Branch-only recovery succeeded."
      echo "Worktree creation failed for: $RESCUE_DIR"
      echo "Created branch: $NEW_BRANCH"
      echo "Current branch ($CURRENT_BRANCH) remains unchanged."
      echo
      echo "Manual next commands:"
      echo "  git switch $NEW_BRANCH"
      echo "  git worktree add <alternate-path> $NEW_BRANCH"
      record_recovery_attempt "branch-only" "" "Branch: $NEW_BRANCH, Commit: $FULL_SHA, git worktree add failed for: $RESCUE_DIR"
      return
    fi
    PARTIAL_STATE="branch-created/worktree-created"
    echo "Created rescue worktree: $RESCUE_DIR"
  fi

  echo
  echo "Current branch ($CURRENT_BRANCH) was NOT modified."

  record_recovery_attempt "success" "" "Commit: $FULL_SHA, Branch: $NEW_BRANCH"
}

# ---------------------------------------------------------------------------
# Mode: reset-current (--commit <sha> --reset-current --confirm-reset-current)
# ---------------------------------------------------------------------------

do_reset_current() {
  if [ -z "$COMMIT_SHA" ]; then
    fail_recovery "--reset-current requires --commit <sha>."
  fi

  if [ "${CONFIRM_RESET:-0}" != "1" ]; then
    echo "ERROR: --reset-current requires --confirm-reset-current."
    echo
    echo "This is a destructive action that modifies the current branch."
    echo "It saves rescue artifacts first, but rewrites tracked files to the"
    echo "selected commit. Untracked files are not deleted."
    echo
    echo "If you are certain, re-run with:"
    echo "  scripts/agent_recover_to_point.sh --commit $COMMIT_SHA --reset-current --confirm-reset-current"
    echo
    echo "Codex high must approve this decision before execution."
    fail_recovery "--reset-current requires --confirm-reset-current."
  fi

  # Refuse to operate destructively on main.
  if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "ERROR: refusing to reset main. Never reset main."
    echo "Create a rescue branch from the desired commit instead:"
    echo "  scripts/agent_recover_to_point.sh --commit $COMMIT_SHA --new-branch rescue/<name>"
    fail_recovery "refusing to reset main."
  fi

  # Validate commit.
  if ! git rev-parse --verify "${COMMIT_SHA}^{commit}" >/dev/null 2>&1; then
    fail_recovery "invalid commit: $COMMIT_SHA"
  fi

  FULL_SHA="$(git rev-parse "${COMMIT_SHA}^{commit}")"

  echo "=== Recovery mode: reset-current ==="
  echo "Commit:  $FULL_SHA"
  echo "Branch:  $CURRENT_BRANCH"
  echo
  echo "WARNING: This will restore tracked files in the current branch to the"
  echo "         selected commit. Untracked files will NOT be deleted."
  echo "         Rescue artifacts will be saved first."
  echo

  ORIGINAL_HEAD="$(git rev-parse HEAD)"

  # Save rescue artifacts before recovery.
  save_rescue_artifacts "$TIMESTAMP"

  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] Would save rescue artifacts first."
    echo "[dry-run] Would keep HEAD unchanged initially: $ORIGINAL_HEAD"
    echo "[dry-run] Would restore index and tracked working-tree files from: $FULL_SHA"
    echo "[dry-run] Would verify index and worktree against: $FULL_SHA"
    echo "[dry-run] Would move HEAD only after successful verification with: git reset --soft $FULL_SHA"
    echo "[dry-run] Would verify final clean tracked state after moving HEAD."
    echo "[dry-run] Would NOT delete untracked files."
    return
  fi

  rollback_tracked_to_original() {
    echo "Attempting best-effort rollback of tracked files to original HEAD: $ORIGINAL_HEAD"
    if ! git restore --source "$ORIGINAL_HEAD" --staged --worktree -- .; then
      echo "WARNING: failed to restore tracked files back to original HEAD."
      echo "Manual inspection is required. Rescue artifacts were saved before recovery."
    fi
  }

  # Safe non-hard-reset sequence:
  # 1. Keep HEAD unchanged.
  # 2. Restore index and tracked worktree files from the target commit.
  # 3. Verify index and worktree match the target commit.
  # 4. Only then move HEAD with git reset --soft.
  # 5. Verify the final tracked state is clean.
  #
  # This avoids moving the branch tip before the restore is known to succeed.

  echo "Restoring tracked files to commit $FULL_SHA while keeping HEAD unchanged..."

  if ! git restore --source "$FULL_SHA" --staged --worktree -- .; then
    rollback_tracked_to_original
    echo "Current status:"
    git status --short --branch || true
    fail_recovery "failed to restore index and tracked working-tree files from $FULL_SHA."
  fi

  if ! git diff --quiet "$FULL_SHA" -- .; then
    rollback_tracked_to_original
    echo "Current status:"
    git status --short --branch || true
    fail_recovery "working tree does not match target commit $FULL_SHA before moving HEAD."
  fi

  if ! git diff --cached --quiet "$FULL_SHA" -- .; then
    rollback_tracked_to_original
    echo "Current status:"
    git status --short --branch || true
    fail_recovery "index does not match target commit $FULL_SHA before moving HEAD."
  fi

  echo "Tracked files verified against $FULL_SHA. Moving HEAD now..."

  if ! git reset --soft "$FULL_SHA"; then
    fail_recovery "git reset --soft failed while moving HEAD to $FULL_SHA."
  fi

  CURRENT_HEAD="$(git rev-parse HEAD)"
  if [ "$CURRENT_HEAD" != "$FULL_SHA" ]; then
    echo "ERROR: HEAD is $CURRENT_HEAD, expected $FULL_SHA."
    echo "Rescue artifacts were saved before recovery."
    fail_recovery "HEAD is $CURRENT_HEAD, expected $FULL_SHA after moving HEAD."
  fi

  if ! git diff --quiet; then
    echo "ERROR: working tree is not clean after moving HEAD to $FULL_SHA."
    echo "Rescue artifacts were saved before recovery. Remaining tracked status:"
    git status --short --branch || true
    fail_recovery "working tree is not clean after moving HEAD to $FULL_SHA."
  fi

  if ! git diff --cached --quiet; then
    echo "ERROR: index is not clean after moving HEAD to $FULL_SHA."
    echo "Rescue artifacts were saved before recovery. Remaining tracked status:"
    git status --short --branch || true
    fail_recovery "index is not clean after moving HEAD to $FULL_SHA."
  fi

  record_recovery_attempt "success" "" "Commit: $FULL_SHA, Branch: $CURRENT_BRANCH"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "$MODE" in
  checkpoint)
    do_checkpoint_recover
    ;;
  new-branch)
    do_new_branch
    ;;
  reset-current)
    do_reset_current
    ;;
  *)
    echo "Error: unknown mode: $MODE"
    usage
    ;;
esac

echo
echo "=== Post-recovery status ==="
echo
echo "Branch: $(git branch --show-current 2>/dev/null || echo detached)"
echo "HEAD:   $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo
git status --short --branch

echo
echo "=== Rescue artifacts ==="
echo "  .agent-logs/recovery-rescue-${TIMESTAMP}.patch"
echo "  .agent-logs/recovery-rescue-${TIMESTAMP}.staged.patch"
echo "  .agent-logs/recovery-rescue-${TIMESTAMP}.status.txt"
echo "  .agent-logs/recovery-rescue-${TIMESTAMP}.untracked.zlist"
echo "  .agent-logs/recovery-rescue-${TIMESTAMP}.untracked.tar (if untracked files were present)"
echo "  .agent-logs/recovery-action-${TIMESTAMP}.md"
