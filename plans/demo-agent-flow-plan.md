# Demo Agent Flow Plan

## Scope

Create documentation artifacts that demonstrate the intended agentic workflow for this repository.

In scope:

- Document the demo lifecycle from spec through PR gate.
- Make the role split explicit: Codex Planner, Claude Code executor, Codex Reviewer.
- Show the expected worktree-based execution path.
- Define review and PR gates at a practical level.

Out of scope:

- Implementing production application code.
- Changing deployment files.
- Changing secrets.
- Changing CI workflows.
- Changing database migrations.

## Milestones

### Milestone 1: Define Demo Spec

Create or refine `specs/demo-agent-flow.md`.

Reviewable outcome:

- The spec clearly states the goal, non-goals, user stories, acceptance criteria, constraints, risks, and rollback plan.
- The spec does not imply unavailable automation.

### Milestone 2: Define Demo Plan

Create or refine `plans/demo-agent-flow-plan.md`.

Reviewable outcome:

- The plan lists scope, milestones, likely files, test plan, risk checkpoints, and PR split plan.
- The plan is small enough to be implemented as one documentation PR.

### Milestone 3: Execute Documentation Change

Execution must happen in a dedicated worktree.

Expected executor flow:

```bash
scripts/new_task_worktree.sh feat/demo-agent-flow ../wt-demo-agent-flow
cd ../wt-demo-agent-flow
```

Then update only the planned documentation files.

Reviewable outcome:

The diff is limited to the demo spec and demo plan unless a reviewer approves additional documentation changes.
Milestone 4: Validate Locally

Run the repository check command before declaring completion.

Expected command:

just check

Reviewable outcome:

Local checks pass, or any missing command/tooling is documented as a known current repository gap.
Milestone 5: Reviewer Gate

Codex Reviewer performs a read-only review.

Reviewer must check:

Diff matches the active spec and plan.
No production implementation code was added.
No protected files were modified.
Risks and rollback are documented.
just check result is reported.

Reviewable outcome:

Reviewer returns APPROVE, REQUEST_CHANGES, or NEEDS_HUMAN_REVIEW.
Milestone 6: PR Gate

Open a small PR for the documentation-only demo.

PR requirements:

PR references specs/demo-agent-flow.md.
PR summarizes the workflow being demonstrated.
PR includes local check results.
PR does not merge until required checks pass.
Files Likely To Change
specs/demo-agent-flow.md
plans/demo-agent-flow-plan.md
context/current-state.md

Files not expected to change:

Deployment files
Secrets
CI workflows
Database migrations
Policy engine implementation
Hook implementation
Test Plan
Run just check.
Manually inspect the documentation for consistency with context/current-state.md.
Confirm the spec includes all required sections.
Confirm the plan includes all required sections.
Confirm the workflow explicitly requires a dedicated worktree.
Confirm the demo does not assume unavailable services.
Risk Checkpoints
Before execution: confirm main is clean and work happens in a dedicated worktree.
After documentation edits: confirm the diff only includes intended files.
Before review: run just check.
During review: verify no protected areas were modified.
Before PR merge: confirm required checks pass.
PR Split Plan

Use one PR for this task.

Reason:

The change is documentation-only.
The affected files are tightly related.
Splitting the spec and plan into separate PRs would add process overhead without reducing meaningful risk.

Potential PR title:

docs: add demo agent workflow spec and plan

