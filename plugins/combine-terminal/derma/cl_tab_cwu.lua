
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
        noReq:Dock(FILL)
        noReq.Paint = function(self2, w, h)
            local C = CS_TERM_COLORS
            draw.SimpleText("No pending clearance requests.", "CS_Body", w/2, h/2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return
    end

    local scroll = vgui.Create("DScrollPanel", self)
    scroll:Dock(FILL)
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

function PANEL:Paint(w, h) end

vgui.Register("CS_TabCWU", PANEL, "DPanel")
