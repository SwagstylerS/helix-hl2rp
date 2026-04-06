function PLUGIN:LoadData()
	self:LoadProductionTables()
	self:LoadWorkOrderBoards()
	self:LoadMedicalWorkstations()
	self:LoadVendorTerminals()
	self:LoadDirectorPCs()
	self:LoadCombineTerminals()
	self:LoadBreakables()

	self:RefreshWorkOrderBoards()
	self:StartDegradationTimer()
end

function PLUGIN:SaveData()
	self:SaveProductionTables()
	self:SaveWorkOrderBoards()
	self:SaveMedicalWorkstations()
	self:SaveVendorTerminals()
	self:SaveDirectorPCs()
	self:SaveCombineTerminals()
	self:SaveBreakables()
end

-- Save/Load: Production Tables
function PLUGIN:SaveProductionTables()
	local data = {}

	for _, v in ipairs(ents.FindByClass("ix_productiontable")) do
		data[#data + 1] = {v:GetPos(), v:GetAngles()}
	end

	ix.data.Set("cwuProductionTables", data)
end

function PLUGIN:LoadProductionTables()
	for _, v in ipairs(ix.data.Get("cwuProductionTables") or {}) do
		local entity = ents.Create("ix_productiontable")

		entity:SetPos(v[1])
		entity:SetAngles(v[2])
		entity:Spawn()
	end
end

-- Save/Load: Work Order Boards
function PLUGIN:SaveWorkOrderBoards()
	local data = {}

	for _, v in ipairs(ents.FindByClass("ix_workorderboard")) do
		data[#data + 1] = {v:GetPos(), v:GetAngles()}
	end

	ix.data.Set("cwuWorkOrderBoards", data)
end

function PLUGIN:LoadWorkOrderBoards()
	for _, v in ipairs(ix.data.Get("cwuWorkOrderBoards") or {}) do
		local entity = ents.Create("ix_workorderboard")

		entity:SetPos(v[1])
		entity:SetAngles(v[2])
		entity:Spawn()
	end
end

-- Save/Load: Medical Workstations
function PLUGIN:SaveMedicalWorkstations()
	local data = {}

	for _, v in ipairs(ents.FindByClass("ix_medicalworkstation")) do
		data[#data + 1] = {v:GetPos(), v:GetAngles()}
	end

	ix.data.Set("cwuMedicalWorkstations", data)
end

function PLUGIN:LoadMedicalWorkstations()
	for _, v in ipairs(ix.data.Get("cwuMedicalWorkstations") or {}) do
		local entity = ents.Create("ix_medicalworkstation")

		entity:SetPos(v[1])
		entity:SetAngles(v[2])
		entity:Spawn()
	end
end

-- Save/Load: Vendor Terminals
function PLUGIN:SaveVendorTerminals()
	local data = {}

	for _, v in ipairs(ents.FindByClass("ix_vendorterminal")) do
		data[#data + 1] = {
			v:GetPos(),
			v:GetAngles(),
			v:GetOwnerCharID(),
			v:GetNWString("OwnerName", ""),
			v:GetNetVar("stock", {}),
			v:GetNWString("TerminalName", ""),
			v:GetLicensed()
		}
	end

	ix.data.Set("cwuVendorTerminals", data)
end

function PLUGIN:LoadVendorTerminals()
	for _, v in ipairs(ix.data.Get("cwuVendorTerminals") or {}) do
		local entity = ents.Create("ix_vendorterminal")

		entity:SetPos(v[1])
		entity:SetAngles(v[2])
		entity:Spawn()
		entity:SetOwnerCharID(v[3] or 0)
		entity:SetNWString("OwnerName", v[4] or "")
		entity:SetNetVar("stock", v[5] or {})
		entity:SetNWString("TerminalName", v[6] or "")
		entity:SetLicensed(v[7] or false)
	end
end

-- Save/Load: Director PCs
function PLUGIN:SaveDirectorPCs()
	local data = {}

	for _, v in ipairs(ents.FindByClass("ix_cwu_director_pc")) do
		data[#data + 1] = {v:GetPos(), v:GetAngles()}
	end

	ix.data.Set("cwuDirectorPCs", data)
end

function PLUGIN:LoadDirectorPCs()
	for _, v in ipairs(ix.data.Get("cwuDirectorPCs") or {}) do
		local entity = ents.Create("ix_cwu_director_pc")

		entity:SetPos(v[1])
		entity:SetAngles(v[2])
		entity:Spawn()
	end
end

-- Save/Load: Combine Terminals
function PLUGIN:SaveCombineTerminals()
	local data = {}

	for _, v in ipairs(ents.FindByClass("ix_cwu_combine_terminal")) do
		data[#data + 1] = {v:GetPos(), v:GetAngles()}
	end

	ix.data.Set("cwuCombineTerminals", data)
end

function PLUGIN:LoadCombineTerminals()
	for _, v in ipairs(ix.data.Get("cwuCombineTerminals") or {}) do
		local entity = ents.Create("ix_cwu_combine_terminal")

		entity:SetPos(v[1])
		entity:SetAngles(v[2])
		entity:Spawn()
	end
end

-- Save/Load: Breakable Infrastructure
function PLUGIN:SaveBreakables()
	local data = {}

	for class, _ in pairs(self.BreakableTypes) do
		for _, v in ipairs(ents.FindByClass(class)) do
			data[#data + 1] = {
				v:GetPos(),
				v:GetAngles(),
				v:GetClass(),
				v:GetBroken(),
				v.linkedEntity and v.linkedEntity:EntIndex() or nil
			}
		end
	end

	ix.data.Set("cwuBreakables", data)
end

function PLUGIN:LoadBreakables()
	for _, v in ipairs(ix.data.Get("cwuBreakables") or {}) do
		local entity = ents.Create(v[3])

		if (IsValid(entity)) then
			entity:SetPos(v[1])
			entity:SetAngles(v[2])
			entity:Spawn()
			entity:SetBroken(v[4] or false)

			if (v[4]) then
				entity:OnBreak()
			end
		end
	end
end
