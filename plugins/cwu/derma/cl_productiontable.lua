local PANEL = {}

function PANEL:Init()
	self:SetSize(400, 350)
	self:Center()
	self:MakePopup()
	self:SetTitle("CWU Production Table")
end

function PANEL:SetBlueprints(entIndex, blueprints)
	self.entIndex = entIndex

	local label = vgui.Create("DLabel", self)
	label:Dock(TOP)
	label:DockMargin(5, 5, 5, 5)
	label:SetText("Select a blueprint to craft:")
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(Color(100, 175, 100))
	label:SizeToContents()

	self.list = vgui.Create("DListView", self)
	self.list:Dock(FILL)
	self.list:DockMargin(5, 0, 5, 5)
	self.list:AddColumn("Blueprint")
	self.list:AddColumn("Tier")
	self.list:AddColumn("Time")
	self.list:AddColumn("Status")
	self.list:SetMultiSelect(false)

	local tierNames = {[0] = "Basic", [1] = "Advanced", [2] = "Restricted"}

	for _, bp in ipairs(blueprints) do
		local status = "Ready"
		local statusColor = Color(100, 255, 100)

		if (!bp.canUse) then
			status = bp.tier == 2 and "Need Approval" or "Tier Locked"
			statusColor = Color(255, 100, 100)
		elseif (!bp.hasMaterials) then
			status = "Need Materials"
			statusColor = Color(255, 200, 100)
		end

		local line = self.list:AddLine(bp.name, tierNames[bp.tier] or "?", bp.craftTime .. "s", status)
		line.bpID = bp.id
		line.canCraft = bp.canUse and bp.hasMaterials

		line:GetChild(3):SetTextColor(statusColor)
	end

	local craftBtn = vgui.Create("DButton", self)
	craftBtn:Dock(BOTTOM)
	craftBtn:DockMargin(5, 0, 5, 5)
	craftBtn:SetTall(30)
	craftBtn:SetText("Begin Crafting")
	craftBtn.DoClick = function()
		local lineID = self.list:GetSelectedLine()

		if (!lineID) then
			return
		end

		local line = self.list:GetLine(lineID)

		if (line and line.canCraft) then
			netstream.Start("CWUProductionStart", self.entIndex, line.bpID)
			self:Remove()
		else
			Derma_Message("Cannot craft this blueprint. Check requirements.", "Production Error", "OK")
		end
	end
end

vgui.Register("ixCWUProductionTable", PANEL, "DFrame")

netstream.Hook("CWUProductionOpen", function(entIndex, blueprints)
	if (IsValid(ix.gui.cwuProduction)) then
		ix.gui.cwuProduction:Remove()
	end

	ix.gui.cwuProduction = vgui.Create("ixCWUProductionTable")
	ix.gui.cwuProduction:SetBlueprints(entIndex, blueprints)
end)
