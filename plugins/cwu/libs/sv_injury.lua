-- ponytail: server-only; rename to sh_injury.lua when Phase 2 needs client region names

PLUGIN.HitgroupRegions = {
	[HITGROUP_HEAD]     = "head",
	[HITGROUP_CHEST]    = "chest",
	[HITGROUP_STOMACH]  = "abdomen",
	[HITGROUP_LEFTARM]  = "left_arm",
	[HITGROUP_RIGHTARM] = "right_arm",
	[HITGROUP_LEFTLEG]  = "left_leg",
	[HITGROUP_RIGHTLEG] = "right_leg",
}

function PLUGIN:HitgroupToRegion(hitgroup)
	return self.HitgroupRegions[hitgroup] or "chest"
end

local BLEED_TICK    = 5    -- server timer interval in seconds
local RECOVERY_STEP = 12   -- ticks between severity reductions (~60s at 5s tick)
local REBLEED_DELAY = 90   -- seconds after bandage before wound starts leaking again
local BLEED_FLOOR   = 10   -- HP floor; bleed stops here (prevent insta-kill before Phase 3)
-- ponytail: DEFAULT_WALK assumes Helix schema default; adjust if schema overrides walk speed
local DEFAULT_WALK  = 200
local LIMP_WALK     = 100

local function HasLegWound(wounds)
	for _, w in ipairs(wounds) do
		if (w.region == "left_leg" or w.region == "right_leg") then
			return true
		end
	end
	return false
end

function PLUGIN:SetInjuries(character, wounds)
	character:SetData("injuries", wounds)
	local ply = character:GetPlayer()
	if (!IsValid(ply)) then return end
	ply:SetWalkSpeed(HasLegWound(wounds) and LIMP_WALK or DEFAULT_WALK)
	netstream.Start(ply, "CWUInjuryUpdate", wounds)
end

function PLUGIN:WipeInjuries(character)
	character:SetData("injuries", {})
	local ply = character:GetPlayer()
	if (IsValid(ply)) then
		ply:SetWalkSpeed(DEFAULT_WALK)
		netstream.Start(ply, "CWUInjuryUpdate", {})
	end
end

function PLUGIN:ApplyBandage(character)
	local wounds = character:GetData("injuries", {})
	for _, w in ipairs(wounds) do
		if (w.bleeding) then
			w.bleeding  = false
			w.rebleedAt = CurTime() + REBLEED_DELAY
			PLUGIN:SetInjuries(character, wounds)
			return true
		end
	end
	return false
end

local bleedTick = 0

timer.Create("CWUBleedTick", BLEED_TICK, 0, function()
	bleedTick = bleedTick + 1
	local doRecovery = (bleedTick % RECOVERY_STEP) == 0

	for _, ply in ipairs(player.GetAll()) do
		if (!IsValid(ply)) then continue end
		local char = ply:GetCharacter()
		if (!char) then continue end

		local wounds = char:GetData("injuries", {})
		if (#wounds == 0) then continue end

		local changed = false
		local hp      = ply:Health()
		local i       = #wounds

		while (i >= 1) do
			local w = wounds[i]

			-- Re-bleed: bandaged wound starts leaking again after delay
			if (!w.bleeding and w.rebleedAt and CurTime() >= w.rebleedAt) then
				w.bleeding  = true
				w.rebleedAt = nil
				changed = true
			end

			-- Drain 3 HP per bleeding wound per tick; floor at BLEED_FLOOR
			if (w.bleeding and hp > BLEED_FLOOR) then
				hp = math.max(BLEED_FLOOR, hp - 3)
			end

			-- Slow natural recovery: reduce severity once per RECOVERY_STEP ticks
			if (doRecovery) then
				w.severity = w.severity - 1
				changed = true
				if (w.severity <= 0) then
					table.remove(wounds, i)
				end
			end

			i = i - 1
		end

		if (hp != ply:Health()) then
			ply:SetHealth(hp)
		end

		if (changed) then
			PLUGIN:SetInjuries(char, wounds)
		end
	end
end)

-- Admin: inject a test wound directly, no damage hook needed in Phase 2
concommand.Add("cwu_inject_wound", function(ply, cmd, args)
	if (IsValid(ply) and !ply:IsAdmin()) then return end

	local region   = args[1] or "chest"
	local severity = math.Clamp(math.floor(tonumber(args[2]) or 1), 1, 3)
	local target   = IsValid(ply) and ply or nil

	if (!target) then
		for _, p in ipairs(player.GetAll()) do
			if (p:IsAdmin()) then target = p; break end
		end
	end

	if (!target) then MsgN("[cwu_inject_wound] No valid target."); return end

	local validRegions = {
		head = true, chest = true, abdomen = true,
		left_arm = true, right_arm = true, left_leg = true, right_leg = true,
	}

	if (!validRegions[region]) then
		MsgN("[cwu_inject_wound] Invalid region. Valid: head chest abdomen left_arm right_arm left_leg right_leg")
		return
	end

	local char = target:GetCharacter()
	if (!char) then MsgN("[cwu_inject_wound] Target has no character."); return end

	local wounds = char:GetData("injuries", {})
	wounds[#wounds + 1] = {region = region, bleeding = true, severity = severity}
	PLUGIN:SetInjuries(char, wounds)
	MsgN(string.format("[cwu_inject_wound] Injected %s wound (sev %d) on %s.", region, severity, target:Name()))
end)

-- ponytail: hardcoded wound threshold; add config after smoke-test if tuning needed
local WOUND_THRESHOLD = 15

hook.Add("EntityTakeDamage", "CWUMedicalInjury", function(entity, dmginfo)
	if (!entity:IsPlayer()) then return end
	if (!ix.config.Get("medicalInjuries", false)) then return end

	local ok, err = pcall(function()
		if (dmginfo:GetDamage() < WOUND_THRESHOLD) then return end

		local char = entity:GetCharacter()
		if (!char) then return end

		local wounds = char:GetData("injuries", {})
		wounds[#wounds + 1] = {
			region   = PLUGIN:HitgroupToRegion(dmginfo:GetHitGroup()),
			bleeding = true,
			severity = 1,
		}
		PLUGIN:SetInjuries(char, wounds)
	end)

	if (!ok) then
		MsgN("[CWUMedicalInjury] hook error (fail-open): " .. tostring(err))
	end
end)

-- Phase 1 demo self-check (kept)
concommand.Add("cwu_injury_demo", function(ply)
	if (IsValid(ply) and !ply:IsAdmin()) then return end

	local char = IsValid(ply) and ply:GetCharacter() or nil

	if (!char) then
		MsgN("[cwu_injury_demo] Run as an admin with an active character.")
		return
	end

	PLUGIN:WipeInjuries(char)

	local wounds = char:GetData("injuries", {})
	wounds[#wounds + 1] = {region = "head", bleeding = true, severity = 2}
	char:SetData("injuries", wounds)

	wounds = char:GetData("injuries", {})
	assert(#wounds == 1, "round-trip: expected 1 wound, got " .. #wounds)
	assert(wounds[1].region == "head", "round-trip: region mismatch")
	assert(wounds[1].bleeding == true, "round-trip: bleeding flag mismatch")
	assert(wounds[1].severity == 2, "round-trip: severity mismatch")

	PLUGIN:WipeInjuries(char)
	assert(#char:GetData("injuries", {}) == 0, "wipe: expected 0 wounds after wipe")

	MsgN("[cwu_injury_demo] OK — all assertions passed.")
end)
