# Weekly Development Plan
**Week of May 18 – May 22, 2026**
**Goal:** Harden Combine Intelligence across server restarts, add Combine radio RP, and close the remaining Medical division synthesis and treatment gaps.

---

## Day 1 — Mon May 18 · Heat Score and Scan History Persistence

**Status:** ✅ Complete

Goals:
- `plugins/combine-terminal/sv_plugin.lua` — add `hook.Add("InitPostEntity", "CS_Heat_Load", function() CS.HeatScores = ix.data.Get("cs_heatScores", {}); CS.ScanHistory = ix.data.Get("cs_scanHistory", {}) end)` immediately after the `CS.HeatScores = CS.HeatScores or {}` state block; this is the primary gap — both tables currently live only in memory and are wiped on every server restart
- `plugins/combine-terminal/sv_plugin.lua` — in the existing `CS_HeatDecay` timer, add `ix.data.Set("cs_heatScores", CS.HeatScores)` after the decay loop closes; the timer already runs every `CFG.HeatDecayRate` seconds so this piggybacks persistence onto the existing cycle with no extra overhead
- `plugins/combine-terminal/sv_plugin.lua` — in the `scansubject` handler, after `table.remove(history, 1)` (the trim that caps history at 50), add `ix.data.Set("cs_scanHistory", CS.ScanHistory)` so the intel board's citizen records survive restarts
- `plugins/combine-terminal/sv_plugin.lua` — add `hook.Add("MapShutdown", "CS_Heat_FlushSave", function() ix.data.Set("cs_heatScores", CS.HeatScores); ix.data.Set("cs_scanHistory", CS.ScanHistory) end)` to flush both datasets on a clean server shutdown before they fall out of scope

---

## Day 2 — Tue May 19 · Combine Radio Chat Channel

**Status:** ✅ Complete

Goals:
- `plugins/combine-ops/sh_plugin.lua` — add a `combine_radio` chat class in a `do...end` block: `CLASS.color = Color(80, 160, 255)`, `CLASS.format = "%s [RADIO] \"%s\""`, `CanSay` checks `speaker:IsCombine()` (or `speaker:Team() == FACTION_OTA`) and returns `"@notAllowed"` for civilians, `CanHear` returns `true` only for Combine/OTA; register with `ix.chat.Register("combine_radio", CLASS)`
- `plugins/combine-ops/sh_plugin.lua` — add a `combine_radio_eavesdrop` class immediately after: same color and format, `CanSay` always returns `false` (server-only send path), `CanHear` returns `true` for non-Combine within `ix.config.Get("chatRange", 280)` units of the speaker and `false` if they already receive via `combine_radio`; register with `ix.chat.Register("combine_radio_eavesdrop", CLASS)`
- `plugins/combine-ops/sv_plugin.lua` — add `/CombineRadio` command: `arguments = ix.type.text`, `OnRun` guards `if !IsCombine(client) then return client:Notify("Unauthorized.") end` then calls `ix.chat.Send(client, "combine_radio", message)` and `ix.chat.Send(client, "combine_radio_eavesdrop", message)` — mirrors the `/CWURadio` pattern exactly
- `plugins/combine-ops/sh_plugin.lua` — add the corresponding `if CLIENT then ix.command.Add("combineradio", {description = "Transmit on the Combine radio channel.", arguments = ix.type.text, OnRun = function() end}) end` stub so the command is registered client-side for the help system (the server-side `ix.command.Add` in sv_plugin.lua is the functional one)

---

## Day 3 — Wed May 20 · Recreational Chem Blueprint + Medical Synthesis Gate

**Status:** ✅ Complete

Goals:
- `plugins/cwu/libs/sh_blueprints.lua` — add the missing blueprint: `PLUGIN:RegisterBlueprint("bp_recreational_chem", {name = "Recreational Chemical", tier = 2, materials = {{"chemical_base", 1}, {"medical_herbs", 1}}, output = "recreational_chem", outputQuantity = 1, craftTime = 20})`; tier 2 is correct (Director approval required) to match the dual-use / plausible-deniability framing in DIRECTION.md; this is the only crafted item without a corresponding blueprint entry
- `plugins/cwu/entities/ix_medicalworkstation.lua` — read the file; if the `Use()` handler opens a synthesis UI independently of the production table, verify it calls `PLUGIN:CanUseBlueprint(character, blueprintID)` before permitting synthesis, so the tier-gate is enforced; add the check if absent
- `plugins/cwu/entities/ix_medicalworkstation.lua` — if the workstation allows compound synthesis, gate it behind `character:GetData("medicalTraining", false)`: add `if !character:GetData("medicalTraining", false) then client:NotifyLocalized("cwuNeedTraining"); return end` in the synthesis path, since Director-granted training is the unlock condition per the Medical division design
- `plugins/cwu/items/crafted/sh_recreational_chem.lua` — confirm `ITEM.isDualUse = true` is present (added May 8); no change if already there
- `plugins/cwu/languages/sh_english.lua` — add `cwuNeedTraining = "Medical training required for compound synthesis."` if the key is absent

---

## Day 4 — Thu May 21 · Citizen Heat Tier Notifications

**Status:** ✅ Complete

Goals:
- `plugins/combine-terminal/sh_plugin.lua` — add `util.AddNetworkString("CS_HeatTierChange")` to the existing `if SERVER then` block alongside the other network strings; this is the channel that tells a citizen their heat tier has escalated
- `plugins/combine-terminal/sv_plugin.lua` — rewrite `AddHeat(sid, amount)` to capture `local oldTier = GetHeatTier(sid)` before updating the score, then calculate `local newTier = GetHeatTier(sid)` after `CS.HeatScores[sid] = math.Clamp(...)` resolves; if `newTier > oldTier`, iterate `player.GetAll()` to find the matching SteamID and send `net.Start("CS_HeatTierChange") net.WriteUInt(newTier, 4) net.Send(ply)`
- `plugins/combine-terminal/cl_plugin.lua` — add `net.Receive("CS_HeatTierChange", function() local tier = net.ReadUInt(4); local msgs = {[1]="Your recent activities have been noted.", [2]="You are under heightened Combine scrutiny.", [3]="ADVISORY: You are a person of interest to Civil Protection.", [4]="HIGH ALERT: You have been flagged for immediate attention."}; chat.AddText(Color(180, 180, 180), "[SYSTEM] ", Color(220, 220, 220), msgs[tier] or "") end)` near the existing `net.Receive` blocks in cl_plugin.lua
- `plugins/combine-terminal/sv_plugin.lua` — the `oldTier > newTier` (heat decay) path does NOT send a notification; citizens are not told when their heat drops, preserving the one-sided surveillance atmosphere

---

## Day 5 — Fri May 22 · Medical Workstation Patient Treatment

**Status:** ✅ Complete

Goals:
- `plugins/cwu/entities/ix_medicalworkstation.lua` — read the file; if the `Use()` handler only opens a synthesis panel, add a "Treat Patient" interaction path: when `character:GetData("medicalTraining", false)` is true and the activator is targeting another player within 150 units (`client:GetEyeTrace().Entity`), open the treatment UI via `netstream.Start(client, "CWUMedicalTreat", targetEntIndex, healingItems)` where `healingItems` is the medic's inventory filtered for items with `isHealingItem = true`
- `plugins/cwu/entities/ix_medicalworkstation.lua` (server section) — add `netstream.Hook("CWUMedicalApply", function(client, targetEntIndex, itemID) ... end)` that validates medicalTraining, confirms the target player is within 200 units, consumes the item via `inventory:Remove(itemID)`, calls `target:SetHealth(math.min(target:Health() + healAmount, target:GetMaxHealth()))`, awards `PLUGIN:AwardLoyalty(character, 2, "treatment")`, and notifies both parties
- `plugins/cwu/derma/cl_medicalworkstation.lua` — read the file; if it only renders a synthesis list, add a second panel tab "TREAT PATIENT" that receives the `CWUMedicalTreat` netstream payload and displays target name, current health, and a listview of healing items from the medic's inventory; on item click send `netstream.Start(LocalPlayer(), "CWUMedicalApply", targetEntIndex, item.id)`
- `plugins/cwu/items/crafted/sh_cwu_bandage.lua` — confirm `ITEM.isHealingItem = true` and `ITEM.healAmount = 20` are set; add them if missing so the treatment UI can discover and use this item
- `plugins/cwu/items/crafted/sh_medical_stimpak.lua` — confirm `ITEM.isHealingItem = true` and `ITEM.healAmount = 40` are set; add them if missing; the stimpak should be the higher-value treatment option available only to Tier 3+ workers who can craft it

---

## Day 6 — Sat May 23 · Weekend

No tasks scheduled. All 5 days of the May 18–22 week completed successfully.

---

## Day 7 — Sun May 24 · Weekend

No tasks scheduled. New weekly plan will be authored for the week of May 25–29.
