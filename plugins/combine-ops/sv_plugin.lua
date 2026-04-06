
local PLUGIN = PLUGIN

-- ============================================================
--  CONFIG
-- ============================================================
local CFG = {
    PanicCooldown   = 600,
    PanicAutoExpire = 600,
    IntelMaxEntries = 20,
    SeniorKeywords  = {"jury", "grid", "oca", "sectoral", "commander", "division", "senior"},
}

-- ============================================================
--  STATE
-- ============================================================
CS              = CS              or {}
CS.PanicTimers  = CS.PanicTimers  or {}
CS.ActivePanics = CS.ActivePanics or {}
CS.CurfewActive = CS.CurfewActive or false
CS.IntelLog     = CS.IntelLog     or {}

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

local function GetAllCombine()
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and IsCombine(ply) then out[#out + 1] = ply end
    end
    return out
end

-- ============================================================
--  COMMANDS — PANIC
-- ============================================================
ix.command.Add("panicbutton", {
    description = "Send a panic signal to all Combine units.",
    OnRun = function(self, client)
        if !IsCombine(client) then return client:Notify("Unauthorized.") end
        local now = CurTime()
        local sid = client:SteamID()
        if CS.PanicTimers[sid] and now < CS.PanicTimers[sid] + CFG.PanicCooldown then
            local rem = math.ceil(CS.PanicTimers[sid] + CFG.PanicCooldown - now)
            return client:Notify(string.format("Panic on cooldown: %ds remaining.", rem))
        end
        CS.PanicTimers[sid]  = now
        CS.ActivePanics[sid] = {name=client:Name(), pos=client:GetPos(), time=now}
        local combineAll = GetAllCombine()
        net.Start("CS_PanicAlert")
            net.WriteString(sid)
            net.WriteString(client:Name())
            net.WriteVector(client:GetPos())
        net.Send(combineAll)
    end,
})

ix.command.Add("panicclear", {
    description = "Cancel your active panic signal.",
    OnRun = function(self, client)
        local sid = client:SteamID()
        if !CS.ActivePanics[sid] then return client:Notify("No active panic signal.") end
        CS.ActivePanics[sid] = nil
        local combineAll = GetAllCombine()
        net.Start("CS_PanicClear")
            net.WriteString(sid)
        net.Send(combineAll)
        client:Notify("Panic signal cancelled.")
    end,
})

-- Panic auto-expiry (every 30s)
timer.Create("CS_PanicExpiry", 30, 0, function()
    local now        = CurTime()
    local combineAll = GetAllCombine()
    for sid, panic in pairs(CS.ActivePanics) do
        if (now - panic.time) >= CFG.PanicAutoExpire then
            CS.ActivePanics[sid] = nil
            if #combineAll > 0 then
                net.Start("CS_PanicClear")
                    net.WriteString(sid)
                net.Send(combineAll)
            end
        end
    end
end)

-- ============================================================
--  COMMANDS — COMMS
-- ============================================================
ix.command.Add("alert", {
    description = "Broadcast an alert message to all Combine units.",
    arguments   = {ix.type.text},
    OnRun = function(self, client, message)
        if !IsCombine(client) then return client:Notify("Unauthorized.") end
        local combineAll = GetAllCombine()
        if #combineAll == 0 then return client:Notify("No Combine units online.") end
        net.Start("CS_Alert")
            net.WriteString(client:Name())
            net.WriteString(message)
        net.Send(combineAll)
        client:Notify("Alert broadcast sent.")
    end,
})

ix.command.Add("radiocall", {
    description = "Send an IC radio message to all online Combine units.",
    arguments   = {ix.type.text},
    OnRun = function(self, client, message)
        if !IsCombine(client) then return client:Notify("Unauthorized.") end
        local combineAll = GetAllCombine()
        if #combineAll == 0 then return client:Notify("No units online.") end
        net.Start("CS_RadioCall")
            net.WriteString(client:Name())
            net.WriteString(message)
        net.Send(combineAll)
    end,
})

ix.command.Add("curfew", {
    description = "Toggle curfew — passively increases heat for all civilians while active.",
    OnRun = function(self, client)
        if !IsSenior(client) then return client:Notify("Unauthorized.") end
        CS.CurfewActive = !CS.CurfewActive
        local combineAll = GetAllCombine()
        if #combineAll > 0 then
            net.Start("CS_CurfewToggle")
                net.WriteBool(CS.CurfewActive)
                net.WriteString(client:Name())
            net.Send(combineAll)
        end
        client:Notify("Curfew " .. (CS.CurfewActive and "ACTIVATED." or "LIFTED."))
    end,
})

ix.command.Add("transferdetainee", {
    description = "Flag a citizen as detained and log the transfer to the intel board.",
    arguments   = {ix.type.character},
    OnRun = function(self, client, target)
        if !IsCombine(client) then return client:Notify("Unauthorized.") end
        local targetPly = target:GetPlayer()
        if !IsValid(targetPly) then return client:Notify("Target is not online.") end
        local cid = target:GetID()
        CS.IntelLog[#CS.IntelLog + 1] = {
            time    = os.date("%H:%M"),
            grid    = "IN-CUSTODY",
            officer = client:Name(),
            cid     = tostring(cid),
        }
        if #CS.IntelLog > CFG.IntelMaxEntries then table.remove(CS.IntelLog, 1) end
        local combineAll = GetAllCombine()
        net.Start("CS_BiometricAlert")
            net.WriteString(string.format("DETAINEE TRANSFER: %s (CID:%d) — %s",
                targetPly:Name(), cid, client:Name()))
            net.WriteUInt(0, 4)
        net.Send(combineAll)
        client:Notify("Transfer logged for " .. targetPly:Name())
    end,
})
