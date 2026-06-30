
AddCSLuaFile()

ENT.Type       = "anim"
ENT.PrintName  = "Citizen Processing Terminal"
ENT.Category   = "HL2 RP"
ENT.Spawnable  = true
ENT.AdminOnly  = true
ENT.bNoPersist = true

local USE_DIST  = 150
local DRAW_DIST = 200 * 200  -- squared
local COOLDOWN  = 30

if SERVER then
    function ENT:SpawnFunction(client, trace)
        local angles = (client:GetPos() - trace.HitPos):Angle()
        angles.p = 0
        angles.r = 0
        local ent = ents.Create("ix_clearance_kiosk")
        ent:SetPos(trace.HitPos + trace.HitNormal * 2)
        ent:SetAngles(angles)
        ent:Spawn()
        ent:Activate()
        return ent
    end

    function ENT:Initialize()
        self:SetModel("models/props_combine/combine_interface001.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
    end

    function ENT:Use(activator, caller)
        if !IsValid(activator) or !activator:IsPlayer() then return end
        if CS and CS.IsCombine and CS.IsCombine(activator) then return end
        if (activator:GetPos() - self:GetPos()):Length() > USE_DIST then return end
        if !activator:GetCharacter() then return end

        local sid = activator:SteamID()

        CS.KioskCooldowns = CS.KioskCooldowns or {}
        if (CS.KioskCooldowns[sid] or 0) > CurTime() then return end

        if CS.CWURequests and CS.CWURequests[sid] then
            activator:NotifyLocalized("clearanceAlreadyPending")
            return
        end

        CS.CWURequests[sid]     = {name = activator:Name(), ply = activator, time = CurTime()}
        CS.KioskCooldowns[sid]  = CurTime() + COOLDOWN

        local combinePlayers = CS.GetCombinePlayers and CS.GetCombinePlayers() or {}
        net.Start("CS_ClearanceNotify")
            net.WriteString(activator:Name())
            net.WriteString(sid)
        net.Send(combinePlayers)

        net.Start("CS_KioskPending")
            net.WriteBool(true)
        net.Send(activator)

        activator:NotifyLocalized("clearanceSubmitted")
    end

    function ENT:PhysgunPickup()
        return false
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()

        local lp = LocalPlayer()
        if !IsValid(lp) then return end
        if lp:GetPos():DistToSqr(self:GetPos()) > DRAW_DIST then return end

        local pending = KIOSK_PENDING == true
        local label   = pending and "REQUEST PENDING" or "PRESENT CID FOR PROCESSING"
        local col     = pending and Color(255, 220, 50) or Color(200, 200, 200)

        local pos    = self:GetPos() + self:GetForward() * 8 + self:GetUp() * 48
        local angles = self:GetAngles()
        angles:RotateAroundAxis(angles:Up(), 90)
        angles:RotateAroundAxis(angles:Forward(), 90)

        cam.Start3D2D(pos, angles, 0.08)
            surface.SetDrawColor(10, 10, 30, 200)
            surface.DrawRect(-100, -30, 200, 55)
            surface.SetDrawColor(50, 80, 130)
            surface.DrawOutlinedRect(-100, -30, 200, 55)
            draw.SimpleText("CITIZEN PROCESSING TERMINAL", "DermaDefault", 0, -12, Color(100, 160, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(label, "DermaDefault", 0, 10, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end
