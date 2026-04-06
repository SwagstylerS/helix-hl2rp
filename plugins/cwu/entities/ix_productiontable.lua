AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "CWU Production Table"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true

ENT.MaxRenderDistance = math.pow(256, 2)

-- States: 0 = idle, 1 = crafting, 2 = complete, 3 = error
function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "State")
	self:NetworkVar("Float", 0, "CraftEnd")
	self:NetworkVar("Float", 1, "CraftDuration")
	self:NetworkVar("String", 0, "CrafterName")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_lab/cremator_table001a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self.nextUseTime = 0
		self:SetState(0)
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_productiontable")

		entity:SetPos(trace.HitPos + Vector(0, 0, 16))
		entity:SetAngles(Angle(0, (entity:GetPos() - client:GetPos()):Angle().y - 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Use(client)
		if (self.nextUseTime > CurTime()) then
			return
		end

		self.nextUseTime = CurTime() + 1

		-- If crafting is complete, spawn the item
		if (self:GetState() == 2) then
			if (self.pendingOutput) then
				local blueprint = PLUGIN:GetBlueprint(self.pendingBlueprintID)

				if (blueprint) then
					ix.item.Spawn(blueprint.output, self:GetPos() + self:GetUp() * 20 + self:GetForward() * 10, function(item, entity)
						self:EmitSound("buttons/combine_button1.wav")
					end)
				end

				self.pendingOutput = false
				self.pendingBlueprintID = nil
				self:SetState(0)
				self:SetCrafterName("")
			end

			return
		end

		-- Only Production or Director can use
		local division = client:GetCWUDivision()

		if (division != "production" and division != "director") then
			client:NotifyLocalized("cwuNotProduction")
			return
		end

		if (self:GetState() == 1) then
			client:Notify("This table is currently in use.")
			return
		end

		-- Gather available blueprints from player inventory
		local character = client:GetCharacter()
		local inventory = character:GetInventory()
		local availableBlueprints = {}

		for _, item in pairs(inventory:GetItems()) do
			if (item.blueprintID and item.blueprintID != "none") then
				local canUse = PLUGIN:CanUseBlueprint(character, item.blueprintID)
				local hasMats = PLUGIN:HasBlueprintMaterials(inventory, item.blueprintID)
				local bp = PLUGIN:GetBlueprint(item.blueprintID)

				availableBlueprints[#availableBlueprints + 1] = {
					id = item.blueprintID,
					name = bp and bp.name or item.blueprintID,
					canUse = canUse,
					hasMaterials = hasMats,
					tier = bp and bp.tier or 0,
					craftTime = bp and bp.craftTime or 10
				}
			end
		end

		netstream.Start(client, "CWUProductionOpen", self:EntIndex(), availableBlueprints)
	end

	function ENT:OnRemove()
		if (!ix.shuttingDown) then
			PLUGIN:SaveProductionTables()
		end
	end

	netstream.Hook("CWUProductionStart", function(client, entIndex, blueprintID)
		local entity = Entity(entIndex)

		if (!IsValid(entity) or entity:GetClass() != "ix_productiontable") then
			return
		end

		if (entity:GetState() != 0) then
			return
		end

		local division = client:GetCWUDivision()

		if (division != "production" and division != "director") then
			return
		end

		local character = client:GetCharacter()
		local inventory = character:GetInventory()

		-- Validate blueprint access
		if (!PLUGIN:CanUseBlueprint(character, blueprintID)) then
			client:NotifyLocalized("cwuBlueprintTierLocked")
			return
		end

		-- Validate materials
		if (!PLUGIN:HasBlueprintMaterials(inventory, blueprintID)) then
			client:NotifyLocalized("cwuMissingMaterials")
			return
		end

		-- Consume materials
		PLUGIN:ConsumeBlueprintMaterials(inventory, blueprintID)

		local blueprint = PLUGIN:GetBlueprint(blueprintID)
		local craftTime = blueprint.craftTime or ix.config.Get("cwuDefaultCraftTime", 10)

		-- Start crafting
		entity:SetState(1)
		entity:SetCraftEnd(CurTime() + craftTime)
		entity:SetCraftDuration(craftTime)
		entity:SetCrafterName(character:GetName())
		entity:EmitSound("ambient/machines/combine_terminal_idle2.wav")

		entity.pendingBlueprintID = blueprintID
		entity.pendingOutput = true

		client:NotifyLocalized("cwuCraftingStarted")

		-- Timer for completion
		timer.Create("CWUCraft_" .. entity:EntIndex(), craftTime, 1, function()
			if (IsValid(entity)) then
				entity:SetState(2)
				entity:EmitSound("buttons/combine_button1.wav")
			end
		end)
	end)
else
	surface.CreateFont("ixProductionTable", {
		font = "Default",
		size = 20,
		weight = 800,
		antialias = false
	})

	surface.CreateFont("ixProductionTableSmall", {
		font = "Default",
		size = 14,
		weight = 600,
		antialias = false
	})

	function ENT:Draw()
		self:DrawModel()

		local position = self:GetPos()

		if (LocalPlayer():GetPos():DistToSqr(position) > self.MaxRenderDistance) then
			return
		end

		local angles = self:GetAngles()

		angles:RotateAroundAxis(angles:Up(), 90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(position + self:GetUp() * 30 + self:GetForward() * -5, angles, 0.07)
			render.PushFilterMin(TEXFILTER.NONE)
			render.PushFilterMag(TEXFILTER.NONE)

			local state = self:GetState()

			surface.SetDrawColor(20, 20, 20)
			surface.DrawRect(-100, -30, 200, 60)

			surface.SetDrawColor(60, 60, 60)
			surface.DrawOutlinedRect(-100, -30, 200, 60)

			if (state == 0) then
				draw.SimpleText("PRODUCTION TABLE", "ixProductionTable", 0, -10, Color(100, 175, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("IDLE", "ixProductionTableSmall", 0, 10, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			elseif (state == 1) then
				draw.SimpleText("CRAFTING", "ixProductionTable", 0, -15, Color(255, 200, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				-- Progress bar
				local craftEnd = self:GetCraftEnd()
				local craftDuration = self:GetCraftDuration()
				local progress = 1 - math.max(0, (craftEnd - CurTime()) / craftDuration)

				surface.SetDrawColor(40, 40, 40)
				surface.DrawRect(-80, 5, 160, 12)

				surface.SetDrawColor(100, 175, 100)
				surface.DrawRect(-80, 5, 160 * progress, 12)

				draw.SimpleText(self:GetCrafterName(), "ixProductionTableSmall", 0, -2, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			elseif (state == 2) then
				local alpha = math.abs(math.cos(RealTime() * 3) * 255)
				draw.SimpleText("COMPLETE", "ixProductionTable", 0, -10, ColorAlpha(Color(0, 255, 0), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("PRESS E TO COLLECT", "ixProductionTableSmall", 0, 10, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			elseif (state == 3) then
				draw.SimpleText("ERROR", "ixProductionTable", 0, 0, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			render.PopFilterMin()
			render.PopFilterMag()
		cam.End3D2D()
	end
end
