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

function PLUGIN:WipeInjuries(character)
	character:SetData("injuries", {})
end

-- Demo self-check: run as admin with an active character.
-- Seed a wound, assert it round-trips through SetData/GetData, then assert wipe clears it.
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
