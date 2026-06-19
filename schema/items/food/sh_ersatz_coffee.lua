
ITEM.name = "Ersatz Coffee"
ITEM.model = Model("models/props_junk/popcan01a.mdl")
ITEM.description = "A can of chicory-and-grain brew marketed as coffee. Warm and bitter."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Drink = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:RestoreStamina(50)
		client:EmitSound("npc/barnacle/barnacle_gulp2.wav", 75, 90, 0.35)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
