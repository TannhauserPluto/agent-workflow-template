#!/usr/bin/env python3
import json
import os
import re
import shutil
import subprocess
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
    r"\bfind\b.*\s-delete\b",
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

# Medium-low commands are allowed locally and logged.
# They are common coding workflow commands whose risk is acceptable.
MEDIUM_LOW_PATTERNS = [
    r"^npm\s+install\s+[\w@./-]+$",
    r"^pnpm\s+add\s+[\w@./-]+$",
    r"^yarn\s+add\s+[\w@./-]+$",
    r"^pip\s+install\s+[\w@./-]+$",
    r"^uv\s+add\s+[\w@./-]+$",
    r"^cargo\s+add\s+[\w@./-]+$",
    r"^cp\s+[\w./-]+\s+[\w./-]+$",
    r"^mv\s+[\w./-]+\s+[\w./-]+$",
    r"^mkdir\s+-p\s+[\w./-]+$",
    r"^touch\s+[\w./-]+$",
]

# Medium-high commands invoke Codex judge.
# They are not automatically destructive, but may modify many files,
# execute package lifecycle scripts, touch git history, or use shell composition.
MEDIUM_HIGH_PATTERNS = [
    r";",
    r"&&",
    r"\|\|",
    r"`",
    r"\$\(",
    r"\bsed\s+-i\b",
    r"\bperl\s+-pi\b",
    r"\bxargs\b",
    r"\bnpm\s+install\b.*(http|git\+|file:|--global|-g|--force|--legacy-peer-deps)",
    r"\bpip\s+install\b.*(http|git\+|-r|--user|--break-system-packages)",
    r"\bcurl\b",
    r"\bwget\b",
    r"\bgit\s+commit\b",
    r"\bgit\s+push\b",
    r"\bgit\s+tag\b",
    r"\bgh\s+",
    r"\bdocker\b",
    r"\bdocker-compose\b",
    r"\bdocker\s+compose\b",
]


def log_event(event: dict):
    with LOG_FILE.open("a", encoding="utf-8") as f:
        event = {"time": datetime.now().isoformat(timespec="seconds"), **event}
        f.write(json.dumps(event, ensure_ascii=False) + "\n")


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

    for pattern in MEDIUM_HIGH_PATTERNS:
        if re.search(pattern, stripped, re.IGNORECASE):
            return "medium-high", f"matched medium-high pattern: {pattern}"

    for pattern in MEDIUM_LOW_PATTERNS:
        if re.search(pattern, stripped, re.IGNORECASE):
            return "medium-low", f"matched medium-low allowlist: {pattern}"

    return "medium-high", "not explicitly allowlisted"


def find_codex():
    found = shutil.which("codex")
    if found:
        return found

    candidates = [
        Path.home() / ".npm-global/bin/codex",
        Path.home() / ".local/bin/codex",
    ]
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)

    return None


def extract_json(text: str):
    """
    Extract the last valid top-level JSON object from noisy CLI output.

    Codex CLI may print logs, transcripts, and token usage around the model answer.
    We therefore scan every possible JSON object start and keep the last object
    containing a 'decision' key.
    """
    text = text.strip()
    if not text:
        return None

    decoder = json.JSONDecoder()
    candidates = []

    for index, char in enumerate(text):
        if char != "{":
            continue
        try:
            obj, _ = decoder.raw_decode(text[index:])
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict) and "decision" in obj:
            candidates.append(obj)

    if candidates:
        return candidates[-1]

    return None


def review_medium_command_with_codex(command: str, reason: str):
    enabled = os.environ.get("AGENT_ENABLE_CODEX_JUDGE", "1") == "1"
    if not enabled:
        return {
            "decision": "allow",
            "reason": "Codex judge disabled by AGENT_ENABLE_CODEX_JUDGE",
            "raw": "",
        }

    codex_bin = find_codex()
    if not codex_bin:
        return {
            "decision": "allow",
            "reason": "Codex CLI not found; fail-open during bootstrap",
            "raw": "",
        }

    model = os.environ.get("CODEX_JUDGE_MODEL", "gpt-5.4-mini")

    prompt = f"""
You are a command safety reviewer for an autonomous coding workflow.

You must review ONE shell command before Claude Code executes it.

Repository policy:
- Allow read-only commands.
- Allow ordinary test/lint/build commands.
- Be cautious with dependency installs, file generation, bulk edits, network access, git operations, Docker, GitHub CLI, and shell composition.
- Deny commands that touch secrets, .env files, deployment scripts, GitHub workflows, migrations, or destructive operations.
- Deny commands that are outside the current coding workflow.
- If a command is only medium-risk but reasonable for coding, allow it.
- If uncertain, deny.

Return JSON only, no markdown:
{{
  "decision": "allow" or "deny",
  "reason": "short reason"
}}

Command:
{command}

Local classifier reason:
{reason}
""".strip()

    try:
        proc = subprocess.run(
            [codex_bin, "exec", "-C", str(ROOT), "-m", model, prompt],
            text=True,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            timeout=90,
        )
    except Exception as exc:
        return {
            "decision": "allow",
            "reason": f"Codex judge failed-open during bootstrap: {exc}",
            "raw": "",
        }

    raw = (proc.stdout or "") + "\n" + (proc.stderr or "")
    parsed = extract_json(raw)

    if proc.returncode != 0:
        return {
            "decision": "allow",
            "reason": f"Codex judge returned non-zero exit {proc.returncode}; fail-open during bootstrap",
            "raw": raw[-1000:],
        }

    if not parsed:
        return {
            "decision": "allow",
            "reason": "Codex judge output was not parseable JSON; fail-open during bootstrap",
            "raw": raw[-1000:],
        }

    decision = str(parsed.get("decision", "")).lower().strip()
    judge_reason = str(parsed.get("reason", "")).strip() or "no reason provided"

    if decision not in {"allow", "deny"}:
        decision = "allow"
        judge_reason = f"invalid Codex decision; fail-open. Original reason: {judge_reason}"

    return {
        "decision": decision,
        "reason": judge_reason,
        "raw": raw[-1000:],
    }


def deny(reason: str, command: str):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": f"Blocked by local policy engine: {reason}. Command: {command}"
        }
    }, ensure_ascii=False))
    return 0


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

    base_event = {
        "risk": risk,
        "reason": reason,
        "command": command,
    }

    if risk == "high":
        log_event({**base_event, "decision": "deny"})
        return deny(reason, command)

    if risk in {"low", "medium-low"}:
        log_event({**base_event, "decision": "allow"})
        return 0

    review = review_medium_command_with_codex(command, reason)
    decision = review["decision"]

    log_event({
        **base_event,
        "decision": decision,
        "codex_reason": review["reason"],
        "codex_raw_tail": review.get("raw", ""),
    })

    if decision == "deny":
        return deny(f"Codex mini denied medium-risk command: {review['reason']}", command)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
