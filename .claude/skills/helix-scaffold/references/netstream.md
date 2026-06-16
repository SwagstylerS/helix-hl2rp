# Scaffold: Netstream message

This schema's preferred networking is **netstream2** (`schema/libs/thirdparty/sh_netstream2.lua`).
It auto-registers message names — **no `util.AddNetworkString`** and no manual `net` read/write.

## Server → client
```lua
-- send to one player
netstream.Start(client, "MyThingOpen", payloadTable)
-- broadcast to several
netstream.Start(player.GetAll(), "MyThingOpen", payloadTable)
```

## Client → server
```lua
netstream.Start("MyThingAction", { choice = 2 })
```

## Receiving (register once, in sv_hooks.lua / cl_hooks.lua)
```lua
-- SERVER: first arg is the sending client
netstream.Hook("MyThingAction", function(client, data)
    if (!IsValid(client)) then return end
    -- validate, then act
end)

-- CLIENT: no client arg
netstream.Hook("MyThingOpen", function(data)
    -- open UI / update state
end)
```

## Payloads
- Netstream serializes Lua tables directly — pass a table, not pre-encoded JSON.
  (The legacy `combine-*` path manually does `util.TableToJSON` + `net.WriteString`; you do
  not need that with netstream.)

## Legacy net.* (combine-* family only)
When extending `combine-ops` / `combine-scanner` / `combine-terminal`, mirror their existing
pattern instead: pool the string in `sh_plugin.lua`'s `if SERVER then` block
(`util.AddNetworkString("CS_Foo")`), then `net.Start("CS_Foo") ... net.Send(client)` /
`net.Receive("CS_Foo", fn)`. Do **not** introduce new raw `net.*` in netstream-based plugins.
