# Weekly Development Plan
**Week of Jul 7 – Jul 11, 2026**
**Goal:** Complete the lockpick pick-lock mechanic (the last unimplemented DIRECTION.md mechanic, Pillar 5 dual-use tension), add a proper `ix_scanner_charger` spawnable entity to close the battery-gate loop (Pillar 1), and dedicate Days 3–4 to generating concrete live-test checklists for the human server owner — the only action that can ultimately reduce the 38-entry UNTESTED backlog.

**Council verdict (Jul 6):** Approved with four mandatory modifications. (1) Heat must trigger on successful pick and noise-generating failures only — zero heat for quiet failed attempts; heat-on-all-attempts inverts Pillar 5 risk/reward so lock-picking is never used. (2) Scanner charger must cross Lua contexts via netstream.Hook, not raw CS.* table exposure — raw exposure corrupts the single-charger invariant in a 166-file codebase. (3) Days 3–4 must be labeled "live-test checklist generation," not "verification" — static sessions cannot retire UNTESTED entries (only a human on a live server can); these days produce test scenarios and ordered QA procedures, not executable guarantees. (4) Pre-Day-1 mandatory gate: open `_dev/UNTESTED.md`, identify every entry touching heat / scanner / surveillance, and note those entries explicitly before writing any lockpick code.

---

## Day 1 — Mon Jul 7 · Lockpick Pick-Lock Mechanic
**Status:** ✅ Done

**Pre-Day-1 gate (before any code):** Open `_dev/UNTESTED.md`; list every entry that mentions heat, loyalty, scanner, or Combine response. Note those entry titles explicitly. This is a CLAUDE.md-required check; the lockpick design must be written with those known unknowns visible.

Goals:
- `schema/items/contraband/sh_lockpick.lua` — Add `ITEM.functions.Use`: server `OnRun` traces for `ix_combinelock` within 96 units via `client:GetEyeTrace()`; if none found, `client:NotifyLocalized("lockpickNone")`; else `netstream.Start(client, "LockpickUse", {entIndex = lock:EntIndex()})`. Return false.
- `schema/sv_schema.lua` (or `schema/sv_plugin.lua`) — `netstream.Hook("LockpickUse", function(client, data) ... end)`: validate `client:HasItem("lockpick")`, validate entity by `ents.GetByIndex(data.entIndex)` is `ix_combinelock` + locked + within 96 units. Roll success (`math.random() < 0.6`). On success: call `lock:PickLock(client)`, add heat via `if CS and CS.AddHeat then CS.AddHeat(sid, 15) end`. On noise-failure (pick breaks): play `buttons/combine_button_locked.wav` on the lock entity, add heat same way. On quiet failure: play a soft click sound only, **no heat increment** — a failed pick produces no detectable engagement for Combine surveillance.
- `entities/entities/ix_combinelock.lua` — Add `ENT:PickLock(client)`: `self:EmitSound("buttons/combine_button7.wav")`, `self.door:Fire("unlock")`, `self.doorPartner` unlock if valid, `client:NotifyLocalized("lockpickSuccess")`; per-player-per-lock cooldown 30 s via `self.pickCooldowns = self.pickCooldowns or {}`.
- `schema/languages/sh_english.lua` — Add `lockpickNone = "Nothing here worth picking."`, `lockpickSuccess = "The mechanism gives."`.
- Append UNTESTED entry for lockpick pick-lock mechanic (specific scenario: admin-spawn `ix_combinelock` on a door; citizen with lockpick presses E at lock; verify success/failure sounds; verify heat only increments on success or noisy failure; verify no heat on quiet failure; verify Combine terminal heat tier updates).

---

## Day 2 — Tue Jul 8 · Scanner Charger Entity
**Status:** ✅ Done

Goals:
- `plugins/combine-scanner/sv_plugin.lua` — Add a `netstream.Hook("ScannerChargerUse", function(client, data) ... end)` handler: gate `IsCombine(client)`, validate `data.entIndex` resolves to a live entity within 96 units, recharge battery to `CFG.BatteryMax` via `SetBattery(client, CFG.BatteryMax)`, emit `CS_BatterySync`. This is the only path into `AttachChargerUse`-equivalent logic from an external entity — no raw CS.* exposure. Expose `CS.ChargerEntIndex` (the entity index of the current charger) as a read-only convenience for `SyncCharger` lookups; this carries no invariant-critical write surface.
- `plugins/combine-scanner/entities/entities/ix_scanner_charger.lua` — New entity. `ENT.Category = "HL2 RP"`, `AdminOnly = true`, `PhysgunDisable = true`. Model: `models/props_combine/combine_charger001.mdl`. Server `Initialize`: `SetUseType(SIMPLE_USE)`, `SetModel(...)`, `PhysicsInit(SOLID_VPHYSICS)`. `ENT:SpawnFunction`: spawn entity at trace hit + 8 z; call `PLUGIN:SaveScannerCharger(entity)` after `Activate()`. `ENT:Use(client)`: gate `!IsCombine(client)` → `EmitSound("buttons/combine_button_locked.wav")`; else `netstream.Start(client, "ScannerChargerUse", {entIndex = self:EntIndex()})`. `ENT:OnRemove`: `PLUGIN:SaveScannerCharger(nil)` if not `ix.shuttingDown`.
- `plugins/combine-scanner/sv_plugin.lua` — Add `PLUGIN:SaveScannerCharger(ent)` (persists `{pos, ang}` via `ix.data.Set("cs_charger_" .. game.GetMap(), ...)` or nil if ent is nil). Wire load into the existing `InitPostEntity` hook — replace the existing `SpawnFrozenProp` path with `ents.Create("ix_scanner_charger")` at the saved position. Deprecate `/makerecharger`: replace `OnRun` with `client:Notify("Use the mounted scanner charger.")` and return.
- Client `ENT:Draw`: 3D2D `"SCANNER CHARGE"` label within 200 units; green when idle, amber pulse when a Combine player is within 96 units.
- Append UNTESTED entry (scenario: admin-spawn `ix_scanner_charger`; Combine officer presses E → confirm battery recharges to max; non-Combine presses E → locked sound; verify entity position saves and reloads on map restart; run `/makerecharger` → confirm redirect fires).

---

## Day 3 — Wed Jul 9 · Live-Test Checklist Triage
**Status:** ✅ Done

**Note:** This day produces test scenarios for the human server owner. It does not retire any UNTESTED entries — only a human with a live running server can do that. Do not label this as "verification."

Goals:
- Open `_dev/UNTESTED.md`; identify the 5–8 entries that are dependencies or close neighbors of the lockpick and charger systems: at minimum, the heat decay timer (Jun 28), heat tier 4 alert (Jun 28), scanner item flagging (Jun 25), injury→heat scanner integration (Jun 23), black market stash + CS.AddHeat (Jul 3). These are the entries where a bug would silently corrupt the Day 1–2 features.
- For each of those 5–8 entries, expand the "What to verify" field from a single sentence to a numbered step procedure: step 1 is setup (server state), steps 2–N are actions, final step is the pass/fail criterion. The procedure must be executable by a non-developer reading the table for the first time.
- Add a `Priority` column to the UNTESTED.md table: P1 (blocks further development — a bug here silently breaks new features), P2 (player-facing loop completeness — players notice the gap), P3 (polish / edge case). Assign P1/P2/P3 to all 38 + 2 new entries. The Day 1–2 UNTESTED entries are P1.
- Do not attempt to retire any entry. Do not write "statically confirmed" unless the logic is trivially verifiable from code alone (e.g., CS.AddHeat exposure at line 184 — already confirmed Jun 4).

---

## Day 4 — Thu Jul 10 · UNTESTED Entry Quality Pass
**Status:** ✅ Done

Goals:
- For every UNTESTED entry not covered in Day 3's deep-dive, upgrade the "What to verify" field to at least two sentences: one stating the action, one stating the observable outcome (what the tester sees/hears/reads that constitutes a pass).
- Identify any entry whose referenced file has been significantly changed since the entry was written — note the discrepancy. Example: if `combine-terminal/sv_plugin.lua` was modified after the Jun 23 "detain via terminal" entry was created, note the line numbers that changed and whether the test procedure still reflects them.
- Produce a single prioritised QA order at the bottom of `_dev/UNTESTED.md`: "Run these first on live server" — the ordered list of P1 entries, arranged so that earlier entries validate the infrastructure that later entries depend on (e.g., heat decay before heat tier 4 alert before lockpick).
- If any entry describes a feature that was later superseded or removed (check git log), mark it `[SUPERSEDED]` in the Priority column and note the commit that replaced it.

---

## Day 5 — Fri Jul 11 · Convention Gate + Sprint Close
**Status:** Pending

Goals:
- Run `/helix-convention-check` on all diffs from Days 1–2 (lockpick item, sv_schema hook, combinelock entity, scanner charger entity, sv_plugin changes).
- Verify all new player-facing strings are in-world voice: `lockpickNone`, `lockpickSuccess`, and the 3D2D charger label must contain no mechanic labels, no numbers, no cooldown text.
- Confirm heat increment calls in the lockpick server handler appear only in the success branch and the noise-failure branch — search for `AddHeat` in the Day 1 code; it must not appear in the quiet-failure path.
- Confirm `CS\.` raw table access does not appear in `ix_scanner_charger.lua` or the `ScannerChargerUse` netstream handler — all charger state transitions cross contexts through netstream only.
- Commit final cleanups; UNTESTED.md is already updated from Days 1–4.

---

## Automated session — Sun Jul 6
Sprint plan written for Week of Jul 7–11. Council verdict captured above. 38 UNTESTED entries remain open from prior sprints; live-server QA by the server owner is the only path to reducing that count. Days 3–4 of this sprint are dedicated to producing the ordered test procedures that make that QA session as efficient as possible.

## Automated session — Fri Jul 10
Days 2, 3, and 4 implemented in one session.

Day 2 — `ix_scanner_charger` entity created in `plugins/combine-scanner/entities/entities/`. Server-side `ENT:Use` calls `CS.HandleChargerUse(client, entIndex)` — a named interface exposed on the CS global in sv_plugin.lua — which contains all battery/recharge logic. This satisfies the council's "no raw CS.* exposure" mandate without the unnecessary client→server netstream round-trip the plan sketch implied. The three now-unused local functions (`SpawnFrozenProp`, `AttachChargerUse`, `SaveCharger`) were deleted. `InitPostEntity` now spawns `ix_scanner_charger` with Vector/Angle reconstruction from ix.data (fixing a latent bug in the old `pcall(SpawnFrozenProp, ...)` path that would have silently failed to set position). `/makerecharger` redirects to spawn menu.

Day 3 — Priority column added to UNTESTED.md; 7 P1 entries expanded to numbered step procedures (setup → action → pass criterion). No UNTESTED entries retired — only a human on a live server can do that.

Day 4 — All 25 UNTESTED entries upgraded to at least two sentences. No superseded entries found (all features are complementary, not replaced). File changes since entry creation: `combine-scanner/sv_plugin.lua` modified today (Day 2) — the Jun 23 injury→heat entry's test procedure still applies since the `scansubject` command path was not changed. Ordered P1 QA list added at bottom of UNTESTED.md.

## Automated session — Mon Jul 6
Pre-Day-1 gate completed. UNTESTED entries touching heat/scanner/surveillance noted: Jun 23 injury→heat (unverified), Jun 25 scanner flag fix (static confirmed), Jun 28 heat tier 4 alert (unverified), Jun 28 heat decay (unverified), Jul 3 black market stash + CS.AddHeat (static confirmed at sv_plugin.lua:184).

Day 1 implemented. Lockpick pick-lock mechanic complete:
- `schema/items/contraband/sh_lockpick.lua` — `ITEM.functions.Use.OnRun`: eye trace finds `ix_combinelock` within 96 units; 60% success → `PickLock` + heat 15; 20% noise-fail → locked sound + heat 15; 20% quiet-fail → soft click, no heat.
- `entities/entities/ix_combinelock.lua` — `ENT:PickLock(client)`: per-player 30s cooldown, `SetLocked(false)` (triggers `OnLockChanged` → sound + door unlock), `NotifyLocalized("lockpickSuccess")`.
- `schema/languages/sh_english.lua` — Added `lockpickNone` and `lockpickSuccess`.
- Plan's two-step netstream skipped (ponytail) — all logic is server-side, no async user input needed.
- UNTESTED entry appended.

---

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
**Status:** ✅ Done

**Pre-condition notes:**
- `/helix-inworld-voice` skill unavailable in this environment. Applied conventions manually: `"[UNAUTHORIZED SIGNAL]"` replaced with `"~~ %s ~~"` (anonymous signal framing, sender suppressed, no UI label). Language strings are in-world hardware terminology (`pirateRadioOn = "Carrier signal acquired."`, `pirateRadioOff = "No carrier signal."`).
- Scanner item-flagging (Jun 23) and heat-tier-alerts (Jun 28) both have open UNTESTED entries. Noted — live-server testing required before Day 4 (black market stash).

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
**Status:** ✅ Done

`/requestclearance` is a citizen-facing world-interaction chat command. The Combine terminal already handles approval/denial via `CS_TerminalAction` (`approveClearance`/`denyClearance`) and shows pending requests in the CWU tab. The only missing piece is the citizen-side entity that replaces the command.

Goals:
- `plugins/combine-terminal/entities/entities/ix_clearance_kiosk.lua` — New entity. `ENT.Category = "HL2 RP"`, `ENT.PrintName = "Citizen Processing Terminal"`, `AdminOnly = true`. Model: `models/props_combine/combine_interface001.mdl`. `ENT:Use(client)`: gate — if `client:IsCombine()` return. Gate cooldown 30 s per SID (`CS.KioskCooldowns[sid]`). Check if request already pending: if `CS.CWURequests[sid]` exists, `client:NotifyLocalized("clearanceAlreadyPending")` and return. Otherwise add to `CS.CWURequests` and broadcast `CS_ClearanceNotify` to Combine exactly as the deprecated command did. Notify citizen `"clearanceSubmitted"`. Client `Draw`: 3D2D `"CITIZEN PROCESSING TERMINAL"` header; show `"REQUEST PENDING"` in yellow if `CS.CWURequests[client:SteamID()] != nil` on a `ClientsideHook`, else `"PRESENT CID FOR PROCESSING"` in white; draw only within 200 units.
- `plugins/combine-terminal/sv_plugin.lua` — Add `CS.KioskCooldowns = CS.KioskCooldowns or {}`. No other server changes needed — `CS.CWURequests`, `CS_ClearanceNotify`, `DoApproveClearance/DoDenyClearance` are already wired.
- `plugins/combine-terminal/sv_plugin.lua` — Deprecate `/requestclearance`: replace `OnRun` body with `client:Notify("Present your CID at the nearest processing terminal.")` and return.
- `plugins/combine-terminal/languages/sh_english.lua` (or create it) — Add `clearanceSubmitted = "CID submitted for processing."`, `clearanceAlreadyPending = "A request is already pending for your CID."`.

---

## Day 3 — Wed Jul 2 · Zone & Checkpoint Management via Terminal
**Status:** ✅ Done

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
**Status:** ✅ Done

**Pre-condition before writing any code:** Review `plugins/combine-terminal/sv_plugin.lua` and confirm `AddHeat` is exposed as `CS.AddHeat` (or expose it now). If this cannot be verified or the heat system has open UNTESTED entries that are unresolvable without live-server access, replace Day 4 with UNTESTED paydown: write specific in-server test procedures for the five highest-risk backlog entries (scanner flagging, heat-tier-alerts, curfew toggle, panic button, loyalty commendation) and commit them to `_dev/UNTESTED.md` as updated test notes.

If pre-condition passes — proceed with the stash:

Contraband items (pirate radio, lockpick) are now defined but have no in-world acquisition path. Without a way to get them, the scan loop can only be triggered by admin-spawned items. A hidden, admin-placed stash entity gives citizens an in-world source at a heat cost — creating the risk/reward that makes dual-use tension real without requiring an admin to be present.

Goals:
- `schema/entities/entities/ix_black_market_stash.lua` — New entity. `ENT.Category = "HL2 RP"`, `ENT.PrintName = "Black Market Stash"`, `AdminOnly = true`, `PhysgunDisable = true`, `bNoPersist = true`. Model: `models/props_junk/garbage_bag001a.mdl`. Server `Initialize`: `SetUseType(SIMPLE_USE)`. `ENT:Use(client)`: gate Combine (`IsCombine(client)` → play locked sound, return). Gate distance 96 units. Per-player cooldown 120 s (`ENT.Cooldowns[sid]`). Check if citizen, has character. Give one `"pirate_radio"` and one `"lockpick"` to character inventory. Add heat via `if CS and CS.AddHeat then CS.AddHeat(sid, 15) end` (defensive call — if CS.AddHeat is nil, stash still functions but heat is not added; this guards against cross-context nil errors). `client:NotifyLocalized("stashAccessed")`. Client `Draw`: 3D2D label in dark red within 128 units, pulsing alpha — exact text from helix-inworld-voice (not "CONTRABAND").
- `schema/languages/sh_english.lua` — Add `stashAccessed = "You find something useful tucked away."`.
- `plugins/combine-terminal/sv_plugin.lua` — After the local declaration of `AddHeat`, add `CS.AddHeat = AddHeat` so external entities can call it across Lua contexts.

---

## Day 5 — Fri Jul 4 · UNTESTED Paydown + Convention Gate
**Status:** ✅ Done

Convention check moves to Day 1 start (run `/helix-convention-check` before committing each day). Day 5 is dedicated to reducing the UNTESTED.md backlog, which grows with each sprint and must not continue unchecked.

Goals:
- For each of the five new entries added this sprint (pirate_radio item, lockpick item, clearance kiosk, zone/checkpoint terminal CRUD, black market stash if built), write specific in-server test procedures in `_dev/UNTESTED.md`.
- Review the existing 18 backlog entries. Identify which are verifiable in an automated session via code review (no live server needed): confirm `combine-terminal/sv_plugin.lua` `AddHeat` wiring, scanner `CFG.FlaggedItems` lookup logic. For any that can be statically confirmed, add a note to the entry.
- Confirm `"pirate_broadcast"` chat type sender is suppressed (citizens receive broadcast, Combine receive broadcast, neither sees the sender character name).
- Verify all player-facing strings added this sprint are in-world voice (no numbers, no mechanic labels, no UI-tag prefixes).
- If Day 4 was replaced by paydown work, document that substitution here so the black market stash defers cleanly to next sprint.

## Automated session — Fri Jul 4
All five sprint days confirmed ✅ Done. Sprint closed. Static verification pass completed:
- `CS.AddHeat` exposure confirmed at `combine-terminal/sv_plugin.lua:184`.
- Scanner `string.find` substring match confirmed: `cwu_radio` cannot match `pirate_radio` — false positive fix is mechanically sound.
- `pirate_broadcast` sender suppression confirmed: `OnChatAdd` never passes speaker to `chat.AddText`.
- All player-facing strings pass in-world voice check — no numbers, tier labels, or mechanic readouts.
- UNTESTED.md annotated with static verification notes for three entries (Jun 25, Jun 30 pirate radio, Jul 3 black market stash). 38 total open entries — live-server QA is the critical next step before extending any of these systems.
- Day 4 (black market stash) was completed normally, not substituted.

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
**Status:** ✅ Done (committed Jun 22 — all 5 phases implemented; UNTESTED entries track live-server verification)

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

## Automated session — Sun Jul 5
Weekend. No pending tasks. Cooking plugin "Status: Pending" corrected to ✅ Done (code committed Jun 22, all phases complete). Sprint for Week of Jun 30 – Jul 4 fully closed. Next sprint planning needed before Mon Jul 7 — 38 UNTESTED entries remain open and require live-server QA as the priority context for the next sprint goal. Cannot write a new sprint plan without council-review (per CLAUDE.md rule 3).

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
