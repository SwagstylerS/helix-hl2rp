
ITEM.name = "Jar of Preserves"
ITEM.model = Model("models/props_lab/jar01b.mdl")
ITEM.description = "A sealed jar of dark fruit preserves. Scarce enough to trade."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:RestoreStamina(25)
		client:SetHealth(math.Clamp(client:Health() + 12, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 105, 0.3)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
