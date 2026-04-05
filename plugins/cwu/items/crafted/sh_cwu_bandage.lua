ITEM.name = "CWU Bandage"
ITEM.model = Model("models/props_junk/garbage_newspaper001a.mdl")
ITEM.description = "A clean bandage crafted by the CWU Production Division."
ITEM.base = "base_crafted_good"
ITEM.category = "CWU Goods"

ITEM.functions.Apply = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.min(client:Health() + 25, client:GetMaxHealth()))
		client:EmitSound("items/medshot4.wav")
		client:Notify("You applied a bandage and recovered some health.")

		return false
	end
}
