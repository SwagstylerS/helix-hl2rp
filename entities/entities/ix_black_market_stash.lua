
AddCSLuaFile()

ENT.Type           = "anim"
ENT.PrintName      = "Black Market Stash"
ENT.Category       = "HL2 RP"
ENT.Spawnable      = true
ENT.AdminOnly      = true
ENT.PhysgunDisable = true
ENT.bNoPersist     = true

local USE_DIST  = 96
local DRAW_DIST = 128 * 128
local COOLDOWN  = 120

if SERVER then
    function ENT:SpawnFunction(client, trace)
        local ent = ents.Create("ix_black_market_stash")
        ent:SetPos(trace.HitPos + trace.HitNormal * 2)
        ent:SetAngles(trace.HitNormal:Angle())
        ent:Spawn()
        ent:Activate()
        return ent
    end

    function ENT:Initialize()
        self:SetModel("models/props_junk/garbage_bag001a.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self.Cooldowns = {}
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end
    end

    function ENT:Use(activator, caller)
        if !IsValid(activator) or !activator:IsPlayer() then return end
        if activator:IsCombine() then
            self:EmitSound("buttons/button10.wav")
            return
        end
        if (activator:GetPos() - self:GetPos()):Length() > USE_DIST then return end

        local char = activator:GetCharacter()
        if !char then return end

        local sid = activator:SteamID()
        self.Cooldowns = self.Cooldowns or {}
        if (self.Cooldowns[sid] or 0) > CurTime() then return end
        self.Cooldowns[sid] = CurTime() + COOLDOWN

        local inv = char:GetInventory()
        if inv then
            inv:Add("pirate_radio", 1)
            inv:Add("lockpick", 1)
        end

        if CS and CS.AddHeat then CS.AddHeat(sid, 15) end

        activator:NotifyLocalized("stashAccessed")
    end
end

if CLIENT then
    surface.CreateFont("ixStashLabel", {
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

        local pos = self:GetPos() + self:GetUp() * 20
        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Right(), -90)

        cam.Start3D2D(pos, ang, 0.05)
            draw.SimpleText("CACHE", "ixStashLabel", 0, 0, Color(160, 30, 30), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end
