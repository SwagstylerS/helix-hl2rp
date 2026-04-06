-- Vendor Management Panel (for owner)
local MANAGE = {}

function MANAGE:Init()
	self:SetSize(450, 400)
	self:Center()
	self:MakePopup()
	self:SetTitle("Vendor Terminal - Management")
end

function MANAGE:SetData(entIndex, stock, earnings)
	self.entIndex = entIndex

	-- Earnings display
	local earningsLabel = vgui.Create("DLabel", self)
	earningsLabel:Dock(TOP)
	earningsLabel:DockMargin(5, 5, 5, 2)
	earningsLabel:SetText("Earnings: " .. ix.currency.Get(earnings))
	earningsLabel:SetFont("DermaDefaultBold")
	earningsLabel:SetTextColor(Color(255, 215, 0))
	earningsLabel:SizeToContents()

	local withdrawBtn = vgui.Create("DButton", self)
	withdrawBtn:Dock(TOP)
	withdrawBtn:DockMargin(5, 0, 5, 5)
	withdrawBtn:SetTall(25)
	withdrawBtn:SetText("Withdraw Earnings")
	withdrawBtn:SetEnabled(earnings > 0)
	withdrawBtn.DoClick = function()
		netstream.Start("CWUVendorWithdraw", self.entIndex)
		self:Remove()
	end

	-- Rename
	local renameBar = vgui.Create("DPanel", self)
	renameBar:Dock(TOP)
	renameBar:SetTall(25)
	renameBar:DockMargin(5, 0, 5, 5)
	renameBar.Paint = nil

	local renameEntry = vgui.Create("DTextEntry", renameBar)
	renameEntry:Dock(FILL)
	renameEntry:DockMargin(0, 0, 5, 0)
	renameEntry:SetPlaceholderText("Terminal Name")

	local renameBtn = vgui.Create("DButton", renameBar)
	renameBtn:Dock(RIGHT)
	renameBtn:SetWide(80)
	renameBtn:SetText("Rename")
	renameBtn.DoClick = function()
		local name = renameEntry:GetValue()

		if (name != "") then
			netstream.Start("CWUVendorRename", self.entIndex, name)
		end
	end

	-- Stock list
	local stockLabel = vgui.Create("DLabel", self)
	stockLabel:Dock(TOP)
	stockLabel:DockMargin(5, 0, 5, 2)
	stockLabel:SetText("Current Stock:")
	stockLabel:SetFont("DermaDefaultBold")
	stockLabel:SetTextColor(Color(100, 175, 100))
	stockLabel:SizeToContents()

	self.stockList = vgui.Create("DListView", self)
	self.stockList:Dock(FILL)
	self.stockList:DockMargin(5, 0, 5, 5)
	self.stockList:AddColumn("Item")
	self.stockList:AddColumn("Price"):SetFixedWidth(80)
	self.stockList:SetMultiSelect(false)

	for i, entry in ipairs(stock) do
		local line = self.stockList:AddLine(entry.name, ix.currency.Get(entry.price))
		line.stockIndex = i
	end

	local removeBtn = vgui.Create("DButton", self)
	removeBtn:Dock(BOTTOM)
	removeBtn:DockMargin(5, 0, 5, 5)
	removeBtn:SetTall(25)
	removeBtn:SetText("Remove Selected (returns to inventory)")
	removeBtn.DoClick = function()
		local lineID = self.stockList:GetSelectedLine()

		if (lineID) then
			local line = self.stockList:GetLine(lineID)

			if (line) then
				netstream.Start("CWUVendorRemoveStock", self.entIndex, line.stockIndex)
				self:Remove()
			end
		end
	end

	-- Add stock panel
	local addPanel = vgui.Create("DPanel", self)
	addPanel:Dock(BOTTOM)
	addPanel:SetTall(55)
	addPanel:DockMargin(5, 0, 5, 0)
	addPanel.Paint = function(pnl, w, h)
		surface.SetDrawColor(30, 30, 30)
		surface.DrawRect(0, 0, w, h)
	end

	local addLabel = vgui.Create("DLabel", addPanel)
	addLabel:Dock(TOP)
	addLabel:DockMargin(5, 2, 5, 0)
	addLabel:SetText("Add from inventory:")
	addLabel:SetTextColor(Color(150, 150, 150))
	addLabel:SizeToContents()

	local addBar = vgui.Create("DPanel", addPanel)
	addBar:Dock(FILL)
	addBar:DockMargin(5, 2, 5, 2)
	addBar.Paint = nil

	self.itemCombo = vgui.Create("DComboBox", addBar)
	self.itemCombo:Dock(FILL)
	self.itemCombo:DockMargin(0, 0, 5, 0)

	-- Populate with inventory items
	local character = LocalPlayer():GetCharacter()

	if (character) then
		for _, item in pairs(character:GetInventory():GetItems()) do
			-- Don't list blueprints, permits, or CID
			if (item.category != "Blueprints" and item.category != "Permits" and item.uniqueID != "cid" and item.uniqueID != "suitcase") then
				self.itemCombo:AddChoice(item.name, item.id)
			end
		end
	end

	self.itemCombo:SetValue("Select Item")

	self.priceEntry = vgui.Create("DTextEntry", addBar)
	self.priceEntry:Dock(RIGHT)
	self.priceEntry:SetWide(60)
	self.priceEntry:DockMargin(0, 0, 5, 0)
	self.priceEntry:SetNumeric(true)
	self.priceEntry:SetPlaceholderText("Price")

	local addBtn = vgui.Create("DButton", addBar)
	addBtn:Dock(RIGHT)
	addBtn:SetWide(60)
	addBtn:SetText("Add")
	addBtn.DoClick = function()
		local _, itemID = self.itemCombo:GetSelected()
		local price = tonumber(self.priceEntry:GetValue())

		if (itemID and price and price > 0) then
			netstream.Start("CWUVendorAddStock", self.entIndex, itemID, price)
			self:Remove()
		end
	end
end

vgui.Register("ixCWUVendorManage", MANAGE, "DFrame")

-- Vendor Purchase Panel (for customers)
local BUY = {}

function BUY:Init()
	self:SetSize(400, 350)
	self:Center()
	self:MakePopup()
end

function BUY:SetData(entIndex, stock, terminalName)
	self.entIndex = entIndex
	self:SetTitle(terminalName)

	self.list = vgui.Create("DListView", self)
	self.list:Dock(FILL)
	self.list:DockMargin(5, 5, 5, 5)
	self.list:AddColumn("Item")
	self.list:AddColumn("Price"):SetFixedWidth(80)
	self.list:SetMultiSelect(false)

	for i, entry in ipairs(stock) do
		local line = self.list:AddLine(entry.name, ix.currency.Get(entry.price))
		line.stockIndex = i
	end

	local buyBtn = vgui.Create("DButton", self)
	buyBtn:Dock(BOTTOM)
	buyBtn:DockMargin(5, 0, 5, 5)
	buyBtn:SetTall(30)
	buyBtn:SetText("Purchase Selected")
	buyBtn.DoClick = function()
		local lineID = self.list:GetSelectedLine()

		if (lineID) then
			local line = self.list:GetLine(lineID)

			if (line) then
				netstream.Start("CWUVendorPurchase", self.entIndex, line.stockIndex)
				self:Remove()
			end
		end
	end
end

vgui.Register("ixCWUVendorBuy", BUY, "DFrame")

-- Vendor Audit Panel (for Combine/Director)
local AUDIT = {}

function AUDIT:Init()
	self:SetSize(500, 350)
	self:Center()
	self:MakePopup()
end

function AUDIT:SetData(transactions, terminalName)
	self:SetTitle("Audit: " .. terminalName)

	self.list = vgui.Create("DListView", self)
	self.list:Dock(FILL)
	self.list:DockMargin(5, 5, 5, 5)
	self.list:AddColumn("Time"):SetFixedWidth(80)
	self.list:AddColumn("Buyer")
	self.list:AddColumn("Item")
	self.list:AddColumn("Price"):SetFixedWidth(60)
	self.list:AddColumn("Tax"):SetFixedWidth(50)
	self.list:SetMultiSelect(false)

	for i = #transactions, 1, -1 do
		local v = transactions[i]

		self.list:AddLine(
			os.date("%m/%d %H:%M", v.time),
			v.buyer or "Unknown",
			v.itemName or v.item or "Unknown",
			ix.currency.Get(v.price or 0),
			ix.currency.Get(v.tax or 0)
		)
	end
end

vgui.Register("ixCWUVendorAudit", AUDIT, "DFrame")

-- Netstream handlers
netstream.Hook("CWUVendorManage", function(entIndex, stock, earnings)
	if (IsValid(ix.gui.cwuVendor)) then
		ix.gui.cwuVendor:Remove()
	end

	ix.gui.cwuVendor = vgui.Create("ixCWUVendorManage")
	ix.gui.cwuVendor:SetData(entIndex, stock, earnings)
end)

netstream.Hook("CWUVendorBuy", function(entIndex, stock, terminalName)
	if (IsValid(ix.gui.cwuVendor)) then
		ix.gui.cwuVendor:Remove()
	end

	ix.gui.cwuVendor = vgui.Create("ixCWUVendorBuy")
	ix.gui.cwuVendor:SetData(entIndex, stock, terminalName)
end)

netstream.Hook("CWUVendorAudit", function(transactions, terminalName)
	if (IsValid(ix.gui.cwuVendor)) then
		ix.gui.cwuVendor:Remove()
	end

	ix.gui.cwuVendor = vgui.Create("ixCWUVendorAudit")
	ix.gui.cwuVendor:SetData(transactions, terminalName)
end)
