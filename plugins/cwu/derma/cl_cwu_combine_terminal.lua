local PANEL = {}

function PANEL:Init()
	self:SetSize(620, 500)
	self:Center()
	self:MakePopup()
	self:SetTitle("Civil Workforce Oversight")

	self.tabs = vgui.Create("DPropertySheet", self)
	self.tabs:Dock(FILL)

	self:CreateTransactionAuditTab()
	self:CreateWorkOrderTab()
	self:CreateRosterTab()
	self:CreateInfrastructureTab()
end

function PANEL:SetData(data)
	self.data = data

	self:PopulateTransactionAudit()
	self:PopulateWorkOrders()
	self:PopulateRoster()
	self:PopulateInfrastructure()
end

-- Tab 1: Transaction Audit
function PANEL:CreateTransactionAuditTab()
	self.auditPanel = vgui.Create("DPanel", self.tabs)
	self.auditPanel:Dock(FILL)
	self.auditPanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(20, 20, 30)
		surface.DrawRect(0, 0, w, h)
	end

	local label = vgui.Create("DLabel", self.auditPanel)
	label:Dock(TOP)
	label:DockMargin(5, 5, 5, 5)
	label:SetText("Transaction Audit Log")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 150, 255))
	label:SizeToContents()

	self.auditList = vgui.Create("DListView", self.auditPanel)
	self.auditList:Dock(FILL)
	self.auditList:DockMargin(5, 0, 5, 5)
	self.auditList:AddColumn("Time"):SetFixedWidth(80)
	self.auditList:AddColumn("Buyer")
	self.auditList:AddColumn("Seller")
	self.auditList:AddColumn("Item")
	self.auditList:AddColumn("Price"):SetFixedWidth(60)
	self.auditList:AddColumn("Tax"):SetFixedWidth(50)
	self.auditList:SetMultiSelect(false)

	self.tabs:AddSheet("Audit", self.auditPanel, "icon16/magnifier.png")
end

function PANEL:PopulateTransactionAudit()
	if (!self.data) then
		return
	end

	self.auditList:Clear()

	local transactions = self.data.transactions or {}

	for i = #transactions, 1, -1 do
		local v = transactions[i]

		local line = self.auditList:AddLine(
			os.date("%m/%d %H:%M", v.time),
			v.buyer or "Unknown",
			v.seller or "Unknown",
			v.itemName or v.item or "Unknown",
			ix.currency.Get(v.price or 0),
			ix.currency.Get(v.tax or 0)
		)

		-- Flag suspicious items (contraband keywords)
		local itemName = (v.itemName or v.item or ""):lower()

		if (string.find(itemName, "stim") or string.find(itemName, "chem") or string.find(itemName, "drug") or string.find(itemName, "combat")) then
			for i = 1, 6 do
				line:GetChild(i):SetTextColor(Color(255, 100, 100))
			end
		end
	end
end

-- Tab 2: Work Orders
function PANEL:CreateWorkOrderTab()
	self.workOrderPanel = vgui.Create("DPanel", self.tabs)
	self.workOrderPanel:Dock(FILL)
	self.workOrderPanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(20, 20, 30)
		surface.DrawRect(0, 0, w, h)
	end

	local label = vgui.Create("DLabel", self.workOrderPanel)
	label:Dock(TOP)
	label:DockMargin(5, 5, 5, 5)
	label:SetText("Work Order Management")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 150, 255))
	label:SizeToContents()

	self.workOrderList = vgui.Create("DListView", self.workOrderPanel)
	self.workOrderList:Dock(FILL)
	self.workOrderList:DockMargin(5, 0, 5, 5)
	self.workOrderList:AddColumn("Type")
	self.workOrderList:AddColumn("Location")
	self.workOrderList:AddColumn("Priority")
	self.workOrderList:AddColumn("Status")
	self.workOrderList:SetMultiSelect(false)

	-- Submit work order form
	local submitPanel = vgui.Create("DPanel", self.workOrderPanel)
	submitPanel:Dock(BOTTOM)
	submitPanel:SetTall(70)
	submitPanel:DockMargin(5, 0, 5, 5)
	submitPanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(30, 30, 40)
		surface.DrawRect(0, 0, w, h)
	end

	local submitLabel = vgui.Create("DLabel", submitPanel)
	submitLabel:Dock(TOP)
	submitLabel:DockMargin(5, 2, 5, 0)
	submitLabel:SetText("Submit Work Order:")
	submitLabel:SetTextColor(Color(150, 150, 200))
	submitLabel:SizeToContents()

	local inputBar = vgui.Create("DPanel", submitPanel)
	inputBar:Dock(TOP)
	inputBar:SetTall(25)
	inputBar:DockMargin(5, 2, 5, 2)
	inputBar.Paint = nil

	self.woDescription = vgui.Create("DTextEntry", inputBar)
	self.woDescription:Dock(FILL)
	self.woDescription:DockMargin(0, 0, 5, 0)
	self.woDescription:SetPlaceholderText("Description")

	self.woLocation = vgui.Create("DTextEntry", inputBar)
	self.woLocation:Dock(RIGHT)
	self.woLocation:SetWide(120)
	self.woLocation:DockMargin(0, 0, 5, 0)
	self.woLocation:SetPlaceholderText("Location")

	self.woPriority = vgui.Create("DComboBox", inputBar)
	self.woPriority:Dock(RIGHT)
	self.woPriority:SetWide(80)
	self.woPriority:DockMargin(0, 0, 5, 0)
	self.woPriority:AddChoice("Low", 1)
	self.woPriority:AddChoice("Medium", 2)
	self.woPriority:AddChoice("High", 3)
	self.woPriority:SetValue("Medium")

	local submitBtn = vgui.Create("DButton", submitPanel)
	submitBtn:Dock(BOTTOM)
	submitBtn:DockMargin(5, 0, 5, 2)
	submitBtn:SetTall(20)
	submitBtn:SetText("Submit")
	submitBtn.DoClick = function()
		local desc = self.woDescription:GetValue()

		if (desc == "") then
			return
		end

		local loc = self.woLocation:GetValue()
		local _, priority = self.woPriority:GetSelected()

		netstream.Start("CWUCombineSubmitWorkOrder", desc, loc, priority or 2)
		self.woDescription:SetValue("")
		self.woLocation:SetValue("")
	end

	self.tabs:AddSheet("Work Orders", self.workOrderPanel, "icon16/clipboard.png")
end

function PANEL:PopulateWorkOrders()
	if (!self.data) then
		return
	end

	self.workOrderList:Clear()

	local priorityNames = {[1] = "Low", [2] = "Medium", [3] = "High"}
	local priorityColors = {[1] = Color(100, 200, 100), [2] = Color(255, 200, 100), [3] = Color(255, 100, 100)}

	for _, v in ipairs(self.data.workOrders or {}) do
		if (!v.completed) then
			local pName = priorityNames[v.priority] or "Medium"
			local line = self.workOrderList:AddLine(
				v.type or "manual",
				v.location or "Unknown",
				pName,
				v.assignedTo and ("Assigned: " .. v.assignedTo) or "Unassigned"
			)

			local color = priorityColors[v.priority] or Color(255, 255, 255)
			line:GetChild(2):SetTextColor(color)
		end
	end
end

-- Tab 3: CWU Roster
function PANEL:CreateRosterTab()
	self.rosterPanel = vgui.Create("DPanel", self.tabs)
	self.rosterPanel:Dock(FILL)
	self.rosterPanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(20, 20, 30)
		surface.DrawRect(0, 0, w, h)
	end

	local label = vgui.Create("DLabel", self.rosterPanel)
	label:Dock(TOP)
	label:DockMargin(5, 5, 5, 5)
	label:SetText("CWU Personnel Roster")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 150, 255))
	label:SizeToContents()

	self.rosterList = vgui.Create("DListView", self.rosterPanel)
	self.rosterList:Dock(FILL)
	self.rosterList:DockMargin(5, 0, 5, 5)
	self.rosterList:AddColumn("Name")
	self.rosterList:AddColumn("Division")
	self.rosterList:AddColumn("Loyalty Tier")
	self.rosterList:AddColumn("Role")
	self.rosterList:SetMultiSelect(false)

	self.tabs:AddSheet("Roster", self.rosterPanel, "icon16/vcard.png")
end

function PANEL:PopulateRoster()
	if (!self.data) then
		return
	end

	self.rosterList:Clear()

	for _, v in ipairs(self.data.roster or {}) do
		local division = v.division or "Unassigned"
		local tierInfo = PLUGIN.LoyaltyTiers[v.tier] or PLUGIN.LoyaltyTiers[0]

		self.rosterList:AddLine(
			v.name,
			division:sub(1, 1):upper() .. division:sub(2),
			v.tier .. " - " .. tierInfo.name,
			v.isDirector and "DIRECTOR" or "Worker"
		)
	end
end

-- Tab 4: Infrastructure Status
function PANEL:CreateInfrastructureTab()
	self.infraPanel = vgui.Create("DPanel", self.tabs)
	self.infraPanel:Dock(FILL)
	self.infraPanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(20, 20, 30)
		surface.DrawRect(0, 0, w, h)
	end

	local label = vgui.Create("DLabel", self.infraPanel)
	label:Dock(TOP)
	label:DockMargin(5, 5, 5, 5)
	label:SetText("Infrastructure Status")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 150, 255))
	label:SizeToContents()

	self.infraList = vgui.Create("DListView", self.infraPanel)
	self.infraList:Dock(FILL)
	self.infraList:DockMargin(5, 0, 5, 5)
	self.infraList:AddColumn("Type")
	self.infraList:AddColumn("Location")
	self.infraList:AddColumn("Status")
	self.infraList:AddColumn("Priority")
	self.infraList:SetMultiSelect(false)

	self.tabs:AddSheet("Infrastructure", self.infraPanel, "icon16/building.png")
end

function PANEL:PopulateInfrastructure()
	if (!self.data) then
		return
	end

	self.infraList:Clear()

	local priorityNames = {[1] = "Low", [2] = "Medium", [3] = "High"}

	for _, v in ipairs(self.data.infrastructure or {}) do
		local statusText = v.broken and "BROKEN" or "Operational"
		local statusColor = v.broken and Color(255, 100, 100) or Color(100, 255, 100)

		local line = self.infraList:AddLine(
			(v.type or "unknown"):upper(),
			v.location or "Unknown",
			statusText,
			priorityNames[v.priority] or "Medium"
		)

		line:GetChild(2):SetTextColor(statusColor)
	end
end

vgui.Register("ixCWUCombineTerminal", PANEL, "DFrame")

netstream.Hook("CWUCombineTerminalOpen", function(data)
	if (IsValid(ix.gui.cwuCombineTerminal)) then
		ix.gui.cwuCombineTerminal:Remove()
	end

	ix.gui.cwuCombineTerminal = vgui.Create("ixCWUCombineTerminal")
	ix.gui.cwuCombineTerminal:SetData(data)
end)
