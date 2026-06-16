---
name: helix-scaffold
description: >-
  Scaffold new Helix HL2RP schema artifacts following this repo's exact file-realm and API
  conventions. Use when adding a new plugin, a new interactive entity (preferred over chat
  commands for any world mechanic), a new item, a new faction or class, or a new netstream
  message. Generates sh_/sv_/cl_ files in the right layout, sets entity ENT.Category to
  "HL2 RP", wires localized strings into plugins/<name>/languages/sh_english.lua, uses
  netstream for new plugin networking, and honors the no-chat-commands-for-world-interaction
  and no-gamey-text rules. After generating, recommends running helix-convention-check.
---

# Helix HL2RP Scaffold

Generate new schema artifacts that match this codebase exactly. This is a **router**:
pick the artifact, load the matching reference, follow its template.

## Procedure

1. **Read `_dev/CONVENTIONS.md`** and `_dev/DIRECTION.md` first.
2. **Pick the artifact** and open the reference:
   - New plugin → `references/plugin.md`
   - Interactive entity (the default for world mechanics) → `references/entity.md`
   - Item → `references/item.md`
   - Faction or class → `references/faction-class.md`
   - Netstream message → `references/netstream.md`
3. **Match the surrounding family.** Layouts vary in this repo and that is fine — see below.
   Do not "normalize" a plugin's style; match its neighbors.
4. **Generate files** in the correct directory with the correct realm prefix.
5. **Wire localization**: any player-facing text gets a key in
   `plugins/<name>/languages/sh_english.lua` (`LANGUAGE` table). Author the text in-world
   using the `helix-convention-check/references/voice-guide.md` register.
6. **Recommend** running `helix-convention-check` on the result.

## Repo layout facts (verified — do not fight these)

- **Plugin file layouts are mixed and all valid:**
  - `cwu`, `writing`: `sh_plugin.lua` + `sv_hooks.lua` + `cl_hooks.lua`
  - `combine-ops`, `combine-scanner`, `combine-terminal`: `sh_plugin.lua` + `sv_plugin.lua` + `cl_plugin.lua`
  - `checkpoint`: `sh_plugin.lua` only (it includes its own entity/hooks)
  Choose the style of the plugin you are extending; for a brand-new standalone plugin,
  default to the `sh_plugin` + `sv_hooks` + `cl_hooks` style (cleanest).
- **`items/` and `entities/` directories autoload** — never add `ix.util.Include` for files
  in them. You DO include `libs/*.lua` and the hook/plugin files from `sh_plugin.lua`.
- **Networking:** new plugins use `netstream.Start`/`netstream.Hook` (no
  `util.AddNetworkString`). The `combine-*` plugins use legacy raw `net.*` + pooled `CS_*`
  strings — only mirror that if you are extending one of those plugins.
- **Naming:** `sh_` shared, `sv_` server, `cl_` client. GMod Lua style in this repo uses
  `!`, `!=`, `&&`, `||` (not `not`/`~=`/`and`/`or`) — match it.
- **Reusable helpers exist** — use them, don't reinvent: `playerMeta:IsCombine()`,
  `:IsDispatch()`, `:IsCWU()`, `:IsCWUDirector()`, `:GetCWUDivision()`
  (`schema/meta/sh_player.lua`, `plugins/cwu/sh_plugin.lua`). See `helix-api-reference`.
