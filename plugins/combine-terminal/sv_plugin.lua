
local PLUGIN = PLUGIN

-- ============================================================
--  CONFIG
-- ============================================================
local CFG = {
    WarrantExpiry       = 86400,
    HeatDecayRate       = 60,
    HeatDecayAmount     = 1,
    HeatMax             = 200,
    HeatDecayFloor      = 180,
    HeatTier1           = 15,
    HeatTier2           = 40,
    HeatTier3           = 80,
    HeatTier4           = 120,
    HeatTier5           = 180,
    HeatTier6           = 200,
    HeatMeetDist        = 300,
    HeatMeetMinScore    = 10,
    HeatMeetMinCount    = 2,
    HeatAmounts         = {MEETING=5, SMUGGLE=10, RESTRICT=15},
    HeatBleedDist       = 200,
    HeatBleedTier4      = 5,
    HeatBleedSterilized = 15,
    HeatBleedCooldown   = 60,

    ClearanceExpiry    = 1800,
    ClearanceDenyHeat  = 5,
    SeniorKeywords     = {"jury", "grid", "oca", "sectoral", "commander", "division", "senior"},
    -- match exact item uniqueIDs; "cwu_radio" is authorized and must not be caught
    FlaggedItems       = {"lockpick", "pistol", "smg1", "contraband", "pirate_radio", "combat_stim", "recreational_chem"},
}

-- ============================================================
--  STATE
-- ============================================================
CS                    = CS                    or {}
CS.HeatScores         = CS.HeatScores         or {}
CS.CWURequests        = CS.CWURequests        or {}
CS.CurfewActive       = CS.CurfewActive       or false
CS.ZoneHeatCooldowns  = CS.ZoneHeatCooldowns  or {}
CS.Sterilized         = CS.Sterilized         or {}
CS.HeatBleedCooldowns       = CS.HeatBleedCooldowns       or {}
CS.CheckpointPreCurfewModes = CS.CheckpointPreCurfewModes or {}

hook.Add("InitPostEntity", "CS_Heat_Load", function()
    CS.HeatScores  = ix.data.Get("cs_heatScores",  {})
    CS.ScanHistory = ix.data.Get("cs_scanHistory", {})
    CS.Sterilized  = ix.data.Get("cs_sterilized",  {})
end)

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

local function IsResistance(client)
    return !IsCombine(client)
end

local function GetSeniors()
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and IsSenior(ply) then out[#out + 1] = ply end
    end
    return out
end

local function GetHeatTier(sid)
    local h = CS.HeatScores[sid] or 0
    if h >= CFG.HeatTier6 then return 6 end
    if h >= CFG.HeatTier5 then return 5 end
    if h >= CFG.HeatTier4 then return 4 end
    if h >= CFG.HeatTier3 then return 3 end
    if h >= CFG.HeatTier2 then return 2 end
    if h >= CFG.HeatTier1 then return 1 end
    return 0
end

local function FindPlayerBySteamID(sid)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:SteamID() == sid then return ply end
    end
    return nil
end

local function GetCombinePlayers()
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and IsCombine(ply) then out[#out + 1] = ply end
    end
    return out
end

local function GetOTAPlayers()
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Team() == FACTION_OTA then out[#out + 1] = ply end
    end
    return out
end

local function AddHeat(sid, amount)
    local oldTier = GetHeatTier(sid)
    CS.HeatScores[sid] = math.Clamp((CS.HeatScores[sid] or 0) + amount, 0, CFG.HeatMax)
    local newTier = GetHeatTier(sid)
    if newTier > oldTier then
        local ply = FindPlayerBySteamID(sid)
        if IsValid(ply) then
            net.Start("CS_HeatTierChange")
                net.WriteUInt(newTier, 4)
            net.Send(ply)
        end

        if newTier == 4 and oldTier < 4 then
            local name = IsValid(ply) and ply:Name() or "Unknown"
            local cid  = 0
            if IsValid(ply) then
                local char = ply:GetCharacter()
                if char then cid = char:GetID() end
            end
            local msg = "DISPATCH: 10-103M — " .. name .. " flagged for flagrant malcompliance. Designate for observation and detainment."
            net.Start("CS_BiometricAlert")
                net.WriteString(msg)
                net.WriteUInt(1, 4)
            net.Send(GetCombinePlayers())
            for _, combinePly in ipairs(GetCombinePlayers()) do
                combinePly:ChatPrint(msg)
            end
        end

        if newTier == 5 and oldTier < 5 then
            local name = IsValid(ply) and ply:Name() or "Unknown"
            local msg = "DISPATCH: 10-103C — " .. name .. " classified Terminal Non-Compliant. Overwatch directive pending."
            local combinePlayers = GetCombinePlayers()
            net.Start("CS_BiometricAlert")
                net.WriteString(msg)
                net.WriteUInt(1, 4)
            net.Send(combinePlayers)
            for _, combinePly in ipairs(combinePlayers) do
                combinePly:ChatPrint(msg)
            end
        end

        if newTier == 6 and oldTier < 6 then
            local name = IsValid(ply) and ply:Name() or "Unknown"
            CS.Sterilized[sid] = true
            ix.data.Set("cs_sterilized", CS.Sterilized)
            if IsValid(ply) then
                local char = ply:GetCharacter()
                if char then char:SetData("cs_sterilized", true) end
            end
            local msg = "OVERWATCH DIRECTIVE: Sterilization order issued — " .. name .. " designated for terminal pacification. OTA units respond."
            local otaPlayers = GetOTAPlayers()
            if #otaPlayers > 0 then
                net.Start("CS_SterilizeOrder")
                    net.WriteString(msg)
                net.Send(otaPlayers)
                for _, otaPly in ipairs(otaPlayers) do
                    otaPly:ChatPrint(msg)
                end
            end
        end
    end
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

local function FindPlayerByCID(cid)
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) then continue end
        local char = ply:GetCharacter()
        if char and char:GetData("cid") == cid then return ply end
    end
    return nil
end

local function GetGridCoord(pos)
    return string.format("%d,%d", math.floor(pos.x / 512), math.floor(pos.y / 512))
end

local function GetPlayerZone(ply)
    local pos = ply:GetPos()
    local zones = ix.data.Get("cs_zones", {})
    for _, zone in ipairs(zones) do
        local zpos = zone.pos
        if type(zpos) == "table" then zpos = Vector(zpos.x or 0, zpos.y or 0, zpos.z or 0) end
        if (pos - zpos):Length() <= zone.radius then
            return zone.name
        end
    end
    return "GRID " .. GetGridCoord(pos)
end

-- ============================================================
--  REUSABLE ACTION HELPERS
-- ============================================================
local function DoIssueWarrant(ply, targetPly, reason)
    if !IsSenior(ply) then ply:Notify("You are not authorized to issue warrants."); return false end
    if !IsValid(targetPly) then ply:Notify("Target player is not online."); return false end
    if IsCombine(targetPly) then ply:Notify("Cannot warrant Combine personnel."); return false end
    local sid      = targetPly:SteamID()
    local warrants = ix.data.Get("cs_warrants", {})
    warrants[sid]  = {reason=reason, issuedBy=ply:Name(), issuedAt=os.time()}
    ix.data.Set("cs_warrants", warrants)
    net.Start("CS_BiometricAlert")
        net.WriteString(string.format("WARRANT ISSUED: %s — %s", targetPly:Name(), reason))
        net.WriteUInt(0, 4)
    net.Send(GetCombinePlayers())
    ply:Notify("Warrant issued for " .. targetPly:Name())
    return true
end

local function DoClearWarrant(ply, targetPly)
    if !IsSenior(ply) then ply:Notify("Unauthorized."); return false end
    if !IsValid(targetPly) then ply:Notify("Target player is not online."); return false end
    local sid      = targetPly:SteamID()
    local warrants = ix.data.Get("cs_warrants", {})
    if warrants[sid] then
        warrants[sid] = nil
        ix.data.Set("cs_warrants", warrants)
        ply:Notify("Warrant cleared for " .. targetPly:Name())
        return true
    else
        ply:Notify("No warrant found for " .. targetPly:Name())
        return false
    end
end

local function DoClearWarrantBySID(ply, sid)
    if !IsSenior(ply) then ply:Notify("Unauthorized."); return false end
    local warrants = ix.data.Get("cs_warrants", {})
    if warrants[sid] then
        warrants[sid] = nil
        ix.data.Set("cs_warrants", warrants)
        ply:Notify("Warrant cleared.")
        return true
    else
        ply:Notify("No warrant found.")
        return false
    end
end

local function DoApproveClearance(ply, targetPly)
    if !IsCombine(ply) then ply:Notify("Unauthorized."); return false end
    if !IsValid(targetPly) then ply:Notify("Target player is not online."); return false end
    local sid = targetPly:SteamID()
    if !CS.CWURequests[sid] then ply:Notify("No pending clearance request."); return false end
    CS.CWURequests[sid] = nil
    local char = targetPly:GetCharacter()
    if char then
        local expires = os.time() + CFG.ClearanceExpiry
        char:SetData("cs_clearance", {level = 1, expires = expires})
        net.Start("CS_ClearanceSync")
            net.WriteBool(true)
            net.WriteInt(expires, 32)
        net.Send(targetPly)
    end
    net.Start("CS_ClearanceResult")
        net.WriteBool(true)
        net.WriteString("Your clearance request was APPROVED.")
    net.Send(targetPly)
    ply:Notify("Clearance approved for " .. targetPly:Name())

    local hist = ix.data.Get("cs_clearanceHistory", {})
    hist[#hist + 1] = {sid = sid, name = targetPly:Name(), officer = ply:Name(), decision = "APPROVED", time = os.time()}
    while #hist > 200 do table.remove(hist, 1) end
    ix.data.Set("cs_clearanceHistory", hist)

    return true
end

local function DoDenyClearance(ply, targetPly)
    if !IsCombine(ply) then ply:Notify("Unauthorized."); return false end
    if !IsValid(targetPly) then ply:Notify("Target player is not online."); return false end
    local sid = targetPly:SteamID()
    if !CS.CWURequests[sid] then ply:Notify("No pending clearance request."); return false end
    CS.CWURequests[sid] = nil
    AddHeat(sid, CFG.ClearanceDenyHeat)
    local char = targetPly:GetCharacter()
    if char then
        char:SetData("cs_clearance", nil)
        net.Start("CS_ClearanceSync")
            net.WriteBool(false)
            net.WriteInt(0, 32)
        net.Send(targetPly)
    end
    net.Start("CS_ClearanceResult")
        net.WriteBool(false)
        net.WriteString("Your clearance request was DENIED.")
    net.Send(targetPly)
    ply:Notify("Clearance denied for " .. targetPly:Name())

    local hist = ix.data.Get("cs_clearanceHistory", {})
    hist[#hist + 1] = {sid = sid, name = targetPly:Name(), officer = ply:Name(), decision = "DENIED", time = os.time()}
    while #hist > 200 do table.remove(hist, 1) end
    ix.data.Set("cs_clearanceHistory", hist)

    return true
end

-- ============================================================
--  DATA BUILDERS
-- ============================================================
local BuildTerminalRecords

BuildTerminalRecords = function()
    local warrants    = ix.data.Get("cs_warrants",  {})
    local notes       = ix.data.Get("cs_notes",     {})
    local records     = {}
    local scanHistory = CS.ScanHistory or {}
    for sid, history in pairs(scanHistory) do
        local last    = history[#history]
        local warrant = warrants[sid]
        local note    = notes[sid]
        local online  = FindPlayerBySteamID(sid)
        local items   = {}
        if IsValid(online) then items = GetRestrictedItems(online) end
        records[#records + 1] = {
            sid            = sid,
            name           = last and last.name or "Unknown",
            cid            = last and last.cid  or 0,
            scanCount      = #history,
            lastScan       = last and last.time or 0,
            hasWarrant     = warrant != nil,
            wReason        = warrant and warrant.reason   or "",
            wIssuedBy      = warrant and warrant.issuedBy or "",
            wIssuedAt      = warrant and warrant.issuedAt or 0,
            heatTier       = GetHeatTier(sid),
            heatScore      = CS.HeatScores[sid] or 0,
            sterilized     = CS.Sterilized[sid] == true,
            cwuPending     = CS.CWURequests[sid] != nil,
            restrictedItems = items,
            notes          = note and note.text or "",
            notesEditor    = note and note.editor or "",
            notesTime      = note and note.time or 0,
            isOnline       = IsValid(online),
        }
    end
    return records
end

local function BuildActiveUnits()
    local units = {}
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) or !IsCombine(ply) then continue end
        local char = ply:GetCharacter()
        if !char then continue end
        local class = ix.class.list[char:GetClass()]
        local factionName = ply:Team() == FACTION_OTA and "OTA" or "MPF"
        local qe = CS.ScanQuotas and CS.ScanQuotas[ply:SteamID()]
        units[#units + 1] = {
            name      = ply:Name(),
            rank      = class and class.name or "Unknown",
            faction   = factionName,
            alive     = ply:Alive(),
            zone      = GetPlayerZone(ply),
            isSenior  = IsSenior(ply),
            scanCount = qe and qe.count or 0,
        }
    end
    return units
end

local function BuildRecentScans(limit)
    limit = limit or 50
    local scanHistory = CS.ScanHistory or {}
    local all = {}
    for sid, history in pairs(scanHistory) do
        for _, scan in ipairs(history) do
            all[#all + 1] = {
                sid      = sid,
                name     = scan.name or "Unknown",
                cid      = scan.cid or 0,
                time     = scan.time or 0,
                heatTier = scan.heatTier or 0,
                officer  = scan.officer or "Unknown",
                grid     = scan.pos and GetGridCoord(scan.pos) or "N/A",
            }
        end
    end
    table.sort(all, function(a, b) return a.time > b.time end)
    local result = {}
    for i = 1, math.min(limit, #all) do
        result[i] = all[i]
    end
    return result
end

local function BuildWarrantList()
    local warrants    = ix.data.Get("cs_warrants",  {})
    local scanHistory = CS.ScanHistory or {}
    local wList = {}
    for sid, w in pairs(warrants) do
        local history = scanHistory[sid]
        local last    = history and history[#history]
        wList[#wList + 1] = {
            sid       = sid,
            name      = last and last.name or "Unknown",
            cid       = last and last.cid or 0,
            reason    = w.reason or "",
            issuedBy  = w.issuedBy or "",
            issuedAt  = w.issuedAt or 0,
            expiresIn = math.max(0, CFG.WarrantExpiry - (os.time() - (w.issuedAt or 0))),
        }
    end
    return {warrants = wList}
end

local function BuildZoneCheckpointData()
    return {
        zones       = ix.data.Get("cs_zones",          {}),
        checkpoints = ix.data.Get("cs_checkpoints",    {}),
        crossingLog = ix.data.Get("cs_checkpointLog",  {}),
    }
end

local function BuildCWURequests()
    local list = {}
    for sid, req in pairs(CS.CWURequests) do
        list[#list + 1] = {
            sid  = sid,
            name = req.name or "Unknown",
            time = req.time or 0,
        }
    end
    return list
end

local function BuildOnlineCitizens()
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) then continue end
        if IsCombine(ply) then continue end
        local char = ply:GetCharacter()
        if !char then continue end
        out[#out + 1] = {name = ply:Name(), sid = ply:SteamID()}
    end
    return out
end

local function BuildFullPayload()
    return {
        records          = BuildTerminalRecords(),
        units            = BuildActiveUnits(),
        recentScans      = BuildRecentScans(50),
        warrants         = BuildWarrantList(),
        zones            = BuildZoneCheckpointData(),
        cwuRequests      = BuildCWURequests(),
        curfewActive     = CS.CurfewActive,
        detainees        = ix.data.Get("cs_detainees",       {}),
        clearanceHistory = ix.data.Get("cs_clearanceHistory", {}),
        eliminations     = ix.data.Get("cs_eliminations",    {}),
        onlineCitizens   = BuildOnlineCitizens(),
    }
end

local function BuildCitizenDetail(sid)
    local warrants    = ix.data.Get("cs_warrants",  {})
    local notes       = ix.data.Get("cs_notes",     {})
    local scanHistory = CS.ScanHistory or {}
    local history     = scanHistory[sid] or {}
    local last        = history[#history]
    local warrant     = warrants[sid]
    local note        = notes[sid]
    local online      = FindPlayerBySteamID(sid)
    local items       = {}
    if IsValid(online) then items = GetRestrictedItems(online) end

    local scanList = {}
    for i = #history, math.max(1, #history - 19), -1 do
        local s = history[i]
        scanList[#scanList + 1] = {
            time     = s.time or 0,
            officer  = s.officer or "Unknown",
            heatTier = s.heatTier or 0,
            grid     = s.pos and GetGridCoord(s.pos) or "N/A",
        }
    end

    return {
        sid             = sid,
        name            = last and last.name or "Unknown",
        cid             = last and last.cid  or 0,
        scanCount       = #history,
        lastScan        = last and last.time or 0,
        hasWarrant      = warrant != nil,
        wReason         = warrant and warrant.reason   or "",
        wIssuedBy       = warrant and warrant.issuedBy or "",
        wIssuedAt       = warrant and warrant.issuedAt or 0,
        heatTier        = GetHeatTier(sid),
        heatScore       = CS.HeatScores[sid] or 0,
        cwuPending      = CS.CWURequests[sid] != nil,
        restrictedItems = items,
        notes           = note and note.text or "",
        notesEditor     = note and note.editor or "",
        notesTime       = note and note.time or 0,
        isOnline        = IsValid(online),
        scanHistory     = scanList,
    }
end

-- ============================================================
--  EXPOSED FUNCTIONS (used by ix_combine_terminal entity)
-- ============================================================
CS.BuildFullPayload = BuildFullPayload
CS.IsCombine        = IsCombine
CS.IsSenior         = IsSenior
CS.GetHeatTier      = GetHeatTier
CS.IsSterilized     = function(sid) return CS.Sterilized[sid] == true end

-- ============================================================
--  NET RECEIVERS — TERMINAL ACTIONS
-- ============================================================
net.Receive("CS_TerminalDetail", function(len, ply)
    if !IsCombine(ply) then return end
    local sid = net.ReadString()
    local detail = BuildCitizenDetail(sid)
    net.Start("CS_TerminalDetail")
        net.WriteString(util.TableToJSON(detail))
    net.Send(ply)
end)

net.Receive("CS_TerminalAction", function(len, ply)
    if !IsCombine(ply) then return end
    local action = net.ReadString()
    local data   = util.JSONToTable(net.ReadString()) or {}

    if action == "issueWarrant" then
        local target = FindPlayerBySteamID(data.sid)
        DoIssueWarrant(ply, target, data.reason or "No reason specified")
    elseif action == "clearWarrant" then
        DoClearWarrantBySID(ply, data.sid)
    elseif action == "setNotes" then
        local notes = ix.data.Get("cs_notes", {})
        local text  = string.sub(tostring(data.text or ""), 1, 1000)
        notes[data.sid] = {text = text, editor = ply:Name(), time = os.time()}
        ix.data.Set("cs_notes", notes)
        ply:Notify("Notes saved.")
    elseif action == "approveClearance" then
        local target = FindPlayerBySteamID(data.sid)
        DoApproveClearance(ply, target)
    elseif action == "denyClearance" then
        local target = FindPlayerBySteamID(data.sid)
        DoDenyClearance(ply, target)
    elseif action == "detainCitizen" then
        local sid = tostring(data.sid or "")
        if sid != "" then
            local targetPly = FindPlayerBySteamID(sid)
            local name = IsValid(targetPly) and targetPly:Name() or tostring(data.name or "Unknown")
            local cid  = 0
            if IsValid(targetPly) then
                local char = targetPly:GetCharacter()
                if char then cid = char:GetID() end
            end
            local log = ix.data.Get("cs_detainees", {})
            log[#log + 1] = {name=name, sid=sid, cid=cid, officer=ply:Name(), time=os.time(), status="DETAINED"}
            while #log > 100 do table.remove(log, 1) end
            ix.data.Set("cs_detainees", log)
            local msg = string.format("DISPATCH: Subject %s — 10-97, custody transfer in progress. Processing unit: %s.", name, ply:Name())
            net.Start("CS_BiometricAlert")
                net.WriteString(msg)
                net.WriteUInt(0, 4)
            net.Send(GetCombinePlayers())
            for _, cp in ipairs(GetCombinePlayers()) do cp:ChatPrint(msg) end
        end
    elseif action == "releaseCitizen" then
        local sid = tostring(data.sid or "")
        if sid != "" then
            local log = ix.data.Get("cs_detainees", {})
            local found   = false
            local relName = "Unknown"
            for i = #log, 1, -1 do
                local entry = log[i]
                if entry.sid == sid and entry.status == "DETAINED" then
                    entry.status      = "RELEASED"
                    entry.releasedBy  = ply:Name()
                    entry.releaseTime = os.time()
                    relName           = entry.name or "Unknown"
                    found             = true
                    break
                end
            end
            if found then
                ix.data.Set("cs_detainees", log)
                local msg = string.format("DISPATCH: Subject %s — 10-22, stand down. Released on authority of %s.", relName, ply:Name())
                net.Start("CS_BiometricAlert")
                    net.WriteString(msg)
                    net.WriteUInt(0, 4)
                net.Send(GetCombinePlayers())
                for _, cp in ipairs(GetCombinePlayers()) do cp:ChatPrint(msg) end
            else
                ply:Notify("No active detention record found for this subject.")
            end
        end
    elseif action == "toggleCurfew" then
        if !IsSenior(ply) then
            ply:Notify("Unauthorized.")
        else
            CS.CurfewActive = !CS.CurfewActive
            net.Start("CS_CurfewToggle")
                net.WriteBool(CS.CurfewActive)
                net.WriteString(ply:Name())
            net.Send(player.GetAll())
            if CS.CurfewActive then
                for _, entity in ipairs(ents.FindByClass("ix_checkpoint")) do
                    if IsValid(entity) then
                        CS.CheckpointPreCurfewModes[entity:EntIndex()] = entity:GetMode()
                        entity:SetMode(3)
                    end
                end
            else
                for _, entity in ipairs(ents.FindByClass("ix_checkpoint")) do
                    if IsValid(entity) then
                        entity:SetMode(CS.CheckpointPreCurfewModes[entity:EntIndex()] or 1)
                    end
                end
                CS.CheckpointPreCurfewModes = {}
            end
            local dispatch = CS.CurfewActive
                and "DISPATCH // CURFEW PROTOCOL — 10-4 all units, civilian transit suspended citywide. Checkpoints to restricted access."
                or  "DISPATCH // 10-22 curfew protocol — all units, checkpoints revert to standard procedure."
            for _, cp in ipairs(GetCombinePlayers()) do
                cp:ChatPrint(dispatch)
            end
        end
    end

    local refresh = BuildFullPayload()
    net.Start("CS_TerminalRefresh")
        net.WriteString(util.TableToJSON(refresh))
    net.Send(ply)
end)

-- ============================================================
--  COMMANDS — WARRANTS
-- ============================================================
ix.command.Add("issuewarrant", {
    description = "Issue a warrant for a citizen by name.",
    arguments   = {ix.type.character, ix.type.text},
    OnRun = function(self, client, target, reason)
        local targetPly = target:GetPlayer()
        DoIssueWarrant(client, targetPly, reason)
    end,
})

ix.command.Add("clearwarrant", {
    description = "Clear an active warrant on a citizen by name.",
    arguments   = {ix.type.character},
    OnRun = function(self, client, target)
        local targetPly = target:GetPlayer()
        DoClearWarrant(client, targetPly)
    end,
})

-- Warrant expiry (every 5 minutes)
timer.Create("CS_WarrantExpiry", 300, 0, function()
    local warrants = ix.data.Get("cs_warrants", {})
    local now      = os.time()
    local changed  = false
    for sid, w in pairs(warrants) do
        if (now - w.issuedAt) >= CFG.WarrantExpiry then warrants[sid] = nil; changed = true end
    end
    if changed then ix.data.Set("cs_warrants", warrants) end
end)

-- ============================================================
--  COMMANDS — ZONES & CHECKPOINTS
-- ============================================================
ix.command.Add("addrestrictedzone", {
    description = "Create a restricted zone at your position.",
    adminOnly   = true,
    arguments   = {ix.type.number, ix.type.string},
    OnRun = function(self, client, radius, name)
        local zones = ix.data.Get("cs_zones", {})
        local pos   = client:GetPos()
        zones[#zones + 1] = {pos={x=pos.x, y=pos.y, z=pos.z}, radius=radius, name=name}
        ix.data.Set("cs_zones", zones)
        client:Notify(string.format("Zone '%s' added (radius %d).", name, radius))
    end,
})

ix.command.Add("removerestrictedzone", {
    description = "Remove the nearest restricted zone.",
    adminOnly   = true,
    OnRun = function(self, client)
        local zones = ix.data.Get("cs_zones", {})
        if #zones == 0 then return client:Notify("No zones defined.") end
        local pos = client:GetPos()
        local closestDist, closestIdx = math.huge, nil
        for i, zone in ipairs(zones) do
            local zpos = zone.pos
            if type(zpos) == "table" then zpos = Vector(zpos.x or 0, zpos.y or 0, zpos.z or 0) end
            local d = (pos - zpos):Length()
            if d < closestDist then closestDist = d; closestIdx = i end
        end
        if closestIdx then table.remove(zones, closestIdx); ix.data.Set("cs_zones", zones) end
        client:Notify("Nearest zone removed.")
    end,
})

ix.command.Add("addcheckpoint", {
    description = "Create a movement checkpoint that logs citizens to the intel board.",
    adminOnly   = true,
    arguments   = {ix.type.number, ix.type.string},
    OnRun = function(self, client, radius, name)
        local checkpoints = ix.data.Get("cs_checkpoints", {})
        local pos = client:GetPos()
        checkpoints[#checkpoints + 1] = {pos={x=pos.x, y=pos.y, z=pos.z}, radius=radius, name=name}
        ix.data.Set("cs_checkpoints", checkpoints)
        client:Notify(string.format("Checkpoint '%s' added (radius %d).", name, radius))
    end,
})

ix.command.Add("removecheckpoint", {
    description = "Remove the nearest movement checkpoint.",
    adminOnly   = true,
    OnRun = function(self, client)
        local checkpoints = ix.data.Get("cs_checkpoints", {})
        if #checkpoints == 0 then return client:Notify("No checkpoints defined.") end
        local pos = client:GetPos()
        local closestDist, closestIdx = math.huge, nil
        for i, cp in ipairs(checkpoints) do
            local cpos = cp.pos
            if type(cpos) == "table" then cpos = Vector(cpos.x or 0, cpos.y or 0, cpos.z or 0) end
            local d = (pos - cpos):Length()
            if d < closestDist then closestDist = d; closestIdx = i end
        end
        if closestIdx then table.remove(checkpoints, closestIdx); ix.data.Set("cs_checkpoints", checkpoints) end
        client:Notify("Nearest checkpoint removed.")
    end,
})

-- ============================================================
--  COMMANDS — CWU CLEARANCE
-- ============================================================
ix.command.Add("requestclearance", {
    description = "Request clearance from Combine as a citizen.",
    OnRun = function(self, client)
        if client:Team() != FACTION_CITIZEN and client:Team() != FACTION_CWU then
            return client:Notify("Only citizens may request clearance.")
        end
        local sid = client:SteamID()
        CS.CWURequests[sid] = {name=client:Name(), ply=client, time=CurTime()}
        net.Start("CS_ClearanceNotify")
            net.WriteString(client:Name())
            net.WriteString(sid)
        net.Send(GetCombinePlayers())
    end,
})

timer.Create("CS_ClearanceExpiry", 60, 0, function()
    local now = CurTime()
    for sid, req in pairs(CS.CWURequests) do
        if (now - req.time) >= CFG.ClearanceExpiry then CS.CWURequests[sid] = nil end
    end
end)

ix.command.Add("approveclearance", {
    description = "Approve a citizen's clearance request by name.",
    arguments   = {ix.type.character},
    OnRun = function(self, client, target)
        local targetPly = target:GetPlayer()
        DoApproveClearance(client, targetPly)
    end,
})

ix.command.Add("denyclearance", {
    description = "Deny a citizen's clearance request by name.",
    arguments   = {ix.type.character},
    OnRun = function(self, client, target)
        local targetPly = target:GetPlayer()
        DoDenyClearance(client, targetPly)
    end,
})

-- ============================================================
--  HEAT — PASSIVE TIMERS
-- ============================================================
timer.Create("CS_HeatMeeting", 30, 0, function()
    local civilians = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and IsResistance(ply) then civilians[#civilians + 1] = ply end
    end
    -- Meeting heat
    for _, ply in ipairs(civilians) do
        local sid = ply:SteamID()
        if (CS.HeatScores[sid] or 0) < CFG.HeatMeetMinScore then continue end
        local nearby = 0
        for _, other in ipairs(civilians) do
            if other == ply then continue end
            if (ply:GetPos() - other:GetPos()):Length() <= CFG.HeatMeetDist then
                if (CS.HeatScores[other:SteamID()] or 0) >= CFG.HeatMeetMinScore then nearby = nearby + 1 end
            end
        end
        if nearby >= CFG.HeatMeetMinCount then AddHeat(sid, CFG.HeatAmounts.MEETING) end
    end
    -- Heat bleed: proximity contamination from high-heat / sterilized citizens
    local now = CurTime()
    for _, ply in ipairs(civilians) do
        local sid = ply:SteamID()
        local cooldownKey = "bleed_" .. sid
        if CS.HeatBleedCooldowns[cooldownKey] and CS.HeatBleedCooldowns[cooldownKey] > now then continue end
        for _, other in ipairs(player.GetAll()) do
            if other == ply or !IsValid(other) or !other:Alive() then continue end
            if (ply:GetPos() - other:GetPos()):Length() > CFG.HeatBleedDist then continue end
            local osid = other:SteamID()
            if CS.Sterilized[osid] then
                AddHeat(sid, CFG.HeatBleedSterilized)
                CS.HeatBleedCooldowns[cooldownKey] = now + CFG.HeatBleedCooldown
                break
            elseif GetHeatTier(osid) >= 4 and GetHeatTier(sid) < 4 then
                AddHeat(sid, CFG.HeatBleedTier4)
                CS.HeatBleedCooldowns[cooldownKey] = now + CFG.HeatBleedCooldown
                break
            end
        end
    end
end)

timer.Create("CS_HeatSmuggle", 60, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) or !ply:Alive() or !IsResistance(ply) then continue end
        if #GetRestrictedItems(ply) > 0 then AddHeat(ply:SteamID(), CFG.HeatAmounts.SMUGGLE) end
    end
end)

timer.Create("CS_ZoneHeat", 30, 0, function()
    local zones = ix.data.Get("cs_zones", {})
    local now   = os.time()
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) or !ply:Alive() or IsCombine(ply) then continue end
        local char = ply:GetCharacter()
        if !char then continue end
        local clearance = char:GetData("cs_clearance")
        if clearance and clearance.expires > now then continue end
        local sid = ply:SteamID()
        local pos = ply:GetPos()
        for i, zone in ipairs(zones) do
            local zpos = zone.pos
            if type(zpos) == "table" then zpos = Vector(zpos.x or 0, zpos.y or 0, zpos.z or 0) end
            if (pos - zpos):Length() <= zone.radius then
                local key  = sid .. "_" .. i
                local last = CS.ZoneHeatCooldowns[key]
                if !last or (now - last) >= 120 then
                    AddHeat(sid, CFG.HeatAmounts.RESTRICT)
                    CS.ZoneHeatCooldowns[key] = now
                    ix.data.Set("cs_heatScores", CS.HeatScores)
                end
                break
            end
        end
    end
end)

timer.Create("CS_HeatDecay", CFG.HeatDecayRate, 0, function()
    for sid, heat in pairs(CS.HeatScores) do
        local floor = CS.Sterilized[sid] and CFG.HeatDecayFloor or 0
        CS.HeatScores[sid] = math.max(floor, heat - CFG.HeatDecayAmount)
    end
    ix.data.Set("cs_heatScores", CS.HeatScores)
end)

timer.Create("CS_CurfewHeat", 30, 0, function()
    if !CS.CurfewActive then return end
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) or !ply:Alive() or !IsResistance(ply) then continue end
        AddHeat(ply:SteamID(), 2)
    end
end)

timer.Create("CS_ClearanceDecay", 120, 0, function()
    local now = os.time()
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) then continue end
        local char = ply:GetCharacter()
        if !char then continue end
        local data = char:GetData("cs_clearance")
        if data and data.expires < now then
            char:SetData("cs_clearance", nil)
        end
    end
end)

hook.Add("MapShutdown", "CS_Heat_FlushSave", function()
    ix.data.Set("cs_heatScores",  CS.HeatScores)
    ix.data.Set("cs_scanHistory", CS.ScanHistory)
    ix.data.Set("cs_sterilized",  CS.Sterilized)
end)

hook.Add("PlayerDeath", "CS_OTAKillConfirm", function(victim, inflictor, attacker)
    if !IsValid(attacker) or !attacker:IsPlayer() then return end
    if attacker:Team() != FACTION_OTA then return end
    local vsid = victim:SteamID()
    if !CS.Sterilized[vsid] then return end

    CS.HeatScores[vsid] = 0
    CS.Sterilized[vsid] = nil
    ix.data.Set("cs_heatScores", CS.HeatScores)
    ix.data.Set("cs_sterilized", CS.Sterilized)

    local vchar = victim:GetCharacter()
    if vchar then vchar:SetData("cs_sterilized", nil) end

    local vname      = victim:Name()
    local vcid       = vchar and vchar:GetID() or 0
    local achar      = attacker:GetCharacter()
    local officerName = attacker:Name()
    local officerCID = achar and achar:GetID() or 0

    if achar then
        achar:SetData("cs_efficiency", (achar:GetData("cs_efficiency", 0) + 1))
    end

    local elims = ix.data.Get("cs_eliminations", {})
    elims[#elims + 1] = {name = vname, cid = vcid, officer = officerName, officerCID = officerCID, time = os.time()}
    while #elims > 200 do table.remove(elims, 1) end
    ix.data.Set("cs_eliminations", elims)

    local msg = "OVERWATCH: Sterilization of " .. vname .. " confirmed. Unit " .. officerName .. " — compliance recorded."
    local combinePlayers = GetCombinePlayers()
    net.Start("CS_EliminationConfirm")
        net.WriteString(msg)
    net.Send(combinePlayers)
    for _, combinePly in ipairs(combinePlayers) do
        combinePly:ChatPrint(msg)
    end
end)

hook.Add("PlayerLoadedCharacter", "CS_ClearanceOnLoad", function(client, char)
    local data = char:GetData("cs_clearance")
    net.Start("CS_ClearanceSync")
        net.WriteBool(data != nil)
        net.WriteInt(data and data.expires or 0, 32)
    net.Send(client)
end)

