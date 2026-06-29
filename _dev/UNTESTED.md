# Untested Code

Code committed in remote sessions that has not yet been verified on a live server.

**Adding an entry:** append a row when committing a new feature or fix. Include the minimum
concrete test that would let you confidently remove the entry.

**Removing an entry:** delete the row after a live-server session confirms the behaviour.
Note the verification date and who ran it in the commit message (`verify: <feature> confirmed`).

---

| Date | Feature | Key files | What to verify on a live server |
|------|---------|-----------|----------------------------------|
| Jun 19 | Curfew checkpoint auto-lockdown | `combine-ops/sv_plugin.lua` | Toggle curfew; confirm `ix_checkpoint` entities switch to mode 3; confirm they restore previous modes when curfew is lifted. |
| Jun 19 | Union Exemplar (Tier 5) vendor tax discount | `cwu/entities/ix_vendorterminal.lua`, `cwu/sh_plugin.lua` | Have a Tier 5 character own a vendor terminal; confirm tax deducted at 50% of base rate on purchase. |
| Jun 19 | Tier 4 senior-worker tax discount | `cwu/entities/ix_vendorterminal.lua` | Have a Tier 4 character own a vendor; confirm 25% tax reduction applied. |
| Jun 19 | Vendor out-of-stock / Commerce Inventory tab | `cwu/entities/ix_cwu_director_pc.lua`, `cwu/derma/cl_cwu_director_pc.lua` | Open Director PC; confirm Vendor Stock tab lists all placed vendor terminals with stock counts and DEPLETED/LOW/STOCKED status. |
| Jun 20 | Infrastructure degradation timer | `cwu/libs/sv_infrastructure.lua` | Confirm `CWUDegradation` timer fires every 5 min (default); breakable entities transition to broken state and generate work orders on `ix_workorderboard`. |
| Jun 20 | Medical injury system | `cwu/libs/sv_injury.lua` | Enable `medicalInjuries 1`; take damage → wound appears; bleed tick drains HP; leg wound causes walk-speed reduction; bandage seals (80% chance) or rebleeds (20%); surgery at `ix_medicalworkstation` clears all wounds and restores walk speed. |
| Jun 20 | Surgery wipe-injury bug fix | `cwu/entities/ix_medicalworkstation.lua` | Run surgery on a patient with leg wound; confirm limp and bleed vignette both clear after completion. |
| Jun 23 | Injury → heat scanner integration | `combine-scanner/sv_plugin.lua` | Scan a citizen who has a bleeding wound; confirm heat score increases by 15 before the scan result is shown. |
| Jun 23 | Detain/release via terminal | `combine-terminal/sv_plugin.lua`, `combine-terminal/derma/cl_tab_detainees.lua` | Open terminal Detainees tab as a Combine officer; log a detention for an online citizen; confirm entry appears with DETAINED status; log a release; confirm status updates to RELEASED. Verify `cs_detainees` persists across map restart. |
| Jun 24 | Curfew toggle on terminal | `combine-terminal/sv_plugin.lua`, `combine-terminal/derma/cl_tab_units.lua` | As a senior Combine, open terminal Units tab; confirm CURFEW CONTROL section is visible; toggle curfew; confirm checkpoints lock; toggle again; confirm restore. Non-senior officer must not see the section. |
| Jun 24 | Panic button wall entity | `combine-ops/entities/entities/ix_panic_button.lua`, `combine-ops/sv_plugin.lua` | Admin-spawn `ix_panic_button`; as a Combine officer, press E to trigger panic; confirm alert to all Combine; press E again to clear; confirm auto-expire after cooldown. Verify position saved and reloads on map restart. |
| Jun 25 | Scanner `pirate_radio` flag fix | `combine-scanner/sv_plugin.lua`, `combine-terminal/sv_plugin.lua` | Scan a CWU worker carrying `cwu_radio`; confirm scan returns clean (no contraband flag). |
| Jun 26 | Loyalty: Combine terminal commendation | `cwu/entities/ix_cwu_combine_terminal.lua`, `cwu/derma/cl_cwu_combine_terminal.lua` | As a Combine officer at the CWU terminal, open Roster tab; select a CWU member; set amount 1–5; click Issue Commendation; confirm target's loyalty score increases by that amount. |
| Jun 26 | Loyalty: removed automatic awards | `cwu/libs/sv_workorders.lua`, `cwu/entities/ix_productiontable.lua`, `cwu/entities/ix_medicalworkstation.lua` | Complete a work order, craft an item, and run a synthesis; confirm no loyalty is awarded automatically in any of these flows. |
| Jun 28 | Cooking hunger system | `cooking/libs/sv_hunger.lua`, `cooking/cl_plugin.lua` | Enable cooking plugin; let hunger drain over time; at ≥50 confirm in-world cue; at ≥75 confirm starvation cue and HP drain (floor 20 HP). Eat food item; confirm hunger drops. |
| Jun 28 | Cooking stations + minigame | `cooking/entities/ix_cookingfireplace.lua`, `cooking/entities/ix_cookingstove.lua`, `cooking/derma/cl_cooking.lua` | Place fireplace and stove; approach as citizen with ingredients; confirm recipe picker opens; play through minigame interactions (stir, flip, season, skim, poke, turn); confirm good play yields cooked item, poor play yields charred variant. |
| Jun 28 | Heat tier 4 alert to Combine | `combine-terminal/sv_plugin.lua` (`AddHeat`) | Manually push a citizen's heat to Tier 4; confirm `CS_BiometricAlert` broadcast fires and all online Combine receive the dispatch ChatPrint. |
| Jun 28 | Heat decay timer | `combine-terminal/sv_plugin.lua` (`CS_HeatDecay`) | Confirm heat decreases by 1 every 60 s (default); confirm sterilized citizens do not decay below `HeatDecayFloor`. |
| Jun 30 | Pirate radio item + pirate_broadcast chat type | `schema/items/contraband/sh_pirate_radio.lua`, `schema/sh_schema.lua`, `schema/sv_schema.lua`, `schema/cl_schema.lua` | Admin-give `pirate_radio` to a citizen; Toggle → confirm "Carrier signal acquired." notify; Broadcast → confirm Derma_StringRequest opens; submit text → confirm `~~ text ~~` message appears for all players within 600 units; Combine can see the message but sender is not identified. Toggle off → "No carrier signal." notify; Broadcast while off → same notify, no dialog. |
| Jun 30 | Lockpick item | `schema/items/contraband/sh_lockpick.lua` | Admin-give `lockpick`; confirm item appears in inventory; scan citizen carrying lockpick → confirm scanner flags the item as contraband (uniqueID `"lockpick"` matches `CFG.FlaggedItems`). |
