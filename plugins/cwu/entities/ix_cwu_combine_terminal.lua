AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "CWU Combine Terminal"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true

ENT.MaxRenderDistance = math.pow(256, 2)

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_combine/combine_interface001.mdl")
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
		local entity = ents.Create("ix_cwu_combine_terminal")

		entity:SetPos(trace.HitPos + Vector(0, 0, 32))
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

		if (!client:IsCombine()) then
			self:EmitSound("buttons/combine_button_locked.wav")
			client:NotifyLocalized("cwuAccessDenied")
			return
		end

		-- Gather CWU roster data
		local roster = {}

		for _, v in ipairs(player.GetAll()) do
			local character = v:GetCharacter()

			if (character and v:IsCWU()) then
				roster[#roster + 1] = {
					name = character:GetName(),
					division = v:GetCWUDivision(),
					tier = character:GetData("loyaltyTier", 0),
					isDirector = v:IsCWUDirector(),
					flagged = character:GetData("combineFlag", false)
				}
			end
		end

		-- Gather infrastructure status
		local infrastructure = {}

		for class, info in pairs(PLUGIN.BreakableTypes) do
			for _, entity in ipairs(ents.FindByClass(class)) do
				local ePos = entity:GetPos()
				infrastructure[#infrastructure + 1] = {
					type = info.type,
					location = string.format("%d, %d", math.floor(ePos.x), math.floor(ePos.y)),
					broken = entity:GetBroken(),
					priority = info.priority
				}
			end
		end

		local transactions = PLUGIN:GetTransactions()
		local workOrders = PLUGIN:GetWorkOrders()

		netstream.Start(client, "CWUCombineTerminalOpen", {
			roster = roster,
			infrastructure = infrastructure,
			transactions = transactions,
			workOrders = workOrders
		})

		self:EmitSound("buttons/combine_button1.wav")
	end

	function ENT:OnRemove()
		if (!ix.shuttingDown) then
			PLUGIN:SaveCombineTerminals()
		end
	end

	-- Netstream handler for submitting work orders via Combine terminal
	netstream.Hook("CWUCombineSubmitWorkOrder", function(client, description, location, priority)
		if (!client:IsCombine()) then
			return
		end

		description = string.sub(tostring(description), 1, 200)
		location = string.sub(tostring(location), 1, 100)
		priority = math.Clamp(math.floor(tonumber(priority) or 2), 1, 3)

		PLUGIN:SubmitManualWorkOrder(description, location, priority, client:GetCharacter():GetName())
		client:NotifyLocalized("cwuWorkOrderSubmitted")
	end)

	netstream.Hook("CWUCombineTerminalAction", function(client, data)
		if (!IsValid(client) or !client:IsPlayer() or !client:IsCombine()) then
			return
		end

		if (type(data) != "table") then return end

		local action = tostring(data.action or "")
		local charName = string.sub(tostring(data.charName or ""), 1, 100)

		if (charName == "") then return end

		local targetChar = nil

		for _, v in ipairs(player.GetAll()) do
			local char = v:GetCharacter()

			if (char and char:GetName() == charName) then
				targetChar = char
				break
			end
		end

		if (!targetChar) then
			client:Notify("Character not found online.")
			return
		end

		if (action == "flag") then
			targetChar:SetData("combineFlag", true)
			client:NotifyLocalized("cwuMemberFlagged", charName)

			local targets = {}

			for _, v in ipairs(player.GetAll()) do
				if (IsValid(v) and v:IsCombine()) then
					targets[#targets + 1] = v
				end
			end

			if (#targets > 0) then
				net.Start("CS_BiometricAlert")
					net.WriteString(string.format("CWU MEMBER FLAGGED: %s", charName))
					net.WriteUInt(2, 4)
				net.Send(targets)
			end
		elseif (action == "unflag") then
			targetChar:SetData("combineFlag", false)
			client:Notify("Combine flag cleared for " .. charName .. ".")
		end
	end)
else
	surface.CreateFont("ixCWUCombineTerminal", {
		font = "Default",
		size = 16,
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

		cam.Start3D2D(position + self:GetForward() * 8 + self:GetUp() * 48, angles, 0.06)
			render.PushFilterMin(TEXFILTER.NONE)
			render.PushFilterMag(TEXFILTER.NONE)

			surface.SetDrawColor(10, 10, 30)
			surface.DrawRect(-80, -25, 160, 50)

			surface.SetDrawColor(50, 50, 100)
			surface.DrawOutlinedRect(-80, -25, 160, 50)

			draw.SimpleText("CIVIL WORKFORCE", "ixCWUCombineTerminal", 0, -10, Color(100, 150, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("OVERSIGHT", "ixCWUCombineTerminal", 0, 10, Color(100, 150, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			render.PopFilterMin()
			render.PopFilterMag()
		cam.End3D2D()
	end
end
