-- Surgery minigame - 3 phases: incision tracing, extraction through channel, suturing
-- Used for advanced surgery at the medical workstation. Requires medical training + stimpak.

local PANEL = {}

local COL_SKIN = Color(200, 160, 130)
local COL_SKIN_DARK = Color(170, 130, 100)
local COL_WOUND = Color(140, 40, 35)
local COL_WOUND_INNER = Color(100, 25, 20)
local COL_INCISION_GUIDE = Color(200, 200, 255, 60)
local COL_INCISION_CUT = Color(160, 30, 25)
local COL_CHANNEL_WALL = Color(140, 50, 45)
local COL_CHANNEL_BG = Color(60, 20, 18)
local COL_OBJECT = Color(80, 80, 90)
local COL_TWEEZERS = Color(180, 190, 200)
local COL_STITCH_POINT = Color(100, 200, 255)
local COL_STITCH_DONE = Color(60, 180, 100)
local COL_STITCH_LINE = Color(40, 40, 50)
local COL_WALL_HIT = Color(255, 60, 60, 150)
local COL_PHASE_TEXT = Color(200, 220, 255)

-- Phase constants
local PHASE_INCISION = 1
local PHASE_EXTRACTION = 2
local PHASE_SUTURING = 3

function PANEL:OnMinigameSetup()
	self.headerText = "SURGICAL PROCEDURE"
	self.phase = PHASE_INCISION
	self.phaseScores = {0, 0, 0}
	self.phaseTransition = false
	self.transitionEnd = 0

	self:SetupIncision()
end

-- ============================================================
-- PHASE 1: INCISION
-- ============================================================
function PANEL:SetupIncision()
	self.hintText = "Click and drag to trace the incision line."

	local cx, cy, cw, ch = self:GetContentArea()
	local centerX = cx + cw / 2
	local centerY = cy + ch / 2

	-- Incision is a vertical line with slight curve
	self.incisionStart = {x = centerX, y = centerY - 80}
	self.incisionEnd = {x = centerX + 10, y = centerY + 80}

	-- Guide points for the ideal path
	self.incisionGuide = {}
	local steps = 20

	for i = 0, steps do
		local t = i / steps
		local x = self.incisionStart.x + (self.incisionEnd.x - self.incisionStart.x) * t
		local y = self.incisionStart.y + (self.incisionEnd.y - self.incisionStart.y) * t
		x = x + math.sin(t * math.pi * 1.5) * 12 -- subtle S-curve

		self.incisionGuide[i + 1] = {x = x, y = y}
	end

	self.incisionPoints = {}
	self.dragging = false
	self.incisionComplete = false
end

function PANEL:HandleIncisionInput(mouseCode, pressed)
	if (pressed and mouseCode == MOUSE_LEFT and !self.dragging and !self.incisionComplete) then
		local mx, my = self:CursorPos()
		local dist = math.sqrt((mx - self.incisionStart.x) ^ 2 + (my - self.incisionStart.y) ^ 2)

		if (dist < 40) then
			self.dragging = true
			self.incisionPoints = {{x = mx, y = my}}
		end
	end
end

function PANEL:HandleIncisionRelease()
	if (self.dragging) then
		self.dragging = false

		-- Check if enough of the line was drawn
		if (#self.incisionPoints > 5) then
			local lastPoint = self.incisionPoints[#self.incisionPoints]
			local distToEnd = math.sqrt((lastPoint.x - self.incisionEnd.x) ^ 2 + (lastPoint.y - self.incisionEnd.y) ^ 2)

			if (distToEnd < 50 or #self.incisionPoints > 10) then
				self:CompleteIncision()
			end
		end
	end
end

function PANEL:UpdateIncision()
	if (!self.dragging) then return end

	local mx, my = self:CursorPos()
	local last = self.incisionPoints[#self.incisionPoints]

	if (last) then
		local dist = math.sqrt((mx - last.x) ^ 2 + (my - last.y) ^ 2)

		if (dist > 4) then
			self.incisionPoints[#self.incisionPoints + 1] = {x = mx, y = my}
		end
	end
end

function PANEL:CompleteIncision()
	self.incisionComplete = true

	-- Score: average distance from guide path
	local totalDist = 0
	local samples = 0

	for _, pt in ipairs(self.incisionPoints) do
		local minDist = math.huge

		for _, gp in ipairs(self.incisionGuide) do
			local d = math.sqrt((pt.x - gp.x) ^ 2 + (pt.y - gp.y) ^ 2)

			if (d < minDist) then
				minDist = d
			end
		end

		totalDist = totalDist + minDist
		samples = samples + 1
	end

	local avgDist = samples > 0 and (totalDist / samples) or 50

	-- Convert distance to score: 0 dist = 1.0, 30+ dist = 0.0
	self.phaseScores[1] = math.Clamp(1 - (avgDist / 30), 0, 1)

	surface.PlaySound("physics/flesh/flesh_bloody_break.wav")
	self:TransitionToPhase(PHASE_EXTRACTION)
end

function PANEL:PaintIncision(w, h, contentY, contentBottom)
	local cx, cy, cw, ch = self:GetContentArea()
	local centerX = cx + cw / 2
	local centerY = cy + ch / 2

	-- Skin background
	draw.RoundedBox(8, centerX - 100, centerY - 110, 200, 220, COL_SKIN)
	draw.RoundedBox(6, centerX - 95, centerY - 105, 190, 210, COL_SKIN_DARK)

	-- Guide line (dashed)
	for i = 1, #self.incisionGuide - 1, 2 do
		local a = self.incisionGuide[i]
		local b = self.incisionGuide[math.min(i + 1, #self.incisionGuide)]

		surface.SetDrawColor(COL_INCISION_GUIDE)
		surface.DrawLine(a.x, a.y, b.x, b.y)
	end

	-- Start point marker
	if (!self.incisionComplete) then
		local pulse = 0.7 + math.sin(CurTime() * 5) * 0.3
		draw.RoundedBox(10, self.incisionStart.x - 10, self.incisionStart.y - 10, 20, 20, ColorAlpha(COL_STITCH_POINT, 200 * pulse))
		draw.SimpleText("START", "ixMinigameBody", self.incisionStart.x, self.incisionStart.y - 18, COL_PHASE_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	end

	-- End point marker
	draw.RoundedBox(6, self.incisionEnd.x - 6, self.incisionEnd.y - 6, 12, 12, ColorAlpha(COL_STITCH_POINT, 80))

	-- Player's incision line
	if (#self.incisionPoints > 1) then
		surface.SetDrawColor(COL_INCISION_CUT)

		for i = 1, #self.incisionPoints - 1 do
			local a = self.incisionPoints[i]
			local b = self.incisionPoints[i + 1]

			for offset = -1, 1 do
				surface.DrawLine(a.x + offset, a.y, b.x + offset, b.y)
			end
		end
	end

	-- Phase label
	draw.SimpleText("PHASE 1: INCISION", "ixMinigameBody", w / 2, contentY + 5, COL_PHASE_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

-- ============================================================
-- PHASE 2: EXTRACTION
-- ============================================================
function PANEL:SetupExtraction()
	self.hintText = "Guide the tweezers to the object without touching the walls."

	local cx, cy, cw, ch = self:GetContentArea()
	local centerX = cx + cw / 2
	local startY = cy + 30
	local endY = cy + ch - 40

	-- Generate winding channel
	self.channel = {}
	local segments = 12
	local channelWidth = 36

	for i = 0, segments do
		local t = i / segments
		local y = startY + (endY - startY) * t
		local xOffset = math.sin(t * math.pi * 3) * 60

		self.channel[i + 1] = {
			x = centerX + xOffset,
			y = y,
			width = channelWidth - t * 6, -- gets narrower towards bottom
		}
	end

	-- Object position at the bottom of the channel
	local lastSeg = self.channel[#self.channel]
	self.extractObject = {x = lastSeg.x, y = lastSeg.y}

	self.wallHits = 0
	self.maxWallHits = 5
	self.wallHitFlash = 0
	self.extractionComplete = false
	self.cursorInChannel = false
	self.extractionStarted = false
end

function PANEL:GetChannelBoundsAtY(y)
	-- Find the two control points this Y falls between
	for i = 1, #self.channel - 1 do
		local a = self.channel[i]
		local b = self.channel[i + 1]

		if (y >= a.y and y <= b.y) then
			local t = (y - a.y) / (b.y - a.y)
			local cx = a.x + (b.x - a.x) * t
			local w = a.width + (b.width - a.width) * t

			return cx - w / 2, cx + w / 2, cx
		end
	end

	-- Outside channel range
	return nil, nil, nil
end

function PANEL:UpdateExtraction()
	if (self.extractionComplete) then return end

	local mx, my = self:CursorPos()
	local leftBound, rightBound = self:GetChannelBoundsAtY(my)

	if (leftBound and rightBound) then
		self.extractionStarted = true

		if (mx < leftBound or mx > rightBound) then
			-- Wall collision
			if (!self.cursorInWall) then
				self.cursorInWall = true
				self.wallHits = self.wallHits + 1
				self.wallHitFlash = CurTime() + 0.2
				surface.PlaySound("buttons/button10.wav")

				if (self.wallHits >= self.maxWallHits) then
					self:CompleteExtraction()
					return
				end
			end
		else
			self.cursorInWall = false
		end

		-- Check if cursor reached the object
		local distToObj = math.sqrt((mx - self.extractObject.x) ^ 2 + (my - self.extractObject.y) ^ 2)

		if (distToObj < 20) then
			self:CompleteExtraction()
		end
	else
		self.cursorInWall = false
	end
end

function PANEL:CompleteExtraction()
	self.extractionComplete = true
	self.phaseScores[2] = math.Clamp(1 - (self.wallHits * 0.18), 0, 1)

	surface.PlaySound("items/medshot4.wav")
	self:TransitionToPhase(PHASE_SUTURING)
end

function PANEL:PaintExtraction(w, h, contentY, contentBottom)
	-- Phase label
	draw.SimpleText("PHASE 2: EXTRACTION", "ixMinigameBody", w / 2, contentY + 5, COL_PHASE_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

	-- Wall hit indicator
	draw.SimpleText(
		string.format("WALL CONTACTS: %d / %d", self.wallHits, self.maxWallHits),
		"ixMinigameBody", w / 2, contentY + 22,
		self.wallHits >= 3 and Color(255, 100, 80) or COL_PHASE_TEXT,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
	)

	-- Draw channel
	-- First draw the "outside" area as the wound
	local cx, cy, cw, ch = self:GetContentArea()
	draw.RoundedBox(4, cx, cy + 35, cw, ch - 55, Color(120, 40, 35, 100))

	-- Draw channel path
	for i = 1, #self.channel - 1 do
		local a = self.channel[i]
		local b = self.channel[i + 1]

		-- Channel walls (draw thick red borders)
		local steps = 10

		for s = 0, steps do
			local t = s / steps
			local y = a.y + (b.y - a.y) * t
			local centerXPos = a.x + (b.x - a.x) * t
			local width = a.width + (b.width - a.width) * t

			-- Channel interior
			surface.SetDrawColor(COL_CHANNEL_BG)
			surface.DrawRect(centerXPos - width / 2, y, width, math.ceil((b.y - a.y) / steps) + 1)

			-- Left wall
			surface.SetDrawColor(COL_CHANNEL_WALL)
			surface.DrawRect(centerXPos - width / 2 - 3, y, 3, math.ceil((b.y - a.y) / steps) + 1)

			-- Right wall
			surface.DrawRect(centerXPos + width / 2, y, 3, math.ceil((b.y - a.y) / steps) + 1)
		end
	end

	-- Draw object at bottom
	if (!self.extractionComplete) then
		local obj = self.extractObject
		draw.RoundedBox(4, obj.x - 8, obj.y - 8, 16, 16, COL_OBJECT)
		draw.RoundedBox(2, obj.x - 5, obj.y - 5, 10, 10, Color(120, 120, 130))
	end

	-- Draw tweezers cursor
	if (!self.extractionComplete) then
		local mx, my = self:CursorPos()

		-- Tweezers shape: two converging lines
		surface.SetDrawColor(COL_TWEEZERS)
		surface.DrawLine(mx - 8, my - 14, mx, my)
		surface.DrawLine(mx + 8, my - 14, mx, my)
		surface.DrawLine(mx - 9, my - 15, mx - 7, my - 13)
		surface.DrawLine(mx + 9, my - 15, mx + 7, my - 13)

		-- Tip dot
		draw.RoundedBox(2, mx - 2, my - 2, 4, 4, COL_TWEEZERS)
	end

	-- Wall hit flash
	if (self.wallHitFlash > CurTime()) then
		local alpha = (self.wallHitFlash - CurTime()) / 0.2 * 150
		draw.RoundedBox(0, 0, contentY, w, contentBottom - contentY, ColorAlpha(COL_WALL_HIT, alpha))
	end
end

-- ============================================================
-- PHASE 3: SUTURING
-- ============================================================
function PANEL:SetupSuturing()
	self.hintText = "Click alternating stitch points to close the wound."

	local cx, cy, cw, ch = self:GetContentArea()
	local centerX = cx + cw / 2
	local centerY = cy + ch / 2

	-- Wound line
	self.sutureWoundY1 = centerY - 80
	self.sutureWoundY2 = centerY + 80
	self.sutureWoundX = centerX

	-- Generate stitch pairs
	self.stitchPairs = {}
	local pairCount = 6
	local startY = self.sutureWoundY1 + 15
	local endY = self.sutureWoundY2 - 15
	local stepY = (endY - startY) / (pairCount - 1)
	local offset = 30

	for i = 1, pairCount do
		local y = startY + (i - 1) * stepY

		self.stitchPairs[i] = {
			left = {x = centerX - offset + math.Rand(-5, 5), y = y + math.Rand(-3, 3), hit = false},
			right = {x = centerX + offset + math.Rand(-5, 5), y = y + math.Rand(-3, 3), hit = false},
		}
	end

	-- Suturing alternates: left1, right1, left2, right2...
	self.stitchSequence = {}

	for i = 1, pairCount do
		self.stitchSequence[#self.stitchSequence + 1] = {pair = i, side = "left"}
		self.stitchSequence[#self.stitchSequence + 1] = {pair = i, side = "right"}
	end

	self.currentStitch = 1
	self.stitchAccuracy = 1.0
	self.suturingComplete = false
end

function PANEL:HandleSutureClick(mx, my)
	if (self.suturingComplete) then return end

	local target = self.stitchSequence[self.currentStitch]

	if (!target) then return end

	local point = self.stitchPairs[target.pair][target.side]
	local dist = math.sqrt((mx - point.x) ^ 2 + (my - point.y) ^ 2)

	if (dist < 22) then
		-- Hit
		point.hit = true

		if (dist > 12) then
			self.stitchAccuracy = self.stitchAccuracy - 0.02
		end

		self.currentStitch = self.currentStitch + 1
		surface.PlaySound("physics/body/body_medium_impact_soft" .. math.random(1, 3) .. ".wav")

		-- Check completion
		if (self.currentStitch > #self.stitchSequence) then
			self:CompleteSuturing()
		end
	else
		-- Wrong click
		self.stitchAccuracy = self.stitchAccuracy - 0.04
		surface.PlaySound("buttons/button10.wav")
	end
end

function PANEL:CompleteSuturing()
	self.suturingComplete = true
	self.phaseScores[3] = math.Clamp(self.stitchAccuracy, 0, 1)

	-- Compute final weighted score
	local finalScore = self.phaseScores[1] * 0.25 + self.phaseScores[2] * 0.45 + self.phaseScores[3] * 0.30

	surface.PlaySound("items/medcharge4.wav")
	self:OnMinigameComplete(finalScore)
end

function PANEL:PaintSuturing(w, h, contentY, contentBottom)
	local cx, cy, cw, ch = self:GetContentArea()
	local centerX = cx + cw / 2
	local centerY = cy + ch / 2

	-- Phase label
	draw.SimpleText("PHASE 3: SUTURING", "ixMinigameBody", w / 2, contentY + 5, COL_PHASE_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

	-- Skin area
	draw.RoundedBox(8, centerX - 80, centerY - 100, 160, 200, COL_SKIN)

	-- Wound line (open cut)
	surface.SetDrawColor(COL_WOUND)

	for offset = -2, 2 do
		surface.DrawLine(self.sutureWoundX + offset, self.sutureWoundY1, self.sutureWoundX + offset, self.sutureWoundY2)
	end

	surface.SetDrawColor(COL_WOUND_INNER)
	surface.DrawLine(self.sutureWoundX, self.sutureWoundY1, self.sutureWoundX, self.sutureWoundY2)

	-- Draw completed stitches
	for i, pair in ipairs(self.stitchPairs) do
		if (pair.left.hit and pair.right.hit) then
			-- Draw stitch line
			surface.SetDrawColor(COL_STITCH_LINE)

			for offset = -1, 0 do
				surface.DrawLine(pair.left.x, pair.left.y + offset, pair.right.x, pair.right.y + offset)
			end

			-- Cross marks at entry points
			draw.RoundedBox(3, pair.left.x - 3, pair.left.y - 3, 6, 6, COL_STITCH_DONE)
			draw.RoundedBox(3, pair.right.x - 3, pair.right.y - 3, 6, 6, COL_STITCH_DONE)
		end
	end

	-- Draw stitch points
	local target = self.stitchSequence[self.currentStitch]

	for i, pair in ipairs(self.stitchPairs) do
		for _, side in ipairs({"left", "right"}) do
			local point = pair[side]

			if (!point.hit) then
				local isTarget = target and target.pair == i and target.side == side

				if (isTarget) then
					-- Active target - pulsing
					local pulse = 0.7 + math.sin(CurTime() * 6) * 0.3
					local r = 10 * (1 + pulse * 0.3)

					-- Glow
					draw.RoundedBox(r + 3, point.x - r - 3, point.y - r - 3, (r + 3) * 2, (r + 3) * 2, ColorAlpha(COL_STITCH_POINT, 30))

					-- Point
					draw.RoundedBox(r, point.x - r, point.y - r, r * 2, r * 2, ColorAlpha(COL_STITCH_POINT, 200 * pulse))
				else
					-- Inactive point
					draw.RoundedBox(5, point.x - 5, point.y - 5, 10, 10, ColorAlpha(COL_STITCH_POINT, 30))
				end
			end
		end
	end
end

-- ============================================================
-- PHASE TRANSITIONS & ROUTING
-- ============================================================
function PANEL:TransitionToPhase(newPhase)
	self.phaseTransition = true
	self.transitionEnd = CurTime() + 0.8

	timer.Simple(0.8, function()
		if (!IsValid(self)) then return end

		self.phaseTransition = false
		self.phase = newPhase

		if (newPhase == PHASE_EXTRACTION) then
			self:SetupExtraction()
		elseif (newPhase == PHASE_SUTURING) then
			self:SetupSuturing()
		end
	end)
end

function PANEL:OnMousePressed(mouseCode)
	if (self.finished or self.phaseTransition) then return end

	if (self.phase == PHASE_INCISION) then
		self:HandleIncisionInput(mouseCode, true)
	elseif (self.phase == PHASE_SUTURING and mouseCode == MOUSE_LEFT) then
		local mx, my = self:CursorPos()
		self:HandleSutureClick(mx, my)
	end
end

function PANEL:OnMouseReleased(mouseCode)
	if (self.finished or self.phaseTransition) then return end

	if (self.phase == PHASE_INCISION and mouseCode == MOUSE_LEFT) then
		self:HandleIncisionRelease()
	end
end

function PANEL:Think()
	if (self.finished) then return end

	-- Base class timeout
	if (self:GetTimeRemaining() <= 0) then
		self:OnMinigameComplete(0)
		return
	end

	if (self.phaseTransition) then return end

	if (self.phase == PHASE_INCISION) then
		self:UpdateIncision()
	elseif (self.phase == PHASE_EXTRACTION) then
		self:UpdateExtraction()
	end
end

function PANEL:PaintMinigame(w, h, contentY, contentBottom)
	-- Phase transition overlay
	if (self.phaseTransition) then
		local progress = 1 - math.Clamp((self.transitionEnd - CurTime()) / 0.8, 0, 1)
		local alpha = math.sin(progress * math.pi) * 200

		draw.RoundedBox(0, 0, contentY, w, contentBottom - contentY, Color(0, 0, 0, alpha))

		if (progress > 0.3) then
			local nextName = self.phase == PHASE_INCISION and "EXTRACTION" or "SUTURING"
			draw.SimpleText("NEXT: " .. nextName, "ixMinigameHeader", w / 2, contentY + (contentBottom - contentY) / 2, ColorAlpha(COL_PHASE_TEXT, alpha * 1.5), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		return
	end

	if (self.phase == PHASE_INCISION) then
		self:PaintIncision(w, h, contentY, contentBottom)
	elseif (self.phase == PHASE_EXTRACTION) then
		self:PaintExtraction(w, h, contentY, contentBottom)
	elseif (self.phase == PHASE_SUTURING) then
		self:PaintSuturing(w, h, contentY, contentBottom)
	end

	-- Phase progress indicators at top-right of content area
	local dotX = w - 30
	local dotY = contentY + 12

	for i = 1, 3 do
		local col

		if (i < self.phase) then
			col = COL_STITCH_DONE
		elseif (i == self.phase) then
			col = COL_STITCH_POINT
		else
			col = Color(60, 70, 80)
		end

		draw.RoundedBox(5, dotX, dotY + (i - 1) * 16, 10, 10, col)
	end
end

vgui.Register("ixCWUMinigameSurgery", PANEL, "ixCWUMinigameBase")
