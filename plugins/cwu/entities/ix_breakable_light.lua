AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Breakable Streetlight"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true

ENT.IsCWUBreakable = true
ENT.BreakableType = "light"
ENT.DegradeChance = 15
ENT.RepairPriority = 1

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Broken")
	self:NetworkVar("Float", 0, "BreakTime")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_wasteland/light_spotlight01_lamp.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self:SetBroken(false)
		self:CreateLight()
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_breakable_light")

		entity:SetPos(trace.HitPos + Vector(0, 0, 128))
		entity:SetAngles(Angle(0, 0, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:CreateLight()
		if (IsValid(self.lightEntity)) then
			self.lightEntity:Remove()
		end

		self.lightEntity = ents.Create("light_dynamic")
		self.lightEntity:SetPos(self:GetPos() - Vector(0, 0, 16))
		self.lightEntity:SetKeyValue("brightness", "5")
		self.lightEntity:SetKeyValue("distance", "512")
		self.lightEntity:SetKeyValue("_light", "255 255 200")
		self.lightEntity:Spawn()
		self.lightEntity:Fire("TurnOn")
		self:DeleteOnRemove(self.lightEntity)
	end

	function ENT:OnBreak()
		if (IsValid(self.lightEntity)) then
			self.lightEntity:Fire("TurnOff")
		end

		self:EmitSound("physics/metal/metal_box_break1.wav", 60)
	end

	function ENT:OnRepair()
		if (IsValid(self.lightEntity)) then
			self.lightEntity:Fire("TurnOn")
		else
			self:CreateLight()
		end

		self:EmitSound("buttons/lever7.wav")
	end

	function ENT:Use(client)
		if (!self:GetBroken()) then
			client:NotifyLocalized("cwuAlreadyWorking")
			return
		end

		local division = client:GetCWUDivision()

		if (division != "maintenance" and division != "director") then
			client:NotifyLocalized("cwuNotMaintenance")
			return
		end

		local inventory = client:GetCharacter():GetInventory()
		local repairKit = inventory:HasItem("repair_kit")

		if (!repairKit) then
			client:NotifyLocalized("cwuNeedRepairKit")
			return
		end

		client:SetAction("@cwuRepairing", 5)

		client:DoStaredAction(self, function()
			if (!IsValid(self) or !self:GetBroken()) then
				return
			end

			-- Consume repair kit
			local kit = client:GetCharacter():GetInventory():HasItem("repair_kit")

			if (kit) then
				kit:Remove()
			end

			self:SetBroken(false)
			self:OnRepair()
			client:NotifyLocalized("cwuRepairComplete")

			PLUGIN:CompleteWorkOrder(self:EntIndex())
		end, 5, function()
			if (IsValid(client)) then
				client:SetAction()
			end
		end)
	end

	function ENT:OnRemove()
		if (!ix.shuttingDown) then
			PLUGIN:SaveBreakables()
		end
	end
else
	function ENT:Draw()
		self:DrawModel()

		if (self:GetBroken()) then
			local position = self:GetPos()
			local angles = self:GetAngles()

			angles:RotateAroundAxis(angles:Up(), 90)
			angles:RotateAroundAxis(angles:Forward(), 90)

			cam.Start3D2D(position + Vector(0, 0, -8), angles, 0.05)
				local alpha = math.abs(math.cos(RealTime() * 2) * 255)
				draw.SimpleText("BROKEN", "DermaDefaultBold", 0, 0, ColorAlpha(Color(255, 0, 0), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End3D2D()
		end
	end
end
