-- Bandaging minigame - click waypoints in sequence to wrap a wound
-- Used for basic treatment at the medical workstation.

local PANEL = {}

local COL_WOUND = Color(140, 40, 35, 200)
local COL_WOUND_INNER = Color(100, 25, 20, 180)
local COL_BANDAGE = Color(230, 220, 200)
local COL_BANDAGE_SHADOW = Color(180, 170, 150, 120)
local COL_WAYPOINT_DONE = Color(60, 180, 100, 80)
local COL_WAYPOINT_ACTIVE = Color(100, 200, 255)
local COL_WAYPOINT_NEXT = Color(100, 200, 255, 40)
local COL_GUIDE_LINE = Color(100, 150, 200, 50)
local COL_MISS_FLASH = Color(255, 60, 60, 100)

function PANEL:OnMinigameSetup()
	self.headerText = "BASIC TREATMENT"
	self.hintText = "Click the marked points to wrap the bandage."

	self.waypoints = {}
	self.currentWaypoint = 1
	self.accuracy = 1.0
	self.misclicks = 0
	self.missFlash = 0
	self.score = 1.0

	self:GenerateWaypoints()
end

function PANEL:GenerateWaypoints()
	local cx, cy, cw, ch = self:GetContentArea()
	local centerX = cx + cw / 2
	local centerY = cy + ch / 2

	-- Wound dimensions
	self.woundX = centerX
	self.woundY = centerY
	self.woundW = 60
	self.woundH = 140

	-- Generate zigzag waypoints around the wound
	local count = 10
	local startY = self.woundY - self.woundH / 2 + 15
	local endY = self.woundY + self.woundH / 2 - 15
	local stepY = (endY - startY) / (count - 1)
	local offsetX = 65

	for i = 1, count do
		local side = (i % 2 == 1) and -1 or 1
		local y = startY + (i - 1) * stepY
		local x = self.woundX + side * offsetX + math.Rand(-8, 8)

		self.waypoints[i] = {
			x = x,
			y = y,
			radius = 18,
			hit = false,
		}
	end
end

function PANEL:OnMousePressed(mouseCode)
	if (mouseCode != MOUSE_LEFT) then return end
	if (self.finished) then return end

	local mx, my = self:CursorPos()
	local wp = self.waypoints[self.currentWaypoint]

	if (!wp) then return end

	local dist = math.sqrt((mx - wp.x) ^ 2 + (my - wp.y) ^ 2)

	if (dist <= wp.radius * 1.5) then
		-- Hit the waypoint
		wp.hit = true

		if (dist > wp.radius) then
			-- Imprecise hit
			self.accuracy = self.accuracy - 0.03
		end

		self.currentWaypoint = self.currentWaypoint + 1
		surface.PlaySound("physics/body/body_medium_impact_soft" .. math.random(1, 3) .. ".wav")

		-- Update score display
		self.score = math.max(0, self.accuracy)

		-- Check if all waypoints are done
		if (self.currentWaypoint > #self.waypoints) then
			self:OnMinigameComplete(math.max(0, self.accuracy))
		end
	else
		-- Misclick
		self.misclicks = self.misclicks + 1
		self.accuracy = self.accuracy - 0.05
		self.missFlash = CurTime() + 0.3
		self.score = math.max(0, self.accuracy)
		surface.PlaySound("buttons/button10.wav")
	end
end

function PANEL:PaintMinigame(w, h, contentY, contentBottom)
	-- Miss flash overlay
	if (self.missFlash > CurTime()) then
		local alpha = (self.missFlash - CurTime()) / 0.3 * COL_MISS_FLASH.a
		draw.RoundedBox(0, 0, contentY, w, contentBottom - contentY, ColorAlpha(COL_MISS_FLASH, alpha))
	end

	-- Draw wound area
	local wX = self.woundX
	local wY = self.woundY
	local wW = self.woundW
	local wH = self.woundH

	-- Wound outer shape (irregular ellipse via overlapping boxes)
	draw.RoundedBox(8, wX - wW / 2 - 4, wY - wH / 2, wW + 8, wH, COL_WOUND)
	draw.RoundedBox(6, wX - wW / 2 + 2, wY - wH / 2 + 5, wW - 4, wH - 10, COL_WOUND_INNER)

	-- Wound detail lines
	surface.SetDrawColor(80, 20, 15, 150)

	for i = 0, 5 do
		local ly = wY - wH / 2 + 20 + i * 20
		local lx = wX - wW / 4 + math.sin(i * 1.5) * 5
		surface.DrawRect(lx, ly, wW / 2, 1)
	end

	-- Draw guide line connecting upcoming waypoints
	for i = self.currentWaypoint, #self.waypoints - 1 do
		local a = self.waypoints[i]
		local b = self.waypoints[i + 1]

		surface.SetDrawColor(COL_GUIDE_LINE)

		-- Dashed line
		local dx = b.x - a.x
		local dy = b.y - a.y
		local len = math.sqrt(dx * dx + dy * dy)
		local steps = math.floor(len / 8)

		for s = 0, steps, 2 do
			local frac = s / steps
			local frac2 = math.min(1, (s + 1) / steps)
			local x1 = a.x + dx * frac
			local y1 = a.y + dy * frac
			local x2 = a.x + dx * frac2
			local y2 = a.y + dy * frac2

			surface.DrawLine(x1, y1, x2, y2)
		end
	end

	-- Draw completed bandage strips
	for i = 1, self.currentWaypoint - 2 do
		local a = self.waypoints[i]
		local b = self.waypoints[i + 1]

		if (a.hit and b.hit) then
			-- Bandage shadow
			surface.SetDrawColor(COL_BANDAGE_SHADOW)

			for offset = -3, 3 do
				surface.DrawLine(a.x + 1, a.y + offset + 1, b.x + 1, b.y + offset + 1)
			end

			-- Bandage strip
			surface.SetDrawColor(COL_BANDAGE)

			for offset = -2, 2 do
				surface.DrawLine(a.x, a.y + offset, b.x, b.y + offset)
			end
		end
	end

	-- Draw last completed strip to current
	if (self.currentWaypoint > 1 and self.currentWaypoint <= #self.waypoints) then
		local prev = self.waypoints[self.currentWaypoint - 1]
		local cur = self.waypoints[self.currentWaypoint]

		if (prev.hit) then
			surface.SetDrawColor(COL_BANDAGE.r, COL_BANDAGE.g, COL_BANDAGE.b, 60)

			for offset = -2, 2 do
				surface.DrawLine(prev.x, prev.y + offset, cur.x, cur.y + offset)
			end
		end
	end

	-- Draw waypoints
	for i, wp in ipairs(self.waypoints) do
		if (wp.hit) then
			-- Completed waypoint
			draw.RoundedBox(wp.radius, wp.x - wp.radius / 2, wp.y - wp.radius / 2, wp.radius, wp.radius, COL_WAYPOINT_DONE)
		elseif (i == self.currentWaypoint) then
			-- Active waypoint - pulsing
			local pulse = 0.7 + math.sin(CurTime() * 6) * 0.3
			local r = wp.radius * (1 + pulse * 0.2)
			local col = ColorAlpha(COL_WAYPOINT_ACTIVE, 200 * pulse)

			-- Outer glow
			draw.RoundedBox(r + 4, wp.x - (r + 4), wp.y - (r + 4), (r + 4) * 2, (r + 4) * 2, ColorAlpha(COL_WAYPOINT_ACTIVE, 30 * pulse))

			-- Ring
			surface.SetDrawColor(col)
			local segments = 24
			local prevPX, prevPY

			for s = 0, segments do
				local angle = (s / segments) * math.pi * 2
				local px = wp.x + math.cos(angle) * r
				local py = wp.y + math.sin(angle) * r

				if (prevPX) then
					surface.DrawLine(prevPX, prevPY, px, py)
				end

				prevPX, prevPY = px, py
			end

			-- Center dot
			draw.RoundedBox(4, wp.x - 4, wp.y - 4, 8, 8, COL_WAYPOINT_ACTIVE)

			-- Number
			draw.SimpleText(tostring(i), "ixMinigameBody", wp.x, wp.y, COL_WAYPOINT_ACTIVE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			-- Future waypoint
			draw.RoundedBox(wp.radius / 2, wp.x - wp.radius / 4, wp.y - wp.radius / 4, wp.radius / 2, wp.radius / 2, COL_WAYPOINT_NEXT)
		end
	end
end

vgui.Register("ixCWUMinigameBandaging", PANEL, "ixCWUMinigameBase")
