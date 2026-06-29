
ITEM.name = "Pirate Radio"
ITEM.description = "A modified portable radio unit capable of broadcasting on open frequencies."
ITEM.model = Model("models/props_lab/radio_on.mdl")
ITEM.cost = 0
ITEM.width = 2
ITEM.height = 1

if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		if (item:GetData("active", false)) then
			surface.SetDrawColor(110, 255, 110, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end
	end
end

ITEM.functions.Toggle = {
	OnRun = function(itemTable)
		local client = itemTable.player
		local active = !itemTable:GetData("active", false)
		itemTable:SetData("active", active)
		client:NotifyLocalized(active and "pirateRadioOn" or "pirateRadioOff")
		return false
	end
}

ITEM.functions.Broadcast = {
	OnRun = function(itemTable)
		local client = itemTable.player
		if (!itemTable:GetData("active", false)) then
			client:NotifyLocalized("pirateRadioOff")
			return false
		end
		netstream.Start(client, "PirateRadioBroadcastPrompt", {})
		return false
	end
}
