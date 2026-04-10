CLASS.name = "CWU - Director"
CLASS.faction = FACTION_CWU
CLASS.description = "The Director of the Civil Workers Union."

function CLASS:CanSwitchTo(client)
	local character = client:GetCharacter()

	if (character) then
		return (character:GetData("loyaltyTier", 0) >= 3)
	end

	return false
end

CLASS_CWU_DIRECTOR = CLASS.index
