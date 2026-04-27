# Server Direction

This document captures the server owner's vision as inferred from the codebase.
**Do not modify this file.** It is the source of truth for planning sessions.

---

## Vision

A faithful, atmospheric Half-Life 2 roleplay server built on the Helix framework.
The server aims to recreate City 17's oppressive dystopia through interlocking mechanical systems
rather than pure admin-mediation: players on all sides of the conflict should have meaningful,
rewarding things to do that create natural faction tension.

---

## Core Pillars

### 1 — Combine Intelligence Apparatus
The Metropolice and OTA operate an active surveillance state.
- Scanner device (battery-gated, quotas) + intel terminal (warrants, heat tiers, zones)
- Checkpoint forcefields that physically block citizens based on clearance level and warrant status
- Panic/alert/curfew system for Combine-side operational RP
- Citizen heat score that rises through suspicious behaviour and decays over time

### 2 — Civil Workers Union (CWU) Economy
The CWU is the civilian economic middleware between Combine control and the citizen underclass.
Four active divisions with distinct mechanics:
- **Production** — blueprint crafting at the production table (material → item conversion)
- **Maintenance** — repair of degrading infrastructure (breakable lights, doors, terminals, pipes)
- **Medical** — patient treatment and chemical synthesis (legitimate medicine + dual-use drugs)
- **Commerce** — vendor terminal operation, business licences, taxed trade
Director manages assignments, blueprints, licences, and the CWU treasury.

### 3 — Loyalty Progression
CWU workers earn loyalty (Tiers 0–5) by completing division work.
Higher loyalty unlocks advanced blueprints, promotion eligibility, and Director trust.
Loyalty is a persistent incentive layer that rewards sustained play.

### 4 — Infrastructure Degradation
Breakable infrastructure entities (lights, doors, terminals, pipes) degrade passively on a timer.
Degraded assets generate work orders on the board.
Maintenance workers repair them using repair kits, completing the work order and earning loyalty.
This creates a living world that reacts to neglect and rewards upkeep.

### 5 — Dual-Use Tension
The Medical division can synthesise both legitimate medicine (stimpaks) and illicit compounds
(combat stimulants, recreational chemicals). These are logged as "Medical Compound" — plausible
deniability is intentional. Combine scanners can flag illicit items, raising citizen heat.

---

## Plugins (current)
| Plugin | Purpose |
|---|---|
| `combine-terminal` | Intel terminal entity, warrants, heat system, zones, clearance |
| `combine-scanner` | Scanner device, battery, charger, biometric scan HUD |
| `combine-ops` | Panic signals, alerts, curfew, detainee management |
| `checkpoint` | Energy forcefield entity with clearance modes and warrant alarms |
| `cwu` | CWU division system, all entities, blueprint crafting, infrastructure |
| `writing` | Writable item system (third-party, minimal customisation) |

---

## Conventions (observed)
- Shared files: `sh_*.lua` | Server: `sv_*.lua` | Client: `cl_*.lua`
- Plugins declare in `sh_plugin.lua`; include `sv_hooks.lua` / `cl_hooks.lua` for Helix hooks
- Networking: `netstream.Start` / `netstream.Hook` (not raw `net.*`) for plugin traffic
- Persistence: `ix.data.Set` / `ix.data.Get`
- Currency: `character:GiveMoney` / `character:TakeMoney`
- Character data: `character:GetData` / `character:SetData`
- Entity categories use `"HL2 RP"` so they appear under one Q-menu tab
- Localisation strings live in `plugins/<name>/languages/sh_english.lua`
