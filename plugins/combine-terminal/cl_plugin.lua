
local PLUGIN = PLUGIN

-- ============================================================
--  NET RECEIVERS
-- ============================================================
net.Receive("CS_TerminalSync", function()
    CS_HoverEnts          = CS_HoverEnts or {}
    CS_HoverEnts.terminal = net.ReadEntity()
    CS_HoverEnts.intel    = net.ReadEntity()
end)

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

net.Receive("CS_IntelOpen", function()
    CS_OpenIntelBoard(util.JSONToTable(net.ReadString()) or {})
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

-- ============================================================
--  INTEL BOARD (unchanged)
-- ============================================================
local CS_IntelFrame = nil

local function MakeHeaderBar(parent, cols, borderCol)
    local bar = vgui.Create("DPanel", parent)
    bar:SetHeight(20)
    bar:Dock(TOP)
    bar:DockMargin(4, 0, 4, 0)
    bar.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0))
        local x = 0
        for i, col in ipairs(cols) do
            draw.SimpleText(col[1], "CS_Notif", x + col[2]/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            x = x + col[2]
            if i < #cols then
                surface.SetDrawColor(borderCol)
                surface.DrawRect(x - 1, 2, 1, h - 4)
            end
        end
        surface.SetDrawColor(borderCol)
        surface.DrawRect(0, h - 1, w, 1)
    end
    return bar
end

local function StyleRow(row, rowCol)
    row.Paint = function(self, w, h)
        if self:IsSelected() then
            surface.SetDrawColor(Color(rowCol.r, rowCol.g, rowCol.b, 60))
        elseif self:IsHovered() then
            surface.SetDrawColor(Color(rowCol.r, rowCol.g, rowCol.b, 30))
        else
            surface.SetDrawColor(Color(0, 0, 0, 0))
        end
        surface.DrawRect(0, 0, w, h)
    end
end

local function StyleCloseBtn(btn, label, bgCol, borderCol, textCol)
    btn:SetText("")
    btn.Paint = function(self, w, h)
        local bg = self:IsHovered() and Color(bgCol.r+15, bgCol.g+15, bgCol.b+15) or bgCol
        draw.RoundedBox(0, 0, 0, w, h, bg)
        surface.SetDrawColor(borderCol)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(label, "CS_Notif", w/2, h/2, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

function CS_OpenIntelBoard(entries)
    if IsValid(CS_IntelFrame) then CS_IntelFrame:Remove() end

    local frame = vgui.Create("DFrame")
    CS_IntelFrame = frame
    frame:SetSize(540, 380)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(25, 15, 5, 240))
        surface.SetDrawColor(Color(180, 120, 0))
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        surface.DrawRect(0, 18, w, 1)
        draw.SimpleText("RESISTANCE INTEL BOARD", "CS_Header", w/2, 9, Color(220,160,40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local btn = vgui.Create("DButton", frame)
    btn:Dock(BOTTOM)
    btn:DockMargin(4, 4, 4, 4)
    btn:SetTall(24)
    btn.DoClick = function() frame:Remove() end
    StyleCloseBtn(btn, "CLOSE INTEL BOARD", Color(40,25,5), Color(180,120,0), Color(220,180,80))

    local spacer = vgui.Create("DPanel", frame)
    spacer:SetHeight(22)
    spacer:Dock(TOP)
    spacer.Paint = function() end

    MakeHeaderBar(frame, {
        {"TIME",80}, {"GRID",80}, {"UNIT",220}, {"CID",80},
    }, Color(180, 120, 0))

    local list = vgui.Create("DListView", frame)
    list:Dock(FILL)
    list:DockMargin(4, 0, 4, 0)
    list:SetMultiSelect(false)
    list:SetHideHeaders(true)
    list.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(20, 12, 4, 255))
    end

    list:AddColumn("TIME"):SetWidth(80)
    list:AddColumn("GRID"):SetWidth(80)
    list:AddColumn("UNIT"):SetWidth(220)
    list:AddColumn("CID"):SetWidth(80)

    local rowCol = Color(220, 180, 80)
    for _, entry in ipairs(entries) do
        local row = list:AddLine(entry.time or "", entry.grid or "", entry.officer or "", entry.cid or "")
        for _, col in pairs(row.Columns or {}) do col:SetTextColor(rowCol); col:SetContentAlignment(5) end
        StyleRow(row, rowCol)
    end
end

-- ============================================================
--  ENTITY HOVER — TERMINAL & INTEL  (Helix native popup)
-- ============================================================
hook.Add("ShouldPopulateEntityInfo", "CS_Terminal_EntityInfo", function(ent)
    if IsValid(CS_TerminalFrame) or IsValid(CS_IntelFrame) then return false end
    local ents = CS_HoverEnts or {}
    if (IsValid(ents.terminal) and ent == ents.terminal) or
       (IsValid(ents.intel)    and ent == ents.intel)    then return true end
end)

hook.Add("PopulateEntityInfo", "CS_Terminal_EntityInfo", function(ent, tooltip)
    local hEnts = CS_HoverEnts or {}
    local ply   = LocalPlayer()
    local isCombine = IsValid(ply) and (ply:Team() == FACTION_OTA or ply:IsCombine())

    if IsValid(hEnts.terminal) and ent == hEnts.terminal then
        if !isCombine then return end
        local title = tooltip:AddRow("name")
        title:SetImportant()
        title:SetText("Unit Terminal")
        title:SetBackgroundColor(Color(50, 180, 50))
        title:SizeToContents()
        local desc = tooltip:AddRow("description")
        desc:SetText("Access classified scan records.")
        desc:SizeToContents()
        tooltip:SetArrowColor(Color(50, 180, 50))
    elseif IsValid(hEnts.intel) and ent == hEnts.intel then
        local title = tooltip:AddRow("name")
        title:SetImportant()
        title:SetText("Intel Board")
        title:SetBackgroundColor(Color(180, 120, 0))
        title:SizeToContents()
        local desc = tooltip:AddRow("description")
        desc:SetText("View patrol activity and movements.")
        desc:SizeToContents()
        tooltip:SetArrowColor(Color(180, 120, 0))
    end
end)

-- ============================================================
--  CLEANUP
-- ============================================================
hook.Add("InitPostEntity", "CS_Terminal_ClientReset", function()
    CS_HoverEnts          = CS_HoverEnts or {}
    CS_HoverEnts.terminal = NULL
    CS_HoverEnts.intel    = NULL
end)
