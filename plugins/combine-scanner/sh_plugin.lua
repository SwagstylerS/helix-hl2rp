
PLUGIN.name        = "Combine Scanner"
PLUGIN.description = "Scanner device, battery system, scan HUD, and charger."
PLUGIN.author      = "nebulous.cloud"

if SERVER then
    util.AddNetworkString("CS_ScanStart")
    util.AddNetworkString("CS_ScanDeny")
    util.AddNetworkString("CS_BatterySync")
    util.AddNetworkString("CS_QuotaWarning")
    util.AddNetworkString("CS_BiometricAlert")
    util.AddNetworkString("CS_BlacksiteNotify")
    util.AddNetworkString("CS_ChargerSync")
end

if CLIENT then
    ix.command.Add("scansubject", {
        description = "Scan the civilian you are looking at.",
        OnRun       = function(self, client) end,
    })
    ix.command.Add("checkquota", {
        description = "Check your daily scan quota progress.",
        OnRun       = function(self, client) end,
    })
    ix.command.Add("scanstatus", {
        description = "Show your current battery and quota in chat.",
        OnRun       = function(self, client) end,
    })
    ix.command.Add("identify", {
        description = "Quick CID and heat lookup on a citizen by name.",
        arguments   = {ix.type.character},
        OnRun       = function(self, client, target) end,
    })
    ix.command.Add("makerecharger", {
        description = "Set the aimed prop as the scanner charger.",
        adminOnly   = true,
        OnRun       = function(self, client) end,
    })
    ix.command.Add("removecharger", {
        description = "Remove the scanner charger.",
        adminOnly   = true,
        OnRun       = function(self, client) end,
    })
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
