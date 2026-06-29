# Weekly Development Plan
**Week of Jun 23 – Jun 27, 2026**
**Goal:** Close the three CONVENTIONS.md "Existing debt" items (detain/release, curfew, panic button) by reworking them into entity/terminal interactions; add Commerce loyalty for vendor restocking; fix scanner false-positive on authorized CWU radios.

---

## Day 1 — Mon Jun 23 · Detain/Release Actions on Combine Terminal
**Status:** ✅ Done

The `/transferdetainee` and `/releasedetainee` commands are CONVENTIONS.md debt. The combine terminal already has a Detainees tab showing the detention log. Add action buttons to that tab so Combine officers can log detentions and releases through the terminal entity, then deprecate the chat commands.

Goals:
- `plugins/combine-terminal/sv_plugin.lua` — In `CS_TerminalAction` receiver (~line 543), add two new dispatch cases: `"detainCitizen"` (reads `data.sid`, `data.name`; appends a new entry to `cs_detainees` with `status="DETAINED"`, `officer=ply:Name()`, `time=os.time()`) and `"releaseCitizen"` (scans `cs_detainees` from end for the most recent entry with matching SID and `status=="DETAINED"`, sets `status="RELEASED"`, `releasedBy=ply:Name()`, `releaseTime=os.time()`). Both gate `IsCombine(ply)`. After each action, save `cs_detainees` and broadcast `CS_BiometricAlert` with an in-world dispatch message to `GetCombinePlayers()`.
- `plugins/combine-terminal/sv_plugin.lua` — In `BuildFullPayload()`, add `onlineCitizens = BuildOnlineCitizens()` where `BuildOnlineCitizens()` loops `player.GetAll()` and returns `{name, sid}` for each non-Combine player with an active character.
- `plugins/combine-terminal/derma/cl_tab_detainees.lua` — Add a button bar at the bottom with two buttons: "LOG DETENTION" (opens a `DFrame` with a `DListView` of `data.onlineCitizens`; confirming selection fires `CS_TerminalAction` with `action="detainCitizen"` and the selected player's SID) and "LOG RELEASE" (reads the selected row's SID from the detainee list and fires `action="releaseCitizen"`). Show buttons only to Combine officers (the terminal already gates non-Combine access).
- `plugins/combine-ops/sv_plugin.lua` — Deprecate `/transferdetainee` and `/releasedetainee`: replace `OnRun` bodies with `client:Notify("File detentions at the processing terminal.")` and return. Leave the command stubs so existing binds don't hard-error.

---

## Day 2 — Tue Jun 24 · Curfew Toggle on Combine Terminal
**Status:** ✅ Done

The `/curfew` command is CONVENTIONS.md debt. It should be a switch or terminal action for senior Combine. The combine terminal already knows `curfewActive` in `BuildFullPayload()` — add a CURFEW CONTROL button to the terminal UI and implement the toggle logic as a `CS_TerminalAction` case.

Goals:
- `plugins/combine-terminal/sv_plugin.lua` — In `CS_TerminalAction`, add case `"toggleCurfew"`: gate by `IsSenior(ply)`. Replicate the curfew toggle logic from `combine-ops/sv_plugin.lua` inline: flip `CS.CurfewActive`; iterate `ents.FindByClass("ix_checkpoint")`, storing/restoring `CS.CheckpointPreCurfewModes` and calling `entity:SetMode()` exactly as the existing `/curfew` command does. Broadcast the dispatch `ChatPrint` to `GetCombinePlayers()` (same in-world 10-4/10-22 messages). After toggling, the regular `CS_TerminalRefresh` response already carries the updated `curfewActive` field.
- `plugins/combine-terminal/derma/cl_tab_units.lua` — At the bottom of the UNITS tab, add a section "CURFEW CONTROL" visible only when `self.m_bSenior` is true. Show a button reading "ACTIVATE CURFEW" or "LIFT CURFEW" depending on `data.curfewActive`. `DoClick` fires `CS_TerminalAction` with `{action="toggleCurfew"}` and updates the button label on the `CS_TerminalRefresh` response.
- `plugins/combine-ops/sv_plugin.lua` — Deprecate the `/curfew` command: replace `OnRun` with `client:Notify("Toggle curfew at the operations terminal.")` and return.

---

## Day 3 — Wed Jun 25 · Panic Button Wall Entity
**Status:** ✅ Done

The `/panicbutton` and `/panicclear` commands are CONVENTIONS.md debt. The fix is a wall-mounted `ix_panic_button` entity that Combine officers activate by pressing E, replicating the panic signal flow through a world object rather than a chat command.

Goals:
- `plugins/combine-ops/entities/entities/ix_panic_button.lua` — New entity. `ENT.Category = "HL2 RP"`, `AdminOnly = true`, `PhysgunDisable = true`, `AddCSLuaFile()`. Server `Initialize`: model `models/props_combine/combine_button001.mdl`, `PhysicsInit(SOLID_VPHYSICS)`, `SetUseType(SIMPLE_USE)`. `ENT:Use(client)`: if `!IsCombine(client)`, play `buttons/combine_button_locked.wav` and `client:Notify("Unauthorized.")` and return. Look up `CS.ActivePanics[sid]`: if active panic from this officer exists, clear it (nil the entry, send `CS_PanicClear` to `GetAllCombine()`); else create panic (populate `CS.ActivePanics[sid]`, set `CS.PanicTimers[sid]`, send `CS_PanicAlert` to `GetAllCombine()`). Respect `CFG.PanicCooldown`. Client `Draw`: 3D2D overlay showing "PANIC ALARM" in red if panic active for local player, grey if idle, within 256 units.
- `plugins/combine-ops/entities/entities/ix_panic_button.lua` — `ENT:SpawnFunction`: standard admin-spawn at trace hit position, then call `PLUGIN:SavePanicButtons()`. `ENT:OnRemove`: call `PLUGIN:SavePanicButtons()` if not `ix.shuttingDown`.
- `plugins/combine-ops/sv_plugin.lua` — Add `PLUGIN:SavePanicButtons()` (iterates `ents.FindByClass("ix_panic_button")`, persists `{pos, ang}` list to `ix.data.Set("cs_panicButtons", ...)`) and `PLUGIN:LoadPanicButtons()` (spawns each saved entity). Wire load into `hook.Add("InitPostEntity", "CS_LoadPanicButtons", ...)`.
- `plugins/combine-ops/sv_plugin.lua` — Deprecate `/panicbutton` and `/panicclear` commands: replace `OnRun` with `client:Notify("Use the mounted panic alarm.")` and return.

---

## Day 4 — Thu Jun 26 · Loyalty Redesign (Combine-dispensed only)
**Status:** ✅ Done

Design changed: loyalty must never be awarded by mechanics — only Combine officers can grant it manually through the Combine terminal. The previous plan (Commerce loyalty for vendor restocking) was cancelled because it would have re-introduced mechanical loyalty-earning, which contradicts the new rule. All automatic `AwardLoyalty` calls in the CWU plugin have been removed; a new manual path was added to the Combine terminal instead.

Changes made:
- `plugins/cwu/libs/sv_workorders.lua` — Removed `AwardLoyalty` from `CompleteWorkOrder` and `ManualCompleteWorkOrder`.
- `plugins/cwu/entities/ix_productiontable.lua` — Removed `AwardLoyalty` from craft-completion timer callback.
- `plugins/cwu/entities/ix_medicalworkstation.lua` — Removed `AwardLoyalty` from both synthesis completion callbacks (stimpak and drug synthesis).
- `plugins/cwu/entities/ix_cwu_combine_terminal.lua` — Added `loyalty` action to `CWUCombineTerminalAction` handler: looks up online character by name, calls `AwardLoyalty(char, amount, "commendation")` with amount clamped 1–5.
- `plugins/cwu/derma/cl_cwu_combine_terminal.lua` — Added "Issue Commendation" button and point amount spinner (1–5) to the Roster tab action panel. Officer selects a CWU member from the list, sets amount, and clicks to send `CWUCombineTerminalAction` with `action="loyalty"`.

---

## Day 5 — Fri Jun 27 · Scanner False-Positive Fix + Stimpak Voice Fix
**Status:** ✅ Done

Two small correctness fixes caught during research: (1) the scanner's `CFG.FlaggedItems` list contains `"radio"` as a plain substring match, which causes `cwu_radio` (a CWU-issued, Combine-authorized item) to be flagged as suspicious on every scan of a CWU worker — this is incorrect and will undermine the Commerce/CWU loop; (2) the stimpak's `OnRun` notification exposes gamey mechanic text.

Goals:
- `plugins/combine-scanner/sv_plugin.lua` — In `CFG.FlaggedItems` (~line 22), change `"radio"` to `"pirate_radio"` (matching a future contraband radio item uniqueID). Add a comment: `-- match exact item uniqueIDs; "cwu_radio" is authorized and must not be caught`. The broader scanning logic is unchanged.
- `plugins/combine-terminal/sv_plugin.lua` — Same fix in `CFG.FlaggedItems` (~line 31): change `"radio"` to `"pirate_radio"` so the terminal's item search is consistent.
- Run a convention check (`/helix-convention-check`) on all diffs from Days 1–4 before committing Day 5.
- Note: `sh_medical_stimpak.lua` notify text (`"The stimpak floods your system with healing compounds."`) is intentional flavor text — no change needed. CONVENTIONS.md updated to reflect this distinction.

---

## Automated session — Fri Jun 26
All five days confirmed ✅ Done. Sprint closed. No pending code tasks remain this week. Next sprint planning needed before Mon Jun 30.

## Automated session — Sat Jun 27
Weekend. No pending tasks. Sprint Week of Jun 23–27 fully closed. All three CONVENTIONS.md debt items resolved (panic button, detain/release terminal, curfew toggle). Next sprint starts Mon Jun 30.

## Automated session — Sun Jun 28
Weekend. No pending tasks. Audited codebase for next sprint gaps: (1) `pirate_radio` and `lockpick` are in `CFG.FlaggedItems` but no items exist — Pillar 5 loop is broken. (2) `/requestclearance` is a citizen chat command that should be an entity; approval/denial is already wired in the terminal CWU tab. (3) `/addcheckpoint`, `/removecheckpoint`, `/addrestrictedzone`, `/removerestrictedzone` are admin chat commands for world state — all should move to the terminal zones tab. Next sprint plan written below.

---

# Weekly Development Plan
**Week of Jun 30 – Jul 4, 2026**
**Goal:** Close four remaining command-debt items (requestclearance citizen kiosk, terminal zone/checkpoint CRUD); create the `pirate_radio` and `lockpick` contraband items that the scanner already references; and add a black-market stash entity so citizens can acquire contraband in-world without admin intervention.

**Council verdict (Jun 29):** Approved with modifications. Three pre-conditions must be met before Day 1 code is written: (1) run `/helix-inworld-voice` on the pirate_radio broadcast text and replace the gamey `"[UNAUTHORIZED SIGNAL]"` prefix with in-world signal language — this is a hard Rule 2 violation and cannot be left for Day 5; (2) open `_dev/UNTESTED.md` and confirm whether scanner item-flagging and heat-tier-alerts have unverified entries — if they do, those two must be live-verified or explicitly blocked before contraband items are created on top of them; (3) before writing Day 4 code, confirm `CS.AddHeat` is callable from an external entity by reviewing `combine-terminal/sv_plugin.lua` and documenting the call path or adding a pcall fallback. Day 4 is conditional: if pre-condition 3 cannot be satisfied, replace Day 4 with UNTESTED paydown. Day 5 convention gate moves to Day 1 start; Day 5 becomes UNTESTED paydown regardless. The pirate_radio broadcast architecture (item OnRun → netstream → Derma dialog → ix.chat.Send) is compliant with both conventions — the broadcast IS the communication mechanic and is exempt from Rule 1; only the prefix text violates Rule 2.

---

## Day 1 — Mon Jun 30 · Pirate Radio + Lockpick Contraband Items
**Status:** Pending

**Pre-conditions before writing any code:**
- Run `/helix-inworld-voice` to determine the correct in-world signal flavor for the pirate_radio broadcast chat type. The `"[UNAUTHORIZED SIGNAL]"` prefix is a gamey UI tag (Rule 2 violation) and must be replaced with in-world language (e.g. an atmospheric signal marker consistent with Combine interception lore) before the chat type is registered.
- Run `/helix-convention-check` on the planned Day 1 diff before committing.
- Check `_dev/UNTESTED.md` for entries covering scanner item-flagging and heat-tier-alerts. If either is unverified, note the gap in this day's entry and proceed only with the understanding that live-server testing is required before Day 4.

The scanner's `CFG.FlaggedItems` table lists `"pirate_radio"` and `"lockpick"` but neither item exists. Scanning a citizen who possesses a non-existent item always returns clean — Pillar 5 dual-use tension cannot trigger. Both items need to exist before any contraband RP loop is possible.

Goals:
- `schema/items/contraband/sh_pirate_radio.lua` — New item. `ITEM.uniqueID = "pirate_radio"`, `ITEM.name = "Pirate Radio"`, model `models/props_lab/radio_on.mdl`. Two item functions: `"Toggle"` (server `OnRun`: flips `itemTable:GetData("active", false)`; notify via `NotifyLocalized`; return false) and `"Broadcast"` (server `OnRun`: if not active, `NotifyLocalized("pirateRadioOff")`; else `netstream.Start(client, "PirateRadioBroadcastPrompt", {})` so client can submit text; return false). `ITEM.cost = 0` — obtained via RP, not bought.
- `schema/cl_plugin.lua` (or equivalent schema client file) — `netstream.Hook("PirateRadioBroadcastPrompt", function() ... end)`: open `Derma_StringRequest` titled `"OPEN FREQUENCY"`, on confirm call `netstream.Start("PirateRadioBroadcast", text)`. (Title is placeholder pending helix-inworld-voice output.)
- `schema/sv_plugin.lua` (or equivalent server file) — `netstream.Hook("PirateRadioBroadcast", function(client, msg) ... end)`: validate `IsValid(client)` + `client:HasItem("pirate_radio")` + `client:GetItemByUniqueID("pirate_radio"):GetData("active")` + `#msg <= 200`; then `ix.chat.Send(client, "pirate_broadcast", msg)`. Confirm no `ix.command.Add` is registered for this — the item OnRun path is the only entry point.
- Register `"pirate_broadcast"` chat type in `schema/sh_plugin.lua`: format string determined by helix-inworld-voice pre-condition (in-world signal flavor, sender name suppressed). Color `Color(80, 200, 80)`, range 600 units, `CanSay` returns true for all factions. Showing it to Combine but hiding the sender creates search pressure.
- `schema/items/contraband/sh_lockpick.lua` — Passive contraband item. `ITEM.uniqueID = "lockpick"`, `ITEM.name = "Lock Pick Set"`, model `models/props_junk/PopCan01a.mdl` (placeholder). No functions this sprint — exists only so the scanner flag resolves. `ITEM.cost = 0`.
- `schema/languages/sh_english.lua` — Add `pirateRadioOff` and `pirateRadioOn` in-world flavor strings (exact text from helix-inworld-voice pass).

---

## Day 2 — Tue Jul 1 · Citizen Clearance Kiosk Entity
**Status:** Pending

`/requestclearance` is a citizen-facing world-interaction chat command. The Combine terminal already handles approval/denial via `CS_TerminalAction` (`approveClearance`/`denyClearance`) and shows pending requests in the CWU tab. The only missing piece is the citizen-side entity that replaces the command.

Goals:
- `plugins/combine-terminal/entities/entities/ix_clearance_kiosk.lua` — New entity. `ENT.Category = "HL2 RP"`, `ENT.PrintName = "Citizen Processing Terminal"`, `AdminOnly = true`. Model: `models/props_combine/combine_interface001.mdl`. `ENT:Use(client)`: gate — if `client:IsCombine()` return. Gate cooldown 30 s per SID (`CS.KioskCooldowns[sid]`). Check if request already pending: if `CS.CWURequests[sid]` exists, `client:NotifyLocalized("clearanceAlreadyPending")` and return. Otherwise add to `CS.CWURequests` and broadcast `CS_ClearanceNotify` to Combine exactly as the deprecated command did. Notify citizen `"clearanceSubmitted"`. Client `Draw`: 3D2D `"CITIZEN PROCESSING TERMINAL"` header; show `"REQUEST PENDING"` in yellow if `CS.CWURequests[client:SteamID()] != nil` on a `ClientsideHook`, else `"PRESENT CID FOR PROCESSING"` in white; draw only within 200 units.
- `plugins/combine-terminal/sv_plugin.lua` — Add `CS.KioskCooldowns = CS.KioskCooldowns or {}`. No other server changes needed — `CS.CWURequests`, `CS_ClearanceNotify`, `DoApproveClearance/DoDenyClearance` are already wired.
- `plugins/combine-terminal/sv_plugin.lua` — Deprecate `/requestclearance`: replace `OnRun` body with `client:Notify("Present your CID at the nearest processing terminal.")` and return.
- `plugins/combine-terminal/languages/sh_english.lua` (or create it) — Add `clearanceSubmitted = "CID submitted for processing."`, `clearanceAlreadyPending = "A request is already pending for your CID."`.

---

## Day 3 — Wed Jul 2 · Zone & Checkpoint Management via Terminal
**Status:** Pending

`/addrestrictedzone`, `/removerestrictedzone`, `/addcheckpoint`, `/removecheckpoint` are admin chat commands that create persistent world state. The terminal already shows zones and checkpoints in the Zones tab with a hint "managed via admin commands." Adding CRUD actions to the terminal moves these into the Combine intelligence workflow where they belong; senior Combine can define sectors without console access.

Goals:
- `plugins/combine-terminal/sv_plugin.lua` — In `CS_TerminalAction`, add four new cases gated by `IsSenior(ply)`:
  - `"addZone"`: reads `data.name` (string, max 32 chars), `data.radius` (number, clamped 64–2048); appends to `cs_zones` using `ply:GetPos()` as origin; `client:Notify()` confirmation. Broadcasts `CS_TerminalRefresh` to all Combine.
  - `"removeZone"`: reads `data.name`; removes matching entry from `cs_zones`; `client:Notify()`. Broadcasts refresh.
  - `"addCheckpoint"`: reads `data.name`, `data.radius`; appends to `cs_checkpoints`. Broadcasts refresh.
  - `"removeCheckpoint"`: reads `data.name`; removes matching. Broadcasts refresh.
- `plugins/combine-terminal/derma/cl_tab_zones.lua` — Below the existing zone list, add a "ZONE MANAGEMENT" section (only rendered when `self.m_bSenior` is true): two `DTextEntry` inputs (Name, Radius), an "ADD ZONE" button (`SendAction("addZone", {name=..., radius=...})`), and a "REMOVE SELECTED" button that reads the selected zone name from the list above and fires `SendAction("removeZone", {name=...})`. Add equivalent "CHECKPOINT MANAGEMENT" section for checkpoints. After receiving `CS_TerminalRefresh`, call `self:Populate(data)` to re-render the updated lists.
- `plugins/combine-terminal/sv_plugin.lua` — Deprecate `/addrestrictedzone`, `/removerestrictedzone`, `/addcheckpoint`, `/removecheckpoint`: replace `OnRun` bodies with `client:Notify("Manage sectors at the operations terminal.")` and return. Keep stubs so existing binds don't error.

---

## Day 4 — Thu Jul 3 · Black Market Stash Entity (conditional)
**Status:** Pending

**Pre-condition before writing any code:** Review `plugins/combine-terminal/sv_plugin.lua` and confirm `AddHeat` is exposed as `CS.AddHeat` (or expose it now). If this cannot be verified or the heat system has open UNTESTED entries that are unresolvable without live-server access, replace Day 4 with UNTESTED paydown: write specific in-server test procedures for the five highest-risk backlog entries (scanner flagging, heat-tier-alerts, curfew toggle, panic button, loyalty commendation) and commit them to `_dev/UNTESTED.md` as updated test notes.

If pre-condition passes — proceed with the stash:

Contraband items (pirate radio, lockpick) are now defined but have no in-world acquisition path. Without a way to get them, the scan loop can only be triggered by admin-spawned items. A hidden, admin-placed stash entity gives citizens an in-world source at a heat cost — creating the risk/reward that makes dual-use tension real without requiring an admin to be present.

Goals:
- `schema/entities/entities/ix_black_market_stash.lua` — New entity. `ENT.Category = "HL2 RP"`, `ENT.PrintName = "Black Market Stash"`, `AdminOnly = true`, `PhysgunDisable = true`, `bNoPersist = true`. Model: `models/props_junk/garbage_bag001a.mdl`. Server `Initialize`: `SetUseType(SIMPLE_USE)`. `ENT:Use(client)`: gate Combine (`IsCombine(client)` → play locked sound, return). Gate distance 96 units. Per-player cooldown 120 s (`ENT.Cooldowns[sid]`). Check if citizen, has character. Give one `"pirate_radio"` and one `"lockpick"` to character inventory. Add heat via `if CS and CS.AddHeat then CS.AddHeat(sid, 15) end` (defensive call — if CS.AddHeat is nil, stash still functions but heat is not added; this guards against cross-context nil errors). `client:NotifyLocalized("stashAccessed")`. Client `Draw`: 3D2D label in dark red within 128 units, pulsing alpha — exact text from helix-inworld-voice (not "CONTRABAND").
- `schema/languages/sh_english.lua` — Add `stashAccessed = "You find something useful tucked away."`.
- `plugins/combine-terminal/sv_plugin.lua` — After the local declaration of `AddHeat`, add `CS.AddHeat = AddHeat` so external entities can call it across Lua contexts.

---

## Day 5 — Fri Jul 4 · UNTESTED Paydown + Convention Gate
**Status:** Pending

Convention check moves to Day 1 start (run `/helix-convention-check` before committing each day). Day 5 is dedicated to reducing the UNTESTED.md backlog, which grows with each sprint and must not continue unchecked.

Goals:
- For each of the five new entries added this sprint (pirate_radio item, lockpick item, clearance kiosk, zone/checkpoint terminal CRUD, black market stash if built), write specific in-server test procedures in `_dev/UNTESTED.md`.
- Review the existing 18 backlog entries. Identify which are verifiable in an automated session via code review (no live server needed): confirm `combine-terminal/sv_plugin.lua` `AddHeat` wiring, scanner `CFG.FlaggedItems` lookup logic. For any that can be statically confirmed, add a note to the entry.
- Confirm `"pirate_broadcast"` chat type sender is suppressed (citizens receive broadcast, Combine receive broadcast, neither sees the sender character name).
- Verify all player-facing strings added this sprint are in-world voice (no numbers, no mechanic labels, no UI-tag prefixes).
- If Day 4 was replaced by paydown work, document that substitution here so the black market stash defers cleanly to next sprint.

---

## Note: Medical Smoke-Test (Carried Forward)
Days 3–5 of the prior week (medical injury smoke-test) remain pending live server access. When `medicalInjuries 1` is enabled on a live server, verify: `EntityTakeDamage` creates wounds, bleed tick drains HP, leg wound causes limp, bandage seals wound (80%)/rebleeds (20%), surgery via `ix_medicalworkstation` clears all wounds. Tune constants in `sv_injury.lua` (WOUND_THRESHOLD, BLEED_FLOOR, REBLEED_DELAY, RECOVERY_STEP) if needed after observation. No code session work required — this is a live-server QA item.

---

---

# Completed Weeks

## Week of Jun 22 – Jun 26, 2026 (archived)
**Goal:** Wire injury→heat scanner integration (medical fast-follow), complete Tier 4 senior-worker tax discount, and close any remaining Pillar 2 CWU gaps identified by smoke-testing the medical system.

---

## Day 1 — Mon Jun 23 · Injury→Heat Scanner Integration
**Status:** ✅ Done

When a Combine scanner biometrically scans a citizen who has active bleeding wounds, the scan should raise their heat score — wounded citizens trying to pass through checkpoints unnoticed are a liability. This reuses the existing `AddHeat` plumbing in `combine-terminal/sv_plugin.lua`.

Goals:
- `plugins/combine-terminal/sv_plugin.lua` — In the `CS_BiometricScan` handler, after building `scanResult`, check whether the scanned player has injuries via `char:GetData("injuries", {})`. If any wound is `bleeding == true`, call `AddHeat(sid, 15)` with a comment "bleeding wound detected by scanner". This mirrors the existing `AddHeat` call pattern in the same handler.
- `plugins/combine-scanner/sv_plugin.lua` — In the scanner `Use`/scan handler, where a `CS_BiometricScan` net message is sent: no change needed; heat is awarded server-side in the terminal handler.
- No new player-facing strings. The existing `CS_BiometricAlert` Tier 4 broadcast handles the Combine notification if heat tips over.

Implementation note: Scan logic lives in `scansubject` command in `combine-scanner/sv_plugin.lua` (no separate `CS_BiometricScan` net handler exists). Wound check inserted before `GetHeatTier` so the scan result reflects the raised score.

---

## Day 2 — Tue Jun 24 · Tier 4 Senior Worker Vendor Tax Discount
**Status:** ✅ Done

`ix.config.Add("cwuSeniorWorkerTaxDiscount", 25, ...)` was added to `sh_plugin.lua` alongside the Tier 5 config but was never wired into the purchase handler. Tier 4 sellers should receive a 25% tax reduction (vs 50% for Tier 5 Union Exemplar).

Goals:
- `plugins/cwu/entities/ix_vendorterminal.lua` — In `CWUVendorPurchase`, immediately after the existing Tier 5 discount block (`if ownerChar and ownerChar:GetData("loyaltyTier", 0) == 5`), add an `elseif` for Tier 4: `elseif ownerChar and ownerChar:GetData("loyaltyTier", 0) >= 4`, apply `taxRate = taxRate * (1 - ix.config.Get("cwuSeniorWorkerTaxDiscount", 25) / 100)`. No new strings — silent economic perk same as Tier 5.

Implementation note: Both the config (`sh_plugin.lua`) and the `elseif` wiring (`ix_vendorterminal.lua`) were already in place — implemented alongside Day 4 of the prior week when Tier 5 discount was added. Plan updated to reflect reality.

---

## Weekend Jun 20 — Pre-Smoke-Test Code Review (automated session)
Static analysis of `sv_injury.lua` and `ix_medicalworkstation.lua` before the live smoke test.
One bug found and fixed: `CWUMedicalSurgery` was restoring full HP without calling `PLUGIN:WipeInjuries`, so leg-wound limps and bleeding vignettes would persist after surgery. Fixed in `ix_medicalworkstation.lua`.
All other systems (bleed tick, severity recovery, re-bleed timer, bandage 80/20 logic, walk-speed restore) reviewed and appear correct.

## Sunday Jun 21 — Pre-Sprint Rest Day (automated session)
No tasks scheduled. Days 1 and 2 (scanner heat integration + Tier 4 vendor discount) were completed ahead of schedule on Jun 20. The Jun 20 static analysis found and fixed the surgery wipe bug. Days 3–5 smoke-test is pending live server access starting Wed Jun 25.

---

## Days 3–5 — Wed–Fri Jun 25–27 · Medical System Smoke-Test + Tuning
**Status:** Pending (requires live server — carried forward as a QA note, not a code task)

After enabling `medicalInjuries 1` on the live server for the first time, observe the injury loop in play.

---

---

## Cooking & Hunger System (new `cooking` plugin)
**Status:** Pending

A full citizen survival loop: persistent hunger that drains over time, in-world environmental cues when hungry or starving (vignette + HP penalty — no numbers or bars), ingredient and cooked-food items, two cooking stations (fireplace for grilling, stove for pot-based cooking), and an active derma cooking minigame with six distinct interactions (stir, flip, season, skim, poke/probe, turn). Cook quality determines the output: good play yields the proper cooked dish; poor play yields a charred burnt variant with lower nutrition.

**Phase 1 — Hunger system** (complete):
- `plugins/cooking/sh_plugin.lua` — PLUGIN meta, `ix.config.Add` for `cookingEnabled` / `cookingHungerRate` / `cookingStarveDamage`, `ix.util.Include` for libs and realm files.
- `plugins/cooking/libs/sv_hunger.lua` — 60s tick loop (mirrors `sv_injury.lua`); `PLUGIN:Feed(character, amount)`; `hook.Add("PlayerAteFood", ...)` → Feed; `notifiedTier` table with in-world `NotifyLocalized` cues at hunger ≥ 50 and ≥ 75; HP drain at hunger ≥ 75 with `STARVE_FLOOR = 20`; `PlayerDisconnected` cleanup; `PlayerLoadedCharacter` sync; `cooking_demo` concommand self-check.
- `plugins/cooking/cl_plugin.lua` — `netstream.Hook("CookingHungerUpdate")`; `PLUGIN:HUDPaint()` brownish vignette scaling from hunger=40 to 100, pulsing at starvation.
- `plugins/cooking/languages/sh_english.lua` — `cookingHungry` / `cookingStarving` in-world cue strings.
- `schema/items/food/*.lua` (12 files) — add `ITEM.nutrition` and `hook.Run("PlayerAteFood", client, itemTable.nutrition or 10)` to each Eat/Drink OnRun.

**Phase 2 — Ingredients, cooked foods, recipe registry** (complete):
- `plugins/cooking/libs/sh_recipes.lua` — `PLUGIN.Recipes` table `{id, name, cookType, ingredients={uniqueID=count}, output, time, interactions={...}}`.
- `plugins/cooking/items/ingredients/` — raw_meat, vegetables, flour, eggs, oil.
- `plugins/cooking/items/cooked/` — cooked_meat, charred_food (burnt variant), stew, bread. Eat → heal + `hook.Run("PlayerAteFood", ...)`.

**Phase 3 — Cooking stations** (complete):
- `plugins/cooking/entities/ix_cookingfireplace.lua` + `ix_cookingstove.lua` — `ENT.Category = "HL2 RP"`, `SetupDataTables` (State/CookEnd/CookDuration/CookName), 3D2D billboard, `SpawnFunction`. Both usable by any non-Combine player.
- `plugins/cooking/sv_plugin.lua` — `netstream.Hook("CookingStart")`: validate distance + ingredients + cookType match → consume ingredients → set State=1 + timer → State=2 on completion. Collect (Use on State=2) → `ix.item.Spawn`.

**Phase 4 — Derma cooking minigame + quality** (complete):
- `plugins/cooking/derma/cl_cooking.lua` — recipe-picker `DFrame` opened by `netstream.Hook("CookingOpen")`; choosing a recipe sends `CookingStart` and opens the minigame panel. Six interaction types: **stir** (click-drag spoon in circle), **flip** (timing hit on rising sizzle bar), **season** (three rapid button presses in sequence), **skim** (drag cursor L→R over foam), **poke/probe** (click-hold ~1.5s for doneness), **turn** (drag handle to green arc zone). Each recipe's `interactions={}` array specifies which subset applies in order. Successful cues accumulate quality 0..1; client sends `CookingQuality` netstream on completion; server selects output item (cooked vs charred) based on quality.

**Phase 5 — Polish** (complete):
- `plugins/cooking/languages/sh_english.lua` — all strings filled (cookingBusy, cookingNoRecipes, cookingMissingIngredients, cookingDone, cookingBurnt, cookingHungry, cookingStarving).
- Convention check passed: 0 blockers, 0 warnings.

---

# Completed Weeks

## Week of Jun 15 – Jun 19, 2026 (archived)
**Goal:** Close remaining Pillar 1 intel/enforcement loops (heat-tier escalation alerts, detainee release lifecycle, curfew checkpoint lockdown) and extend the Commerce/Loyalty loop with vendor stock alerts and a Union Exemplar tax perk.

---

## Day 1 — Mon Jun 15 · Heat Tier 4 "Person of Interest" Alert to Combine
**Status:** ✅ Done

- Added `CS_BiometricAlert` broadcast (priority 1) + `ChatPrint` to all Combine players when a citizen's heat crosses into Tier 4, in `AddHeat()`.
- Fixed a pre-existing forward-reference bug: `FindPlayerBySteamID`/`GetCombinePlayers` were defined after `AddHeat` but called from within it, causing a nil-call error whenever a heat tier changed. Moved both definitions above `AddHeat` and removed the now-duplicate later definitions.
- `heatTier`/`heatScore` fields in `BuildFullPayload()` were already populated — no change needed there.

---

## Day 2 — Tue Jun 16 · Detainee Release Command + Status Tracking
**Status:** ✅ Done

Goals:
- `plugins/combine-ops/sv_plugin.lua` — In the `transferdetainee` command `OnRun` (~line 152), add `status = "DETAINED"` to the log entry table that's appended to `cs_detainees`.
- `plugins/combine-ops/sv_plugin.lua` — Add a new command `releasedetainee` (mirrors `transferdetainee`).
- `plugins/combine-terminal/derma/cl_tab_detainees.lua` — Added STATUS column; colour rows by status.

---

## Day 3 — Wed Jun 17 · Vendor Terminal Out-of-Stock Alert to Owner
**Status:** ✅ Done

- Design changed: dropped push HUD banner in favour of Commerce Inventory Oversight tab on the CWU Director PC.
- `plugins/cwu/entities/ix_cwu_director_pc.lua` — `ENT:Use` enumerates `ents.FindByClass("ix_vendorterminal")` and includes a `vendorTerminals` list in the `CWUDirectorPCOpen` netstream payload.
- `plugins/cwu/derma/cl_cwu_director_pc.lua` — Added `CreateVendorStockTab()` / `PopulateVendorStock()`: DListView of Terminal / Operator / Stock / Status / Earnings with DEPLETED/LOW/STOCKED colouring.

---

## Day 4 — Thu Jun 18 · Union Exemplar (Tier 5) Vendor Tax Discount
**Status:** ✅ Done

- Added `ix.config.Add("cwuModelCitizenTaxDiscount", 50, ...)` in `sh_plugin.lua`.
- In `CWUVendorPurchase`, hoisted owner character lookup before tax calculation. Tier 5 owners receive 50% tax reduction (configurable).

---

## Day 5 — Fri Jun 19 · Curfew Checkpoint Auto-Lockdown
**Status:** ✅ Done

Goals:
- `plugins/combine-ops/sv_plugin.lua` — In the `curfew` command `OnRun`, after toggling `CS.CurfewActive`, iterate `ents.FindByClass("ix_checkpoint")`. Store/restore modes via `CS.CheckpointPreCurfewModes` and `entity:SetMode(3)` on activation / restore on deactivation.

---
