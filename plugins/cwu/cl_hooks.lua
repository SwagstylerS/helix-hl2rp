-- Client-side CWU hooks

CWU_LocalTier = 0
CWU_LocalPoints = 0

local tierUpData = nil
local tierUpAt = 0

local newOrderData = nil
local newOrderAt = 0

netstream.Hook("CWULoyaltySync", function(data)
	CWU_LocalTier = data.tier
	CWU_LocalPoints = data.points
end)

netstream.Hook("CWUTierUpAnnounce", function(data)
	tierUpData = data
	tierUpAt = CurTime()
end)

netstream.Hook("CWUNewWorkOrder", function(data)
	newOrderData = data
	newOrderAt = CurTime()
end)

hook.Add("HUDPaint", "CWU_TierBadge", function()
	local ply = LocalPlayer()

	if (!IsValid(ply) or !ply:IsCWU()) then return end

	local tierInfo = PLUGIN.LoyaltyTiers[CWU_LocalTier]

	if (!tierInfo) then return end

	draw.SimpleText(
		tierInfo.name .. "  [Tier " .. CWU_LocalTier .. "]",
		"DermaDefault",
		10,
		ScrH() - 20,
		tierInfo.color,
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_BOTTOM
	)

	local barX = 10
	local barY = ScrH() - 8
	local barW = 160
	local barH = 4
	local fillRatio = (CWU_LocalPoints % 10) / 10

	surface.SetDrawColor(40, 40, 40)
	surface.DrawRect(barX, barY, barW, barH)
	surface.SetDrawColor(100, 175, 100)
	surface.DrawRect(barX, barY, math.floor(barW * fillRatio), barH)

	if (tierUpData == nil) then return end

	local elapsed = CurTime() - tierUpAt

	if (elapsed >= 5) then
		tierUpData = nil
		return
	end

	local alpha = 255
	if (elapsed > 4) then
		alpha = math.floor(255 * (1 - (elapsed - 4)))
	end

	local panelW = 360
	local panelH = 60
	local panelX = ScrW() / 2 - panelW / 2
	local panelY = ScrH() / 2 - 80 - panelH / 2

	surface.SetDrawColor(20, 20, 20, math.floor(200 * alpha / 255))
	surface.DrawRect(panelX, panelY, panelW, panelH)

	surface.SetDrawColor(tierUpData.r, tierUpData.g, tierUpData.b, alpha)
	surface.DrawRect(panelX, panelY, panelW, 2)
	surface.DrawRect(panelX, panelY + panelH - 2, panelW, 2)
	surface.DrawRect(panelX, panelY, 2, panelH)
	surface.DrawRect(panelX + panelW - 2, panelY, 2, panelH)

	draw.SimpleText(
		"TIER ADVANCEMENT",
		"DermaDefault",
		ScrW() / 2,
		panelY + 14,
		Color(255, 255, 255, alpha),
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)

	draw.SimpleText(
		tierUpData.name .. " [Tier " .. tierUpData.tier .. "]",
		"DermaDefault",
		ScrW() / 2,
		panelY + 38,
		Color(tierUpData.r, tierUpData.g, tierUpData.b, alpha),
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)
end)

netstream.Hook("CWURecreationalEffect", function(duration)
	PLUGIN.ChemEffectEnd = CurTime() + duration
end)

function PLUGIN:HUDPaint()
	if (PLUGIN.ChemEffectEnd) then
		if (CurTime() < PLUGIN.ChemEffectEnd) then
			DrawMotionBlur(0.06, 0.6, 1/60)
			surface.SetDrawColor(40, 200, 80, 30)
			surface.DrawRect(0, 0, ScrW(), ScrH())
		else
			PLUGIN.ChemEffectEnd = nil
		end
	end

	if (newOrderData != nil) then
		local elapsed = CurTime() - newOrderAt

		if (elapsed >= 6) then
			newOrderData = nil
		elseif (LocalPlayer():GetCWUDivision() == "maintenance") then
			local alpha = 255

			if (elapsed > 5) then
				alpha = math.floor(255 * (1 - (elapsed - 5)))
			end

			local panelW, panelH = 320, 48
			local panelX = ScrW() / 2 - panelW / 2
			local panelY = ScrH() - 130

			surface.SetDrawColor(20, 20, 20, math.floor(210 * alpha / 255))
			surface.DrawRect(panelX, panelY, panelW, panelH)

			surface.SetDrawColor(100, 175, 100, alpha)
			surface.DrawRect(panelX, panelY, panelW, 2)
			surface.DrawRect(panelX, panelY + panelH - 2, panelW, 2)
			surface.DrawRect(panelX, panelY, 2, panelH)
			surface.DrawRect(panelX + panelW - 2, panelY, 2, panelH)

			draw.SimpleText(
				"NEW WORK ORDER",
				"DermaDefault",
				ScrW() / 2,
				panelY + 14,
				Color(255, 255, 255, alpha),
				TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER
			)

			draw.SimpleText(
				"[" .. (newOrderData.type or "?") .. "] — " .. (newOrderData.location or "?"),
				"DermaDefault",
				ScrW() / 2,
				panelY + 34,
				Color(100, 175, 100, alpha),
				TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER
			)
		end
	end
end

function PLUGIN:CreateCharacterInfo(panel)
	if (LocalPlayer():IsCWU()) then
		panel.cwuDivision = panel:Add("DLabel")
		panel.cwuDivision:SetFont("ixSmallFont")
		panel.cwuDivision:Dock(TOP)
		panel.cwuDivision:DockMargin(0, 0, 0, 0)
		panel.cwuDivision:SetTextColor(Color(100, 175, 100))

		panel.cwuTier = panel:Add("DLabel")
		panel.cwuTier:SetFont("ixSmallFont")
		panel.cwuTier:Dock(TOP)
		panel.cwuTier:DockMargin(0, 0, 0, 0)
	end
end

function PLUGIN:UpdateCharacterInfo(panel)
	if (IsValid(panel.cwuDivision)) then
		local division = LocalPlayer():GetCWUDivision()

		if (division) then
			panel.cwuDivision:SetText("CWU: " .. division:sub(1, 1):upper() .. division:sub(2))
			panel.cwuDivision:SizeToContents()
		end
	end

	if (IsValid(panel.cwuTier)) then
		local character = LocalPlayer():GetCharacter()

		if (character) then
			local tier = character:GetData("loyaltyTier", 0)
			local tierInfo = PLUGIN.LoyaltyTiers[tier]

			if (tierInfo) then
				panel.cwuTier:SetText("Loyalty: " .. tierInfo.name)
				panel.cwuTier:SetTextColor(tierInfo.color)
				panel.cwuTier:SizeToContents()
			end
		end
	end
end
