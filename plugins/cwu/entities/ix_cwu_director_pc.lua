AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "CWU Director PC"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true

ENT.MaxRenderDistance = math.pow(256, 2)

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "InUse")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_lab/monitor01a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self.nextUseTime = 0
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_cwu_director_pc")

		entity:SetPos(trace.HitPos + Vector(0, 0, 8))
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

		if (!client:IsCWUDirector()) then
			self:EmitSound("buttons/combine_button_locked.wav")
			client:NotifyLocalized("cwuAccessDenied")
			return
		end

		-- Gather data to send to client
		local cwuMembers = {}
		local citizens = {}

		for _, v in ipairs(player.GetAll()) do
			local character = v:GetCharacter()

			if (!character) then
				continue
			end

			if (v:IsCWU()) then
				cwuMembers[#cwuMembers + 1] = {
					name = character:GetName(),
					charID = character:GetID(),
					division = v:GetCWUDivision(),
					tier = character:GetData("loyaltyTier", 0),
					medicalTraining = character:GetData("medicalTraining", false),
					steamID = v:SteamID64()
				}
			elseif (character:GetFaction() == FACTION_CITIZEN) then
				citizens[#citizens + 1] = {
					name = character:GetName(),
					charID = character:GetID(),
					tier = character:GetData("loyaltyTier", 0),
					steamID = v:SteamID64()
				}
			end
		end

		-- Gather blueprint approval data
		local blueprintApprovals = {}

		for _, v in ipairs(player.GetAll()) do
			local character = v:GetCharacter()

			if (character and v:GetCWUDivision() == "production") then
				local approvals = {}

				for bpID, _ in pairs(PLUGIN.Blueprints) do
					local bp = PLUGIN:GetBlueprint(bpID)

					if (bp and bp.tier == 2) then
						approvals[bpID] = character:GetData("approved_bp_" .. bpID, false)
					end
				end

				blueprintApprovals[character:GetID()] = approvals
			end
		end

		local treasury = PLUGIN:GetTreasury()
		local transactions = PLUGIN:GetTransactions()
		local recentTransactions = {}

		-- Send last 20 transactions for treasury tab
		for i = math.max(1, #transactions - 19), #transactions do
			if (transactions[i]) then
				recentTransactions[#recentTransactions + 1] = transactions[i]
			end
		end

		netstream.Start(client, "CWUDirectorPCOpen", {
			cwuMembers = cwuMembers,
			citizens = citizens,
			blueprintApprovals = blueprintApprovals,
			treasury = treasury,
			recentTransactions = recentTransactions,
			allTransactions = transactions
		})

		self:EmitSound("buttons/combine_button1.wav")
	end

	function ENT:OnRemove()
		if (!ix.shuttingDown) then
			PLUGIN:SaveDirectorPCs()
		end
	end

	-- Netstream handlers for Director PC actions
	netstream.Hook("CWUDirectorAssign", function(client, charID, division)
		if (!client:IsCWUDirector()) then
			return
		end

		local classID = PLUGIN:GetDivisionClassID(division)

		if (!classID) then
			return
		end

		for _, v in ipairs(player.GetAll()) do
			local character = v:GetCharacter()

			if (character and character:GetID() == charID and character:GetFaction() == FACTION_CITIZEN) then
				character:JoinClass(classID, true)
				client:NotifyLocalized("cwuAssigned", character:GetName(), division)

				v:Notify("You have been assigned to the CWU " .. division:sub(1, 1):upper() .. division:sub(2) .. " Division.")
				break
			end
		end
	end)

	netstream.Hook("CWUDirectorRemove", function(client, charID)
		if (!client:IsCWUDirector()) then
			return
		end

		for _, v in ipairs(player.GetAll()) do
			local character = v:GetCharacter()

			if (character and character:GetID() == charID and v:IsCWU()) then
				character:JoinClass(CLASS_CITIZEN, true)
				client:NotifyLocalized("cwuRemoved", character:GetName())

				v:Notify("You have been removed from the CWU.")
				break
			end
		end
	end)

	netstream.Hook("CWUDirectorApproveBlueprint", function(client, charID, blueprintID, approved)
		if (!client:IsCWUDirector()) then
			return
		end

		for _, v in ipairs(player.GetAll()) do
			local character = v:GetCharacter()

			if (character and character:GetID() == charID) then
				character:SetData("approved_bp_" .. blueprintID, approved)

				if (approved) then
					client:NotifyLocalized("cwuBlueprintApproved", character:GetName())
				else
					client:NotifyLocalized("cwuBlueprintRevoked", character:GetName())
				end

				break
			end
		end
	end)

	netstream.Hook("CWUDirectorLicense", function(client, charID, grant)
		if (!client:IsCWUDirector()) then
			return
		end

		for _, v in ipairs(player.GetAll()) do
			local character = v:GetCharacter()

			if (character and character:GetID() == charID) then
				local inventory = character:GetInventory()

				if (grant) then
					if (!inventory:HasItem("business_license")) then
						inventory:Add("business_license")
						client:NotifyLocalized("cwuLicenseGranted", character:GetName())
					end
				else
					local item = inventory:HasItem("business_license")

					if (item) then
						inventory:Remove(item.id)
						client:NotifyLocalized("cwuLicenseRevoked", character:GetName())
					end
				end

				break
			end
		end
	end)

	netstream.Hook("CWUDirectorMedicalTraining", function(client, charID, grant)
		if (!client:IsCWUDirector()) then
			return
		end

		for _, v in ipairs(player.GetAll()) do
			local character = v:GetCharacter()

			if (character and character:GetID() == charID) then
				character:SetData("medicalTraining", grant)

				if (grant) then
					client:NotifyLocalized("cwuTrainingGranted", character:GetName())
				else
					client:NotifyLocalized("cwuTrainingRevoked", character:GetName())
				end

				break
			end
		end
	end)

	netstream.Hook("CWUDirectorWithdraw", function(client, amount)
		if (!client:IsCWUDirector()) then
			return
		end

		amount = math.floor(math.max(0, amount))

		if (amount <= 0) then
			return
		end

		if (PLUGIN:WithdrawTreasury(amount)) then
			client:GetCharacter():GiveMoney(amount)
			client:NotifyLocalized("cwuWithdrawSuccess", ix.currency.Get(amount))
		else
			client:NotifyLocalized("cwuInsufficientTreasury")
		end
	end)
else
	surface.CreateFont("ixCWUDirectorPC", {
		font = "Default",
		size = 18,
		weight = 800,
		antialias = false
	})

	surface.CreateFont("ixCWUDirectorPCSmall", {
		font = "Default",
		size = 12,
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

		cam.Start3D2D(position + self:GetForward() * 5.5 + self:GetRight() * 0 + self:GetUp() * 14, angles, 0.05)
			render.PushFilterMin(TEXFILTER.NONE)
			render.PushFilterMag(TEXFILTER.NONE)

			surface.SetDrawColor(20, 20, 20)
			surface.DrawRect(-100, -40, 200, 80)

			surface.SetDrawColor(60, 60, 60)
			surface.DrawOutlinedRect(-100, -40, 200, 80)

			draw.SimpleText("CWU DIRECTOR", "ixCWUDirectorPC", 0, -20, Color(100, 175, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("TERMINAL", "ixCWUDirectorPC", 0, 0, Color(100, 175, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local alpha = math.abs(math.cos(RealTime() * 2) * 255)
			draw.SimpleText("PRESS E TO ACCESS", "ixCWUDirectorPCSmall", 0, 25, ColorAlpha(Color(100, 175, 100), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			render.PopFilterMin()
			render.PopFilterMag()
		cam.End3D2D()
	end
end
