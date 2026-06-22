-- ponytail: mirrors sv_injury.lua tick pattern; server-only

local HUNGER_TICK      = 60   -- server timer interval in seconds
local HUNGRY_THRESHOLD = 50   -- first cue: "your stomach tightens"
local STARVE_THRESHOLD = 75   -- HP drain begins
local STARVE_FLOOR     = 20   -- HP floor; hunger stops killing here

-- ponytail: per-steamid table; reset on disconnect so thresholds re-notify on reconnect
local notifiedTier = {}

function PLUGIN:Feed(character, amount)
	local hunger = math.max(0, character:GetData("hunger", 0) - amount)
	character:SetData("hunger", hunger)
	local ply = character:GetPlayer()
	if (!IsValid(ply)) then return end
	notifiedTier[ply:SteamID()] = 0
	netstream.Start(ply, "CookingHungerUpdate", hunger)
end

hook.Add("PlayerAteFood", "CookingFeed", function(client, nutrition)
	local char = client:GetCharacter()
	if (!char) then return end
	PLUGIN:Feed(char, nutrition or 10)
end)

hook.Add("PlayerDisconnected", "CookingHungerCleanup", function(ply)
	notifiedTier[ply:SteamID()] = nil
end)

hook.Add("PlayerLoadedCharacter", "CookingHungerSync", function(client, character)
	timer.Simple(0.5, function()
		if (!IsValid(client)) then return end
		netstream.Start(client, "CookingHungerUpdate", character:GetData("hunger", 0))
	end)
end)

local hungerTick = 0

timer.Create("CookingHungerTick", HUNGER_TICK, 0, function()
	if (!ix.config.Get("cookingEnabled", false)) then return end

	hungerTick = hungerTick + 1

	for _, ply in ipairs(player.GetAll()) do
		if (!IsValid(ply)) then continue end
		local char = ply:GetCharacter()
		if (!char) then continue end

		local ok, err = pcall(function()
			local hunger = math.Clamp(char:GetData("hunger", 0) + ix.config.Get("cookingHungerRate", 2), 0, 100)
			char:SetData("hunger", hunger)

			if (hunger >= STARVE_THRESHOLD) then
				local hp = ply:Health()
				if (hp > STARVE_FLOOR) then
					ply:SetHealth(math.max(STARVE_FLOOR, hp - ix.config.Get("cookingStarveDamage", 3)))
				end
			end

			local sid  = ply:SteamID()
			local tier = notifiedTier[sid] or 0

			if (hunger >= STARVE_THRESHOLD and tier < 2) then
				notifiedTier[sid] = 2
				ply:NotifyLocalized("cookingStarving")
			elseif (hunger >= HUNGRY_THRESHOLD and tier < 1) then
				notifiedTier[sid] = 1
				ply:NotifyLocalized("cookingHungry")
			elseif (hunger < HUNGRY_THRESHOLD) then
				notifiedTier[sid] = 0
			end

			netstream.Start(ply, "CookingHungerUpdate", hunger)
		end)

		if (!ok) then
			MsgN("[CookingHungerTick] error (fail-open): " .. tostring(err))
		end
	end
end)

concommand.Add("cooking_demo", function(ply)
	if (IsValid(ply) and !ply:IsAdmin()) then return end

	local char = IsValid(ply) and ply:GetCharacter() or nil
	if (!char) then MsgN("[cooking_demo] Run as an admin with an active character."); return end

	char:SetData("hunger", 50)
	assert(char:GetData("hunger", 0) == 50, "round-trip failed")

	PLUGIN:Feed(char, 30)
	assert(char:GetData("hunger", 0) == 20, "Feed(30) expected 20, got " .. char:GetData("hunger", 0))

	PLUGIN:Feed(char, 999)
	assert(char:GetData("hunger", 0) == 0, "Feed clamp to 0 failed")

	char:SetData("hunger", 0)
	MsgN("[cooking_demo] OK — all assertions passed.")
end)
