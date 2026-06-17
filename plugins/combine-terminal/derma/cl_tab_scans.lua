
-- ============================================================
--  CS_TabScans — Biometric scan log + checkpoint crossing log
-- ============================================================


local PANEL = {}

AccessorFunc(PANEL, "m_TerminalFrame", "TerminalFrame")
AccessorFunc(PANEL, "m_bSenior",       "Senior", FORCE_BOOL)

function PANEL:Init() end

function PANEL:Populate(data)
    self:Clear()
    local C = CS_TERM_COLORS
    local scans      = data and data.recentScans or {}
    local zoneData   = data and data.zones or {}
    local crossings  = zoneData.crossingLog or {}

    -- ==================== SCAN LOG ====================
    local scanHeader = vgui.Create("DPanel", self)
    scanHeader:Dock(TOP)
    scanHeader:SetTall(22)
    scanHeader.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(string.format("SCAN LOG — LAST %d ENTRIES", #scans), "CS_BodyBold", 4, h/2, C.textBright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, h - 1, w, 1)
    end

    if #scans > 0 then
        local scanList = vgui.Create("DListView", self)
        scanList:Dock(TOP)
        scanList:SetTall(math.min(#scans * 20 + 24, 300))
        scanList:SetMultiSelect(false)
        scanList.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        end

        scanList:AddColumn("TIME"):SetWidth(120)
        scanList:AddColumn("CITIZEN"):SetWidth(180)
        scanList:AddColumn("CID"):SetWidth(65)
        scanList:AddColumn("OFFICER"):SetWidth(180)
        scanList:AddColumn("HEAT"):SetWidth(60)
        scanList:AddColumn("GRID"):SetWidth(100)
        CS_StyleListHeaders(scanList, C.border)

        scanList.OnRowSelected = function(_, _, row)
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

        for _, scan in ipairs(scans) do
            local timeStr = scan.time and scan.time > 0 and os.date("%H:%M %d/%m/%Y", scan.time) or "N/A"
            local heatStr = string.format("T%d", scan.heatTier or 0)
            local row = scanList:AddLine(
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
    else
        local noScans = vgui.Create("DPanel", self)
        noScans:Dock(TOP)
        noScans:SetTall(28)
        noScans.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No scans recorded.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- ==================== CHECKPOINT CROSSINGS ====================
    local spacer = vgui.Create("DPanel", self)
    spacer:Dock(TOP)
    spacer:SetTall(10)
    spacer.Paint = function() end

    local cpHeader = vgui.Create("DPanel", self)
    cpHeader:Dock(TOP)
    cpHeader:SetTall(22)
    cpHeader.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(string.format("CHECKPOINT CROSSINGS (%d)", #crossings), "CS_BodyBold", 4, h/2, C.borderDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, h - 1, w, 1)
    end

    if #crossings > 0 then
        local shown  = math.min(#crossings, 25)
        local cpList = vgui.Create("DListView", self)
        cpList:Dock(TOP)
        cpList:SetTall(math.min(shown * 20 + 24, 220))
        cpList:SetMultiSelect(false)
        cpList.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        end

        cpList:AddColumn("TIME"):SetWidth(80)
        cpList:AddColumn("CITIZEN"):SetWidth(180)
        cpList:AddColumn("CHECKPOINT"):SetWidth(180)
        cpList:AddColumn("STATUS"):SetWidth(100)
        CS_StyleListHeaders(cpList, C.borderDim)

        local total = #crossings
        for i = total, math.max(1, total - 24), -1 do
            local entry     = crossings[i]
            local timeStr   = os.date("%H:%M", entry.time or 0)
            local statusStr, rowCol
            if entry.wasWanted then
                statusStr = "WANTED"
                rowCol    = C.red
            elseif entry.hadClearance then
                statusStr = "CLEARED"
                rowCol    = C.border
            else
                statusStr = "SUSPICIOUS"
                rowCol    = C.yellow
            end
            local row = cpList:AddLine(timeStr, entry.name or "Unknown", entry.checkpoint or "Unknown", statusStr)
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(rowCol); col:SetContentAlignment(5) end
            row.Paint = function(self2, w, h)
                if self2:IsHovered() then
                    surface.SetDrawColor(Color(rowCol.r, rowCol.g, rowCol.b, 20))
                    surface.DrawRect(0, 0, w, h)
                end
            end
        end
    else
        local noCP = vgui.Create("DPanel", self)
        noCP:Dock(TOP)
        noCP:SetTall(28)
        noCP.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No checkpoint crossings recorded.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabScans", PANEL, "DPanel")
