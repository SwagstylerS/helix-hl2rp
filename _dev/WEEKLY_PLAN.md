# Weekly Development Plan
**Week of May 4 – May 8, 2026**
**Goal:** Close the remaining Combine Intelligence gaps and complete the dual-use tension loop — scanner quotas, clearance persistence, checkpoint save/load, and illicit item detection.

---

## Day 1 — Mon May 4 · Scanner Scan Quotas

**Status:** ✅ Complete

Goals:
- `plugins/combine-scanner/sv_plugin.lua` — add `CS.ScanQuotas = CS.ScanQuotas or {}`; load persisted quotas from `ix.data.Get("cs_scanQuotas", {})` in `InitPostEntity`; in the `scansubject` handler, before the battery check, read the officer's daily quota entry `{count, day}`, block with `"DAILY QUOTA REACHED"` if `count >= 20` (config value), otherwise increment and save; add `timer.Create("CS_QuotaReset", 60, 0, ...)` that checks `os.date("%Y%m%d")` against each entry's `day` and zeroes stale entries
- `plugins/combine-scanner/sv_plugin.lua` — add `/scanquota` command (Combine only) that prints `"QUOTA: %d / %d SCANS TODAY"` using the officer's current entry
- `plugins/combine-scanner/sh_plugin.lua` — add `util.AddNetworkString("CS_QuotaSync")`
- `plugins/combine-scanner/sv_plugin.lua` — after each scan (and on `PlayerLoadedCharacter` for Combine), send `net.Start("CS_QuotaSync") net.WriteUInt(count, 8) net.WriteUInt(max, 8) net.Send(client)` so the HUD stays accurate
- `plugins/combine-scanner/cl_plugin.lua` — add `net.Receive("CS_QuotaSync", ...)` storing `CS.LocalQuotaCount` and `CS.LocalQuotaMax`; in the existing `HUDPaint` scanner display, add a second line `"QUOTA: %d / %d"` drawn below the battery bar
- `plugins/combine-terminal/sv_plugin.lua` — extend `BuildActiveUnits()` to include `scanCount = (CS.ScanQuotas[ply:SteamID()] or {}).count or 0` on each unit entry
- `plugins/combine-terminal/derma/cl_tab_units.lua` — add a `"Scans"` column to the `DListView` and populate it from the `scanCount` field

---

## Day 2 — Tue May 5 · Recreational Chemical Client Visual Effect

**Status:** ✅ Complete

Goals:
- `plugins/cwu/cl_hooks.lua` — add `netstream.Hook("CWURecreationalEffect", function(duration) PLUGIN.ChemEffectEnd = CurTime() + duration end)` to receive the server-dispatched event
- `plugins/cwu/cl_hooks.lua` — add `PLUGIN:PostRenderVGUI()` (or `HUDPaint`) hook: if `PLUGIN.ChemEffectEnd` is set and `CurTime() < PLUGIN.ChemEffectEnd`, call `DrawMotionBlur(0.06, 0.6, 1/60)` and draw a 12%-alpha green-tinted rect over the full screen (`surface.SetDrawColor(40, 200, 80, 30); surface.DrawRect(0, 0, ScrW(), ScrH())`); clear `PLUGIN.ChemEffectEnd` when expired
- `plugins/cwu/items/crafted/sh_recreational_chem.lua` — verify the `OnRun` passes `return false` to consume the item (already present); confirm `netstream.Start(client, "CWURecreationalEffect", 60)` uses the correct duration (60 seconds)
- `plugins/cwu/items/crafted/sh_cwu_supplement.lua` — check if this item has an `OnRun` function; if missing, add one mirroring bandage: `client:SetHealth(math.min(client:Health() + 15, client:GetMaxHealth())); client:EmitSound("items/medshot4.wav"); return false`
- `plugins/cwu/languages/sh_english.lua` — verify the `cwuChemEffect` string exists; add if missing: `"The haze washes over your senses."`

---

## Day 3 — Wed May 6 · Checkpoint Individual Clearance Integration

**Status:** Pending

Goals:
- `plugins/combine-terminal/sv_plugin.lua` — in `DoApproveClearance`: after sending `CS_ClearanceResult` and clearing `CS.CWURequests[sid]`, find the target's online character and call `character:SetData("cs_clearance", {level = 1, expires = os.time() + CFG.ClearanceExpiry})`; guard with `if IsValid(targetPly) then local char = targetPly:GetCharacter(); if char then ... end end`
- `plugins/combine-terminal/sv_plugin.lua` — in `DoDenyClearance`: after sending the deny message, clear the flag: `local char = targetPly:GetCharacter(); if char then char:SetData("cs_clearance", nil) end`
- `plugins/combine-terminal/sv_plugin.lua` — add `timer.Create("CS_ClearanceDecay", 120, 0, function() ... end)` that iterates `player.GetAll()`, reads each character's `cs_clearance` data, and calls `char:SetData("cs_clearance", nil)` for entries where `data.expires < os.time()`
- `plugins/checkpoint/entities/entities/ix_checkpoint.lua` — extend `HasClearance(client, mode)`: after the `MODE_YELLOW` CWU faction check, add a second branch that returns `true` if `character:GetData("cs_clearance") ~= nil` and `character:GetData("cs_clearance").expires > os.time()` — this allows individually-approved citizens through yellow checkpoints without being in the CWU faction
- `plugins/checkpoint/entities/entities/ix_checkpoint.lua` — in `CheckWarrant`, the warrant check already runs before `HasClearance` in `ShouldCollide`, so warranted citizens with a clearance flag are still correctly blocked (no change needed there)

---

## Day 4 — Thu May 7 · Checkpoint Entity Persistence

**Status:** Pending

Goals:
- `plugins/checkpoint/sh_plugin.lua` — define `Schema.SaveCheckpoints` in the shared plugin scope: iterate `ents.FindByClass("ix_checkpoint")`, build a table of `{pos, angles, name, mode}` for each valid entity, and write via `ix.data.Set("ix_checkpoints_" .. game.GetMap(), data)`; this makes the function available globally since Helix evaluates shared plugin files on both realms
- `plugins/checkpoint/sh_plugin.lua` — define `Schema.LoadCheckpoints`: read `ix.data.Get("ix_checkpoints_" .. game.GetMap(), {})` and, for each saved entry, `ents.Create("ix_checkpoint")`, set pos/angles, `Spawn()`, `Activate()`, then `entity:SetCheckpointName(entry.name)` and `entity:SetMode(entry.mode)`; mark each restored entity with `entity.ixIsSafe = true` so `OnRemove` doesn't overwrite the save
- `plugins/checkpoint/sh_plugin.lua` — add `hook.Add("InitPostEntity", "ix_checkpoint_load", function() timer.Simple(1, Schema.LoadCheckpoints) end)` (server only, guarded with `if SERVER then`) so checkpoints respawn after map load with their last saved mode and name
- `plugins/checkpoint/entities/entities/ix_checkpoint.lua` — in `ENT:SpawnFunction`, after `Schema:SaveCheckpoints()`, confirm the returned entity is not nil before saving (already the case); verify `ENT.bNoPersist = true` remains so Helix's own persistence layer doesn't double-spawn

---

## Day 5 — Fri May 8 · Dual-Use Item Scanner Detection

**Status:** Pending

Goals:
- `plugins/combine-scanner/sv_plugin.lua` — extend `CFG.FlaggedItems` to include `"combat_stim"` and `"recreational_chem"` so `GetRestrictedItems` picks up dual-use compounds; add `CFG.DualUseHeat = 8` (less than `SMUGGLE = 10` since these carry plausible deniability)
- `plugins/combine-scanner/sv_plugin.lua` — in the `scansubject` handler, after building `restricted` and `contraStr`, check each detected item's `isDualUse` flag via `ix.item.list[uid] and ix.item.list[uid].isDualUse`; if any dual-use items found, call `AddHeat(sid, CFG.DualUseHeat)` and prefix `contraStr` with `"MEDICAL COMPOUND: "` to preserve the plausible-deniability framing from DIRECTION.md
- `plugins/combine-scanner/sv_plugin.lua` — ensure dual-use items found in the inventory do NOT appear verbatim as their item name in the scan result; instead always label them `"Medical Compound"` in `contraStr` (replace the raw `item.name` lookup for `isDualUse` items with the string literal `"Medical Compound"`)
- `plugins/combine-terminal/sv_plugin.lua` — in `CFG.FlaggedItems` (the identical list used by the terminal for live inventory checks), add `"combat_stim"` and `"recreational_chem"` to match the scanner's flagging behaviour
- `plugins/cwu/items/crafted/sh_combat_stim.lua` — confirm `ITEM.isDualUse = true` is set (already present); no change needed
- `plugins/cwu/items/crafted/sh_recreational_chem.lua` — confirm `ITEM.isDualUse = true` is set (already present); no change needed
- `plugins/cwu/languages/sh_english.lua` — add string `cwuDualUseCarried = "MEDICAL COMPOUND DETECTED"` for potential future HUD use
