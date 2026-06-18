# CLAUDE.md — helix-hl2rp

A **Half-Life 2 Roleplay schema for Garry's Mod**, built on the [Helix](https://github.com/nebulouscloud/helix)
framework (Lua, ~166 files, 6 plugins). It recreates City 17's occupation through interlocking
mechanical systems (Combine surveillance, CWU economy, loyalty, infrastructure decay).

## Read these first (source of truth)
- `_dev/DIRECTION.md` — vision & the five core pillars. **Do not modify.**
- `_dev/CONVENTIONS.md` — the hard design rules (below). Check before any new mechanic.
- `_dev/WEEKLY_PLAN.md` — the current sprint, day-by-day with acceptance criteria.

## The two hard rules
1. **No chat commands for world interaction.** World mechanics (detain, trade, operate gear,
   panic, curfew…) go through **entities / terminals / menus**, never chat commands.
   *Exception:* pure communication commands (radio/dispatch, e.g. `/CWURadio`, `/alert`) are fine.
2. **No gamey text.** Player-facing strings must read **in-world** — Combine dispatch 10-codes,
   CWU bureaucratic language, citizens get environmental cues only. Never expose raw scores,
   tier numbers, cooldowns, percentages, or mechanic labels.

## Layout & conventions cheat-sheet
- **Realms:** `sh_` shared · `sv_` server · `cl_` client. GMod Lua style uses `!`, `!=`, `&&`, `||`.
- **Plugin layouts vary and are all valid:** `cwu`/`writing` use `sh_plugin.lua` +
  `sv_hooks.lua`/`cl_hooks.lua`; `combine-*` use `sh_plugin.lua` + `sv_plugin.lua`/`cl_plugin.lua`;
  `checkpoint` uses `sh_plugin.lua` only. Match the plugin you're editing.
- **Networking:** prefer `netstream.Start`/`netstream.Hook` (auto-registers; used by `cwu`).
  The `combine-*` plugins use legacy raw `net.*` + pooled `CS_*` strings — only mirror that
  when extending them.
- **Autoloaded dirs (no `ix.util.Include`):** `items/`, `entities/`, `schema/factions/`,
  `schema/classes/`, `languages/`.
- **Entities:** `ENT.Category = "HL2 RP"`, `AddCSLuaFile()`, gate `ENT:Use` with distance +
  the meta helpers (`ply:IsCombine()`, `:IsCWU()`, …) in `schema/meta/sh_player.lua`.
- **Persistence:** `ix.data.Set/Get`; character: `:GetData/:SetData`, `:GiveMoney/:TakeMoney`.
- **Localization:** `plugins/<name>/languages/sh_english.lua` (`LANGUAGE` table); reference via
  `NotifyLocalized("key")` or `"@key"`.
- No CI / lint config / build system exists; deployment is a manual Helix schema install.

## Git
Work is committed **directly to `master`** for this effort (per the owner). Commit style:
lowercase, `feat:`/`fix:`/`chore:`/`plan:`, emoji-free, descriptive.

## Project skills (in `.claude/skills/`)
Prefer these — they encode the rules above:
- **helix-convention-check** — audit a diff/file against `_dev/CONVENTIONS.md` before committing.
- **helix-scaffold** — generate a new plugin / entity / item / faction-class / netstream message.
- **helix-api-reference** — Helix `ix.*` + GMod API signatures (don't guess).
- **helix-sprint-executor** — implement the next Pending day of `_dev/WEEKLY_PLAN.md`.
- **helix-inworld-voice** — write player-facing text in the correct faction voice.
- **helix-lint** — run glualint (if installed) on changed Lua.
- Vendored: **ponytail** (do-less / YAGNI gate), **council-review** (Karpathy LLM-Council /
  DMAD multi-perspective design review), **stop-slop** (strip AI tells from prose).
  See `.claude/skills/THIRD_PARTY.md`.

## Mandatory: ponytail for any code discussion or change
**Run `/ponytail` before writing, editing, or discussing any Lua code** — this includes bug
fixes, sprint tasks, new features, design questions, code review, and "how would I…" questions.
No exceptions. Ponytail scopes the minimal correct approach first; only proceed with what it
approves. This applies in both interactive and autonomous (scheduled) sessions.
