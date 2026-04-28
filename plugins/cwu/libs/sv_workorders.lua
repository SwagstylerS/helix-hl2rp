-- Work order system for CWU Maintenance division

function PLUGIN:GetWorkOrders()
	return ix.data.Get("cwuWorkOrders", {})
end

function PLUGIN:SaveWorkOrders(orders)
	ix.data.Set("cwuWorkOrders", orders)
end

function PLUGIN:GenerateWorkOrder(entity)
	local orders = self:GetWorkOrders()
	local breakableInfo = self.BreakableTypes[entity:GetClass()]

	if (!breakableInfo) then
		return
	end

	-- Check for duplicate order on same entity
	for _, order in ipairs(orders) do
		if (order.entityIndex == entity:EntIndex() and !order.completed) then
			return
		end
	end

	orders[#orders + 1] = {
		id = #orders + 1,
		entityIndex = entity:EntIndex(),
		entityClass = entity:GetClass(),
		type = breakableInfo.type,
		location = entity:GetArea() or "Unknown",
		priority = breakableInfo.priority,
		time = os.time(),
		assignedTo = nil,
		completed = false
	}

	self:SaveWorkOrders(orders)
	self:RefreshWorkOrderBoards()
end

function PLUGIN:SubmitManualWorkOrder(description, location, priority, submitter)
	local orders = self:GetWorkOrders()

	orders[#orders + 1] = {
		id = #orders + 1,
		entityIndex = nil,
		entityClass = nil,
		type = "manual",
		description = description,
		location = location or "Unknown",
		priority = priority or 2,
		time = os.time(),
		submittedBy = submitter,
		assignedTo = nil,
		completed = false
	}

	self:SaveWorkOrders(orders)
	self:RefreshWorkOrderBoards()
end

function PLUGIN:CompleteWorkOrder(entityIndex, character)
	local orders = self:GetWorkOrders()

	for _, order in ipairs(orders) do
		if (order.entityIndex == entityIndex and !order.completed) then
			order.completed = true
			order.completedTime = os.time()
		end
	end

	if (character) then
		self:AwardLoyalty(character, 2, "repair")
	end

	self:SaveWorkOrders(orders)
	self:RefreshWorkOrderBoards()
end

function PLUGIN:CleanCompletedWorkOrders()
	local orders = self:GetWorkOrders()
	local cleaned = {}

	for _, order in ipairs(orders) do
		if (!order.completed) then
			cleaned[#cleaned + 1] = order
		end
	end

	self:SaveWorkOrders(cleaned)
end

function PLUGIN:ClaimWorkOrder(orderID, charName)
	local orders = self:GetWorkOrders()

	for _, order in ipairs(orders) do
		if (order.id == orderID and !order.completed) then
			order.assignedTo = charName
			break
		end
	end

	self:SaveWorkOrders(orders)
	self:RefreshWorkOrderBoards()
end

function PLUGIN:ManualCompleteWorkOrder(orderID, character)
	local orders = self:GetWorkOrders()

	for _, order in ipairs(orders) do
		if (order.id == orderID and !order.completed) then
			order.completed = true
			order.completedTime = os.time()
			break
		end
	end

	self:AwardLoyalty(character, 2, "repair")
	self:SaveWorkOrders(orders)
	self:RefreshWorkOrderBoards()
end

function PLUGIN:RefreshWorkOrderBoards()
	local orders = self:GetWorkOrders()

	for _, board in ipairs(ents.FindByClass("ix_workorderboard")) do
		if (IsValid(board)) then
			board:SetNetVar("workOrders", orders)
		end
	end
end
