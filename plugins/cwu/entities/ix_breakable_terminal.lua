AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Breakable Ration Terminal"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true

ENT.IsCWUBreakable = true
ENT.BreakableType = "terminal"
ENT.DegradeChance = 8
ENT.RepairPriority = 3

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Broken")
	self:NetworkVar("Float", 0, "BreakTime")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_lab/monitor02.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self:SetBroken(false)
		self.linkedDispenser = nil
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_breakable_terminal")

		entity:SetPos(trace.HitPos + Vector(0, 0, 16))
		entity:Spawn()
		entity:Activate()

		-- Link to nearest ration dispenser
		local nearest = nil
		local nearestDist = 256

		for _, ent in ipairs(ents.FindByClass("ix_rationdispenser")) do
			local dist = ent:GetPos():Distance(entity:GetPos())

			if (dist < nearestDist) then
				nearestDist = dist
				nearest = ent
			end
		end

		if (IsValid(nearest)) then
			entity.linkedDispenser = nearest
		end

		return entity
	end

	function ENT:OnBreak()
		if (IsValid(self.linkedDispenser)) then
			self.linkedDispenser:SetEnabled(false)
		end

		self:EmitSound("ambient/energy/spark5.wav", 60)
	end

	function ENT:OnRepair()
		if (IsValid(self.linkedDispenser)) then
			self.linkedDispenser:SetEnabled(true)
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

			PLUGIN:CompleteWorkOrder(self:EntIndex(), client:GetCharacter())
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

			cam.Start3D2D(position + self:GetForward() * 5 + self:GetUp() * 8, angles, 0.04)
				local alpha = math.abs(math.cos(RealTime() * 3) * 255)
				draw.SimpleText("MALFUNCTION", "DermaDefaultBold", 0, 0, ColorAlpha(Color(255, 0, 0), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End3D2D()
		end
	end
end
