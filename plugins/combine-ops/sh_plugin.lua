
PLUGIN.name        = "Combine Ops"
PLUGIN.description = "Panic signals, alerts, radio comms, curfew, and detainee management."
PLUGIN.author      = "nebulous.cloud"

if SERVER then
    util.AddNetworkString("CS_PanicAlert")
    util.AddNetworkString("CS_PanicClear")
    util.AddNetworkString("CS_Alert")
    util.AddNetworkString("CS_CurfewToggle")
end

if CLIENT then
    ix.command.Add("panicbutton", {
        description = "Send a panic signal to all Combine units.",
        OnRun       = function(self, client) end,
    })
    ix.command.Add("panicclear", {
        description = "Cancel your active panic signal.",
        OnRun       = function(self, client) end,
    })
    ix.command.Add("alert", {
        description = "Broadcast an alert message to all Combine units.",
        arguments   = {ix.type.text},
        OnRun       = function(self, client, message) end,
    })
    ix.command.Add("curfew", {
        description = "Toggle curfew — passively increases heat for all civilians while active.",
        OnRun       = function(self, client) end,
    })
    ix.command.Add("transferdetainee", {
        description = "Flag a citizen as detained and log the transfer to the intel board.",
        arguments   = {ix.type.character},
        OnRun       = function(self, client, target) end,
    })
    ix.command.Add("combineradio", {
        description = "Transmit on the Combine radio channel.",
        arguments   = {ix.type.text},
        OnRun       = function(self, client, message) end,
    })
end

-- Combine Radio chat class (Combine/OTA only)
do
    local CLASS = {}
    CLASS.color  = Color(80, 160, 255)
    CLASS.format = "%s [RADIO] \"%s\""

    function CLASS:CanSay(speaker, text)
        if !speaker:IsCombine() and speaker:Team() != FACTION_OTA then
            return "@notAllowed"
        end
    end

    function CLASS:CanHear(speaker, listener)
        return listener:IsCombine() or listener:Team() == FACTION_OTA
    end

    function CLASS:OnChatAdd(speaker, text)
        chat.AddText(self.color, string.format(self.format, speaker:Name(), text))
    end

    ix.chat.Register("combine_radio", CLASS)
end

-- Combine Radio eavesdrop (nearby non-Combine can overhear)
do
    local CLASS = {}
    CLASS.color  = Color(80, 160, 255)
    CLASS.format = "%s [RADIO] \"%s\""

    function CLASS:CanSay(speaker, text)
        return false
    end

    function CLASS:CanHear(speaker, listener)
        if ix.chat.classes.combine_radio:CanHear(speaker, listener) then
            return false
        end
        local chatRange = ix.config.Get("chatRange", 280)
        return (speaker:GetPos() - listener:GetPos()):LengthSqr() <= (chatRange * chatRange)
    end

    function CLASS:OnChatAdd(speaker, text)
        chat.AddText(self.color, string.format(self.format, speaker:Name(), text))
    end

    ix.chat.Register("combine_radio_eavesdrop", CLASS)
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
