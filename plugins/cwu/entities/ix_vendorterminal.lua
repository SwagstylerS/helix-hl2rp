AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "CWU Vendor Terminal"
ENT.Category = "HL2 RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisable = true
ENT.bNoPersist = true

ENT.MaxRenderDistance = math.pow(256, 2)

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "OwnerCharID")
	self:NetworkVar("Bool", 0, "Licensed")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_lab/monitor01a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self.nextUseTime = 0
		self:SetOwnerCharID(0)
		self:SetLicensed(false)
		self:SetNWString("OwnerName", "")
		self:SetNWString("TerminalName", "Vendor Terminal")
		self:SetNetVar("stock", {})
		self:SetNetVar("earnings", 0)
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_vendorterminal")

		entity:SetPos(trace.HitPos + Vector(0, 0, 8))
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

		-- Process payment
		character:TakeMoney(price)

		local taxRate = ix.config.Get("cwuTaxRate", 10) / 100
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
			sellerID = entity:GetOwnerCharID(),
			buyer = character:GetName(),
			buyerID = character:GetID(),
			item = entry.uniqueID,
			itemName = entry.name,
			quantity = 1,
			price = price,
			tax = taxAmount,
			terminal = entity:GetNWString("TerminalName", "Vendor Terminal")
		})

		-- Award loyalty to the terminal owner for making a sale
		local ownerCharID = entity:GetOwnerCharID()

		if (ownerCharID > 0) then
			for _, v in ipairs(player.GetAll()) do
				local ownerChar = v:GetCharacter()

				if (ownerChar and ownerChar:GetID() == ownerCharID) then
					PLUGIN:AwardLoyalty(ownerChar, 1, "sale")
					break
				end
			end
		end

		client:NotifyLocalized("cwuPurchaseComplete")
		entity:EmitSound("buttons/button4.wav", 60)

		PLUGIN:SaveVendorTerminals()
	end)
else
	surface.CreateFont("ixVendorTerminal", {
		font = "Default",
		size = 16,
		weight = 800,
		antialias = false
	})

	surface.CreateFont("ixVendorTerminalSmall", {
		font = "Default",
		size = 11,
		weight = 600,
		antialias = false
	})

	function ENT:Draw()
		self:DrawModel()

		local position = self:GetPos()

		if (LocalPlayer():GetPos():DistToSqr(position) > self.MaxRenderDistance) then
			return
		end

		local angles = self:GetAngles()

		angles:RotateAroundAxis(angles:Up(), 90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(position + self:GetForward() * 5.5 + self:GetUp() * 14, angles, 0.05)
			render.PushFilterMin(TEXFILTER.NONE)
			render.PushFilterMag(TEXFILTER.NONE)

			surface.SetDrawColor(20, 20, 20)
			surface.DrawRect(-90, -35, 180, 70)

			surface.SetDrawColor(60, 60, 60)
			surface.DrawOutlinedRect(-90, -35, 180, 70)

			local name = self:GetNWString("TerminalName", "Vendor Terminal")
			draw.SimpleText(name, "ixVendorTerminal", 0, -18, Color(100, 200, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local owner = self:GetNWString("OwnerName", "")

			if (owner != "") then
				draw.SimpleText(owner, "ixVendorTerminalSmall", 0, -2, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			local stock = self:GetNetVar("stock", {})
			local stockCount = #stock
			local statusText = stockCount > 0 and "OPEN - " .. stockCount .. " items" or "CLOSED"
			local statusColor = stockCount > 0 and Color(100, 255, 100) or Color(255, 100, 100)

			draw.SimpleText(statusText, "ixVendorTerminalSmall", 0, 14, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			render.PopFilterMin()
			render.PopFilterMag()
		cam.End3D2D()
	end
end
