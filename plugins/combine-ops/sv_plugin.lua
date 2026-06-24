
local PLUGIN = PLUGIN

-- ============================================================
--  CONFIG
-- ============================================================
local CFG = {
    PanicCooldown   = 600,
    PanicAutoExpire = 600,
    SeniorKeywords  = {"jury", "grid", "oca", "sectoral", "commander", "division", "senior"},
}

-- ============================================================
--  STATE
-- ============================================================
CS              = CS              or {}
CS.PanicTimers  = CS.PanicTimers  or {}
CS.ActivePanics = CS.ActivePanics or {}
CS.CurfewActive = CS.CurfewActive or false
CS.CheckpointPreCurfewModes = CS.CheckpointPreCurfewModes or {}

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
--  PANIC BUTTON PERSISTENCE
-- ============================================================
function PLUGIN:SavePanicButtons()
    local buttons = {}
    for _, ent in ipairs(ents.FindByClass("ix_panic_button")) do
        if IsValid(ent) then
            local p = ent:GetPos()
            local a = ent:GetAngles()
            buttons[#buttons + 1] = {
                pos = {x = p.x, y = p.y, z = p.z},
                ang = {p = a.p, y = a.y, r = a.r},
            }
        end
    end
    ix.data.Set("cs_panicButtons", buttons)
end

function PLUGIN:LoadPanicButtons()
    local buttons = ix.data.Get("cs_panicButtons", {})
    for _, data in ipairs(buttons) do
        local pos = Vector(data.pos.x, data.pos.y, data.pos.z)
        local ang = Angle(data.ang.p, data.ang.y, data.ang.r)
        local ent = ents.Create("ix_panic_button")
        ent:SetPos(pos)
        ent:SetAngles(ang)
        ent:Spawn()
        ent:Activate()
    end
end

hook.Add("InitPostEntity", "CS_LoadPanicButtons", function()
    PLUGIN:LoadPanicButtons()
end)

-- ============================================================
--  COMMANDS — PANIC (deprecated — use the ix_panic_button entity)
-- ============================================================
ix.command.Add("panicbutton", {
    description = "Send a panic signal to all Combine units.",
    OnRun = function(self, client)
        client:Notify("Use the mounted panic alarm.")
    end,
})

ix.command.Add("panicclear", {
    description = "Cancel your active panic signal.",
    OnRun = function(self, client)
        client:Notify("Use the mounted panic alarm.")
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
            for _, ent in ipairs(ents.FindByClass("ix_panic_button")) do
                if IsValid(ent) and ent:GetOwnerSID() == sid then
                    ent:SetActive(false)
                    ent:SetOwnerSID("")
                end
            end
        end
    end
end)

-- ============================================================
--  COMMANDS — COMMS
-- ============================================================
ix.command.Add("CombineRadio", {
    description = "Transmit on the Combine radio channel.",
    arguments   = {ix.type.text},
    OnRun = function(self, client, message)
        if !IsCombine(client) then return client:Notify("Unauthorized.") end
        ix.chat.Send(client, "combine_radio", message)
        ix.chat.Send(client, "combine_radio_eavesdrop", message)
    end,
})

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

ix.command.Add("curfew", {
    description = "Toggle curfew — passively increases heat for all civilians while active.",
    OnRun = function(self, client)
        client:Notify("Toggle curfew at the operations terminal.")
    end,
})

-- Sync curfew state to all newly loaded characters (Combine and citizens alike)
hook.Add("PlayerLoadedCharacter", "CS_Ops_CurfewSync", function(client, char)
    net.Start("CS_CurfewToggle")
        net.WriteBool(CS.CurfewActive)
        net.WriteString("SYSTEM")
    net.Send(client)
end)

ix.command.Add("transferdetainee", {
    description = "Flag a citizen as detained and log the transfer to the intel board.",
    arguments   = {ix.type.character},
    OnRun = function(self, client, target)
        client:Notify("File detentions at the processing terminal.")
    end,
})

ix.command.Add("releasedetainee", {
    description = "Release a detained citizen and log the release to the intel board.",
    arguments   = {ix.type.character},
    OnRun = function(self, client, target)
        client:Notify("File detentions at the processing terminal.")
    end,
})
