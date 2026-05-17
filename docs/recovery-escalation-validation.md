# Recovery and Escalation Validation Report

## Scope

This report records the manual validation performed for the recovery and escalation workflow.

Validated files:

- scripts/agent_diagnose_stuck.sh
- scripts/agent_recover_to_point.sh
- scripts/escalate_to_codex.sh
- scripts/run_codex_reviewer.sh
- docs/agent-branch-recovery-workflow.md
- AGENTS.md
- CLAUDE.md

## Commands validated

- bash -n scripts/agent_diagnose_stuck.sh
- bash -n scripts/agent_recover_to_point.sh
- bash -n scripts/escalate_to_codex.sh
- bash -n scripts/run_codex_reviewer.sh
- just check
- scripts/agent_diagnose_stuck.sh --feature recovery-escalation
- scripts/escalate_to_codex.sh --feature recovery-escalation
- scripts/agent_recover_to_point.sh
- scripts/agent_recover_to_point.sh --commit HEAD
- scripts/agent_recover_to_point.sh --commit HEAD --reset-current
- scripts/agent_recover_to_point.sh --commit HEAD --new-branch rescue/recovery-escalation-smoke

## Reviewer blocker follow-up

Reviewer-found blockers were fixed on 2026-05-16:

- `scripts/agent_recover_to_point.sh --reset-current` now moves `HEAD` with `git reset --soft <commit>`, restores the index and tracked working tree from the requested commit, preserves untracked files, and verifies no tracked diff remains.
- `scripts/agent_recover_to_point.sh` now rejects conflicting or inapplicable flags before recovery actions.
- `scripts/agent_recover_to_point.sh --checkpoint latest` now fails explicitly if tracked restore fails before checkpoint patches are applied, instead of masking the restore error.
- `scripts/agent_recover_to_point.sh --commit <sha> --new-branch <branch>` now sanitizes the generated rescue worktree directory for branch names containing slashes.
- `scripts/escalate_to_codex.sh` now prefers the newest relevant `.agent-logs/codex-review-packet-*.md` reviewer packet when building `reviewer-output.txt`, with a clear placeholder when no reviewer evidence exists.

Validation commands rerun:

- bash -n scripts/agent_recover_to_point.sh
- bash -n scripts/escalate_to_codex.sh
- bash -n scripts/run_codex_reviewer.sh
- scripts/agent_recover_to_point.sh --commit HEAD --reset-current
- scripts/agent_recover_to_point.sh --commit HEAD --new-branch rescue/recovery-escalation-smoke --clean-untracked
- scripts/agent_recover_to_point.sh --checkpoint latest --new-branch rescue/bad
- scripts/agent_recover_to_point.sh --commit HEAD --reset-current --confirm-reset-current --dry-run
- scripts/agent_recover_to_point.sh --commit HEAD --new-branch rescue/recovery-escalation-path-smoke --dry-run
- scripts/agent_recover_to_point.sh --checkpoint latest --dry-run
- scripts/escalate_to_codex.sh --feature recovery-escalation
- just check

Expected validation outcomes:

- The first three commands passed shell syntax validation.
- The unconfirmed `--reset-current` command failed fast without running recovery.
- The invalid `--clean-untracked` and checkpoint/new-branch combinations failed fast with clear errors.
- The confirmed reset-current command was run only with `--dry-run` and did not rewrite the branch.
- The rescue-branch dry-run printed a sanitized worktree path for a slash-containing branch name:
  - ../wt-rescue_recovery-escalation-path-smoke
- The checkpoint dry-run printed intended actions without modifying files.
- Escalation bundle generation completed and copied the latest Codex review packet into `reviewer-output.txt`.
- `just check` passed with the current placeholder fmt/lint/test targets.

## Expected results

- All shell scripts pass bash syntax validation.
- just check completes, although fmt/lint/test are currently placeholder steps.
- The diagnosis script creates a stuck report under .agent-logs/.
- The escalation script creates a bundle under .agent-escalation/.
- The escalation bundle includes:
  - checkpoints.txt
  - diff.patch
  - escalation.md
  - git-log.txt
  - reviewer-output.txt
  - staged.diff.patch
  - status.txt
  - stuck-report.md
  - test-output.txt
- Invalid recovery argument combinations are rejected.
- --reset-current is refused unless explicit confirmation is provided.
- Rescue-branch mode creates a separate rescue branch and worktree instead of rewriting the current branch.
- Cleanup of smoke-test rescue worktree/branch is manual and intentionally guarded by local policy.

## Actual results

- bash -n passed for all new scripts and the reviewer script.
- just check passed, but fmt/lint/test are still placeholders.
- scripts/agent_diagnose_stuck.sh --feature recovery-escalation generated a stuck report.
- scripts/escalate_to_codex.sh --feature recovery-escalation generated an escalation bundle with the expected files.
- Initial escalation runs exposed a pipefail plus head SIGPIPE issue.
- The SIGPIPE issue was fixed in:
  - scripts/agent_diagnose_stuck.sh
  - scripts/escalate_to_codex.sh
- Invalid recovery argument tests rejected unsafe or incomplete forms.
- Rescue branch smoke test passed before path hardening:
  - branch: rescue/recovery-escalation-smoke
  - worktree: ../wt-rescue/recovery-escalation-smoke
- Later path-hardening dry-run confirmed future slash-containing branch worktrees use a single sanitized directory:
  - ../wt-rescue_recovery-escalation-path-smoke
- Cleanup of the rescue branch/worktree was blocked by the local policy engine, which is expected for destructive git operations.

## Not validated

- Full checkpoint restore was not destructively exercised on the active task branch.
- reset-current destructive recovery was not executed.
- just check is still placeholder-based and should be improved in a later task.

## Safety conclusion

The implementation follows the intended safety model:

- No destructive recovery by default.
- No git reset --hard.
- No default git clean -fd.
- Failure state is saved before recovery actions.
- Rescue branches are preferred over rewriting the current branch.
- reset-current requires explicit confirmation.
- Escalation creates a bundle for Codex high review but does not auto-invoke Codex.
- No automatic PR merge is performed.

## Reviewer-requested behavioral evidence

This section was added after Codex Reviewer requested clearer evidence for the behavior tests required by the plan.

### Diagnosis behavior evidence

Command exercised:

- scripts/agent_diagnose_stuck.sh --feature recovery-escalation

Observed result:

- The script generated a stuck report.
- Observed report path:
  - .agent-logs/stuck-report-20260516-181940.md
- This confirms that the diagnosis path creates a runtime report under .agent-logs/.
- .agent-logs/ is intentionally ignored and is not committed.

### Escalation bundle behavior evidence

Command exercised:

- scripts/escalate_to_codex.sh --feature recovery-escalation

Observed result:

- The script generated an escalation bundle.
- Observed bundle path:
  - .agent-escalation/escalation-20260516-181940
- Observed bundle files:
  - checkpoints.txt
  - diff.patch
  - escalation.md
  - git-log.txt
  - reviewer-output.txt
  - staged.diff.patch
  - status.txt
  - stuck-report.md
  - test-output.txt
- The script printed the manual next step:
  - present escalation.md to Codex high for recovery decision
- The script did not auto-invoke Codex and did not modify git history.
- .agent-escalation/ is intentionally ignored and is not committed.

### Recovery argument validation evidence

Commands exercised:

- scripts/agent_recover_to_point.sh
- scripts/agent_recover_to_point.sh --commit HEAD
- scripts/agent_recover_to_point.sh --commit HEAD --reset-current

Observed result:

- Missing recovery form was rejected.
- Incomplete commit recovery was rejected.
- reset-current without --confirm-reset-current was rejected.
- The script printed usage guidance.
- The script explicitly stated that Codex high must approve reset-current before execution.

### Rescue branch behavior evidence

Command exercised:

- scripts/agent_recover_to_point.sh --commit HEAD --new-branch rescue/recovery-escalation-smoke

Observed result:

- A rescue branch was created:
  - rescue/recovery-escalation-smoke
- A separate rescue worktree was created during the original smoke test:
  - /home/y/agent-workbench/wt-rescue/recovery-escalation-smoke
- Current hardened path generation for future slash-containing branch names uses a sanitized directory:
  - /home/y/agent-workbench/wt-rescue_recovery-escalation-path-smoke
- The active task branch remained:
  - feat/recovery-escalation
- The active task worktree remained:
  - /home/y/agent-workbench/wt-recovery-escalation
- No automatic merge was performed.
- The smoke-test branch and worktree were later removed manually.

### Checkpoint recovery safety evidence

Checkpoint restore was not executed destructively on the active task branch.

Reason:

- Checkpoint restore can alter the active worktree.
- This feature is specifically designed so Codex high chooses recovery paths before execution.
- Running destructive checkpoint recovery on the active implementation branch would violate the safety model being introduced.

Safe coverage used instead:

- Checkpoint information is collected into diagnosis reports.
- Checkpoint information is copied into escalation bundles.
- Recovery script exposes checkpoint recovery as an explicit form:
  - --checkpoint latest
- Untracked cleanup remains opt-in only:
  - --clean-untracked
- No default git clean -fd behavior is used.

If dry-run was run for checkpoint recovery, record it here:

- scripts/agent_recover_to_point.sh --checkpoint latest --dry-run
- Expected acceptable outcomes:
  - prints intended checkpoint recovery actions without modifying files
  - or reports that no checkpoint is available
- In both cases, no destructive active-branch recovery is performed.

### Reset-current safety evidence

reset-current was not executed destructively.

Reason:

- reset-current rewrites tracked files in the current branch.
- It should only be run after Codex high selects that recovery path and a human confirms it.

Safety behavior validated:

- reset-current without --confirm-reset-current is rejected.
- reset-current requires:
  - --reset-current
  - --confirm-reset-current
- Dry-run may be used to inspect behavior without modifying the current branch:
  - scripts/agent_recover_to_point.sh --commit HEAD --reset-current --confirm-reset-current --dry-run

### Reviewer integration evidence

Command to run before PR:

- scripts/run_codex_reviewer.sh recovery-escalation

Observed issue:

- Codex Reviewer can hit local sandbox or bubblewrap read errors in this Linux environment.
- When that happens, the reviewer may rely on provided test evidence rather than fully reading runtime artifacts.
- This validation report is committed so behavior evidence is visible in the staged diff.

Reviewer-script integration:

- scripts/run_codex_reviewer.sh was updated to include syntax checks for:
  - scripts/agent_diagnose_stuck.sh
  - scripts/agent_recover_to_point.sh
  - scripts/escalate_to_codex.sh

### Explicitly not executed

The following high-risk paths were intentionally not executed on the active task branch:

- destructive checkpoint restore
- reset-current with real execution
- git clean -fd
- git reset --hard

Reason:

- The purpose of this workflow is to prevent uncontrolled destructive recovery.
- These paths should only be used after Codex high selects them and the human operator confirms the action.

## Final recovery hardening validation

Additional validation was run after reviewer feedback on checkpoint restore and reset-current ordering.

Observed validation:

- grep for `git restore.*|| true` returned no matches.
- `bash -n scripts/agent_recover_to_point.sh` passed.
- `scripts/agent_recover_to_point.sh --commit HEAD --reset-current` was rejected because `--confirm-reset-current` was missing.
- `scripts/agent_recover_to_point.sh --commit HEAD --reset-current --confirm-reset-current --dry-run` did not modify the current branch.
- reset-current dry-run showed the safe order:
  - save rescue artifacts first
  - keep HEAD unchanged initially
  - restore index and tracked working-tree files from the target commit
  - verify index and worktree against the target commit
  - move HEAD only after successful verification
  - verify final clean tracked state
- `scripts/agent_recover_to_point.sh --commit HEAD --new-branch rescue/recovery-escalation-smoke --clean-untracked` was rejected because `--clean-untracked` is only valid with `--checkpoint latest`.
- `scripts/agent_recover_to_point.sh --checkpoint latest --dry-run` printed the selected checkpoint and did not perform destructive recovery.
- checkpoint dry-run explicitly reported that untracked files would not be cleaned by default.

Safety conclusion from final validation:

- checkpoint recovery no longer masks required restore failures with `|| true`.
- reset-current no longer moves HEAD before restore and verification.
- conflicting clean-untracked usage is rejected.
- checkpoint recovery remains non-destructive in dry-run validation.

## Confirm-reset-current validation rerun result

Final rerun result:

- `scripts/agent_recover_to_point.sh --checkpoint latest --confirm-reset-current` now fails before checkpoint recovery starts.
- Observed error:
  - `Error: --confirm-reset-current is only valid with --reset-current.`
- This confirms that checkpoint mode can no longer bypass the global confirm-reset-current validation.

Usage wording cleanup:

- Help text now says `git clean -fd by default`.
- The actual cleanup command remains explicit as `git clean -fd -- .` and is only reachable through the explicit `--clean-untracked` checkpoint path.

## Reviewer-blocking audit follow-up

Reviewer-blocking audit issues were fixed on 2026-05-17:

- `scripts/agent_diagnose_stuck.sh` now discovers the newest `.agent-escalation/escalation-*` bundles and includes bounded evidence excerpts from `escalation.md`, `reviewer-output.txt`, `test-output.txt`, `status.txt`, `git-log.txt`, and `checkpoints.txt` when present.
- `scripts/agent_recover_to_point.sh` now writes `recovery-action-<timestamp>.md` for success and targeted failure paths, including checkpoint restore failures, new-branch/worktree failures, reset-current restore failures, reset-current pre-move verification failures, and reset-current final verification failures.

Validation commands rerun:

- bash -n scripts/agent_diagnose_stuck.sh
- bash -n scripts/agent_recover_to_point.sh
- bash -n scripts/escalate_to_codex.sh
- scripts/agent_diagnose_stuck.sh --feature recovery-escalation
- scripts/agent_recover_to_point.sh --checkpoint latest --confirm-reset-current
- scripts/agent_recover_to_point.sh --commit HEAD --reset-current
- scripts/agent_recover_to_point.sh --commit HEAD --reset-current --confirm-reset-current --dry-run
- just check

## Reviewer-blocking validation follow-up

Additional reviewer-blocking validation was completed on 2026-05-17.

Diagnosis escalation evidence:

- `scripts/agent_diagnose_stuck.sh --feature recovery-escalation` generated a stuck report.
- The report includes an early `Evidence Discovery Summary` listing the newest `.agent-escalation/escalation-*` directories.
- The report includes bounded bundle evidence for:
  - `escalation.md`
  - `reviewer-output.txt`
  - `test-output.txt`
  - `status.txt`
  - `git-log.txt`
  - `checkpoints.txt`
- Subdirectory smoke:
  - ran `../scripts/agent_diagnose_stuck.sh --feature recovery-escalation` from `scripts/`.
  - observed report path:
    - `.agent-logs/stuck-report-20260517-172906.md`
  - command exited 0.
- Unsafe feature slug rejection:
  - `scripts/agent_diagnose_stuck.sh --feature ../../AGENTS` exited non-zero.
  - `scripts/escalate_to_codex.sh --feature ../../AGENTS --dry-run` exited non-zero.
  - both commands printed:
    - `Error: unsafe feature slug: ../../AGENTS`

Recovery action logs:

- Recovery attempts now record `recovery-action-<timestamp>.md` for success, failed, and `branch-only` outcomes after entering an actual recovery mode.
- The action log records timestamp, mode, status, branch, HEAD, target commit or checkpoint, rescue artifact paths, failure detail where relevant, and `git status --short --branch`.

Branch-only fallback smoke:

- Command:
  - `scripts/agent_recover_to_point.sh --commit HEAD --new-branch rescue/recovery-escalation-fallback-smoke`
- Setup:
  - pre-created `../wt-rescue_recovery-escalation-fallback-smoke` to force the worktree path conflict.
- Observed result:
  - rescue branch was created.
  - worktree creation was reported as failed because the directory already existed.
  - script reported `Branch-only recovery succeeded.`
  - current branch remained `feat/recovery-escalation`.
  - script exited 0.
  - action log was written:
    - `.agent-logs/recovery-action-20260517-174049.md`
  - action log status:
    - `branch-only`
  - action log included rescue untracked evidence paths:
    - `.agent-logs/recovery-rescue-20260517-174049.untracked.zlist`
    - `.agent-logs/recovery-rescue-20260517-174049.untracked.tar`
- Cleanup:
  - deleted temporary branch `rescue/recovery-escalation-fallback-smoke`.
  - removed temporary conflicting directory `../wt-rescue_recovery-escalation-fallback-smoke`.

Checkpoint restore smoke in disposable worktree:

- Active implementation worktree was not used for real checkpoint restore.
- Disposable branch:
  - `smoke/checkpoint-restore`
- Disposable worktree:
  - `../wt-checkpoint-restore-smoke`
- Setup:
  - created the disposable worktree from current `HEAD`.
  - copied current versions of:
    - `scripts/agent_recover_to_point.sh`
    - `scripts/agent_diagnose_stuck.sh`
    - `scripts/escalate_to_codex.sh`
  - inside the disposable worktree, created `checkpoint-smoke.txt` with content `before`.
  - staged `checkpoint-smoke.txt`.
  - ran `scripts/failure_checkpoint.sh`.
  - changed `checkpoint-smoke.txt` content to `after`.
- Command:
  - `scripts/agent_recover_to_point.sh --checkpoint latest`
- Observed result:
  - script saved rescue artifacts first.
  - script restored the selected checkpoint rather than the rescue checkpoint.
  - `checkpoint-smoke.txt` content was restored to `before`.
  - selected checkpoint untracked archive was detected but not restored by default.
  - current untracked files were left intact; no broad `git clean -fd` was run.
  - action log was written in the disposable worktree.
  - command exited 0.
- Cleanup:
  - removed disposable worktree `../wt-checkpoint-restore-smoke`.
  - deleted disposable branch `smoke/checkpoint-restore`.

Checkpoint staged deletion smoke in disposable worktree:

- Active implementation worktree was not used for real checkpoint restore.
- Disposable branch:
  - `smoke/checkpoint-restore`
- Disposable worktree:
  - `../wt-checkpoint-restore-smoke`
- Setup:
  - created the disposable worktree from current `HEAD`.
  - copied current versions of:
    - `scripts/agent_recover_to_point.sh`
    - `scripts/agent_diagnose_stuck.sh`
    - `scripts/escalate_to_codex.sh`
  - staged deletion of tracked file `AGENTS.md` with `git rm AGENTS.md`.
  - ran `scripts/failure_checkpoint.sh`.
  - restored `AGENTS.md` before recovery to prove recovery replays the checkpoint deletion.
- Command:
  - `scripts/agent_recover_to_point.sh --checkpoint latest`
- Observed result:
  - script saved rescue artifacts first.
  - rescue artifacts included:
    - `.agent-logs/recovery-rescue-20260517-174834.untracked.zlist`
    - `.agent-logs/recovery-rescue-20260517-174834.untracked.tar`
  - selected checkpoint untracked archive was detected but not restored by default.
  - selected checkpoint staged deletion was restored.
  - `test ! -e AGENTS.md` passed.
  - `git diff --cached --name-status -- AGENTS.md` showed:
    - `D AGENTS.md`
  - command exited 0.
- Cleanup:
  - removed disposable worktree `../wt-checkpoint-restore-smoke`.
  - deleted disposable branch `smoke/checkpoint-restore`.

Reviewer rerun:

- Command:
  - `scripts/run_codex_reviewer.sh recovery-escalation`
- Result:
  - end-to-end reviewer command completed on 2026-05-17.
  - observed packet:
    - `.agent-logs/codex-review-packet-recovery-escalation-20260517-170028.md`
  - observed verdict:
    - `REQUEST_CHANGES`
  - the blocking findings from that run were:
    - branch-only fallback needed to exit 0 after branch creation/worktree failure.
    - checkpoint restore needed a real disposable-worktree smoke test.
    - validation evidence needed to record the reviewer command.
  - this follow-up addresses those findings before the final reviewer rerun.
