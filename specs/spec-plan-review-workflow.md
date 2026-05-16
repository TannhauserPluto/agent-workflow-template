# Spec Plan Review Workflow Spec

## Goal

Add a Codex-based spec, planning, and review workflow to this repository so future agentic coding tasks can follow a repeatable lifecycle:

1. Create or refine a feature spec
2. Create or refine an implementation plan
3. Execute the task in a dedicated worktree
4. Run local checks
5. Use Codex Reviewer to review diff, tests, and risks
6. Open a PR protected by GitHub rules and CI

## Non-goals

- Do not implement production application code.
- Do not replace GitHub CI or branch rules.
- Do not make reviewer output an enforced CI blocker yet.
- Do not automate PR creation yet.
- Do not bypass Claude Code hooks, checkpoint recovery, or worktree rules.

## User Stories

- As a planner, I want a reusable prompt and script to turn user requests into specs and plans.
- As an executor, I want clear repository rules that require reading active specs and plans before implementation.
- As a reviewer, I want a reusable prompt and script to inspect diffs against active specs, plans, and test output.
- As a maintainer, I want repository-level instructions updated so Codex and Claude follow the same workflow.

## Acceptance Criteria

- `prompts/codex_planner.md` exists and defines the planner role.
- `prompts/codex_reviewer.md` exists and defines the reviewer role.
- `scripts/new_feature_spec.sh` can create a feature spec and plan skeleton.
- `scripts/run_codex_planner.sh` can call Codex Planner and return refined spec/plan content.
- `scripts/run_codex_reviewer.sh` can call Codex Reviewer using active spec, active plan, git diff, status, and check output.
- `AGENTS.md` documents the spec-plan-review workflow for Codex.
- `CLAUDE.md` documents execution rules for Claude Code.
- `context/current-state.md` reflects the current implemented workflow state.
- A demo spec and plan exist to validate the workflow shape.
- A smoke test record documents that planner and reviewer scripts were exercised.
- `just check` passes.

## Constraints

- Planner must not directly implement code.
- Reviewer must be read-only.
- Claude Code remains the executor.
- Feature work should happen in a dedicated worktree.
- `main` must stay clean and protected by PR and CI.
- Model names must be configurable by environment variables.
- The workflow must remain usable even if Codex connectivity is temporarily unstable.

## Risks

- Codex CLI output can be verbose and token-expensive.
- Codex model names may vary across accounts or CLI versions.
- Reviewer output is advisory only and not yet enforced by CI.
- `just check` currently contains placeholder checks.
- Users may accidentally review a PR against the wrong active spec and plan.

## Rollback Plan

- Revert this PR to remove the planner/reviewer workflow.
- Existing Claude hooks, policy engine, checkpoint recovery, worktree helper scripts, and GitHub CI remain unaffected.
- If only the demo docs are problematic, remove `specs/demo-agent-flow.md` and `plans/demo-agent-flow-plan.md` without reverting the scripts.
