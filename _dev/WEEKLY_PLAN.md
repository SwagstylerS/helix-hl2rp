# Weekly Development Plan
**Week of Jun 9 – Jun 13, 2026**
**Goal:** Close loyalty incentive gaps across Production and Medical divisions, complete the infrastructure notification loop, and deliver the two remaining Pillar 1 intel gaps — detainee log and clearance audit trail.

---

## Monday Jun 8 — Pre-week note
No tasks scheduled for today. Development week begins Tuesday Jun 9.

---

## Day 1 — Mon Jun 9 · Production Crafting Loyalty + Drug Synthesis Loyalty
**Status:** ✅ Complete

Goals:
- `plugins/cwu/entities/ix_productiontable.lua` — In the `CWUProductionStart` netstream handler (~line 187), inside `timer.Create("CWUCraft_" .. entity:EntIndex(), craftTime, 1, function() ... end)`, after `entity:EmitSound(...)`, add: `if IsValid(client) then local char = client:GetCharacter() if char then PLUGIN:AwardLoyalty(char, 1, "crafting") end end` — awards 1 loyalty point when crafting completes (state transitions to 2); `client` is already captured in the enclosing closure
- `plugins/cwu/entities/ix_medicalworkstation.lua` — In the `CWUMedicalSynthDrug` netstream handler (~line 378), inside the `client:DoStaredAction(entity, function() ... end, ...)` completion callback, after `client:Notify("Synthesis complete: Medical compound produced.")` and before `entity:SetState(0)`, add `PLUGIN:AwardLoyalty(client:GetCharacter(), 1, "synthesis")` — awards 1 loyalty point for illicit compound synthesis, matching the 1-point award already given for legitimate stimpak synthesis (`CWUMedicalSynthMedicine`)
- `plugins/cwu/languages/sh_english.lua` — Confirm `cwuLoyaltyGained` string covers the "crafting" and "synthesis" reason strings, or add `cwuCraftingLoyalty = "Crafting loyalty awarded."` if a distinct message is desired; `cwuLoyaltyGained` already covers both if the award fires through `AwardLoyalty`

---

## Day 2 — Tue Jun 10 · Work Order New-Order Notifications to Maintenance Workers
**Status:** ✅ Complete

Goals:
- `plugins/cwu/libs/sv_workorders.lua` — In `PLUGIN:GenerateWorkOrder(entity)` (line ~15), after `self:RefreshWorkOrderBoards()`, add a loop: `for _, ply in ipairs(player.GetAll()) do if IsValid(ply) and ply:GetCWUDivision() == "maintenance" then netstream.Start(ply, "CWUNewWorkOrder", {type = breakableInfo.type, location = string.format("%d, %d", math.floor(ePos.x), math.floor(ePos.y))}) end end` — notifies every online Maintenance worker when degradation generates a new order
- `plugins/cwu/cl_hooks.lua` — Near the `tierUpData`/`tierUpAt` declarations at the top, add `local newOrderData = nil` and `local newOrderAt = 0`
- `plugins/cwu/cl_hooks.lua` — After the existing `CWUTierUpAnnounce` hook, add `netstream.Hook("CWUNewWorkOrder", function(data) newOrderData = data; newOrderAt = CurTime() end)`
- `plugins/cwu/cl_hooks.lua` — In `PLUGIN:HUDPaint()` (line ~102), after the recreational chemical effect block, add a 6-second HUD banner when `newOrderData ~= nil and (CurTime() - newOrderAt) < 6` and `LocalPlayer():GetCWUDivision() == "maintenance"`: draw a 320×48 panel at `ScrW()/2 - 160, ScrH() - 130` with background `Color(20, 20, 20, 210)` and a 2px green border `Color(100, 175, 100)`; first line "NEW WORK ORDER" in `Color(255, 255, 255)`; second line `"[" .. (newOrderData.type or "?") .. "] — " .. (newOrderData.location or "?")` in `Color(100, 175, 100)`; alpha-fade the last second; clear `newOrderData` when elapsed ≥ 6

---

## Day 3 — Wed Jun 11 · Detainee Log Persistence + Terminal Tab
**Status:** ✅ Complete

Goals:
- `plugins/combine-ops/sv_plugin.lua` — In the `transferdetainee` command `OnRun` (line ~152), after `client:Notify("Transfer logged for " .. targetPly:Name())`, append a persistent entry: `local log = ix.data.Get("cs_detainees", {}); log[#log + 1] = {name = targetPly:Name(), cid = cid, officer = client:Name(), time = os.time()}; while #log > 100 do table.remove(log, 1) end; ix.data.Set("cs_detainees", log)` — caps log at 100 entries, oldest first
- `plugins/combine-terminal/sv_plugin.lua` — In `BuildFullPayload()` (line ~379), add `detainees = ix.data.Get("cs_detainees", {})` to the returned table alongside `records`, `units`, etc.
- `plugins/combine-terminal/derma/cl_tab_detainees.lua` — New file: define `local C = CS_TERM_COLORS` and `local PANEL = {}`; in `PANEL:Populate(data)`, clear and rebuild a `DListView` with columns TIME (80px fixed), NAME (140px), CID (60px fixed), OFFICER (130px); iterate `data.detainees` newest-first (cap at 50 display rows); for entries within the last hour set line text colour to `C.orange`; if `#(data.detainees or {}) == 0` show a `DLabel` "No detainee transfers logged." styled with `C.textDim`; register with `vgui.Register("CS_TabDetainees", PANEL, "Panel")`
- `plugins/combine-terminal/derma/cl_terminalframe.lua` — In `PANEL:Populate()` (line ~98), add `{"DETAINEES", "CS_TabDetainees"}` as the last entry in the `tabs` table so the new tab appears after CLEARANCE in the tab bar

---

## Day 4 — Thu Jun 12 · Clearance Approval History Log
**Status:** ✅ Complete

Goals:
- `plugins/combine-terminal/sv_plugin.lua` — In `DoApproveClearance()` (line ~206), after `ix.data.Set` for the clearance data, append: `local hist = ix.data.Get("cs_clearanceHistory", {}); hist[#hist + 1] = {sid = sid, name = targetPly:Name(), officer = ply:Name(), decision = "APPROVED", time = os.time()}; while #hist > 200 do table.remove(hist, 1) end; ix.data.Set("cs_clearanceHistory", hist)`
- `plugins/combine-terminal/sv_plugin.lua` — Mirror the same append in `DoDenyClearance()` (line ~229) with `decision = "DENIED"` — the existing `AddHeat` and `ClearanceSync` logic stays unchanged
- `plugins/combine-terminal/sv_plugin.lua` — In `BuildFullPayload()`, add `clearanceHistory = ix.data.Get("cs_clearanceHistory", {})` to the returned table
- `plugins/combine-terminal/derma/cl_tab_cwu.lua` — After the existing clearance-requests block (the pending list), add a `DLabel` header "CLEARANCE HISTORY" styled with `C.borderDim`; render a `DListView` with columns TIME (80px), NAME (140px), OFFICER (130px), DECISION (80px); populate from `data.clearanceHistory` newest-first capped at 50 rows; colour APPROVED rows with `C.good` text and DENIED rows with `C.red` text

---

## Day 5 — Fri Jun 13 · Live Blueprint Request Alert for Director PC
**Status:** ✅ Complete

Goals:
- `plugins/cwu/entities/ix_productiontable.lua` — In the `CWURequestBlueprintApproval` netstream handler (line ~241), inside the `for _, v in ipairs(player.GetAll())` Director notification loop, after `v:Notify(...)`, add `netstream.Start(v, "CWUBlueprintRequestAlert", {charName = character:GetName(), blueprintName = bp.name})` so Directors receive a rich client-side event in addition to the plain notify
- `plugins/cwu/derma/cl_cwu_director_pc.lua` — At the bottom of the file before `vgui.Register`, add `netstream.Hook("CWUBlueprintRequestAlert", function(data) surface.PlaySound("buttons/button17.wav") if IsValid(ix.gui.cwuDirectorPC) and IsValid(ix.gui.cwuDirectorPC.blueprintRequestsList) then ix.gui.cwuDirectorPC.blueprintRequestsList:AddLine(data.charName, data.blueprintName, "PENDING") end end)` — plays the alert chime and, if the Director PC panel is currently open, inserts the new request directly into the blueprint requests list without requiring the panel to be closed and reopened
- `plugins/cwu/derma/cl_cwu_director_pc.lua` — Confirm `self.blueprintRequestsList` is the field name used in `PANEL:CreateBlueprintRequestsTab()` (the `DListView` created there) and that it is assigned to `self.blueprintRequestsList`; if the field has a different name, use that name in the hook above
