CLASS.name = "Civil Worker's Union"
CLASS.faction = FACTION_CWU
CLASS.description = "An unassigned CWU member awaiting division placement."

function CLASS:CanSwitchTo(client)
	return false
end

CLASS_CWU = CLASS.index