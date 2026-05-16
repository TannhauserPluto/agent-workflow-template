# Spec Plan Review Workflow Plan

## Scope

Add the first version of a spec-driven Codex planning and review workflow.

In scope:

- Add planner and reviewer prompts.
- Add scripts for creating feature spec/plan skeletons.
- Add scripts for running Codex Planner and Codex Reviewer.
- Update `AGENTS.md` with Codex workflow rules.
- Update `CLAUDE.md` with execution rules.
- Update `context/current-state.md`.
- Add demo spec and plan to validate the workflow format.

Out of scope:

- Enforcing reviewer output in GitHub CI.
- Automatically opening PRs.
- Automatically writing planner output into files.
- Implementing production application code.
- Changing GitHub workflow files.
- Changing deployment, secret, or migration files.

## Milestones

### Milestone 1: Add Planner and Reviewer Prompts

Files:

- `prompts/codex_planner.md`
- `prompts/codex_reviewer.md`

Reviewable outcome:

- Planner role is limited to spec and plan generation.
- Reviewer role is read-only and reviews spec alignment, plan alignment, tests, risks, and scope creep.

### Milestone 2: Add Workflow Scripts

Files:

- `scripts/new_feature_spec.sh`
- `scripts/run_codex_planner.sh`
- `scripts/run_codex_reviewer.sh`

Reviewable outcome:

- Scripts pass `bash -n`.
- Planner script returns suggestions and does not directly overwrite files.
- Reviewer script reads active spec, active plan, git diff, status, and `just check` output.

### Milestone 3: Update Agent Instructions

Files:

- `AGENTS.md`
- `CLAUDE.md`

Reviewable outcome:

- Codex rules describe planner/reviewer responsibilities.
- Claude rules require active spec/plan before implementation.
- Instructions do not conflict with existing hooks, policy engine, checkpoint, or worktree rules.

### Milestone 4: Update Repository Context

Files:

- `context/current-state.md`

Reviewable outcome:

- Current state reflects implemented GitHub CI, ruleset, Claude hooks, policy engine, Codex judge, checkpoint recovery, and worktree workflow.

### Milestone 5: Add Demo Workflow Artifacts

Files:

- `specs/demo-agent-flow.md`
- `plans/demo-agent-flow-plan.md`
- `docs/codex-workflow-smoke-test.md`

Reviewable outcome:

- Demo spec and plan show the expected lifecycle.
- Demo remains documentation-only.
- Demo does not require unavailable external services.

### Milestone 6: Validate and Review

Commands:

```bash
bash -n scripts/new_feature_spec.sh
bash -n scripts/run_codex_planner.sh
bash -n scripts/run_codex_reviewer.sh
just check
scripts/run_codex_reviewer.sh spec-plan-review-workflow
```
Reviewable outcome:

- Local checks pass.
- Codex Reviewer reviews this PR against `specs/spec-plan-review-workflow.md` and `plans/spec-plan-review-workflow-plan.md`.

## Files Likely To Change

- `prompts/codex_planner.md`
- `prompts/codex_reviewer.md`
- `scripts/new_feature_spec.sh`
- `scripts/run_codex_planner.sh`
- `scripts/run_codex_reviewer.sh`
- `AGENTS.md`
- `CLAUDE.md`
- `context/current-state.md`
- `specs/spec-plan-review-workflow.md`
- `plans/spec-plan-review-workflow-plan.md`
- `specs/demo-agent-flow.md`
- `plans/demo-agent-flow-plan.md`
- `docs/codex-workflow-smoke-test.md`

## Test Plan

- Run shell syntax checks for all new scripts.
- Run `just check`.
- Run Codex Planner on `demo-agent-flow`.
- Run Codex Reviewer on `spec-plan-review-workflow`.
- Record smoke-test evidence in `docs/codex-workflow-smoke-test.md`.
- Confirm reviewer does not report scope creep for AGENTS/CLAUDE changes.
- Confirm PR diff does not modify protected files such as `.github/workflows`, secrets, deployment files, or migrations.

## Risk Checkpoints

- Before PR: confirm active reviewer spec is `spec-plan-review-workflow`, not `demo-agent-flow`.
- Before merge: confirm `just check` passes.
- Before merge: confirm reviewer output is APPROVE or contains only non-blocking issues.
- If reviewer reports scope creep, update spec/plan or remove out-of-scope files.

## PR Split Plan

Use one PR for this workflow foundation.

Reason:

- Prompts, scripts, agent instructions, and context updates are tightly coupled.
- Splitting would make the workflow incomplete in intermediate PRs.

Future PRs can separately add:

- Enforced reviewer CI gate
- Automatic PR creation
- Better model/effort configuration
- Real project-type checks in `justfile`
