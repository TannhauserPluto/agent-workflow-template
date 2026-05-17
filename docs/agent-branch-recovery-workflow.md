# Agent Branch Recovery and Escalation Workflow

## Overview

This document describes the recovery and escalation workflow for Claude Code
tasks that become stuck during implementation. The workflow preserves failure
state, generates diagnostic evidence, and escalates recovery decisions to
Codex high.

## Role Boundaries

| Role | Responsibility |
|------|---------------|
| **Claude Code + DeepSeek** | Normal implementation from spec/plan. Stops and diagnoses when stuck. |
| **Codex high** | Chooses the recovery path after reviewing diagnostic evidence. |
| **Claude Code (recovery)** | Executes the chosen recovery command only after Codex high decides. |
| **Codex reviewer** | Audits recovery artifacts for safety compliance. |

Claude Code + DeepSeek must **not** independently decide major rollback,
rescue-branch strategy, or destructive recovery. Those decisions belong to
Codex high.

## Normal Implementation Flow

1. Codex planner creates `specs/<feature>.md` and `plans/<feature>-plan.md`.
2. Claude Code + DeepSeek executes implementation from the spec and plan in a
   dedicated worktree.
3. Checkpoints are created automatically before broad changes.
4. Claude runs `just check` at milestones.
5. Codex reviewer audits the final diff before PR.

## Stuck Conditions

Claude Code should recognize these stuck conditions and stop editing:

- **Repeated check failures** — `just check` fails across multiple attempts
  without progress.
- **Contradictory edits** — Changes undo or conflict with previous changes.
- **Uncertainty about rollback point** — Unsure which commit or checkpoint is
  safe to return to.
- **Broad rewrites beyond plan** — Implementation scope expands beyond the
  approved plan.
- **Checkpoint restore uncertainty** — Unsure whether restoring a checkpoint
  is safe given intervening changes.

## Required Stuck Sequence

When stuck, Claude Code must follow this sequence:

1. **Stop implementation edits** — do not write more code into a failing state.
2. **Save failure state** — run `scripts/failure_checkpoint.sh` to capture the
   current state.
3. **Run diagnosis** — execute `scripts/agent_diagnose_stuck.sh` to generate a
   full diagnostic report.
4. **Create escalation bundle** — execute `scripts/escalate_to_codex.sh` to
   package all evidence for Codex high.
5. **Wait for Codex high** — present the escalation bundle and await a recovery
   decision.
6. **Execute the chosen recovery** — only after Codex high selects a path,
   run the corresponding recovery command.

```bash
# Step 2: Save failure state
scripts/failure_checkpoint.sh

# Step 3: Diagnose
scripts/agent_diagnose_stuck.sh --feature my-feature

# Step 4: Escalate
scripts/escalate_to_codex.sh --feature my-feature

# Step 5: Present .agent-escalation/escalation-*/escalation.md to Codex high
# Step 6: Execute only the path Codex high selects
```

## Recovery Decisions

Codex high can choose from five recovery paths:

### 1. Continue on current branch

The current state is acceptable. Resume implementation from HEAD.

```
No command needed — Claude continues from current state.
```

### 2. Recover to checkpoint

Restore the latest checkpoint patches onto the current working tree.

```bash
scripts/agent_recover_to_point.sh --checkpoint latest
```

Saves rescue artifacts first. Does not delete untracked files unless
`--clean-untracked` is explicitly passed.

### 3. Create a rescue branch (PREFERRED safe path)

Create a new branch from a known-stable commit without modifying the current
branch. This is the recommended default recovery path because it preserves
all current state and creates a clean workspace.

```bash
scripts/agent_recover_to_point.sh --commit <sha> --new-branch rescue/<name>
```

Creates both a branch and a worktree when possible. The current branch is
never modified.

### 4. Reset current branch (DESTRUCTIVE — requires explicit approval)

Restore tracked files in the current branch to a specific commit. This is a
destructive action that requires Codex high explicit approval and the
`--confirm-reset-current` flag.

```bash
scripts/agent_recover_to_point.sh --commit <sha> --reset-current --confirm-reset-current
```

- Refuses to run without `--confirm-reset-current`.
- Refuses to run on `main`.
- Does NOT use `git reset --hard` — uses `git restore --source` instead.
- Does NOT delete untracked files.
- Rescue artifacts are saved before any action.
- The action is recorded in `.agent-logs/recovery-action-<timestamp>.md`.

### 5. Escalate to direct Codex fix

Codex high takes over the branch and implements the fix directly. Claude Code
hands off and does not continue editing.

## Rescue Branch Preference

Rescue branches are the preferred recovery mechanism:

- They preserve the current branch with all its history and state intact.
- They create a clean workspace from a known-stable point.
- They allow parallel inspection of both the broken and rescue states.
- They do not require `git reset`, `git clean`, or any destructive action.
- Reviewer can compare the rescue branch against the original to audit the
  recovery.

## Prohibited Actions

The following actions are never allowed by default and require explicit Codex
high approval when permitted:

| Action | Policy |
|--------|--------|
| `git reset --hard` | Never used by the recovery scripts. |
| `git clean -fd` | Only available with explicit `--clean-untracked` flag on `--checkpoint latest` recovery (path 2). |
| Deleting `main` | Never allowed. Scripts refuse to operate destructively on `main`. |
| Auto-merging PRs | Never allowed. |
| Claude-only recovery decisions | Claude Code + DeepSeek must not choose destructive recovery paths independently. |

## Artifact Locations

| Artifact | Location |
|----------|----------|
| Stuck reports | `.agent-logs/stuck-report-<timestamp>.md` |
| Rescue patches | `.agent-logs/recovery-rescue-<timestamp>.patch` |
| Rescue staged patches | `.agent-logs/recovery-rescue-<timestamp>.staged.patch` |
| Rescue status | `.agent-logs/recovery-rescue-<timestamp>.status.txt` |
| Recovery action log | `.agent-logs/recovery-action-<timestamp>.md` |
| Escalation bundles | `.agent-escalation/escalation-<timestamp>/` |
| Checkpoints | `.checkpoints/` |

## Reviewer Audit Checklist

When auditing a recovery, the Codex reviewer should verify:

- [ ] Rescue artifacts were saved before any recovery action.
- [ ] No `git reset --hard` was used.
- [ ] No `git clean -fd` was used without `--clean-untracked` opt-in.
- [ ] A rescue branch was preferred over rewriting the current branch.
- [ ] `main` was never modified.
- [ ] No auto-merge occurred.
- [ ] The escalation bundle contains a clear Codex high decision.
- [ ] The recovery action log matches the chosen recovery path.

## Scripts Reference

- `scripts/agent_diagnose_stuck.sh` — Generate a stuck diagnostic report.
- `scripts/agent_recover_to_point.sh` — Execute a recovery action.
- `scripts/escalate_to_codex.sh` — Create an escalation bundle for Codex high.
- `scripts/failure_checkpoint.sh` — Save current failure state.
- `scripts/restore_checkpoint.sh` — Restore a checkpoint (used internally by recovery).
