# System map
- This repository is the baseline template for an agentic coding workflow.
- GitHub PR gates and CI are configured.
- Claude Code executes tasks with DeepSeek through an Anthropic-compatible endpoint.
- Command safety is enforced through Claude Code hooks and a local policy engine.
- Medium-high risk commands can be routed to Codex judge.
- Checkpoint recovery is configured.
- Worktree workflow is being configured.

# Current architecture constraints
- Planning is separate from execution.
- Feature work should happen in a dedicated git worktree.
- Claude Code is the executor, not the planner.
- Codex Planner produces specs and plans.
- Codex Reviewer reviews diff, tests, and risks.
- Main must stay clean and synchronized with origin/main.
- Final merge is protected by PR, CI, and GitHub ruleset.

# Active modules
- specs/
- plans/
- context/
- scripts/
- .claude/
- .codex/
- prompts/
- .github/workflows/

# Implemented capabilities
- GitHub CI: Basic checks
- GitHub ruleset: PR required before merging into main
- Claude Code hooks: PreToolUse, PostToolUse, Stop
- Local command policy engine
- High-risk command blocking
- Medium-risk Codex judge routing
- Checkpoint creation and restore
- Worktree helper scripts in progress

# Known debt
- Planner output is not yet automatically written into spec/plan files.
- Reviewer output is not yet enforced as a merge blocker.
- CI currently runs only placeholder checks through justfile.
- Codex judge can be token-expensive for medium-high commands.
- Long-running real project workflow has not yet been validated.

# Current open risks
- DeepSeek API balance can block Claude execution.
- Codex network connectivity can be unstable.
- Model names may need adjustment through environment variables.
- Checkpoint restore must avoid deleting important untracked files.

# Next likely tasks
1. Finish worktree workflow PR
2. Add Codex planner/reviewer scripts
3. Add one-click task startup script
4. Upgrade justfile checks for real project types
5. Validate the full workflow on a small demo task
