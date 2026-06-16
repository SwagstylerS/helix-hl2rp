# Scaffold: Faction / Class

## Faction — `schema/factions/sh_<name>.lua`
Grounded in `schema/factions/sh_cwu.lua`.
```lua
FACTION.name        = "Civil Workers Union"
FACTION.description = "A civil worker employed under the Universal Union's CWU programme."
FACTION.color       = Color(100, 175, 100)
FACTION.isDefault   = false   -- true only for the default joinable faction (citizen)

function FACTION:OnCharacterCreated(client, character)
    local id = Schema:ZeroNumber(math.random(1, 99999), 5)
    local inventory = character:GetInventory()

    character:SetData("cid", id)
    inventory:Add("suitcase", 1)
    inventory:Add("cid", 1, { name = character:GetName(), id = id })
end

-- REQUIRED trailing global alias so other files can reference the index:
FACTION_CWU = FACTION.index
```
Existing factions / globals: `FACTION_CITIZEN`, `FACTION_CWU`, `FACTION_MPF`, `FACTION_OTA`,
plus an administrator faction. Note `IsCombine()` checks `FACTION_MPF` / `FACTION_OTA`.

## Class — `schema/classes/sh_<name>.lua`
Classes belong to a faction; expose a `CLASS_<NAME>` global the same way.
```lua
CLASS.name    = "Production Worker"
CLASS.faction = FACTION_CWU
-- CLASS.isDefault = true   -- default class for the faction
-- CLASS.limit = 0          -- optional player cap

function CLASS:OnCanBe(client)
    return true -- gate eligibility here
end

CLASS_CWU_PRODUCTION = CLASS.index
```
Existing class globals include `CLASS_CITIZEN`, `CLASS_CWU`, `CLASS_CWU_PRODUCTION`,
`CLASS_CWU_MAINTENANCE`, `CLASS_CWU_MEDICAL`, `CLASS_CWU_COMMERCE`, `CLASS_CWU_DIRECTOR`,
and the metropolice / overwatch classes. Reuse `playerMeta:GetCWUDivision()` rather than
re-deriving division from class.

## Notes
- Both files are autoloaded from `schema/factions/` and `schema/classes/` — no include.
- Always set the trailing global alias; lots of code references `FACTION_*` / `CLASS_*`.
