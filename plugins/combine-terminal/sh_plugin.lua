
PLUGIN.name        = "Combine Terminal"
PLUGIN.description = "Intel terminal, warrants, heat system, zones, checkpoints, and clearance."
PLUGIN.author      = "nebulous.cloud"

if SERVER then
    util.AddNetworkString("CS_TerminalOpen")
    util.AddNetworkString("CS_ClearanceNotify")
    util.AddNetworkString("CS_ClearanceResult")
    util.AddNetworkString("CS_TerminalDetail")
    util.AddNetworkString("CS_TerminalAction")
    util.AddNetworkString("CS_TerminalRefresh")
end

if CLIENT then
    -- Warrants (senior)
    ix.command.Add("issuewarrant", {
        description = "Issue a warrant for a citizen by name.",
        arguments   = {ix.type.character, ix.type.text},
        OnRun       = function(self, client, target, reason) end,
    })
    ix.command.Add("clearwarrant", {
        description = "Clear an active warrant on a citizen by name.",
        arguments   = {ix.type.character},
        OnRun       = function(self, client, target) end,
    })

    -- Clearance
    ix.command.Add("requestclearance", {
        description = "Request clearance from Combine as a citizen.",
        OnRun       = function(self, client) end,
    })
    ix.command.Add("approveclearance", {
        description = "Approve a citizen's clearance request by name.",
        arguments   = {ix.type.character},
        OnRun       = function(self, client, target) end,
    })
    ix.command.Add("denyclearance", {
        description = "Deny a citizen's clearance request by name.",
        arguments   = {ix.type.character},
        OnRun       = function(self, client, target) end,
    })

    -- Zones & checkpoints (admin)
    ix.command.Add("addrestrictedzone", {
        description = "Create a restricted zone at your position.",
        adminOnly   = true,
        arguments   = {ix.type.number, ix.type.string},
        OnRun       = function(self, client, radius, name) end,
    })
    ix.command.Add("removerestrictedzone", {
        description = "Remove the nearest restricted zone.",
        adminOnly   = true,
        OnRun       = function(self, client) end,
    })
    ix.command.Add("addcheckpoint", {
        description = "Create a movement checkpoint that logs citizens to the intel board.",
        adminOnly   = true,
        arguments   = {ix.type.number, ix.type.string},
        OnRun       = function(self, client, radius, name) end,
    })
    ix.command.Add("removecheckpoint", {
        description = "Remove the nearest movement checkpoint.",
        adminOnly   = true,
        OnRun       = function(self, client) end,
    })
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
