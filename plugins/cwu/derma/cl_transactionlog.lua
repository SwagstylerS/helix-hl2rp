-- Shared transaction log panel used by Director PC and Combine Terminal
local PANEL = {}

function PANEL:Init()
	self:SetSize(550, 400)
	self:Center()
	self:MakePopup()
	self:SetTitle("CWU Transaction Log")
end

function PANEL:SetTransactions(transactions)
	self.list = vgui.Create("DListView", self)
	self.list:Dock(FILL)
	self.list:DockMargin(5, 5, 5, 5)
	self.list:AddColumn("Time"):SetFixedWidth(80)
	self.list:AddColumn("Buyer")
	self.list:AddColumn("Seller")
	self.list:AddColumn("Item")
	self.list:AddColumn("Price"):SetFixedWidth(60)
	self.list:AddColumn("Tax"):SetFixedWidth(50)
	self.list:AddColumn("Terminal")
	self.list:SetMultiSelect(false)

	for i = #transactions, 1, -1 do
		local v = transactions[i]

		local line = self.list:AddLine(
			os.date("%m/%d %H:%M", v.time),
			v.buyer or "Unknown",
			v.seller or "Unknown",
			v.itemName or v.item or "Unknown",
			ix.currency.Get(v.price or 0),
			ix.currency.Get(v.tax or 0),
			v.terminal or "Unknown"
		)

		-- Flag suspicious items
		local itemName = (v.itemName or v.item or ""):lower()

		if (string.find(itemName, "stim") or string.find(itemName, "chem") or string.find(itemName, "drug") or string.find(itemName, "combat")) then
			for col = 1, 7 do
				local child = line:GetChild(col - 1)

				if (IsValid(child)) then
					child:SetTextColor(Color(255, 100, 100))
				end
			end
		end
	end
end

vgui.Register("ixCWUTransactionLog", PANEL, "DFrame")
