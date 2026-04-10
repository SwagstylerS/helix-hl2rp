
local PLUGIN = PLUGIN

-- Fonts may already exist from combine-scanner, safe to re-declare
surface.CreateFont("CS_Notif", {font="Courier New", size=11, weight=700, antialias=true})

-- ============================================================
--  LOCAL STATE
-- ============================================================
local activePanics = {}
local curfewActive = false

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
    chat.AddText(Color(255, 50, 50), "[RADIO - PANIC] ", Color(220, 220, 220), name .. " requests immediate assistance!")
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

net.Receive("CS_CurfewToggle", function()
    local active = net.ReadBool()
    local who    = net.ReadString()
    curfewActive = active
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
--  HUD: IN-WORLD PANIC BLIPS
-- ============================================================
local function DrawPanicBlips()
    local ply = LocalPlayer()
    if !IsValid(ply) then return end
    if ply:Team() != FACTION_OTA and !ply:IsCombine() then return end

    local count = 0
    for _ in pairs(activePanics) do count = count + 1 end
    if count == 0 then return end

    local now = CurTime()

    for sid, panic in pairs(activePanics) do
        local screenPos = panic.pos:ToScreen()
        if !screenPos.visible then continue end

        local dist    = (panic.pos - ply:GetPos()):Length()
        local elapsed = now - panic.time
        local pulse   = math.abs(math.sin(now * 3))
        local alpha   = math.floor(200 + 55 * pulse)

        -- Blip marker
        local bx, by = screenPos.x, screenPos.y
        local size = 8
        surface.SetDrawColor(255, 50, 50, alpha)
        surface.DrawRect(bx - size/2, by - size/2, size, size)

        -- Outer pulsing ring
        local ringSize = math.floor(12 + 6 * pulse)
        surface.SetDrawColor(255, 50, 50, math.floor(120 * pulse))
        surface.DrawOutlinedRect(bx - ringSize/2, by - ringSize/2, ringSize, ringSize, 1)

        -- Info text stack
        local textY = by + size/2 + 4
        draw.SimpleText(panic.name, "CS_Notif", bx, textY, Color(255, 80, 80, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        textY = textY + 12
        draw.SimpleText(string.format("%.0f units", dist), "CS_Notif", bx, textY, Color(255, 180, 180, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        textY = textY + 12
        draw.SimpleText(string.format("%.0fs ago", elapsed), "CS_Notif", bx, textY, Color(255, 180, 180, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end

-- ============================================================
--  HUD: CURFEW BANNER
-- ============================================================
local function DrawCurfewBanner()
    if !curfewActive then return end
    local ply = LocalPlayer()
    if !IsValid(ply) then return end
    if ply:Team() != FACTION_OTA and !ply:IsCombine() then return end

    local sw    = ScrW()
    local pulse = math.abs(math.sin(CurTime() * 2))
    local alpha = math.floor(180 + 75 * pulse)

    draw.SimpleText("CURFEW ACTIVE", "CS_Notif", sw / 2, 6, Color(255, 60, 60, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

-- ============================================================
--  MAIN HUD HOOK
-- ============================================================
hook.Add("HUDPaint", "CS_Ops_HUDPaint", function()
    DrawPanicBlips()
    DrawCurfewBanner()
end)

-- ============================================================
--  CLEANUP
-- ============================================================
hook.Add("InitPostEntity", "CS_Ops_ClientReset", function()
    activePanics = {}
    curfewActive = false
end)
