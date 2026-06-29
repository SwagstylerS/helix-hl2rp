
function Schema:AddCombineDisplayMessage(text, color, ...)
	if (LocalPlayer():IsCombine() and IsValid(ix.gui.combine)) then
		ix.gui.combine:AddLine(text, color, nil, ...)
	end
end

netstream.Hook("PirateRadioBroadcastPrompt", function()
	Derma_StringRequest("Open Frequency", "Transmit on open frequency:", "", function(text)
		if (#text > 0) then
			netstream.Start("PirateRadioBroadcast", text)
		end
	end)
end)
