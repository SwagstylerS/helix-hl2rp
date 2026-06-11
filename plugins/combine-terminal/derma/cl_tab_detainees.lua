
-- ============================================================
--  CS_TabDetainees — Detainee transfer log
-- ============================================================

local C = CS_TERM_COLORS

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

function PANEL:Init() end

function PANEL:Populate(data)
    self:Clear()
    local C = CS_TERM_COLORS
    local detainees = (data and data.detainees) or {}
    local total      = #detainees

    local header = vgui.Create("DPanel", self)
    header:Dock(TOP)
    header:SetTall(22)
    header:DockMargin(0, 0, 0, 2)
    header.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(string.format("DETAINEE TRANSFERS (%d)", total), "CS_BodyBold", 4, h/2, C.borderDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, h - 1, w, 1)
    end

    if total > 0 then
        local shown = math.min(total, 50)
        local list  = vgui.Create("DListView", self)
        list:Dock(TOP)
        list:SetTall(math.min(shown * 20 + 24, 400))
        list:SetMultiSelect(false)
        list.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        end

        list:AddColumn("TIME"):SetWidth(80):SetFixedWidth(true)
        list:AddColumn("NAME"):SetWidth(140)
        list:AddColumn("CID"):SetWidth(60):SetFixedWidth(true)
        list:AddColumn("OFFICER"):SetWidth(130)
        StyleListHeaders(list, C.borderDim)

        local now = os.time()
        for i = total, math.max(1, total - 49), -1 do
            local entry    = detainees[i]
            local timeStr  = os.date("%H:%M", entry.time or 0)
            local rowColor = C.text
            if (now - (entry.time or 0)) < 3600 then
                rowColor = C.orange
            end
            local row = list:AddLine(timeStr, entry.name or "Unknown", tostring(entry.cid or 0), entry.officer or "Unknown")
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
            draw.SimpleText("No detainee transfers logged.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabDetainees", PANEL, "Panel")
