
ITEM.name = "Roll of Gauze"
ITEM.model = Model("models/props_wasteland/prison_toiletchunk01f.mdl")
ITEM.description = "A roll of unbleached cotton gauze. Sufficient for basic wound dressing."
ITEM.category = "Medical"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Apply = {
	sound = "items/medshot4.wav",
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.Clamp(client:Health() + 15, 0, client:GetMaxHealth()))
	end
}
