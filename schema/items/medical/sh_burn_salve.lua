
ITEM.name = "Burn Salve"
ITEM.model = Model("models/props_lab/jar01b.mdl")
ITEM.description = "A jar of pale yellow salve formulated for thermal injuries. Union Medical surplus stock."
ITEM.category = "Medical"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Apply = {
	sound = "items/medshot4.wav",
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.Clamp(client:Health() + 18, 0, client:GetMaxHealth()))
	end
}
