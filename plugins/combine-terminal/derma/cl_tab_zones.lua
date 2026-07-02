
-- ============================================================
--  CS_TabZones — Zones & Checkpoints tab
-- ============================================================

local function SendAction(action, data)
    net.Start("CS_TerminalAction")
        net.WriteString(action)
        net.WriteString(util.TableToJSON(data))
    net.SendToServer()
end

local function GetGridFromPos(pos)
    if type(pos) == "table" then
        return string.format("%d,%d", math.floor((pos.x or 0) / 512), math.floor((pos.y or 0) / 512))
    end
    return "N/A"
end

local function PaintEntry(s2, w, h)
    local C = CS_TERM_COLORS
    draw.RoundedBox(0, 0, 0, w, h, C.bg)
    surface.SetDrawColor(C.borderDim)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
    s2:DrawTextEntryText(C.text, C.highlight, C.textBright)
end

local function MakeManageBtn(parent, label, wide, doClick)
    local btn = vgui.Create("DButton", parent)
    btn:Dock(LEFT)
    btn:SetWide(wide)
    btn:DockMargin(0, 4, 4, 4)
    btn:SetText("")
    btn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        doClick()
    end
    btn.Paint = function(s2, w, h)
        local C = CS_TERM_COLORS
        local bg = s2:IsHovered() and C.highlight or C.bgDark
        draw.RoundedBox(0, 0, 0, w, h, bg)
        surface.SetDrawColor(C.borderDim)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(label, "CS_Small", w/2, h/2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return btn
end

local PANEL = {}

AccessorFunc(PANEL, "m_TerminalFrame", "TerminalFrame")
AccessorFunc(PANEL, "m_bSenior",       "Senior", FORCE_BOOL)

function PANEL:Init() end

function PANEL:Populate(data)
    self:Clear()
    self.m_ZoneList       = nil
    self.m_CheckpointList = nil
    local C = CS_TERM_COLORS
    local zoneData    = data and data.zones or {}
    local zones       = zoneData.zones or {}
    local checkpoints = zoneData.checkpoints or {}

    -- ==================== RESTRICTED ZONES ====================
    local zHeader = vgui.Create("DPanel", self)
    zHeader:Dock(TOP)
    zHeader:SetTall(22)
    zHeader:DockMargin(0, 0, 0, 2)
    zHeader.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(string.format("RESTRICTED ZONES (%d)", #zones), "CS_BodyBold", 4, h/2, C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, h - 1, w, 1)
    end

    if #zones > 0 then
        local zList = vgui.Create("DListView", self)
        zList:Dock(TOP)
        zList:SetTall(math.min(#zones * 20 + 24, 200))
        zList:SetMultiSelect(false)
        zList.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        end

        zList:AddColumn("NAME"):SetWidth(250)
        zList:AddColumn("GRID"):SetWidth(120)
        zList:AddColumn("RADIUS"):SetWidth(100)
        CS_StyleListHeaders(zList, C.red)

        for _, zone in ipairs(zones) do
            local row = zList:AddLine(
                zone.name or "Unnamed",
                GetGridFromPos(zone.pos),
                tostring(zone.radius or 0) .. " units"
            )
            row.m_Name = zone.name or "Unnamed"
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(C.red); col:SetContentAlignment(5) end
            row.Paint = function(self2, w, h)
                local C = CS_TERM_COLORS
                if self2:IsHovered() then
                    surface.SetDrawColor(Color(C.red.r, C.red.g, C.red.b, 20))
                    surface.DrawRect(0, 0, w, h)
                end
            end
        end
        self.m_ZoneList = zList
    else
        local noZones = vgui.Create("DPanel", self)
        noZones:Dock(TOP)
        noZones:SetTall(28)
        noZones.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No restricted zones defined.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Zone management (senior only)
    if self.m_bSenior then
        local zmRow = vgui.Create("DPanel", self)
        zmRow:Dock(TOP)
        zmRow:SetTall(32)
        zmRow:DockMargin(0, 2, 0, 0)
        zmRow.Paint = function(s2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
            draw.SimpleText("ZONE MGMT", "CS_Small", 6, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local zmName = vgui.Create("DTextEntry", zmRow)
        zmName:Dock(LEFT)
        zmName:SetWide(175)
        zmName:DockMargin(80, 4, 4, 4)
        zmName:SetFont("CS_Small")
        zmName:SetPlaceholderText("ZONE NAME")
        zmName.Paint = PaintEntry

        local zmRad = vgui.Create("DTextEntry", zmRow)
        zmRad:Dock(LEFT)
        zmRad:SetWide(55)
        zmRad:DockMargin(0, 4, 4, 4)
        zmRad:SetFont("CS_Small")
        zmRad:SetPlaceholderText("RADIUS")
        zmRad.Paint = PaintEntry

        MakeManageBtn(zmRow, "ADD ZONE", 90, function()
            local name = string.Trim(zmName:GetValue())
            local rad  = tonumber(zmRad:GetValue()) or 256
            if name == "" then return end
            SendAction("addZone", {name = name, radius = rad})
        end)
        MakeManageBtn(zmRow, "REMOVE SELECTED", 140, function()
            if !self.m_ZoneList or !IsValid(self.m_ZoneList) then return end
            local sel = self.m_ZoneList:GetSelected()
            if !sel or #sel == 0 then return end
            local row = sel[1]
            if row and row.m_Name then
                SendAction("removeZone", {name = row.m_Name})
            end
        end)
    end

    -- Spacer
    local spacer = vgui.Create("DPanel", self)
    spacer:Dock(TOP)
    spacer:SetTall(12)
    spacer.Paint = function() end

    -- ==================== CHECKPOINTS ====================
    local cpHeader = vgui.Create("DPanel", self)
    cpHeader:Dock(TOP)
    cpHeader:SetTall(22)
    cpHeader:DockMargin(0, 0, 0, 2)
    cpHeader.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(string.format("CHECKPOINTS (%d)", #checkpoints), "CS_BodyBold", 4, h/2, C.border, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, h - 1, w, 1)
    end

    if #checkpoints > 0 then
        local cpList = vgui.Create("DListView", self)
        cpList:Dock(TOP)
        cpList:SetTall(math.min(#checkpoints * 20 + 24, 200))
        cpList:SetMultiSelect(false)
        cpList.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        end

        cpList:AddColumn("NAME"):SetWidth(250)
        cpList:AddColumn("GRID"):SetWidth(120)
        cpList:AddColumn("RADIUS"):SetWidth(100)
        CS_StyleListHeaders(cpList, C.border)

        for _, cp in ipairs(checkpoints) do
            local row = cpList:AddLine(
                cp.name or "Unnamed",
                GetGridFromPos(cp.pos),
                tostring(cp.radius or 0) .. " units"
            )
            row.m_Name = cp.name or "Unnamed"
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(C.border); col:SetContentAlignment(5) end
            row.Paint = function(self2, w, h)
                local C = CS_TERM_COLORS
                if self2:IsHovered() then
                    surface.SetDrawColor(C.hover)
                    surface.DrawRect(0, 0, w, h)
                end
            end
        end
        self.m_CheckpointList = cpList
    else
        local noCP = vgui.Create("DPanel", self)
        noCP:Dock(TOP)
        noCP:SetTall(28)
        noCP.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No checkpoints defined.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Checkpoint management (senior only)
    if self.m_bSenior then
        local cpMRow = vgui.Create("DPanel", self)
        cpMRow:Dock(TOP)
        cpMRow:SetTall(32)
        cpMRow:DockMargin(0, 2, 0, 0)
        cpMRow.Paint = function(s2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
            draw.SimpleText("CHECKPOINT MGMT", "CS_Small", 6, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local cpName = vgui.Create("DTextEntry", cpMRow)
        cpName:Dock(LEFT)
        cpName:SetWide(175)
        cpName:DockMargin(110, 4, 4, 4)
        cpName:SetFont("CS_Small")
        cpName:SetPlaceholderText("CHECKPOINT NAME")
        cpName.Paint = PaintEntry

        local cpRad = vgui.Create("DTextEntry", cpMRow)
        cpRad:Dock(LEFT)
        cpRad:SetWide(55)
        cpRad:DockMargin(0, 4, 4, 4)
        cpRad:SetFont("CS_Small")
        cpRad:SetPlaceholderText("RADIUS")
        cpRad.Paint = PaintEntry

        MakeManageBtn(cpMRow, "ADD CHECKPOINT", 115, function()
            local name = string.Trim(cpName:GetValue())
            local rad  = tonumber(cpRad:GetValue()) or 256
            if name == "" then return end
            SendAction("addCheckpoint", {name = name, radius = rad})
        end)
        MakeManageBtn(cpMRow, "REMOVE SELECTED", 140, function()
            if !self.m_CheckpointList or !IsValid(self.m_CheckpointList) then return end
            local sel = self.m_CheckpointList:GetSelected()
            if !sel or #sel == 0 then return end
            local row = sel[1]
            if row and row.m_Name then
                SendAction("removeCheckpoint", {name = row.m_Name})
            end
        end)
    end

    -- Spacer
    local logSpacer = vgui.Create("DPanel", self)
    logSpacer:Dock(TOP)
    logSpacer:SetTall(12)
    logSpacer.Paint = function() end

    -- ==================== CROSSING LOG ====================
    local crossingLog = zoneData.crossingLog or {}
    local logTotal    = #crossingLog

    local clHeader = vgui.Create("DPanel", self)
    clHeader:Dock(TOP)
    clHeader:SetTall(22)
    clHeader:DockMargin(0, 0, 0, 2)
    clHeader.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText("CROSSING LOG", "CS_BodyBold", 4, h/2, C.borderDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, h - 1, w, 1)
    end

    if logTotal > 0 then
        local shown   = math.min(logTotal, 25)
        local clList  = vgui.Create("DListView", self)
        clList:Dock(TOP)
        clList:SetTall(math.min(shown * 20 + 24, 200))
        clList:SetMultiSelect(false)
        clList.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        end

        clList:AddColumn("TIME"):SetWidth(80)
        clList:AddColumn("CITIZEN"):SetWidth(150)
        clList:AddColumn("CHECKPOINT"):SetWidth(150)
        clList:AddColumn("STATUS"):SetWidth(90)
        CS_StyleListHeaders(clList, C.borderDim)

        for i = logTotal, math.max(1, logTotal - 24), -1 do
            local entry = crossingLog[i]
            local timeStr = os.date("%H:%M", entry.time or 0)
            local statusStr, rowColor
            if entry.wasWanted then
                statusStr = "WANTED"
                rowColor  = C.red
            elseif entry.hadClearance then
                statusStr = "CLEARED"
                rowColor  = C.text
            else
                statusStr = "SUSPICIOUS"
                rowColor  = C.yellow
            end
            local row = clList:AddLine(timeStr, entry.name or "Unknown", entry.checkpoint or "Unknown", statusStr)
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(rowColor); col:SetContentAlignment(5) end
            row.Paint = function(self2, w, h)
                if self2:IsHovered() then
                    surface.SetDrawColor(Color(rowColor.r, rowColor.g, rowColor.b, 20))
                    surface.DrawRect(0, 0, w, h)
                end
            end
        end
    else
        local noLog = vgui.Create("DPanel", self)
        noLog:Dock(TOP)
        noLog:SetTall(28)
        noLog.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No crossing records.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    if !self.m_bSenior then
        local hint = vgui.Create("DPanel", self)
        hint:Dock(BOTTOM)
        hint:SetTall(16)
        hint.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("Sector management is restricted to senior Combine officers.", "CS_Small", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabZones", PANEL, "DPanel")
