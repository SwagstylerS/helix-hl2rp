
local PLUGIN = PLUGIN

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
