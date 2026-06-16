---
name: helix-sprint-executor
description: >-
  Execute the next pending day of the weekly development sprint in _dev/WEEKLY_PLAN.md for
  this Helix HL2RP schema. Use when asked to "do the next sprint task", "continue the weekly
  plan", "work the plan", or to implement a specific day. Reads WEEKLY_PLAN.md, finds the
  first day whose Status is Pending (not Done), implements exactly the file/function/line
  changes in its Goals against the acceptance criteria (no scope creep), runs
  helix-convention-check on the result, and proposes flipping that day's Status to Done.
---

# Helix Sprint Executor

Drive the weekly plan the way this repo is already driven: one day at a time, precisely to
its acceptance criteria.

## Procedure

1. **Read `_dev/WEEKLY_PLAN.md`.** Parse the day blocks and `**Status:**` lines. See
   `references/sprint-format.md` for the exact grammar (`✅ Done` vs `Pending`).
2. **Select the target day:** the first block whose status is **Pending** (skip `✅ Done`).
   - If the user named a specific day, use that.
   - If multiple are pending and the user was vague, confirm which one before editing.
3. **Read every file the day's Goals reference** before touching anything. The Goals cite
   exact files, function names, and approximate line numbers — treat them as the spec.
4. **Implement precisely.** Do only what the acceptance criteria describe. Do not refactor
   adjacent code or pull in later days. Match the surrounding plugin's style (see
   `helix-scaffold` for layout/networking conventions — combine-* uses raw net + `CS_*`).
5. **Self-review:** run `helix-convention-check` on the diff. The plan's own wording can be
   borderline-gamey (e.g. a heat-score string in a broadcast) — if the literal text in
   WEEKLY_PLAN conflicts with CONVENTIONS.md (no gamey text), surface the tension and
   propose an in-world rewrite using `helix-inworld-voice` rather than silently shipping it.
6. **Update status (with confirmation):** propose flipping that day's `**Status:**` to
   `✅ Done` and appending a short completion note matching the style of the already-done
   days (what changed, any bug fixed, what needed no change). Apply only after the user is OK.

## Notes
- As of the last read, Days 1–2 were `✅ Done`; the first Pending was **Day 3 (Vendor
  Terminal Out-of-Stock Alert)**. Always re-read the file — status changes over time.
- This skill edits code; it is not plan-mode. Still, confirm the day selection and the
  status edit with the user.
