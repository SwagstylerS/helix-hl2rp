# Development Conventions

Design rules that apply to all plugins. Check this before implementing any new mechanic.

---

## Interaction Model

**No chat commands for world interaction.**
Players must interact with the world through entities — use menus, terminals, props, or context actions. Mechanics like detaining, releasing, trading, panicking, or operating equipment must go through an in-world entity or UI.

**Exception — communication commands are fine.** If the mechanic *is* sending text (radio channels, dispatch broadcasts, faction comms), a chat command is the correct implementation. `/CombineRadio`, `/alert`, and similar are acceptable as-is.

**Existing debt (to be reworked into entities):**
- `/panicbutton` / `/panicclear` — should be a wearable device or wall-mounted button entity
- `/transferdetainee` / `/releasedetainee` — should be an action on a terminal or processing entity
- `/curfew` — should be a switch or terminal action for senior Combine

---

## Text & Messaging

**No gamey text.**
Any message shown to players must read as something that exists in the world, not as a game system speaking. No exposing internal scores, tier numbers, cooldown countdowns, or mechanic labels.

- Bad: `"PERSON OF INTEREST: John — heat score reached critical levels (80/100)"`
- Good: `"DISPATCH: 10-103M — John flagged for flagrant malcompliance. Designate for observation and detainment."`

Use Combine dispatch radio language (10-codes, "subject", "unit", "malcompliant", "processing") for CP/OTA-facing messages. CWU-facing messages should use bureaucratic Union language. Citizens receive nothing mechanical — environmental cues only.

**Flavor text that names an in-world object is acceptable.** The rule targets mechanical exposure (numbers, tier labels, cooldown timers), not immersive description. `"The stimpak floods your system with healing compounds."` is fine — it names the item and evokes a physical sensation without revealing any stat. Show-don't-tell is the ideal, but descriptive flavor text is always preferable to a bare mechanic readout.

---

## Development Process

**Council gate for sprint planning.**
A new sprint may not be written into `_dev/WEEKLY_PLAN.md` until `/council-review` has been run
on the proposed goal and day list. The council verdict and any plan changes it caused are recorded
in the sprint header. If the council raises a blocker, the plan must address it before the sprint
is finalised.

**Untested code tracking.**
Every feature or fix committed in an automated session gets an entry in `_dev/UNTESTED.md`:
date, feature name, key files, and a concrete in-server test. The entry stays until a live-server
session verifies the behaviour and removes it. Before extending a system, check whether it has an
open UNTESTED entry — building on unverified code compounds the risk.
