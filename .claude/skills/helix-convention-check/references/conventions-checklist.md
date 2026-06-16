# Convention Checklist (detection guide)

Read `_dev/CONVENTIONS.md` first — it is authoritative. This file is the operational
detection guide for the rules in it.

## 1. No chat commands for world interaction — BLOCKER

**Detect:** new `ix.command.Add("Name", { ... OnRun = function(...) ... end })` where the
`OnRun` body does anything other than send chat. World-interaction signals:
- `ents.*`, `entity:*`, `:SetMode`, `:SetNetVar`, `:Remove`, `:Spawn`
- inventory: `:GetInventory()`, `inventory:Add/Remove`
- money: `:GiveMoney`, `:TakeMoney`
- character/world state: `:SetData(...)` for non-cosmetic state, `ix.data.Set`
- teleport / heal / damage / restrain.

**Allowed (not a violation):** `OnRun` whose effect is essentially `ix.chat.Send(...)`,
`client:Notify`-only acknowledgements of a *comms* action, or admin/debug tooling marked
`adminOnly = true` (admin tools are out of the player-facing world model).

**Fix suggestion:** "Move this mechanic onto an entity (`ENT:Use`) or a terminal/menu
action; keep the command only if it is pure communication."

## 2. No gamey text — BLOCKER

**Detect** in any player-facing string:
- digits used as a score/threshold: `(80/100)`, `reached 80`, `+15 points` shown to a
  citizen, `heat score`, `heatScore`, `heatTier`, `tier 4`, `Tier 5`
- countdowns / cooldowns surfaced to the player: `cooldown`, `seconds remaining`, `wait Ns`
- mechanic labels: `PERSON OF INTEREST: <name> — heat score ...`, `loyalty +N`, debug-y
  ALL-CAPS system phrases that describe the *mechanic* rather than the fiction.

**Per-faction rewrite** (use `voice-guide.md`):
- Combine (MPF/OTA, dispatch): 10-codes + "subject/unit/malcompliant/processing/advisory".
- CWU: bureaucratic Union register ("Union directive", "quota", "requisition", "oversight").
- Citizens: environmental cue only — a sound, a light, a vague advisory; never a number.

**Note:** numeric/score columns inside a *Combine-only terminal UI* (the intel database)
are in-world instrument readouts and are acceptable there; the rule targets broadcasts,
notifications, and citizen-facing text. Flag UI numbers only if shown to citizens.

## 3. Networking — prefer netstream — WARNING

- New `net.Start` / `net.Receive` / `util.AddNetworkString` **in plugin code** → WARNING:
  "Prefer `netstream.Start` / `netstream.Hook` (auto-registers, used by cwu)."
- Do NOT flag the established `combine-*` `CS_*` net strings or their existing handlers.
- `netstream` needs no `util.AddNetworkString`; flagging a `util.AddNetworkString` paired
  with new netstream usage is also a WARNING (redundant).

## 4. Entity category — BLOCKER (new entities)

- A new entity file must set `ENT.Category = "HL2 RP"` so it lands under the one Q-menu
  tab. Missing or different category → BLOCKER.
- Also expect `AddCSLuaFile()` at top and `ENT.Type` set.

## 5. Localization presence — WARNING

- Any `NotifyLocalized("key")`, `return "@key"`, or `"@key"` reference must have a matching
  entry in that plugin's `languages/sh_english.lua` `LANGUAGE` table. Missing key → WARNING.
- New hardcoded English in a plugin that already uses `LANGUAGE` keys → NOTE (consider a key).

## 6. Realm correctness — NOTE/WARNING

- `util.AddNetworkString` only inside `if SERVER then`.
- `sv_*` files must not reference client-only globals (`LocalPlayer`, `surface`, `draw`,
  `vgui`, `ScrW/ScrH`); `cl_*` must not call server-only APIs. Mismatch → WARNING.
- Client-loaded entity/derma files need `AddCSLuaFile()` (or be in autoloaded `cl_`/derma).

## Output format

```
BLOCKERS
  plugins/foo/sh_plugin.lua:42 — rule 1 — /detain mutates entity state via a chat command
    → move detain onto the processing terminal's Use action; drop the command.

WARNINGS
  plugins/foo/sv_plugin.lua:88 — rule 3 — new raw net.Start("FooOpen")
    → use netstream.Start(client, "FooOpen", data)

NOTES
  ...

Verdict: 1 blocker, 1 warning, 0 notes.
```
