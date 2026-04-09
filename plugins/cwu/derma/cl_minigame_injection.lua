-- Injection/Synthesis minigame - timing meter with green zone
-- Used for all chemical synthesis procedures at the medical workstation.

local PANEL = {}

local COL_BAR_BG = Color(30, 35, 40)
local COL_RED = Color(180, 50, 50)
local COL_YELLOW = Color(200, 180, 50)
local COL_GREEN = Color(50, 200, 80)
local COL_INDICATOR = Color(255, 255, 255)
local COL_GLOW = Color(200, 220, 255, 80)
local COL_ROUND_TEXT = Color(160, 180, 200)
local COL_BEAKER = Color(80, 140, 180, 120)
local COL_BUBBLE = Color(100, 200, 160, 150)

function PANEL:OnMinigameSetup()
	self.headerText = "CHEMICAL SYNTHESIS"
	self.hintText = "Click when the indicator is in the green zone."

	-- Determine round count based on synthesis type
	if (self.sessionType == "injection_medicine") then
		self.totalRounds = 3
	else
		self.totalRounds = 4
	end

	self.currentRound = 1
	self.roundScores = {}
	self.indicatorPos = 0
	self.indicatorDir = 1
	self.indicatorSpeed = 0.7
	self.waitingForInput = true
	self.roundPaused = false
	self.pauseEndTime = 0
	self.roundResultText = nil
	self.roundResultColor = nil

	-- Bubbles for beaker animation
	self.bubbles = {}

	self:GenerateZones()
end

function PANEL:GenerateZones()
	-- Green zone: 15-20% of bar, random position each round
	local greenWidth = math.Rand(0.12, 0.18)
	local greenStart = math.Rand(0.15, 0.85 - greenWidth)

	self.greenZone = {start = greenStart, finish = greenStart + greenWidth}

	-- Yellow extends 8% beyond green on each side
	local yellowPad = 0.08
	self.yellowZone = {
		start = math.max(0, greenStart - yellowPad),
		finish = math.min(1, greenStart + greenWidth + yellowPad)
	}
end

function PANEL:Think()
	-- Call base Think for timeout/distance checks
	if (self.finished) then return end

	-- Base class timeout check
	if (self:GetTimeRemaining() <= 0) then
		self:OnMinigameComplete(0)
		return
	end

	-- Handle round pause
	if (self.roundPaused) then
		if (CurTime() >= self.pauseEndTime) then
			self.roundPaused = false
			self.roundResultText = nil

			if (self.currentRound > self.totalRounds) then
				-- All rounds done, compute final score
				local total = 0

				for _, s in ipairs(self.roundScores) do
					total = total + s
				end

				self:OnMinigameComplete(total / self.totalRounds)
				return
			end

			-- Set up next round
			self.indicatorSpeed = self.indicatorSpeed + 0.25
			self.waitingForInput = true
			self:GenerateZones()
		end

		return
	end

	-- Move indicator
	if (self.waitingForInput) then
		self.indicatorPos = self.indicatorPos + self.indicatorDir * self.indicatorSpeed * FrameTime()

		if (self.indicatorPos >= 1) then
			self.indicatorPos = 1
			self.indicatorDir = -1
		elseif (self.indicatorPos <= 0) then
			self.indicatorPos = 0
			self.indicatorDir = 1
		end
	end

	-- Spawn bubbles occasionally
	if (math.random() < 0.15) then
		self.bubbles[#self.bubbles + 1] = {
			x = math.Rand(-15, 15),
			y = 0,
			speed = math.Rand(30, 60),
			size = math.Rand(3, 8),
			alpha = 200,
		}
	end

	-- Update bubbles
	local dt = FrameTime()

	for i = #self.bubbles, 1, -1 do
		local b = self.bubbles[i]
		b.y = b.y - b.speed * dt
		b.x = b.x + math.sin(CurTime() * 3 + i) * 10 * dt
		b.alpha = b.alpha - 40 * dt

		if (b.alpha <= 0 or b.y < -120) then
			table.remove(self.bubbles, i)
		end
	end
end

function PANEL:OnMousePressed(mouseCode)
	if (mouseCode != MOUSE_LEFT) then return end
	if (self.finished or self.roundPaused or !self.waitingForInput) then return end

	self:DoInput()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:OnMinigameCancel()
		return true
	end

	if (key == KEY_SPACE and !self.finished and !self.roundPaused and self.waitingForInput) then
		self:DoInput()
		return true
	end
end

function PANEL:DoInput()
	self.waitingForInput = false

	local pos = self.indicatorPos
	local roundScore

	if (pos >= self.greenZone.start and pos <= self.greenZone.finish) then
		roundScore = 1.0
		self.roundResultText = "PERFECT!"
		self.roundResultColor = COL_GREEN
		surface.PlaySound("buttons/button9.wav")
	elseif (pos >= self.yellowZone.start and pos <= self.yellowZone.finish) then
		roundScore = 0.5
		self.roundResultText = "OK"
		self.roundResultColor = COL_YELLOW
		surface.PlaySound("buttons/button14.wav")
	else
		roundScore = 0.1
		self.roundResultText = "MISS"
		self.roundResultColor = COL_RED
		surface.PlaySound("buttons/button10.wav")
	end

	self.roundScores[#self.roundScores + 1] = roundScore
	self.currentRound = self.currentRound + 1

	-- Update displayed score as running average
	local total = 0

	for _, s in ipairs(self.roundScores) do
		total = total + s
	end

	self.score = total / self.totalRounds

	-- Pause before next round
	self.roundPaused = true
	self.pauseEndTime = CurTime() + 0.7
end

function PANEL:PaintMinigame(w, h, contentY, contentBottom)
	local contentH = contentBottom - contentY
	local cx = w / 2
	local cy = contentY + contentH / 2

	-- Draw beaker above bar
	local beakerW = 50
	local beakerH = 80
	local beakerX = cx - beakerW / 2
	local beakerY = cy - 90

	-- Beaker body
	surface.SetDrawColor(COL_BEAKER)
	surface.DrawRect(beakerX, beakerY, beakerW, beakerH)
	surface.SetDrawColor(60, 100, 140, 80)
	surface.DrawRect(beakerX + 4, beakerY + 4, beakerW - 8, beakerH - 4)

	-- Beaker neck
	local neckW = 24
	surface.SetDrawColor(COL_BEAKER)
	surface.DrawRect(cx - neckW / 2, beakerY - 20, neckW, 22)
	surface.SetDrawColor(60, 100, 140, 80)
	surface.DrawRect(cx - neckW / 2 + 3, beakerY - 17, neckW - 6, 17)

	-- Liquid fill (rises with rounds completed)
	local fillFrac = #self.roundScores / self.totalRounds
	local fillH = math.floor((beakerH - 8) * (0.3 + 0.7 * fillFrac))
	local liquidColor = Color(60, 180, 120, 160)

	if (self.sessionType == "injection_combat") then
		liquidColor = Color(180, 60, 60, 160)
	elseif (self.sessionType == "injection_recreational") then
		liquidColor = Color(160, 80, 200, 160)
	end

	surface.SetDrawColor(liquidColor)
	surface.DrawRect(beakerX + 4, beakerY + beakerH - 4 - fillH, beakerW - 8, fillH)

	-- Bubbles inside beaker
	for _, b in ipairs(self.bubbles) do
		local bx = cx + b.x
		local by = beakerY + beakerH - 8 + b.y

		if (by > beakerY + 4 and by < beakerY + beakerH - 4) then
			draw.RoundedBox(b.size, bx - b.size / 2, by - b.size / 2, b.size, b.size, ColorAlpha(COL_BUBBLE, b.alpha))
		end
	end

	-- Round counter
	local roundDisplay = math.min(self.currentRound, self.totalRounds)
	draw.SimpleText(
		string.format("CYCLE %d / %d", roundDisplay, self.totalRounds),
		"ixMinigameBody", cx, cy - 10, COL_ROUND_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
	)

	-- Timing bar
	local barW = w - 100
	local barH = 32
	local barX = 50
	local barY = cy + 15

	-- Bar background
	surface.SetDrawColor(COL_BAR_BG)
	surface.DrawRect(barX, barY, barW, barH)

	-- Red zone (entire bar as base)
	surface.SetDrawColor(COL_RED.r, COL_RED.g, COL_RED.b, 60)
	surface.DrawRect(barX, barY, barW, barH)

	-- Yellow zone
	local yelX = barX + math.floor(barW * self.yellowZone.start)
	local yelW = math.floor(barW * (self.yellowZone.finish - self.yellowZone.start))
	surface.SetDrawColor(COL_YELLOW.r, COL_YELLOW.g, COL_YELLOW.b, 80)
	surface.DrawRect(yelX, barY, yelW, barH)

	-- Green zone
	local grnX = barX + math.floor(barW * self.greenZone.start)
	local grnW = math.floor(barW * (self.greenZone.finish - self.greenZone.start))
	surface.SetDrawColor(COL_GREEN.r, COL_GREEN.g, COL_GREEN.b, 100)
	surface.DrawRect(grnX, barY, grnW, barH)

	-- Bar border
	surface.SetDrawColor(COL_INDICATOR.r, COL_INDICATOR.g, COL_INDICATOR.b, 40)
	surface.DrawOutlinedRect(barX, barY, barW, barH, 1)

	-- Tick marks
	surface.SetDrawColor(255, 255, 255, 30)

	for i = 1, 9 do
		local tx = barX + math.floor(barW * i / 10)
		surface.DrawRect(tx, barY, 1, barH)
	end

	-- Indicator
	local indX = barX + math.floor(barW * self.indicatorPos)

	-- Glow
	surface.SetDrawColor(COL_GLOW)
	surface.DrawRect(indX - 6, barY - 2, 12, barH + 4)

	-- Line
	surface.SetDrawColor(COL_INDICATOR)
	surface.DrawRect(indX - 1, barY - 4, 3, barH + 8)

	-- Triangle pointer above
	draw.NoTexture()
	surface.SetDrawColor(COL_INDICATOR)
	surface.DrawPoly({
		{x = indX, y = barY - 5},
		{x = indX - 6, y = barY - 12},
		{x = indX + 6, y = barY - 12},
	})

	-- Round result text
	if (self.roundResultText) then
		local alpha = math.Clamp((self.pauseEndTime - CurTime()) / 0.7 * 255, 0, 255)
		draw.SimpleText(
			self.roundResultText, "ixMinigameLarge",
			cx, cy + 70,
			ColorAlpha(self.roundResultColor, alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)
	end

	-- Flash bar border on result
	if (self.roundPaused and self.roundResultColor) then
		local flash = math.Clamp((self.pauseEndTime - CurTime()) / 0.7, 0, 1)
		surface.SetDrawColor(self.roundResultColor.r, self.roundResultColor.g, self.roundResultColor.b, flash * 180)
		surface.DrawOutlinedRect(barX - 1, barY - 1, barW + 2, barH + 2, 2)
	end
end

vgui.Register("ixCWUMinigameInjection", PANEL, "ixCWUMinigameBase")
