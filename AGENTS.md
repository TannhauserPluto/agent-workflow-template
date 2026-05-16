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
