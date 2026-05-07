PLUGIN.name = "Checkpoint Forcefield"
PLUGIN.description = "Combine energy wall checkpoint with clearance states, warrant detection, and HL2-style visuals."
PLUGIN.author = "ixhl2rp"

if SERVER then
	function Schema.SaveCheckpoints()
		local data = {}

		for _, ent in ipairs(ents.FindByClass("ix_checkpoint")) do
			if IsValid(ent) then
				local pos = ent:GetPos()
				local ang = ent:GetAngles()

				data[#data + 1] = {
					pos = {x = pos.x, y = pos.y, z = pos.z},
					angles = {p = ang.p, y = ang.y, r = ang.r},
					name = ent:GetCheckpointName(),
					mode = ent:GetMode()
				}
			end
		end

		ix.data.Set("ix_checkpoints_" .. game.GetMap(), data)
	end

	function Schema.LoadCheckpoints()
		local saved = ix.data.Get("ix_checkpoints_" .. game.GetMap(), {})

		for _, entry in ipairs(saved) do
			local ent = ents.Create("ix_checkpoint")
			ent.ixIsSafe = true
			ent:SetPos(Vector(entry.pos.x, entry.pos.y, entry.pos.z))
			ent:SetAngles(Angle(entry.angles.p, entry.angles.y, entry.angles.r))
			ent:Spawn()
			ent:Activate()
			ent:SetCheckpointName(entry.name)
			ent:SetMode(entry.mode)
		end
	end

	hook.Add("InitPostEntity", "ix_checkpoint_load", function()
		timer.Simple(1, Schema.LoadCheckpoints)
	end)
end
