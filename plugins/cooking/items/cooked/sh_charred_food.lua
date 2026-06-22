
ITEM.name = "Charred Food"
ITEM.model = Model("models/props_junk/garbage_melon001a.mdl")
ITEM.description = "Burnt and barely edible. It will keep you alive."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1
ITEM.nutrition = 8

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player
		client:RestoreStamina(15)
		client:SetHealth(math.Clamp(client:Health() + 5, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 80, 0.3)
		hook.Run("PlayerAteFood", client, itemTable.nutrition or 8)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
