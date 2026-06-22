PLUGIN.name = "Cooking & Hunger"
PLUGIN.description = "Hunger system and cooking stations for City 17 citizens."
PLUGIN.author = "HL2RP"

ix.util.Include("libs/sv_hunger.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")

ix.config.Add("cookingEnabled", false, "Enable hunger and cooking systems. Default OFF — enable after smoke test.", nil, {category = "Cooking"})
ix.config.Add("cookingHungerRate", 2, "Hunger points added per tick (0–100 scale, tick = 60s).", nil, {data = {min = 1, max = 20}, category = "Cooking"})
ix.config.Add("cookingStarveDamage", 3, "HP drained per tick when starving (hunger ≥ 75).", nil, {data = {min = 1, max = 10}, category = "Cooking"})
