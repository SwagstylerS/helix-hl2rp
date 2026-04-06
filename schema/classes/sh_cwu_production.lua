CLASS.name = "CWU - Production"
CLASS.faction = FACTION_CITIZEN
CLASS.description = "A CWU worker assigned to the Production Division."

function CLASS:CanSwitchTo(client)
	return false
end

CLASS_CWU_PRODUCTION = CLASS.index
