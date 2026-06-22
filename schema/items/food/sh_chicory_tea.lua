
ITEM.name = "Cup of Chicory"
ITEM.model = Model("models/props_junk/garbage_metalcan001a.mdl")
ITEM.description = "A dented tin of dried chicory steeped into something vaguely tea-like."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1
ITEM.nutrition = 5

ITEM.functions.Drink = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:RestoreStamina(25)
		client:EmitSound("npc/barnacle/barnacle_gulp2.wav", 75, 100, 0.3)
		hook.Run("PlayerAteFood", client, itemTable.nutrition or 10)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
