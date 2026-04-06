ITEM.name = "Medical Stimpak"
ITEM.model = Model("models/props_lab/jar01a.mdl")
ITEM.description = "A potent medical compound. Can be used for direct treatment or at a medical workstation for surgery."
ITEM.base = "base_crafted"
ITEM.category = "CWU Goods"

ITEM.functions.Inject = {
	OnRun = function(itemTable)
		local client = itemTable.player

		client:SetHealth(math.min(client:Health() + 50, client:GetMaxHealth()))
		client:EmitSound("items/medcharge4.wav")
		client:Notify("The stimpak floods your system with healing compounds.")

		return false
	end
}
