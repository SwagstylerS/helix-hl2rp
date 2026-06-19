
ITEM.name = "Nutrient Paste"
ITEM.model = Model("models/props_lab/jar01a.mdl")
ITEM.description = "A jar of grey-beige paste. Union-issue base nutrition. Palatable only by necessity."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:RestoreStamina(25)
		client:SetHealth(math.Clamp(client:Health() + 10, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 140, 0.2)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
