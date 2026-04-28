AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "CWU Work Order Board"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true

ENT.MaxRenderDistance = math.pow(256, 2)

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_lab/clipboard.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self.nextUseTime = 0
		self:SetNetVar("workOrders", PLUGIN:GetWorkOrders())
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_workorderboard")

		entity:SetPos(trace.HitPos + Vector(0, 0, 48))
		entity:SetAngles(Angle(0, (entity:GetPos() - client:GetPos()):Angle().y - 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:RefreshOrders()
		self:SetNetVar("workOrders", PLUGIN:GetWorkOrders())
	end

	function ENT:Use(client)
		if (self.nextUseTime > CurTime()) then
			return
		end

		self.nextUseTime = CurTime() + 1

		-- CWU members, Combine, and admins can view
		if (!client:IsCWU() and !client:IsCombine() and client:Team() != FACTION_ADMIN) then
			return
		end

		local orders = PLUGIN:GetWorkOrders()
		netstream.Start(client, "CWUWorkOrderBoardOpen", orders)

		self:EmitSound("buttons/lightswitch2.wav", 40)
	end

	function ENT:OnRemove()
		if (!ix.shuttingDown) then
			PLUGIN:SaveWorkOrderBoards()
		end
	end

	netstream.Hook("CWUWorkOrderClaim", function(client, orderID)
		if (!IsValid(client) or !client:IsPlayer()) then return end

		local div = client:GetCWUDivision()
		if (div != "maintenance" and div != "director") then return end
		if (!isnumber(orderID)) then return end

		local nearBoard = false
		for _, board in ipairs(ents.FindByClass("ix_workorderboard")) do
			if (IsValid(board) and client:GetPos():DistToSqr(board:GetPos()) <= 65536) then
				nearBoard = true
				break
			end
		end
		if (!nearBoard) then return end

		local character = client:GetCharacter()
		if (!character) then return end

		local orders = PLUGIN:GetWorkOrders()
		for _, order in ipairs(orders) do
			if (order.id == orderID and !order.completed) then
				if (order.assignedTo) then
					client:NotifyLocalized("cwuWorkOrderAlreadyClaimed")
					return
				end

				PLUGIN:ClaimWorkOrder(orderID, character:GetName())
				client:NotifyLocalized("cwuWorkOrderClaimed")
				netstream.Start(client, "CWUWorkOrderBoardOpen", PLUGIN:GetWorkOrders())
				return
			end
		end
	end)

	netstream.Hook("CWUWorkOrderComplete", function(client, orderID)
		if (!IsValid(client) or !client:IsPlayer()) then return end

		local div = client:GetCWUDivision()
		if (div != "maintenance" and div != "director") then return end
		if (!isnumber(orderID)) then return end

		local nearBoard = false
		for _, board in ipairs(ents.FindByClass("ix_workorderboard")) do
			if (IsValid(board) and client:GetPos():DistToSqr(board:GetPos()) <= 65536) then
				nearBoard = true
				break
			end
		end
		if (!nearBoard) then return end

		local character = client:GetCharacter()
		if (!character) then return end

		local orders = PLUGIN:GetWorkOrders()
		for _, order in ipairs(orders) do
			if (order.id == orderID and !order.completed) then
				if (order.assignedTo != character:GetName()) then return end

				-- Reject if the linked entity is still alive — repair it directly
				if (order.entityIndex) then
					local ent = Entity(order.entityIndex)
					if (IsValid(ent) and ent:GetClass() == order.entityClass) then
						client:Notify("Repair the entity directly — it is still present.")
						return
					end
				end

				PLUGIN:ManualCompleteWorkOrder(orderID, character)
				client:NotifyLocalized("cwuWorkOrderCompleted")
				netstream.Start(client, "CWUWorkOrderBoardOpen", PLUGIN:GetWorkOrders())
				return
			end
		end
	end)
else
	surface.CreateFont("ixWorkOrderBoard", {
		font = "Default",
		size = 16,
		weight = 800,
		antialias = false
	})

	surface.CreateFont("ixWorkOrderBoardSmall", {
		font = "Default",
		size = 11,
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

		cam.Start3D2D(position + self:GetForward() * 1 + self:GetUp() * 6, angles, 0.03)
			render.PushFilterMin(TEXFILTER.NONE)
			render.PushFilterMag(TEXFILTER.NONE)

			draw.SimpleText("WORK ORDERS", "ixWorkOrderBoard", 0, -20, Color(100, 175, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local orders = self:GetNetVar("workOrders", {})
			local pending = 0

			for _, order in ipairs(orders) do
				if (!order.completed) then
					pending = pending + 1
				end
			end

			local color = pending > 0 and Color(255, 200, 100) or Color(100, 255, 100)
			draw.SimpleText("Pending: " .. pending, "ixWorkOrderBoardSmall", 0, 0, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			render.PopFilterMin()
			render.PopFilterMag()
		cam.End3D2D()
	end
end
