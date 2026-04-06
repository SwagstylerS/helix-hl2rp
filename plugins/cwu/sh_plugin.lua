PLUGIN.name = "Civil Workers Union"
PLUGIN.description = "Adds the CWU division system with Production, Maintenance, Medical, and Commerce divisions."
PLUGIN.author = "HL2RP"

ix.util.Include("libs/sh_loyalty.lua")
ix.util.Include("libs/sh_blueprints.lua")
ix.util.Include("libs/sv_transactions.lua")
ix.util.Include("libs/sv_infrastructure.lua")
ix.util.Include("libs/sv_workorders.lua")

ix.util.Include("sv_hooks.lua")
ix.util.Include("cl_hooks.lua")

-- Config values
ix.config.Add("cwuDegradationInterval", 300, "Seconds between infrastructure degradation checks.", nil, {
	data = {min = 60, max = 3600},
	category = "cwu"
})

ix.config.Add("cwuTaxRate", 10, "Percentage tax on vendor terminal sales.", nil, {
	data = {min = 0, max = 50},
	category = "cwu"
})

ix.config.Add("cwuMaxTransactions", 500, "Maximum transaction log entries stored.", nil, {
	data = {min = 100, max = 5000},
	category = "cwu"
})

ix.config.Add("cwuDefaultCraftTime", 10, "Default crafting time in seconds.", nil, {
	data = {min = 1, max = 120},
	category = "cwu"
})

-- Player meta helpers
local playerMeta = FindMetaTable("Player")

function playerMeta:IsCWU()
	local character = self:GetCharacter()

	if (!character) then
		return false
	end

	local class = character:GetClass()

	return class == CLASS_CWU
		or class == CLASS_CWU_PRODUCTION
		or class == CLASS_CWU_MAINTENANCE
		or class == CLASS_CWU_MEDICAL
		or class == CLASS_CWU_COMMERCE
		or class == CLASS_CWU_DIRECTOR
end

function playerMeta:IsCWUDirector()
	local character = self:GetCharacter()

	if (!character) then
		return false
	end

	return character:GetClass() == CLASS_CWU_DIRECTOR
end

function playerMeta:GetCWUDivision()
	local character = self:GetCharacter()

	if (!character) then
		return nil
	end

	local class = character:GetClass()

	if (class == CLASS_CWU_PRODUCTION) then
		return "production"
	elseif (class == CLASS_CWU_MAINTENANCE) then
		return "maintenance"
	elseif (class == CLASS_CWU_MEDICAL) then
		return "medical"
	elseif (class == CLASS_CWU_COMMERCE) then
		return "commerce"
	elseif (class == CLASS_CWU_DIRECTOR) then
		return "director"
	elseif (class == CLASS_CWU) then
		return "unassigned"
	end

	return nil
end

-- CWU Radio chat class
do
	local CLASS = {}
	CLASS.color = Color(100, 175, 100)
	CLASS.format = "%s [CWU] radios \"%s\""

	function CLASS:CanSay(speaker, text)
		if (!speaker:IsCWU()) then
			speaker:NotifyLocalized("notAllowed")
			return false
		end
	end

	function CLASS:CanHear(speaker, listener)
		return listener:IsCWU() or listener:IsCombine()
	end

	function CLASS:OnChatAdd(speaker, text)
		chat.AddText(self.color, string.format(self.format, speaker:Name(), text))
	end

	ix.chat.Register("cwu_radio", CLASS)
end

-- CWU Radio eavesdrop (nearby citizens can overhear)
do
	local CLASS = {}
	CLASS.color = Color(150, 200, 150)
	CLASS.format = "%s [CWU] radios \"%s\""

	function CLASS:CanHear(speaker, listener)
		if (ix.chat.classes.cwu_radio:CanHear(speaker, listener)) then
			return false
		end

		local chatRange = ix.config.Get("chatRange", 280)

		return (speaker:GetPos() - listener:GetPos()):LengthSqr() <= (chatRange * chatRange)
	end

	function CLASS:OnChatAdd(speaker, text)
		chat.AddText(self.color, string.format(self.format, speaker:Name(), text))
	end

	ix.chat.Register("cwu_radio_eavesdrop", CLASS)
end

-- CWU Division class lookup table
PLUGIN.DivisionClasses = {
	["production"] = "CLASS_CWU_PRODUCTION",
	["maintenance"] = "CLASS_CWU_MAINTENANCE",
	["medical"] = "CLASS_CWU_MEDICAL",
	["commerce"] = "CLASS_CWU_COMMERCE"
}

function PLUGIN:GetDivisionClassID(division)
	local lookup = {
		["production"] = CLASS_CWU_PRODUCTION,
		["maintenance"] = CLASS_CWU_MAINTENANCE,
		["medical"] = CLASS_CWU_MEDICAL,
		["commerce"] = CLASS_CWU_COMMERCE
	}

	return lookup[division:lower()]
end

-- Commands

-- /CWURadio - send on CWU radio channel
do
	local COMMAND = {}
	COMMAND.arguments = ix.type.text

	function COMMAND:OnRun(client, message)
		if (!client:IsCWU()) then
			return "@notAllowed"
		end

		if (client:IsRestricted()) then
			return "@notNow"
		end

		ix.chat.Send(client, "cwu_radio", message)
		ix.chat.Send(client, "cwu_radio_eavesdrop", message)
	end

	ix.command.Add("CWURadio", COMMAND)
end

-- /CWUDirector - admin bootstrap for promoting a citizen to Director
do
	local COMMAND = {}
	COMMAND.adminOnly = true
	COMMAND.arguments = ix.type.character

	function COMMAND:OnRun(client, target)
		local targetClient = target:GetPlayer()

		if (target:GetFaction() != FACTION_CITIZEN) then
			return "@cwuMustBeCitizen"
		end

		if (target:GetData("loyaltyTier", 0) < 3) then
			return "@cwuDirectorNeedsTier3"
		end

		target:JoinClass(CLASS_CWU_DIRECTOR, true)
		client:Notify("Promoted " .. target:GetName() .. " to CWU Director.")

		if (IsValid(targetClient)) then
			targetClient:Notify("You have been promoted to CWU Director.")
		end
	end

	ix.command.Add("CWUDirector", COMMAND)
end

-- /CWUSetTier - admin tool for setting loyalty tier
do
	local COMMAND = {}
	COMMAND.adminOnly = true
	COMMAND.arguments = {ix.type.character, ix.type.number}

	function COMMAND:OnRun(client, target, tier)
		tier = math.Clamp(math.floor(tier), 0, 5)

		target:SetData("loyaltyTier", tier)

		local tierInfo = PLUGIN.LoyaltyTiers[tier]
		local tierName = tierInfo and tierInfo.name or "Unknown"

		client:Notify("Set " .. target:GetName() .. "'s loyalty tier to " .. tier .. " (" .. tierName .. ").")

		local targetClient = target:GetPlayer()

		if (IsValid(targetClient)) then
			targetClient:Notify("Your loyalty tier has been set to " .. tier .. " (" .. tierName .. ").")
		end
	end

	ix.command.Add("CWUSetTier", COMMAND)
end
