AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "CWU Medical Workstation"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true

ENT.MaxRenderDistance = math.pow(256, 2)

-- States: 0 = idle, 1 = treating, 2 = synthesizing
function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "State")
	self:NetworkVar("Bool", 0, "InUse")
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
		self:SetInUse(false)
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_medicalworkstation")

		entity:SetPos(trace.HitPos + Vector(0, 0, 16))
		entity:SetAngles(Angle(0, (entity:GetPos() - client:GetPos()):Angle().y - 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Use(client)
		if (self.nextUseTime > CurTime() or self:GetInUse()) then
			return
		end

		self.nextUseTime = CurTime() + 1

		local division = client:GetCWUDivision()

		if (division != "medical" and division != "director") then
			client:NotifyLocalized("cwuNotMedical")
			return
		end

		local character = client:GetCharacter()
		local hasMedicalTraining = character:GetData("medicalTraining", false)
		local inventory = character:GetInventory()

		-- Treatment path: trained medic looking at a nearby patient
		if (hasMedicalTraining) then
			local traceEnt = client:GetEyeTrace().Entity

			if (IsValid(traceEnt) and traceEnt:IsPlayer() and traceEnt:GetPos():Distance(client:GetPos()) < 150) then
				local healingItems = {}

				for _, item in pairs(inventory:GetItems()) do
					if (item.isHealingItem) then
						healingItems[#healingItems + 1] = {
							id = item:GetID(),
							name = item.name,
							healAmount = item.healAmount or 0
						}
					end
				end

				netstream.Start(client, "CWUMedicalTreat", traceEnt:EntIndex(), healingItems)
				return
			end
		end

		-- Synthesis path
		local hasChemBase = #inventory:GetItemsByUniqueID("chemical_base", true) >= 2
		local hasHerbs = #inventory:GetItemsByUniqueID("medical_herbs", true) >= 1

		netstream.Start(client, "CWUMedicalOpen", self:EntIndex(), {
			hasMedicalTraining = hasMedicalTraining,
			hasChemBase = hasChemBase,
			hasHerbs = hasHerbs,
			hasStimpak = inventory:HasItem("medical_stimpak") and true or false
		})
	end

	function ENT:OnRemove()
		if (!ix.shuttingDown) then
			PLUGIN:SaveMedicalWorkstations()
		end
	end

	-- Treatment: Basic bandaging (any CWU Medical)
	netstream.Hook("CWUMedicalTreatBasic", function(client, entIndex, targetSteamID)
		local entity = Entity(entIndex)

		if (!IsValid(entity) or entity:GetClass() != "ix_medicalworkstation") then
			return
		end

		local division = client:GetCWUDivision()

		if (division != "medical" and division != "director") then
			return
		end

		-- Find target patient nearby
		local target = nil

		for _, v in ipairs(player.GetAll()) do
			if (v:SteamID64() == targetSteamID and v:GetPos():Distance(entity:GetPos()) < 200) then
				target = v
				break
			end
		end

		if (!IsValid(target)) then
			client:Notify("No eligible patient within workstation range.")
			return
		end

		entity:SetInUse(true)
		entity:SetState(1)
		client:SetAction("@cwuTreating", 5)

		client:DoStaredAction(entity, function()
			if (IsValid(target)) then
				target:SetHealth(math.min(target:Health() + 25, target:GetMaxHealth()))
				target:EmitSound("items/medshot4.wav")
				target:Notify("CWU medical care has been rendered. Follow any recovery directives issued.")
			end

			PLUGIN:AwardLoyalty(client:GetCharacter(), 2, "treatment")
			client:Notify("Care administered. Service record updated.")
			entity:SetState(0)
			entity:SetInUse(false)
		end, 5, function()
			if (IsValid(entity)) then
				entity:SetState(0)
				entity:SetInUse(false)
			end

			if (IsValid(client)) then
				client:SetAction()
			end
		end)
	end)

	-- Treatment: Advanced surgery (requires medicalTraining + stimpak)
	netstream.Hook("CWUMedicalSurgery", function(client, entIndex, targetSteamID)
		local entity = Entity(entIndex)

		if (!IsValid(entity) or entity:GetClass() != "ix_medicalworkstation") then
			return
		end

		local character = client:GetCharacter()

		if (!character:GetData("medicalTraining", false)) then
			client:NotifyLocalized("cwuNeedMedicalTraining")
			return
		end

		local stimpak = character:GetInventory():HasItem("medical_stimpak")

		if (!stimpak) then
			client:NotifyLocalized("cwuNeedStimpak")
			return
		end

		local target = nil

		for _, v in ipairs(player.GetAll()) do
			if (v:SteamID64() == targetSteamID and v:GetPos():Distance(entity:GetPos()) < 200) then
				target = v
				break
			end
		end

		if (!IsValid(target)) then
			client:Notify("No eligible patient within workstation range.")
			return
		end

		entity:SetInUse(true)
		entity:SetState(1)
		client:SetAction("@cwuTreating", 10)

		client:DoStaredAction(entity, function()
			-- Consume stimpak
			local kit = client:GetCharacter():GetInventory():HasItem("medical_stimpak")

			if (kit) then
				kit:Remove()
			end

			if (IsValid(target)) then
				target:SetHealth(target:GetMaxHealth())
				target:EmitSound("items/medcharge4.wav")
				target:Notify("Surgical intervention complete. You are cleared for standard duty under the Union programme.")
			end

			PLUGIN:AwardLoyalty(client:GetCharacter(), 2, "treatment")
			client:Notify("Surgical intervention logged. Patient cleared for duty.")
			entity:SetState(0)
			entity:SetInUse(false)
		end, 10, function()
			if (IsValid(entity)) then
				entity:SetState(0)
				entity:SetInUse(false)
			end

			if (IsValid(client)) then
				client:SetAction()
			end
		end)
	end)

	-- Synthesis: Legitimate medicine (stimpak)
	netstream.Hook("CWUMedicalSynthMedicine", function(client, entIndex)
		local entity = Entity(entIndex)

		if (!IsValid(entity) or entity:GetClass() != "ix_medicalworkstation") then
			return
		end

		if (client:GetPos():DistToSqr(entity:GetPos()) > 65536) then
			return
		end

		local character = client:GetCharacter()
		if (!character) then return end

		if (!PLUGIN:CanUseBlueprint(character, "bp_medical_stimpak")) then
			client:NotifyLocalized("cwuBlueprintTierLocked")
			return
		end

		local inventory = character:GetInventory()
		local chemBases = inventory:GetItemsByUniqueID("chemical_base", true)
		local herbs = inventory:GetItemsByUniqueID("medical_herbs", true)

		if (#chemBases < 2 or #herbs < 1) then
			client:NotifyLocalized("cwuMissingMaterials")
			return
		end

		entity:SetInUse(true)
		entity:SetState(2)
		entity:EmitSound("ambient/machines/combine_terminal_idle2.wav")
		client:SetAction("@cwuSynthesizing", 15)

		client:DoStaredAction(entity, function()
			-- Consume materials
			for i = 1, 2 do
				if (chemBases[i]) then chemBases[i]:Remove() end
			end

			if (herbs[1]) then herbs[1]:Remove() end

			-- Produce stimpak
			ix.item.Spawn("medical_stimpak", entity:GetPos() + entity:GetUp() * 20, function(item, ent)
				entity:EmitSound("buttons/combine_button1.wav")
			end)

			PLUGIN:AwardLoyalty(client:GetCharacter(), 1, "synthesis")
			client:Notify("Synthesis complete. Output registered under Union Medical.")
			entity:SetState(0)
			entity:SetInUse(false)
		end, 15, function()
			if (IsValid(entity)) then
				entity:SetState(0)
				entity:SetInUse(false)
			end

			if (IsValid(client)) then
				client:SetAction()
			end
		end)
	end)

	-- Treatment: Item-based healing (trained medic + healing item from inventory)
	netstream.Hook("CWUMedicalApply", function(client, targetEntIndex, itemID)
		if (!IsValid(client) or !client:IsPlayer()) then return end

		local character = client:GetCharacter()
		if (!character) then return end

		if (!character:GetData("medicalTraining", false)) then
			client:NotifyLocalized("cwuNeedMedicalTraining")
			return
		end

		local target = Entity(targetEntIndex)

		if (!IsValid(target) or !target:IsPlayer()) then
			client:Notify("No valid patient registered at this workstation.")
			return
		end

		if (target:GetPos():Distance(client:GetPos()) > 200) then
			client:Notify("Patient must be within immediate proximity for treatment.")
			return
		end

		local inventory = character:GetInventory()
		local item = inventory:GetItems()[itemID]

		if (!item or !item.isHealingItem) then
			client:Notify("Supplied item is not registered as Union medical equipment.")
			return
		end

		local healAmount = item.healAmount or 0
		item:Remove()

		target:SetHealth(math.min(target:Health() + healAmount, target:GetMaxHealth()))
		target:EmitSound("items/medshot4.wav")
		target:Notify("CWU medical care has been rendered. Follow any recovery directives issued.")

		PLUGIN:AwardLoyalty(character, 2, "treatment")
		client:Notify("Care administered. Service record updated.")
	end)

	-- Synthesis: Illicit drugs (combat stim or recreational) - dual use tension
	netstream.Hook("CWUMedicalSynthDrug", function(client, entIndex, drugType)
		local entity = Entity(entIndex)

		if (!IsValid(entity) or entity:GetClass() != "ix_medicalworkstation") then
			return
		end

		if (client:GetPos():DistToSqr(entity:GetPos()) > 65536) then
			return
		end

		local character = client:GetCharacter()
		if (!character) then return end

		if (!character:GetData("medicalTraining", false)) then
			client:NotifyLocalized("cwuNeedTraining")
			return
		end

		local blueprintID = drugType == "combat" and "bp_combat_stim" or "bp_recreational_chem"

		if (!PLUGIN:CanUseBlueprint(character, blueprintID)) then
			client:NotifyLocalized("cwuBlueprintNotApproved")
			return
		end

		local isRecreational = drugType != "combat"
		local inventory = character:GetInventory()
		local chemBases = inventory:GetItemsByUniqueID("chemical_base", true)
		local herbs = isRecreational and inventory:GetItemsByUniqueID("medical_herbs", true) or nil

		if (isRecreational) then
			if (#chemBases < 1 or #herbs < 1) then
				client:NotifyLocalized("cwuMissingMaterials")
				return
			end
		elseif (#chemBases < 2) then
			client:NotifyLocalized("cwuMissingMaterials")
			return
		end

		local outputItem = isRecreational and "recreational_chem" or "combat_stim"

		entity:SetInUse(true)
		entity:SetState(2)
		entity:EmitSound("ambient/machines/combine_terminal_idle2.wav")
		client:SetAction("@cwuSynthesizing", 20)

		client:DoStaredAction(entity, function()
			if (isRecreational) then
				if (chemBases[1]) then chemBases[1]:Remove() end
				if (herbs[1]) then herbs[1]:Remove() end
			else
				for i = 1, 2 do
					if (chemBases[i]) then chemBases[i]:Remove() end
				end
			end

			ix.item.Spawn(outputItem, entity:GetPos() + entity:GetUp() * 20, function(item, ent)
				entity:EmitSound("buttons/combine_button1.wav")
			end)

			client:Notify("Synthesis complete. Output registered under Union Medical.")
			PLUGIN:LogTransaction({
				type       = "synthesis",
				synthesizer   = character:GetName(),
				synthesizerID = character:GetID(),
				item       = outputItem,
				itemName   = "Medical Compound",
				quantity   = 1,
			})
			PLUGIN:AwardLoyalty(client:GetCharacter(), 1, "synthesis")
			entity:SetState(0)
			entity:SetInUse(false)
		end, 20, function()
			if (IsValid(entity)) then
				entity:SetState(0)
				entity:SetInUse(false)
			end

			if (IsValid(client)) then
				client:SetAction()
			end
		end)
	end)
else
	surface.CreateFont("ixMedicalWorkstation", {
		font = "Default",
		size = 18,
		weight = 800,
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

		cam.Start3D2D(position + self:GetUp() * 30 + self:GetForward() * -5, angles, 0.06)
			render.PushFilterMin(TEXFILTER.NONE)
			render.PushFilterMag(TEXFILTER.NONE)

			surface.SetDrawColor(20, 20, 20)
			surface.DrawRect(-90, -25, 180, 50)

			surface.SetDrawColor(60, 60, 60)
			surface.DrawOutlinedRect(-90, -25, 180, 50)

			local state = self:GetState()
			local stateText = "MEDICAL STATION"
			local stateColor = Color(100, 150, 255)

			if (state == 1) then
				stateText = "PROCEDURE IN PROGRESS"
				stateColor = Color(255, 200, 100)
			elseif (state == 2) then
				stateText = "SYNTHESIS IN PROGRESS"
				stateColor = Color(200, 100, 255)
			end

			draw.SimpleText(stateText, "ixMedicalWorkstation", 0, -5, stateColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			if (state == 0) then
				draw.SimpleText("IDLE", "DermaDefault", 0, 12, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			render.PopFilterMin()
			render.PopFilterMag()
		cam.End3D2D()
	end
end
