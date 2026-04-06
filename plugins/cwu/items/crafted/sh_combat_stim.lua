ITEM.name = "Combat Stimulant"
ITEM.model = Model("models/props_lab/jar01a.mdl")
ITEM.description = "A powerful chemical compound. Grants a temporary boost, but carries a crash."
ITEM.base = "base_crafted"
ITEM.category = "Chemicals"
ITEM.isDualUse = true

ITEM.functions.Inject = {
	OnRun = function(itemTable)
		local client = itemTable.player

		-- Boost: +25 temp HP, speed boost
		client:SetHealth(math.min(client:Health() + 25, client:GetMaxHealth() + 25))
		client:SetRunSpeed(client:GetRunSpeed() + 40)
		client:EmitSound("items/medcharge4.wav")
		client:Notify("A surge of energy floods your body.")

		-- Crash after 30 seconds
		local uniqueID = "cwuCombatStim_" .. client:SteamID64()

		timer.Create(uniqueID, 30, 1, function()
			if (IsValid(client)) then
				client:SetHealth(math.max(1, client:Health() - 10))
				client:SetRunSpeed(client:GetRunSpeed() - 40)
				client:EmitSound("player/pl_pain5.wav")
				client:Notify("The stimulant wears off. You feel weaker.")
			end
		end)

		return false
	end
}
