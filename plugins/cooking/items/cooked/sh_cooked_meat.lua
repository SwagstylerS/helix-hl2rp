
ITEM.name = "Cooked Meat"
ITEM.model = Model("models/props_junk/garbage_melon001a.mdl")
ITEM.description = "Properly cooked meat. Still warm."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1
ITEM.nutrition = 25

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player
		client:RestoreStamina(60)
		client:SetHealth(math.Clamp(client:Health() + 20, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 100, 0.4)
		hook.Run("PlayerAteFood", client, itemTable.nutrition or 25)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
