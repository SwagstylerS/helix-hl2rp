
ITEM.name = "Tin of Beans"
ITEM.model = Model("models/props_junk/garbage_metalcan001a.mdl")
ITEM.description = "A dented tin of reconstituted legumes. The label has long since peeled away."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.Clamp(client:Health() + 8, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 120, 0.3)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
