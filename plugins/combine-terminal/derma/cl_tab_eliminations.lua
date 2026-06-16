
-- ============================================================
--  CS_TabEliminations — Confirmed sterilization log
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

function PANEL:Init() end

function PANEL:Populate(data)
    self:Clear()
    local C      = CS_TERM_COLORS
    local elims  = data and data.eliminations or {}

    local header = vgui.Create("DPanel", self)
    header:Dock(TOP)
    header:SetTall(22)
    header.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(string.format("CONFIRMED STERILIZATIONS — %d TOTAL", #elims), "CS_BodyBold", 4, h/2, C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C.red)
        surface.DrawRect(0, h - 1, w, 1)
    end

    if #elims > 0 then
        local list = vgui.Create("DListView", self)
        list:Dock(FILL)
        list:SetMultiSelect(false)
        list.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        end

        list:AddColumn("TIME"):SetWidth(130)
        list:AddColumn("SUBJECT"):SetWidth(200)
        list:AddColumn("CID"):SetWidth(65)
        list:AddColumn("OFFICER"):SetWidth(200)
        list:AddColumn("EFF."):SetWidth(40)
        StyleListHeaders(list, C.red)

        local rowCol = C.red
        for i = #elims, math.max(1, #elims - 99), -1 do
            local e = elims[i]
            local timeStr = e.time and e.time > 0 and os.date("%H:%M %d/%m/%Y", e.time) or "N/A"
            local row = list:AddLine(timeStr, e.name or "Unknown", tostring(e.cid or 0), e.officer or "Unknown", tostring(e.officerCID or ""))
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(rowCol); col:SetContentAlignment(5) end
            row.Paint = function(self2, w, h)
                if self2:IsHovered() then
                    surface.SetDrawColor(Color(rowCol.r, rowCol.g, rowCol.b, 20))
                    surface.DrawRect(0, 0, w, h)
                end
            end
        end
    else
        local empty = vgui.Create("DPanel", self)
        empty:Dock(TOP)
        empty:SetTall(28)
        empty.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No confirmed sterilizations on record.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabEliminations", PANEL, "DPanel")
