
-- ============================================================
--  CS_TabWarrants — Warrants & BOLOs tab
-- ============================================================

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

local function MakeActionButton(parent, label, onClick, color)
    local btn = vgui.Create("DButton", parent)
    btn:SetTall(24)
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

local function SendAction(action, data)
    net.Start("CS_TerminalAction")
        net.WriteString(action)
        net.WriteString(util.TableToJSON(data))
    net.SendToServer()
end

local PANEL = {}

AccessorFunc(PANEL, "m_TerminalFrame", "TerminalFrame")
AccessorFunc(PANEL, "m_bSenior",       "Senior", FORCE_BOOL)

function PANEL:Init()
    self.m_bSenior = false
end

function PANEL:Populate(data)
    self:Clear()
    local C = CS_TERM_COLORS

    local wData  = data and data.warrants or {}
    local wList  = wData.warrants or {}

    -- ==================== ACTIVE WARRANTS ====================
    local wHeader = vgui.Create("DPanel", self)
    wHeader:Dock(TOP)
    wHeader:SetTall(22)
    wHeader:DockMargin(0, 0, 0, 2)
    wHeader.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(string.format("ACTIVE WARRANTS (%d)", #wList), "CS_BodyBold", 4, h/2, C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, h - 1, w, 1)
    end

    if #wList > 0 then
        local wListView = vgui.Create("DListView", self)
        wListView:Dock(TOP)
        wListView:SetTall(math.min(#wList * 20 + 24, 180))
        wListView:SetMultiSelect(false)
        wListView.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        end

        wListView:AddColumn("NAME"):SetWidth(140)
        wListView:AddColumn("CID"):SetWidth(60)
        wListView:AddColumn("REASON"):SetWidth(240)
        wListView:AddColumn("ISSUED BY"):SetWidth(120)
        wListView:AddColumn("EXPIRES"):SetWidth(80)
        StyleListHeaders(wListView, C.red)

        for _, warrant in ipairs(wList) do
            local expStr
            if warrant.expiresIn and warrant.expiresIn > 0 then
                local hrs = math.floor(warrant.expiresIn / 3600)
                local mins = math.floor((warrant.expiresIn % 3600) / 60)
                expStr = string.format("%dh %dm", hrs, mins)
            else
                expStr = "EXPIRED"
            end
            local row = wListView:AddLine(
                warrant.name or "Unknown", tostring(warrant.cid or 0),
                warrant.reason or "N/A", warrant.issuedBy or "N/A", expStr
            )
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(C.red); col:SetContentAlignment(5) end
            row.m_SID = warrant.sid
            row.Paint = function(self2, rw, rh)
                local C = CS_TERM_COLORS
                if self2:IsHovered() then
                    surface.SetDrawColor(Color(C.red.r, C.red.g, C.red.b, 25))
                    surface.DrawRect(0, 0, rw, rh)
                end
            end
        end

        -- Senior: clear warrant on double click
        if self.m_bSenior then
            wListView.DoDoubleClick = function(_, _, row)
                if row.m_SID then
                    surface.PlaySound("buttons/button15.wav")
                    SendAction("clearWarrant", {sid = row.m_SID})
                end
            end

            local clearHint = vgui.Create("DPanel", self)
            clearHint:Dock(TOP)
            clearHint:SetTall(14)
            clearHint.Paint = function(self2, w2, h2)
                local C = CS_TERM_COLORS
                draw.SimpleText("Double-click a warrant to clear it", "CS_Small", 4, h2/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
    else
        local noWarrants = vgui.Create("DPanel", self)
        noWarrants:Dock(TOP)
        noWarrants:SetTall(30)
        noWarrants.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No active warrants.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- ==================== ISSUE NEW WARRANT (Senior only) ====================
    if self.m_bSenior then
        local spacer2 = vgui.Create("DPanel", self)
        spacer2:Dock(TOP)
        spacer2:SetTall(10)
        spacer2.Paint = function() end

        local issueHeader = vgui.Create("DPanel", self)
        issueHeader:Dock(TOP)
        issueHeader:SetTall(22)
        issueHeader:DockMargin(0, 0, 0, 4)
        issueHeader.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("ISSUE NEW WARRANT", "CS_BodyBold", 4, h/2, C.textBright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(C.borderDim)
            surface.DrawRect(0, h - 1, w, 1)
        end

        local issueRow = vgui.Create("DPanel", self)
        issueRow:Dock(TOP)
        issueRow:SetTall(28)
        issueRow.Paint = function() end

        local cidLabel = vgui.Create("DPanel", issueRow)
        cidLabel:Dock(LEFT)
        cidLabel:SetWide(50)
        cidLabel.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("CID:", "CS_BodyBold", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local cidEntry = vgui.Create("DTextEntry", issueRow)
        cidEntry:Dock(LEFT)
        cidEntry:SetWide(80)
        cidEntry:DockMargin(0, 2, 4, 2)
        cidEntry:SetFont("CS_Body")
        cidEntry:SetTextColor(C.text)
        cidEntry:SetCursorColor(C.textBright)
        cidEntry:SetNumeric(true)
        cidEntry.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
            surface.SetDrawColor(C.borderDim)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            self2:DrawTextEntryText(C.text, C.highlight, C.text)
        end

        local reasonLabel = vgui.Create("DPanel", issueRow)
        reasonLabel:Dock(LEFT)
        reasonLabel:SetWide(60)
        reasonLabel.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("Reason:", "CS_BodyBold", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local reasonEntry = vgui.Create("DTextEntry", issueRow)
        reasonEntry:Dock(FILL)
        reasonEntry:DockMargin(0, 2, 4, 2)
        reasonEntry:SetFont("CS_Body")
        reasonEntry:SetTextColor(C.text)
        reasonEntry:SetCursorColor(C.textBright)
        reasonEntry.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
            surface.SetDrawColor(C.borderDim)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            self2:DrawTextEntryText(C.text, C.highlight, C.text)
        end

        local issueBtn = MakeActionButton(issueRow, "ISSUE", function()
            local records = self.m_TerminalFrame and self.m_TerminalFrame:GetTerminalData() and self.m_TerminalFrame:GetTerminalData().records or {}
            local targetCID = tonumber(cidEntry:GetText())
            if !targetCID then return end
            local targetSID
            for _, rec in ipairs(records) do
                if rec.cid == targetCID then targetSID = rec.sid; break end
            end
            if targetSID then
                local reason = reasonEntry:GetText()
                if reason == "" then reason = "No reason specified" end
                SendAction("issueWarrant", {sid = targetSID, reason = reason})
            end
        end, C.red)
        issueBtn:Dock(RIGHT)
        issueBtn:SetWide(80)
        issueBtn:DockMargin(0, 2, 0, 2)
    end
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabWarrants", PANEL, "DPanel")
