---
name: helix-api-reference
description: >-
  Authoritative reference for the Helix framework (ix.*) and Garry's Mod Lua APIs used in
  this HL2RP schema. Use BEFORE writing Helix/GMod code, or whenever unsure about a call,
  so you do not guess signatures. Covers ix.util.Include, ix.config.Add, ix.command.Add,
  ix.chat.Register/Send, ix.item, ix.data.Set/Get, ix.flag, character meta
  (GetData/SetData, GiveMoney/TakeMoney, GetClass/JoinClass), this schema's player meta
  helpers (IsCombine/IsDispatch/IsCWU/IsCWUDirector/GetCWUDivision), netstream vs raw net,
  entity NetworkVar/Use/Draw/HUDPaint, and GMod realm rules (sh_/sv_/cl_, AddCSLuaFile,
  SERVER/CLIENT guards, LocalPlayer vs client).
---

# Helix / GMod API Reference

Don't guess Helix or GMod signatures — consult the references here, each anchored to a real
usage in this repo.

- `references/ix-api.md` — the `ix.*` surface (config, command, chat, item, data, flag,
  character/player meta) with one canonical example each.
- `references/gmod-realms.md` — GMod realm and guard rules (SERVER/CLIENT, AddCSLuaFile,
  LocalPlayer vs client). Adapted from the community gmod-addon-maker skill (attributed).
- `references/repo-meta-helpers.md` — this schema's own player/character helpers and the
  `FACTION_*` / `CLASS_*` globals, with file locations — use these instead of reinventing.

## Fast gotchas (read first)
- **GMod Lua style here:** `!`, `!=`, `&&`, `||` (not `not`/`~=`/`and`/`or`). Match it.
- **`netstream` auto-registers** message names — no `util.AddNetworkString`. Only the
  `combine-*` plugins use raw `net.*` + pooled `CS_*` strings.
- **`ix.config.Add` needs an options table** with a `category`, and `data = {min, max}` for
  numeric configs.
- **`character` can be nil** — always guard `local char = client:GetCharacter(); if (!char) then return end`.
- **Autoloaded dirs:** `items/`, `entities/`, `schema/factions/`, `schema/classes/`,
  `languages/` — never `ix.util.Include` files in these.
- **`@key`** in a returned command string or `NotifyLocalized("key")` resolves against the
  `LANGUAGE` table in `languages/sh_english.lua`.
