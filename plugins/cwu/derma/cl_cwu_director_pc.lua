local PANEL = {}

function PANEL:Init()
	self:SetSize(600, 500)
	self:Center()
	self:MakePopup()
	self:SetTitle("CWU Director Terminal")

	self.tabs = vgui.Create("DPropertySheet", self)
	self.tabs:Dock(FILL)

	self:CreatePersonnelTab()
	self:CreateBlueprintTab()
	self:CreateLicenseTab()
	self:CreateMedicalTrainingTab()
	self:CreateTreasuryTab()
	self:CreateTransactionLogTab()
end

function PANEL:SetData(data)
	self.data = data

	self:PopulatePersonnel()
	self:PopulateBlueprints()
	self:PopulateLicenses()
	self:PopulateMedicalTraining()
	self:PopulateTreasury()
	self:PopulateTransactionLog()
end

-- Tab 1: Personnel Management
function PANEL:CreatePersonnelTab()
	self.personnelPanel = vgui.Create("DPanel", self.tabs)
	self.personnelPanel:Dock(FILL)
	self.personnelPanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(30, 30, 30)
		surface.DrawRect(0, 0, w, h)
	end

	local topBar = vgui.Create("DPanel", self.personnelPanel)
	topBar:Dock(TOP)
	topBar:SetTall(30)
	topBar:DockMargin(5, 5, 5, 5)
	topBar.Paint = nil

	local label = vgui.Create("DLabel", topBar)
	label:Dock(LEFT)
	label:SetText("Personnel Management")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 175, 100))
	label:SizeToContents()

	self.personnelList = vgui.Create("DListView", self.personnelPanel)
	self.personnelList:Dock(FILL)
	self.personnelList:DockMargin(5, 0, 5, 5)
	self.personnelList:AddColumn("Name")
	self.personnelList:AddColumn("Status")
	self.personnelList:AddColumn("Tier")
	self.personnelList:SetMultiSelect(false)

	local buttonBar = vgui.Create("DPanel", self.personnelPanel)
	buttonBar:Dock(BOTTOM)
	buttonBar:SetTall(35)
	buttonBar:DockMargin(5, 0, 5, 5)
	buttonBar.Paint = nil

	local divisionCombo = vgui.Create("DComboBox", buttonBar)
	divisionCombo:Dock(LEFT)
	divisionCombo:SetWide(150)
	divisionCombo:DockMargin(0, 0, 5, 0)
	divisionCombo:AddChoice("Production", "production")
	divisionCombo:AddChoice("Maintenance", "maintenance")
	divisionCombo:AddChoice("Medical", "medical")
	divisionCombo:AddChoice("Commerce", "commerce")
	divisionCombo:SetValue("Select Division")
	self.divisionCombo = divisionCombo

	local assignBtn = vgui.Create("DButton", buttonBar)
	assignBtn:Dock(LEFT)
	assignBtn:SetWide(100)
	assignBtn:DockMargin(0, 0, 5, 0)
	assignBtn:SetText("Assign to CWU")
	assignBtn.DoClick = function()
		local _, _, charID = self.personnelList:GetSelectedLine()

		if (!charID) then
			return
		end

		local _, division = divisionCombo:GetSelected()

		if (!division) then
			return
		end

		local line = self.personnelList:GetLine(self.personnelList:GetSelectedLine())

		if (line) then
			netstream.Start("CWUDirectorAssign", line.charID, division)
		end
	end

	local removeBtn = vgui.Create("DButton", buttonBar)
	removeBtn:Dock(LEFT)
	removeBtn:SetWide(120)
	removeBtn:SetText("Remove from CWU")
	removeBtn.DoClick = function()
		local lineID = self.personnelList:GetSelectedLine()

		if (!lineID) then
			return
		end

		local line = self.personnelList:GetLine(lineID)

		if (line and line.charID) then
			netstream.Start("CWUDirectorRemove", line.charID)
		end
	end

	self.tabs:AddSheet("Personnel", self.personnelPanel, "icon16/group.png")
end

function PANEL:PopulatePersonnel()
	if (!self.data) then
		return
	end

	self.personnelList:Clear()

	-- Show CWU members first
	for _, v in ipairs(self.data.cwuMembers or {}) do
		local line = self.personnelList:AddLine(v.name, "CWU - " .. (v.division or "Unassigned"), v.tier)
		line.charID = v.charID
	end

	-- Then unassigned citizens
	for _, v in ipairs(self.data.citizens or {}) do
		local line = self.personnelList:AddLine(v.name, "Citizen", v.tier)
		line.charID = v.charID
	end
end

-- Tab 2: Blueprint Approvals
function PANEL:CreateBlueprintTab()
	self.blueprintPanel = vgui.Create("DPanel", self.tabs)
	self.blueprintPanel:Dock(FILL)
	self.blueprintPanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(30, 30, 30)
		surface.DrawRect(0, 0, w, h)
	end

	local label = vgui.Create("DLabel", self.blueprintPanel)
	label:Dock(TOP)
	label:DockMargin(5, 5, 5, 5)
	label:SetText("Restricted Blueprint Approvals")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 175, 100))
	label:SizeToContents()

	self.blueprintList = vgui.Create("DListView", self.blueprintPanel)
	self.blueprintList:Dock(FILL)
	self.blueprintList:DockMargin(5, 0, 5, 5)
	self.blueprintList:AddColumn("Worker")
	self.blueprintList:AddColumn("Blueprint")
	self.blueprintList:AddColumn("Status")
	self.blueprintList:SetMultiSelect(false)

	local toggleBtn = vgui.Create("DButton", self.blueprintPanel)
	toggleBtn:Dock(BOTTOM)
	toggleBtn:DockMargin(5, 0, 5, 5)
	toggleBtn:SetTall(30)
	toggleBtn:SetText("Toggle Approval")
	toggleBtn.DoClick = function()
		local lineID = self.blueprintList:GetSelectedLine()

		if (!lineID) then
			return
		end

		local line = self.blueprintList:GetLine(lineID)

		if (line and line.charID and line.bpID) then
			local newStatus = !line.approved
			netstream.Start("CWUDirectorApproveBlueprint", line.charID, line.bpID, newStatus)
			line:SetColumnText(3, newStatus and "APPROVED" or "DENIED")
			line.approved = newStatus
		end
	end

	self.tabs:AddSheet("Blueprints", self.blueprintPanel, "icon16/wrench.png")
end

function PANEL:PopulateBlueprints()
	if (!self.data) then
		return
	end

	self.blueprintList:Clear()

	-- Find restricted blueprints
	local restrictedBPs = {}

	for bpID, bp in pairs(PLUGIN.Blueprints) do
		if (bp.tier == 2) then
			restrictedBPs[bpID] = bp
		end
	end

	-- Show each Production worker's approval status for each restricted blueprint
	for _, member in ipairs(self.data.cwuMembers or {}) do
		if (member.division == "production") then
			local approvals = self.data.blueprintApprovals[member.charID] or {}

			for bpID, bp in pairs(restrictedBPs) do
				local approved = approvals[bpID] or false
				local line = self.blueprintList:AddLine(member.name, bp.name, approved and "APPROVED" or "DENIED")
				line.charID = member.charID
				line.bpID = bpID
				line.approved = approved
			end
		end
	end
end

-- Tab 3: Business Licenses
function PANEL:CreateLicenseTab()
	self.licensePanel = vgui.Create("DPanel", self.tabs)
	self.licensePanel:Dock(FILL)
	self.licensePanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(30, 30, 30)
		surface.DrawRect(0, 0, w, h)
	end

	local label = vgui.Create("DLabel", self.licensePanel)
	label:Dock(TOP)
	label:DockMargin(5, 5, 5, 5)
	label:SetText("Business License Management")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 175, 100))
	label:SizeToContents()

	self.licenseList = vgui.Create("DListView", self.licensePanel)
	self.licenseList:Dock(FILL)
	self.licenseList:DockMargin(5, 0, 5, 5)
	self.licenseList:AddColumn("Worker")
	self.licenseList:AddColumn("Division")
	self.licenseList:SetMultiSelect(false)

	local buttonBar = vgui.Create("DPanel", self.licensePanel)
	buttonBar:Dock(BOTTOM)
	buttonBar:SetTall(35)
	buttonBar:DockMargin(5, 0, 5, 5)
	buttonBar.Paint = nil

	local grantBtn = vgui.Create("DButton", buttonBar)
	grantBtn:Dock(LEFT)
	grantBtn:SetWide(150)
	grantBtn:DockMargin(0, 0, 5, 0)
	grantBtn:SetText("Grant License")
	grantBtn.DoClick = function()
		local lineID = self.licenseList:GetSelectedLine()

		if (!lineID) then
			return
		end

		local line = self.licenseList:GetLine(lineID)

		if (line and line.charID) then
			netstream.Start("CWUDirectorLicense", line.charID, true)
		end
	end

	local revokeBtn = vgui.Create("DButton", buttonBar)
	revokeBtn:Dock(LEFT)
	revokeBtn:SetWide(150)
	revokeBtn:SetText("Revoke License")
	revokeBtn.DoClick = function()
		local lineID = self.licenseList:GetSelectedLine()

		if (!lineID) then
			return
		end

		local line = self.licenseList:GetLine(lineID)

		if (line and line.charID) then
			netstream.Start("CWUDirectorLicense", line.charID, false)
		end
	end

	self.tabs:AddSheet("Licenses", self.licensePanel, "icon16/money.png")
end

function PANEL:PopulateLicenses()
	if (!self.data) then
		return
	end

	self.licenseList:Clear()

	for _, member in ipairs(self.data.cwuMembers or {}) do
		local line = self.licenseList:AddLine(member.name, member.division or "Unassigned")
		line.charID = member.charID
	end
end

-- Tab 4: Medical Training
function PANEL:CreateMedicalTrainingTab()
	self.medicalPanel = vgui.Create("DPanel", self.tabs)
	self.medicalPanel:Dock(FILL)
	self.medicalPanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(30, 30, 30)
		surface.DrawRect(0, 0, w, h)
	end

	local label = vgui.Create("DLabel", self.medicalPanel)
	label:Dock(TOP)
	label:DockMargin(5, 5, 5, 5)
	label:SetText("Medical Training Authorization")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 175, 100))
	label:SizeToContents()

	self.medicalList = vgui.Create("DListView", self.medicalPanel)
	self.medicalList:Dock(FILL)
	self.medicalList:DockMargin(5, 0, 5, 5)
	self.medicalList:AddColumn("Worker")
	self.medicalList:AddColumn("Training Status")
	self.medicalList:SetMultiSelect(false)

	local toggleBtn = vgui.Create("DButton", self.medicalPanel)
	toggleBtn:Dock(BOTTOM)
	toggleBtn:DockMargin(5, 0, 5, 5)
	toggleBtn:SetTall(30)
	toggleBtn:SetText("Toggle Training")
	toggleBtn.DoClick = function()
		local lineID = self.medicalList:GetSelectedLine()

		if (!lineID) then
			return
		end

		local line = self.medicalList:GetLine(lineID)

		if (line and line.charID) then
			local newStatus = !line.trained
			netstream.Start("CWUDirectorMedicalTraining", line.charID, newStatus)
			line:SetColumnText(2, newStatus and "TRAINED" or "UNTRAINED")
			line.trained = newStatus
		end
	end

	self.tabs:AddSheet("Medical", self.medicalPanel, "icon16/heart.png")
end

function PANEL:PopulateMedicalTraining()
	if (!self.data) then
		return
	end

	self.medicalList:Clear()

	for _, member in ipairs(self.data.cwuMembers or {}) do
		if (member.division == "medical") then
			local line = self.medicalList:AddLine(member.name, member.medicalTraining and "TRAINED" or "UNTRAINED")
			line.charID = member.charID
			line.trained = member.medicalTraining
		end
	end
end

-- Tab 5: Treasury
function PANEL:CreateTreasuryTab()
	self.treasuryPanel = vgui.Create("DPanel", self.tabs)
	self.treasuryPanel:Dock(FILL)
	self.treasuryPanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(30, 30, 30)
		surface.DrawRect(0, 0, w, h)
	end

	local label = vgui.Create("DLabel", self.treasuryPanel)
	label:Dock(TOP)
	label:DockMargin(5, 5, 5, 5)
	label:SetText("CWU Treasury")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 175, 100))
	label:SizeToContents()

	self.treasuryBalance = vgui.Create("DLabel", self.treasuryPanel)
	self.treasuryBalance:Dock(TOP)
	self.treasuryBalance:DockMargin(5, 0, 5, 5)
	self.treasuryBalance:SetFont("DermaDefaultBold")
	self.treasuryBalance:SetTextColor(Color(255, 215, 0))
	self.treasuryBalance:SetText("Balance: 0 tokens")
	self.treasuryBalance:SizeToContents()

	local withdrawBar = vgui.Create("DPanel", self.treasuryPanel)
	withdrawBar:Dock(TOP)
	withdrawBar:SetTall(30)
	withdrawBar:DockMargin(5, 0, 5, 5)
	withdrawBar.Paint = nil

	self.withdrawAmount = vgui.Create("DTextEntry", withdrawBar)
	self.withdrawAmount:Dock(LEFT)
	self.withdrawAmount:SetWide(150)
	self.withdrawAmount:DockMargin(0, 0, 5, 0)
	self.withdrawAmount:SetNumeric(true)
	self.withdrawAmount:SetPlaceholderText("Amount")

	local withdrawBtn = vgui.Create("DButton", withdrawBar)
	withdrawBtn:Dock(LEFT)
	withdrawBtn:SetWide(120)
	withdrawBtn:SetText("Withdraw")
	withdrawBtn.DoClick = function()
		local amount = tonumber(self.withdrawAmount:GetValue())

		if (amount and amount > 0) then
			netstream.Start("CWUDirectorWithdraw", amount)
		end
	end

	local recentLabel = vgui.Create("DLabel", self.treasuryPanel)
	recentLabel:Dock(TOP)
	recentLabel:DockMargin(5, 10, 5, 5)
	recentLabel:SetText("Recent Transactions")
	recentLabel:SetFont("DermaDefaultBold")
	recentLabel:SetTextColor(Color(150, 150, 150))
	recentLabel:SizeToContents()

	self.treasuryTransactions = vgui.Create("DListView", self.treasuryPanel)
	self.treasuryTransactions:Dock(FILL)
	self.treasuryTransactions:DockMargin(5, 0, 5, 5)
	self.treasuryTransactions:AddColumn("Time")
	self.treasuryTransactions:AddColumn("Item")
	self.treasuryTransactions:AddColumn("Tax")
	self.treasuryTransactions:SetMultiSelect(false)

	self.tabs:AddSheet("Treasury", self.treasuryPanel, "icon16/coins.png")
end

function PANEL:PopulateTreasury()
	if (!self.data) then
		return
	end

	self.treasuryBalance:SetText("Balance: " .. ix.currency.Get(self.data.treasury or 0))
	self.treasuryBalance:SizeToContents()

	self.treasuryTransactions:Clear()

	for _, v in ipairs(self.data.recentTransactions or {}) do
		self.treasuryTransactions:AddLine(
			os.date("%m/%d %H:%M", v.time),
			v.itemName or v.item or "Unknown",
			ix.currency.Get(v.tax or 0)
		)
	end
end

-- Tab 6: Transaction Log
function PANEL:CreateTransactionLogTab()
	self.transLogPanel = vgui.Create("DPanel", self.tabs)
	self.transLogPanel:Dock(FILL)
	self.transLogPanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(30, 30, 30)
		surface.DrawRect(0, 0, w, h)
	end

	local label = vgui.Create("DLabel", self.transLogPanel)
	label:Dock(TOP)
	label:DockMargin(5, 5, 5, 5)
	label:SetText("Transaction Log")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 175, 100))
	label:SizeToContents()

	self.transLogList = vgui.Create("DListView", self.transLogPanel)
	self.transLogList:Dock(FILL)
	self.transLogList:DockMargin(5, 0, 5, 5)
	self.transLogList:AddColumn("Time"):SetFixedWidth(80)
	self.transLogList:AddColumn("Buyer")
	self.transLogList:AddColumn("Seller")
	self.transLogList:AddColumn("Item")
	self.transLogList:AddColumn("Price"):SetFixedWidth(60)
	self.transLogList:AddColumn("Tax"):SetFixedWidth(50)
	self.transLogList:SetMultiSelect(false)

	self.tabs:AddSheet("Transactions", self.transLogPanel, "icon16/book.png")
end

function PANEL:PopulateTransactionLog()
	if (!self.data) then
		return
	end

	self.transLogList:Clear()

	local transactions = self.data.allTransactions or {}

	-- Show newest first
	for i = #transactions, 1, -1 do
		local v = transactions[i]

		self.transLogList:AddLine(
			os.date("%m/%d %H:%M", v.time),
			v.buyer or "Unknown",
			v.seller or "Unknown",
			v.itemName or v.item or "Unknown",
			ix.currency.Get(v.price or 0),
			ix.currency.Get(v.tax or 0)
		)
	end
end

vgui.Register("ixCWUDirectorPC", PANEL, "DFrame")

-- Open when server sends data
netstream.Hook("CWUDirectorPCOpen", function(data)
	if (IsValid(ix.gui.cwuDirectorPC)) then
		ix.gui.cwuDirectorPC:Remove()
	end

	ix.gui.cwuDirectorPC = vgui.Create("ixCWUDirectorPC")
	ix.gui.cwuDirectorPC:SetData(data)
end)
