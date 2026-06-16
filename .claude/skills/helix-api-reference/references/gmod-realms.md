# GMod Realm & Guard Rules

> Adapted from the community **gmod-addon-maker** skill
> (github.com/davila7/claude-code-templates) — realm/guard rules only, re-grounded for this
> Helix schema. Upstream is MIT-style; see `.claude/skills/THIRD_PARTY.md`.

Garry's Mod runs Lua in three realms. Getting the realm wrong is the most common bug.

| Prefix | Realm | Runs on | Notes |
|--------|-------|---------|-------|
| `sh_`  | Shared | server **and** client | definitions both sides need (items, factions, configs, chat classes) |
| `sv_`  | Server | server only | game logic, persistence, authority |
| `cl_`  | Client | client only | HUD, derma, input, rendering |

## Guards
- `if SERVER then ... end` / `if CLIENT then ... end` to fence realm-specific code inside a
  shared file (entities are shared files: see the `SERVER`/`CLIENT` split in
  `ix_combine_terminal.lua`).
- `util.AddNetworkString(name)` is **server-only** — always inside `if SERVER then`.
  (With `netstream` you don't need it at all.)
- `AddCSLuaFile()` at the top of any file the **client** must download (entities, derma,
  shared files referenced client-side). Missing it = "attempt to index nil" on clients.

## Player references
- **Server:** you receive `client`/`activator`/`ply` as arguments — use those. There is no
  single "local player" on the server.
- **Client:** `LocalPlayer()` is the viewer. Never call `LocalPlayer()` in `sv_` code.
- Validate everything from the network: `if (!IsValid(client) or !client:IsPlayer()) then return end`.

## Rendering / UI
- `surface.*`, `draw.*`, `vgui.*`, `Material`, `ScrW()/ScrH()`, `hook.Add("HUDPaint", ...)`
  are **client-only**. Calling them server-side errors.

## Common GMod errors this prevents
- "Tried to use a NULL entity" → guard `IsValid()` before use.
- client gets "attempt to index nil (global 'ENT')" → missing `AddCSLuaFile()`.
- "attempt to call method 'X' (a nil value)" on `character` → `character` was nil; guard it.
