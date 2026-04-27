PLUGIN.LoyaltyTiers = {
	[0] = {name = "Unregistered", color = Color(150, 150, 150)},
	[1] = {name = "Registered", color = Color(200, 200, 200)},
	[2] = {name = "Trusted", color = Color(100, 200, 100)},
	[3] = {name = "Valued", color = Color(100, 100, 255)},
	[4] = {name = "Exemplary", color = Color(200, 100, 255)},
	[5] = {name = "Model Citizen", color = Color(255, 215, 0)}
}

function PLUGIN:GetLoyaltyTier(character)
	return character:GetData("loyaltyTier", 0)
end

function PLUGIN:GetLoyaltyTierInfo(tier)
	return self.LoyaltyTiers[tier] or self.LoyaltyTiers[0]
end

function PLUGIN:CanUseBlueprintTier(character, blueprintTier)
	local loyalty = self:GetLoyaltyTier(character)

	-- Basic blueprints: available to all CWU Production workers
	if (blueprintTier == 0) then
		return true
	end

	-- Advanced blueprints: requires Tier 3+ loyalty
	if (blueprintTier == 1) then
		return loyalty >= 3
	end

	-- Restricted blueprints: requires Director approval flag
	if (blueprintTier == 2) then
		return false -- must be checked per-blueprint via character data
	end

	return false
end

if (SERVER) then
	function PLUGIN:AwardLoyalty(character, amount, reason)
		local points = character:GetData("loyaltyPoints", 0) + amount
		character:SetData("loyaltyPoints", points)

		local oldTier = character:GetData("loyaltyTier", 0)
		local newTier = math.min(math.floor(points / 10), 5)

		local client = character:GetPlayer()

		if (newTier > oldTier) then
			character:SetData("loyaltyTier", newTier)

			if (IsValid(client)) then
				local tierInfo = self:GetLoyaltyTierInfo(newTier)
				client:NotifyLocalized("cwuTierUp", tierInfo.name, newTier)
			end
		end

		if (IsValid(client)) then
			client:NotifyLocalized("cwuLoyaltyGained", amount)
		end
	end
end
