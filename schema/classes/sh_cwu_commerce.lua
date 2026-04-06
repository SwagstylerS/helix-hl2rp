CLASS.name = "CWU - Commerce"
CLASS.faction = FACTION_CITIZEN
CLASS.description = "A CWU worker assigned to the Commerce Division."

function CLASS:CanSwitchTo(client)
	return false
end

CLASS_CWU_COMMERCE = CLASS.index
