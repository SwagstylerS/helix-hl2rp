# Scaffold: Interactive Entity (preferred for world mechanics)

Per CONVENTIONS.md, world mechanics belong on entities, not chat commands. Place at
`plugins/<name>/entities/ix_<thing>.lua` (autoloaded — no include) or, for a schema-wide
entity, `entities/entities/ix_<thing>.lua`.

Grounded in `plugins/combine-terminal/entities/entities/ix_combine_terminal.lua` and
`plugins/cwu/entities/ix_vendorterminal.lua`.

```lua
AddCSLuaFile()

ENT.Type      = "anim"
ENT.PrintName = "My Thing"
ENT.Category  = "HL2 RP"   -- REQUIRED: one Q-menu tab
ENT.Spawnable = true
ENT.AdminOnly = true       -- most schema entities are admin-spawned
ENT.bNoPersist = true      -- set false if it should save with the map

local MODEL     = "models/props_combine/combine_interface003.mdl"
local USE_DIST  = 150

function ENT:SetupDataTables()
    -- Networked vars create Get/Set automatically, e.g.:
    -- self:NetworkVar("Int", 0, "Mode")
end

if SERVER then
    function ENT:SpawnFunction(client, trace)
        local ang = (client:GetPos() - trace.HitPos):Angle()
        ang.p, ang.r = 0, 0
        local e = ents.Create("ix_<thing>")
        e:SetPos(trace.HitPos + trace.HitNormal * 2)
        e:SetAngles(ang)
        e:Spawn()
        e:Activate()
        return e
    end

    function ENT:Initialize()
        self:SetModel(MODEL)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if (IsValid(phys)) then phys:EnableMotion(false) end
    end

    function ENT:Use(activator, caller)
        if (!IsValid(activator) or !activator:IsPlayer()) then return end

        -- Gate access with the reusable meta helpers (do not reinvent faction checks):
        if (!activator:IsCombine()) then
            activator:Notify("Unauthorized.") -- prefer an in-world dispatch line; see voice-guide
            return
        end

        if ((activator:GetPos() - self:GetPos()):Length() > USE_DIST) then
            activator:Notify("You are too far away.")
            return
        end

        -- PREFERRED networking for new entities: netstream (auto-registers).
        netstream.Start(activator, "MyThingOpen", { foo = 1 })
        -- (combine-* family instead uses net.Start("CS_...") with a pooled string.)
    end

    function ENT:PhysgunPickup() return false end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end

    -- Optional hover tooltip (gate to the right audience):
    hook.Add("PopulateEntityInfo", "MyThing_Info", function(ent, tooltip)
        if (!IsValid(ent) or ent:GetClass() != "ix_<thing>") then return end
        local row = tooltip:AddRow("name")
        row:SetImportant()
        row:SetText("My Thing")
        row:SizeToContents()
    end)
end
```

## Notes
- All player-facing strings here must follow `voice-guide.md` (the `"Unauthorized."` in the
  real terminal is borderline-gamey debt — prefer a dispatch-voiced line for new code).
- Use `NetworkVar` for any state the client must see (mode, owner, status); client `Draw`/
  `HUDPaint` should react to `Get*()` getters.
