
ITEM.name = "Bottle of Spirits"
ITEM.model = Model("models/props_junk/garbage_plasticbottle003a.mdl")
ITEM.description = "A plastic bottle of rough-distilled spirits. Provenance unknown. Acquired outside sanctioned channels."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1
ITEM.nutrition = 8

ITEM.functions.Drink = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:RestoreStamina(75)
		client:SetHealth(math.Clamp(client:Health() + 10, 0, client:GetMaxHealth()))
		client:EmitSound("npc/barnacle/barnacle_gulp2.wav", 75, 75, 0.5)
		hook.Run("PlayerAteFood", client, itemTable.nutrition or 10)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
