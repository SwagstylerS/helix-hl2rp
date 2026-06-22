
ITEM.name = "Powdered Milk"
ITEM.model = Model("models/props_junk/garbage_milkcarton001a.mdl")
ITEM.description = "A carton of dried milk powder. Dissolves in water, provided water is available."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1
ITEM.nutrition = 8

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:RestoreStamina(25)
		client:SetHealth(math.Clamp(client:Health() + 6, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 125, 0.2)
		hook.Run("PlayerAteFood", client, itemTable.nutrition or 10)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
