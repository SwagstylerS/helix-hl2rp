local PANEL = {}

function PANEL:Init()
	self:SetSize(400, 380)
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

	local actionBtn = vgui.Create("DButton", self)
	actionBtn:Dock(BOTTOM)
	actionBtn:DockMargin(5, 0, 5, 5)
	actionBtn:SetTall(30)
	actionBtn:SetText("Select Blueprint")
	actionBtn:SetEnabled(false)

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
		local isPending = bp.hasPendingRequest or (ix.gui.cwuPendingBPRequests and ix.gui.cwuPendingBPRequests[bp.id])
		local status = "Ready"
		local statusColor = Color(100, 255, 100)

		if (!bp.canUse) then
			if (bp.requestable) then
				status = isPending and "Approval Pending" or "Request Approval"
				statusColor = isPending and Color(255, 200, 100) or Color(100, 150, 255)
			else
				status = "Tier Locked"
				statusColor = Color(255, 100, 100)
			end
		elseif (!bp.hasMaterials) then
			status = "Need Materials"
			statusColor = Color(255, 200, 100)
		end

		local line = self.list:AddLine(bp.name, tierNames[bp.tier] or "?", bp.craftTime .. "s", status)
		line.bpID = bp.id
		line.canCraft = bp.canUse and bp.hasMaterials
		line.requestable = bp.requestable or false
		line.hasPendingRequest = isPending or false

		line:GetChild(3):SetTextColor(statusColor)
	end

	self.list.OnRowSelected = function(_, _, line)
		if (line.canCraft) then
			actionBtn:SetText("Begin Crafting")
			actionBtn:SetEnabled(true)
		elseif (line.requestable) then
			if (line.hasPendingRequest) then
				actionBtn:SetText("Approval Pending")
				actionBtn:SetEnabled(false)
			else
				actionBtn:SetText("Request Approval")
				actionBtn:SetEnabled(true)
			end
		else
			actionBtn:SetText("Cannot Craft")
			actionBtn:SetEnabled(false)
		end
	end

	actionBtn.DoClick = function()
		local lineID = self.list:GetSelectedLine()

		if (!lineID) then
			return
		end

		local line = self.list:GetLine(lineID)

		if (!line) then
			return
		end

		if (line.canCraft) then
			netstream.Start("CWUProductionStart", self.entIndex, line.bpID)
			self:Remove()
		elseif (line.requestable and !line.hasPendingRequest) then
			netstream.Start("CWURequestBlueprintApproval", line.bpID)

			if (!ix.gui.cwuPendingBPRequests) then
				ix.gui.cwuPendingBPRequests = {}
			end
			ix.gui.cwuPendingBPRequests[line.bpID] = true

			line.hasPendingRequest = true
			line:SetColumnText(4, "Approval Pending")
			line:GetChild(3):SetTextColor(Color(255, 200, 100))

			actionBtn:SetText("Approval Pending")
			actionBtn:SetEnabled(false)
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
