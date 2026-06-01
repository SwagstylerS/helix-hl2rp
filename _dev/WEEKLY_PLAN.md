# Weekly Development Plan
**Week of Jun 2 – Jun 6, 2026**
**Goal:** Close the final Pillar 1 intel gaps (crossing log UI, zone-entry heat), complete Pillar 3's incentive feedback loop (tier-up visual), and clean up dual-use heat calibration and Director-to-worker notifications.

---

## Day 1 — Mon Jun 2 · Checkpoint Crossing Log in Terminal Zones Tab
**Status:** Pending

Goals:
- `plugins/combine-terminal/derma/cl_tab_zones.lua` — in `PANEL:Populate(data)`, after the existing checkpoints list block (~line 152, before the admin hint), add a spacer and a "CROSSING LOG" header panel styled with `C.borderDim`; render `zoneData.crossingLog` (passed from `BuildZoneCheckpointData()` as `data.zones.crossingLog`) as a `DListView` capped to the last 25 entries (newest first); columns: TIME (80px), CITIZEN (150px), CHECKPOINT (150px), STATUS (90px)
- `plugins/combine-terminal/derma/cl_tab_zones.lua` — per crossing row, set STATUS to `"WANTED"` / `"CLEARED"` / `"SUSPICIOUS"` based on `entry.wasWanted` / `entry.hadClearance`; colour rows red for wanted (`C.red`), green for cleared (`C.good`), amber for suspicious (`C.warn`)
- `plugins/combine-terminal/derma/cl_tab_zones.lua` — add an "empty" panel ("No crossing records.") when `crossingLog` is `nil` or `#crossingLog == 0`, using the same style as the existing "No checkpoints defined." panel
- This directly completes the deferred item from Day 5 of last week ("data plumbing is enough this session — the data plumbing is enough")

---

## Day 2 — Tue Jun 3 · Zone-Entry Heat Accumulation Timer
**Status:** Pending

Goals:
- `plugins/combine-terminal/sv_plugin.lua` — add `CS.ZoneHeatCooldowns = {}` to the STATE block (alongside `CS.HeatScores`, `CS.ScanHistory`); entries are keyed `"sid_zoneidx"` with a Unix timestamp of last application
- `plugins/combine-terminal/sv_plugin.lua` — after the existing `CS_HeatMeeting` timer (~line 629), add `timer.Create("CS_ZoneHeat", 30, 0, function() ... end)` that: (1) reads `local zones = ix.data.Get("cs_zones", {})`; (2) iterates `player.GetAll()` skipping Combine; (3) for each non-Combine player checks if their character has no active clearance (`char:GetData("cs_clearance") == nil or char:GetData("cs_clearance").expires < os.time()`); (4) for each zone where player distance ≤ `zone.radius`, checks cooldown key `sid .. "_" .. i`; (5) if cooldown is absent or expired (120 s), calls `AddHeat(sid, CFG.HeatAmounts.RESTRICT)`, sets cooldown, and saves heat via `ix.data.Set("cs_heatScores", CS.HeatScores)`
- `plugins/combine-terminal/sv_plugin.lua` — inside the same `CS_ZoneHeat` timer, after applying heat, fire `CS_HeatTierChange` to the affected player if their tier advanced (reuse the same tier-change net block used by the scan handler), so the citizen receives the tier-notification HUD added in the May 21 feature

---

## Day 3 — Wed Jun 4 · Loyalty Tier-Up Announcement
**Status:** Pending

Goals:
- `plugins/cwu/libs/sh_loyalty.lua` — in `AwardLoyalty()`, inside the `if (newTier > oldTier)` block (line 49), after the existing `client:NotifyLocalized("cwuTierUp", ...)` call, add `netstream.Start(client, "CWUTierUpAnnounce", {tier = newTier, name = tierInfo.name, r = tierInfo.color.r, g = tierInfo.color.g, b = tierInfo.color.b})` so a richer client-side event fires on advancement
- `plugins/cwu/cl_hooks.lua` — add `local tierUpData = nil; local tierUpAt = 0` near the top; add `netstream.Hook("CWUTierUpAnnounce", function(data) tierUpData = data; tierUpAt = CurTime() end)` near the existing `CWULoyaltySync` hook
- `plugins/cwu/cl_hooks.lua` — in the `CWU_TierBadge` HUDPaint hook, add a 5-second announcement overlay when `tierUpData ~= nil and (CurTime() - tierUpAt) < 5`: draw a centered panel (360 × 60) at `ScrW()/2`, `ScrH()/2 - 80` with background `Color(20, 20, 20, 200)`, tier-coloured border, and two lines — `"TIER ADVANCEMENT"` in white and `tierUpData.name .. " [Tier " .. tierUpData.tier .. "]"` in the tier colour; alpha-fade out in the final second; clear `tierUpData` once elapsed
- `plugins/cwu/cl_hooks.lua` — in the same `CWU_TierBadge` hook, replace the raw `CWU_LocalPoints .. " pts"` text with a mini progress bar (160 × 4 px) drawn just below the tier text: fill ratio = `(CWU_LocalPoints % 10) / 10`, using `Color(100, 175, 100)` on `Color(40, 40, 40)`, so workers can see progress toward the next tier boundary of 10 points per tier

---

## Day 4 — Thu Jun 5 · Scanner Illicit-Item Heat Calibration
**Status:** Pending

Goals:
- `plugins/combine-scanner/sv_plugin.lua` — locate the scan handler where `CFG.DualUseHeat` is applied to flagged items; split flagged items into two sets: `illicit = {"combat_stim", "recreational_chem"}` and `suspicious = {"lockpick", "pistol", "smg1", "radio"}` (read directly from `CFG.FlaggedItems`); apply `CFG.HeatAmounts.SMUGGLE` (10) for illicit items and keep `CFG.DualUseHeat` (8) for merely suspicious items
- `plugins/combine-scanner/sv_plugin.lua` — when an illicit item triggers SMUGGLE heat, fire `net.Start("CS_BiometricAlert")` with message `"SMUGGLE SUSPECTED — " .. targetName .. ": " .. itemDisplayName` and tier byte `3`; broadcast to all Combine (not only seniors), so every officer on duty gets the alert — currently only a scan at tier 3 escalates, but catching illicit goods should always escalate regardless of who did the scan
- `plugins/combine-scanner/sv_plugin.lua` — add `contraItemNames = {combat_stim = "Combat Stimulant", recreational_chem = "Recreational Chemical"}` lookup table near the top of the scan handler to give readable names in the alert instead of raw `uniqueID` strings
- `plugins/combine-scanner/sv_plugin.lua` — after the heat is applied for illicit items, call `ix.data.Set("cs_heatScores", CS.HeatScores)` immediately (the scan handler currently defers persistence to the decay timer; illicit-item heat should be durable on scan)

---

## Day 5 — Fri Jun 6 · Director-to-Worker Assignment Notifications
**Status:** Pending

Goals:
- `plugins/cwu/entities/ix_cwu_director_pc.lua` — in the `CWUDirectorAssign` netstream handler, after the target character's class is set, find the online player via `character:GetPlayer()` and call `targetClient:NotifyLocalized("cwuAssignedTo", division)` if `IsValid(targetClient)`
- `plugins/cwu/entities/ix_cwu_director_pc.lua` — in the `CWUDirectorRemove` netstream handler, find the online player and call `targetClient:NotifyLocalized("cwuRemovedFromCWU")` if online
- `plugins/cwu/entities/ix_cwu_director_pc.lua` — in the `CWUDirectorLicense` netstream handler (line ~204), after the grant or revoke path executes, notify the target character: `targetClient:NotifyLocalized("cwuLicenseGrantedSelf")` on grant, `targetClient:NotifyLocalized("cwuLicenseRevokedSelf")` on revoke — the Director currently sees confirmation but the worker has no feedback
- `plugins/cwu/languages/sh_english.lua` — add four strings at the end of the Director PC section: `cwuAssignedTo = "You have been assigned to the CWU %s division."`, `cwuRemovedFromCWU = "You have been removed from CWU service."`, `cwuLicenseGrantedSelf = "Your business licence has been granted by the Director."`, `cwuLicenseRevokedSelf = "Your business licence has been revoked by the Director."`
