
ITEM.name = "Antiseptic Solution"
ITEM.model = Model("models/props_junk/garbage_plasticbottle003a.mdl")
ITEM.description = "A plastic bottle of diluted antiseptic solution. Standard field hygiene for open wounds."
ITEM.category = "Medical"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Apply = {
	sound = "items/medshot4.wav",
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.Clamp(client:Health() + 8, 0, client:GetMaxHealth()))
	end
}
