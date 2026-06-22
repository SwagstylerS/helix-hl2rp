
-- ============================================================
--  CS_TabDetainees — Detainee transfer log
-- ============================================================

local C = CS_TERM_COLORS

local function SendAction(action, data)
    net.Start("CS_TerminalAction")
        net.WriteString(action)
        net.WriteString(util.TableToJSON(data))
    net.SendToServer()
end

local function MakeActionButton(parent, label, onClick, color)
    local btn = vgui.Create("DButton", parent)
    btn:SetTall(26)
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

local PANEL = {}

AccessorFunc(PANEL, "m_TerminalFrame", "TerminalFrame")
AccessorFunc(PANEL, "m_bSenior",       "Senior", FORCE_BOOL)

function PANEL:Init() end

function PANEL:Populate(data)
    self:Clear()
    self.m_DetaineeList = nil
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
        list:AddColumn("STATUS"):SetWidth(80):SetFixedWidth(true)
        CS_StyleListHeaders(list, C.borderDim)

        local now = os.time()
        for i = total, math.max(1, total - 49), -1 do
            local entry    = detainees[i]
            local timeStr  = os.date("%H:%M", entry.time or 0)
            local status   = entry.status or "DETAINED"
            local rowColor
            if status == "RELEASED" then
                rowColor = C.good
            elseif status == "DETAINED" then
                rowColor = C.red
            else
                rowColor = (now - (entry.time or 0)) < 3600 and C.orange or C.text
            end
            local row = list:AddLine(timeStr, entry.name or "Unknown", tostring(entry.cid or 0), entry.officer or "Unknown", status)
            row.m_SID = entry.sid
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(rowColor); col:SetContentAlignment(5) end
            row.Paint = function(self2, w, h)
                if self2:IsSelected() then
                    surface.SetDrawColor(Color(rowColor.r, rowColor.g, rowColor.b, 60))
                    surface.DrawRect(0, 0, w, h)
                elseif self2:IsHovered() then
                    surface.SetDrawColor(Color(rowColor.r, rowColor.g, rowColor.b, 20))
                    surface.DrawRect(0, 0, w, h)
                end
            end
        end
        self.m_DetaineeList = list
    else
        local noLog = vgui.Create("DPanel", self)
        noLog:Dock(TOP)
        noLog:SetTall(28)
        noLog.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No detainee transfers logged.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Button bar
    local spacer = vgui.Create("DPanel", self)
    spacer:Dock(TOP)
    spacer:SetTall(6)
    spacer.Paint = function() end

    local btnRow = vgui.Create("DPanel", self)
    btnRow:Dock(TOP)
    btnRow:SetTall(32)
    btnRow.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, 0, w, 1)
    end

    local onlineCitizens = (data and data.onlineCitizens) or {}
    local detainList = self.m_DetaineeList

    local detainBtn = MakeActionButton(btnRow, "LOG DETENTION", function()
        if #onlineCitizens == 0 then return end

        local frame = vgui.Create("DFrame")
        frame:SetSize(340, 280)
        frame:Center()
        frame:SetTitle("")
        frame:SetDraggable(true)
        frame:MakePopup()
        frame.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bg)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
            surface.DrawRect(0, 20, w, 1)
            draw.SimpleText("LOG DETENTION — SELECT SUBJECT", "CS_BodyBold", w/2, 10, C.textBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local confirmBtn = vgui.Create("DButton", frame)
        confirmBtn:Dock(BOTTOM)
        confirmBtn:DockMargin(6, 0, 6, 6)
        confirmBtn:SetTall(26)
        confirmBtn:SetText("")
        confirmBtn.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            local bg = self2:IsHovered() and Color(C.red.r, C.red.g, C.red.b, 40) or C.bgDark
            draw.RoundedBox(0, 0, 0, w, h, bg)
            surface.SetDrawColor(C.red)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("CONFIRM DETENTION", "CS_BodyBold", w/2, h/2, C.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local pickList = vgui.Create("DListView", frame)
        pickList:Dock(FILL)
        pickList:DockMargin(6, 28, 6, 4)
        pickList:SetMultiSelect(false)
        pickList.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        end
        pickList:AddColumn("SUBJECT NAME"):SetWidth(290)
        CS_StyleListHeaders(pickList, C.border)

        for _, cit in ipairs(onlineCitizens) do
            local row = pickList:AddLine(cit.name or "Unknown")
            row.m_SID  = cit.sid
            row.m_Name = cit.name or "Unknown"
            local rowC = C.text
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(rowC); col:SetContentAlignment(5) end
            row.Paint = function(self2, w, h)
                local C = CS_TERM_COLORS
                if self2:IsSelected() then
                    surface.SetDrawColor(Color(C.border.r, C.border.g, C.border.b, 60))
                    surface.DrawRect(0, 0, w, h)
                elseif self2:IsHovered() then
                    surface.SetDrawColor(Color(C.border.r, C.border.g, C.border.b, 20))
                    surface.DrawRect(0, 0, w, h)
                end
            end
        end

        confirmBtn.DoClick = function()
            local selected = pickList:GetSelected()
            if !selected or #selected == 0 then return end
            local row = selected[1]
            if row and row.m_SID then
                surface.PlaySound("buttons/button15.wav")
                SendAction("detainCitizen", {sid = row.m_SID, name = row.m_Name})
                frame:Remove()
            end
        end
    end, C.red)
    detainBtn:Dock(LEFT)
    detainBtn:SetWide(160)
    detainBtn:DockMargin(0, 3, 4, 3)

    local releaseBtn = MakeActionButton(btnRow, "LOG RELEASE", function()
        if !detainList or !IsValid(detainList) then return end
        local selected = detainList:GetSelected()
        if !selected or #selected == 0 then return end
        local row = selected[1]
        if row and row.m_SID then
            SendAction("releaseCitizen", {sid = row.m_SID})
        end
    end, C.good)
    releaseBtn:Dock(LEFT)
    releaseBtn:SetWide(160)
    releaseBtn:DockMargin(0, 3, 0, 3)
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabDetainees", PANEL, "Panel")
