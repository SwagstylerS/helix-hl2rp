ITEM.name = "Ration Supplement"
ITEM.model = Model("models/props_junk/garbage_metalcan001a.mdl")
ITEM.description = "A nutrient supplement crafted by the CWU. Restores health and stamina."
ITEM.base = "base_crafted"
ITEM.category = "CWU Goods"

ITEM.functions.Consume = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.min(client:Health() + 30, client:GetMaxHealth()))
		client:EmitSound("items/battery_pickup.wav")
		client:Notify("You consumed the supplement and feel revitalized.")

		return false
	end
}
