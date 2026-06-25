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
