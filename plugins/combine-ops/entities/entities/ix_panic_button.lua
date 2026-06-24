
AddCSLuaFile()

ENT.Type           = "anim"
ENT.PrintName      = "Panic Alarm"
ENT.Category       = "HL2 RP"
ENT.Spawnable      = true
ENT.AdminOnly      = true
ENT.PhysgunDisable = true
ENT.bNoPersist     = true

local PANIC_COOLDOWN = 600

function ENT:SetupDataTables()
    self:NetworkVar("Bool",   0, "Active")
    self:NetworkVar("String", 0, "OwnerSID")
end

if SERVER then
    local function GetAllCombine()
        local out = {}
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsCombine() then out[#out + 1] = ply end
        end
        return out
    end

    function ENT:Initialize()
        self:SetModel("models/props_combine/combine_button001.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end
        self:SetActive(false)
        self:SetOwnerSID("")
    end

    function ENT:Use(client)
        if !IsValid(client) or !client:IsPlayer() then return end
        if !client:IsCombine() then
            self:EmitSound("buttons/combine_button_locked.wav")
            client:Notify("Unauthorized.")
            return
        end

        CS             = CS             or {}
        CS.ActivePanics = CS.ActivePanics or {}
        CS.PanicTimers  = CS.PanicTimers  or {}

        local sid        = client:SteamID()
        local now        = CurTime()
        local combineAll = GetAllCombine()

        if CS.ActivePanics[sid] then
            CS.ActivePanics[sid] = nil
            self:SetActive(false)
            self:SetOwnerSID("")
            self:EmitSound("buttons/combine_button2.wav")
            if #combineAll > 0 then
                net.Start("CS_PanicClear")
                    net.WriteString(sid)
                net.Send(combineAll)
            end
        else
            if CS.PanicTimers[sid] and now < CS.PanicTimers[sid] + PANIC_COOLDOWN then
                local rem = math.ceil(CS.PanicTimers[sid] + PANIC_COOLDOWN - now)
                self:EmitSound("buttons/combine_button_locked.wav")
                client:Notify("Alarm on cooldown — " .. rem .. "s remaining.")
                return
            end
            CS.PanicTimers[sid]  = now
            CS.ActivePanics[sid] = {name = client:Name(), pos = client:GetPos(), time = now}
            self:SetActive(true)
            self:SetOwnerSID(sid)
            self:EmitSound("buttons/combine_button1.wav")
            if #combineAll > 0 then
                net.Start("CS_PanicAlert")
                    net.WriteString(sid)
                    net.WriteString(client:Name())
                    net.WriteVector(client:GetPos())
                net.Send(combineAll)
            end
        end
    end

    function ENT:SpawnFunction(client, trace)
        local ang = trace.HitNormal:Angle()
        ang:RotateAroundAxis(ang:Right(), 90)
        local entity = ents.Create("ix_panic_button")
        entity:SetPos(trace.HitPos + trace.HitNormal * 2)
        entity:SetAngles(ang)
        entity:Spawn()
        entity:Activate()
        PLUGIN:SavePanicButtons()
        return entity
    end

    function ENT:OnRemove()
        if !ix.shuttingDown then
            PLUGIN:SavePanicButtons()
        end
    end
else
    surface.CreateFont("ixPanicButton", {
        font      = "Default",
        size      = 18,
        weight    = 800,
        antialias = false,
    })

    function ENT:Draw()
        self:DrawModel()

        local ply = LocalPlayer()
        if !IsValid(ply) then return end
        if ply:GetPos():DistToSqr(self:GetPos()) > (256 * 256) then return end

        local isActive   = self:GetActive()
        local labelColor = isActive and Color(255, 50, 50) or Color(120, 120, 120)

        local pos = self:GetPos() + self:GetUp() * 8
        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Right(), -90)

        cam.Start3D2D(pos, ang, 0.04)
            draw.SimpleText("PANIC ALARM", "ixPanicButton", 0, 0, labelColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end
