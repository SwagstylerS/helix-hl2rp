
-- ============================================================
--  CS_TabDatabase — Civilian Database tab (list + detail)
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

local PANEL = {}

AccessorFunc(PANEL, "m_TerminalFrame", "TerminalFrame")
AccessorFunc(PANEL, "m_bSenior",       "Senior", FORCE_BOOL)

function PANEL:Init()
    local C = CS_TERM_COLORS
    self.m_Records = {}
    self.m_bSenior = false
    self.m_InDetail = false

    -- LIST VIEW container
    self.listContainer = vgui.Create("DPanel", self)
    self.listContainer:Dock(FILL)
    self.listContainer.Paint = function() end

    -- Search + Filter bar
    local toolbar = vgui.Create("DPanel", self.listContainer)
    toolbar:Dock(TOP)
    toolbar:SetTall(28)
    toolbar:DockMargin(0, 0, 0, 4)
    toolbar.Paint = function() end

    self.searchEntry = vgui.Create("DTextEntry", toolbar)
    self.searchEntry:Dock(FILL)
    self.searchEntry:DockMargin(0, 0, 4, 0)
    self.searchEntry:SetFont("CS_Body")
    self.searchEntry:SetTextColor(C.text)
    self.searchEntry:SetCursorColor(C.textBright)
    self.searchEntry:SetHighlightColor(C.highlight)
    self.searchEntry:SetPlaceholderText("Search by name or CID...")
    self.searchEntry.Paint = function(entry, w, h)
        local C = CS_TERM_COLORS
        draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        surface.SetDrawColor(C.borderDim)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        entry:DrawTextEntryText(C.text, C.highlight, C.text)
        if entry:GetText() == "" and !entry:HasFocus() then
            draw.SimpleText("Search by name or CID...", "CS_Body", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    self.searchEntry.OnChange = function()
        self:FilterList()
    end

    self.filterCombo = vgui.Create("DComboBox", toolbar)
    self.filterCombo:Dock(RIGHT)
    self.filterCombo:SetWide(160)
    self.filterCombo:SetFont("CS_Body")
    self.filterCombo:SetTextColor(Color(0, 0, 0, 0))
    self.filterCombo:SetValue("ALL")
    self.filterCombo:AddChoice("ALL")
    self.filterCombo:AddChoice("WARRANTED")
    self.filterCombo:AddChoice("HIGH HEAT")
    self.filterCombo:AddChoice("BLACKSITE PENDING")
    self.filterCombo:AddChoice("BLACKSITE APPROVED")
    self.filterCombo:AddChoice("ACTIVE POPULACE")
    self.filterCombo.Paint = function(combo, w, h)
        local C = CS_TERM_COLORS
        draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        surface.SetDrawColor(C.borderDim)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(combo:GetValue(), "CS_Body", 6, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("v", "CS_Body", w - 10, h/2, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    self.filterCombo.OnSelect = function()
        self:FilterList()
    end

    -- Record count
    self.countLabel = vgui.Create("DPanel", self.listContainer)
    self.countLabel:Dock(BOTTOM)
    self.countLabel:SetTall(16)
    self.countLabel.m_Count = 0
    self.countLabel.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(string.format("RECORDS: %d", self2.m_Count), "CS_Small", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- List
    self.list = vgui.Create("DListView", self.listContainer)
    self.list:Dock(FILL)
    self.list:DockMargin(0, 0, 0, 0)
    self.list:SetMultiSelect(false)
    self.list.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
    end

    self.list:AddColumn("NAME"):SetWidth(160)
    self.list:AddColumn("CID"):SetWidth(65)
    self.list:AddColumn("SCANS"):SetWidth(55)
    self.list:AddColumn("LAST SCAN"):SetWidth(110)
    self.list:AddColumn("HEAT"):SetWidth(70)
    self.list:AddColumn("WARRANT"):SetWidth(80)
    self.list:AddColumn("BLACKSITE"):SetWidth(95)
    self.list:AddColumn("STATUS"):SetWidth(70)
    StyleListHeaders(self.list, C.border)

    self.list.OnRowSelected = function(_, _, row)
        local sid = row.m_SID
        if sid then
            surface.PlaySound("buttons/button15.wav")
            self:RequestDetail(sid)
        end
    end

    -- DETAIL VIEW container
    self.detailContainer = vgui.Create("CS_CitizenDetail", self)
    self.detailContainer:Dock(FILL)
    self.detailContainer:SetVisible(false)
    self.detailContainer.OnBack = function()
        self:ShowList()
    end
end

function PANEL:Populate(data)
    self.m_Records = data and data.records or {}
    self:FilterList()
    if self.detailContainer then
        self.detailContainer:SetSenior(self.m_bSenior)
        self.detailContainer:SetTerminalFrame(self.m_TerminalFrame)
    end
end

function PANEL:FilterList()
    local C = CS_TERM_COLORS
    self.list:Clear()

    local search = string.lower(self.searchEntry:GetText() or "")
    local filter = self.filterCombo:GetValue() or "ALL"
    local count  = 0

    for _, rec in ipairs(self.m_Records) do
        local show = true

        -- Search filter
        if search != "" then
            local nameLow = string.lower(rec.name or "")
            local cidStr  = tostring(rec.cid or "")
            if !string.find(nameLow, search, 1, true) and !string.find(cidStr, search, 1, true) then
                show = false
            end
        end

        -- Category filter
        if show and filter == "WARRANTED" and !rec.hasWarrant then show = false end
        if show and filter == "HIGH HEAT" and (rec.heatTier or 0) < 3 then show = false end
        if show and filter == "BLACKSITE PENDING" and !rec.bsPending then show = false end
        if show and filter == "BLACKSITE APPROVED" and !rec.bsApproved then show = false end
        if show and filter == "ACTIVE POPULACE" and !rec.isOnline then show = false end

        if show then
            local lastStr  = rec.lastScan and rec.lastScan > 0 and os.date("%H:%M %d/%m", rec.lastScan) or "NONE"
            local wStr     = rec.hasWarrant and "YES" or "NO"
            local heatStr  = string.format("T%d (%d)", rec.heatTier or 0, rec.heatScore or 0)
            local bsStr    = rec.bsApproved and "APPROVED" or (rec.bsPending and "PENDING" or "CLEAR")
            local statStr  = rec.isOnline and "ONLINE" or "OFFLINE"

            local row = self.list:AddLine(
                rec.name or "Unknown",
                tostring(rec.cid or 0),
                tostring(rec.scanCount or 0),
                lastStr, heatStr, wStr, bsStr, statStr
            )
            row.m_SID = rec.sid

            local rowCol
            if rec.bsApproved then
                rowCol = C.red
            elseif rec.hasWarrant or rec.bsPending then
                rowCol = C.yellow
            elseif (rec.heatTier or 0) >= 3 then
                rowCol = C.orange
            else
                rowCol = C.border
            end
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(rowCol); col:SetContentAlignment(5) end
            StyleRow(row, rowCol)

            count = count + 1
        end
    end

    if IsValid(self.countLabel) then
        self.countLabel.m_Count = count
    end
end

function PANEL:RequestDetail(sid)
    net.Start("CS_TerminalDetail")
        net.WriteString(sid)
    net.SendToServer()
end

function PANEL:OnCitizenDetail(detail)
    self.detailContainer:SetSenior(self.m_bSenior)
    self.detailContainer:SetDetail(detail)
    self.listContainer:SetVisible(false)
    self.detailContainer:SetVisible(true)
    self.m_InDetail = true
end

function PANEL:ShowList()
    self.listContainer:SetVisible(true)
    self.detailContainer:SetVisible(false)
    self.m_InDetail = false
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabDatabase", PANEL, "DPanel")
