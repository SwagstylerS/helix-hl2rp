
-- ============================================================
--  CS_CitizenDetail — Individual citizen profile view
-- ============================================================

-- Helper: styled text entry
local function MakeTextEntry(parent, multiline, tall)
    local C = CS_TERM_COLORS
    local entry = vgui.Create("DTextEntry", parent)
    entry:SetTall(tall or 24)
    entry:SetMultiline(multiline or false)
    entry:SetFont("CS_Body")
    entry:SetTextColor(C.text)
    entry:SetCursorColor(C.textBright)
    entry:SetHighlightColor(C.highlight)
    entry.Paint = function(self, w, h)
        local C = CS_TERM_COLORS
        draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        surface.SetDrawColor(C.borderDim)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(C.text, C.highlight, C.text)
    end
    return entry
end

-- Helper: styled action button
local function MakeActionButton(parent, label, onClick, color)
    local C = CS_TERM_COLORS
    color = color or C.border
    local btn = vgui.Create("DButton", parent)
    btn:SetTall(26)
    btn:SetText("")
    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if onClick then onClick() end
    end
    btn.Paint = function(self, w, h)
        local C = CS_TERM_COLORS
        local bg = self:IsHovered() and Color(color.r, color.g, color.b, 40) or C.bgDark
        draw.RoundedBox(0, 0, 0, w, h, bg)
        surface.SetDrawColor(color)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(label, "CS_BodyBold", w/2, h/2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return btn
end

-- Helper: info row label + value
local function MakeInfoRow(parent, label, value, valueColor)
    local C = CS_TERM_COLORS
    valueColor = valueColor or C.text
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 2)
    row:SetTall(18)
    row.Paint = function(self, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(label, "CS_BodyBold", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(value, "CS_Body", 160, h/2, valueColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return row
end

-- Helper: section header
local function MakeSectionHeader(parent, text)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 6, 0, 2)
    row:SetTall(20)
    row.Paint = function(self, w, h)
        local C = CS_TERM_COLORS
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, h - 1, w, 1)
        draw.SimpleText(text, "CS_BodyBold", 4, h/2, C.textBright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return row
end

local function StyleListHeaders(list, borderCol)
    for _, col in ipairs(list.Columns) do
        local header = col.Header
        if IsValid(header) then
            header:SetFont("CS_Notif")
            header:SetTextColor(Color(255, 255, 255))
            header:SetContentAlignment(5)
            header.Paint = function(self2, w, h)
                local C = CS_TERM_COLORS
                draw.RoundedBox(0, 0, 0, w, h, C.headerBg)
                surface.SetDrawColor(borderCol)
                surface.DrawRect(0, h - 1, w, 1)
            end
        end
    end
end

local PANEL = {}

AccessorFunc(PANEL, "m_TerminalFrame", "TerminalFrame")
AccessorFunc(PANEL, "m_bSenior",       "Senior", FORCE_BOOL)

function PANEL:Init()
    self.m_Detail = {}
    self.m_bSenior = false
    self.OnBack = nil
end

function PANEL:SetDetail(detail)
    self.m_Detail = detail or {}
    self:Rebuild()
end

function PANEL:SendAction(action, data)
    net.Start("CS_TerminalAction")
        net.WriteString(action)
        net.WriteString(util.TableToJSON(data))
    net.SendToServer()
end

function PANEL:Rebuild()
    self:Clear()
    local C = CS_TERM_COLORS
    local d = self.m_Detail
    if !d.sid then return end

    -- BACK button
    local backBtn = MakeActionButton(self, "< BACK TO DATABASE", function()
        if self.OnBack then self.OnBack() end
    end, C.text)
    backBtn:Dock(TOP)
    backBtn:DockMargin(0, 0, 0, 4)

    -- Main layout: left and right columns
    local body = vgui.Create("DPanel", self)
    body:Dock(FILL)
    body.Paint = function() end

    local leftPanel = vgui.Create("DScrollPanel", body)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(self:GetWide() * 0.55)
    leftPanel:DockMargin(0, 0, 4, 0)
    leftPanel:GetVBar():SetWide(0)

    local rightPanel = vgui.Create("DScrollPanel", body)
    rightPanel:Dock(FILL)
    rightPanel:GetVBar():SetWide(0)

    -- ==================== LEFT COLUMN ====================

    -- Header: Name + CID
    local header = vgui.Create("DPanel", leftPanel)
    header:Dock(TOP)
    header:SetTall(40)
    header.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(d.name or "Unknown", "CS_DetailHeader", 4, 10, C.textBright, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(string.format("CID: %s", tostring(d.cid or "N/A")), "CS_Body", 4, 28, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local statusText = d.isOnline and "ONLINE" or "OFFLINE"
        local statusCol  = d.isOnline and C.textBright or C.textDim
        draw.SimpleText(statusText, "CS_BodyBold", w - 4, 10, statusCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    MakeSectionHeader(leftPanel, "CITIZEN PROFILE")

    MakeInfoRow(leftPanel, "TOTAL SCANS:", tostring(d.scanCount or 0))
    MakeInfoRow(leftPanel, "LAST SCAN:", d.lastScan and d.lastScan > 0 and os.date("%H:%M %d/%m/%Y", d.lastScan) or "NEVER")

    -- Heat
    local heatScore = d.heatScore or 0
    local heatTier  = d.heatTier or 0
    local heatStr   = string.format("%d/100 (TIER %d)", heatScore, heatTier)
    local heatCol   = heatTier >= 4 and C.red or (heatTier >= 3 and C.orange or (heatTier >= 2 and C.yellow or C.text))
    MakeInfoRow(leftPanel, "HEAT LEVEL:", heatStr, heatCol)

    -- Warrant
    local wStr = d.hasWarrant and "ACTIVE" or "NONE"
    local wCol = d.hasWarrant and C.red or C.text
    MakeInfoRow(leftPanel, "WARRANT:", wStr, wCol)
    if d.hasWarrant then
        MakeInfoRow(leftPanel, "  REASON:", d.wReason or "N/A", C.yellow)
        MakeInfoRow(leftPanel, "  ISSUED BY:", d.wIssuedBy or "N/A", C.textDim)
    end

    -- Blacksite
    local bsStr, bsCol
    if d.bsApproved then
        bsStr = "APPROVED"
        bsCol = C.red
    elseif d.bsPending then
        bsStr = string.format("PENDING (%d scans)", d.bsCount or 0)
        bsCol = C.yellow
    else
        bsStr = "CLEAR"
        bsCol = C.text
    end
    MakeInfoRow(leftPanel, "BLACKSITE:", bsStr, bsCol)

    -- Restricted items
    local items = d.restrictedItems or {}
    local itemStr = #items > 0 and table.concat(items, ", ") or "NONE"
    local itemCol = #items > 0 and C.orange or C.text
    MakeInfoRow(leftPanel, "CONTRABAND:", itemStr, itemCol)

    -- CWU
    local cwuStr = d.cwuPending and "REQUEST PENDING" or "NONE"
    local cwuCol = d.cwuPending and C.yellow or C.text
    MakeInfoRow(leftPanel, "CWU CLEARANCE:", cwuStr, cwuCol)

    -- Officer notes
    MakeSectionHeader(leftPanel, "OFFICER NOTES")

    if d.notesEditor and d.notesEditor != "" then
        local editInfo = string.format("Last edited by %s", d.notesEditor)
        if d.notesTime and d.notesTime > 0 then
            editInfo = editInfo .. " at " .. os.date("%H:%M %d/%m", d.notesTime)
        end
        local editRow = vgui.Create("DPanel", leftPanel)
        editRow:Dock(TOP)
        editRow:SetTall(14)
        editRow.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText(editInfo, "CS_Small", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local notesEntry = MakeTextEntry(leftPanel, true, 80)
    notesEntry:Dock(TOP)
    notesEntry:DockMargin(0, 2, 0, 2)
    notesEntry:SetText(d.notes or "")

    local saveBtn = MakeActionButton(leftPanel, "SAVE NOTES", function()
        self:SendAction("setNotes", {sid = d.sid, text = notesEntry:GetText()})
    end, C.border)
    saveBtn:Dock(TOP)
    saveBtn:DockMargin(0, 0, 0, 4)

    -- ==================== RIGHT COLUMN ====================

    if self.m_bSenior then
        MakeSectionHeader(rightPanel, "ACTIONS")

        -- Warrant actions
        if d.hasWarrant then
            local clearBtn = MakeActionButton(rightPanel, "CLEAR WARRANT", function()
                self:SendAction("clearWarrant", {sid = d.sid})
            end, C.yellow)
            clearBtn:Dock(TOP)
            clearBtn:DockMargin(0, 2, 0, 2)
        else
            local reasonLabel = vgui.Create("DPanel", rightPanel)
            reasonLabel:Dock(TOP)
            reasonLabel:SetTall(16)
            reasonLabel:DockMargin(0, 2, 0, 0)
            reasonLabel.Paint = function(self2, w, h)
                local C = CS_TERM_COLORS
                draw.SimpleText("Warrant Reason:", "CS_Small", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            local reasonEntry = MakeTextEntry(rightPanel, false, 24)
            reasonEntry:Dock(TOP)
            reasonEntry:DockMargin(0, 0, 0, 2)
            reasonEntry:SetPlaceholderText("Enter reason...")

            local issueBtn = MakeActionButton(rightPanel, "ISSUE WARRANT", function()
                local reason = reasonEntry:GetText()
                if reason == "" then reason = "No reason specified" end
                self:SendAction("issueWarrant", {sid = d.sid, reason = reason})
            end, C.red)
            issueBtn:Dock(TOP)
            issueBtn:DockMargin(0, 0, 0, 2)
        end

        -- Blacksite actions
        if d.bsPending then
            local approveBS = MakeActionButton(rightPanel, "APPROVE BLACKSITE", function()
                self:SendAction("approveBlacksite", {cid = d.cid})
            end, C.red)
            approveBS:Dock(TOP)
            approveBS:DockMargin(0, 4, 0, 2)

            local denyBS = MakeActionButton(rightPanel, "DENY BLACKSITE", function()
                self:SendAction("denyBlacksite", {cid = d.cid})
            end, C.yellow)
            denyBS:Dock(TOP)
            denyBS:DockMargin(0, 0, 0, 2)
        end

        -- CWU actions
        if d.cwuPending then
            local approveCWU = MakeActionButton(rightPanel, "APPROVE CLEARANCE", function()
                self:SendAction("approveClearance", {sid = d.sid})
            end, C.border)
            approveCWU:Dock(TOP)
            approveCWU:DockMargin(0, 4, 0, 2)

            local denyCWU = MakeActionButton(rightPanel, "DENY CLEARANCE", function()
                self:SendAction("denyClearance", {sid = d.sid})
            end, C.red)
            denyCWU:Dock(TOP)
            denyCWU:DockMargin(0, 0, 0, 2)
        end
    end

    -- Scan history
    MakeSectionHeader(rightPanel, "SCAN HISTORY")

    local scanList = vgui.Create("DListView", rightPanel)
    scanList:Dock(FILL)
    scanList:DockMargin(0, 0, 0, 0)
    scanList:SetMultiSelect(false)
    scanList.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
    end

    scanList:AddColumn("TIME"):SetWidth(100)
    scanList:AddColumn("OFFICER"):SetWidth(120)
    scanList:AddColumn("HEAT"):SetWidth(50)
    scanList:AddColumn("GRID"):SetWidth(80)
    StyleListHeaders(scanList, C.border)

    local history = d.scanHistory or {}
    for _, scan in ipairs(history) do
        local timeStr = scan.time and scan.time > 0 and os.date("%H:%M %d/%m", scan.time) or "N/A"
        local row = scanList:AddLine(timeStr, scan.officer or "?", tostring(scan.heatTier or 0), scan.grid or "N/A")
        for _, col in pairs(row.Columns or {}) do col:SetTextColor(C.text); col:SetContentAlignment(5) end
        row.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            if self2:IsHovered() then
                surface.SetDrawColor(C.hover)
                surface.DrawRect(0, 0, w, h)
            end
        end
    end
end

function PANEL:Paint(w, h)
    local C = CS_TERM_COLORS
    if !C then return end
    draw.RoundedBox(0, 0, 0, w, h, C.bgPanel)
end

vgui.Register("CS_CitizenDetail", PANEL, "DPanel")
