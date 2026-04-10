
local PLUGIN = PLUGIN

-- ============================================================
--  CONFIG
-- ============================================================
local CFG = {
    ScanCooldown       = 30,
    ScanDistance       = 900,
    BatteryMax         = 20,
    BatteryChargeTime  = 5,
    ChargerMoveLimit   = 50,
    ChargerDist        = 100,
    ChargerName        = "ix_scanner_charger",
    BiometricAlertTier = 3,
    HeatTier1          = 15,
    HeatTier2          = 30,
    HeatTier3          = 55,
    HeatTier4          = 80,
    SeniorKeywords     = {"jury", "grid", "oca", "sectoral", "commander", "division", "senior"},
    FlaggedItems       = {"lockpick", "pistol", "smg1", "contraband", "radio"},
    FakeContraband     = {
        "Unauthorized frequency transmitter",
        "Unmarked ration coupons",
        "Seditious literature",
        "Unregistered medical supplies",
        "Encrypted data chip",
        "Anti-Citizen propaganda",
        "Blackmarket currency tokens",
    },
}

-- ============================================================
--  STATE  (shared CS global, additive across plugins)
-- ============================================================
CS             = CS             or {}
CS.Cooldowns   = CS.Cooldowns   or {}
CS.ScanHistory = CS.ScanHistory or {}
CS.Recharging  = CS.Recharging  or {}

-- ============================================================
--  HELPERS
-- ============================================================
local function IsCombine(client)
    return client:IsCombine() or client:Team() == FACTION_OTA
end

local function IsSenior(client)
    if client:IsAdmin() then return true end
    local char = client:GetCharacter()
    if !char then return false end
    local class = ix.class.list[char:GetClass()]
    if !class then return false end
    local className = string.lower(class.name or "")
    for _, kw in ipairs(CFG.SeniorKeywords) do
        if string.find(className, kw, 1, true) then return true end
    end
    return false
end

local function GetSeniors()
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and IsSenior(ply) then out[#out + 1] = ply end
    end
    return out
end

local function SendDeny(client, msg)
    net.Start("CS_ScanDeny")
        net.WriteString(msg)
    net.Send(client)
end

local function GetHeatTier(sid)
    -- CS.HeatScores is populated by combine-terminal
    local h = (CS.HeatScores or {})[sid] or 0
    if h >= CFG.HeatTier4 then return 4 end
    if h >= CFG.HeatTier3 then return 3 end
    if h >= CFG.HeatTier2 then return 2 end
    if h >= CFG.HeatTier1 then return 1 end
    return 0
end

local function GetBattery(client)
    local char = client:GetCharacter()
    if !char then return 0 end
    return char:GetData("cs_battery", CFG.BatteryMax)
end

local function SetBattery(client, amount)
    local char = client:GetCharacter()
    if !char then return end
    amount = math.Clamp(amount, 0, CFG.BatteryMax)
    char:SetData("cs_battery", amount)
    net.Start("CS_BatterySync")
        net.WriteUInt(amount, 8)
    net.Send(client)
end

local function GetRestrictedItems(client)
    local char = client:GetCharacter()
    if !char then return {} end
    local inv = char:GetInventory()
    if !inv then return {} end
    local found = {}
    for _, item in pairs(inv:GetItems()) do
        if item and item.uniqueID then
            local uid = string.lower(item.uniqueID)
            for _, flagged in ipairs(CFG.FlaggedItems) do
                if string.find(uid, flagged, 1, true) then
                    found[#found + 1] = item.name or item.uniqueID
                    break
                end
            end
        end
    end
    return found
end

local function GetFakeContraband(sid)
    local hash = 0
    for i = 1, #sid do
        hash = (hash * 31 + string.byte(sid, i)) % 1000000
    end
    math.randomseed(hash)
    return CFG.FakeContraband[math.random(1, #CFG.FakeContraband)]
end

local function GetDay()
    local t = os.date("*t")
    return string.format("%04d%02d%02d", t.year, t.month, t.day)
end

local function SpawnFrozenProp(model, pos, ang)
    local ent = ents.Create("prop_dynamic")
    ent:SetModel(model)
    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:Spawn()
    ent:SetMoveType(MOVETYPE_NONE)
    return ent
end

-- ============================================================
--  CHARGER ENTITY
-- ============================================================
local function AttachChargerUse(ent)
    ent:SetUseType(SIMPLE_USE)
    CS._ChargerEnt = ent
end

local function GetChargerMapKey()
    return "cs_charger_" .. game.GetMap()
end

local function SaveCharger()
    if IsValid(CS._ChargerEnt) then
        ix.data.Set(GetChargerMapKey(), {
            model = CS._ChargerEnt:GetModel(),
            pos   = CS._ChargerEnt:GetPos(),
            ang   = CS._ChargerEnt:GetAngles(),
        })
    end
end

local function SyncCharger(target)
    local charger = IsValid(CS._ChargerEnt) and CS._ChargerEnt or NULL
    if !IsValid(charger) then
        local list = ents.FindByName(CFG.ChargerName)
        charger = IsValid(list[1]) and list[1] or NULL
    end
    net.Start("CS_ChargerSync")
        net.WriteEntity(charger)
    net.Send(target)
end

local function SyncChargerToAllCombine()
    local targets = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and IsCombine(p) then targets[#targets + 1] = p end
    end
    if #targets > 0 then SyncCharger(targets) end
end

hook.Add("PlayerUse", "CS_Scanner_ChargerUse", function(ply, ent)
    if ent == CS._ChargerEnt or ent:GetName() == CFG.ChargerName then
        if !IsCombine(ply) then return false end
        if (ply:GetPos() - ent:GetPos()):Length() > CFG.ChargerDist then
            SendDeny(ply, "TOO FAR FROM CHARGER")
            return false
        end
        if GetBattery(ply) >= CFG.BatteryMax then
            ply:Notify("Battery already full.")
            return false
        end
        local sid = ply:SteamID()
        if CS.Recharging[sid] then
            ply:Notify("Recharge already in progress.")
            return false
        end
        CS.Recharging[sid] = true
        local startPos = ply:GetPos()
        ply:Notify("Recharging... do not move.")
        timer.Simple(CFG.BatteryChargeTime, function()
            CS.Recharging[sid] = nil
            if !IsValid(ply) then return end
            if (ply:GetPos() - startPos):Length() > CFG.ChargerMoveLimit then
                return SendDeny(ply, "RECHARGE CANCELLED: MOVEMENT DETECTED")
            end
            SetBattery(ply, CFG.BatteryMax)
            ply:Notify("Scanner fully recharged.")
        end)
        return false
    end
end)

hook.Add("InitPostEntity", "CS_Scanner_PropRespawn", function()
    timer.Simple(3, function()
        local data = ix.data.Get(GetChargerMapKey(), nil)
        if !data then return end
        local ok, ent = pcall(SpawnFrozenProp, data.model, data.pos, data.ang)
        if ok and IsValid(ent) then
            AttachChargerUse(ent)
            SyncChargerToAllCombine()
        else
            CS._ChargerRespawnFailed = true
        end
    end)
end)

hook.Add("PlayerInitialSpawn", "CS_Scanner_RespawnFailNotify", function(client)
    timer.Simple(3, function()
        if !IsValid(client) or !client:IsAdmin() then return end
        if CS._ChargerRespawnFailed then
            client:Notify("[CS] WARNING: Charger failed to respawn. Use /makerecharger to reset.")
        end
    end)
end)

hook.Add("PlayerLoadedCharacter", "CS_Scanner_CharacterLoad", function(client, char)
    if !IsCombine(client) then return end
    local battery = char:GetData("cs_battery", CFG.BatteryMax)
    net.Start("CS_BatterySync")
        net.WriteUInt(battery, 8)
    net.Send(client)
    -- Issue scanner_device if not in inventory
    local inv = char:GetInventory()
    if !inv then return end
    for _, item in pairs(inv:GetItems()) do
        if item and item.uniqueID == "scanner_device" then
            SyncCharger(client)
            return
        end
    end
    inv:Add("scanner_device")
    client:Notify("SCANNER UNIT ISSUED // REPORT TO DUTY")
    SyncCharger(client)
end)

-- ============================================================
--  COMMANDS — PROP MANAGEMENT
-- ============================================================
ix.command.Add("makerecharger", {
    description = "Set the aimed prop as the scanner charger.",
    adminOnly   = true,
    OnRun = function(self, client)
        local ent = client:GetEyeTrace().Entity
        if !IsValid(ent) then return client:Notify("No entity in eyetrace.") end
        if IsValid(CS._ChargerEnt) then CS._ChargerEnt:Remove() end
        AttachChargerUse(ent)
        SaveCharger()
        client:Notify("Scanner charger set.")
        SyncChargerToAllCombine()
    end,
})

ix.command.Add("removecharger", {
    description = "Remove the scanner charger.",
    adminOnly   = true,
    OnRun = function(self, client)
        if IsValid(CS._ChargerEnt) then
            CS._ChargerEnt:Remove()
            CS._ChargerEnt = nil
        end
        ix.data.Set(GetChargerMapKey(), nil)
        client:Notify("Scanner charger removed.")
        SyncChargerToAllCombine()
    end,
})

-- ============================================================
--  COMMANDS — SCAN
-- ============================================================
ix.command.Add("scansubject", {
    description = "Scan the civilian you are looking at.",
    OnRun = function(self, client)
        if !IsCombine(client) then
            return SendDeny(client, "UNAUTHORIZED: COMBINE ONLY")
        end

        local scanInv = client:GetCharacter() and client:GetCharacter():GetInventory()
        if scanInv then
            local hasScanner = false
            for _, item in pairs(scanInv:GetItems()) do
                if item and item.uniqueID == "scanner_device" then hasScanner = true; break end
            end
            if !hasScanner then return SendDeny(client, "SCANNER UNIT NOT DETECTED // ACQUIRE DEVICE FIRST") end
        else
            return SendDeny(client, "SCANNER UNIT NOT DETECTED // ACQUIRE DEVICE FIRST")
        end

        local battery = GetBattery(client)
        if battery <= 0 then return SendDeny(client, "BATTERY DEPLETED: USE CHARGER") end

        local target = client:GetEyeTrace().Entity
        local isNPC  = IsValid(target) and target:IsNPC()
        if !IsValid(target) or (!target:IsPlayer() and !isNPC) or !target:Alive() then
            return SendDeny(client, "NO VALID SUBJECT IN RANGE")
        end
        if target:IsPlayer() and IsCombine(target) then
            return SendDeny(client, "CANNOT SCAN COMBINE PERSONNEL")
        end
        if (client:GetPos() - target:GetPos()):Length() > CFG.ScanDistance then
            return SendDeny(client, "SUBJECT OUT OF RANGE")
        end

        SetBattery(client, battery - 1)

        if isNPC then
            math.randomseed(target:EntIndex() + os.time() % 10000)
            local npcHeat   = math.random(0, 4)
            local npcContra = math.random(1, 4) == 1
            local contraStr = npcContra and CFG.FakeContraband[math.random(1, #CFG.FakeContraband)] or ""
            net.Start("CS_ScanStart")
                net.WriteEntity(target)
                net.WriteString(target:GetClass())
                net.WriteUInt(0, 16)
                net.WriteUInt(npcHeat, 4)
                net.WriteBool(false); net.WriteString(""); net.WriteString("")
                net.WriteBool(false); net.WriteBool(false); net.WriteBool(false)
                net.WriteBool(npcContra)
                net.WriteString(contraStr)
                net.WriteBool(true)
            net.Send(client)
            return
        end

        local sid = target:SteamID()
        local now = CurTime()

        if CS.Cooldowns[sid] and now < CS.Cooldowns[sid] then
            local rem = math.ceil(CS.Cooldowns[sid] - now)
            return SendDeny(client, string.format("COOLDOWN: %ds REMAINING", rem))
        end
        CS.Cooldowns[sid] = now + CFG.ScanCooldown

        local char       = target:GetCharacter()
        local cid        = char and char:GetID() or 0
        local warrants   = ix.data.Get("cs_warrants",  {})
        local warrant    = warrants[sid]
        local heatTier   = GetHeatTier(sid)
        local restricted = GetRestrictedItems(target)
        local hasContra  = #restricted > 0
        local contraStr  = ""

        if hasContra then
            contraStr = table.concat(restricted, ", ")
        elseif heatTier >= 2 then
            contraStr = GetFakeContraband(sid)
            hasContra = true
        end

        local cwuPending = (CS.CWURequests or {})[sid] != nil

        -- Biometric alert to seniors at high tier
        if heatTier >= CFG.BiometricAlertTier then
            net.Start("CS_BiometricAlert")
                net.WriteString(target:Name())
                net.WriteUInt(heatTier, 4)
            net.Send(GetSeniors())
        end

        -- Scan history
        CS.ScanHistory[sid] = CS.ScanHistory[sid] or {}
        local history = CS.ScanHistory[sid]
        history[#history + 1] = {
            name = target:Name(), cid = cid, time = os.time(),
            heatTier = heatTier, hasWarrant = warrant != nil,
            officer = client:Name(), pos = target:GetPos(),
        }
        if #history > 50 then table.remove(history, 1) end

        net.Start("CS_ScanStart")
            net.WriteEntity(target)
            net.WriteString(target:Name())
            net.WriteUInt(cid, 16)
            net.WriteUInt(heatTier, 4)
            net.WriteBool(warrant != nil)
            net.WriteString(warrant and warrant.reason   or "")
            net.WriteString(warrant and warrant.issuedBy or "")
            net.WriteBool(false)
            net.WriteBool(false)
            net.WriteBool(cwuPending)
            net.WriteBool(hasContra)
            net.WriteString(contraStr)
            net.WriteBool(false)
        net.Send(client)
    end,
})

ix.command.Add("scanstatus", {
    description = "Show your current battery level in chat.",
    OnRun = function(self, client)
        if !IsCombine(client) then return client:Notify("Unauthorized.") end
        local battery = GetBattery(client)
        client:ChatPrint(string.format("[CS STATUS] Battery: %d/%d",
            battery, CFG.BatteryMax))
    end,
})

ix.command.Add("identify", {
    description = "Quick CID and heat lookup on a citizen by name.",
    arguments   = {ix.type.character},
    OnRun = function(self, client, target)
        if !IsCombine(client) then return client:Notify("Unauthorized.") end
        local targetPly = target:GetPlayer()
        if !IsValid(targetPly) then return client:Notify("Target is not online.") end
        local sid       = targetPly:SteamID()
        local cid       = target:GetID()
        local tier      = GetHeatTier(sid)
        local warrants  = ix.data.Get("cs_warrants", {})
        local warrant   = warrants[sid]
        local tierNames = {"CLEAR", "LOW", "GUARDED", "ELEVATED", "HIGH", "CRITICAL"}
        local tierStr   = tierNames[tier + 1] or "UNKNOWN"
        client:ChatPrint(string.format("[IDENTIFY] %s | CID: %d | Heat: %s | Warrant: %s",
            targetPly:Name(), cid, tierStr, warrant and ("YES — " .. warrant.reason) or "NO"))
    end,
})

