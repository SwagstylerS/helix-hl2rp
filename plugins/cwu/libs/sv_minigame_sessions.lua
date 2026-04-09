-- Server-side minigame session manager
-- Tracks active medical minigame sessions with token-based anti-cheat

PLUGIN.MinigameSessions = PLUGIN.MinigameSessions or {}

-- Duration configs per procedure type
local PROCEDURE_TIMING = {
	bandaging = {min = 2, max = 30},
	surgery = {min = 5, max = 60},
	injection_medicine = {min = 3, max = 45},
	injection_combat = {min = 3, max = 45},
	injection_recreational = {min = 3, max = 45},
}

function PLUGIN:CreateMinigameSession(client, entity, sessionType, extraData)
	-- Cancel any existing session for this player
	self:CancelMinigameSession(client)

	local token = string.format("%08x%08x", math.random(0, 0x7FFFFFFF), math.random(0, 0x7FFFFFFF))
	local timing = PROCEDURE_TIMING[sessionType] or {min = 2, max = 45}

	local session = {
		token = token,
		client = client,
		entity = entity,
		type = sessionType,
		targetSteamID = extraData and extraData.targetSteamID or nil,
		drugType = extraData and extraData.drugType or nil,
		startTime = CurTime(),
		minDuration = timing.min,
		maxDuration = timing.max,
	}

	self.MinigameSessions[token] = session

	-- Set workstation state
	entity:SetInUse(true)

	if (string.StartWith(sessionType, "injection")) then
		entity:SetState(2) -- synthesizing
	else
		entity:SetState(1) -- treating
	end

	-- Auto-timeout timer
	timer.Create("CWUMinigameTimeout_" .. token, timing.max + 5, 1, function()
		if (self.MinigameSessions[token]) then
			self:CleanupMinigameSession(token, true)
		end
	end)

	return token, timing.max
end

function PLUGIN:ValidateMinigameCompletion(client, token, score)
	local session = self.MinigameSessions[token]

	if (!session) then
		return nil
	end

	if (session.client != client) then
		return nil
	end

	if (type(score) != "number" or score < 0 or score > 1) then
		return nil
	end

	local elapsed = CurTime() - session.startTime

	if (elapsed < session.minDuration) then
		return nil
	end

	-- Valid completion - remove session and cleanup timer
	self.MinigameSessions[token] = nil
	timer.Remove("CWUMinigameTimeout_" .. token)

	-- Reset workstation
	if (IsValid(session.entity)) then
		session.entity:SetInUse(false)
		session.entity:SetState(0)
	end

	return session
end

function PLUGIN:CleanupMinigameSession(token, bTimeout)
	local session = self.MinigameSessions[token]

	if (!session) then
		return
	end

	self.MinigameSessions[token] = nil
	timer.Remove("CWUMinigameTimeout_" .. token)

	if (IsValid(session.entity)) then
		session.entity:SetInUse(false)
		session.entity:SetState(0)
	end

	if (bTimeout and IsValid(session.client)) then
		session.client:NotifyLocalized("cwuMinigameTimeout")
	end
end

function PLUGIN:CancelMinigameSession(client)
	for token, session in pairs(self.MinigameSessions) do
		if (session.client == client) then
			self:CleanupMinigameSession(token)
		end
	end
end

-- Clean up on player disconnect
function PLUGIN:PlayerDisconnected(client)
	self:CancelMinigameSession(client)
end
