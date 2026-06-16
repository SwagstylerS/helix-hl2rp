# ix.* API surface (with repo-anchored examples)

## Includes & realms
```lua
ix.util.Include("sv_hooks.lua")   -- realm inferred from sv_/cl_/sh_ prefix
ix.util.Include("libs/sh_x.lua", "shared")
```

## Config — `ix.config.Add(key, default, description, callback, options)`
```lua
ix.config.Add("cwuTaxRate", 10, "Percentage tax on vendor terminal sales.", nil, {
    data = {min = 0, max = 50},
    category = "cwu"
})
local rate = ix.config.Get("cwuTaxRate", 10)
```
Anchor: `plugins/cwu/sh_plugin.lua`.

## Commands — `ix.command.Add(name, COMMAND)`
```lua
local COMMAND = {}
COMMAND.description = "..."
COMMAND.adminOnly   = true                 -- optional
COMMAND.arguments   = {ix.type.character, ix.type.text} -- or ix.type.number/string/bool

function COMMAND:OnRun(client, target, message)
    if (!client:IsCWU()) then return "@notAllowed" end  -- "@key" -> localized error
    ix.chat.Send(client, "cwu_radio", message)
end

ix.command.Add("CWURadio", COMMAND)
```
Anchors: `plugins/cwu/sh_plugin.lua`, `plugins/combine-terminal/sh_plugin.lua` (note the
combine family declares command stubs inside `if CLIENT then`).
**Convention:** commands must NOT perform world interaction (entities only); pure comms is OK.

## Chat — `ix.chat.Register(name, CLASS)` / `ix.chat.Send(client, class, text)`
```lua
local CLASS = {}
CLASS.color  = Color(100, 175, 100)
CLASS.format = "%s [CWU] radios \"%s\""
function CLASS:CanSay(speaker, text) ... end       -- return false to block
function CLASS:CanHear(speaker, listener) ... end   -- return bool
function CLASS:OnChatAdd(speaker, text)
    chat.AddText(self.color, string.format(self.format, speaker:Name(), text))
end
ix.chat.Register("cwu_radio", CLASS)
```
Anchors: `plugins/cwu/sh_plugin.lua`, `schema/sh_schema.lua` (dispatch class).

## Items — table-based, autoloaded from `items/`
`ITEM.name/model/description/base/category/price`; behaviors in `ITEM.functions.X.OnRun`.
Global registry: `ix.item.list`. Give an item: `character:GetInventory():Add("uniqueID", count, data)`.
Anchor: `plugins/cwu/items/crafted/sh_cwu_bandage.lua`.

## Persistence — `ix.data.Set(key, value [, global, ignoreMap])` / `ix.data.Get(key, default)`
```lua
ix.data.Set("cs_detainees", log)
local log = ix.data.Get("cs_detainees", {})
```
Map-scoped by default (e.g. checkpoint data keyed per `game.GetMap()`).

## Character meta
```lua
local char = client:GetCharacter()
if (!char) then return end
char:GetData("loyaltyTier", 0)      char:SetData("loyaltyTier", 3)
char:GiveMoney(50)                  char:TakeMoney(20)
char:GetClass()                     char:JoinClass(CLASS_CWU_DIRECTOR, true)
char:GetID()                        char:GetName()
char:GetInventory()
```

## Flags — `ix.flag.Add(flag, desc, callback)`; `character:HasFlags("x")`, `:GiveFlags`, `:TakeFlags`.

## Localization — `LANGUAGE` table in `languages/sh_english.lua`
```lua
client:NotifyLocalized("cwuPurchaseComplete")
return "@notAllowed"   -- from a command OnRun
```
