local PANEL = {}

function PANEL:Init()
	self:SetSize(400, 380)
	self:Center()
	self:MakePopup()
	self:SetTitle("CWU Medical Workstation")
end

function PANEL:SetData(entIndex, data)
	self.entIndex = entIndex

	-- Treatment section
	local treatLabel = vgui.Create("DLabel", self)
	treatLabel:Dock(TOP)
	treatLabel:DockMargin(5, 5, 5, 2)
	treatLabel:SetText("TREATMENT")
	treatLabel:SetFont("DermaDefaultBold")
	treatLabel:SetTextColor(Color(100, 150, 255))
	treatLabel:SizeToContents()

	-- Patient selector
	local patientBar = vgui.Create("DPanel", self)
	patientBar:Dock(TOP)
	patientBar:SetTall(25)
	patientBar:DockMargin(5, 2, 5, 2)
	patientBar.Paint = nil

	local patientLabel = vgui.Create("DLabel", patientBar)
	patientLabel:Dock(LEFT)
	patientLabel:SetWide(60)
	patientLabel:SetText("Patient:")
	patientLabel:SetTextColor(Color(200, 200, 200))

	self.patientCombo = vgui.Create("DComboBox", patientBar)
	self.patientCombo:Dock(FILL)

	-- Populate nearby players
	for _, v in ipairs(player.GetAll()) do
		if (v != LocalPlayer() and v:GetPos():Distance(LocalPlayer():GetPos()) < 300) then
			local name = v:GetCharacter() and v:GetCharacter():GetName() or v:Name()
			self.patientCombo:AddChoice(name, v:SteamID64())
		end
	end

	self.patientCombo:SetValue("Select Patient")

	-- Basic treatment button
	local basicBtn = vgui.Create("DButton", self)
	basicBtn:Dock(TOP)
	basicBtn:DockMargin(5, 2, 5, 2)
	basicBtn:SetTall(28)
	basicBtn:SetText("Basic Treatment (Bandaging - heals 25 HP)")
	basicBtn.DoClick = function()
		local _, steamID = self.patientCombo:GetSelected()

		if (!steamID) then
			Derma_Message("Select a patient first.", "Error", "OK")
			return
		end

		netstream.Start("CWUMedicalTreatBasic", self.entIndex, steamID)
		self:Remove()
	end

	-- Advanced surgery button
	local surgeryBtn = vgui.Create("DButton", self)
	surgeryBtn:Dock(TOP)
	surgeryBtn:DockMargin(5, 0, 5, 2)
	surgeryBtn:SetTall(28)
	surgeryBtn:SetText("Surgery (Full heal - requires training + stimpak)")
	surgeryBtn:SetEnabled(data.hasMedicalTraining and data.hasStimpak)
	surgeryBtn.DoClick = function()
		local _, steamID = self.patientCombo:GetSelected()

		if (!steamID) then
			Derma_Message("Select a patient first.", "Error", "OK")
			return
		end

		netstream.Start("CWUMedicalSurgery", self.entIndex, steamID)
		self:Remove()
	end

	-- Divider
	local divider = vgui.Create("DPanel", self)
	divider:Dock(TOP)
	divider:SetTall(2)
	divider:DockMargin(5, 5, 5, 5)
	divider.Paint = function(pnl, w, h)
		surface.SetDrawColor(60, 60, 60)
		surface.DrawRect(0, 0, w, h)
	end

	-- Synthesis section
	local synthLabel = vgui.Create("DLabel", self)
	synthLabel:Dock(TOP)
	synthLabel:DockMargin(5, 2, 5, 2)
	synthLabel:SetText("CHEMICAL SYNTHESIS")
	synthLabel:SetFont("DermaDefaultBold")
	synthLabel:SetTextColor(Color(200, 100, 255))
	synthLabel:SizeToContents()

	-- Medicine synthesis
	local medSynthBtn = vgui.Create("DButton", self)
	medSynthBtn:Dock(TOP)
	medSynthBtn:DockMargin(5, 2, 5, 2)
	medSynthBtn:SetTall(28)
	medSynthBtn:SetText("Synthesize Medical Stimpak (2x Chemical Base + 1x Herbs)")
	medSynthBtn:SetEnabled(data.hasChemBase and data.hasHerbs)
	medSynthBtn.DoClick = function()
		netstream.Start("CWUMedicalSynthMedicine", self.entIndex)
		self:Remove()
	end

	-- Illicit synthesis (same UI, different output - the dual-use tension)
	local combatBtn = vgui.Create("DButton", self)
	combatBtn:Dock(TOP)
	combatBtn:DockMargin(5, 0, 5, 2)
	combatBtn:SetTall(28)
	combatBtn:SetText("Synthesize Compound A (2x Chemical Base)")
	combatBtn:SetEnabled(data.hasChemBase)
	combatBtn.DoClick = function()
		netstream.Start("CWUMedicalSynthDrug", self.entIndex, "combat")
		self:Remove()
	end

	local recBtn = vgui.Create("DButton", self)
	recBtn:Dock(TOP)
	recBtn:DockMargin(5, 0, 5, 2)
	recBtn:SetTall(28)
	recBtn:SetText("Synthesize Compound B (2x Chemical Base)")
	recBtn:SetEnabled(data.hasChemBase)
	recBtn.DoClick = function()
		netstream.Start("CWUMedicalSynthDrug", self.entIndex, "recreational")
		self:Remove()
	end

	-- Note about dual-use
	local note = vgui.Create("DLabel", self)
	note:Dock(BOTTOM)
	note:DockMargin(5, 2, 5, 5)
	note:SetText("All synthesis outputs are logged as 'Medical Compound'.")
	note:SetTextColor(Color(150, 150, 150))
	note:SizeToContents()
end

vgui.Register("ixCWUMedicalWorkstation", PANEL, "DFrame")

netstream.Hook("CWUMedicalOpen", function(entIndex, data)
	if (IsValid(ix.gui.cwuMedical)) then
		ix.gui.cwuMedical:Remove()
	end

	ix.gui.cwuMedical = vgui.Create("ixCWUMedicalWorkstation")
	ix.gui.cwuMedical:SetData(entIndex, data)
end)

-- Recreational chemical screen effect
netstream.Hook("CWURecreationalEffect", function(duration)
	local endTime = CurTime() + duration

	hook.Add("RenderScreenspaceEffects", "CWURecreational", function()
		if (CurTime() > endTime) then
			hook.Remove("RenderScreenspaceEffects", "CWURecreational")
			return
		end

		local intensity = math.max(0, (endTime - CurTime()) / duration)

		DrawMotionBlur(0.1, intensity * 0.8, 0.01)
		DrawColorModify({
			["$pp_colour_brightness"] = 0.05 * intensity,
			["$pp_colour_contrast"] = 1 + 0.2 * intensity,
			["$pp_colour_colour"] = 1 + 0.5 * intensity * math.sin(CurTime() * 2),
			["$pp_colour_addr"] = 0.02 * intensity,
			["$pp_colour_addg"] = 0,
			["$pp_colour_addb"] = 0.02 * intensity,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0
		})
	end)
end)
