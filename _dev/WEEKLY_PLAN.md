# Weekly Development Plan
**Week of Apr 28 – May 2, 2026**
**Goal:** Close the CWU reward loop — loyalty progression, work-order interactivity, and blueprint approval so all four divisions have a complete play cycle.

---

## Day 1 — Mon Apr 28 · Loyalty Reward Loop

**Status:** ✅ Complete

Goals:
- `plugins/cwu/libs/sh_loyalty.lua` — add `PLUGIN:AwardLoyalty(character, amount, reason)` that increments a persistent point accumulator (`loyaltyPoints`) and auto-promotes tier when threshold is crossed (e.g. every 10 points = +1 tier, capped at 5); notify the player on tier-up
- `plugins/cwu/libs/sv_workorders.lua` — extend `CompleteWorkOrder(entityIndex, character)` with an optional `character` param; call `PLUGIN:AwardLoyalty(character, 2, "repair")` when a character is supplied
- `plugins/cwu/entities/ix_breakable_light.lua`, `ix_breakable_door.lua`, `ix_breakable_pipe.lua`, `ix_breakable_terminal.lua` — pass `client:GetCharacter()` as second arg in each `PLUGIN:CompleteWorkOrder` call inside the `Use` DoStaredAction callback
- `plugins/cwu/entities/ix_vendorterminal.lua` — in the `CWUVendorPurchase` netstream handler, after the sale is logged, call `PLUGIN:AwardLoyalty` on the terminal owner's character (look up by `GetOwnerCharID`) with 1 point per sale
- `plugins/cwu/entities/ix_medicalworkstation.lua` — add `PLUGIN:AwardLoyalty(client:GetCharacter(), 2, "treatment")` in the `DoStaredAction` success callbacks for `CWUMedicalTreatBasic` and `CWUMedicalSurgery`, and 1 point in `CWUMedicalSynthMedicine`
- `plugins/cwu/languages/sh_english.lua` — add strings: `cwuLoyaltyGained`, `cwuTierUp`

---

## Day 2 — Tue Apr 29 · Work Order Self-Assignment

**Status:** Pending

Goals:
- `plugins/cwu/libs/sv_workorders.lua` — add `PLUGIN:ClaimWorkOrder(orderID, charName)` that sets `order.assignedTo = charName` and saves/refreshes boards; add `PLUGIN:ManualCompleteWorkOrder(orderID, character)` for orders that have no linked entity (manual or already-removed entity), awards loyalty and marks complete
- `plugins/cwu/entities/ix_workorderboard.lua` — add `netstream.Hook("CWUWorkOrderClaim", ...)` (validates CWU Maintenance/Director, calls `ClaimWorkOrder`); add `netstream.Hook("CWUWorkOrderComplete", ...)` (validates claimant matches character, calls `ManualCompleteWorkOrder`)
- `plugins/cwu/derma/cl_workorderboard.lua` — rebuild `SetOrders` to use a scrollable `DScrollPanel` with per-row panels; each row gets a "CLAIM" button (disabled if already assigned) and a "DONE" button (only enabled when `order.assignedTo` matches the local character name); send `CWUWorkOrderClaim` / `CWUWorkOrderComplete` via netstream on click
- `plugins/cwu/languages/sh_english.lua` — add strings: `cwuWorkOrderClaimed`, `cwuWorkOrderAlreadyClaimed`, `cwuWorkOrderCompleted`

---

## Day 3 — Wed Apr 30 · Manual Work Order Submission

**Status:** Pending

Goals:
- `plugins/cwu/sh_plugin.lua` — register `/CWUSubmitOrder` command (arguments: `ix.type.text` for description, `ix.type.text` for location); restrict to Maintenance and Director divisions; call `PLUGIN:SubmitManualWorkOrder` with a priority of 2 and the character's name as submitter; notify success with `cwuWorkOrderSubmitted`
- `plugins/cwu/entities/ix_workorderboard.lua` — add `netstream.Hook("CWUWorkOrderSubmit", ...)` server handler that validates Director/admin access, accepts `{description, location, priority}`, calls `PLUGIN:SubmitManualWorkOrder`, and refreshes boards
- `plugins/cwu/derma/cl_workorderboard.lua` — add a "Submit Order" footer section visible only to `client:IsCWUDirector()` or admin; two `DTextEntry` fields (Description, Location) plus a `DComboBox` for priority (Low/Medium/High); "SUBMIT" button sends `CWUWorkOrderSubmit` via netstream
- `plugins/cwu/libs/sv_workorders.lua` — add `PLUGIN:CleanCompletedWorkOrders()` auto-trim: call it at the end of `SaveWorkOrders` whenever the list exceeds `cwuMaxTransactions` config, removing oldest completed entries first

---

## Day 4 — Thu May 1 · CWU Combine Terminal Polish

**Status:** Pending

Goals:
- `plugins/cwu/entities/ix_cwu_combine_terminal.lua` — audit current `Use` handler; ensure the payload sent to Combine includes both CWU roster (division, tier, name) and breakable infrastructure status (broken count per type, sourced from `ents.FindByClass` for each `PLUGIN.BreakableTypes` key)
- `plugins/cwu/derma/cl_cwu_combine_terminal.lua` — verify both the Roster tab and the Infrastructure tab render correctly; if the infrastructure tab is missing, add it: a scrollable list of breakable type + broken count + repair status, colour-coded red (broken) / green (operational)
- `plugins/cwu/entities/ix_cwu_combine_terminal.lua` — add `netstream.Hook("CWUCombineTerminalAction", ...)` to allow Combine to flag a CWU member (sets `character:SetData("combineFlag", true)`) and send a biometric alert via `CS_BiometricAlert` — this mirrors the Director PC's audit powers from the Combine side
- `plugins/cwu/languages/sh_english.lua` — add strings: `cwuMemberFlagged`, `cwuInfrastructureStatus` (if missing)

---

## Day 5 — Fri May 2 · Blueprint Approval Request Flow

**Status:** Pending

Goals:
- `plugins/cwu/entities/ix_productiontable.lua` — in the `Use` handler, after building `availableBlueprints`, for tier-2 blueprints where `canUse == false`, include a `requestable = true` field; add `netstream.Hook("CWURequestBlueprintApproval", ...)` server handler that validates the requesting character is Production/Director, records the request in `ix.data` under `"cwuBlueprintRequests"` as `{charID, charName, blueprintID, time}`, and notifies online Directors/admins
- `plugins/cwu/entities/ix_cwu_director_pc.lua` — include pending blueprint requests in the `Use` payload by reading `ix.data.Get("cwuBlueprintRequests", {})`; add `netstream.Hook("CWUBlueprintApprove", ...)` that sets `character:SetData("approved_bp_" .. blueprintID, true)` and removes the request; add `netstream.Hook("CWUBlueprintRevoke", ...)` that clears the flag
- `plugins/cwu/derma/cl_productiontable.lua` — for tier-2 rows with `requestable = true`, change the button label to "Request Approval" and send `CWURequestBlueprintApproval` instead of `CWUProductionStart`; show a pending indicator if a request is already in flight (store flag in `ix.gui`)
- `plugins/cwu/derma/cl_cwu_director_pc.lua` — add a "Blueprint Requests" section (or tab) listing `cwuBlueprintRequests`; each row shows character name + blueprint name + time, with APPROVE and REVOKE buttons wired to the new netstream hooks
- `plugins/cwu/languages/sh_english.lua` — add strings: `cwuBlueprintRequested`, `cwuBlueprintApprovalPending`, `cwuNoPendingRequests`
