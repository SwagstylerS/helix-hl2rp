-- Infrastructure degradation system
-- Tracks breakable entities and periodically degrades them

PLUGIN.BreakableTypes = {
	["ix_breakable_light"] = {chance = 15, priority = 1, type = "light"},
	["ix_breakable_door"] = {chance = 5, priority = 3, type = "door"},
	["ix_breakable_terminal"] = {chance = 8, priority = 3, type = "terminal"},
	["ix_breakable_pipe"] = {chance = 12, priority = 1, type = "pipe"}
}

function PLUGIN:StartDegradationTimer()
	timer.Create("CWUDegradation", ix.config.Get("cwuDegradationInterval", 300), 0, function()
		self:RunDegradationTick()
	end)
end

function PLUGIN:StopDegradationTimer()
	timer.Remove("CWUDegradation")
end

function PLUGIN:RunDegradationTick()
	for class, info in pairs(self.BreakableTypes) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			if (IsValid(entity) and !entity:GetBroken()) then
				if (math.random(1, 100) <= info.chance) then
					entity:SetBroken(true)
					entity:SetBreakTime(CurTime())
					entity:OnBreak()

					self:GenerateWorkOrder(entity)
				end
			end
		end
	end
end
