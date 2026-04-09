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

		-- Check available synthesis recipes
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

	-- Helper: find target patient near workstation
	local function FindPatient(entity, targetSteamID)
		for _, v in ipairs(player.GetAll()) do
			if (v:SteamID64() == targetSteamID and v:GetPos():Distance(entity:GetPos()) < 200) then
				return v
			end
		end

		return nil
	end

	-- Minigame request handler: validates and creates a session
	netstream.Hook("CWUMinigameRequest", function(client, entIndex, sessionType, targetSteamID)
		local entity = Entity(entIndex)

		if (!IsValid(entity) or entity:GetClass() != "ix_medicalworkstation") then
			return
		end

		if (entity:GetInUse()) then
			client:Notify("The workstation is currently in use.")
			return
		end

		local division = client:GetCWUDivision()

		if (division != "medical" and division != "director") then
			return
		end

		local character = client:GetCharacter()
		local inventory = character:GetInventory()
		local extraData = {entPos = entity:GetPos()}

		-- Validate per procedure type
		if (sessionType == "bandaging") then
			if (!targetSteamID) then return end

			local target = FindPatient(entity, targetSteamID)

			if (!IsValid(target)) then
				client:Notify("Patient must be near the workstation.")
				return
			end

			extraData.targetSteamID = targetSteamID

		elseif (sessionType == "surgery") then
			if (!targetSteamID) then return end

			if (!character:GetData("medicalTraining", false)) then
				client:NotifyLocalized("cwuNeedMedicalTraining")
				return
			end

			if (!inventory:HasItem("medical_stimpak")) then
				client:NotifyLocalized("cwuNeedStimpak")
				return
			end

			local target = FindPatient(entity, targetSteamID)

			if (!IsValid(target)) then
				client:Notify("Patient must be near the workstation.")
				return
			end

			extraData.targetSteamID = targetSteamID

		elseif (sessionType == "injection_medicine") then
			local chemBases = inventory:GetItemsByUniqueID("chemical_base", true)
			local herbs = inventory:GetItemsByUniqueID("medical_herbs", true)

			if (#chemBases < 2 or #herbs < 1) then
				client:NotifyLocalized("cwuMissingMaterials")
				return
			end

			extraData.drugType = "medicine"

		elseif (sessionType == "injection_combat" or sessionType == "injection_recreational") then
			local chemBases = inventory:GetItemsByUniqueID("chemical_base", true)

			if (#chemBases < 2) then
				client:NotifyLocalized("cwuMissingMaterials")
				return
			end

			extraData.drugType = sessionType == "injection_combat" and "combat" or "recreational"
		else
			return
		end

		-- Play ambient sound for synthesis
		if (string.StartWith(sessionType, "injection")) then
			entity:EmitSound("ambient/machines/combine_terminal_idle2.wav")
		end

		local token, maxTime = PLUGIN:CreateMinigameSession(client, entity, sessionType, extraData)
		netstream.Start(client, "CWUMinigameStart", token, sessionType, maxTime, extraData)
	end)

	-- Minigame completion handler: validates score and applies outcome
	netstream.Hook("CWUMinigameComplete", function(client, token, score)
		local session = PLUGIN:ValidateMinigameCompletion(client, token, score)

		if (!session) then
			return
		end

		local entity = session.entity

		if (session.type == "bandaging") then
			local target = FindPatient(entity, session.targetSteamID)

			if (IsValid(target)) then
				local healAmount

				if (score >= 0.8) then
					healAmount = 25
				elseif (score >= 0.5) then
					healAmount = 20
				elseif (score >= 0.3) then
					healAmount = 15
				else
					healAmount = 10
				end

				target:SetHealth(math.min(target:Health() + healAmount, target:GetMaxHealth()))
				target:EmitSound("items/medshot4.wav")
				target:Notify("You have been treated by a CWU medic. (+" .. healAmount .. " HP)")
			end

			client:Notify("Treatment complete.")

		elseif (session.type == "surgery") then
			-- Consume stimpak
			local stimpak = client:GetCharacter():GetInventory():HasItem("medical_stimpak")

			if (stimpak) then
				stimpak:Remove()
			end

			local target = FindPatient(entity, session.targetSteamID)

			if (IsValid(target)) then
				local maxHP = target:GetMaxHealth()
				local newHP

				if (score >= 0.8) then
					newHP = maxHP
				elseif (score >= 0.5) then
					newHP = math.floor(maxHP * 0.75)
				elseif (score >= 0.3) then
					newHP = math.floor(maxHP * 0.50)
				else
					newHP = math.floor(maxHP * 0.35)
				end

				target:SetHealth(math.max(target:Health(), newHP))
				target:EmitSound("items/medcharge4.wav")

				if (score >= 0.5) then
					target:Notify("You have undergone surgery. Health restored to " .. newHP .. ".")
				else
					target:Notify("The surgery was botched. Partial healing applied.")
				end
			end

			client:Notify("Surgery complete.")

		elseif (string.StartWith(session.type, "injection")) then
			local character = client:GetCharacter()
			local inventory = character:GetInventory()

			-- Determine output and materials
			local outputItem, needsHerbs

			if (session.drugType == "medicine") then
				outputItem = "medical_stimpak"
				needsHerbs = true
			elseif (session.drugType == "combat") then
				outputItem = "combat_stim"
				needsHerbs = false
			else
				outputItem = "recreational_chem"
				needsHerbs = false
			end

			-- Consume materials
			local chemBases = inventory:GetItemsByUniqueID("chemical_base", true)

			for i = 1, 2 do
				if (chemBases[i]) then chemBases[i]:Remove() end
			end

			if (needsHerbs) then
				local herbs = inventory:GetItemsByUniqueID("medical_herbs", true)

				if (herbs[1]) then herbs[1]:Remove() end
			end

			-- Score determines success
			if (score >= 0.5) then
				if (IsValid(entity)) then
					ix.item.Spawn(outputItem, entity:GetPos() + entity:GetUp() * 20, function(item, ent)
						if (IsValid(entity)) then
							entity:EmitSound("buttons/combine_button1.wav")
						end
					end)
				end

				-- Intentionally vague notification (dual-use concealment)
				client:Notify("Synthesis complete: Medical compound produced.")
			else
				-- Synthesis failed - materials consumed, no item produced
				client:NotifyLocalized("cwuSynthesisFailed")
			end
		end
	end)

	-- Minigame cancel handler
	netstream.Hook("CWUMinigameCancel", function(client, token)
		local session = PLUGIN.MinigameSessions[token]

		if (!session or session.client != client) then
			return
		end

		PLUGIN:CleanupMinigameSession(token)
		client:NotifyLocalized("cwuMinigameCancel")
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
				stateText = "TREATING..."
				stateColor = Color(255, 200, 100)
			elseif (state == 2) then
				stateText = "SYNTHESIZING..."
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
