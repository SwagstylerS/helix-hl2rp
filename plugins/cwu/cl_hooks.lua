-- Client-side CWU hooks

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
