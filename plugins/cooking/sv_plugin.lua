-- Server logic: cooking station netstream handlers and helpers.

-- Returns {uniqueID = count} for a character's inventory.
function PLUGIN:GetInventoryCounts(inventory)
	local counts = {}
	for _, item in pairs(inventory:GetItems()) do
		local uid = item.uniqueID
		counts[uid] = (counts[uid] or 0) + 1
	end
	return counts
end

-- Checks whether the inventory holds all required ingredients for a recipe.
function PLUGIN:HasIngredients(inventory, recipe)
	for itemID, count in pairs(recipe.ingredients) do
		if (#inventory:GetItemsByUniqueID(itemID, true) < count) then
			return false
		end
	end
	return true
end

-- Removes ingredient items for a recipe from an inventory.
function PLUGIN:ConsumeIngredients(inventory, recipe)
	for itemID, count in pairs(recipe.ingredients) do
		local items = inventory:GetItemsByUniqueID(itemID, true)
		for i = 1, count do
			if (items[i]) then items[i]:Remove() end
		end
	end
end

-- Spawns the cook result and resets entity state.
function PLUGIN:CollectCookResult(entity, client)
	local outputID = entity.pendingOutputID
	if (!outputID) then return end

	ix.item.Spawn(outputID, entity:GetPos() + entity:GetUp() * 20, function(item, itemEnt)
		entity:EmitSound("buttons/combine_button1.wav")
	end)

	entity.pendingOutputID  = nil
	entity.pendingQuality   = nil
	entity.pendingRecipeID  = nil
	entity:SetState(0)
	entity:SetCookName("")
end

-- Called by ENT:Use on both cooking entities.
function PLUGIN:HandleStationUse(entity, client)
	if (!ix.config.Get("cookingEnabled", false)) then return end
	if (client:GetPos():DistToSqr(entity:GetPos()) > 40000) then return end
	if (client:IsCombine()) then return end

	-- Collect finished cook.
	if (entity:GetState() == 2) then
		PLUGIN:CollectCookResult(entity, client)
		return
	end

	if (entity:GetState() == 1) then
		client:NotifyLocalized("cookingBusy")
		return
	end

	local char = client:GetCharacter()
	if (!char) then return end

	local inventory = char:GetInventory()
	local counts    = PLUGIN:GetInventoryCounts(inventory)
	local available = PLUGIN:GetRecipesFor(entity.CookType, counts)

	if (next(available) == nil) then
		client:NotifyLocalized("cookingNoRecipes")
		return
	end

	local recipeList = {}
	for id, r in pairs(available) do
		recipeList[#recipeList + 1] = {id = id, name = r.name, time = r.time, interactions = r.interactions}
	end

	netstream.Start(client, "CookingOpen", entity:EntIndex(), entity.CookType, recipeList)
end

-- Client chose a recipe and started cooking.
netstream.Hook("CookingStart", function(client, entIndex, recipeID)
	local entity = Entity(entIndex)

	if (!IsValid(entity)) then return end
	if (client:GetPos():DistToSqr(entity:GetPos()) > 40000) then return end
	if (entity:GetState() != 0) then return end
	if (client:IsCombine()) then return end

	local recipe = PLUGIN.Recipes[recipeID]
	if (!recipe) then return end
	if (recipe.cookType != entity.CookType) then return end

	local char = client:GetCharacter()
	if (!char) then return end

	local inventory = char:GetInventory()

	if (!PLUGIN:HasIngredients(inventory, recipe)) then
		client:NotifyLocalized("cookingMissingIngredients")
		return
	end

	PLUGIN:ConsumeIngredients(inventory, recipe)

	local cookTime = recipe.time or 30

	entity:SetState(1)
	entity:SetCookEnd(CurTime() + cookTime)
	entity:SetCookDuration(cookTime)
	entity:SetCookName(recipe.name)
	entity:EmitSound("ambient/machines/combine_terminal_idle2.wav")

	entity.pendingRecipeID = recipeID
	entity.pendingQuality  = nil

	-- Send minigame open to client.
	netstream.Start(client, "CookingMinigame", entIndex, recipe.interactions, cookTime)

	timer.Create("CookingTimer_" .. entIndex, cookTime, 1, function()
		if (!IsValid(entity)) then return end

		local quality = entity.pendingQuality or 1.0
		local isBurnt = quality < PLUGIN.QualityThreshold
		local output  = isBurnt and recipe.burntOutput or recipe.output

		entity.pendingOutputID = output
		entity:SetState(2)
		entity:EmitSound("buttons/combine_button1.wav")

		-- Notify the cooking player if still nearby.
		if (IsValid(client)) then
			client:NotifyLocalized(isBurnt and "cookingBurnt" or "cookingDone")
		end
	end)
end)

-- Client submits minigame quality score on cook completion.
netstream.Hook("CookingQuality", function(client, entIndex, quality)
	local entity = Entity(entIndex)
	if (!IsValid(entity)) then return end
	if (entity:GetState() != 1) then return end
	-- ponytail: clamp; client is untrusted
	entity.pendingQuality = math.Clamp(tonumber(quality) or 0, 0, 1)
end)
