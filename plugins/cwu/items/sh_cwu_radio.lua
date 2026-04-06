ITEM.name = "CWU Radio"
ITEM.model = Model("models/props_lab/reciever01b.mdl")
ITEM.description = "A CWU-issued radio preset to the union frequency."
ITEM.category = "CWU Goods"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Toggle = {
	OnRun = function(itemTable)
		local enabled = !itemTable:GetData("enabled", false)
		itemTable:SetData("enabled", enabled)

		itemTable.player:Notify(enabled and "CWU radio enabled." or "CWU radio disabled.")

		return false
	end
}

function ITEM:GetDescription()
	local enabled = self:GetData("enabled", false)
	return self.description .. "\n\nStatus: " .. (enabled and "ON" or "OFF")
end
