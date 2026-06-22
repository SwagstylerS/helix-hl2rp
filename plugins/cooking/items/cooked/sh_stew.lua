
ITEM.name = "Stew"
ITEM.model = Model("models/props_lab/jar01b.mdl")
ITEM.description = "A dense, dark stew. Still hot from the pot."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1
ITEM.nutrition = 30

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player
		client:RestoreStamina(75)
		client:SetHealth(math.Clamp(client:Health() + 25, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 95, 0.4)
		hook.Run("PlayerAteFood", client, itemTable.nutrition or 30)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
