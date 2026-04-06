
-- ============================================================
--  CS_TerminalFrame — Main CRT-styled terminal window
-- ============================================================

CS_TERM_COLORS = {
    bg         = Color(10, 25, 10, 245),
    bgDark     = Color(5, 15, 5, 255),
    bgPanel    = Color(8, 20, 8, 255),
    border     = Color(50, 180, 50),
    borderDim  = Color(30, 100, 30),
    text       = Color(80, 200, 80),
    textBright = Color(100, 255, 100),
    textDim    = Color(40, 120, 40),
    highlight  = Color(50, 180, 50, 60),
    hover      = Color(50, 180, 50, 30),
    red        = Color(200, 50, 50),
    yellow     = Color(200, 180, 50),
    orange     = Color(200, 120, 50),
    headerBg   = Color(0, 0, 0),
    scanline   = Color(0, 0, 0, 12),
    white      = Color(255, 255, 255),
}

surface.CreateFont("CS_Title",    {font="Courier New", size=14, weight=900, antialias=true})
surface.CreateFont("CS_TabLabel", {font="Courier New", size=12, weight=700, antialias=true})
surface.CreateFont("CS_Body",     {font="Courier New", size=11, weight=500, antialias=true})
surface.CreateFont("CS_BodyBold", {font="Courier New", size=11, weight=700, antialias=true})
surface.CreateFont("CS_Small",    {font="Courier New", size=10, weight=500, antialias=true})
surface.CreateFont("CS_Notif",    {font="Courier New", size=11, weight=700, antialias=true})
surface.CreateFont("CS_Header",   {font="Courier New", size=11, weight=900, antialias=true})
surface.CreateFont("CS_DetailHeader", {font="Courier New", size=16, weight=900, antialias=true})

local C = CS_TERM_COLORS

local PANEL = {}

AccessorFunc(PANEL, "m_bSenior", "Senior", FORCE_BOOL)

function PANEL:Init()
    self:SetSize(1000, 650)
    self:Center()
    self:SetTitle("")
    self:SetDraggable(true)
    self:ShowCloseButton(false)
    self:MakePopup()

    self.m_Data = {}
    self.m_bSenior = false
    self.m_Tabs = {}
    self.m_TabPanels = {}
    self.m_ActiveTab = nil
    self.m_flBoot = CurTime()

    -- Close button
    self.closeBtn = vgui.Create("DButton", self)
    self.closeBtn:Dock(BOTTOM)
    self.closeBtn:DockMargin(6, 4, 6, 6)
    self.closeBtn:SetTall(26)
    self.closeBtn:SetText("")
    self.closeBtn.DoClick = function() self:Remove() end
    self.closeBtn.Paint = function(btn, w, h)
        local bg = btn:IsHovered() and Color(C.bgDark.r + 10, C.bgDark.g + 20, C.bgDark.b + 10) or C.bgDark
        draw.RoundedBox(0, 0, 0, w, h, bg)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("DISCONNECT TERMINAL", "CS_BodyBold", w/2, h/2, C.textBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Tab bar
    self.tabBar = vgui.Create("CS_TabBar", self)
    self.tabBar:Dock(TOP)
    self.tabBar:DockMargin(6, 24, 6, 0)
    self.tabBar:SetTall(30)
    self.tabBar.OnTabSelected = function(_, tabName)
        self:SwitchTab(tabName)
    end

    -- Content area
    self.content = vgui.Create("DPanel", self)
    self.content:Dock(FILL)
    self.content:DockMargin(6, 4, 6, 0)
    self.content.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, h, C.bgPanel)
        surface.SetDrawColor(C.borderDim)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
end

function PANEL:SetTerminalData(data)
    self.m_Data = data or {}
end

function PANEL:GetTerminalData()
    return self.m_Data
end

function PANEL:Populate()
    local tabs = {
        {"DATABASE",   "CS_TabDatabase"},
        {"UNITS",      "CS_TabUnits"},
        {"SCANS",      "CS_TabScans"},
        {"WARRANTS",   "CS_TabWarrants"},
        {"ZONES",      "CS_TabZones"},
        {"CLEARANCE",  "CS_TabCWU"},
    }

    for _, info in ipairs(tabs) do
        local tabName, panelClass = info[1], info[2]
        self.tabBar:AddTab(tabName)

        -- Snapshot children before creation so we can clean up orphans on failure
        local childrenBefore = {}
        for _, ch in ipairs(self.content:GetChildren()) do childrenBefore[ch] = true end

        local ok, panel = pcall(vgui.Create, panelClass, self.content)
        if ok and IsValid(panel) then
            panel:Dock(FILL)
            panel:DockMargin(4, 4, 4, 4)
            panel:SetVisible(false)
            if panel.SetTerminalFrame then panel:SetTerminalFrame(self) end
            if panel.SetSenior then panel:SetSenior(self.m_bSenior) end
            if panel.Populate then
                local popOk, popErr = pcall(panel.Populate, panel, self.m_Data)
                if !popOk then
                    print("[CS_Terminal] Error populating " .. tabName .. ": " .. tostring(popErr))
                end
            end
            self.m_TabPanels[tabName] = panel
        else
            -- Init crashed: vgui.Create may have orphaned a visible child panel — remove it
            print("[CS_Terminal] Failed to create panel for tab: " .. tabName .. " — " .. tostring(panel))
            for _, ch in ipairs(self.content:GetChildren()) do
                if !childrenBefore[ch] and IsValid(ch) then
                    ch:Remove()
                end
            end
        end
    end

    self.tabBar:SelectTab("DATABASE")
end

function PANEL:SwitchTab(tabName)
    for name, panel in pairs(self.m_TabPanels) do
        panel:SetVisible(name == tabName)
    end
    self.m_ActiveTab = tabName
end

function PANEL:GetTabPanel(tabName)
    return self.m_TabPanels[tabName]
end

function PANEL:OnCitizenDetail(detail)
    local db = self.m_TabPanels["DATABASE"]
    if IsValid(db) and db.OnCitizenDetail then
        db:OnCitizenDetail(detail)
    end
end

function PANEL:OnDataRefresh(data)
    self.m_Data = data
    for _, panel in pairs(self.m_TabPanels) do
        if IsValid(panel) and panel.Populate then
            panel:Populate(data)
        end
    end
end

function PANEL:Paint(w, h)
    -- Background
    draw.RoundedBox(0, 0, 0, w, h, C.bg)

    -- Border
    surface.SetDrawColor(C.border)
    surface.DrawOutlinedRect(0, 0, w, h, 2)

    -- Title bar line
    surface.DrawRect(0, 20, w, 1)

    -- Title text
    draw.SimpleText("CIVIL PROTECTION OPERATIONS TERMINAL", "CS_Title", w/2, 10, C.textBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Status indicator
    local uptime = string.format("UPTIME: %s", string.FormattedTime(CurTime() - self.m_flBoot, "%02i:%02i:%02i"))
    draw.SimpleText(uptime, "CS_Small", w - 10, 10, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- Classification
    draw.SimpleText("CLASSIFIED", "CS_Small", 10, 10, C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- CRT scanlines
    for y = 0, h, 3 do
        surface.SetDrawColor(C.scanline)
        surface.DrawRect(0, y, w, 1)
    end

    -- Subtle vignette at edges
    local vignetteAlpha = 40
    for i = 0, 15 do
        local a = vignetteAlpha * (1 - i / 15)
        surface.SetDrawColor(0, 0, 0, a)
        surface.DrawOutlinedRect(i, i, w - i*2, h - i*2, 1)
    end
end

vgui.Register("CS_TerminalFrame", PANEL, "DFrame")
