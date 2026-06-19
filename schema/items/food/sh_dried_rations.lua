
ITEM.name = "Dried Rations"
ITEM.model = Model("models/weapons/w_package.mdl")
ITEM.description = "A vacuum-sealed block of compressed grain and dried protein. Standard Union field provision."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:RestoreStamina(50)
		client:SetHealth(math.Clamp(client:Health() + 12, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 110, 0.3)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
