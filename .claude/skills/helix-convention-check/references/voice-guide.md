# In-World Voice Guide (canonical)

This is the single canonical voice reference. `helix-convention-check` uses it to detect
and rewrite gamey text; `helix-inworld-voice` uses it to author new player-facing text.
Grounded in `_dev/CONVENTIONS.md` and existing strings in the codebase.

## Core rule

Every message a player sees must read as something that exists **in the world**, never as
a game system speaking. Never expose internal scores, tier numbers, cooldown countdowns,
percentages, or mechanic labels to the affected player.

## Audience → voice

### Combine (Metropolice / OTA / Dispatch) — radio dispatch register
Clipped, procedural, dehumanizing. Use 10-codes and Combine jargon.
- Vocabulary: `subject`, `unit`, `malcompliant` / `malcompliance`, `anticitizen`,
  `processing`, `detainment`, `designate`, `observation`, `advisory`, `dispatch`,
  `sector`, `clearance`, `Civil Protection`.
- Real examples in the codebase:
  - `"ADVISORY: You are a person of interest to Civil Protection."`
  - `">> DISPATCH // <message> <<"`
  - `"NO VALID SUBJECT IN RANGE"`, `"SUBJECT OUT OF RANGE"`
- Transform (from CONVENTIONS.md):
  - BAD: `"PERSON OF INTEREST: John — heat score reached critical levels (80/100)"`
  - GOOD: `"DISPATCH: 10-103M — John flagged for flagrant malcompliance. Designate for observation and detainment."`

Common 10-codes for flavor (use sparingly, keep meaning legible): 10-103 (disturbance),
10-103M (malcompliance), 10-107 (suspicious person), 10-108 (officer needs assistance).

### CWU (Civil Workers Union) — bureaucratic Union register
Officious, paperwork-flavored, euphemistic. The Union is middleware for control.
- Vocabulary: `directive`, `oversight`, `requisition`, `quota`, `allocation`, `licence`,
  `division`, `treasury`, `requisition order`, `compliance`, `the Union programme`.
- Real examples: `"CIVIL WORKFORCE OVERSIGHT"`, `"You need a business license to operate
  this terminal."`, `"Blueprint access approved for %s."`
- Transform:
  - BAD: `"You earned +15 loyalty (tier 3/5)"`
  - GOOD: `"Union oversight notes satisfactory output. Standing under the programme is improved."`

### Citizens — environmental cues only
Citizens are the underclass; they get **no mechanical readouts**. Convey state through the
world: a flickering light, a distant siren, a vague advisory, a sound, a screen-edge tint.
- BAD (to a citizen): `"Your heat is now 60/100."` / `"Cooldown: 30s"`
- GOOD: an ambient scanner ping, a one-line in-world advisory with no numbers, or nothing
  at all — let Combine-side broadcasts carry the consequence.

## Authoring workflow (for helix-inworld-voice)

Given: (a) what mechanically happened, (b) who sees it. Produce:
1. The in-world string in the correct register above.
2. A suggested `sh_english.lua` key (camelCase, plugin-prefixed) if the message is localized,
   e.g. `csDetaineeDesignated = "DISPATCH: 10-103M — ..."`.
3. Note which realm sends it (server `Notify`/`ChatPrint` vs `netstream`) if relevant.

## Quick checklist before shipping a string
- [ ] No raw numbers/scores/tiers/percentages shown to the affected player.
- [ ] No mechanic labels ("heat", "loyalty", "cooldown", "tier").
- [ ] Register matches the audience (dispatch / Union / environmental).
- [ ] Localized via a `sh_english.lua` key if the plugin uses `LANGUAGE`.
