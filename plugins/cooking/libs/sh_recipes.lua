-- Shared recipe registry. Loaded on both realms via sh_plugin.lua.

PLUGIN.Recipes = {
	cooked_meat = {
		name        = "Cooked Meat",
		cookType    = "grill",
		ingredients = {raw_meat = 1},
		output      = "cooked_meat",
		burntOutput = "charred_food",
		time        = 25,
		interactions = {"flip", "poke", "turn"},
	},
	stew = {
		name        = "Stew",
		cookType    = "pot",
		ingredients = {raw_meat = 1, vegetables = 1},
		output      = "stew",
		burntOutput = "charred_food",
		time        = 35,
		interactions = {"stir", "season", "skim"},
	},
	bread = {
		name        = "Bread",
		cookType    = "pot",
		ingredients = {flour = 2, eggs = 1, oil = 1},
		output      = "bread",
		burntOutput = "charred_food",
		time        = 40,
		interactions = {"stir", "season", "flip", "poke"},
	},
}

-- Quality threshold below which the burnt output is spawned instead.
PLUGIN.QualityThreshold = 0.5

-- Returns recipes whose cookType matches and whose ingredients the inventory holds.
-- inventory: table of {uniqueID = count}
function PLUGIN:GetRecipesFor(cookType, inventory)
	local out = {}
	for id, recipe in pairs(self.Recipes) do
		if (recipe.cookType != cookType) then continue end
		local canCook = true
		for itemID, count in pairs(recipe.ingredients) do
			if ((inventory[itemID] or 0) < count) then
				canCook = false
				break
			end
		end
		if (canCook) then
			out[id] = recipe
		end
	end
	return out
end
