
AddCSLuaFile()

ENT.Type           = "anim"
ENT.PrintName      = "Scanner Charger"
ENT.Category       = "HL2 RP"
ENT.Spawnable      = true
ENT.AdminOnly      = true
ENT.PhysgunDisable = true
ENT.bNoPersist     = true

local USE_DIST  = 96
local DRAW_DIST = 200 * 200

if SERVER then
    function ENT:SpawnFunction(client, trace)
        local angles = (client:GetPos() - trace.HitPos):Angle()
        angles.p = 0
        angles.r = 0
        local ent = ents.Create("ix_scanner_charger")
        ent:SetPos(trace.HitPos + trace.HitNormal * 2)
        ent:SetAngles(angles)
        ent:Spawn()
        ent:Activate()
        ix.data.Set("cs_charger_" .. game.GetMap(), {pos = ent:GetPos(), ang = ent:GetAngles()})
        if CS and CS.SyncChargerToAll then CS.SyncChargerToAll() end
        return ent
    end

    function ENT:Initialize()
        self:SetModel("models/props_combine/combine_charger001.mdl")
        self:SetName("ix_scanner_charger")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end
        CS = CS or {}
        CS._ChargerEnt = self
    end

    function ENT:Use(activator, caller)
        if !IsValid(activator) or !activator:IsPlayer() then return end
        if !activator:IsCombine() then
            self:EmitSound("buttons/combine_button_locked.wav")
            return
        end
        if CS and CS.HandleChargerUse then
            CS.HandleChargerUse(activator, self:EntIndex())
        end
    end

    function ENT:OnRemove()
        if ix.shuttingDown then return end
        CS = CS or {}
        if CS._ChargerEnt == self then CS._ChargerEnt = nil end
        ix.data.Set("cs_charger_" .. game.GetMap(), nil)
        if CS.SyncChargerToAll then CS.SyncChargerToAll() end
    end

    function ENT:PhysgunPickup()
        return false
    end
end

if CLIENT then
    surface.CreateFont("ixChargerLabel", {
        font      = "Default",
        size      = 16,
        weight    = 600,
        antialias = false,
    })

    function ENT:Draw()
        self:DrawModel()
        local lp = LocalPlayer()
        if !IsValid(lp) then return end
        if lp:GetPos():DistToSqr(self:GetPos()) > DRAW_DIST then return end

        local nearCombine = false
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsCombine() and ply:GetPos():DistToSqr(self:GetPos()) < USE_DIST * USE_DIST then
                nearCombine = true
                break
            end
        end

        local col
        if nearCombine then
            col = Color(255, 140 + math.floor(math.abs(math.sin(CurTime() * 3)) * 115), 0)
        else
            col = Color(0, 255, 0)
        end

        local pos = self:GetPos() + self:GetForward() * 4 + self:GetUp() * 40
        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Forward(), 90)

        cam.Start3D2D(pos, ang, 0.08)
            surface.SetDrawColor(10, 20, 10, 180)
            surface.DrawRect(-80, -20, 160, 40)
            draw.SimpleText("SCANNER CHARGE", "ixChargerLabel", 0, 0, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end
