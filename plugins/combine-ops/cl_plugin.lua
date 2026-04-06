
local PLUGIN = PLUGIN

-- Fonts may already exist from combine-scanner, safe to re-declare
surface.CreateFont("CS_Notif", {font="Courier New", size=11, weight=700, antialias=true})

-- ============================================================
--  LOCAL STATE
-- ============================================================
local activePanics = {}

-- Local color scheme for the panic minimap (mirrors combine-scanner logic)
local function GetScheme()
    local ply = LocalPlayer()
    if IsValid(ply) and ply:Team() == FACTION_OTA then
        return {
            bg        = Color(25, 10, 10, 200),
            border    = Color(200, 60, 60),
            borderDim = Color(120, 30, 30),
            alert     = Color(255, 60, 60),
        }
    end
    return {
        bg        = Color(10, 25, 10, 200),
        border    = Color(50, 180, 50),
        borderDim = Color(30, 100, 30),
        alert     = Color(255, 80, 80),
    }
end

-- ============================================================
--  NET RECEIVERS
-- ============================================================
net.Receive("CS_PanicAlert", function()
    local sid  = net.ReadString()
    local name = net.ReadString()
    local pos  = net.ReadVector()
    activePanics[sid] = {name=name, pos=pos, time=CurTime()}
    CS_NotifQueue = CS_NotifQueue or {}
    CS_NotifQueue[#CS_NotifQueue + 1] = {
        lines  = {"PANIC SIGNAL", name, "RESPOND IMMEDIATELY"},
        color  = Color(255, 50, 50),
        showAt = CurTime(),
    }
end)

net.Receive("CS_PanicClear", function()
    activePanics[net.ReadString()] = nil
end)

net.Receive("CS_Alert", function()
    local sender  = net.ReadString()
    local message = net.ReadString()
    CS_NotifQueue = CS_NotifQueue or {}
    CS_NotifQueue[#CS_NotifQueue + 1] = {
        lines  = {"UNIT ALERT — " .. sender, message},
        color  = Color(255, 180, 0),
        showAt = CurTime(),
    }
    chat.AddText(Color(255, 180, 0), "[ALERT] ", Color(220, 220, 220), sender .. ": " .. message)
end)

net.Receive("CS_RadioCall", function()
    local sender  = net.ReadString()
    local message = net.ReadString()
    CS_NotifQueue = CS_NotifQueue or {}
    CS_NotifQueue[#CS_NotifQueue + 1] = {
        lines  = {"RADIO — " .. sender, message},
        color  = Color(80, 160, 255),
        showAt = CurTime(),
    }
    chat.AddText(Color(80, 160, 255), "[RADIO] ", Color(220, 220, 220), sender .. ": " .. message)
end)

net.Receive("CS_CurfewToggle", function()
    local active = net.ReadBool()
    local who    = net.ReadString()
    local color  = active and Color(255, 80, 80) or Color(80, 220, 80)
    local label  = active and "CURFEW ACTIVATED" or "CURFEW LIFTED"
    CS_NotifQueue = CS_NotifQueue or {}
    CS_NotifQueue[#CS_NotifQueue + 1] = {
        lines  = {label, "Issued by: " .. who},
        color  = color,
        showAt = CurTime(),
    }
    chat.AddText(color, "[CURFEW] ", Color(220, 220, 220), label .. " — " .. who)
end)

-- ============================================================
--  HUD: PANIC MINIMAP
-- ============================================================
local function DrawPanicMinimap()
    local ply = LocalPlayer()
    if !IsValid(ply) then return end
    if ply:Team() != FACTION_OTA and !ply:IsCombine() then return end

    local count = 0
    for _ in pairs(activePanics) do count = count + 1 end
    if count == 0 then return end

    local sw    = ScrW()
    local sh    = ScrH()
    local MAP_S = 120
    local PAD   = 10
    local mx    = sw - MAP_S - PAD
    local my    = sh - MAP_S - PAD
    local SCALE = MAP_S / 6000
    local c     = GetScheme()
    local now   = CurTime()

    surface.SetDrawColor(c.bg.r, c.bg.g, c.bg.b, 200)
    surface.DrawRect(mx, my, MAP_S, MAP_S)
    surface.SetDrawColor(c.border)
    surface.DrawOutlinedRect(mx, my, MAP_S, MAP_S, 1)
    surface.SetDrawColor(c.border.r, c.border.g, c.border.b, 50)
    for i = 1, 3 do
        surface.DrawRect(mx + math.floor(MAP_S*i/4), my, 1, MAP_S)
        surface.DrawRect(mx, my + math.floor(MAP_S*i/4), MAP_S, 1)
    end

    local cx = mx + MAP_S / 2
    local cy = my + MAP_S / 2
    surface.SetDrawColor(Color(100, 255, 100))
    surface.DrawRect(cx - 2, cy - 2, 5, 5)

    local selfPos = ply:GetPos()
    local closest, closestDist = nil, math.huge
    for sid, panic in pairs(activePanics) do
        local dx  = (panic.pos.x - selfPos.x) * SCALE
        local dy  = (panic.pos.y - selfPos.y) * SCALE
        local bx  = math.Clamp(cx + dx, mx + 2, mx + MAP_S - 2)
        local by  = math.Clamp(cy + dy, my + 2, my + MAP_S - 2)
        local pulse = math.abs(math.sin(now * 3))
        surface.SetDrawColor(Color(255, 50, 50, math.floor(255 * (0.5 + 0.5*pulse))))
        surface.DrawRect(bx - 2, by - 2, 5, 5)
        local d = (panic.pos - selfPos):Length()
        if d < closestDist then closestDist = d; closest = panic end
    end

    if closest then
        local gridX    = math.floor(closest.pos.x / 512)
        local gridY    = math.floor(closest.pos.y / 512)
        local infoText = string.format("[%d,%d] %.0fu", gridX, gridY, closestDist)
        draw.SimpleText(infoText, "CS_Notif", mx + MAP_S/2, my + MAP_S - 12, c.alert, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end

-- ============================================================
--  MAIN HUD HOOK
-- ============================================================
hook.Add("HUDPaint", "CS_Ops_HUDPaint", function()
    DrawPanicMinimap()
end)

-- ============================================================
--  CLEANUP
-- ============================================================
hook.Add("InitPostEntity", "CS_Ops_ClientReset", function()
    activePanics = {}
end)
