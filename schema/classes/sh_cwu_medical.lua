CLASS.name = "CWU - Medical"
CLASS.faction = FACTION_CITIZEN
CLASS.description = "A CWU worker assigned to the Medical Division."

function CLASS:CanSwitchTo(client)
	return false
end

CLASS_CWU_MEDICAL = CLASS.index
