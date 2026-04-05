local PANEL = {}

function PANEL:Init()
	self:SetSize(500, 400)
	self:Center()
	self:MakePopup()
	self:SetTitle("CWU Work Order Board")
end

function PANEL:SetOrders(orders)
	local label = vgui.Create("DLabel", self)
	label:Dock(TOP)
	label:DockMargin(5, 5, 5, 5)
	label:SetText("Active Work Orders")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 175, 100))
	label:SizeToContents()

	self.list = vgui.Create("DListView", self)
	self.list:Dock(FILL)
	self.list:DockMargin(5, 0, 5, 5)
	self.list:AddColumn("Type"):SetFixedWidth(70)
	self.list:AddColumn("Location")
	self.list:AddColumn("Priority"):SetFixedWidth(70)
	self.list:AddColumn("Status")
	self.list:AddColumn("Description")
	self.list:SetMultiSelect(false)

	local priorityNames = {[1] = "Low", [2] = "Medium", [3] = "High"}
	local priorityColors = {[1] = Color(100, 200, 100), [2] = Color(255, 200, 100), [3] = Color(255, 100, 100)}

	local pendingCount = 0

	for _, order in ipairs(orders or {}) do
		if (!order.completed) then
			pendingCount = pendingCount + 1

			local pName = priorityNames[order.priority] or "Medium"
			local line = self.list:AddLine(
				(order.type or "?"):upper(),
				order.location or "Unknown",
				pName,
				order.assignedTo and ("Assigned: " .. order.assignedTo) or "UNASSIGNED",
				order.description or ""
			)

			local color = priorityColors[order.priority]

			if (color) then
				line:GetChild(2):SetTextColor(color)
			end
		end
	end

	if (pendingCount == 0) then
		local noOrders = vgui.Create("DLabel", self)
		noOrders:Dock(BOTTOM)
		noOrders:DockMargin(5, 5, 5, 5)
		noOrders:SetText("No pending work orders. All systems operational.")
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
