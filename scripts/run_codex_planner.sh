#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: scripts/run_codex_planner.sh <feature-slug> <request>"
  exit 1
fi

FEATURE="$1"
REQUEST="$2"

SPEC="specs/${FEATURE}.md"
PLAN="plans/${FEATURE}-plan.md"

if ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found."
  exit 1
fi

cat <<EOF_PROMPT | codex exec -C . -m "${CODEX_PLANNER_MODEL:-gpt-5.5}" -
$(cat prompts/codex_planner.md)

Repository context:

$(cat context/current-state.md)

Current spec file path:
$SPEC

Current plan file path:
$PLAN

User request:
$REQUEST

Please produce the refined spec and plan content.
Do not edit files directly. Return markdown only.
EOF_PROMPT
