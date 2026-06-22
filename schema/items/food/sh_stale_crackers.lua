
ITEM.name = "Packet of Crackers"
ITEM.model = Model("models/props_junk/cardboard_box001a.mdl")
ITEM.description = "A battered packet of pressed-grain crackers. Stale, but caloric."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1
ITEM.nutrition = 5

ITEM.functions.Eat = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.Clamp(client:Health() + 5, 0, client:GetMaxHealth()))
		client:EmitSound("npc/antlion_grub/squashed.wav", 75, 150, 0.15)
		hook.Run("PlayerAteFood", client, itemTable.nutrition or 10)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
