
PLUGIN.name        = "Combine Ops"
PLUGIN.description = "Panic signals, alerts, radio comms, curfew, and detainee management."
PLUGIN.author      = "nebulous.cloud"

if SERVER then
    util.AddNetworkString("CS_PanicAlert")
    util.AddNetworkString("CS_PanicClear")
    util.AddNetworkString("CS_Alert")
    util.AddNetworkString("CS_RadioCall")
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
    ix.command.Add("radiocall", {
        description = "Send an IC radio message to all online Combine units.",
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
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
