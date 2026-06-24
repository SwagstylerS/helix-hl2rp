-- Work order system for CWU Maintenance division

function PLUGIN:GetWorkOrders()
	return ix.data.Get("cwuWorkOrders", {})
end

function PLUGIN:SaveWorkOrders(orders)
	ix.data.Set("cwuWorkOrders", orders)

	if (#orders > ix.config.Get("cwuMaxWorkOrders", 200)) then
		self:CleanCompletedWorkOrders()
	end
end

local function NextOrderID(orders)
	local maxID = 0
	for _, o in ipairs(orders) do
		if (o.id and o.id > maxID) then maxID = o.id end
	end
	return maxID + 1
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

	local ePos = entity:GetPos()
	orders[#orders + 1] = {
		id = NextOrderID(orders),
		entityIndex = entity:EntIndex(),
		entityClass = entity:GetClass(),
		type = breakableInfo.type,
		location = string.format("%d, %d", math.floor(ePos.x), math.floor(ePos.y)),
		priority = breakableInfo.priority,
		time = os.time(),
		assignedTo = nil,
		completed = false
	}

	self:SaveWorkOrders(orders)
	self:RefreshWorkOrderBoards()

	for _, ply in ipairs(player.GetAll()) do
		if (IsValid(ply) and ply:GetCWUDivision() == "maintenance") then
			netstream.Start(ply, "CWUNewWorkOrder", {type = breakableInfo.type, location = string.format("%d, %d", math.floor(ePos.x), math.floor(ePos.y))})
		end
	end
end

function PLUGIN:SubmitManualWorkOrder(description, location, priority, submitter)
	local orders = self:GetWorkOrders()

	orders[#orders + 1] = {
		id = NextOrderID(orders),
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
	local orderType, orderLocation = "infrastructure", "Unknown"

	for _, order in ipairs(orders) do
		if (order.entityIndex == entityIndex and !order.completed) then
			order.completed = true
			order.completedTime = os.time()
			orderType = order.type or "infrastructure"
			orderLocation = order.location or "Unknown"
		end
	end

	self:SaveWorkOrders(orders)
	self:RefreshWorkOrderBoards()

	if (character) then
		self:LogWorkEntry(character, orderType, orderLocation)
	end
end

function PLUGIN:CleanCompletedWorkOrders()
	local orders = self:GetWorkOrders()
	local maxOrders = ix.config.Get("cwuMaxWorkOrders", 200)

	if (#orders <= maxOrders) then return end

	local completed = {}
	local pending = {}

	for _, order in ipairs(orders) do
		if (order.completed) then
			completed[#completed + 1] = order
		else
			pending[#pending + 1] = order
		end
	end

	table.sort(completed, function(a, b)
		return (a.completedTime or 0) < (b.completedTime or 0)
	end)

	local keep = math.max(0, maxOrders - #pending)
	local result = {}

	for _, o in ipairs(pending) do result[#result + 1] = o end

	for i = #completed - keep + 1, #completed do
		if (i >= 1) then result[#result + 1] = completed[i] end
	end

	ix.data.Set("cwuWorkOrders", result)
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
	local orderType, orderLocation = "manual", "Unknown"

	for _, order in ipairs(orders) do
		if (order.id == orderID and !order.completed) then
			order.completed = true
			order.completedTime = os.time()
			orderType = order.type or "manual"
			orderLocation = order.location or "Unknown"
			break
		end
	end

	self:SaveWorkOrders(orders)
	self:RefreshWorkOrderBoards()

	if (character) then
		self:LogWorkEntry(character, orderType, orderLocation)
	end
end

function PLUGIN:LogWorkEntry(character, orderType, orderLocation)
	local log = ix.data.Get("cwuWorkLog", {})
	local charIDStr = tostring(character:GetID())

	log[charIDStr] = log[charIDStr] or {}
	log[charIDStr][#log[charIDStr] + 1] = {
		charID = character:GetID(),
		charName = character:GetName(),
		type = orderType,
		location = orderLocation,
		time = os.time(),
		paid = false
	}

	ix.data.Set("cwuWorkLog", log)
end

function PLUGIN:RefreshWorkOrderBoards()
	local orders = self:GetWorkOrders()

	for _, board in ipairs(ents.FindByClass("ix_workorderboard")) do
		if (IsValid(board)) then
			board:SetNetVar("workOrders", orders)
		end
	end
end
