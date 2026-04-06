ITEM.name = "Blueprint Base"
ITEM.model = Model("models/props_lab/clipboard.mdl")
ITEM.description = "A technical blueprint."
ITEM.category = "Blueprints"
ITEM.width = 1
ITEM.height = 1
ITEM.blueprintID = "none"

function ITEM:GetDescription()
	local blueprint = PLUGIN:GetBlueprint(self.blueprintID)

	if (!blueprint) then
		return self.description
	end

	local text = "Blueprint: " .. blueprint.name .. "\n"
	text = text .. "Tier: " .. (blueprint.tier == 0 and "Basic" or blueprint.tier == 1 and "Advanced" or "Restricted") .. "\n"
	text = text .. "Craft Time: " .. blueprint.craftTime .. "s\n\n"
	text = text .. "Materials:\n"

	for _, v in ipairs(blueprint.materials) do
		local itemTable = ix.item.Get(v[1])
		local name = itemTable and itemTable.name or v[1]
		text = text .. "  - " .. name .. " x" .. v[2] .. "\n"
	end

	return text
end
