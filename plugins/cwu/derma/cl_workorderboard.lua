local PANEL = {}

function PANEL:Init()
	self:SetSize(560, 460)
	self:Center()
	self:MakePopup()
	self:SetTitle("CWU Work Order Board")
end

function PANEL:SetOrders(orders)
	if (IsValid(self.header)) then self.header:Remove() end
	if (IsValid(self.scroll)) then self.scroll:Remove() end

	self.header = vgui.Create("DLabel", self)
	self.header:Dock(TOP)
	self.header:DockMargin(8, 6, 8, 4)
	self.header:SetText("Active Work Orders")
	self.header:SetFont("DermaDefaultBold")
	self.header:SetTextColor(Color(100, 175, 100))
	self.header:SizeToContents()

	self.scroll = vgui.Create("DScrollPanel", self)
	self.scroll:Dock(FILL)
	self.scroll:DockMargin(8, 0, 8, 8)

	local priorityColors = {[1] = Color(100, 200, 100), [2] = Color(255, 200, 100), [3] = Color(255, 100, 100)}
	local priorityNames  = {[1] = "Low", [2] = "Medium", [3] = "High"}

	local charName = ""
	local char = LocalPlayer():GetCharacter()
	if (char) then charName = char:GetName() end

	local pendingCount = 0

	for _, order in ipairs(orders or {}) do
		if (order.completed) then continue end
		pendingCount = pendingCount + 1

		local orderID       = order.id
		local isAssigned    = (order.assignedTo != nil and order.assignedTo != false)
		local isAssignedToMe = (charName != "" and order.assignedTo == charName)

		local row = vgui.Create("DPanel", self.scroll)
		row:Dock(TOP)
		row:DockMargin(0, 0, 0, 2)
		row:SetHeight(48)
		row.Paint = function(_, w, h)
			surface.SetDrawColor(35, 50, 35, 255)
			surface.DrawRect(0, 0, w, h)
		end

		-- Build right-side elements first so FILL gets the correct remaining space
		local doneBtn = vgui.Create("DButton", row)
		doneBtn:Dock(RIGHT)
		doneBtn:DockMargin(2, 8, 6, 8)
		doneBtn:SetWidth(62)
		doneBtn:SetText("DONE")
		doneBtn:SetFont("DermaDefaultBold")
		doneBtn:SetEnabled(isAssignedToMe)
		doneBtn.DoClick = function()
			netstream.Start("CWUWorkOrderComplete", orderID)
		end

		local claimBtn = vgui.Create("DButton", row)
		claimBtn:Dock(RIGHT)
		claimBtn:DockMargin(2, 8, 2, 8)
		claimBtn:SetWidth(62)
		claimBtn:SetText("CLAIM")
		claimBtn:SetFont("DermaDefaultBold")
		claimBtn:SetEnabled(!isAssigned)
		claimBtn.DoClick = function()
			netstream.Start("CWUWorkOrderClaim", orderID)
		end

		local priLabel = vgui.Create("DLabel", row)
		priLabel:Dock(RIGHT)
		priLabel:DockMargin(0, 0, 6, 0)
		priLabel:SetWidth(58)
		priLabel:SetContentAlignment(5)
		priLabel:SetText(priorityNames[order.priority] or "Medium")
		priLabel:SetFont("DermaDefault")
		priLabel:SetTextColor(priorityColors[order.priority] or Color(255, 200, 100))

		-- Type badge (LEFT)
		local typeLabel = vgui.Create("DLabel", row)
		typeLabel:Dock(LEFT)
		typeLabel:DockMargin(8, 0, 0, 0)
		typeLabel:SetWidth(84)
		typeLabel:SetContentAlignment(4)
		typeLabel:SetText((order.type or "?"):upper())
		typeLabel:SetFont("DermaDefaultBold")
		typeLabel:SetTextColor(Color(180, 220, 180))

		-- Info panel (FILL)
		local info = vgui.Create("DPanel", row)
		info:Dock(FILL)
		info:DockMargin(4, 4, 4, 4)
		info:SetPaintBackground(false)

		local locText = (order.location or "Unknown")
		if (order.description and order.description != "") then
			locText = locText .. " — " .. order.description
		end

		local locLabel = vgui.Create("DLabel", info)
		locLabel:Dock(TOP)
		locLabel:SetHeight(18)
		locLabel:SetText(locText)
		locLabel:SetFont("DermaDefault")
		locLabel:SetTextColor(Color(200, 200, 200))

		local statusText  = isAssigned and ("→ " .. order.assignedTo) or "UNASSIGNED"
		local statusColor = isAssigned and Color(200, 200, 100) or Color(140, 140, 140)

		local statusLabel = vgui.Create("DLabel", info)
		statusLabel:Dock(TOP)
		statusLabel:SetHeight(16)
		statusLabel:SetText(statusText)
		statusLabel:SetFont("DermaDefault")
		statusLabel:SetTextColor(statusColor)
	end

	if (pendingCount == 0) then
		local noOrders = vgui.Create("DLabel", self.scroll)
		noOrders:Dock(TOP)
		noOrders:DockMargin(8, 14, 8, 8)
		noOrders:SetText("No pending work orders. All systems operational.")
		noOrders:SetFont("DermaDefault")
		noOrders:SetTextColor(Color(100, 255, 100))
		noOrders:SizeToContents()
	end
end

vgui.Register("ixCWUWorkOrderBoard", PANEL, "DFrame")

netstream.Hook("CWUWorkOrderBoardOpen", function(orders)
	if (IsValid(ix.gui.cwuWorkOrders)) then
		ix.gui.cwuWorkOrders:Remove()
	end

	ix.gui.cwuWorkOrders = vgui.Create("ixCWUWorkOrderBoard")
	ix.gui.cwuWorkOrders:SetOrders(orders)
end)
