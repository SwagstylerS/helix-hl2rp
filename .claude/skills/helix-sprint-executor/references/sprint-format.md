# WEEKLY_PLAN.md grammar

`_dev/WEEKLY_PLAN.md` structure (so parsing is robust):

- A top header: `# Weekly Development Plan`, a `**Week of ...**` line, and a `**Goal:**` line.
- Day blocks delimited by `---`, each headed:
  `## Day N — <Weekday> <Mon DD> · <Title>`
- Immediately under the header: a status line:
  - `**Status:** ✅ Done`  → completed, skip.
  - `**Status:** Pending`  → not started, this is a candidate.
  - (Treat any value that is not `✅ Done` as not-done.)
- Then optional prose notes (for done days, a summary of what was actually done).
- Then a `Goals:` list — bullet points, each typically:
  `` `path/to/file.lua` — <instruction with function name and ~line number and acceptance criteria>``

## Selecting the next day
Scan top-to-bottom; pick the first day whose status is not `✅ Done`.

## Marking done
Change `**Status:** Pending` → `**Status:** ✅ Done` and add a short prose note above
`Goals:` describing: what was added, any pre-existing bug fixed in passing, and what needed
no change (mirror the Day 1 / Day 2 notes already in the file).
