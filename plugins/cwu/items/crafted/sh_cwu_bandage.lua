ITEM.name = "CWU Bandage"
ITEM.model = Model("models/props_junk/garbage_newspaper001a.mdl")
ITEM.description = "A clean bandage crafted by the CWU Production Division."
ITEM.base = "base_crafted"
ITEM.category = "CWU Goods"
ITEM.isHealingItem = true
ITEM.healAmount = 20

ITEM.functions.Apply = {
	OnRun = function(itemTable)
		local client = itemTable.player
		local character = client:GetCharacter()

		if (!character) then return false end

		if (!PLUGIN:ApplyBandage(character)) then
			client:Notify("No open wound to dress.")
			return false
		end

		client:EmitSound("items/medshot4.wav")
		client:Notify("The dressing holds for now. Seek further treatment.")
		return true  -- true = consume item (Helix convention; false = keep)
	end
}
