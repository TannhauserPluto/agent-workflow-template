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

## Spec-plan execution rules
- Do not start implementation unless an active spec and plan exist.
- Read the active spec and plan before editing.
- Do not expand scope beyond the plan.
- At the end of a milestone, run `just check`.
- Before PR, run Codex Reviewer with `scripts/run_codex_reviewer.sh <feature-slug>`.

## Task startup
- New tasks should be initialized from `main` using `scripts/start_agent_task.sh`.
- After startup, Claude Code should run inside the generated worktree.
- Do not initialize new feature tasks manually unless the startup script fails.

## Executor stuck protocol

- If implementation becomes stuck, stop editing immediately.
- Do not continue blindly editing into a failing state.
- Run diagnosis to capture the failure state:
  - scripts/failure_checkpoint.sh
  - scripts/agent_diagnose_stuck.sh --feature <slug>
- Create an escalation bundle and present it to Codex high:
  - scripts/escalate_to_codex.sh --feature <slug>
- Do not independently choose destructive recovery.
- Recovery decisions, including checkpoint restore, rescue branch, reset-current, and rollback strategy, belong to Codex high.
- After Codex high selects a recovery path, execute only the chosen command.
- Prefer rescue branches with --new-branch over rewriting the current branch with --reset-current.
