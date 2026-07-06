
ITEM.name = "Lock Pick Set"
ITEM.description = "A compact set of picks and tension wrenches for manipulating mechanical locks."
ITEM.model = Model("models/props_junk/PopCan01a.mdl")
ITEM.cost = 0
ITEM.width = 1
ITEM.height = 1

ITEM.functions.Use = {
	OnRun = function(itemTable)
		local client = itemTable.player
		local trace = client:GetEyeTrace()
		local lock = trace.Entity

		if (!IsValid(lock) or lock:GetClass() != "ix_combinelock" or !lock:GetLocked() or client:GetPos():Distance(lock:GetPos()) > 96) then
			client:NotifyLocalized("lockpickNone")
			return false
		end

		local sid = client:SteamID()
		local roll = math.random()

		if (roll < 0.6) then
			lock:PickLock(client)
			if (CS and CS.AddHeat) then CS.AddHeat(sid, 15) end
		elseif (roll < 0.8) then
			lock:EmitSound("buttons/combine_button_locked.wav")
			if (CS and CS.AddHeat) then CS.AddHeat(sid, 15) end
		else
			lock:EmitSound("buttons/button9.wav")
		end

		return false
	end
}
