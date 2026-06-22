
ITEM.name = "Bread"
ITEM.model = Model("models/props_lab/jar01a.mdl")
ITEM.description = "A rough loaf of baked bread. Heavy and filling."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1
ITEM.nutrition = 20

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player
		client:RestoreStamina(50)
		client:SetHealth(math.Clamp(client:Health() + 15, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 110, 0.3)
		hook.Run("PlayerAteFood", client, itemTable.nutrition or 20)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
