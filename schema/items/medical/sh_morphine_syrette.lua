
ITEM.name = "Morphine Syrette"
ITEM.model = Model("models/healthvial.mdl")
ITEM.description = "A pre-loaded syrette of morphine solution. Rarely obtained outside black-market medical channels."
ITEM.category = "Medical"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Apply = {
	sound = "items/medshot4.wav",
	OnRun = function(itemTable)
		local client = itemTable.player

		client:RestoreStamina(75)
		client:SetHealth(math.Clamp(client:Health() + 45, 0, client:GetMaxHealth()))
	end
}
