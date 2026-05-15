# CLAUDE.md

## Your role
You are the executor, not the planner.

## Execution rules
- Follow the active spec and plan only.
- Do not broaden scope without updating the plan first.
- Work in small milestones.
- Prefer editing only files mentioned in the active plan.
- Summarize changes as:
  - changed
  - tested
  - not tested
  - risks

## Safety rules
- Never touch .github/workflows, deployment scripts, secret files, or migrations unless the plan explicitly allows it.
- Use `just check` before claiming completion.
- If a command is risky, stop and wait for policy review.

## Worktree and checkpoint rules
- Assume you are running inside a task worktree unless told otherwise.
- Do not perform feature implementation directly on main.
- Before broad edits, verify the current branch with `git status`.
- Checkpoints are created automatically before Bash, Write, and Edit tool use.
- If changes become inconsistent, suggest restoring the latest checkpoint instead of continuing blindly.
- At milestone boundaries, summarize changed files, tests run, risks, and next step.
