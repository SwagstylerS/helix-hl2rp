
-- ============================================================
--  CS_TabBar — Custom horizontal tab strip
-- ============================================================

local PANEL = {}

function PANEL:Init()
    self.m_Tabs = {}
    self.m_Active = nil
    self.OnTabSelected = nil
end

function PANEL:AddTab(name)
    self.m_Tabs[#self.m_Tabs + 1] = name
end

function PANEL:SelectTab(name)
    self.m_Active = name
    if self.OnTabSelected then
        self.OnTabSelected(self, name)
    end
end

function PANEL:GetActiveTab()
    return self.m_Active
end

function PANEL:Paint(w, h)
    local C = CS_TERM_COLORS
    if !C then return end

    draw.RoundedBox(0, 0, 0, w, h, C.bgDark)
    surface.SetDrawColor(C.borderDim)
    surface.DrawOutlinedRect(0, 0, w, h, 1)

    local count = #self.m_Tabs
    if count == 0 then return end

    local tabW = w / count
    local mx, my = self:CursorPos()

    for i, name in ipairs(self.m_Tabs) do
        local x = (i - 1) * tabW
        local isActive = (name == self.m_Active)
        local isHovered = (mx >= x and mx < x + tabW and my >= 0 and my <= h)

        if isActive then
            draw.RoundedBox(0, x + 1, 0, tabW - 2, h, Color(C.border.r, C.border.g, C.border.b, 40))
            surface.SetDrawColor(C.border)
            surface.DrawRect(x + 1, h - 2, tabW - 2, 2)
        elseif isHovered then
            draw.RoundedBox(0, x + 1, 0, tabW - 2, h, Color(C.border.r, C.border.g, C.border.b, 15))
        end

        local textCol = isActive and C.textBright or (isHovered and C.text or C.textDim)
        draw.SimpleText(name, "CS_TabLabel", x + tabW/2, h/2, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if i < count then
            surface.SetDrawColor(C.borderDim)
            surface.DrawRect(x + tabW - 1, 4, 1, h - 8)
        end
    end
end

function PANEL:OnMousePressed(code)
    if code != MOUSE_LEFT then return end

    local count = #self.m_Tabs
    if count == 0 then return end

    local w = self:GetWide()
    local tabW = w / count
    local mx = self:CursorPos()

    for i, name in ipairs(self.m_Tabs) do
        local x = (i - 1) * tabW
        if mx >= x and mx < x + tabW then
            self:SelectTab(name)
            surface.PlaySound("buttons/button15.wav")
            break
        end
    end
end

vgui.Register("CS_TabBar", PANEL, "DPanel")
