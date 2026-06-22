-- Cooking minigame and recipe picker panels.

-- ──────────────────────────────────────────────────────────────────────────────
-- Interaction definitions
-- Each has: label, init(state,w,h), paint(state,w,h), and optional handlers.
-- state.done = true signals step completion; state.succeeded = true = quality +1.
-- ──────────────────────────────────────────────────────────────────────────────

local INTER = {}

-- STIR: click-drag the mouse; accumulate drag distance → success at threshold.
INTER.stir = {
	label = "STIR",
	init = function(s, w, h)
		s.cx, s.cy   = w * 0.5, h * 0.5
		s.radius     = math.min(w, h) * 0.35
		s.dragDist   = 0
		s.dragging   = false
		s.lastX      = 0
		s.lastY      = 0
		s.threshold  = 140
	end,
	paint = function(s, w, h)
		local fill = math.Clamp(s.dragDist / s.threshold, 0, 1)
		-- pot circle
		surface.SetDrawColor(60, 50, 40)
		surface.DrawRect(s.cx - s.radius, s.cy - s.radius * 0.4, s.radius * 2, s.radius * 0.8)
		-- liquid
		local liqAlpha = 180 + math.floor(math.sin(RealTime() * 3) * 30)
		surface.SetDrawColor(120, 80, 40, liqAlpha)
		surface.DrawRect(s.cx - s.radius + 4, s.cy - s.radius * 0.4 + 4, (s.radius * 2 - 8) * fill, s.radius * 0.8 - 8)
		-- label
		draw.SimpleText("STIR", "DermaDefaultBold", s.cx, s.cy + s.radius * 0.7, s.dragging and Color(255, 220, 80) or Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end,
	onMouseDown = function(s, x, y)
		s.dragging = true
		s.lastX, s.lastY = x, y
	end,
	onMouseUp = function(s)
		s.dragging = false
	end,
	onCursorMoved = function(s, x, y)
		if (!s.dragging) then return end
		local dx = x - s.lastX
		local dy = y - s.lastY
		s.dragDist = s.dragDist + math.sqrt(dx * dx + dy * dy)
		s.lastX, s.lastY = x, y
		if (s.dragDist >= s.threshold) then
			s.succeeded = true
			s.done = true
		end
	end,
}

-- FLIP: sizzle bar fills; click the flip zone when bar > 65%.
INTER.flip = {
	label = "FLIP",
	init = function(s, w, h)
		s.barStart   = RealTime()
		s.barTime    = 3.5
		s.cx, s.cy   = w * 0.5, h * 0.5
		s.zoneActive = false
	end,
	paint = function(s, w, h)
		local elapsed  = RealTime() - s.barStart
		local progress = math.Clamp(elapsed / s.barTime, 0, 1)
		s.zoneActive   = progress > 0.65

		-- grill surface
		surface.SetDrawColor(40, 35, 30)
		surface.DrawRect(s.cx - 70, s.cy - 20, 140, 40)

		-- sizzle bar (represents heat)
		local barColor = s.zoneActive and Color(255, 180, 0) or Color(200, 100, 30)
		surface.SetDrawColor(barColor)
		surface.DrawRect(s.cx - 68, s.cy - 6, math.floor(136 * progress), 12)
		surface.SetDrawColor(80, 80, 80)
		surface.DrawOutlinedRect(s.cx - 68, s.cy - 6, 136, 12)

		-- FLIP prompt
		local col = s.zoneActive and Color(255, 240, 60) or Color(120, 120, 120)
		if (s.zoneActive) then
			-- pulse
			local alpha = math.abs(math.sin(RealTime() * 6)) * 255
			surface.SetDrawColor(ColorAlpha(Color(255, 200, 0), alpha * 0.3))
			surface.DrawRect(s.cx - 50, s.cy + 18, 100, 28)
		end
		draw.SimpleText("FLIP", "DermaDefaultBold", s.cx, s.cy + 32, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end,
	onMouseDown = function(s, x, y)
		if (!s.zoneActive) then return end
		s.succeeded = true
		s.done = true
	end,
	think = function(s)
		if (RealTime() - s.barStart >= s.barTime) then
			s.done = true  -- missed the window
		end
	end,
}

-- SEASON: click three salt icons in sequence (left, right, left).
INTER.season = {
	label = "SEASON",
	init = function(s, w, h)
		s.sequence = {1, 2, 1}  -- 1=left, 2=right
		s.step     = 1
		s.cx, s.cy = w * 0.5, h * 0.5
		s.icons    = {
			{x = w * 0.3, y = h * 0.5},
			{x = w * 0.7, y = h * 0.5},
		}
		s.iconR = 20
	end,
	paint = function(s, w, h)
		for i, icon in ipairs(s.icons) do
			local isNext  = (s.step <= #s.sequence) and (s.sequence[s.step] == i)
			local done    = (s.step > #s.sequence)
			local col     = isNext and Color(255, 230, 80) or Color(80, 80, 80)
			if (done) then col = Color(0, 200, 80) end
			surface.SetDrawColor(col)
			surface.DrawOutlinedRect(icon.x - s.iconR, icon.y - s.iconR, s.iconR * 2, s.iconR * 2)
			local letter = (i == 1) and "L" or "R"
			draw.SimpleText(letter, "DermaDefaultBold", icon.x, icon.y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		draw.SimpleText("SEASON", "DermaDefaultBold", w * 0.5, h * 0.85, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end,
	onMouseDown = function(s, x, y)
		if (s.step > #s.sequence) then return end
		local target = s.sequence[s.step]
		local icon   = s.icons[target]
		if (math.abs(x - icon.x) <= s.iconR and math.abs(y - icon.y) <= s.iconR) then
			s.step = s.step + 1
			if (s.step > #s.sequence) then
				s.succeeded = true
				s.done = true
			end
		else
			s.step = 1  -- wrong icon: restart sequence (no punishment, just restart)
		end
	end,
}

-- SKIM: move mouse left-to-right across the skim strip while hovering it.
INTER.skim = {
	label = "SKIM",
	init = function(s, w, h)
		s.stripY  = h * 0.45
		s.stripH  = 24
		s.stripX1 = w * 0.1
		s.stripX2 = w * 0.9
		s.entered = false
		s.maxX    = s.stripX1  -- track rightmost X reached while in strip
	end,
	paint = function(s, w, h)
		-- pot top
		surface.SetDrawColor(50, 50, 50)
		surface.DrawRect(s.stripX1, s.stripY, s.stripX2 - s.stripX1, s.stripH)
		-- foam (decreases as skim progresses)
		local progress = math.Clamp((s.maxX - s.stripX1) / (s.stripX2 - s.stripX1), 0, 1)
		surface.SetDrawColor(220, 220, 200, 200)
		surface.DrawRect(s.stripX1, s.stripY + 4, (s.stripX2 - s.stripX1) * (1 - progress), s.stripH - 8)
		surface.SetDrawColor(100, 100, 100)
		surface.DrawOutlinedRect(s.stripX1, s.stripY, s.stripX2 - s.stripX1, s.stripH)
		draw.SimpleText("SKIM", "DermaDefaultBold", (s.stripX1 + s.stripX2) * 0.5, s.stripY + s.stripH + 16, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end,
	onCursorMoved = function(s, x, y)
		if (y >= s.stripY and y <= s.stripY + s.stripH) then
			if (!s.entered and x <= s.stripX1 + (s.stripX2 - s.stripX1) * 0.25) then
				s.entered = true
			end
			if (s.entered and x > s.maxX) then
				s.maxX = x
			end
			if (s.entered and s.maxX >= s.stripX2 - (s.stripX2 - s.stripX1) * 0.1) then
				s.succeeded = true
				s.done = true
			end
		end
	end,
}

-- POKE: click and hold for 1.5 seconds.
INTER.poke = {
	label = "POKE",
	init = function(s, w, h)
		s.cx, s.cy = w * 0.5, h * 0.5
		s.holding  = false
		s.holdStart = 0
		s.holdTime  = 1.5
	end,
	paint = function(s, w, h)
		local elapsed = s.holding and (RealTime() - s.holdStart) or 0
		local fill    = math.Clamp(elapsed / s.holdTime, 0, 1)
		-- meat shape
		surface.SetDrawColor(160, 80, 60)
		surface.DrawRect(s.cx - 45, s.cy - 25, 90, 50)
		-- juice color changes as probe fills
		local r = math.floor(160 + fill * 80)
		local g = math.floor(80 - fill * 30)
		surface.SetDrawColor(r, g, 60, 200)
		surface.DrawRect(s.cx - 43, s.cy - 23, math.floor(86 * fill), 46)
		-- probe indicator
		draw.SimpleText("POKE", "DermaDefaultBold", s.cx, s.cy + 38, s.holding and Color(255, 220, 80) or Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end,
	onMouseDown = function(s, x, y)
		s.holding   = true
		s.holdStart = RealTime()
	end,
	onMouseUp = function(s)
		if (s.holding) then
			if (RealTime() - s.holdStart >= s.holdTime) then
				s.succeeded = true
				s.done = true
			end
		end
		s.holding = false
	end,
	think = function(s)
		if (s.holding and RealTime() - s.holdStart >= s.holdTime) then
			s.succeeded = true
			s.done = true
		end
	end,
}

-- TURN: drag mouse left/right to rotate handle into the green arc zone.
INTER.turn = {
	label = "TURN",
	init = function(s, w, h)
		s.cx, s.cy  = w * 0.5, h * 0.5
		s.radius    = math.min(w, h) * 0.3
		-- green zone: 45°–135° (top arc, mapped from 0=right, going counter-clockwise)
		s.greenMin  = math.rad(45)
		s.greenMax  = math.rad(135)
		s.angle     = math.rad(270)  -- start at bottom
		s.dragging  = false
		s.lastX     = 0
	end,
	paint = function(s, w, h)
		-- draw arc background
		surface.SetDrawColor(50, 50, 50)
		surface.DrawRect(s.cx - s.radius, s.cy - s.radius, s.radius * 2, s.radius * 2)

		-- green zone indicator (approximate with rect segments)
		surface.SetDrawColor(0, 120, 0, 100)
		surface.DrawRect(s.cx - s.radius + 4, s.cy - s.radius + 4, s.radius * 2 - 8, s.radius * 0.6)

		-- handle dot at current angle
		local hx = s.cx + math.cos(s.angle) * (s.radius - 10)
		local hy = s.cy + math.sin(s.angle) * (s.radius - 10)
		local inZone = (s.angle >= s.greenMin and s.angle <= s.greenMax)
		surface.SetDrawColor(inZone and Color(80, 255, 80) or Color(255, 200, 80))
		surface.DrawRect(hx - 8, hy - 8, 16, 16)

		draw.SimpleText("TURN", "DermaDefaultBold", s.cx, s.cy + s.radius + 8, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end,
	onMouseDown = function(s, x, y)
		s.dragging = true
		s.lastX = x
	end,
	onMouseUp = function(s)
		if (s.dragging) then
			local inZone = (s.angle >= s.greenMin and s.angle <= s.greenMax)
			if (inZone) then
				s.succeeded = true
				s.done = true
			end
		end
		s.dragging = false
	end,
	onCursorMoved = function(s, x, y)
		if (!s.dragging) then return end
		local dx = x - s.lastX
		s.angle  = s.angle + dx * 0.025
		-- clamp to 0..2pi
		s.angle  = s.angle % (math.pi * 2)
		s.lastX  = x
	end,
}

-- ──────────────────────────────────────────────────────────────────────────────
-- Recipe picker
-- ──────────────────────────────────────────────────────────────────────────────

netstream.Hook("CookingOpen", function(entIndex, cookType, recipes)
	if (IsValid(ix.gui.cookingPicker)) then ix.gui.cookingPicker:Remove() end

	local frame = vgui.Create("DFrame")
	ix.gui.cookingPicker = frame
	frame:SetSize(300, 60 + #recipes * 36)
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("Prepare food")
	frame:SetDraggable(false)

	for i, recipe in ipairs(recipes) do
		local btn = vgui.Create("DButton", frame)
		btn:SetPos(10, 28 + (i - 1) * 36)
		btn:SetSize(280, 30)
		btn:SetText(recipe.name)
		btn.DoClick = function()
			netstream.Start("CookingStart", entIndex, recipe.id)
			frame:Remove()
		end
	end
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- Minigame frame
-- ──────────────────────────────────────────────────────────────────────────────

netstream.Hook("CookingMinigame", function(entIndex, interactions, cookTime)
	if (IsValid(ix.gui.cookingMinigame)) then ix.gui.cookingMinigame:Remove() end

	local PW, PH = 320, 240

	local frame = vgui.Create("DFrame")
	ix.gui.cookingMinigame = frame
	frame:SetSize(PW, PH)
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("")
	frame:SetDraggable(false)
	frame:ShowCloseButton(false)

	local stepCount  = #interactions
	local stepTime   = math.max(5, math.floor(cookTime / stepCount))
	local stepIdx    = 1
	local successes  = 0
	local stepState  = {}
	local stepStart  = RealTime()
	local finished   = false

	local iPanel = vgui.Create("DPanel", frame)
	iPanel:SetPos(0, 20)
	iPanel:SetSize(PW, PH - 40)
	iPanel:SetMouseInputEnabled(true)

	local function loadStep(idx)
		stepState  = {}
		stepStart  = RealTime()
		local def  = INTER[interactions[idx]]
		if (def and def.init) then
			def.init(stepState, PW, PH - 40)
		end
	end

	local function finishMinigame()
		if (finished) then return end
		finished = true
		local quality = (stepCount > 0) and (successes / stepCount) or 1
		netstream.Start("CookingQuality", entIndex, quality)
		timer.Simple(0.5, function()
			if (IsValid(frame)) then frame:Remove() end
		end)
	end

	local function advanceStep(succeeded)
		if (succeeded) then successes = successes + 1 end
		stepIdx = stepIdx + 1
		if (stepIdx > stepCount) then
			finishMinigame()
		else
			loadStep(stepIdx)
		end
	end

	iPanel.Paint = function(self, w, h)
		surface.SetDrawColor(25, 22, 18)
		surface.DrawRect(0, 0, w, h)

		local def = INTER[interactions[stepIdx]]
		if (!def) then return end

		def.paint(stepState, w, h)

		-- Action label at top
		draw.SimpleText(def.label, "DermaDefaultBold", w * 0.5, 10, Color(255, 240, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	iPanel.Think = function(self)
		if (finished) then return end
		local def = INTER[interactions[stepIdx]]
		if (def and def.think) then
			def.think(stepState)
		end
		if (stepState.done) then
			advanceStep(stepState.succeeded == true)
		elseif (RealTime() - stepStart >= stepTime) then
			advanceStep(false)
		end
	end

	iPanel.OnMousePressed = function(self, mcode)
		if (mcode != MOUSE_LEFT) then return end
		local x, y = self:CursorPos()
		local def   = INTER[interactions[stepIdx]]
		if (def and def.onMouseDown) then def.onMouseDown(stepState, x, y) end
	end

	iPanel.OnMouseReleased = function(self, mcode)
		if (mcode != MOUSE_LEFT) then return end
		local def = INTER[interactions[stepIdx]]
		if (def and def.onMouseUp) then def.onMouseUp(stepState) end
		if (stepState.done) then advanceStep(stepState.succeeded == true) end
	end

	iPanel.OnCursorMoved = function(self, x, y)
		local def = INTER[interactions[stepIdx]]
		if (def and def.onCursorMoved) then def.onCursorMoved(stepState, x, y) end
		if (stepState.done) then advanceStep(stepState.succeeded == true) end
	end

	-- Cook-time safety: server timer fires regardless; close panel after cookTime + 3s buffer
	timer.Simple(cookTime + 3, function()
		finishMinigame()
	end)

	loadStep(stepIdx)
end)
