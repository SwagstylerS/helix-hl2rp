
FACTION.name = "Civil Workers Union"
FACTION.description = "A civil worker employed under the Universal Union's CWU programme."
FACTION.color = Color(100, 175, 100)
FACTION.isDefault = false

function FACTION:OnCharacterCreated(client, character)
	local id = Schema:ZeroNumber(math.random(1, 99999), 5)
	local inventory = character:GetInventory()

	character:SetData("cid", id)

	inventory:Add("suitcase", 1)
	inventory:Add("cid", 1, {
		name = character:GetName(),
		id = id
	})
end

FACTION_CWU = FACTION.index
