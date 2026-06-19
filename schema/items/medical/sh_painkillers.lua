
ITEM.name = "Analgesic Tablets"
ITEM.model = Model("models/props_lab/jar01a.mdl")
ITEM.description = "A small glass jar of pain relief tablets. Cuts the edge off injury without treating the cause."
ITEM.category = "Medical"
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Take = {
	sound = "items/medshot4.wav",
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.Clamp(client:Health() + 10, 0, client:GetMaxHealth()))
	end
}
