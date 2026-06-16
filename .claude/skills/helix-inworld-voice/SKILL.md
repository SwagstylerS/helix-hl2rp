---
name: helix-inworld-voice
description: >-
  Write or rewrite player-facing text for this HL2RP server so it reads as in-world, never as
  a game system. Use whenever producing a Notify / NotifyLocalized / ChatPrint / chat message
  / derma label / dispatch broadcast / sh_english.lua language string. Combine (Metropolice /
  OTA / Dispatch) messages use radio 10-codes and terms like subject, unit, malcompliant,
  processing, advisory; CWU messages use bureaucratic Union language (directive, oversight,
  requisition, quota, licence); citizens receive environmental cues only — never expose heat
  scores, tier numbers, cooldowns, percentages, or mechanic labels.
---

# In-World Voice Writer

Generative counterpart to `helix-convention-check`. Turn "what mechanically happened" into
text that sounds like it belongs in City 17.

## Procedure
1. Read the canonical voice rules in
   `../helix-convention-check/references/voice-guide.md` (single source — do not duplicate).
2. Identify the **audience** (Combine / CWU / citizen) — that picks the register.
3. Write the line(s) in that register, exposing **no** raw numbers, tiers, cooldowns, or
   mechanic labels to the affected player.
4. If the plugin localizes text, also produce a `sh_english.lua` `LANGUAGE` key
   (camelCase, plugin-prefixed) and show where it goes.
5. Note the realm/transport if relevant (server `Notify`/`ChatPrint` vs `netstream`).

## Quick reference (full detail in voice-guide.md)
- **Combine / Dispatch:** clipped radio — `"DISPATCH: 10-103M — <name> flagged for flagrant
  malcompliance. Designate for observation and detainment."` Real codebase lines:
  `"ADVISORY: You are a person of interest to Civil Protection."`, `">> DISPATCH // %s <<"`.
- **CWU:** bureaucratic — `"Union oversight notes satisfactory output; standing under the
  programme is improved."` Real lines: `"CIVIL WORKFORCE OVERSIGHT"`, `"Business license
  granted to %s."`
- **Citizen:** environmental only — a scanner ping, a flickering light, a vague advisory with
  no numbers, or nothing; let Combine-side broadcasts carry the consequence.

## Anti-patterns (rewrite these on sight)
- `"heat score reached 80/100"`, `"Tier 4"`, `"Cooldown: 30s"`, `"+15 loyalty"`,
  `"PERSON OF INTEREST: <name> — heat ..."` → restate as fiction in the right voice.
