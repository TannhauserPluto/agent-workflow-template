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
