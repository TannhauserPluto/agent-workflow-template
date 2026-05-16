# Demo Agent Flow Spec

## Goal

Create a small, end-to-end demo workflow that shows how this repository expects agentic coding work to move through:

1. Spec creation
2. Plan creation
3. Execution in a dedicated worktree
4. Reviewer validation
5. PR and merge gates

The demo should be understandable without production code and should serve as a reference example for future tasks.

## Non-goals

- Do not implement production application code.
- Do not modify deployment, secrets, database migrations, or CI workflows.
- Do not change the required planner/executor/reviewer role split.
- Do not bypass GitHub PR and CI gates.

## User Stories

- As a planner, I want a concrete example spec and plan so future tasks have a clear shape to follow.
- As an executor, I want demo instructions that make it clear execution must happen in a dedicated worktree.
- As a reviewer, I want explicit review gates so I can compare implementation against the spec and plan.
- As a maintainer, I want the demo workflow to document expected PR gates before changes reach main.

## Acceptance Criteria

- A demo spec exists at `specs/demo-agent-flow.md`.
- A demo plan exists at `plans/demo-agent-flow-plan.md`.
- The demo describes the required lifecycle: spec, plan, execution, review, PR gates.
- The demo states that implementation must not happen directly on `main`.
- The demo states that execution must happen in a dedicated worktree created through `scripts/new_task_worktree.sh`.
- The demo includes a review gate where Codex Reviewer checks the diff, tests, and risks against the active spec and plan.
- The demo includes a PR gate requiring checks to pass before merge.
- The demo remains documentation-only and does not require external services.

## Constraints

- Planning and execution must remain separate.
- Execution must happen in a dedicated branch or worktree.
- `main` must stay clean and synchronized with `origin/main`.
- The workflow must prefer small, reviewable milestones.
- `just check` must be run before declaring completion.
- The demo must reflect current repository state from `context/current-state.md`.

## Risks

- The demo may become outdated as the workflow evolves.
- The workflow may be too abstract to guide actual execution.
- Future contributors may treat the demo as optional documentation instead of the expected process.
- DeepSeek balance or Codex connectivity may block real execution in future tasks.

## Rollback Plan

- Because this task is documentation-only, rollback is limited to reverting the spec and plan changes from the feature branch or deleting the task worktree.
- If the demo creates confusion, update or revert `specs/demo-agent-flow.md` and `plans/demo-agent-flow-plan.md` before opening a PR.
- If the task worktree goes off track, remove it and recreate it from a clean `main` using `scripts/new_task_worktree.sh`.
