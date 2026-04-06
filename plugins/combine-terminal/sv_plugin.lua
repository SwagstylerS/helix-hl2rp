
local PLUGIN = PLUGIN

-- ============================================================
--  CONFIG
-- ============================================================
local CFG = {
    TerminalDist       = 150,
    IntelDist          = 150,
    IntelMaxEntries    = 20,
    TerminalModel      = "models/combine_interface001.mdl",
    IntelModel         = "models/props_junk/wood_crate001a.mdl",
    WarrantExpiry      = 86400,
    HeatDecayRate      = 60,
    HeatDecayAmount    = 1,
    HeatMax            = 100,
    HeatTier1          = 15,
    HeatTier2          = 30,
    HeatTier3          = 55,
    HeatTier4          = 80,
    HeatMeetDist       = 300,
    HeatMeetMinScore   = 10,
    HeatMeetMinCount   = 2,
    HeatAmounts        = {MEETING=5, SMUGGLE=10, RESTRICT=15},
    BlacksiteThreshold = 3,
    ClearanceExpiry    = 1800,
    ClearanceDenyHeat  = 5,
    SeniorKeywords     = {"jury", "grid", "oca", "sectoral", "commander", "division", "senior"},
    FlaggedItems       = {"lockpick", "pistol", "smg1", "contraband", "radio"},
}

-- ============================================================
--  STATE
-- ============================================================
CS             = CS             or {}
CS.HeatScores  = CS.HeatScores  or {}
CS.CWURequests = CS.CWURequests or {}
CS.IntelLog    = CS.IntelLog    or {}
CS.CurfewActive = CS.CurfewActive or false

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
    if h >= CFG.HeatTier4 then return 4 end
    if h >= CFG.HeatTier3 then return 3 end
    if h >= CFG.HeatTier2 then return 2 end
    if h >= CFG.HeatTier1 then return 1 end
    return 0
end

local function AddHeat(sid, amount)
    CS.HeatScores[sid] = math.Clamp((CS.HeatScores[sid] or 0) + amount, 0, CFG.HeatMax)
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

local function SpawnFrozenProp(model, pos, ang)
    local ent = ents.Create("prop_dynamic")
    ent:SetModel(model)
    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:Spawn()
    ent:SetMoveType(MOVETYPE_NONE)
    return ent
end

local function GetCombinePlayers()
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and IsCombine(ply) then out[#out + 1] = ply end
    end
    return out
end

local function FindPlayerBySteamID(sid)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:SteamID() == sid then return ply end
    end
    return nil
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

local function DoApproveBlacksite(ply, cid)
    if !IsSenior(ply) then ply:Notify("Unauthorized."); return false end
    local blacksite   = ix.data.Get("cs_blacksite", {})
    local scanHistory = CS.ScanHistory or {}
    for sid, bs in pairs(blacksite) do
        local history = scanHistory[sid]
        local last    = history and history[#history]
        if last and last.cid == cid then
            bs.approved = true; blacksite[sid] = bs
            ix.data.Set("cs_blacksite", blacksite)
            ply:Notify(string.format("CID %d blacksite case approved.", cid))
            return true
        end
    end
    ply:Notify("CID not found in blacksite records.")
    return false
end

local function DoDenyBlacksite(ply, cid)
    if !IsSenior(ply) then ply:Notify("Unauthorized."); return false end
    local blacksite   = ix.data.Get("cs_blacksite", {})
    local scanHistory = CS.ScanHistory or {}
    for sid, bs in pairs(blacksite) do
        local history = scanHistory[sid]
        local last    = history and history[#history]
        if last and last.cid == cid then
            blacksite[sid] = {count=0, approved=false}
            ix.data.Set("cs_blacksite", blacksite)
            ply:Notify(string.format("CID %d blacksite case denied and count reset.", cid))
            return true
        end
    end
    ply:Notify("CID not found.")
    return false
end

local function DoApproveClearance(ply, targetPly)
    if !IsCombine(ply) then ply:Notify("Unauthorized."); return false end
    if !IsValid(targetPly) then ply:Notify("Target player is not online."); return false end
    local sid = targetPly:SteamID()
    if !CS.CWURequests[sid] then ply:Notify("No pending clearance request."); return false end
    CS.CWURequests[sid] = nil
    net.Start("CS_ClearanceResult")
        net.WriteBool(true)
        net.WriteString("Your clearance request was APPROVED.")
    net.Send(targetPly)
    ply:Notify("Clearance approved for " .. targetPly:Name())
    return true
end

local function DoDenyClearance(ply, targetPly)
    if !IsCombine(ply) then ply:Notify("Unauthorized."); return false end
    if !IsValid(targetPly) then ply:Notify("Target player is not online."); return false end
    local sid = targetPly:SteamID()
    if !CS.CWURequests[sid] then ply:Notify("No pending clearance request."); return false end
    CS.CWURequests[sid] = nil
    AddHeat(sid, CFG.ClearanceDenyHeat)
    net.Start("CS_ClearanceResult")
        net.WriteBool(false)
        net.WriteString("Your clearance request was DENIED.")
    net.Send(targetPly)
    ply:Notify("Clearance denied for " .. targetPly:Name())
    return true
end

-- ============================================================
--  DATA BUILDERS
-- ============================================================
local BuildTerminalRecords

BuildTerminalRecords = function()
    local warrants    = ix.data.Get("cs_warrants",  {})
    local blacksite   = ix.data.Get("cs_blacksite", {})
    local notes       = ix.data.Get("cs_notes",     {})
    local records     = {}
    local scanHistory = CS.ScanHistory or {}
    for sid, history in pairs(scanHistory) do
        local last    = history[#history]
        local warrant = warrants[sid]
        local bs      = blacksite[sid]
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
            bsPending      = bs != nil and !bs.approved,
            bsApproved     = bs != nil and bs.approved,
            bsCount        = bs and bs.count or 0,
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
        units[#units + 1] = {
            name     = ply:Name(),
            rank     = class and class.name or "Unknown",
            faction  = factionName,
            alive    = ply:Alive(),
            zone     = GetPlayerZone(ply),
            isSenior = IsSenior(ply),
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
    local blacksite   = ix.data.Get("cs_blacksite", {})
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
    local bsList = {}
    for sid, bs in pairs(blacksite) do
        if (bs.count or 0) >= CFG.BlacksiteThreshold and !bs.approved then
            local history = scanHistory[sid]
            local last    = history and history[#history]
            bsList[#bsList + 1] = {
                sid   = sid,
                name  = last and last.name or "Unknown",
                cid   = last and last.cid or 0,
                count = bs.count or 0,
            }
        end
    end
    return {warrants = wList, blacksite = bsList}
end

local function BuildZoneCheckpointData()
    return {
        zones       = ix.data.Get("cs_zones",       {}),
        checkpoints = ix.data.Get("cs_checkpoints", {}),
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

local function BuildFullPayload()
    return {
        records      = BuildTerminalRecords(),
        units        = BuildActiveUnits(),
        recentScans  = BuildRecentScans(50),
        warrants     = BuildWarrantList(),
        zones        = BuildZoneCheckpointData(),
        cwuRequests  = BuildCWURequests(),
        curfewActive = CS.CurfewActive,
    }
end

local function BuildCitizenDetail(sid)
    local warrants    = ix.data.Get("cs_warrants",  {})
    local blacksite   = ix.data.Get("cs_blacksite", {})
    local notes       = ix.data.Get("cs_notes",     {})
    local scanHistory = CS.ScanHistory or {}
    local history     = scanHistory[sid] or {}
    local last        = history[#history]
    local warrant     = warrants[sid]
    local bs          = blacksite[sid]
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
        bsPending       = bs != nil and !bs.approved,
        bsApproved      = bs != nil and bs.approved,
        bsCount         = bs and bs.count or 0,
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
--  TERMINAL / INTEL ENTITIES
-- ============================================================
local function AttachTerminalUse(ent)
    ent:SetUseType(SIMPLE_USE)
    CS._TerminalEnt = ent
end

local function AttachIntelUse(ent)
    ent:SetUseType(SIMPLE_USE)
    CS._IntelEnt = ent
end

local function GetTermMapKey()
    return "cs_term_" .. game.GetMap()
end

local function SaveTermProps()
    local data = {}
    if IsValid(CS._TerminalEnt) then
        data.terminal = {model=CS._TerminalEnt:GetModel(), pos=CS._TerminalEnt:GetPos(), ang=CS._TerminalEnt:GetAngles()}
    end
    if IsValid(CS._IntelEnt) then
        data.intel = {model=CS._IntelEnt:GetModel(), pos=CS._IntelEnt:GetPos(), ang=CS._IntelEnt:GetAngles()}
    end
    ix.data.Set(GetTermMapKey(), data)
end

local function SyncTerminals(target)
    net.Start("CS_TerminalSync")
        net.WriteEntity(IsValid(CS._TerminalEnt) and CS._TerminalEnt or NULL)
        net.WriteEntity(IsValid(CS._IntelEnt)    and CS._IntelEnt    or NULL)
    net.Send(target)
end

local function SyncTerminalsToAll()
    SyncTerminals(player.GetAll())
end

hook.Add("PlayerUse", "CS_Terminal_EntityUse", function(ply, ent)
    if ent == CS._TerminalEnt then
        if !IsCombine(ply) then return false end
        if (ply:GetPos() - ent:GetPos()):Length() > CFG.TerminalDist then
            ply:Notify("You are too far from the terminal.")
            return false
        end
        local payload  = BuildFullPayload()
        local isSenior = IsSenior(ply)
        local json     = util.TableToJSON(payload)
        net.Start("CS_TerminalOpen")
            net.WriteString(json)
            net.WriteBool(isSenior)
        net.Send(ply)
        return false
    end

    if ent == CS._IntelEnt then
        if (ply:GetPos() - ent:GetPos()):Length() > CFG.IntelDist then
            ply:Notify("You are too far from the intel board.")
            return false
        end
        local entries = {}
        for i = #CS.IntelLog, math.max(1, #CS.IntelLog - CFG.IntelMaxEntries + 1), -1 do
            entries[#entries + 1] = CS.IntelLog[i]
        end
        net.Start("CS_IntelOpen")
            net.WriteString(util.TableToJSON(entries))
        net.Send(ply)
        return false
    end
end)

hook.Add("InitPostEntity", "CS_Terminal_PropRespawn", function()
    timer.Simple(3, function()
        local data = ix.data.Get(GetTermMapKey(), {})
        if data.terminal then
            local ok, ent = pcall(SpawnFrozenProp, data.terminal.model, data.terminal.pos, data.terminal.ang)
            if ok and IsValid(ent) then AttachTerminalUse(ent) else CS._TerminalRespawnFailed = true end
        end
        if data.intel then
            local ok, ent = pcall(SpawnFrozenProp, data.intel.model, data.intel.pos, data.intel.ang)
            if ok and IsValid(ent) then AttachIntelUse(ent) else CS._IntelRespawnFailed = true end
        end
    end)
end)

hook.Add("PlayerInitialSpawn", "CS_Terminal_RespawnFailNotify", function(client)
    timer.Simple(3, function()
        if !IsValid(client) or !client:IsAdmin() then return end
        if CS._TerminalRespawnFailed then
            client:Notify("[CS] WARNING: Terminal failed to respawn. Use /maketerminal to reset.")
        end
        if CS._IntelRespawnFailed then
            client:Notify("[CS] WARNING: Intel board failed to respawn. Use /makeintelboard to reset.")
        end
    end)
end)

hook.Add("PlayerLoadedCharacter", "CS_Terminal_CharacterLoad", function(client, char)
    SyncTerminals(client)
end)

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
    elseif action == "approveBlacksite" then
        DoApproveBlacksite(ply, tonumber(data.cid) or 0)
    elseif action == "denyBlacksite" then
        DoDenyBlacksite(ply, tonumber(data.cid) or 0)
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
    end

    local refresh = BuildFullPayload()
    net.Start("CS_TerminalRefresh")
        net.WriteString(util.TableToJSON(refresh))
    net.Send(ply)
end)

-- ============================================================
--  COMMANDS — PROP MANAGEMENT
-- ============================================================
ix.command.Add("maketerminal", {
    description = "Set the aimed prop as the scan records terminal.",
    adminOnly   = true,
    OnRun = function(self, client)
        local ent = client:GetEyeTrace().Entity
        if !IsValid(ent) then return client:Notify("No entity in eyetrace.") end
        if IsValid(CS._TerminalEnt) then CS._TerminalEnt:Remove() end
        AttachTerminalUse(ent)
        SaveTermProps()
        client:Notify("Terminal set.")
        SyncTerminalsToAll()
    end,
})

ix.command.Add("removeterminal", {
    description = "Remove the scan records terminal.",
    adminOnly   = true,
    OnRun = function(self, client)
        if IsValid(CS._TerminalEnt) then CS._TerminalEnt:Remove(); CS._TerminalEnt = nil end
        local data = ix.data.Get(GetTermMapKey(), {})
        data.terminal = nil
        ix.data.Set(GetTermMapKey(), data)
        client:Notify("Terminal removed.")
    end,
})

ix.command.Add("makeintelboard", {
    description = "Set the aimed prop as the intel board.",
    adminOnly   = true,
    OnRun = function(self, client)
        local ent = client:GetEyeTrace().Entity
        if !IsValid(ent) then return client:Notify("No entity in eyetrace.") end
        if IsValid(CS._IntelEnt) then CS._IntelEnt:Remove() end
        AttachIntelUse(ent)
        SaveTermProps()
        client:Notify("Intel board set.")
        SyncTerminalsToAll()
    end,
})

ix.command.Add("removeintelboard", {
    description = "Remove the intel board.",
    adminOnly   = true,
    OnRun = function(self, client)
        if IsValid(CS._IntelEnt) then CS._IntelEnt:Remove(); CS._IntelEnt = nil end
        local data = ix.data.Get(GetTermMapKey(), {})
        data.intel = nil
        ix.data.Set(GetTermMapKey(), data)
        client:Notify("Intel board removed.")
    end,
})

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
        if client:Team() != FACTION_CITIZEN then
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
--  COMMANDS — BLACKSITE
-- ============================================================
ix.command.Add("reviewblacklist", {
    description = "List all pending blacksite cases for review.",
    OnRun = function(self, client)
        if !IsSenior(client) then return client:Notify("Unauthorized.") end
        local blacksite = ix.data.Get("cs_blacksite", {})
        local found = false
        local scanHistory = CS.ScanHistory or {}
        for sid, bs in pairs(blacksite) do
            if (bs.count or 0) >= CFG.BlacksiteThreshold and !bs.approved then
                local history = scanHistory[sid]
                local last    = history and history[#history]
                client:ChatPrint(string.format("[BS] %s (CID:%d) — %d elevated scans",
                    last and last.name or sid, last and last.cid or 0, bs.count))
                found = true
            end
        end
        if !found then client:Notify("No pending blacksite cases.") end
    end,
})

ix.command.Add("approveblacklist", {
    description = "Approve a blacksite case by CID number.",
    arguments   = {ix.type.number},
    OnRun = function(self, client, cid)
        DoApproveBlacksite(client, cid)
    end,
})

ix.command.Add("denyblacklist", {
    description = "Deny a blacksite case and reset its scan count.",
    arguments   = {ix.type.number},
    OnRun = function(self, client, cid)
        DoDenyBlacksite(client, cid)
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
end)

timer.Create("CS_HeatSmuggle", 60, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) or !ply:Alive() or !IsResistance(ply) then continue end
        if #GetRestrictedItems(ply) > 0 then AddHeat(ply:SteamID(), CFG.HeatAmounts.SMUGGLE) end
    end
end)

timer.Create("CS_HeatZone", 15, 0, function()
    local zones = ix.data.Get("cs_zones", {})
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) or !ply:Alive() or !IsResistance(ply) then continue end
        local pos = ply:GetPos()
        for _, zone in ipairs(zones) do
            local zpos = zone.pos
            if type(zpos) == "table" then zpos = Vector(zpos.x or 0, zpos.y or 0, zpos.z or 0) end
            if (pos - zpos):Length() <= zone.radius then
                AddHeat(ply:SteamID(), CFG.HeatAmounts.RESTRICT)
                break
            end
        end
    end
end)

timer.Create("CS_HeatDecay", CFG.HeatDecayRate, 0, function()
    for sid, heat in pairs(CS.HeatScores) do
        CS.HeatScores[sid] = math.max(0, heat - CFG.HeatDecayAmount)
    end
end)

timer.Create("CS_CurfewHeat", 30, 0, function()
    if !CS.CurfewActive then return end
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) or !ply:Alive() or !IsResistance(ply) then continue end
        AddHeat(ply:SteamID(), 2)
    end
end)

timer.Create("CS_CheckpointLog", 15, 0, function()
    local checkpoints = ix.data.Get("cs_checkpoints", {})
    if #checkpoints == 0 then return end
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) or !ply:Alive() or !IsResistance(ply) then continue end
        local pos  = ply:GetPos()
        local char = ply:GetCharacter()
        local cid  = char and char:GetID() or 0
        for _, cp in ipairs(checkpoints) do
            local cpos = cp.pos
            if type(cpos) == "table" then cpos = Vector(cpos.x or 0, cpos.y or 0, cpos.z or 0) end
            if (pos - cpos):Length() <= cp.radius then
                CS.IntelLog[#CS.IntelLog + 1] = {
                    time    = os.date("%H:%M"),
                    grid    = string.format("[CP:%s]", cp.name),
                    officer = ply:Name(),
                    cid     = tostring(cid),
                }
                if #CS.IntelLog > CFG.IntelMaxEntries then table.remove(CS.IntelLog, 1) end
                break
            end
        end
    end
end)
