
AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Combine Terminal"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.bNoPersist = true

local TERMINAL_MODEL = "models/props_combine/combine_interface003.mdl"
local USE_DIST = 150

function ENT:SetupDataTables()
end

if SERVER then
    function ENT:SpawnFunction(client, trace)
        local angles = (client:GetPos() - trace.HitPos):Angle()
        angles.p = 0
        angles.r = 0

        local entity = ents.Create("ix_combine_terminal")
        entity:SetPos(trace.HitPos + trace.HitNormal * 2)
        entity:SetAngles(angles)
        entity:Spawn()
        entity:Activate()

        return entity
    end

    function ENT:Initialize()
        self:SetModel(TERMINAL_MODEL)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end
    end

    function ENT:Use(activator, caller)
        if !IsValid(activator) or !activator:IsPlayer() then return end

        local isCombine = CS and CS.IsCombine and CS.IsCombine(activator)
        if !isCombine then
            activator:Notify("Unauthorized.")
            return
        end

        if (activator:GetPos() - self:GetPos()):Length() > USE_DIST then
            activator:Notify("You are too far from the terminal.")
            return
        end

        local payload  = CS.BuildFullPayload()
        local isSenior = CS.IsSenior(activator)
        local json     = util.TableToJSON(payload)
        net.Start("CS_TerminalOpen")
            net.WriteString(json)
            net.WriteBool(isSenior)
        net.Send(activator)
    end

    function ENT:PhysgunPickup()
        return false
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end

    hook.Add("ShouldPopulateEntityInfo", "CS_CombineTerminal_EntityInfo", function(ent)
        if !IsValid(ent) or ent:GetClass() != "ix_combine_terminal" then return end
        if IsValid(CS_TerminalFrame) then return false end
        local ply = LocalPlayer()
        if !IsValid(ply) then return end
        if ply:Team() != FACTION_OTA and !ply:IsCombine() then return end
        return true
    end)

    hook.Add("PopulateEntityInfo", "CS_CombineTerminal_EntityInfo", function(ent, tooltip)
        if !IsValid(ent) or ent:GetClass() != "ix_combine_terminal" then return end
        local ply = LocalPlayer()
        if !IsValid(ply) then return end
        if ply:Team() != FACTION_OTA and !ply:IsCombine() then return end

        local title = tooltip:AddRow("name")
        title:SetImportant()
        title:SetText("Combine Terminal")
        title:SetBackgroundColor(Color(50, 180, 50))
        title:SizeToContents()
        local desc = tooltip:AddRow("description")
        desc:SetText("Access classified scan records and citizen database.")
        desc:SizeToContents()
        tooltip:SetArrowColor(Color(50, 180, 50))
    end)
end
