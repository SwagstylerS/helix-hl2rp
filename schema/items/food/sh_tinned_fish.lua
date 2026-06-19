
ITEM.name = "Tin of Sprats"
ITEM.model = Model("models/props_junk/garbage_metalcan001a.mdl")
ITEM.description = "A tin of preserved sprats packed in brine. Salty and protein-dense."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.Clamp(client:Health() + 8, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 130, 0.25)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
