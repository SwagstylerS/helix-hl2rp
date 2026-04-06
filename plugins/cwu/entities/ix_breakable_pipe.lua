AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Breakable Pipe"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true

ENT.IsCWUBreakable = true
ENT.BreakableType = "pipe"
ENT.DegradeChance = 12
ENT.RepairPriority = 1

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Broken")
	self:NetworkVar("Float", 0, "BreakTime")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_c17/pipe01_connector01.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self:SetBroken(false)
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_breakable_pipe")

		entity:SetPos(trace.HitPos + Vector(0, 0, 16))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:OnBreak()
		self:EmitSound("ambient/water/drip_loop2.wav", 50)

		-- Create drip effect
		if (!IsValid(self.dripEffect)) then
			self.dripEffect = ents.Create("env_smokestack")

			if (IsValid(self.dripEffect)) then
				self.dripEffect:SetPos(self:GetPos() - Vector(0, 0, 8))
				self.dripEffect:SetKeyValue("InitialState", "1")
				self.dripEffect:SetKeyValue("BaseSpread", "2")
				self.dripEffect:SetKeyValue("SpreadSpeed", "5")
				self.dripEffect:SetKeyValue("Speed", "20")
				self.dripEffect:SetKeyValue("Rate", "15")
				self.dripEffect:SetKeyValue("StartSize", "1")
				self.dripEffect:SetKeyValue("EndSize", "3")
				self.dripEffect:SetKeyValue("JetLength", "30")
				self.dripEffect:SetKeyValue("rendercolor", "100 150 200")
				self.dripEffect:SetKeyValue("renderamt", "100")
				self.dripEffect:Spawn()
				self.dripEffect:Activate()
				self:DeleteOnRemove(self.dripEffect)
			end
		end
	end

	function ENT:OnRepair()
		self:StopSound("ambient/water/drip_loop2.wav")
		self:EmitSound("buttons/lever7.wav")

		if (IsValid(self.dripEffect)) then
			self.dripEffect:Remove()
			self.dripEffect = nil
		end
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

			cam.Start3D2D(position + self:GetUp() * 8, angles, 0.04)
				local alpha = math.abs(math.cos(RealTime() * 2) * 255)
				draw.SimpleText("LEAKING", "DermaDefaultBold", 0, 0, ColorAlpha(Color(100, 150, 255), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End3D2D()
		end
	end
end
