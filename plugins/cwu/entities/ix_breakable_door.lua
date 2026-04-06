AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Breakable Door Mechanism"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true

ENT.IsCWUBreakable = true
ENT.BreakableType = "door"
ENT.DegradeChance = 5
ENT.RepairPriority = 3

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Broken")
	self:NetworkVar("Float", 0, "BreakTime")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_combine/combine_lock01.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self:SetBroken(false)
		self.linkedDoor = nil
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_breakable_door")

		entity:SetPos(trace.HitPos + Vector(0, 0, 40))
		entity:Spawn()
		entity:Activate()

		-- Try to link to nearest door
		local nearestDoor = nil
		local nearestDist = 128

		for _, ent in ipairs(ents.GetAll()) do
			if (ent:IsDoor() and ent:GetPos():Distance(entity:GetPos()) < nearestDist) then
				nearestDist = ent:GetPos():Distance(entity:GetPos())
				nearestDoor = ent
			end
		end

		if (IsValid(nearestDoor)) then
			entity.linkedDoor = nearestDoor
		end

		return entity
	end

	function ENT:OnBreak()
		if (IsValid(self.linkedDoor)) then
			self.linkedDoor:Fire("Unlock")
			self.linkedDoor:Fire("Open")
			self.linkedDoor:SetKeyValue("speed", "0")
		end

		self:EmitSound("physics/metal/metal_box_break2.wav", 60)
	end

	function ENT:OnRepair()
		if (IsValid(self.linkedDoor)) then
			self.linkedDoor:SetKeyValue("speed", "100")
			self.linkedDoor:Fire("Close")
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

		if (!inventory:HasItem("repair_kit")) then
			client:NotifyLocalized("cwuNeedRepairKit")
			return
		end

		client:SetAction("@cwuRepairing", 5)

		client:DoStaredAction(self, function()
			if (!IsValid(self) or !self:GetBroken()) then
				return
			end

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

			cam.Start3D2D(position + self:GetForward() * 3, angles, 0.04)
				local alpha = math.abs(math.cos(RealTime() * 2) * 255)
				draw.SimpleText("JAMMED", "DermaDefaultBold", 0, 0, ColorAlpha(Color(255, 100, 0), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End3D2D()
		end
	end
end
