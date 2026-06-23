
-- ============================================================
--  CS_TabUnits — Active Combine Units tab
-- ============================================================

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

    -- Curfew control bar — docked BOTTOM before FILL so layout is correct
    self.curfewBar = vgui.Create("DPanel", self)
    self.curfewBar:Dock(BOTTOM)
    self.curfewBar:SetTall(38)
    self.curfewBar:DockMargin(0, 4, 0, 0)
    self.curfewBar:SetVisible(false)
    self.curfewBar.Paint = function(s2, w, h)
        local C = CS_TERM_COLORS
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, 0, w, 1)
        draw.SimpleText("CURFEW CONTROL", "CS_Small", 6, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    self.btnCurfew = vgui.Create("DButton", self.curfewBar)
    self.btnCurfew:Dock(RIGHT)
    self.btnCurfew:SetWide(180)
    self.btnCurfew:DockMargin(0, 6, 0, 6)
    self.btnCurfew:SetText("")
    self.btnCurfew.m_Label    = "ACTIVATE CURFEW"
    self.btnCurfew.m_IsActive = false
    self.btnCurfew.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        SendAction("toggleCurfew", {})
    end
    self.btnCurfew.Paint = function(s2, w, h)
        local C   = CS_TERM_COLORS
        local col = s2.m_IsActive and C.good or C.yellow
        local bg  = s2:IsHovered() and Color(col.r, col.g, col.b, 40) or C.bgDark
        draw.RoundedBox(0, 0, 0, w, h, bg)
        surface.SetDrawColor(col)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(s2.m_Label, "CS_BodyBold", w/2, h/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
    self.list:AddColumn("ZONE"):SetWidth(160)
    self.list:AddColumn("SCANS"):SetWidth(55)
    CS_StyleListHeaders(self.list, C.border)
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
            unit.zone or "N/A",
            tostring(unit.scanCount or 0)
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

    if self.m_bSenior then
        self.curfewBar:SetVisible(true)
        local active = data and data.curfewActive or false
        self.btnCurfew.m_Label    = active and "LIFT CURFEW" or "ACTIVATE CURFEW"
        self.btnCurfew.m_IsActive = active
    end
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabUnits", PANEL, "DPanel")
