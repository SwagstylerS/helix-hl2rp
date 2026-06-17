---
name: helix-build
description: >
  Gate and implement new HL2RP feature ideas. Runs council-review to
  stress-test the idea (purpose, possibilities, risks in the HL2RP context),
  presents the verdict, waits for user confirmation, then implements the
  minimal working version using ponytail (lazy-dev, full mode) on opus.
  Use when: "build this", "implement this idea", "add X to the schema",
  "new feature", or whenever proposing something new for helix-hl2rp.
---

# Helix Build — Council-Gated Ponytail Implementation

Every new mechanic passes two gates before code is written:
1. **Council review** — does it fit the world and is it the right idea?
2. **Ponytail gate** — does it need to exist, and what is the shortest path?

---

## Step 1: Gather Context

Read these files before framing anything:

- `_dev/DIRECTION.md` — the five pillars; no mechanic ships against them
- `_dev/CONVENTIONS.md` — hard design rules (no chat-commands for world
  interaction, no gamey text, ENT.Category, netstream preference, etc.)
- `_dev/WEEKLY_PLAN.md` — current sprint; check if the idea overlaps or
  conflicts with planned work
- `git log --oneline -10` — recent changes; avoid re-doing finished work

---

## Step 2: Council Review

Invoke the `council-review` skill. Run the **full council** (not `--quick`) —
new feature decisions are high-stakes and cheap to get wrong.

Frame the question like this before passing to the council:

```
QUESTION:
Should we add [IDEA] to the HL2RP schema? If so, what is the right shape?

CONTEXT:
Project: Garry's Mod HL2RP schema on the Helix framework.
Hard constraints from CONVENTIONS.md:
  - No chat commands for world interaction (entities/menus/terminals only).
  - No gamey text — all player-facing strings must read in-world.
  - Combine/CWU/citizen voice rules strictly enforced.
Current sprint: [summary from WEEKLY_PLAN.md]
Recent git activity: [git log --oneline -10]
Relevant pillars from DIRECTION.md: [quote the 1-2 most relevant]

WHAT'S AT STAKE:
Wrong call means either:
  (a) a mechanic that breaks immersion or violates design conventions, or
  (b) missing a system that would make City 17 feel more alive.
Both failures are expensive to undo once they touch the live schema.
```

The council must assess all three angles:

- **Purpose** — what concrete in-world problem does this solve?
- **Possibilities** — what does it unlock or enable downstream?
- **Risks** — mechanical, atmospheric, and technical failure modes.

---

## Step 3: Present Verdict and Gate

Show the full council verdict in chat.

Then ask exactly this:

> "Proceed with ponytail implementation, or revise the idea first?"

**Do not write any code until the user confirms.** If they want to revise,
re-run the council with the updated idea (back to Step 2).

---

## Step 4: Ponytail Implementation on Opus

After the user confirms, spawn an **Agent with `model="opus"`** and give it
the following brief:

```
You are implementing [IDEA] for a Garry's Mod HL2RP schema (Helix framework).

Council verdict: [paste the council's Recommendation and Do This First sections]

Constraints:
- Read _dev/CONVENTIONS.md before touching anything.
- No chat commands for world interaction. Entities/menus/terminals only.
- No gamey player-facing text. In-world voice only.
- ENT.Category = "HL2 RP" on all new entities.
- Prefer netstream.Start/Hook over raw net.* in plugin code.
- Realms: sh_ shared, sv_ server-only, cl_ client-only.

Ponytail rules (full mode — enforce the whole ladder):
1. Does this need to exist at all? YAGNI — skip speculative scope.
2. Stdlib / Helix built-in covers it? Use it.
3. Native GMod feature covers it? Use it.
4. Already-used dependency solves it? Use it.
5. One line? One line.
6. Only then: the minimum code that works.

Before writing code:
- Check helix-api-reference for any ix.* or GMod API calls.
- If a new plugin/entity/item is needed, use helix-scaffold.

After writing code:
- Run helix-convention-check on the diff.
- Run helix-lint if glualint is installed.
- Commit with a lowercase feat:/fix:/chore: message, no emoji.
```

The agent implements, self-reviews, and proposes a commit. You (the main
Claude) review the diff with `helix-convention-check` before confirming the
commit.

---

## Notes

- The council gate is not optional. If the user tries to skip it ("just
  implement X"), remind them this workflow exists to prevent wasted work and
  run a `--quick` council at minimum.
- Ponytail governs what gets built, not the council's scope. The council
  decides *whether* and *what shape*; ponytail decides *how little code*.
- If the council verdict is "don't build this", respect it. Present the
  reasoning and close the loop — don't sneak a "lite version" in anyway.
