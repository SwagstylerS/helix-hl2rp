
ITEM.name = "Field Splint"
ITEM.model = Model("models/props_c17/tools_wrench01a.mdl")
ITEM.description = "A length of rigid rod and binding cord improvised into a field splint. Crude but functional."
ITEM.category = "Medical"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Apply = {
	sound = "items/medshot4.wav",
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.Clamp(client:Health() + 20, 0, client:GetMaxHealth()))
	end
}
