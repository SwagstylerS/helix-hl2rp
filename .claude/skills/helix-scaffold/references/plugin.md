# Scaffold: New Plugin

Directory: `plugins/<name>/`. Default to the hooks-style layout (used by `cwu`, `writing`).

## `plugins/<name>/sh_plugin.lua`
```lua
PLUGIN.name = "Human Readable Name"
PLUGIN.description = "What this plugin adds."
PLUGIN.author = "HL2RP"

-- Shared libs first (registries, data tables), then server, then client.
-- ix.util.Include("libs/sh_foo.lua")
ix.util.Include("sv_hooks.lua")
ix.util.Include("cl_hooks.lua")

-- Config: note the {data = {min, max}, category = "..."} options table.
ix.config.Add("myInterval", 300, "Seconds between ticks.", nil, {
    data = {min = 60, max = 3600},
    category = "<name>"
})

-- DO NOT include files under items/ or entities/ — Helix autoloads those dirs.
```

## `plugins/<name>/sv_hooks.lua`
```lua
local PLUGIN = PLUGIN

function PLUGIN:PostInitPostEntity()
    -- server init
end

-- Netstream receivers (client -> server) live here, NOT util.AddNetworkString:
netstream.Hook("MyAction", function(client, data)
    -- validate client, then act
end)
```

## `plugins/<name>/cl_hooks.lua`
```lua
local PLUGIN = PLUGIN

netstream.Hook("MyUpdate", function(data)
    -- update client state / open UI
end)

function PLUGIN:HUDPaint()
    -- client HUD
end
```

## `plugins/<name>/languages/sh_english.lua`
```lua
LANGUAGE = {
    myThingDone = "In-world confirmation text.",
}
```

## Notes
- `combine-*` style instead uses `sv_plugin.lua`/`cl_plugin.lua` and pools `util.AddNetworkString("CS_...")` inside `if SERVER then` in `sh_plugin.lua`. Only use that when extending those plugins.
- Commands in `combine-terminal/sh_plugin.lua` are declared inside `if CLIENT then` as stubs — match local conventions when adding commands to that family.
