
-- ============================================================
--  CS_TabScans — Recent Scans chronological log
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

local PANEL = {}

AccessorFunc(PANEL, "m_TerminalFrame", "TerminalFrame")
AccessorFunc(PANEL, "m_bSenior",       "Senior", FORCE_BOOL)

function PANEL:Init()
    local C = CS_TERM_COLORS

    -- Title
    local titleBar = vgui.Create("DPanel", self)
    titleBar:Dock(TOP)
    titleBar:SetTall(22)
    titleBar.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText("SCAN LOG — LAST 50 ENTRIES", "CS_BodyBold", 4, h/2, C.textBright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, h - 1, w, 1)
    end

    self.list = vgui.Create("DListView", self)
    self.list:Dock(FILL)
    self.list:SetMultiSelect(false)
    self.list.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
    end

    self.list:AddColumn("TIME"):SetWidth(120)
    self.list:AddColumn("CITIZEN"):SetWidth(180)
    self.list:AddColumn("CID"):SetWidth(65)
    self.list:AddColumn("OFFICER"):SetWidth(180)
    self.list:AddColumn("HEAT"):SetWidth(60)
    self.list:AddColumn("GRID"):SetWidth(100)
    StyleListHeaders(self.list, C.border)

    self.list.OnRowSelected = function(_, _, row)
        local sid = row.m_SID
        if sid and IsValid(self.m_TerminalFrame) then
            local dbTab = self.m_TerminalFrame:GetTabPanel("DATABASE")
            if IsValid(dbTab) then
                surface.PlaySound("buttons/button15.wav")
                dbTab:RequestDetail(sid)
                self.m_TerminalFrame:SwitchTab("DATABASE")
                self.m_TerminalFrame.tabBar:SelectTab("DATABASE")
            end
        end
    end
end

function PANEL:Populate(data)
    local C = CS_TERM_COLORS
    self.list:Clear()
    local scans = data and data.recentScans or {}

    for _, scan in ipairs(scans) do
        local timeStr = scan.time and scan.time > 0 and os.date("%H:%M %d/%m/%Y", scan.time) or "N/A"
        local heatStr = string.format("T%d", scan.heatTier or 0)
        local row = self.list:AddLine(
            timeStr, scan.name or "Unknown", tostring(scan.cid or 0),
            scan.officer or "Unknown", heatStr, scan.grid or "N/A"
        )
        row.m_SID = scan.sid

        local tier = scan.heatTier or 0
        local rowCol = tier >= 4 and C.red or (tier >= 3 and C.orange or (tier >= 2 and C.yellow or C.border))
        for _, col in pairs(row.Columns or {}) do col:SetTextColor(rowCol); col:SetContentAlignment(5) end
        row.Paint = function(self2, w, h)
            if self2:IsSelected() then
                surface.SetDrawColor(Color(rowCol.r, rowCol.g, rowCol.b, 60))
                surface.DrawRect(0, 0, w, h)
            elseif self2:IsHovered() then
                surface.SetDrawColor(Color(rowCol.r, rowCol.g, rowCol.b, 30))
                surface.DrawRect(0, 0, w, h)
            end
        end
    end
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabScans", PANEL, "DPanel")
