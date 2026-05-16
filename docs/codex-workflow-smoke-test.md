# Codex Workflow Smoke Test

## Purpose

Record evidence that the spec-plan-review workflow was exercised beyond shell syntax checks.

## Commands exercised

```bash
bash -n scripts/new_feature_spec.sh
bash -n scripts/run_codex_planner.sh
bash -n scripts/run_codex_reviewer.sh
just check
scripts/run_codex_planner.sh demo-agent-flow "Create a demo workflow showing spec, plan, execution, review, and PR gates."
scripts/run_codex_reviewer.sh spec-plan-review-workflow
```

## Observed result

- `bash -n` checks passed for the new shell scripts.
- `just check` completed successfully with the current placeholder fmt/lint/test commands.
- `run_codex_planner.sh` produced refined markdown content for the demo spec and plan.
- `run_codex_reviewer.sh` reviewed the active spec, active plan, git status, git diff, and check output.
- Reviewer initially requested changes for a malformed markdown fence and missing shell-check evidence.
- The malformed markdown fence was fixed.
- Reviewer feedback was used to add this smoke-test record and improve `new_feature_spec.sh`.

## Known limitations

- Codex connectivity may produce transient websocket or model-refresh warnings.
- Reviewer output is advisory only and is not yet enforced by CI.
- Current `just check` uses placeholder project checks.
