# AGENTS.md

## Role split
- Codex planner is responsible for specs, plans, and task decomposition.
- Codex reviewer is read-only and reviews diff, tests, and risks.
- Execution is handled by Claude Code in a worktree.

## Hard rules
- Never write to main directly.
- Always work in a dedicated branch or worktree.
- Read specs/, plans/, and context/current-state.md before making changes.
- Prefer small, reviewable milestones.
- Run `just check` before declaring a task complete.
- Do not modify deployment, secrets, CI workflows, or database migrations unless explicitly allowed by the active plan.
- Keep PRs small and traceable to one spec.

## Worktree workflow
- Feature work must happen in a dedicated git worktree.
- Use `scripts/new_task_worktree.sh <branch> <dir>` to create task worktrees.
- Use checkpoint scripts before risky or broad changes.
- If a task goes off track, prefer restoring a checkpoint or deleting the task worktree instead of trying to repair main.
- Main must stay clean and synchronized with origin/main.

## Spec-plan-review workflow
- Codex Planner produces and updates `specs/<feature>.md` and `plans/<feature>-plan.md`.
- Claude Code executes only after the spec and plan exist.
- Codex Reviewer is read-only and reviews diff, tests, and risks before PR.
- Reviewer must compare implementation against the active spec and plan.
- If reviewer returns REQUEST_CHANGES, fix before opening or merging PR.

## One-command task startup
- Use `scripts/start_agent_task.sh <feature-slug> "<request>"` to initialize new tasks.
- The script must be run from clean `main`.
- It creates a feature branch, task worktree, and initial spec/plan skeleton.
- After task creation, execution should continue inside the generated worktree.

## Recovery and escalation

### Role boundaries

- Claude Code + DeepSeek handles normal implementation from spec/plan.
- Claude Code must stop implementation and diagnose when stuck; it must not continue blindly editing into a failing state.
- Recovery decisions belong to Codex high, not Claude Code + DeepSeek.
- Claude Code must not independently choose destructive recovery paths, major rollbacks, or rescue-branch strategy.
- Claude Code may execute the chosen recovery command only after Codex high selects a path.

### Stuck protocol

1. Stop implementation edits.
2. Save failure state with scripts/failure_checkpoint.sh when appropriate.
3. Run diagnosis with scripts/agent_diagnose_stuck.sh --feature <slug>.
4. Create escalation bundle with scripts/escalate_to_codex.sh --feature <slug>.
5. Present .agent-escalation/escalation-<timestamp>/escalation.md to Codex high.
6. Execute only the recovery path Codex high selects.

### Safety rules for recovery

- Always save failure state before any recovery action.
- Prefer rescue branches with --new-branch over rewriting the current branch with --reset-current.
- Never use git reset --hard.
- Never use git clean -fd by default.
- Never delete, reset, or rewrite main.
- Never auto-merge PRs.

### Recovery scripts

- scripts/agent_diagnose_stuck.sh generates stuck diagnostic reports under .agent-logs/.
- scripts/agent_recover_to_point.sh performs safe recovery from checkpoints or commits.
- scripts/escalate_to_codex.sh creates escalation bundles under .agent-escalation/ for Codex high review.
- See docs/agent-branch-recovery-workflow.md for the full workflow.
