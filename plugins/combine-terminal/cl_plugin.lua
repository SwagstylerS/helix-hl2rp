
local PLUGIN = PLUGIN

local localClearanceExpires = 0

-- ============================================================
--  NET RECEIVERS
-- ============================================================
net.Receive("CS_TerminalOpen", function()
    local json     = net.ReadString()
    local isSenior = net.ReadBool()
    local payload  = util.JSONToTable(json) or {}

    -- Backward compat: old format was a flat array of records
    if payload[1] then
        payload = {records = payload}
    end

    CS_OpenTerminal(payload, isSenior)
end)

net.Receive("CS_TerminalDetail", function()
    local detail = util.JSONToTable(net.ReadString()) or {}
    if IsValid(CS_TerminalFrame) then
        CS_TerminalFrame:OnCitizenDetail(detail)
    end
end)

net.Receive("CS_TerminalRefresh", function()
    local data = util.JSONToTable(net.ReadString()) or {}
    if IsValid(CS_TerminalFrame) then
        CS_TerminalFrame:OnDataRefresh(data)
    end
end)

net.Receive("CS_ClearanceNotify", function()
    local name = net.ReadString()
    net.ReadString()
    CS_NotifQueue = CS_NotifQueue or {}
    CS_NotifQueue[#CS_NotifQueue + 1] = {
        lines  = {"CLEARANCE REQUEST", name},
        color  = Color(80, 200, 80),
        showAt = CurTime(),
    }
end)

net.Receive("CS_ClearanceResult", function()
    local approved = net.ReadBool()
    local msg      = net.ReadString()
    CS_NotifQueue = CS_NotifQueue or {}
    CS_NotifQueue[#CS_NotifQueue + 1] = {
        lines  = {msg},
        color  = approved and Color(80, 200, 80) or Color(255, 60, 60),
        showAt = CurTime(),
    }
end)

net.Receive("CS_HeatTierChange", function()
    local tier = net.ReadUInt(4)
    local msgs = {
        [1] = "Your recent activities have been noted.",
        [2] = "You are under heightened Combine scrutiny.",
        [3] = "ADVISORY: You are a person of interest to Civil Protection.",
        [4] = "HIGH ALERT: You have been flagged for immediate attention.",
        [5] = "You are being actively tracked by Combine units.",
    }
    local msg = msgs[tier]
    if msg and msg != "" then
        chat.AddText(Color(180, 180, 180), "[SYSTEM] ", Color(220, 220, 220), msg)
    end
end)

net.Receive("CS_SterilizeOrder", function()
    local msg = net.ReadString()
    CS_NotifQueue = CS_NotifQueue or {}
    CS_NotifQueue[#CS_NotifQueue + 1] = {
        lines  = {"OVERWATCH DIRECTIVE", msg},
        color  = Color(200, 30, 30),
        showAt = CurTime(),
    }
end)

net.Receive("CS_EliminationConfirm", function()
    local msg = net.ReadString()
    CS_NotifQueue = CS_NotifQueue or {}
    CS_NotifQueue[#CS_NotifQueue + 1] = {
        lines  = {"COMPLIANCE RECORDED", msg},
        color  = Color(80, 200, 80),
        showAt = CurTime(),
    }
end)

net.Receive("CS_ClearanceSync", function()
    local active  = net.ReadBool()
    local expires = net.ReadInt(32)
    localClearanceExpires = active and expires or 0
end)

hook.Add("HUDPaint", "CS_ClearanceBadge", function()
    local ply = LocalPlayer()
    if !IsValid(ply) or ply:IsCombine() then return end
    if localClearanceExpires <= os.time() then return end
    local mins = math.ceil((localClearanceExpires - os.time()) / 60)
    draw.SimpleText("CLEARANCE: ACTIVE — " .. mins .. "m", "CS_Notif", ScrW() - 8, 6, Color(80, 200, 80), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end)

-- ============================================================
--  TERMINAL ENTRY POINT
-- ============================================================
CS_TerminalFrame = nil

function CS_OpenTerminal(payload, isSenior)
    if IsValid(CS_TerminalFrame) then CS_TerminalFrame:Remove() end

    -- Kill any existing entity tooltip so it doesn't bleed over the terminal UI
    if IsValid(ix.gui.entityInfo) then
        ix.gui.entityInfo:Remove()
        ix.gui.entityInfo = nil
    end

    local frame = vgui.Create("CS_TerminalFrame")
    CS_TerminalFrame = frame
    frame:SetTerminalData(payload)
    frame:SetSenior(isSenior)
    frame:Populate()
end
