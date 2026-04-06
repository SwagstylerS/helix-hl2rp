
PLUGIN.name        = "Combine Terminal"
PLUGIN.description = "Intel terminal, warrants, heat system, zones, checkpoints, and clearance."
PLUGIN.author      = "nebulous.cloud"

if SERVER then
    util.AddNetworkString("CS_TerminalOpen")
    util.AddNetworkString("CS_IntelOpen")
    util.AddNetworkString("CS_ClearanceNotify")
    util.AddNetworkString("CS_ClearanceResult")
    util.AddNetworkString("CS_TerminalSync")
    util.AddNetworkString("CS_TerminalDetail")
    util.AddNetworkString("CS_TerminalAction")
    util.AddNetworkString("CS_TerminalRefresh")
end

if CLIENT then
    -- Prop management (admin)
    ix.command.Add("maketerminal", {
        description = "Set the aimed prop as the scan records terminal.",
        adminOnly   = true,
        OnRun       = function(self, client) end,
    })
    ix.command.Add("removeterminal", {
        description = "Remove the scan records terminal.",
        adminOnly   = true,
        OnRun       = function(self, client) end,
    })
    ix.command.Add("makeintelboard", {
        description = "Set the aimed prop as the intel board.",
        adminOnly   = true,
        OnRun       = function(self, client) end,
    })
    ix.command.Add("removeintelboard", {
        description = "Remove the intel board.",
        adminOnly   = true,
        OnRun       = function(self, client) end,
    })

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

    -- Blacksite (senior)
    ix.command.Add("reviewblacklist", {
        description = "List all pending blacksite cases for review.",
        OnRun       = function(self, client) end,
    })
    ix.command.Add("approveblacklist", {
        description = "Approve a blacksite case by CID number.",
        arguments   = {ix.type.number},
        OnRun       = function(self, client, cid) end,
    })
    ix.command.Add("denyblacklist", {
        description = "Deny a blacksite case and reset its scan count.",
        arguments   = {ix.type.number},
        OnRun       = function(self, client, cid) end,
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
