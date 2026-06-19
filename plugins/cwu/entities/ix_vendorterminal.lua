AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "CWU Vendor"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true
ENT.AutomaticFrameAdvance = true

-- ponytail: random citizen skin re-rolled each spawn; persist a saved model in SaveVendorTerminals if a vendor needs a fixed face
local CITIZEN_MODELS = {
	"models/humans/group01/male_01.mdl",
	"models/humans/group01/male_02.mdl",
	"models/humans/group01/male_03.mdl",
	"models/humans/group01/male_04.mdl",
	"models/humans/group01/male_05.mdl",
	"models/humans/group01/male_06.mdl",
	"models/humans/group01/male_07.mdl",
	"models/humans/group01/male_08.mdl",
	"models/humans/group01/male_09.mdl",
	"models/humans/group01/female_01.mdl",
	"models/humans/group01/female_02.mdl",
	"models/humans/group01/female_03.mdl",
	"models/humans/group01/female_04.mdl",
	"models/humans/group01/female_06.mdl",
	"models/humans/group01/female_07.mdl"
}

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "OwnerCharID")
	self:NetworkVar("Bool", 0, "Licensed")
end

-- mirrors the framework ix_vendor: idle by sequence name, robust across models
function ENT:SetAnim()
	for k, v in ipairs(self:GetSequenceList()) do
		if (v:lower():find("idle") and v != "idlenoise") then
			return self:ResetSequence(k)
		end
	end

	if (self:GetSequenceCount() > 1) then
		self:ResetSequence(4)
	end
end

function ENT:GetAxisAlignedBoundingBox()
	local mins, maxs = self:GetModelBounds()
	mins = Vector(mins.x, mins.y, 0)
	mins, maxs = self:GetRotatedAABB(mins, maxs)

	return mins, maxs
end

function ENT:InitPhysObj()
	local mins, maxs = self:GetAxisAlignedBoundingBox()
	local bPhysObjCreated = self:PhysicsInitBox(mins, maxs)

	if (bPhysObjCreated) then
		local physObj = self:GetPhysicsObject()
		physObj:EnableMotion(false)
		physObj:Sleep()
	end
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel(table.Random(CITIZEN_MODELS))
		self:SetUseType(SIMPLE_USE)
		self:SetMoveType(MOVETYPE_NONE)
		self:DrawShadow(true)
		self:InitPhysObj()

		self:AddCallback("OnAngleChange", function(entity)
			local mins, maxs = entity:GetAxisAlignedBoundingBox()

			entity:SetCollisionBounds(mins, maxs)
		end)

		self.nextUseTime = 0
		self:SetOwnerCharID(0)
		self:SetLicensed(false)
		self:SetNWString("OwnerName", "")
		self:SetNWString("TerminalName", "Vendor Terminal")
		self:SetNetVar("stock", {})
		self:SetNetVar("earnings", 0)

		timer.Simple(1, function()
			if (IsValid(self)) then
				self:SetAnim()
			end
		end)
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_vendorterminal")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, (entity:GetPos() - client:GetPos()):Angle().y - 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:IsOwner(client)
		local character = client:GetCharacter()
		return character and character:GetID() == self:GetOwnerCharID()
	end

	function ENT:Use(client)
		if (self.nextUseTime > CurTime()) then
			return
		end

		self.nextUseTime = CurTime() + 1

		local character = client:GetCharacter()

		if (!character) then
			return
		end

		-- Combine/Director: view transaction log
		if (client:IsCombine() or client:IsCWUDirector()) then
			local transactions = PLUGIN:GetTransactions()
			local terminalName = self:GetNWString("TerminalName", "Vendor Terminal")

			-- Filter to this terminal's transactions
			local filtered = {}

			for _, v in ipairs(transactions) do
				if (v.terminal == terminalName) then
					filtered[#filtered + 1] = v
				end
			end

			netstream.Start(client, "CWUVendorAudit", filtered, terminalName)
			self:EmitSound("buttons/combine_button1.wav")
			return
		end

		-- Owner: management mode
		if (self:IsOwner(client)) then
			local stock = self:GetNetVar("stock", {})
			local earnings = self:GetNetVar("earnings", 0)

			netstream.Start(client, "CWUVendorManage", self:EntIndex(), stock, earnings)
			self:EmitSound("buttons/lightswitch2.wav", 40)
			return
		end

		-- If no owner set, allow Commerce worker to claim
		if (self:GetOwnerCharID() == 0) then
			local division = client:GetCWUDivision()

			if (division == "commerce" or division == "director") then
				if (!character:GetInventory():HasItem("business_license")) then
					client:NotifyLocalized("cwuNeedLicense")
					return
				end

				self:SetOwnerCharID(character:GetID())
				self:SetNWString("OwnerName", character:GetName())
				self:SetLicensed(true)
				client:Notify("You have claimed this vendor terminal.")
				PLUGIN:SaveVendorTerminals()
				return
			end
		end

		-- Anyone else: purchase mode
		local stock = self:GetNetVar("stock", {})

		if (#stock == 0) then
			client:Notify("This vendor has no items for sale.")
			return
		end

		netstream.Start(client, "CWUVendorBuy", self:EntIndex(), stock, self:GetNWString("TerminalName", "Vendor Terminal"))
		self:EmitSound("buttons/lightswitch2.wav", 40)
	end

	function ENT:OnRemove()
		if (!ix.shuttingDown) then
			PLUGIN:SaveVendorTerminals()
		end
	end

	-- Owner adds stock from inventory
	netstream.Hook("CWUVendorAddStock", function(client, entIndex, itemID, price)
		local entity = Entity(entIndex)

		if (!IsValid(entity) or entity:GetClass() != "ix_vendorterminal") then
			return
		end

		if (!entity:IsOwner(client)) then
			return
		end

		local character = client:GetCharacter()
		local inventory = character:GetInventory()
		local item = ix.item.instances[itemID]

		if (!item or item:GetOwner() != character:GetID()) then
			return
		end

		price = math.floor(math.max(1, tonumber(price) or 1))

		local stock = entity:GetNetVar("stock", {})

		stock[#stock + 1] = {
			uniqueID = item.uniqueID,
			name = item.name,
			price = price,
			itemID = item.id
		}

		-- Remove from inventory
		inventory:Remove(item.id)

		entity:SetNetVar("stock", stock)
		PLUGIN:SaveVendorTerminals()
	end)

	-- Owner removes stock (returns to inventory)
	netstream.Hook("CWUVendorRemoveStock", function(client, entIndex, stockIndex)
		local entity = Entity(entIndex)

		if (!IsValid(entity) or entity:GetClass() != "ix_vendorterminal") then
			return
		end

		if (!entity:IsOwner(client)) then
			return
		end

		local stock = entity:GetNetVar("stock", {})
		local entry = stock[stockIndex]

		if (!entry) then
			return
		end

		-- Return item to owner inventory
		client:GetCharacter():GetInventory():Add(entry.uniqueID)
		table.remove(stock, stockIndex)

		entity:SetNetVar("stock", stock)
		PLUGIN:SaveVendorTerminals()
	end)

	-- Owner withdraws earnings
	netstream.Hook("CWUVendorWithdraw", function(client, entIndex)
		local entity = Entity(entIndex)

		if (!IsValid(entity) or entity:GetClass() != "ix_vendorterminal") then
			return
		end

		if (!entity:IsOwner(client)) then
			return
		end

		local earnings = entity:GetNetVar("earnings", 0)

		if (earnings <= 0) then
			return
		end

		client:GetCharacter():GiveMoney(earnings)
		entity:SetNetVar("earnings", 0)
		client:Notify("Withdrawn " .. ix.currency.Get(earnings) .. " from terminal earnings.")
	end)

	-- Owner renames terminal
	netstream.Hook("CWUVendorRename", function(client, entIndex, name)
		local entity = Entity(entIndex)

		if (!IsValid(entity) or entity:GetClass() != "ix_vendorterminal") then
			return
		end

		if (!entity:IsOwner(client)) then
			return
		end

		name = string.sub(tostring(name), 1, 50)
		entity:SetNWString("TerminalName", name)
		PLUGIN:SaveVendorTerminals()
	end)

	-- Customer purchases item
	netstream.Hook("CWUVendorPurchase", function(client, entIndex, stockIndex)
		local entity = Entity(entIndex)

		if (!IsValid(entity) or entity:GetClass() != "ix_vendorterminal") then
			return
		end

		local character = client:GetCharacter()
		local stock = entity:GetNetVar("stock", {})
		local entry = stock[stockIndex]

		if (!entry) then
			client:NotifyLocalized("cwuOutOfStock")
			return
		end

		local price = entry.price

		if (!character:HasMoney(price)) then
			client:NotifyLocalized("cwuInsufficientFunds")
			return
		end

		-- Find owner character before tax computation (may be nil if offline)
		local ownerCharID = entity:GetOwnerCharID()
		local ownerChar = nil

		if (ownerCharID > 0) then
			for _, v in ipairs(player.GetAll()) do
				local char = v:GetCharacter()

				if (char and char:GetID() == ownerCharID) then
					ownerChar = char
					break
				end
			end
		end

		-- Process payment
		character:TakeMoney(price)

		local taxRate = ix.config.Get("cwuTaxRate", 10) / 100

		if (ownerChar and ownerChar:GetData("loyaltyTier", 0) == 5) then
			taxRate = taxRate * (1 - ix.config.Get("cwuModelCitizenTaxDiscount", 50) / 100)
		elseif (ownerChar and ownerChar:GetData("loyaltyTier", 0) == 4) then
			taxRate = taxRate * (1 - ix.config.Get("cwuSeniorWorkerTaxDiscount", 25) / 100)
		end

		local taxAmount = math.floor(price * taxRate)
		local sellerAmount = price - taxAmount

		-- Add tax to CWU treasury
		PLUGIN:AddTreasury(taxAmount)

		-- Add seller earnings
		local earnings = entity:GetNetVar("earnings", 0)
		entity:SetNetVar("earnings", earnings + sellerAmount)

		-- Give item to buyer
		character:GetInventory():Add(entry.uniqueID)

		-- Remove from stock
		table.remove(stock, stockIndex)
		entity:SetNetVar("stock", stock)

		-- Log transaction
		PLUGIN:LogTransaction({
			seller = entity:GetNWString("OwnerName", "Unknown"),
			sellerID = ownerCharID,
			buyer = character:GetName(),
			buyerID = character:GetID(),
			item = entry.uniqueID,
			itemName = entry.name,
			quantity = 1,
			price = price,
			tax = taxAmount,
			terminal = entity:GetNWString("TerminalName", "Vendor Terminal")
		})

		client:NotifyLocalized("cwuPurchaseComplete")
		entity:EmitSound("buttons/button4.wav", 60)

		PLUGIN:SaveVendorTerminals()
	end)
else
	-- framework-style look-at info panel instead of a 3D2D nameplate
	function ENT:OnPopulateEntityInfo(tooltip)
		local name = tooltip:AddRow("name")
		name:SetImportant()
		name:SetText(self:GetNWString("TerminalName", "Vendor"))
		name:SizeToContents()

		local owner = self:GetNWString("OwnerName", "")

		if (owner != "") then
			local ownerRow = tooltip:AddRow("owner")
			ownerRow:SetText(owner)
			ownerRow:SizeToContents()
		end

		local stockCount = #self:GetNetVar("stock", {})
		local status = tooltip:AddRow("status")
		status:SetBackgroundColor(stockCount > 0 and Color(70, 120, 70) or Color(120, 70, 70))
		status:SetText(stockCount > 0 and "OPEN - " .. stockCount .. " items" or "CLOSED")
		status:SizeToContents()
	end
end
