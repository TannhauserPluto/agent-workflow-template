# Scope

Implement a recovery and escalation layer around the existing worktree/checkpoint workflow.

The implementation adds three shell scripts, one documentation page, and role-boundary updates to the agent instructions. The scripts are local-first: they collect evidence, preserve failure state, and prepare recovery choices for Codex high. They must not merge, delete branches, delete `main`, or clean untracked files by default.

# Milestones

## Milestone 1: Diagnosis script

Add `scripts/agent_diagnose_stuck.sh`.

Behavior:

- Resolve repo root with `git rev-parse --show-toplevel`.
- Create `.agent-logs/` if missing.
- Generate `stuck-report-<timestamp>.md`.
- Accept optional `--feature <slug>` to identify `specs/<slug>.md` and `plans/<slug>-plan.md`.
- If `--feature` is not supplied, infer a best-effort slug from the current branch:
  - `feat/<slug>` -> `<slug>`
  - `fix/<slug>` -> `<slug>`
  - `rescue/<slug>` -> `<slug>` when possible
- Include clear `MISSING` or `NOT FOUND` markers instead of failing when optional artifacts are absent.
- Print the generated report path.

Report sections:

- Summary: timestamp, repo root, worktree path, branch, HEAD.
- Git status: `git status --short --branch`.
- Diff stat: `git diff --stat`.
- Unstaged diff: `git diff`.
- Staged diff: `git diff --staged`.
- Untracked files: `git ls-files --others --exclude-standard`.
- Recent log: `git log --oneline --decorate -n 20`.
- Recent checkpoints: `.checkpoints/latest`, recent `.checkpoints/*.meta.txt`, and filenames sorted newest first.
- Recent checks/reviewer logs: best-effort discovery in `.agent-logs/`, `.agent-escalation/`, and any existing project log locations.
- Related spec/plan: include contents if detectable.

## Milestone 2: Recovery script

Add `scripts/agent_recover_to_point.sh`.

Supported forms:

```bash
scripts/agent_recover_to_point.sh --checkpoint latest
scripts/agent_recover_to_point.sh --commit <sha> --new-branch <branch>
scripts/agent_recover_to_point.sh --commit <sha> --reset-current --confirm-reset-current
```

Required safety behavior:

- Reject unknown or conflicting argument combinations.
- Refuse to operate on `main` for `--reset-current`.
- Before any recovery action, save failure state:
  - run `scripts/failure_checkpoint.sh` when available
  - write `.agent-logs/recovery-rescue-<timestamp>.patch`
  - write `.agent-logs/recovery-rescue-<timestamp>.staged.patch`
  - write `.agent-logs/recovery-rescue-<timestamp>.status.txt`
  - archive/list untracked files when practical without deleting them
- For `--checkpoint latest`, prefer invoking or reusing the existing checkpoint restore logic, but do not enable untracked cleanup by default.
- For `--commit <sha> --new-branch <branch>`:
  - validate the commit exists with `git rev-parse --verify`.
  - validate the target branch does not already exist unless a documented safe reuse path is implemented.
  - create a rescue branch from that commit.
  - prefer creating a new worktree for the rescue branch when possible; otherwise clearly report that only the branch was created.
  - do not alter the current branch.
- For `--commit <sha> --reset-current --confirm-reset-current`:
  - require the confirmation flag.
  - save rescue artifacts first.
  - record the exact action in `.agent-logs/recovery-action-<timestamp>.md`.
  - use the least destructive sequence practical, such as restoring tracked paths to the selected commit, and avoid `git clean -fd`.
  - if implementation uses `git reset --hard`, gate it behind `--confirm-reset-current` only and document the reason in the script comments and docs.
- Print a post-action status and the saved rescue artifact paths.

## Milestone 3: Escalation bundle script

Add `scripts/escalate_to_codex.sh`.

Behavior:

- Resolve repo root and create `.agent-escalation/escalation-<timestamp>/`.
- Accept optional `--feature <slug>` and optional `--stuck-report <path>`.
- If no stuck report is supplied, run `scripts/agent_diagnose_stuck.sh` and copy the resulting report into the bundle.
- Bundle files:
  - `escalation.md`
  - `stuck-report.md`
  - `diff.patch`
  - `staged.diff.patch`
  - `status.txt`
  - `git-log.txt`
  - `checkpoints.txt`
  - `test-output.txt` when available
  - `reviewer-output.txt` when available
- `escalation.md` must include:
  - the user/task context if detectable from spec/plan
  - a concise stuck summary placeholder for Claude to fill if needed
  - explicit decision menu for Codex high:
    1. continue current branch
    2. recover to checkpoint
    3. recover to commit
    4. create a rescue branch from a stable point
    5. escalate to direct Codex fix
  - safety rules from the spec
  - exact bundle file list
  - suggested prompt text to paste into Codex high
- First version must not automatically invoke Codex.

## Milestone 4: Documentation and role boundaries

Add `docs/agent-branch-recovery-workflow.md`.

Document:

- Normal implementation flow: Claude Code + DeepSeek executes from spec/plan.
- Stuck condition examples:
  - repeated failed checks without progress
  - contradictory edits
  - uncertainty about rollback point
  - broad rewrites beyond plan
  - checkpoint restore uncertainty
- Required stuck sequence:
  1. stop implementation edits
  2. save failure state
  3. run diagnosis
  4. create escalation bundle
  5. Codex high chooses recovery path
  6. Claude executes only the chosen recovery
- Recovery decision details and commands.
- Rescue branch preference and rationale.
- Prohibited actions:
  - no automatic merge
  - no branch deletion of `main`
  - no default `git reset --hard`
  - no default `git clean -fd`
  - no Claude-only recovery decisions
- How reviewer should audit recovery artifacts.

Update `AGENTS.md`:

- Add a recovery/escalation section under role split or hard rules.
- State that Codex high owns recovery decisions after stuck diagnosis.
- State that current failure state must be preserved before recovery.
- Add the new scripts and doc to the workflow.

Update `CLAUDE.md`:

- Add an executor stuck protocol.
- Instruct Claude Code to stop blind editing, run diagnosis, and create escalation bundle.
- State Claude must not choose destructive recovery without Codex high direction.
- State Claude may execute the chosen recovery command after Codex high decides.

## Milestone 5: Checks and review readiness

- Run shell syntax checks for all changed scripts:

```bash
bash -n scripts/agent_diagnose_stuck.sh
bash -n scripts/agent_recover_to_point.sh
bash -n scripts/escalate_to_codex.sh
```

- Run smoke tests in a temporary task branch/worktree when practical.
- Run `just check`.
- Run `scripts/run_codex_reviewer.sh recovery-escalation` before PR.

# Files likely to change

- `scripts/agent_diagnose_stuck.sh`: new stuck report generator.
- `scripts/agent_recover_to_point.sh`: new safe recovery command wrapper.
- `scripts/escalate_to_codex.sh`: new escalation bundle generator.
- `docs/agent-branch-recovery-workflow.md`: new workflow documentation.
- `AGENTS.md`: update repository-level role boundaries and safety rules.
- `CLAUDE.md`: update executor-specific stuck and recovery protocol.
- Optional only if needed:
  - `scripts/run_codex_reviewer.sh`: add the new scripts to reviewer shell syntax checks.
  - `docs/worktree-checkpoint-workflow.md`: cross-link to the new recovery workflow doc.

# Test plan

## Static checks

- `bash -n scripts/agent_diagnose_stuck.sh`
- `bash -n scripts/agent_recover_to_point.sh`
- `bash -n scripts/escalate_to_codex.sh`
- `just check`

## Diagnosis smoke test

From the task worktree:

```bash
scripts/agent_diagnose_stuck.sh --feature recovery-escalation
```

Verify:

- `.agent-logs/stuck-report-*.md` is created.
- Report includes branch, worktree path, HEAD, status, diff stat, full diff, untracked files, recent log, checkpoints, spec, and plan.
- Missing optional logs are represented clearly without script failure.

## Escalation smoke test

```bash
scripts/escalate_to_codex.sh --feature recovery-escalation
```

Verify:

- `.agent-escalation/escalation-*/` is created.
- Bundle includes all required files.
- `escalation.md` includes the five allowed Codex high decisions.
- Script does not invoke Codex.

## Recovery argument validation

Run invalid forms and verify non-zero exit with usage:

```bash
scripts/agent_recover_to_point.sh
scripts/agent_recover_to_point.sh --commit HEAD
scripts/agent_recover_to_point.sh --checkpoint latest --commit HEAD
scripts/agent_recover_to_point.sh --commit HEAD --reset-current
```

## Rescue branch smoke test

Use a disposable branch name:

```bash
scripts/agent_recover_to_point.sh --commit HEAD --new-branch rescue/recovery-escalation-smoke
```

Verify:

- Rescue branch/worktree is created from the requested commit.
- Current branch diff is unchanged.
- Rescue artifacts are saved first.
- No merge occurs.

Clean up the disposable rescue branch/worktree manually after review.

## Checkpoint recovery smoke test

Create a small disposable edit and checkpoint, then run:

```bash
scripts/failure_checkpoint.sh
scripts/agent_recover_to_point.sh --checkpoint latest
```

Verify:

- The script saves a new failure state before attempting recovery.
- It does not run `git clean -fd`.
- It restores tracked/staged checkpoint patches consistently with the existing checkpoint behavior.
- It leaves untracked files intact unless an explicit existing restore option is intentionally used.

## Reset-current dry safety test

```bash
scripts/agent_recover_to_point.sh --commit HEAD --reset-current
```

Verify:

- The command refuses to run without `--confirm-reset-current`.
- Rescue artifacts are not partially created unless the command proceeds to a real recovery path, or the script clearly documents and handles preflight artifact creation.

# Risk checkpoints

- Before editing recovery code, create or verify a checkpoint.
- After Milestone 1, inspect a generated stuck report before implementing recovery actions.
- Before Milestone 2 reset-current behavior, confirm the exact command sequence in code review.
- Before Milestone 3, verify escalation bundle paths are local and do not require network access.
- Before PR, reviewer must compare implementation against:
  - no default hard reset
  - no default clean
  - rescue artifacts before recovery
  - rescue branch preference
  - no automatic merge

# PR split plan

Preferred single PR because the feature is small and traceable to one spec.

If split is needed:

1. PR 1: diagnosis script plus docs and instruction updates.
2. PR 2: recovery script and escalation bundle script.
3. PR 3: reviewer/check integration and smoke-test hardening.

## Validation report

This task includes a committed validation report:

- docs/recovery-escalation-validation.md

Purpose:

- Record smoke tests performed for the recovery and escalation workflow.
- Make behavior evidence reviewable without committing runtime artifacts from .agent-logs/ or .agent-escalation/.
- Document which high-risk paths were validated and which destructive paths were intentionally not executed.
