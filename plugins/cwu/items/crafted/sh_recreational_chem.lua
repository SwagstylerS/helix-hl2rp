ITEM.name = "Recreational Chemical"
ITEM.model = Model("models/props_lab/jar01a.mdl")
ITEM.description = "A chemical compound with recreational properties. Not sanctioned by the Union."
ITEM.base = "base_crafted"
ITEM.category = "Chemicals"
ITEM.isDualUse = true

ITEM.functions.Use = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:EmitSound("items/medshot4.wav")
		client:Notify("A warm haze washes over you.")

		-- Screen effects handled via netstream on client
		netstream.Start(client, "CWURecreationalEffect", 60)

		return false
	end
}
