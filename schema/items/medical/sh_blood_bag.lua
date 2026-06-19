
ITEM.name = "Blood Bag"
ITEM.model = Model("models/weapons/w_package.mdl")
ITEM.description = "A sealed transfusion bag salvaged from a medical supply cache. Type-O. Rare."
ITEM.category = "Medical"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Apply = {
	sound = "items/medshot4.wav",
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.Clamp(client:Health() + 40, 0, client:GetMaxHealth()))
	end
}
