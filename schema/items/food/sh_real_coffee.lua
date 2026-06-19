
ITEM.name = "Tin of Real Coffee"
ITEM.model = Model("models/props_junk/garbage_metalcan001a.mdl")
ITEM.description = "A small tin of genuine roasted coffee. Its scarcity makes it almost a form of currency."
ITEM.category = "Consumables"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Drink = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:RestoreStamina(100)
		client:EmitSound("npc/barnacle/barnacle_gulp2.wav", 75, 85, 0.4)
	end,
	OnCanRun = function(itemTable)
		return !itemTable.player:IsCombine()
	end
}
