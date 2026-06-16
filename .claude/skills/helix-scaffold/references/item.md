# Scaffold: Item

Place at `plugins/<name>/items/<category>/sh_<item>.lua` or `schema/items/<...>/sh_<item>.lua`
(both autoload — no include). Grounded in `plugins/cwu/items/crafted/sh_cwu_bandage.lua`.

```lua
ITEM.name        = "CWU Bandage"
ITEM.model       = Model("models/props_junk/garbage_newspaper001a.mdl")
ITEM.description = "A clean bandage crafted by the CWU Production Division."
ITEM.base        = "base_crafted"   -- optional: inherit a base item (see items/base/)
ITEM.category    = "CWU Goods"
ITEM.price       = 18               -- optional

-- Domain fields used by bases / hooks in this schema:
ITEM.isHealingItem = true
ITEM.healAmount    = 20

ITEM.functions.Apply = {
    -- icon / sound optional
    OnRun = function(itemTable)
        local client = itemTable.player

        client:SetHealth(math.min(client:Health() + 25, client:GetMaxHealth()))
        client:EmitSound("items/medshot4.wav")
        client:Notify("You applied a bandage and recovered some health.")

        return false -- false = consume the item (remove from inventory)
    end
}
```

## Notes
- Base items live in `plugins/cwu/items/base/` (e.g. `base_crafted`, `base_materials`,
  `base_permit`, `base_chemicals`). Reuse a base instead of duplicating shared behavior.
- `OnRun` returning `false` removes the item; returning `true`/nil keeps it (per Helix item API).
- Player-facing `Notify` text follows `voice-guide.md`.
