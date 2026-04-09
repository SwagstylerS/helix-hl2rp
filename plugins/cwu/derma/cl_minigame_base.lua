-- Base minigame panel - provides shared chrome, timer, score display, and networking
-- All medical minigames extend this panel.

surface.CreateFont("ixMinigameHeader", {font = "Courier New", size = 22, weight = 800, antialias = true})
surface.CreateFont("ixMinigameBody", {font = "Courier New", size = 14, weight = 600, antialias = true})
surface.CreateFont("ixMinigameHint", {font = "Default", size = 16, weight = 500, antialias = true})
surface.CreateFont("ixMinigameLarge", {font = "Courier New", size = 36, weight = 800, antialias = true})
surface.CreateFont("ixMinigameScore", {font = "Courier New", size = 16, weight = 700, antialias = true})

local PANEL = {}

local COL_BG = Color(15, 20, 25, 240)
local COL_BORDER = Color(60, 120, 160)
local COL_HEADER_BG = Color(10, 15, 20, 250)
local COL_HEADER_TEXT = Color(100, 150, 255)
local COL_TIMER = Color(200, 220, 255)
local COL_SCORE_BG = Color(20, 30, 35)
local COL_SCORE_FILL = Color(60, 180, 100)
local COL_SCANLINE = Color(60, 120, 160, 12)
local COL_HINT = Color(160, 180, 200)

function PANEL:Init()
	self:SetSize(700, 500)
	self:Center()
	self:MakePopup()
	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(true)

	self.sessionToken = nil
	self.sessionType = nil
	self.maxTime = 30
	self.startTime = CurTime()
	self.score = 0
	self.headerText = "MEDICAL PROCEDURE"
	self.hintText = ""
	self.finished = false
	self.finishTime = nil
	self.resultText = nil
	self.resultColor = nil
end

function PANEL:SetSessionData(token, sessionType, maxTime, extraData)
	self.sessionToken = token
	self.sessionType = sessionType
	self.maxTime = maxTime
	self.startTime = CurTime()
	self.extraData = extraData or {}

	self:OnMinigameSetup()
end

-- Override in subclasses to set up the minigame
function PANEL:OnMinigameSetup()
end

function PANEL:GetElapsed()
	return CurTime() - self.startTime
end

function PANEL:GetTimeRemaining()
	return math.max(0, self.maxTime - self:GetElapsed())
end

function PANEL:OnMinigameComplete(score)
	if (self.finished) then return end

	self.finished = true
	self.finishTime = CurTime()
	self.score = math.Clamp(score, 0, 1)

	if (score >= 0.8) then
		self.resultText = "EXCELLENT"
		self.resultColor = Color(80, 255, 120)
	elseif (score >= 0.5) then
		self.resultText = "ADEQUATE"
		self.resultColor = Color(255, 220, 80)
	else
		self.resultText = "POOR"
		self.resultColor = Color(255, 80, 80)
	end

	surface.PlaySound("buttons/combine_button1.wav")

	netstream.Start("CWUMinigameComplete", self.sessionToken, self.score)

	-- Auto-close after showing result
	timer.Simple(1.5, function()
		if (IsValid(self)) then
			self:Remove()
		end
	end)
end

function PANEL:OnMinigameCancel()
	if (self.finished) then return end

	self.finished = true
	netstream.Start("CWUMinigameCancel", self.sessionToken)
	self:Remove()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:OnMinigameCancel()
		return true
	end
end

function PANEL:Think()
	if (self.finished) then return end

	-- Auto-fail on timeout
	if (self:GetTimeRemaining() <= 0) then
		self:OnMinigameComplete(0)
		return
	end

	-- Check distance to workstation (player may have been moved)
	local ply = LocalPlayer()

	if (IsValid(ply) and self.extraData and self.extraData.entPos) then
		local dist = ply:GetPos():Distance(self.extraData.entPos)

		if (dist > 300) then
			self:OnMinigameCancel()
			return
		end
	end
end

function PANEL:Paint(w, h)
	-- Background
	draw.RoundedBox(4, 0, 0, w, h, COL_BG)

	-- Scanline effect
	local sweepY = ((CurTime() * 60) % h)
	surface.SetDrawColor(COL_SCANLINE)
	surface.DrawRect(0, sweepY, w, 2)

	-- Subtle scanlines every 3px
	surface.SetDrawColor(0, 0, 0, 15)

	for y = 0, h, 3 do
		surface.DrawRect(0, y, w, 1)
	end

	-- Border
	surface.SetDrawColor(COL_BORDER)
	surface.DrawOutlinedRect(0, 0, w, h, 2)

	-- Header bar
	local headerH = 36
	surface.SetDrawColor(COL_HEADER_BG)
	surface.DrawRect(2, 2, w - 4, headerH)
	surface.SetDrawColor(COL_BORDER)
	surface.DrawRect(2, headerH + 2, w - 4, 1)

	-- Header text
	draw.SimpleText(self.headerText, "ixMinigameHeader", 12, headerH / 2 + 2, COL_HEADER_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- Timer
	local timeLeft = self:GetTimeRemaining()
	local timerStr = string.format("%02d:%02d", math.floor(timeLeft / 60), math.floor(timeLeft % 60))
	local timerCol = timeLeft < 5 and Color(255, 80, 80) or COL_TIMER
	draw.SimpleText(timerStr, "ixMinigameHeader", w - 12, headerH / 2 + 2, timerCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	-- Score bar at bottom
	local barH = 24
	local barY = h - barH - 6
	local barX = 12
	local barW = w - 24
	surface.SetDrawColor(COL_SCORE_BG)
	surface.DrawRect(barX, barY, barW, barH)
	surface.SetDrawColor(COL_SCORE_FILL)
	surface.DrawRect(barX, barY, math.floor(barW * self.score), barH)
	surface.SetDrawColor(COL_BORDER)
	surface.DrawOutlinedRect(barX, barY, barW, barH, 1)
	draw.SimpleText(string.format("ACCURACY: %d%%", math.floor(self.score * 100)), "ixMinigameScore", barX + barW / 2, barY + barH / 2, Color(220, 230, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- Hint text
	if (self.hintText and self.hintText != "") then
		draw.SimpleText(self.hintText, "ixMinigameHint", w / 2, barY - 14, COL_HINT, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	end

	-- Result overlay
	if (self.finished and self.resultText) then
		local alpha = math.min(255, (CurTime() - self.finishTime) * 600)
		draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, alpha * 0.4))
		draw.SimpleText(self.resultText, "ixMinigameLarge", w / 2, h / 2 - 20, ColorAlpha(self.resultColor, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- Subclass draws in the content area (between header and score bar)
	self:PaintMinigame(w, h, 44, barY - 20)
end

-- Override in subclasses - contentY is where drawing starts, contentBottom is where it ends
function PANEL:PaintMinigame(w, h, contentY, contentBottom)
end

-- Utility: get content area dimensions
function PANEL:GetContentArea()
	local headerH = 44
	local barH = 44
	return 12, headerH, self:GetWide() - 24, self:GetTall() - headerH - barH
end

vgui.Register("ixCWUMinigameBase", PANEL, "DPanel")
