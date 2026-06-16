# Repo-specific meta helpers & globals

Reuse these — do not re-derive faction/class checks inline.

## Player meta helpers
Defined in `schema/meta/sh_player.lua` and `plugins/cwu/sh_plugin.lua`:

| Helper | Returns | Notes |
|--------|---------|-------|
| `ply:IsCombine()` | bool | `Team() == FACTION_MPF or FACTION_OTA` |
| `ply:IsDispatch()` | bool | OTA, or MPF with rank SCN/DvL/SeC (via `Schema:IsCombineRank`) |
| `ply:IsCWU()` | bool | any CWU class (unassigned, production, maintenance, medical, commerce, director) |
| `ply:IsCWUDirector()` | bool | class == `CLASS_CWU_DIRECTOR` |
| `ply:GetCWUDivision()` | string/nil | "production"/"maintenance"/"medical"/"commerce"/"director"/"unassigned" |

There is also a `CS.*` module table in the `combine-*` plugins exposing things like
`CS.IsCombine(ply)`, `CS.IsSenior(ply)`, `CS.GetCombinePlayers()`,
`CS.FindPlayerBySteamID(sid)`, `CS.BuildFullPayload()`, and `CS.HeatScores`. When extending
a `combine-*` plugin, use those rather than new globals.

## Faction globals
`FACTION_CITIZEN`, `FACTION_CWU`, `FACTION_MPF`, `FACTION_OTA`, plus an administrator faction.
Each is set as `FACTION_X = FACTION.index` at the bottom of `schema/factions/sh_*.lua`.

## Class globals
`CLASS_CITIZEN`, `CLASS_CWU`, `CLASS_CWU_PRODUCTION`, `CLASS_CWU_MAINTENANCE`,
`CLASS_CWU_MEDICAL`, `CLASS_CWU_COMMERCE`, `CLASS_CWU_DIRECTOR`, and the metropolice /
overwatch classes. Set as `CLASS_X = CLASS.index` at the bottom of `schema/classes/sh_*.lua`.

## Schema helpers
- `Schema:ZeroNumber(n, width)` — zero-pad an id (used for CID generation).
- `Schema:IsCombineRank(name, code)` — rank-tag check against a player name.
- `Schema:SaveCheckpoints()` — persist checkpoint entities (used by the checkpoint plugin).

## Persistence keys in use
`cs_detainees`, `ix_checkpoints_<map>`, CWU treasury/transaction keys — search before
inventing a new `ix.data` key for the same concept.
