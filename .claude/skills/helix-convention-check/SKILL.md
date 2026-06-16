---
name: helix-convention-check
description: >-
  Review a Helix HL2RP code change (a diff, a file, or a whole plugin) against this
  schema's design conventions in _dev/CONVENTIONS.md and _dev/DIRECTION.md. Use after
  writing or before committing any plugin / entity / item / command / networking / UI
  code. Checks: no chat commands for world interaction (world mechanics must be
  entities, menus, or terminals — pure communication commands like /alert or /CWURadio
  are allowed); no gamey text (player-facing strings must read in-world — Combine
  dispatch 10-codes, CWU bureaucratic language, citizen environmental cues — never raw
  scores, tiers, cooldowns, or mechanic labels); prefer netstream over new raw net.* in
  plugin code; new entity ENT.Category must be "HL2 RP"; new localized strings exist in
  plugins/<name>/languages/sh_english.lua; sv_/sh_/cl_ realm correctness. Review-only.
---

# Helix HL2RP Convention Check

You audit a change against the server's hard rules. **You do not edit code** unless the
user explicitly asks you to fix findings.

## Procedure

1. **Load the source of truth first.** Read `_dev/CONVENTIONS.md` and `_dev/DIRECTION.md`
   in the repo. These are authoritative and may change — never rely on a memorized copy.
2. **Determine the scope.** If reviewing a diff, run `git diff` (or `git show <ref>`); if
   a file/plugin, read it. Only judge **new or changed** code — established code is not a
   regression (see allowlist below).
3. **Run the checklist** in `references/conventions-checklist.md`. Assign each finding a
   severity: **BLOCKER** (violates a hard rule), **WARNING** (violates a "prefer" rule or
   likely-unintended), **NOTE** (style / minor).
4. **For gamey-text findings,** use `references/voice-guide.md` to both flag the bad
   string and propose an in-world rewrite in the correct faction voice.
5. **Report.** Group findings by severity. Each line: `path:line — <rule> — <what's wrong>`
   then a one-line concrete fix. End with a short verdict (e.g. "2 blockers, 1 warning").

## The two hard rules (most important)

- **No chat commands for world interaction.** A new `ix.command.Add` whose `OnRun`
  mutates world / entity / inventory / money / character state is a BLOCKER — that
  mechanic belongs on an entity, terminal, or menu. *Exception:* commands whose only job
  is to send text (radio/dispatch/comms, e.g. `/CWURadio`, `/alert`) are fine.
- **No gamey text.** Any player-facing string (`Notify`, `NotifyLocalized`, `ChatPrint`,
  `chat.AddText`, derma `SetText`/`draw.*Text`) that exposes a raw number-as-score,
  `/100`, `tier N`, cooldown countdown, percentage, or a mechanic label is a BLOCKER.
  Rewrite it in-world (see voice guide).

## Allowlist — do NOT flag these as new violations

- Existing technical debt named in CONVENTIONS.md: `/panicbutton`, `/panicclear`,
  `/transferdetainee`, `/releasedetainee`, `/curfew`. Note them only if the diff *touches*
  them, framed as "pre-existing debt — candidate to migrate to an entity."
- The `combine-*` plugins' existing raw `net.*` usage and pooled `CS_*` network strings
  (declared in their `sh_plugin.lua` SERVER block). Only flag **newly added** raw `net.*`
  in plugin code as a WARNING suggesting `netstream`.

See `references/conventions-checklist.md` for the full per-rule detection guide.
