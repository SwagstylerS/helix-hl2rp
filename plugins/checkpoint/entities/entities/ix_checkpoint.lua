
AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Checkpoint"
ENT.Category = "HL2RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.bNoPersist = true

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Mode")
	self:NetworkVar("Int", 1, "Health")
	self:NetworkVar("Bool", 0, "Alarm")
	self:NetworkVar("Bool", 1, "Disabled")
	self:NetworkVar("Entity", 0, "Dummy")
	self:NetworkVar("String", 0, "CheckpointName")
end

local MODE_GREEN = 1
local MODE_YELLOW = 2
local MODE_RED = 3
local MAX_HEALTH = 1000
local REBOOT_TIME = 900 -- 15 minutes

local MODE_NAMES = {
	[MODE_GREEN] = "GREEN — Open to all.",
	[MODE_YELLOW] = "YELLOW — CWU / CP / OTA only.",
	[MODE_RED] = "RED — CP / OTA only."
}

-- Returns true if the player has clearance for the given mode.
local function HasClearance(client, mode)
	if (client:IsCombine() or client:Team() == FACTION_ADMIN) then
		return true
	end

	if (mode == MODE_GREEN) then
		return true
	end

	if (mode == MODE_YELLOW) then
		if (client:Team() == FACTION_CWU) then
			return true
		end
	end

	return false
end

-- Warrant detection with 3 fallback methods.
local function CheckWarrant(client)
	-- Method 1: Custom hook for external integration.
	local hookResult = hook.Run("HelixCheckWarrant", client)

	if (hookResult == true) then
		return true
	end

	-- Method 2: Check combine-terminal warrant data directly.
	local warrants = ix.data.Get("cs_warrants", {})

	if (warrants[client:SteamID()]) then
		return true
	end

	-- Method 3: Generic character data fallback.
	local character = client:GetCharacter()

	if (character and character:GetData("warrant")) then
		return true
	end

	return false
end

-- Context menu property: Set Checkpoint Name (admin only).
-- Must be in shared scope so client registers the menu and server receives it.
properties.Add("checkpoint_setname", {
	MenuLabel = "Set Checkpoint Name",
	Order = 401,
	MenuIcon = "icon16/tag_blue_edit.png",

	Filter = function(self, entity, client)
		if (!IsValid(entity)) then return false end
		if (entity:GetClass() != "ix_checkpoint") then return false end
		if (!client:IsAdmin()) then return false end

		return true
	end,

	Action = function(self, entity)
		Derma_StringRequest(
			"Set Checkpoint Name",
			"Enter a name for this checkpoint:",
			entity:GetCheckpointName() or "",
			function(text)
				self:MsgStart()
					net.WriteEntity(entity)
					net.WriteString(text)
				self:MsgEnd()
			end
		)
	end,

	Receive = function(self, length, client)
		local entity = net.ReadEntity()
		local name = net.ReadString()

		if (!IsValid(entity)) then return end
		if (entity:GetClass() != "ix_checkpoint") then return end
		if (!client:IsAdmin()) then return end

		name = string.sub(name, 1, 32)

		if (name == "") then
			name = "Checkpoint"
		end

		entity:SetCheckpointName(name)
		client:ChatPrint("Checkpoint renamed to: " .. name)

		Schema:SaveCheckpoints()
	end
})

if (SERVER) then
	function ENT:PhysgunPickup()
		return false
	end

	function ENT:SpawnFunction(client, trace)
		local angles = (client:GetPos() - trace.HitPos):Angle()
		angles.p = 0
		angles.r = 0
		angles:RotateAroundAxis(angles:Up(), 270)

		local entity = ents.Create("ix_checkpoint")
		entity:SetPos(trace.HitPos + Vector(0, 0, 40))
		entity:SetAngles(angles:SnapTo("y", 90))
		entity:Spawn()
		entity:Activate()

		Schema:SaveCheckpoints()
		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/props_combine/combine_fence01b.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local data = {}
			data.start = self:GetPos() + self:GetRight() * -16
			data.endpos = self:GetPos() + self:GetRight() * -480
			data.filter = self
		local trace = util.TraceLine(data)

		self.dummy = ents.Create("prop_physics")
		self.dummy:SetModel("models/props_combine/combine_fence01a.mdl")
		self.dummy:SetPos(trace.HitPos)
		self.dummy:SetAngles(self:GetAngles())
		self.dummy:Spawn()
		self.dummy.PhysgunDisabled = true
		self:DeleteOnRemove(self.dummy)

		-- Forward damage from the dummy post to this entity.
		local checkpoint = self

		self.dummy.OnTakeDamage = function(dummy, dmgInfo)
			if (IsValid(checkpoint)) then
				checkpoint:OnTakeDamage(dmgInfo)
			end
		end

		local dummyLocal = self:WorldToLocal(self.dummy:GetPos())
		local fwd = self:GetForward() * 4
		local fwdLocal = self:WorldToLocal(self:GetPos() + fwd) -- offset along forward axis

		local verts = {
			Vector(0, 0, -25) + fwdLocal,
			Vector(0, 0, -25) - fwdLocal,
			Vector(0, 0, 150) + fwdLocal,
			Vector(0, 0, 150) - fwdLocal,
			dummyLocal + Vector(0, 0, -25) + fwdLocal,
			dummyLocal + Vector(0, 0, -25) - fwdLocal,
			dummyLocal + Vector(0, 0, 150) + fwdLocal,
			dummyLocal + Vector(0, 0, 150) - fwdLocal,
		}

		self:PhysicsInitConvex(verts)

		local physObj = self:GetPhysicsObject()

		if (IsValid(physObj)) then
			physObj:EnableMotion(false)
			physObj:Sleep()
		end

		self:SetCustomCollisionCheck(true)
		self:EnableCustomCollisions(true)
		self:SetDummy(self.dummy)

		physObj = self.dummy:GetPhysicsObject()

		if (IsValid(physObj)) then
			physObj:EnableMotion(false)
			physObj:Sleep()
		end

		self:SetMoveType(MOVETYPE_NOCLIP)
		self:SetMoveType(MOVETYPE_PUSH)
		self:MakePhysicsObjectAShadow()
		self:SetMode(MODE_GREEN)
		self:SetAlarm(false)
		self:SetDisabled(false)
		self:SetHealth(MAX_HEALTH)

		if (self:GetCheckpointName() == "") then
			self:SetCheckpointName("Checkpoint")
		end
	end

	function ENT:OnTakeDamage(dmgInfo)
		if (self:GetDisabled()) then
			return
		end

		local damage = dmgInfo:GetDamage()
		local newHP = self:GetHealth() - damage

		if (newHP <= 0) then
			self:DisableCheckpoint()
		else
			self:SetHealth(newHP)
		end
	end

	function ENT:DisableCheckpoint()
		self:SetDisabled(true)
		self:SetHealth(0)
		self:EmitSound("ambient/energy/spark6.wav", 100, 80)
		self:EmitSound("npc/turret_floor/die.wav", 100, 70)

		local name = self:GetCheckpointName()

		-- Alert Combine.
		for _, ply in ipairs(player.GetAll()) do
			if (ply:IsCombine()) then
				ply:ChatPrint("[CHECKPOINT] " .. name .. " has been DESTROYED and is offline.")
			end
		end



		local logLine = os.date("[%Y-%m-%d %H:%M:%S] ") .. "[CHECKPOINT] " .. name .. " destroyed.\n"
		file.Append("ixhl2rp_checkpoint_log.txt", logLine)

		-- Auto-reboot after 15 minutes.
		local entIndex = self:EntIndex()

		timer.Create("ix_checkpoint_reboot_" .. entIndex, REBOOT_TIME, 1, function()
			if (IsValid(self)) then
				self:RebootCheckpoint()
			end
		end)
	end

	function ENT:RebootCheckpoint()
		self:SetDisabled(false)
		self:SetHealth(MAX_HEALTH)
		self:SetMode(MODE_GREEN)
		self:EmitSound("buttons/combine_button7.wav", 100, 100)

		local name = self:GetCheckpointName()

		for _, ply in ipairs(player.GetAll()) do
			if (ply:IsCombine()) then
				ply:ChatPrint("[CHECKPOINT] " .. name .. " is back ONLINE.")
			end
		end

	end

	-- Returns the midpoint of the checkpoint wall.
	function ENT:GetMidpoint()
		local dummy = self:GetDummy()

		if (IsValid(dummy)) then
			return (self:GetPos() + dummy:GetPos()) / 2
		end

		return self:GetPos()
	end

	-- Returns the detection radius (half the wall length + buffer).
	function ENT:GetDetectionRadius()
		local dummy = self:GetDummy()

		if (IsValid(dummy)) then
			return self:GetPos():Distance(dummy:GetPos()) / 2 + 80
		end

		return 300
	end

	function ENT:StartTouch(entity)
		if (self:GetDisabled()) then
			return
		end

		if (!self.buzzer) then
			self.buzzer = CreateSound(entity, "ambient/machines/combine_shield_touch_loop1.wav")
			self.buzzer:Play()
			self.buzzer:ChangeVolume(0.8, 0)
		else
			self.buzzer:ChangeVolume(0.8, 0.5)
			self.buzzer:Play()
		end

		self.entities = (self.entities or 0) + 1

		-- Handle blocking for players.
		if (entity:IsPlayer() and IsValid(entity)) then
			local mode = self:GetMode() or MODE_GREEN

			if (!HasClearance(entity, mode)) then
				local dir = (entity:GetPos() - self:GetPos()):GetNormalized()
				entity:SetVelocity(dir * 300)

				if ((entity.ixCheckpointMsg or 0) < CurTime()) then
					entity:ChatPrint("You do not have clearance to pass this checkpoint.")
					entity.ixCheckpointMsg = CurTime() + 3
				end
			end
		end
	end

	function ENT:EndTouch(entity)
		self.entities = math.max((self.entities or 0) - 1, 0)

		if (self.buzzer and self.entities == 0) then
			self.buzzer:FadeOut(0.5)
		end
	end

	-- Think-based proximity warrant scanner (more reliable than StartTouch on custom meshes).
	function ENT:Think()
		if (self:GetDisabled()) then
			self:NextThink(CurTime() + 2)
			return true
		end

		local midpoint = self:GetMidpoint()
		local radius = self:GetDetectionRadius()

		for _, ply in ipairs(player.GetAll()) do
			if (IsValid(ply) and ply:Alive() and !ply:IsCombine() and ply:Team() != FACTION_ADMIN) then
				if (midpoint:DistToSqr(ply:GetPos()) <= radius * radius) then
					if (CheckWarrant(ply)) then
						self:TriggerWarrantAlarm(ply)
					end
				end
			end
		end

		self:NextThink(CurTime() + 1)
		return true
	end

	function ENT:OnRemove()
		if (self.buzzer) then
			self.buzzer:Stop()
			self.buzzer = nil
		end

		if (!ix.shuttingDown and !self.ixIsSafe) then
			Schema:SaveCheckpoints()
		end
	end

	function ENT:Use(activator)
		if (self:GetDisabled()) then
			activator:ChatPrint("This checkpoint is offline. Rebooting...")
			return
		end

		if ((self.nextUse or 0) >= CurTime()) then
			return
		end

		self.nextUse = CurTime() + 1.5

		if (activator:IsCombine() or activator:Team() == FACTION_ADMIN) then
			local newMode = self:GetMode() + 1

			if (newMode > MODE_RED) then
				newMode = MODE_GREEN
			end

			self:SetMode(newMode)
			self:EmitSound("buttons/combine_button5.wav", 140, 100 + (newMode - 1) * 15)

			Schema:SaveCheckpoints()
		else
			self:EmitSound("buttons/combine_button3.wav")
		end
	end

	function ENT:TriggerWarrantAlarm(client)
		-- Prevent alarm spam.
		if (self:GetAlarm()) then
			return
		end

		self:SetAlarm(true)
		self:EmitSound("ambient/alarms/alarm_citizen_loop1.wav", 100, 100)

		local name = client:Name()
		local cpName = self:GetCheckpointName()
		local message = "[CHECKPOINT:" .. cpName .. "] WARRANT DETECTED: " .. name

		-- Alert all online Combine.
		for _, ply in ipairs(player.GetAll()) do
			if (ply:IsCombine()) then
				ply:ChatPrint(message)
			end
		end


		-- Log to file.
		local logLine = os.date("[%Y-%m-%d %H:%M:%S] ") .. message .. "\n"
		file.Append("ixhl2rp_checkpoint_log.txt", logLine)

		-- Reset alarm after 5 seconds.
		local entIndex = self:EntIndex()

		timer.Create("ix_checkpoint_alarm_" .. entIndex, 5, 1, function()
			if (IsValid(self)) then
				self:SetAlarm(false)
				self:StopSound("ambient/alarms/alarm_citizen_loop1.wav")
			end
		end)
	end

	-- Collision filtering for checkpoints.
	hook.Add("ShouldCollide", "ix_checkpoints", function(a, b)
		local client
		local entity

		if (a:IsPlayer()) then
			client = a
			entity = b
		elseif (b:IsPlayer()) then
			client = b
			entity = a
		end

		if (IsValid(entity) and entity:GetClass() == "ix_checkpoint") then
			-- Disabled checkpoints let everyone through.
			if (entity:GetDisabled()) then
				return false
			end

			if (IsValid(client)) then
				local mode = entity:GetMode() or MODE_GREEN

				-- Combine and admins always pass.
				if (client:IsCombine() or client:Team() == FACTION_ADMIN) then
					return false
				end

				-- Warrant holders are always blocked.
				if (CheckWarrant(client)) then
					return true
				end

				return !HasClearance(client, mode)
			else
				return entity:GetMode() != MODE_GREEN
			end
		end
	end)
else
	local SHIELD_MATERIAL = ix.util.GetMaterial("effects/combineshield/comshieldwall3")

	local MODE_COLORS = {
		[MODE_GREEN] = {0, 0.8, 0},
		[MODE_YELLOW] = {0.9, 0.8, 0},
		[MODE_RED] = {0.9, 0, 0}
	}

	local MODE_HUD_TEXT = {
		[MODE_GREEN] = "OPEN",
		[MODE_YELLOW] = "RESTRICTED",
		[MODE_RED] = "LOCKED"
	}

	local MODE_HUD_COLORS = {
		[MODE_GREEN] = Color(50, 200, 50),
		[MODE_YELLOW] = Color(220, 200, 50),
		[MODE_RED] = Color(200, 50, 50)
	}

	function ENT:Initialize()
		self:SetRenderBounds(Vector(-500, -500, -50), Vector(500, 500, 200))

		local data = {}
			data.start = self:GetPos() + self:GetRight() * -16
			data.endpos = self:GetPos() + self:GetRight() * -480
			data.filter = self
		local trace = util.TraceLine(data)

		self:EnableCustomCollisions(true)
		self:PhysicsInitConvex({
			vector_origin,
			Vector(0, 0, 150),
			trace.HitPos + Vector(0, 0, 150),
			trace.HitPos
		})
	end

	function ENT:Draw()
		self:DrawModel()

		-- Don't draw shield when disabled.
		if (self:GetDisabled()) then
			return
		end

		local mode = self:GetMode()

		if (mode == 0) then
			return
		end

		local alarm = self:GetAlarm()
		local color = MODE_COLORS[mode] or MODE_COLORS[MODE_GREEN]

		-- Alarm overrides to flashing red.
		if (alarm) then
			local flash = math.abs(math.sin(CurTime() * 8))
			color = {flash, 0, 0}
		end

		-- Pulse effect.
		local pulse = math.sin(CurTime() * 2) * 0.15 + 0.85

		render.SetColorModulation(color[1] * pulse, color[2] * pulse, color[3] * pulse)
		render.SetMaterial(SHIELD_MATERIAL)

		local angles = self:GetAngles()
		local matrix = Matrix()
		matrix:Translate(self:GetPos() + self:GetUp() * -40)
		matrix:Rotate(angles)

		local dummy = self:GetDummy()

		if (IsValid(dummy)) then
			local vertex = self:WorldToLocal(dummy:GetPos())
			self:SetRenderBounds(vector_origin, vertex + self:GetUp() * 150)

			cam.PushModelMatrix(matrix)
				self:DrawShield(vertex)
			cam.PopModelMatrix()

			matrix:Translate(vertex)
			matrix:Rotate(Angle(0, 180, 0))

			cam.PushModelMatrix(matrix)
				self:DrawShield(vertex)
			cam.PopModelMatrix()
		end

		render.SetColorModulation(1, 1, 1)
	end

	function ENT:DrawShield(vertex)
		mesh.Begin(MATERIAL_QUADS, 1)
			mesh.Position(vector_origin)
			mesh.TexCoord(0, 0, 0)
			mesh.AdvanceVertex()

			mesh.Position(self:GetUp() * 190)
			mesh.TexCoord(0, 0, 3)
			mesh.AdvanceVertex()

			mesh.Position(vertex + self:GetUp() * 190)
			mesh.TexCoord(0, 3, 3)
			mesh.AdvanceVertex()

			mesh.Position(vertex)
			mesh.TexCoord(0, 3, 0)
			mesh.AdvanceVertex()
		mesh.End()
	end

	-- HUD indicator: CP/OTA only, shows when near the checkpoint wall.
	hook.Add("HUDPaint", "ix_checkpoint_hud", function()
		local client = LocalPlayer()

		if (!IsValid(client)) then
			return
		end

		-- Only Combine can see checkpoint status.
		if (!client:IsCombine()) then
			return
		end

		local nearest = nil
		local nearestDist = math.huge

		for _, ent in ipairs(ents.FindByClass("ix_checkpoint")) do
			-- Check distance from the midpoint of the wall, not the post.
			local dummy = ent:GetDummy()
			local midpoint = ent:GetPos()

			if (IsValid(dummy)) then
				midpoint = (ent:GetPos() + dummy:GetPos()) / 2
			end

			local wallHalf = 240
			if (IsValid(dummy)) then
				wallHalf = ent:GetPos():Distance(dummy:GetPos()) / 2
			end

			-- HUD range: half the wall length + ~1 meter (52 units) buffer.
			local maxRange = wallHalf + 52
			local dist = midpoint:DistToSqr(client:GetPos())

			if (dist < maxRange * maxRange and dist < nearestDist) then
				nearest = ent
				nearestDist = dist
			end
		end

		if (!IsValid(nearest)) then
			return
		end

		local mode = nearest:GetMode()
		local alarm = nearest:GetAlarm()
		local disabled = nearest:GetDisabled()
		local cpName = nearest:GetCheckpointName()

		if (cpName == "") then
			cpName = "Checkpoint"
		end

		local text, hudColor

		if (disabled) then
			local flash = math.abs(math.sin(CurTime() * 2))
			text = cpName .. " — OFFLINE"
			hudColor = Color(120 + 80 * flash, 120 + 80 * flash, 120 + 80 * flash, 200)
		elseif (alarm) then
			local flash = math.abs(math.sin(CurTime() * 6))
			text = cpName .. " — WARRANT ALERT"
			hudColor = Color(255 * flash, 0, 0, 200 + 55 * flash)
		else
			local statusText = MODE_HUD_TEXT[mode] or "UNKNOWN"
			text = cpName .. " — " .. statusText
			hudColor = MODE_HUD_COLORS[mode] or MODE_HUD_COLORS[MODE_GREEN]
		end

		local scrW, scrH = ScrW(), ScrH()
		local font = "ixSmallFont"

		surface.SetFont(font)
		local textW, textH = surface.GetTextSize(text)

		local boxW = math.max(textW + 24, 180)
		local boxH = textH + 12
		local boxX = (scrW - boxW) / 2
		local boxY = scrH - 80 - boxH

		-- Background.
		surface.SetDrawColor(20, 20, 20, 180)
		surface.DrawRect(boxX, boxY, boxW, boxH)

		-- Color bar on top.
		surface.SetDrawColor(hudColor)
		surface.DrawRect(boxX, boxY, boxW, 3)

		-- Text.
		draw.SimpleText(text, font, scrW / 2, boxY + boxH / 2, hudColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end)
end
