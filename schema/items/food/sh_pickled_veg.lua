
ITEM.name = "Jar of Pickles"
ITEM.model = Model("models/props_lab/jar01b.mdl")
ITEM.description = "A jar of mixed vegetables preserved in acidic brine. Tart and still edible."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1
ITEM.nutrition = 8

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.Clamp(client:Health() + 8, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 115, 0.25)
		hook.Run("PlayerAteFood", client, itemTable.nutrition or 10)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
