# Development Conventions

Design rules that apply to all plugins. Check this before implementing any new mechanic.

---

## Interaction Model

**No chat commands for world interaction.**
Players must interact with the world through entities — use menus, terminals, props, or context actions. Chat commands (`/command`) are acceptable only for out-of-character admin/utility actions (e.g. `/panicbutton` as a last resort signal). Mechanics like detaining, releasing, trading, or operating equipment must go through an in-world entity or UI.

---

## Text & Messaging

**No gamey text.**
Any message shown to players must read as something that exists in the world, not as a game system speaking. No exposing internal scores, tier numbers, cooldown countdowns, or mechanic labels.

- Bad: `"PERSON OF INTEREST: John — heat score reached critical levels (80/100)"`
- Good: `"DISPATCH: 10-103M — John flagged for flagrant malcompliance. Designate for observation and detainment."`

Use Combine dispatch radio language (10-codes, "subject", "unit", "malcompliant", "processing") for CP/OTA-facing messages. CWU-facing messages should use bureaucratic Union language. Citizens receive nothing mechanical — environmental cues only.
