
AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Forcefield"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.PhysgunDisabled = true
ENT.bNoPersist = true

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Mode")
	self:NetworkVar("Int", 1, "FieldHealth")
	self:NetworkVar("Entity", 0, "Dummy")
	self:NetworkVar("Bool", 0, "Disabled")
	self:NetworkVar("String", 0, "FieldName")
end

properties.Add("forcefield_setname", {
	MenuLabel = "Set Forcefield Name",
	Order = 401,
	MenuIcon = "icon16/tag_blue_edit.png",

	Filter = function(self, entity, client)
		if (!IsValid(entity)) then return false end
		if (entity:GetClass() != "ix_forcefield") then return false end
		if (!client:IsAdmin()) then return false end

		return true
	end,

	Action = function(self, entity)
		Derma_StringRequest(
			"Set Forcefield Name",
			"Enter a name for this forcefield:",
			entity:GetFieldName() or "",
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
		if (entity:GetClass() != "ix_forcefield") then return end
		if (!client:IsAdmin()) then return end

		name = string.sub(name, 1, 32)

		if (name == "") then
			name = "Forcefield"
		end

		entity:SetFieldName(name)
		client:ChatPrint("Forcefield renamed to: " .. name)

		Schema:SaveForceFields()
	end
})

local MODE_ALLOW_ALL = 1
local MODE_ALLOW_CID = 2
local MODE_ALLOW_NONE = 3

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local angles = (client:GetPos() - trace.HitPos):Angle()
		angles.p = 0
		angles.r = 0
		angles:RotateAroundAxis(angles:Up(), 270)

		-- Push horizontally away from any wall surface that was clicked.
		local spawnXY = trace.HitPos + Vector(trace.HitNormal.x, trace.HitNormal.y, 0) * 16

		-- Trace straight down to find the actual floor so posts don't float.
		local floorTrace = util.TraceLine({
			start  = spawnXY + Vector(0, 0, 100),
			endpos = spawnXY - Vector(0, 0, 512),
			filter = client
		})

		local spawnPos = floorTrace.Hit and floorTrace.HitPos or spawnXY

		local entity = ents.Create("ix_forcefield")
		entity:SetPos(spawnPos)
		entity:SetAngles(angles:SnapTo("y", 90))
		entity:Spawn()
		entity:Activate()

		Schema:SaveForceFields()
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

		local dummyPos = trace.HitPos
		if (trace.Fraction < 1) then
			dummyPos = dummyPos + trace.HitNormal * 8
		end

		local forcefield = self

		self.dummy = ents.Create("prop_physics")
		self.dummy:SetModel("models/props_combine/combine_fence01a.mdl")
		self.dummy:SetPos(dummyPos)
		self.dummy:SetAngles(self:GetAngles())
		self.dummy:Spawn()
		self.dummy.PhysgunDisabled = true
		self:DeleteOnRemove(self.dummy)

		self.dummy.OnTakeDamage = function(dummy, dmgInfo)
			if (IsValid(forcefield)) then
				forcefield:TakeDamage(dmgInfo:GetDamage(), dmgInfo:GetAttacker(), dmgInfo:GetInflictor())
			end
		end

		local verts = {
			{pos = Vector(0, 0, -25)},
			{pos = Vector(0, 0, 150)},
			{pos = self:WorldToLocal(self.dummy:GetPos()) + Vector(0, 0, 150)},
			{pos = self:WorldToLocal(self.dummy:GetPos()) + Vector(0, 0, 150)},
			{pos = self:WorldToLocal(self.dummy:GetPos()) - Vector(0, 0, 25)},
			{pos = Vector(0, 0, -25)}
		}

		self:PhysicsFromMesh(verts)

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
		self:SetMode(MODE_ALLOW_ALL)
		self:SetDisabled(false)
		self:SetFieldHealth(1000)

		if (self:GetFieldName() == "") then
			self:SetFieldName("Forcefield")
		end
	end

	function ENT:TraceAttack(dmgInfo, dir, trace)
		self:TakeDamage(dmgInfo:GetDamage(), dmgInfo:GetAttacker(), dmgInfo:GetInflictor())
	end

	function ENT:OnTakeDamage(dmgInfo)
		if (self:GetDisabled()) then return end

		local newHP = self:GetFieldHealth() - dmgInfo:GetDamage()

		if (newHP <= 0) then
			self:DisableField()
		else
			self:SetFieldHealth(newHP)
		end
	end

	function ENT:DisableField()
		self:SetDisabled(true)
		self:SetFieldHealth(0)
		self:EmitSound("ambient/energy/spark6.wav", 100, 80)
		self:EmitSound("npc/turret_floor/die.wav", 100, 70)

		local name = self:GetFieldName()

		for _, ply in ipairs(player.GetAll()) do
			if (ply:IsCombine()) then
				ply:ChatPrint("[FORCEFIELD] " .. name .. " has been DESTROYED and is offline.")
			end
		end

		Schema:SaveForceFields()

		local entIndex = self:EntIndex()

		timer.Create("ix_forcefield_reboot_" .. entIndex, 900, 1, function()
			if (IsValid(self)) then
				self:RebootField()
			end
		end)
	end

	function ENT:RebootField()
		self:SetDisabled(false)
		self:SetFieldHealth(1000)
		self:SetMode(MODE_ALLOW_ALL)
		self:EmitSound("buttons/combine_button7.wav", 100, 100)

		local name = self:GetFieldName()

		for _, ply in ipairs(player.GetAll()) do
			if (ply:IsCombine()) then
				ply:ChatPrint("[FORCEFIELD] " .. name .. " is back ONLINE.")
			end
		end
	end

	function ENT:StartTouch(entity)
		if (!self.buzzer) then
			self.buzzer = CreateSound(entity, "ambient/machines/combine_shield_touch_loop1.wav")
			self.buzzer:Play()
			self.buzzer:ChangeVolume(0.8, 0)
		else
			self.buzzer:ChangeVolume(0.8, 0.5)
			self.buzzer:Play()
		end

		self.entities = (self.entities or 0) + 1
	end

	function ENT:EndTouch(entity)
		self.entities = math.max((self.entities or 0) - 1, 0)

		if (self.buzzer and self.entities == 0) then
			self.buzzer:FadeOut(0.5)
		end
	end

	function ENT:OnRemove()
		if (self.buzzer) then
			self.buzzer:Stop()
			self.buzzer = nil
		end

		if (!ix.shuttingDown and !self.ixIsSafe) then
			Schema:SaveForceFields()
		end
	end

	local MODES = {
		{
			function(client)
				return false
			end,
			"Off."
		},
		{
			function(client)
				local character = client:GetCharacter()

				if (character and character:GetInventory() and !character:GetInventory():HasItem("cid")) then
					return true
				else
					return false
				end
			end,
			"Only allow with valid CID."
		},
		{
			function(client)
				return true
			end,
			"Never allow citizens."
		}
	}

	function ENT:Use(activator)
		if ((self.nextUse or 0) < CurTime()) then
			self.nextUse = CurTime() + 1.5
		else
			return
		end

		if (activator:IsCombine()) then
			self:SetMode(self:GetMode() + 1)

			if (self:GetMode() > #MODES) then
				self:SetMode(1)

				self:SetSkin(1)
				self.dummy:SetSkin(1)
				self:EmitSound("npc/turret_floor/die.wav")
			else
				self:SetSkin(0)
				self.dummy:SetSkin(0)
			end

			self:EmitSound("buttons/combine_button5.wav", 140, 100 + (self:GetMode() - 1) * 15)
			activator:ChatPrint("Changed barrier mode to: "..MODES[self:GetMode()][2])

			Schema:SaveForceFields()
		else
			self:EmitSound("buttons/combine_button3.wav")
		end
	end

	hook.Add("ShouldCollide", "ix_forcefields", function(a, b)
		local client
		local entity

		if (a:IsPlayer()) then
			client = a
			entity = b
		elseif (b:IsPlayer()) then
			client = b
			entity = a
		end

		if (IsValid(entity) and entity:GetClass() == "ix_forcefield") then
			if (entity:GetDisabled()) then
				return false
			end

			if (IsValid(client)) then
				if (client:IsCombine() or client:Team() == FACTION_ADMIN) then
					return false
				end

				local mode = entity:GetMode() or 1

				return istable(MODES[mode]) and MODES[mode][1](client)
			else
				return entity:GetMode() != 4
			end
		end
	end)
else
	local SHIELD_MATERIAL = ix.util.GetMaterial("effects/combineshield/comshieldwall3")

	function ENT:Initialize()
		local data = {}
			data.start = self:GetPos() + self:GetRight()*-16
			data.endpos = self:GetPos() + self:GetRight()*-480
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

		if (self:GetDisabled() or self:GetMode() == 1) then
			return
		end

		local angles = self:GetAngles()
		local matrix = Matrix()
		matrix:Translate(self:GetPos() + self:GetUp() * -40)
		matrix:Rotate(angles)

		render.SetMaterial(SHIELD_MATERIAL)

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
end
