
local PLUGIN = PLUGIN

-- ============================================================
--  FONTS
-- ============================================================
surface.CreateFont("CS_Mono", {font="Courier New", size=12, weight=700, antialias=false})
surface.CreateFont("CS_Header", {font="Courier New", size=11, weight=900, antialias=true})
surface.CreateFont("CS_Dispatch", {font="Courier New", size=13, weight=900, antialias=true})
surface.CreateFont("CS_Notif", {font="Courier New", size=11, weight=700, antialias=true})

-- ============================================================
--  CONVARS
-- ============================================================
local cv_duration = CreateClientConVar("cs_scan_duration", "2.5",  false, false)
local cv_reset    = CreateClientConVar("cs_reset_time",    "420",  false, false)
local cv_sound    = CreateClientConVar("cs_sound_path",    "npc/scanner/scanner_scan02.wav", false, false)

-- ============================================================
--  COLOR SCHEMES
-- ============================================================
local C_MPF = {
    bg=Color(10,25,10,210), border=Color(50,180,50), borderDim=Color(30,100,30),
    hdrBg=Color(15,35,15,230), hdrTxt=Color(100,255,100), label=Color(70,160,70),
    val=Color(180,255,180), matHi=Color(120,255,120), matMid=Color(80,200,80),
    progBg=Color(20,50,20), progFg=Color(50,200,50), scanLine=Color(50,200,50,18),
    good=Color(100,255,100), warn=Color(255,220,50), alert=Color(255,80,80),
    sep=Color(40,120,40), hdrLabel=Color(60,200,60),
}
local C_OTA = {
    bg=Color(25,10,10,210), border=Color(200,60,60), borderDim=Color(120,30,30),
    hdrBg=Color(35,15,15,230), hdrTxt=Color(255,100,80), label=Color(180,70,50),
    val=Color(255,180,160), matHi=Color(255,120,80), matMid=Color(200,80,60),
    progBg=Color(50,20,20), progFg=Color(220,60,40), scanLine=Color(220,60,40,18),
    good=Color(255,120,80), warn=Color(255,220,50), alert=Color(255,60,60),
    sep=Color(150,50,40), hdrLabel=Color(210,70,50),
}

function CS_GetScheme()
    local ply = LocalPlayer()
    if IsValid(ply) and ply:Team() == FACTION_OTA then return C_OTA end
    return C_MPF
end

-- ============================================================
--  RAIN
-- ============================================================
local rCodepoints = {}
for cp = 0xA4D0, 0xA4FF do rCodepoints[#rCodepoints + 1] = cp end
local function RC() return utf8.char(rCodepoints[math.random(1, #rCodepoints)]) end
local function RS(n) local t={} for i=1,n do t[i]=RC() end return table.concat(t) end

-- ============================================================
--  FAKE DATA
-- ============================================================
local function MakeFake(ply)
    local sid  = ply:SteamID()
    local hash = 0
    for i = 1, #sid do hash = (hash * 31 + string.byte(sid, i)) % 1000000 end
    math.randomseed(bit.bxor(hash, math.floor(CurTime() / cv_reset:GetFloat())))
    local loyalty   = math.random(0, 100)
    local rationHrs = math.random(2, 71)
    local unitNum   = math.random(100000, 999999)
    return {
        loyalty    = string.format("%d/100", loyalty),
        lastRation = string.format("%dH AGO", rationHrs),
        unitCode   = string.format("CV-%06d", unitNum),
        bio        = loyalty > 60 and "STABLE" or (loyalty > 30 and "FLAGGED" or "CRITICAL"),
        compliance = loyalty > 50 and "COMPLIANT" or "NON-COMPLIANT",
    }
end

local function MakeFakeNPC(entIndex)
    math.randomseed(entIndex * 7919)
    local loyalty   = math.random(0, 100)
    local rationHrs = math.random(2, 71)
    local unitNum   = math.random(100000, 999999)
    return {
        loyalty    = string.format("%d/100", loyalty),
        lastRation = string.format("%dH AGO", rationHrs),
        unitCode   = string.format("NPC-%06d", unitNum),
        bio        = loyalty > 60 and "STABLE" or (loyalty > 30 and "FLAGGED" or "CRITICAL"),
        compliance = loyalty > 50 and "COMPLIANT" or "NON-COMPLIANT",
    }
end

-- ============================================================
--  FIELD BUILDER
-- ============================================================
local TIER_LABELS = {"LOW", "GUARDED", "ELEVATED", "HIGH", "CRITICAL"}

local function BuildFields(scanData)
    local fields = {}
    local function F(lbl, vk, resolve, forceAlert, forceWarn)
        fields[#fields + 1] = {lbl=lbl, vk=vk, resolve=resolve, forceAlert=forceAlert or false, forceWarn=forceWarn or false}
    end
    if scanData.hasWarrant then
        F("WARRANT",   "warrant_flag", 0.05, true)
        F("REASON",    "wReason",      0.08, true)
        F("ISSUED BY", "wIssuedBy",    0.10)
    end
    if scanData.bsApproved then
        F("STATUS", "bs_status", 0.05, true)
    elseif scanData.bsPending then
        F("STATUS", "bs_status", 0.05, false, true)
    end
    if scanData.cwuPending then F("CLEARANCE", "cwu_flag", 0.12, false, true) end
    F("SUBJECT",    "name",       0.15)
    F("CID",        "cid",        0.25)
    F("UNIT CODE",  "unitCode",   0.35)
    F("LOYALTY",    "loyalty",    0.45)
    F("THREAT LVL", "threatLvl",  0.55)
    F("COMPLIANCE", "compliance", 0.65)
    F("BIO STATUS", "bio",        0.75)
    F("LAST RTN",   "lastRation", 0.85)
    if scanData.hasContra then F("CONTRABAND", "contraband", 0.92, true) end
    return fields
end

local function ValColor(c, field, data)
    if field.forceAlert then return c.alert end
    if field.forceWarn  then return c.warn  end
    if field.vk == "threatLvl" then
        local tier = data.heatTier or 0
        if tier >= 3 then return c.alert end
        if tier >= 1 then return c.warn  end
        return c.good
    end
    return c.val
end

-- ============================================================
--  CLIENT GLOBALS  (shared across plugins)
-- ============================================================
CS_NotifQueue = CS_NotifQueue or {}
CS_HoverEnts  = CS_HoverEnts  or {terminal = NULL, intel = NULL, charger = NULL}

-- ============================================================
--  LOCAL STATE
-- ============================================================
local activeScan   = nil
local denyMsg      = nil
local denyAt       = nil
local batteryLevel = nil

local PANEL_LINGER = 6
local RAIN_W       = 52
local HDR_H        = 20
local LINE_H       = 15
local PROG_H       = 18
local PANEL_W      = 310

local NOTIF_W    = 240
local NOTIF_LINE = 16
local NOTIF_PAD  = 8
local NOTIF_SHOW = 6
local NOTIF_FADE = 0.8

-- ============================================================
--  NET RECEIVERS
-- ============================================================
net.Receive("CS_ScanStart", function()
    local target     = net.ReadEntity()
    local name       = net.ReadString()
    local cid        = net.ReadUInt(16)
    local heatTier   = net.ReadUInt(4)
    local hasWarrant = net.ReadBool()
    local wReason    = net.ReadString()
    local wIssuedBy  = net.ReadString()
    local bsApproved = net.ReadBool()
    local bsPending  = net.ReadBool()
    local cwuPending = net.ReadBool()
    local hasContra  = net.ReadBool()
    local contraStr  = net.ReadString()
    local isNPC      = net.ReadBool()

    local fake = isNPC
        and MakeFakeNPC(IsValid(target) and target:EntIndex() or 0)
        or  (IsValid(target) and MakeFake(target) or {})

    local tierColors = {
        Color(100,255,100), Color(200,220,80), Color(255,180,50),
        Color(255,100,50),  Color(255,50,50),
    }

    local data = {
        name         = name,
        cid          = tostring(cid),
        unitCode     = fake.unitCode   or "???",
        loyalty      = fake.loyalty    or "???",
        threatLvl    = TIER_LABELS[heatTier + 1] or "UNKNOWN",
        compliance   = fake.compliance or "???",
        bio          = fake.bio        or "???",
        lastRation   = fake.lastRation or "???",
        hasWarrant   = hasWarrant,
        warrant_flag = hasWarrant and "ACTIVE" or nil,
        wReason      = wReason,
        wIssuedBy    = wIssuedBy,
        bsApproved   = bsApproved,
        bsPending    = bsPending,
        bs_status    = bsApproved and "BLACKSITE: APPROVED" or (bsPending and "BLACKSITE: PENDING" or nil),
        cwuPending   = cwuPending,
        cwu_flag     = cwuPending and "CLEARANCE REQ. PENDING" or nil,
        hasContra    = hasContra,
        contraband   = hasContra and contraStr or nil,
        heatTier     = heatTier,
    }

    local duration = cv_duration:GetFloat()
    local now      = CurTime()
    local rainCols = {}
    for c = 1, 6 do
        local col = {}
        for r = 1, 9 do col[r] = RC() end
        rainCols[c] = col
    end

    activeScan = {
        ent          = target,
        startTime    = now,
        displayUntil = now + duration + PANEL_LINGER,
        data         = data,
        rainCols     = rainCols,
        soundPlayed  = false,
        fields       = BuildFields(data),
        duration     = duration,
        tierColor    = tierColors[heatTier + 1] or Color(200,200,200),
    }

    local c      = CS_GetScheme()
    local tier   = TIER_LABELS[heatTier + 1] or "UNKNOWN"
    local cidStr = cid > 0 and tostring(cid) or "N/A"
    chat.AddText(c.hdrLabel, "[SCAN] ", Color(220,220,220), name, c.label, "  CID:" .. cidStr .. "  TIER:" .. tier)
    if hasWarrant then
        chat.AddText(Color(255,80,80), "  [WARRANT] ", Color(220,220,220), wReason .. " — " .. wIssuedBy)
    end
    if bsApproved then
        chat.AddText(Color(255,80,80), "  [BLACKSITE: APPROVED]")
    elseif bsPending then
        chat.AddText(Color(255,200,50), "  [BLACKSITE: PENDING]")
    end
    if hasContra then
        chat.AddText(Color(255,80,80), "  [CONTRABAND] ", Color(220,220,220), contraStr)
    end
end)

net.Receive("CS_ScanDeny", function()
    denyMsg = net.ReadString()
    denyAt  = CurTime()
end)

net.Receive("CS_BatterySync", function()
    batteryLevel = net.ReadUInt(8)
end)

net.Receive("CS_ChargerSync", function()
    CS_HoverEnts.charger = net.ReadEntity()
end)

net.Receive("CS_BiometricAlert", function()
    local msg = net.ReadString()
    net.ReadUInt(4)
    CS_NotifQueue[#CS_NotifQueue + 1] = {
        lines  = {"BIOMETRIC ALERT", msg},
        color  = Color(255, 220, 50),
        showAt = CurTime(),
    }
end)

-- ============================================================
--  HUD: SCAN PANEL
-- ============================================================
local function DrawScanPanel()
    if !activeScan then return end
    local now = CurTime()
    if now > activeScan.displayUntil then activeScan = nil; return end

    local elapsed  = now - activeScan.startTime
    local progress = math.Clamp(elapsed / activeScan.duration, 0, 1)

    if progress >= 1 and !activeScan.soundPlayed then
        activeScan.soundPlayed = true
        surface.PlaySound(cv_sound:GetString())
    end

    if !activeScan._rainTimer or now > activeScan._rainTimer then
        activeScan._rainTimer = now + 0.1
        for c = 1, 6 do
            table.remove(activeScan.rainCols[c], 1)
            activeScan.rainCols[c][9] = RC()
        end
    end

    local c      = CS_GetScheme()
    local fields = activeScan.fields
    local nF     = #fields
    local panelH = HDR_H + nF * LINE_H + 4 + PROG_H
    local sw, sh = ScrW(), ScrH()

    local px, py
    if IsValid(activeScan.ent) then
        local sp = activeScan.ent:GetPos():ToScreen()
        if sp.visible and sp.x >= 0 and sp.x <= sw and sp.y >= 0 and sp.y <= sh then
            px = math.Clamp(sp.x - PANEL_W / 2, 4, sw - PANEL_W - 4)
            py = math.Clamp(sp.y - panelH - 20, 4, sh - panelH - 4)
        else
            px = sw - PANEL_W - 10; py = 10
        end
    else
        px = sw - PANEL_W - 10; py = 10
    end

    draw.RoundedBox(3, px, py, PANEL_W, panelH, c.bg)
    surface.SetDrawColor(c.border)
    surface.DrawOutlinedRect(px, py, PANEL_W, panelH, 2)

    local sweepY = py + ((now * 55) % panelH)
    surface.SetDrawColor(c.scanLine)
    surface.DrawRect(px + 2, sweepY, PANEL_W - 4, 2)

    surface.SetDrawColor(c.hdrBg)
    surface.DrawRect(px, py, PANEL_W, HDR_H)
    surface.SetDrawColor(c.sep)
    surface.DrawRect(px, py + HDR_H - 1, PANEL_W, 1)

    local hdrLabel      = (LocalPlayer():Team() == FACTION_OTA) and "OVW SCANNER v3.1" or "CP SCANNER v3.1"
    local progressLabel = progress >= 1 and "SCAN COMPLETE" or string.format("SCANNING %d%%", math.floor(progress * 100))
    draw.SimpleText(hdrLabel,      "CS_Header", px + 6,          py + HDR_H/2, c.hdrLabel, TEXT_ALIGN_LEFT,  TEXT_ALIGN_CENTER)
    draw.SimpleText(progressLabel, "CS_Header", px + PANEL_W - 6, py + HDR_H/2, c.hdrTxt,   TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    surface.SetDrawColor(c.sep)
    surface.DrawRect(px + RAIN_W, py + HDR_H, 1, panelH - HDR_H)

    local colW = RAIN_W / 6
    for ci = 1, 6 do
        local col = activeScan.rainCols[ci]
        for ri = 1, #col do
            local gx = px + (ci-1)*colW + colW/2
            local gy = py + HDR_H + (ri-1)*LINE_H + LINE_H/2
            local gc = ri == 1 and c.matHi or Color(c.matMid.r, c.matMid.g, c.matMid.b, 128)
            draw.SimpleText(col[ri], "CS_Mono", gx, gy, gc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local dataX = px + RAIN_W + 6
    local dataW = PANEL_W - RAIN_W - 10
    for i, field in ipairs(fields) do
        local fy       = py + HDR_H + (i-1)*LINE_H + 2
        local resolved = progress >= field.resolve
        local rawVal   = tostring(activeScan.data[field.vk] or "???")
        local val      = resolved and rawVal or RS(math.max(3, #rawVal))
        local vc       = resolved and ValColor(c, field, activeScan.data) or c.label
        draw.SimpleText(field.lbl .. ":", "CS_Mono", dataX,           fy, c.label, TEXT_ALIGN_LEFT,  TEXT_ALIGN_TOP)
        draw.SimpleText(val,              "CS_Mono", dataX+dataW-2,   fy, vc,      TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    local progY = py + HDR_H + nF * LINE_H + 4
    local progW = PANEL_W - 4
    surface.SetDrawColor(c.progBg)
    surface.DrawRect(px + 2, progY, progW, PROG_H)
    surface.SetDrawColor(c.progFg)
    surface.DrawRect(px + 2, progY, math.floor(progW * progress), PROG_H)
    surface.SetDrawColor(c.bg)
    for t = 1, 9 do
        surface.DrawRect(px + 2 + math.floor(progW * t / 10), progY, 1, PROG_H)
    end
end

-- ============================================================
--  HUD: DENY MESSAGE
-- ============================================================
local function DrawDenyMessage()
    if !denyMsg or !denyAt then return end
    local elapsed = CurTime() - denyAt
    if elapsed > 5 then denyMsg = nil; denyAt = nil; return end

    local c    = CS_GetScheme()
    local sw   = ScrW()
    local sh   = ScrH()
    local text = string.format(">> DISPATCH // %s <<", denyMsg)
    surface.SetFont("CS_Dispatch")
    local tw  = surface.GetTextSize(text)
    local px  = (sw - tw) / 2 - 10
    local py  = sh * 0.72
    local pw  = tw + 20
    local ph  = 24
    local fade = elapsed > 4 and (1 - (elapsed - 4)) or 1
    surface.SetDrawColor(c.bg.r, c.bg.g, c.bg.b, math.floor(210 * fade))
    surface.DrawRect(px, py, pw, ph)
    surface.SetDrawColor(c.border.r, c.border.g, c.border.b, math.floor(255 * fade))
    surface.DrawOutlinedRect(px, py, pw, ph, 2)
    draw.SimpleText(text, "CS_Dispatch", sw/2, py+ph/2, Color(c.alert.r, c.alert.g, c.alert.b, math.floor(255*fade)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- ============================================================
--  HUD: NOTIFICATION QUEUE  (all plugins push to CS_NotifQueue)
-- ============================================================
local function DrawNotifications()
    if #CS_NotifQueue == 0 then return end
    local now      = CurTime()
    local sw       = ScrW()
    local yOff     = 10
    local toRemove = {}

    for i, notif in ipairs(CS_NotifQueue) do
        local elapsed = now - notif.showAt
        if elapsed > NOTIF_SHOW + NOTIF_FADE then
            toRemove[#toRemove + 1] = i
        else
            local slideP = math.Clamp(elapsed / 0.3, 0, 1)
            local xOff   = NOTIF_W * (1 - slideP)
            local alpha  = math.Clamp(elapsed > NOTIF_SHOW and (1-(elapsed-NOTIF_SHOW)/NOTIF_FADE) or 1, 0, 1)
            local nLines = #notif.lines
            local ph     = nLines * NOTIF_LINE + NOTIF_PAD * 2
            local px     = sw - NOTIF_W - 10 + xOff
            local py     = yOff
            local c      = CS_GetScheme()
            surface.SetDrawColor(c.bg.r, c.bg.g, c.bg.b, math.floor(210 * alpha))
            surface.DrawRect(px, py, NOTIF_W, ph)
            surface.SetDrawColor(notif.color.r, notif.color.g, notif.color.b, math.floor(255 * alpha))
            surface.DrawRect(px, py, 4, ph)
            surface.SetDrawColor(c.borderDim.r, c.borderDim.g, c.borderDim.b, math.floor(255 * alpha))
            surface.DrawOutlinedRect(px, py, NOTIF_W, ph, 1)
            for j, line in ipairs(notif.lines) do
                local lc = j == 1 and notif.color or c.val
                draw.SimpleText(line, "CS_Notif", px+10, py+NOTIF_PAD+(j-1)*NOTIF_LINE,
                    Color(lc.r, lc.g, lc.b, math.floor(255*alpha)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            yOff = yOff + ph + 4
        end
    end
    for i = #toRemove, 1, -1 do table.remove(CS_NotifQueue, toRemove[i]) end
end

-- ============================================================
--  HUD: BATTERY
-- ============================================================
local function DrawBatteryHUD()
    local ply = LocalPlayer()
    if !IsValid(ply) then return end
    if ply:Team() != FACTION_OTA and !ply:IsCombine() then return end
    if batteryLevel == nil then return end

    local BAT_W   = 12
    local BAT_H   = 60
    local BAT_MAX = 20
    local bx      = 14
    local by      = 60
    local ratio   = batteryLevel / BAT_MAX
    local fillH   = math.floor(BAT_H * ratio)
    local c       = CS_GetScheme()
    local fillCol = ratio > 0.3 and Color(100, 220, 100) or Color(220, 60, 60)

    surface.SetDrawColor(c.bg)
    surface.DrawRect(bx, by, BAT_W, BAT_H)
    surface.SetDrawColor(fillCol)
    surface.DrawRect(bx, by + BAT_H - fillH, BAT_W, fillH)
    surface.SetDrawColor(c.border)
    surface.DrawOutlinedRect(bx, by, BAT_W, BAT_H, 1)
    draw.SimpleText("BAT",                         "CS_Notif", bx+BAT_W/2, by-12,       c.label, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    draw.SimpleText(batteryLevel .. "/" .. BAT_MAX, "CS_Notif", bx+BAT_W/2, by+BAT_H+2, c.label, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

-- ============================================================
--  ENTITY HOVER — CHARGER  (Helix native popup)
-- ============================================================
hook.Add("ShouldPopulateEntityInfo", "CS_Scanner_EntityInfo", function(ent)
    if IsValid(CS_HoverEnts.charger) and ent == CS_HoverEnts.charger then return true end
end)

hook.Add("PopulateEntityInfo", "CS_Scanner_EntityInfo", function(ent, tooltip)
    if !IsValid(CS_HoverEnts.charger) or ent != CS_HoverEnts.charger then return end
    local ply = LocalPlayer()
    if !IsValid(ply) or (ply:Team() != FACTION_OTA and !ply:IsCombine()) then return end
    local title = tooltip:AddRow("name")
    title:SetImportant()
    title:SetText("Scanner Charger")
    title:SetBackgroundColor(Color(50, 180, 50))
    title:SizeToContents()
    local desc = tooltip:AddRow("description")
    desc:SetText("Recharge scanner battery unit.")
    desc:SizeToContents()
    tooltip:SetArrowColor(Color(50, 180, 50))
end)

-- ============================================================
--  MAIN HUD HOOK
-- ============================================================
hook.Add("HUDPaint", "CS_Scanner_HUDPaint", function()
    DrawScanPanel()
    DrawDenyMessage()
    DrawNotifications()
    DrawBatteryHUD()
end)

-- ============================================================
--  CLEANUP
-- ============================================================
hook.Add("EntityRemoved", "CS_Scanner_ScanCleanup", function(ent)
    if activeScan and activeScan.ent == ent then activeScan = nil end
end)

hook.Add("InitPostEntity", "CS_Scanner_ClientReset", function()
    activeScan    = nil
    denyMsg       = nil
    denyAt        = nil
    batteryLevel  = nil
    CS_NotifQueue = {}
    CS_HoverEnts  = {terminal = NULL, intel = NULL, charger = NULL}
end)
