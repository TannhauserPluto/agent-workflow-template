#!/usr/bin/env python3
import json
import re
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd()
LOG_DIR = ROOT / ".agent-logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / "command_policy.log"

HIGH_RISK_PATTERNS = [
    r"\brm\s+-rf\b",
    r"\bsudo\s+rm\b",
    r"\bmkfs\b",
    r"\bdd\s+if=",
    r"\bchmod\s+-R\s+777\b",
    r"\bchown\s+-R\b",
    r"\bcurl\b.*\|\s*(bash|sh)",
    r"\bwget\b.*\|\s*(bash|sh)",
    r"\bgit\s+push\b.*--force",
    r"\bgit\s+reset\b.*--hard",
    r"\bgit\s+clean\b.*-fd",
    r"\bgh\s+secret\b",
    r"\bexport\b.*(TOKEN|KEY|SECRET|PASSWORD)",
    r"\b[A-Za-z_]*(TOKEN|KEY|SECRET|PASSWORD)[A-Za-z_]*=",
]

SENSITIVE_PATH_PATTERNS = [
    r"\.env",
    r"\.pem\b",
    r"\.key\b",
    r"\.ssh/",
    r"\.github/workflows/",
    r"deploy",
    r"migration",
    r"migrations",
]

LOW_RISK_PREFIXES = (
    "ls",
    "pwd",
    "cat ",
    "head ",
    "tail ",
    "grep ",
    "rg ",
    "find ",
    "git status",
    "git diff",
    "git log",
    "git branch",
    "tree",
    "just check",
    "just test",
    "just lint",
    "just fmt",
    "pytest",
    "npm test",
    "pnpm test",
)

def classify(command: str):
    stripped = command.strip()

    for pattern in HIGH_RISK_PATTERNS:
        if re.search(pattern, stripped, re.IGNORECASE):
            return "high", f"matched high-risk command pattern: {pattern}"

    for pattern in SENSITIVE_PATH_PATTERNS:
        if re.search(pattern, stripped, re.IGNORECASE):
            return "high", f"matched sensitive path/pattern: {pattern}"

    if stripped.startswith(LOW_RISK_PREFIXES):
        return "low", "matched low-risk allowlist"

    if any(x in stripped for x in [" install ", " add ", " write", "mv ", "cp ", "sed -i", "perl -pi"]):
        return "medium", "medium-risk mutation or dependency command"

    return "medium", "not explicitly allowlisted"

def main():
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        payload = {}

    command = (
        payload.get("tool_input", {}).get("command")
        or payload.get("command")
        or ""
    )

    risk, reason = classify(command)

    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps({
            "time": datetime.now().isoformat(timespec="seconds"),
            "risk": risk,
            "reason": reason,
            "command": command,
        }, ensure_ascii=False) + "\n")

    if risk == "high":
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": f"Blocked by local policy engine: {reason}. Command: {command}"
            }
        }, ensure_ascii=False))
        return 0

    # low and medium are allowed for now.
    # Medium will later be routed to Codex mini review.
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
