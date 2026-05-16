# Goal

Add stuck diagnosis, safe recovery, and Codex escalation workflow scripts.

# Non-goals

- Do not automate merges, PR creation, or branch deletion.
- Do not replace the existing worktree, checkpoint, planner, or reviewer scripts.
- Do not make Claude Code + DeepSeek responsible for choosing destructive recovery actions.
- Do not call Codex automatically in the first version of escalation; generate a complete bundle and prompt instead.
- Do not modify deployment, secrets, CI workflows, or database migrations.

# User stories

- As Claude Code executing a task, when implementation appears stuck, I can stop editing and capture the current failure state in a durable report.
- As Codex high, I can inspect the stuck report, current diff, recent logs, spec, plan, and checkpoints before choosing a recovery path.
- As an executor, I can recover by creating a rescue branch from a known stable commit or checkpoint without rewriting the current branch by default.
- As an executor, I can intentionally reset the current branch only when Codex high explicitly chooses that path and the script saves rescue artifacts first.
- As a reviewer, I can audit what was preserved, what branch was created or reset, and which recovery decision was followed.

# Acceptance criteria

- `scripts/agent_diagnose_stuck.sh` exists and can be run from any repository subdirectory.
- `agent_diagnose_stuck.sh` creates `.agent-logs/stuck-report-<timestamp>.md` and prints the report path.
- The stuck report includes:
  - timestamp
  - current branch
  - worktree path
  - HEAD commit
  - `git status --short --branch`
  - `git diff --stat`
  - full unstaged diff
  - staged diff, if any
  - recent git log
  - untracked files
  - recent checkpoint metadata/list
  - recent check and reviewer logs when detectable
  - related spec and plan when detectable from branch name or supplied feature slug
- `scripts/agent_recover_to_point.sh` exists and supports:
  - `--checkpoint latest`
  - `--commit <sha> --new-branch <branch>`
  - `--commit <sha> --reset-current`
- `agent_recover_to_point.sh --checkpoint latest` restores the latest checkpoint using the existing checkpoint format where practical, and does not delete untracked files by default.
- `agent_recover_to_point.sh --commit <sha> --new-branch <branch>` creates a new branch or worktree from the selected commit without modifying the current branch.
- `agent_recover_to_point.sh --commit <sha> --reset-current` refuses to run unless an explicit confirmation flag is supplied, saves rescue artifacts first, and records the action in `.agent-logs/`.
- The reset-current flow does not use `git reset --hard` as the default behavior. If a hard reset is implemented as an explicit expert-only path, it must require a visibly named flag such as `--confirm-reset-current` and must save rescue patches first.
- No recovery flow runs `git clean -fd` by default.
- No script deletes `main`, merges branches, or switches `main` destructively.
- `scripts/escalate_to_codex.sh` exists and creates `.agent-escalation/escalation-<timestamp>/`.
- The escalation bundle contains:
  - `escalation.md`
  - the latest or newly generated stuck report
  - git diff patch
  - staged diff patch
  - test output if available
  - reviewer output if available
  - git log
  - checkpoint list
  - enough prompt text for Codex high to choose one of the approved recovery decisions
- `docs/agent-branch-recovery-workflow.md` documents normal execution, stuck diagnosis, escalation, recovery decisions, rescue branches, and prohibited actions.
- `AGENTS.md` and `CLAUDE.md` clearly state:
  - Claude Code + DeepSeek handles normal implementation.
  - Claude Code must stop and diagnose when stuck instead of blindly editing.
  - Recovery decisions belong to Codex high.
  - Current failure state must be saved before recovery.
  - Prefer rescue branches over rewriting current branches.

# Constraints

- Follow the existing role split:
  - Codex planner owns this spec and `plans/recovery-escalation-plan.md`.
  - Claude Code executes implementation in the task worktree.
  - Codex reviewer reviews the final diff against this spec and plan.
- Keep the first implementation shell-only and compatible with the existing script style.
- Use existing `.checkpoints/` artifacts created by `scripts/failure_checkpoint.sh`.
- Store diagnostic and escalation artifacts inside the task worktree:
  - `.agent-logs/`
  - `.agent-escalation/`
- Artifacts should be local by default and not require network access.
- Scripts must fail fast on invalid argument combinations.
- Scripts must be safe when run outside a git repo, on detached HEAD, or with no checkpoints.
- Scripts must avoid broad cleanup of untracked files.

# Risks

- A recovery script can accidentally overwrite uncommitted useful work if it restores or resets without first saving rescue patches.
- Checkpoint patches may not apply cleanly after unrelated edits.
- Branch name to spec/plan detection may be ambiguous for branches that do not match `feat/<feature-slug>`.
- Escalation bundles can become large because full diffs are embedded or copied.
- Test/reviewer logs may not have a stable existing path and may need best-effort discovery.
- Interactive confirmations can make automation harder, while non-interactive recovery can be unsafe.
- Worktrees can already exist for a requested rescue branch.

# Rollback plan

- Revert this feature by removing the three new scripts, the new recovery workflow doc, and the role-boundary additions in `AGENTS.md` and `CLAUDE.md`.
- Generated runtime artifacts in `.agent-logs/` and `.agent-escalation/` are disposable local evidence and can be ignored or removed after review.
- If implementation changes break the workflow, use the existing checkpoint scripts or create a new rescue branch from the pre-feature commit rather than rewriting `main`.
