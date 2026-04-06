
-- ============================================================
--  CS_TabUnits — Active Combine Units tab
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

    -- Summary bar
    self.summary = vgui.Create("DPanel", self)
    self.summary:Dock(TOP)
    self.summary:SetTall(24)
    self.summary:DockMargin(0, 0, 0, 4)
    self.summary.m_Total = 0
    self.summary.m_Alive = 0
    self.summary.m_KIA = 0
    self.summary.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(
            string.format("TOTAL DEPLOYED: %d  |  ACTIVE: %d  |  KIA: %d",
                self2.m_Total, self2.m_Alive, self2.m_KIA),
            "CS_BodyBold", w/2, h/2, C.textBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
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

    self.list:AddColumn("DESIGNATION"):SetWidth(200)
    self.list:AddColumn("RANK"):SetWidth(160)
    self.list:AddColumn("FACTION"):SetWidth(70)
    self.list:AddColumn("STATUS"):SetWidth(80)
    self.list:AddColumn("ZONE"):SetWidth(200)
    StyleListHeaders(self.list, C.border)
end

function PANEL:Populate(data)
    local C = CS_TERM_COLORS
    self.list:Clear()
    local units = data and data.units or {}
    local alive, kia = 0, 0

    for _, unit in ipairs(units) do
        local statusStr = unit.alive and "ACTIVE" or "KIA"
        if unit.alive then alive = alive + 1 else kia = kia + 1 end

        local seniorTag = unit.isSenior and " [SR]" or ""
        local row = self.list:AddLine(
            (unit.name or "Unknown") .. seniorTag,
            unit.rank or "Unknown",
            unit.faction or "?",
            statusStr,
            unit.zone or "N/A"
        )

        local rowCol = unit.alive and C.border or C.red
        for _, col in pairs(row.Columns or {}) do col:SetTextColor(rowCol); col:SetContentAlignment(5) end
        local unitAlive = unit.alive
        row.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            if self2:IsSelected() then
                surface.SetDrawColor(Color(rowCol.r, rowCol.g, rowCol.b, 60))
                surface.DrawRect(0, 0, w, h)
            elseif self2:IsHovered() then
                surface.SetDrawColor(Color(rowCol.r, rowCol.g, rowCol.b, 30))
                surface.DrawRect(0, 0, w, h)
            end
            if !unitAlive then
                surface.SetDrawColor(Color(C.red.r, C.red.g, C.red.b, 15))
                surface.DrawRect(0, 0, w, h)
            end
        end
    end

    self.summary.m_Total = #units
    self.summary.m_Alive = alive
    self.summary.m_KIA   = kia
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabUnits", PANEL, "DPanel")
