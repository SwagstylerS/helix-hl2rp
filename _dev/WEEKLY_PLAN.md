# Weekly Development Plan
**Week of May 26 – May 30, 2026**
**Goal:** Close citizen-facing feedback loops (curfew visibility, clearance HUD, loyalty HUD), complete the CWU treasury economy with Director payroll, and wire checkpoint warrant alarms into the intel system.

---

## Mon May 25 — Pre-Week
No tasks scheduled — plan begins May 26. No code changes executed.

---

## Day 1 — Mon May 26 · Curfew Visible to Citizens
**Status:** Pending

Goals:
- `plugins/combine-ops/sv_plugin.lua` — in the `curfew` command `OnRun`, change `net.Send(combineAll)` to `net.Send(player.GetAll())` so every player receives `CS_CurfewToggle`; citizens currently accumulate heat from curfew with no awareness — this is the root fix
- `plugins/combine-ops/sv_plugin.lua` — in the `CS_Ops_CurfewSync` `PlayerLoadedCharacter` hook, add a second send block after the existing Combine-only sync: `if !IsCombine(client) then net.Start("CS_CurfewToggle") net.WriteBool(CS.CurfewActive) net.WriteString("SYSTEM") net.Send(client) end` so citizen characters also receive the current curfew state on login
- `plugins/combine-ops/cl_plugin.lua` — in `DrawCurfewBanner()`, replace the blanket early-return guard `if ply:Team() != FACTION_OTA and !ply:IsCombine() then return end` with an if/else branch: Combine players keep the existing bright-red tactical banner; non-Combine players see a muted `Color(180, 60, 60)` text "CURFEW IN EFFECT" drawn at `ScrW()/2, 6` with a fixed alpha of 180 — subdued enough not to overpower the HUD, visible enough to inform RP decisions

---

## Day 2 — Tue May 27 · Citizen Clearance Status HUD
**Status:** Pending

Goals:
- `plugins/combine-terminal/sh_plugin.lua` — add `util.AddNetworkString("CS_ClearanceSync")` inside the existing `if SERVER then` block alongside the other six network strings
- `plugins/combine-terminal/sv_plugin.lua` — add `hook.Add("PlayerLoadedCharacter", "CS_ClearanceOnLoad", function(client, char) local data = char:GetData("cs_clearance") net.Start("CS_ClearanceSync") net.WriteBool(data != nil) net.WriteInt(data and data.expires or 0, 32) net.Send(client) end)` so every character load pushes the current clearance state immediately
- `plugins/combine-terminal/sv_plugin.lua` — at the end of `DoApproveClearance()`, after `char:SetData("cs_clearance", ...)`, send `CS_ClearanceSync` with `WriteBool(true)` and `WriteInt(expires, 32)` to `targetPly` so the HUD activates in real time on approval without requiring a relog
- `plugins/combine-terminal/sv_plugin.lua` — at the end of `DoDenyClearance()`, send `CS_ClearanceSync` with `WriteBool(false)` and `WriteInt(0, 32)` to `targetPly` so the badge disappears immediately on denial
- `plugins/combine-terminal/cl_plugin.lua` — add `local localClearanceExpires = 0`; add `net.Receive("CS_ClearanceSync", function() local active = net.ReadBool() localClearanceExpires = active and net.ReadInt(32) or 0 end)` near existing `net.Receive` blocks; add `hook.Add("HUDPaint", "CS_ClearanceBadge", function() local ply = LocalPlayer() if !IsValid(ply) or ply:IsCombine() then return end if localClearanceExpires <= os.time() then return end local mins = math.ceil((localClearanceExpires - os.time()) / 60) draw.SimpleText("CLEARANCE: ACTIVE — " .. mins .. "m", "CS_Notif", ScrW() - 8, 6, Color(80, 200, 80), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP) end)` to render the badge for non-Combine with active clearance

---

## Day 3 — Wed May 28 · CWU Loyalty Tier Persistent HUD
**Status:** Pending

Goals:
- `plugins/cwu/sv_hooks.lua` — in the existing `PlayerLoadedCharacter` hook, after the character class checks, add `if (client:IsCWU()) then netstream.Start(client, "CWULoyaltySync", {tier = char:GetData("loyaltyTier", 0), points = char:GetData("loyaltyPoints", 0)}) end` to push the worker's loyalty state on every character load
- `plugins/cwu/libs/sh_loyalty.lua` — at the end of `AwardLoyalty()`, inside the existing `if (IsValid(client)) then` block (the one that sends `cwuLoyaltyGained` notification), add `netstream.Start(client, "CWULoyaltySync", {tier = character:GetData("loyaltyTier", 0), points = points})` so the HUD stays in sync in real time whenever loyalty is awarded
- `plugins/cwu/cl_hooks.lua` — add `CWU_LocalTier = 0; CWU_LocalPoints = 0` at the top; add `netstream.Hook("CWULoyaltySync", function(data) CWU_LocalTier = data.tier CWU_LocalPoints = data.points end)`; add `hook.Add("HUDPaint", "CWU_TierBadge", function() local ply = LocalPlayer() if !IsValid(ply) or !ply:IsCWU() then return end local tierInfo = PLUGIN.LoyaltyTiers[CWU_LocalTier] if !tierInfo then return end draw.SimpleText(tierInfo.name .. "  [Tier " .. CWU_LocalTier .. "]  — " .. CWU_LocalPoints .. " pts", "DermaDefault", 10, ScrH() - 20, tierInfo.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM) end)` — renders a color-coded tier badge at the bottom-left corner matching each tier's color from `PLUGIN.LoyaltyTiers`

---

## Day 4 — Thu May 29 · Director Per-Worker Payroll
**Status:** Pending

Goals:
- `plugins/cwu/entities/ix_cwu_director_pc.lua` — add a `netstream.Hook("CWUDirectorPayWorker", function(client, charID, amount) ... end)` block immediately after the existing `CWUDirectorWithdraw` handler: validate `client:IsCWUDirector()`; clamp `amount = math.Clamp(math.floor(tonumber(amount) or 0), 1, 10000)`; early return with `cwuInsufficientTreasury` if `!PLUGIN:WithdrawTreasury(amount)`; iterate `player.GetAll()` to find `character:GetID() == charID`, call `character:GiveMoney(amount)`, log via `PLUGIN:LogTransaction({type="wage", seller="CWU Treasury", buyer=char:GetName(), buyerID=charID, item="wage", itemName="CWU Wage", quantity=1, price=amount, tax=0, terminal="Director Payroll"})`, notify both parties, and break on match; if no match found after the loop, refund via `PLUGIN:AddTreasury(amount)` and notify the director "Target worker is not online."
- `plugins/cwu/derma/cl_cwu_director_pc.lua` — in the Members tab, replace plain `AddLine` roster rows with a row-plus-button pattern: after each member line is added to the listview, create a small "Pay" `DButton` (40px wide, same row height) that on click opens a `DFrame` (220×90) titled "Pay " .. memberName containing a numeric `DTextEntry` (placeholder "Amount") and a Confirm button that calls `netstream.Start("CWUDirectorPayWorker", charID, tonumber(entry:GetValue()) or 0)` then closes both frames
- `plugins/cwu/languages/sh_english.lua` — add `cwuWorkerPaid = "Paid %s %s from the CWU treasury."` and `cwuWageReceived = "You received %s wages from the CWU Director."` at the end of the Director PC section

---

## Day 5 — Fri May 30 · Checkpoint Warrant Crossing Alert
**Status:** Pending

Goals:
- `plugins/checkpoint/entities/ix_checkpoint.lua` — read the entity's `Touch` or `StartTouch` handler; confirm whether the warrant detection path already fires a net alert; if not (expected), add inside the citizen-crossing evaluation block: `local warrants = ix.data.Get("cs_warrants", {}); local sid = ply:SteamID(); if (warrants[sid]) then net.Start("CS_BiometricAlert") net.WriteString("CHECKPOINT — " .. self:GetCheckpointName() .. ": " .. ply:Name() .. " [WANTED — " .. (warrants[sid].reason or "no reason") .. "]") net.WriteUInt(2, 4) net.Send(CS.GetCombinePlayers and CS.GetCombinePlayers() or {}) end` — this uses the existing `CS_BiometricAlert` network string declared in combine-scanner and the intel alert channel already visible in the terminal
- `plugins/checkpoint/entities/ix_checkpoint.lua` — also log the crossing attempt to a rolling `cs_checkpointLog` table (cap at 100 entries) via `ix.data.Set`: each entry contains `{name, sid, checkpoint=self:GetCheckpointName(), time=os.time(), wasWanted=warrants[sid]!=nil, hadClearance=bool}` so Combine can review attempted crossings at the terminal later
- `plugins/combine-terminal/sv_plugin.lua` — in `BuildZoneCheckpointData()`, extend the return table to include `crossingLog = ix.data.Get("cs_checkpointLog", {})` so the terminal's Zones tab can expose recent crossings in a future UI pass; no derma change needed this session — the data plumbing is enough
