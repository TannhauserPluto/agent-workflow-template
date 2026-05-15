# System map
- Repo just initialized.
- No production code yet.
- This repository is the baseline template for an agentic coding workflow.

# Current architecture constraints
- Planning is separate from execution.
- Execution happens in a dedicated worktree.
- Command safety is enforced by hooks + policy engine.
- Final merge is protected by PR + CI.

# Active modules
- specs/
- plans/
- context/
- scripts/
- .claude/
- .codex/

# Known debt
- Hooks not implemented yet.
- Reviewer agents not implemented yet.
- CI not implemented yet.

# Current open risks
- DeepSeek balance may block Claude execution.
- No policy engine rules yet.
- No restore/checkpoint automation yet.

# Next likely tasks
1. Add spec and plan templates
2. Add Claude project settings and permissions
3. Add minimal policy engine
4. Add checkpoint scripts
5. Add CI and PR template
