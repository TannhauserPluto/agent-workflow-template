
# Worktree + Checkpoint Workflow

## Purpose

This repository uses two safety layers for agentic coding:

1. Git worktree isolates each task in its own directory and branch.
    
2. Checkpoint saves recoverable patches inside the current task worktree.
    

## Standard task flow

Create a task worktree:

```bash
scripts/new_task_worktree.sh feat/example-task ../wt-example-task
cd ../wt-example-task
claude
```

Claude Code should work inside the task worktree, not directly on `main`.

## Checkpoints

During Claude Code execution, checkpoints are created automatically before Bash, Write, and Edit tool use.

Manually create a checkpoint:

```bash
bash scripts/failure_checkpoint.sh
```

Restore the latest checkpoint:

```bash
bash scripts/restore_checkpoint.sh
```

Restore and also clean untracked files:

```bash
bash scripts/restore_checkpoint.sh --clean-untracked
```

## After PR merge

Return to the main repository and remove the task worktree:

```bash
cd ~/agent-workbench/project-template
scripts/remove_task_worktree.sh ../wt-example-task feat/example-task
```

## Rules

- Never implement features directly on `main`.
    
- Each feature, bugfix, or experiment gets its own worktree.
    
- Commit at milestone boundaries.
    
- Open PRs from task branches.
    
- Delete task worktrees after merge.
