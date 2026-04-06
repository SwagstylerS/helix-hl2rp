
-- ============================================================
--  CS_TabZones — Zones & Checkpoints tab
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

local function GetGridFromPos(pos)
    if type(pos) == "table" then
        return string.format("%d,%d", math.floor((pos.x or 0) / 512), math.floor((pos.y or 0) / 512))
    end
    return "N/A"
end

local PANEL = {}

AccessorFunc(PANEL, "m_TerminalFrame", "TerminalFrame")
AccessorFunc(PANEL, "m_bSenior",       "Senior", FORCE_BOOL)

function PANEL:Init() end

function PANEL:Populate(data)
    self:Clear()
    local C = CS_TERM_COLORS
    local zoneData = data and data.zones or {}
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
        StyleListHeaders(zList, C.red)

        for _, zone in ipairs(zones) do
            local row = zList:AddLine(
                zone.name or "Unnamed",
                GetGridFromPos(zone.pos),
                tostring(zone.radius or 0) .. " units"
            )
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(C.red); col:SetContentAlignment(5) end
            row.Paint = function(self2, w, h)
                local C = CS_TERM_COLORS
                if self2:IsHovered() then
                    surface.SetDrawColor(Color(C.red.r, C.red.g, C.red.b, 20))
                    surface.DrawRect(0, 0, w, h)
                end
            end
        end
    else
        local noZones = vgui.Create("DPanel", self)
        noZones:Dock(TOP)
        noZones:SetTall(28)
        noZones.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No restricted zones defined.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
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
        StyleListHeaders(cpList, C.border)

        for _, cp in ipairs(checkpoints) do
            local row = cpList:AddLine(
                cp.name or "Unnamed",
                GetGridFromPos(cp.pos),
                tostring(cp.radius or 0) .. " units"
            )
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(C.border); col:SetContentAlignment(5) end
            row.Paint = function(self2, w, h)
                local C = CS_TERM_COLORS
                if self2:IsHovered() then
                    surface.SetDrawColor(C.hover)
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
            draw.SimpleText("No checkpoints defined.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Admin hint
    local hint = vgui.Create("DPanel", self)
    hint:Dock(BOTTOM)
    hint:SetTall(16)
    hint.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText("Zones and checkpoints are managed via admin commands.", "CS_Small", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabZones", PANEL, "DPanel")
