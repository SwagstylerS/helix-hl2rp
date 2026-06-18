# Weekly Development Plan
**Week of Jun 15 – Jun 19, 2026**
**Goal:** Close remaining Pillar 1 intel/enforcement loops (heat-tier escalation alerts, detainee release lifecycle, curfew checkpoint lockdown) and extend the Commerce/Loyalty loop with vendor stock alerts and a Union Exemplar tax perk.

---

## Day 1 — Mon Jun 15 · Heat Tier 4 "Person of Interest" Alert to Combine
**Status:** ✅ Done

- Added `CS_BiometricAlert` broadcast (priority 1) + `ChatPrint` to all Combine players when a citizen's heat crosses into Tier 4, in `AddHeat()`.
- Fixed a pre-existing forward-reference bug: `FindPlayerBySteamID`/`GetCombinePlayers` were defined after `AddHeat` but called from within it, causing a nil-call error whenever a heat tier changed. Moved both definitions above `AddHeat` and removed the now-duplicate later definitions.
- `heatTier`/`heatScore` fields in `BuildFullPayload()` were already populated — no change needed there.

Goals:
- `plugins/combine-terminal/sv_plugin.lua` — In the local `AddHeat(sid, amount)` function (~line 82), the existing tier-up block only sends `CS_HeatTierChange` to the citizen themselves. After that block, when `newTier == 4 and oldTier < 4`, also resolve the player via `FindPlayerBySteamID(sid)` and their character, then broadcast a `CS_BiometricAlert` to `GetCombinePlayers()` with a message formatted like `"PERSON OF INTEREST: " .. name .. " (CID:" .. cid .. ") — heat score reached critical levels (" .. CS.HeatScores[sid] .. "/100)"` and `net.WriteUInt(1, 4)` for the priority byte (matching the existing alert pattern used by `DoIssueWarrant` and `TriggerWarrantAlarm`)
- `plugins/combine-terminal/sv_plugin.lua` — Also `ChatPrint` the same message to each Combine player in `GetCombinePlayers()` so it's visible without opening the terminal, consistent with how checkpoint warrant alarms notify Combine via chat
- No new persistence needed — the DATABASE tab (`cl_tab_database.lua`) already exposes a "HIGH HEAT" filter and per-record `heatTier`/`heatScore` columns, so the alert is the missing real-time notification piece; verify the existing `heatTier`/`heatScore` fields are populated in `BuildFullPayload()`'s `records` table (they already are per `GetHeatTier`/`CS.HeatScores` usage at ~line 291-292)

---

## Day 2 — Tue Jun 16 · Detainee Release Command + Status Tracking
**Status:** ✅ Done

Goals:
- `plugins/combine-ops/sv_plugin.lua` — In the `transferdetainee` command `OnRun` (~line 152), add `status = "DETAINED"` to the log entry table that's appended to `cs_detainees` (alongside `name`, `cid`, `officer`, `time`)
- `plugins/combine-ops/sv_plugin.lua` — Add a new command `releasedetainee` (mirrors `transferdetainee`: `description`, `arguments = {ix.type.character}`, `IsCombine(client)` check, target must be online via `target:GetPlayer()`). `OnRun`: load `cs_detainees`, scan from the end (`for i = #log, 1, -1`) for the most recent entry where `entry.cid == target:GetID() and entry.status == "DETAINED"`, set `entry.status = "RELEASED"`, `entry.releasedBy = client:Name()`, `entry.releaseTime = os.time()`, then `ix.data.Set("cs_detainees", log)`. If no matching entry is found, `client:Notify("No active detention found for this citizen.")` and return. On success, broadcast `CS_BiometricAlert` to `GetCombinePlayers()` with `"DETAINEE RELEASED: " .. targetPly:Name() .. " (CID:" .. cid .. ") — " .. client:Name()` and priority `net.WriteUInt(0, 4)`, plus `client:Notify("Release logged for " .. targetPly:Name())`
- `plugins/combine-terminal/sv_plugin.lua` — No change needed: `BuildFullPayload()` already returns `detainees = ix.data.Get("cs_detainees", {})` (added June 11), so the new `status`/`releasedBy`/`releaseTime` fields flow through automatically
- `plugins/combine-terminal/derma/cl_tab_detainees.lua` — In `PANEL:Populate()` (~line 32), add a `STATUS` column (`SetWidth(80):SetFixedWidth(true)`) after `OFFICER` in the `DListView`; populate each row with `entry.status or "DETAINED"`; colour rows where `status == "DETAINED"` using `C.red`, and rows where `status == "RELEASED"` using `C.good` (override the existing `< 3600s` orange highlight logic so status colour takes priority over the recency colour)

---

## Day 3 — Wed Jun 17 · Vendor Terminal Out-of-Stock Alert to Owner
**Status:** ✅ Done

- **Design change from the original goals:** dropped the push HUD banner — a CWU worker
  shouldn't "magically" receive a screen notification (gamey, and it bypasses the
  entity/terminal interaction model). Instead, vendor stock is **checkable in-world on the
  CWU Director PC**, via a new "Commerce Inventory Oversight" tab.
- `plugins/cwu/entities/ix_cwu_director_pc.lua` — `ENT:Use` now enumerates
  `ents.FindByClass("ix_vendorterminal")` and includes a `vendorTerminals` list (name, owner,
  ownerCharID, stockCount, earnings) in the existing `CWUDirectorPCOpen` netstream payload.
- `plugins/cwu/derma/cl_cwu_director_pc.lua` — added `CreateVendorStockTab()` /
  `PopulateVendorStock()` (registered in `Init`/`SetData`): a DListView of Terminal /
  Operator / Stock / Status / Earnings. Status is `DEPLETED` / `LOW` (≤2) / `STOCKED`;
  depleted rows are tinted red and low rows amber so the Director can spot terminals needing
  a restock at a glance. Stock counts here are an in-world instrument readout on a faction
  oversight terminal — not a player-facing score — so it stays within CONVENTIONS.
- The vendor terminal owner already sees their own stock via the existing `CWUVendorManage`
  panel (`ENT:Use` on their terminal), so no per-owner notification is needed.
- `cl_hooks.lua` left untouched (the originally-planned out-of-stock banner was not added).

Original goals (superseded by the above):
- `plugins/cwu/entities/ix_vendorterminal.lua` — In the `CWUVendorPurchase` netstream handler (~line 242), after `table.remove(stock, stockIndex)` and `entity:SetNetVar("stock", stock)`, check if `#stock == 0`. If so, and `entity:GetOwnerCharID() > 0`, loop `player.GetAll()` to find the owner (same pattern as the loyalty-award loop just below it) and `netstream.Start(ownerPly, "CWUVendorOutOfStock", {terminalName = entity:GetNWString("TerminalName", "Vendor Terminal")})` — only fires while the owner is online
- `plugins/cwu/cl_hooks.lua` — Near the top with `newOrderData`/`newOrderAt` (~line 9), add `local outOfStockData = nil` and `local outOfStockAt = 0`
- `plugins/cwu/cl_hooks.lua` — After the `CWUNewWorkOrder` hook (~line 25), add `netstream.Hook("CWUVendorOutOfStock", function(data) outOfStockData = data; outOfStockAt = CurTime() end)`
- `plugins/cwu/cl_hooks.lua` — In `PLUGIN:HUDPaint()` (~line 110), after the `newOrderData` banner block, add a parallel 6-second banner (reuse the same 320×48 panel layout, positioned at `ScrH() - 130 - 56` so it stacks above the work-order banner if both are active) with a red/orange border `Color(200, 140, 60)`; first line "VENDOR OUT OF STOCK"; second line `(outOfStockData.terminalName or "Vendor Terminal") .. " has sold out — restock to resume sales."`; clear `outOfStockData` after 6 seconds, same fade-out as the work order banner

---

## Day 4 — Thu Jun 18 · Union Exemplar (Tier 5) Vendor Tax Discount
**Status:** ✅ Done

- Added `ix.config.Add("cwuModelCitizenTaxDiscount", 50, ...)` in `sh_plugin.lua` alongside `cwuTaxRate`.
- In `CWUVendorPurchase`, hoisted owner character lookup to before the tax calculation. If the owner's `loyaltyTier == 5`, the effective tax rate is multiplied by `(1 - discount/100)` — a 50% default reduction (configurable).
- Eliminated the now-duplicate second `player.GetAll()` loop; reuses the same `ownerChar` for `PLUGIN:AwardLoyalty`. The `sellerID` log field now uses the hoisted `ownerCharID` local instead of a redundant `entity:GetOwnerCharID()` call.
- Silent economic perk — no new player-facing strings; reflects only in the seller's earnings total and the transaction log's `tax` column.

Goals:
- `plugins/cwu/sh_plugin.lua` — Near the existing `ix.config.Add("cwuTaxRate", 10, ...)` (~line 20), add `ix.config.Add("cwuModelCitizenTaxDiscount", 50, "Percentage reduction to vendor tax for Tier 5 (Union Exemplar) sellers.", nil, {category = "CWU"})`
- `plugins/cwu/entities/ix_vendorterminal.lua` — In `CWUVendorPurchase` (~line 242), the existing loyalty-award loop after the sale (`for _, v in ipairs(player.GetAll())` matching `ownerChar:GetID() == ownerCharID`) only runs *after* tax/earnings are computed. Restructure so this owner lookup happens **before** the `taxRate` calculation (~line 268), storing the found `ownerChar` (may be `nil` if owner offline). Then compute `taxRate`: if `ownerChar and ownerChar:GetData("loyaltyTier", 0) == 5`, apply `taxRate = taxRate * (1 - ix.config.Get("cwuModelCitizenTaxDiscount", 50) / 100)`, else use the normal `ix.config.Get("cwuTaxRate", 10) / 100`
- `plugins/cwu/entities/ix_vendorterminal.lua` — Reuse the already-found `ownerChar` for the existing `PLUGIN:AwardLoyalty(ownerChar, 1, "sale")` call (~line 308), removing the now-duplicate second `player.GetAll()` loop
- `plugins/cwu/languages/sh_english.lua` — No new strings required; this is a silent economic perk reflected only in the seller's `earnings` total and the transaction log's `tax` column

---

## Day 5 — Fri Jun 19 · Curfew Checkpoint Auto-Lockdown
**Status:** ✅ Done

Goals:
- `plugins/combine-ops/sv_plugin.lua` — In the `curfew` command `OnRun` (~line 131), after toggling `CS.CurfewActive`, iterate `ents.FindByClass("ix_checkpoint")`. When curfew is being **activated** (`CS.CurfewActive == true`), for each valid checkpoint store its current mode in a module table `CS.CheckpointPreCurfewModes[entity:EntIndex()] = entity:GetMode()` (init this table near the other `CS.*` state tables ~line 17-19) and then `entity:SetMode(3)` (mode 3 = RED/"CP-OTA only", per `plugins/checkpoint/entities/entities/ix_checkpoint.lua` `MODE_RED`)
- `plugins/combine-ops/sv_plugin.lua` — When curfew is being **lifted** (`CS.CurfewActive == false`), for each checkpoint restore `entity:SetMode(CS.CheckpointPreCurfewModes[entity:EntIndex()] or 1)` (default to 1 = GREEN if no stored value), then clear `CS.CheckpointPreCurfewModes`
- `plugins/combine-ops/sv_plugin.lua` — After adjusting checkpoint modes, broadcast a `ChatPrint` to `GetAllCombine()`: `"[CURFEW] All checkpoints set to LOCKDOWN (RED)."` on activation, or `"[CURFEW] Checkpoint lockdown lifted — modes restored."` on deactivation
- `plugins/checkpoint/entities/entities/ix_checkpoint.lua` — No code change needed: `SetMode`/`GetMode` are already generated by `NetworkVar("Int", 0, "Mode")` and the client-side `Draw`/`HUDPaint` and `ShouldCollide` hooks already react to `GetMode()` changes; also call `Schema:SaveCheckpoints()` is not required here since mode changes from curfew are transient and should not persist across map restarts (unlike admin-set modes via `ENT:Use`)

---
