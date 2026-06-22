AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Cooking Stove"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true

-- States: 0 = idle, 1 = cooking, 2 = done
ENT.CookType = "pot"
ENT.MaxRenderDistance = math.pow(256, 2)

function ENT:SetupDataTables()
	self:NetworkVar("Int",    0, "State")
	self:NetworkVar("Float",  0, "CookEnd")
	self:NetworkVar("Float",  1, "CookDuration")
	self:NetworkVar("String", 0, "CookName")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_lab/cremator_table001a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if (IsValid(phys)) then phys:EnableMotion(false); phys:Sleep() end

		self.nextUseTime = 0
		self:SetState(0)
	end

	function ENT:SpawnFunction(client, trace)
		local ent = ents.Create("ix_cookingstove")
		ent:SetPos(trace.HitPos + Vector(0, 0, 16))
		ent:SetAngles(Angle(0, (ent:GetPos() - client:GetPos()):Angle().y - 180, 0))
		ent:Spawn()
		ent:Activate()
		return ent
	end

	function ENT:Use(client)
		if (self.nextUseTime > CurTime()) then return end
		self.nextUseTime = CurTime() + 1
		PLUGIN:HandleStationUse(self, client)
	end
else
	surface.CreateFont("ixCookingStation", {
		font = "Default", size = 20, weight = 800, antialias = false
	})
	surface.CreateFont("ixCookingStationSm", {
		font = "Default", size = 14, weight = 600, antialias = false
	})

	function ENT:Draw()
		self:DrawModel()

		local pos = self:GetPos()
		if (LocalPlayer():GetPos():DistToSqr(pos) > self.MaxRenderDistance) then return end

		local ang = self:GetAngles()
		ang:RotateAroundAxis(ang:Up(), 90)
		ang:RotateAroundAxis(ang:Forward(), 90)

		cam.Start3D2D(pos + self:GetUp() * 50 + self:GetForward() * -5, ang, 0.07)
			render.PushFilterMin(TEXFILTER.NONE)
			render.PushFilterMag(TEXFILTER.NONE)

			local state = self:GetState()

			surface.SetDrawColor(20, 20, 20)
			surface.DrawRect(-100, -30, 200, 60)
			surface.SetDrawColor(60, 60, 60)
			surface.DrawOutlinedRect(-100, -30, 200, 60)

			if (state == 0) then
				draw.SimpleText("STOVE", "ixCookingStation", 0, -10, Color(150, 180, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("IDLE", "ixCookingStationSm", 0, 10, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			elseif (state == 1) then
				local progress = 1 - math.max(0, (self:GetCookEnd() - CurTime()) / self:GetCookDuration())
				draw.SimpleText("COOKING", "ixCookingStation", 0, -15, Color(255, 160, 30), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				surface.SetDrawColor(40, 40, 40)
				surface.DrawRect(-80, 5, 160, 12)
				surface.SetDrawColor(100, 160, 220)
				surface.DrawRect(-80, 5, 160 * progress, 12)
				draw.SimpleText(self:GetCookName(), "ixCookingStationSm", 0, -2, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			elseif (state == 2) then
				local alpha = math.abs(math.cos(RealTime() * 3) * 255)
				draw.SimpleText("DONE", "ixCookingStation", 0, -10, ColorAlpha(Color(0, 220, 0), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("PRESS E TO COLLECT", "ixCookingStationSm", 0, 10, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			render.PopFilterMin()
			render.PopFilterMag()
		cam.End3D2D()
	end
end
