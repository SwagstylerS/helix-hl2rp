CLASS.name = "CWU - Maintenance"
CLASS.faction = FACTION_CITIZEN
CLASS.description = "A CWU worker assigned to the Maintenance Division."

function CLASS:CanSwitchTo(client)
	return false
end

CLASS_CWU_MAINTENANCE = CLASS.index
