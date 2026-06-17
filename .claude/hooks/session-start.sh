#!/usr/bin/env bash
# SessionStart hook for helix-hl2rp.
# Pure read/echo: surfaces the design docs, the current sprint day, and the project skills.
# MUST NOT block or fail the session — every path exits 0.

set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd || echo .)"
cd "$repo_root" 2>/dev/null || true

echo "=== helix-hl2rp — HL2 Roleplay schema (Helix) ==="
echo "Hard rules (see _dev/CONVENTIONS.md):"
echo "  1) No chat commands for world interaction — use entities/terminals/menus."
echo "  2) No gamey text — in-world voice only (dispatch / Union / environmental cues)."
echo "Read first: _dev/DIRECTION.md (vision), _dev/CONVENTIONS.md (rules), _dev/WEEKLY_PLAN.md (sprint)."

# Surface the next Pending sprint day, if the plan exists.
plan="_dev/WEEKLY_PLAN.md"
if [ -f "$plan" ]; then
  next_day="$(grep -nE '^## Day ' "$plan" 2>/dev/null | head -50 | while IFS= read -r line; do
    lineno="${line%%:*}"
    title="${line#*:}"; title="${title#\#\# }"            # strip "## "
    status="$(sed -n "$((lineno+1)),$((lineno+2))p" "$plan" 2>/dev/null | grep -m1 'Status:')"
    state="${status#*Status:}"; state="${state//\*/}"      # drop "**"
    state="${state#"${state%%[![:space:]]*}"}"             # trim leading space
    case "$status" in
      *"Done"*) : ;;                                       # completed, skip
      *Status:*) echo "${title} (${state})"; break ;;
    esac
  done)"
  if [ -n "${next_day:-}" ]; then
    echo "Next sprint task: ${next_day}"
  fi
fi

# glualint: report availability, never install or block.
if command -v glualint >/dev/null 2>&1; then
  echo "glualint: available — run /helix-lint to statically check Lua."
else
  echo "glualint: not installed (optional). /helix-lint explains the one-time install; /helix-convention-check needs no binary."
fi

echo "Project skills: helix-build (council → ponytail gate), helix-convention-check, helix-scaffold, helix-api-reference, helix-sprint-executor, helix-inworld-voice, helix-lint (+ vendored: ponytail, council-review, stop-slop)."
exit 0
