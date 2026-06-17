
-- ============================================================
--  CS_TabCWU — CWU Clearance Requests tab
-- ============================================================

local function MakeActionButton(parent, label, onClick, color)
    local btn = vgui.Create("DButton", parent)
    btn:SetTall(22)
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

local function SendAction(action, data)
    net.Start("CS_TerminalAction")
        net.WriteString(action)
        net.WriteString(util.TableToJSON(data))
    net.SendToServer()
end


local PANEL = {}

AccessorFunc(PANEL, "m_TerminalFrame", "TerminalFrame")
AccessorFunc(PANEL, "m_bSenior",       "Senior", FORCE_BOOL)

function PANEL:Init() end

function PANEL:Populate(data)
    self:Clear()
    local C = CS_TERM_COLORS

    local requests = data and data.cwuRequests or {}

    -- Title
    local titleBar = vgui.Create("DPanel", self)
    titleBar:Dock(TOP)
    titleBar:SetTall(22)
    titleBar.Paint = function(self2, w, h)
        local C = CS_TERM_COLORS
        draw.SimpleText(string.format("PENDING CLEARANCE REQUESTS (%d)", #requests), "CS_BodyBold", 4, h/2, C.textBright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C.borderDim)
        surface.DrawRect(0, h - 1, w, 1)
    end

    if #requests == 0 then
        local noReq = vgui.Create("DPanel", self)
        noReq:Dock(TOP)
        noReq:SetTall(28)
        noReq.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No pending clearance requests.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    else

    local scroll = vgui.Create("DScrollPanel", self)
    scroll:Dock(TOP)
    scroll:SetTall(math.min(#requests * 34, 200))
    scroll:GetVBar():SetWide(0)

    for _, req in ipairs(requests) do
        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP)
        row:SetTall(32)
        row:DockMargin(0, 0, 0, 2)

        local timeStr = "N/A"
        if req.time and req.time > 0 then
            local elapsed = math.floor(CurTime() - req.time)
            local mins = math.floor(elapsed / 60)
            timeStr = string.format("%d min ago", mins)
        end

        row.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
            surface.SetDrawColor(C.borderDim)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(req.name or "Unknown", "CS_Body", 8, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(timeStr, "CS_Body", 248, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local btnPanel = vgui.Create("DPanel", row)
        btnPanel:Dock(RIGHT)
        btnPanel:SetWide(200)
        btnPanel:DockMargin(4, 4, 4, 4)
        btnPanel.Paint = function() end

        local approveBtn = MakeActionButton(btnPanel, "APPROVE", function()
            SendAction("approveClearance", {sid = req.sid})
        end, C.border)
        approveBtn:Dock(LEFT)
        approveBtn:SetWide(90)
        approveBtn:DockMargin(0, 0, 4, 0)

        local denyBtn = MakeActionButton(btnPanel, "DENY", function()
            SendAction("denyClearance", {sid = req.sid})
        end, C.red)
        denyBtn:Dock(LEFT)
        denyBtn:SetWide(90)
    end
    end

    local history = data and data.clearanceHistory or {}
    local total   = #history

    local histHeader = vgui.Create("DLabel", self)
    histHeader:Dock(TOP)
    histHeader:DockMargin(0, 8, 0, 2)
    histHeader:SetTall(20)
    histHeader:SetText("CLEARANCE HISTORY")
    histHeader:SetFont("CS_BodyBold")
    histHeader:SetTextColor(C.borderDim)
    histHeader:SetContentAlignment(4)

    if total > 0 then
        local shown = math.min(total, 50)
        local histList = vgui.Create("DListView", self)
        histList:Dock(TOP)
        histList:SetTall(math.min(shown * 20 + 24, 400))
        histList:SetMultiSelect(false)
        histList.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
        end

        histList:AddColumn("TIME"):SetWidth(80)
        histList:AddColumn("NAME"):SetWidth(140)
        histList:AddColumn("OFFICER"):SetWidth(130)
        histList:AddColumn("DECISION"):SetWidth(80)
        CS_StyleListHeaders(histList, C.borderDim)

        for i = total, math.max(1, total - 49), -1 do
            local entry    = history[i]
            local timeStr  = os.date("%H:%M", entry.time or 0)
            local rowColor = entry.decision == "DENIED" and C.red or C.text
            local row = histList:AddLine(timeStr, entry.name or "Unknown", entry.officer or "Unknown", entry.decision or "")
            for _, col in pairs(row.Columns or {}) do col:SetTextColor(rowColor); col:SetContentAlignment(5) end
            row.Paint = function(self2, w, h)
                if self2:IsHovered() then
                    surface.SetDrawColor(Color(rowColor.r, rowColor.g, rowColor.b, 20))
                    surface.DrawRect(0, 0, w, h)
                end
            end
        end
    else
        local noHist = vgui.Create("DPanel", self)
        noHist:Dock(TOP)
        noHist:SetTall(28)
        noHist.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No clearance decisions logged.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

function PANEL:Paint(w, h) end

vgui.Register("CS_TabCWU", PANEL, "DPanel")
