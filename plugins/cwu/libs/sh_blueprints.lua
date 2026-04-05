-- Blueprint recipe registry
-- Each blueprint defines: materials needed, output item, craft time, and tier requirement
PLUGIN.Blueprints = {}

function PLUGIN:RegisterBlueprint(id, data)
	self.Blueprints[id] = data
end

function PLUGIN:GetBlueprint(id)
	return self.Blueprints[id]
end

-- Register all blueprints
-- Tier 0 = Basic (all Production workers)
-- Tier 1 = Advanced (Tier 3+ loyalty)
-- Tier 2 = Restricted (Director approval required)

PLUGIN:RegisterBlueprint("bp_bandage", {
	name = "Bandage",
	tier = 0,
	materials = {{"cloth_scraps", 2}},
	output = "cwu_bandage",
	outputQuantity = 1,
	craftTime = 8
})

PLUGIN:RegisterBlueprint("bp_ration_supplement", {
	name = "Ration Supplement",
	tier = 0,
	materials = {{"medical_herbs", 1}, {"chemical_base", 1}},
	output = "cwu_supplement",
	outputQuantity = 1,
	craftTime = 10
})

PLUGIN:RegisterBlueprint("bp_repair_kit", {
	name = "Repair Kit",
	tier = 0,
	materials = {{"scrap_metal", 2}, {"electronic_parts", 1}},
	output = "repair_kit",
	outputQuantity = 1,
	craftTime = 12
})

PLUGIN:RegisterBlueprint("bp_basic_tool", {
	name = "Basic Tools",
	tier = 0,
	materials = {{"scrap_metal", 1}},
	output = "basic_tool",
	outputQuantity = 1,
	craftTime = 6
})

PLUGIN:RegisterBlueprint("bp_medical_stimpak", {
	name = "Medical Stimpak",
	tier = 1,
	materials = {{"chemical_base", 2}, {"medical_herbs", 1}},
	output = "medical_stimpak",
	outputQuantity = 1,
	craftTime = 15
})

PLUGIN:RegisterBlueprint("bp_combat_stim", {
	name = "Combat Stimulant",
	tier = 2,
	materials = {{"chemical_base", 2}},
	output = "combat_stim",
	outputQuantity = 1,
	craftTime = 20
})

PLUGIN:RegisterBlueprint("bp_combine_maint", {
	name = "Maintenance Component",
	tier = 2,
	materials = {{"scrap_metal", 2}, {"electronic_parts", 2}},
	output = "combine_maint_part",
	outputQuantity = 1,
	craftTime = 25
})

function PLUGIN:CanUseBlueprint(character, blueprintID)
	local blueprint = self:GetBlueprint(blueprintID)

	if (!blueprint) then
		return false
	end

	local tier = blueprint.tier

	-- Basic: all Production workers
	if (tier == 0) then
		return true
	end

	-- Advanced: Tier 3+ loyalty
	if (tier == 1) then
		return self:CanUseBlueprintTier(character, 1)
	end

	-- Restricted: needs Director approval per blueprint
	if (tier == 2) then
		return character:GetData("approved_bp_" .. blueprintID, false)
	end

	return false
end

function PLUGIN:HasBlueprintMaterials(inventory, blueprintID)
	local blueprint = self:GetBlueprint(blueprintID)

	if (!blueprint) then
		return false
	end

	for _, v in ipairs(blueprint.materials) do
		local materialID = v[1]
		local requiredCount = v[2]
		local items = inventory:GetItemsByUniqueID(materialID, true)

		if (#items < requiredCount) then
			return false
		end
	end

	return true
end

function PLUGIN:ConsumeBlueprintMaterials(inventory, blueprintID)
	local blueprint = self:GetBlueprint(blueprintID)

	if (!blueprint) then
		return false
	end

	for _, v in ipairs(blueprint.materials) do
		local materialID = v[1]
		local requiredCount = v[2]
		local items = inventory:GetItemsByUniqueID(materialID, true)

		for i = 1, requiredCount do
			if (items[i]) then
				items[i]:Remove()
			end
		end
	end

	return true
end
