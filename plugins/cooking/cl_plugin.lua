-- Client hooks for cooking plugin.

local localHunger = 0

netstream.Hook("CookingHungerUpdate", function(hunger)
	localHunger = hunger
end)

function PLUGIN:HUDPaint()
	if (!ix.config.Get("cookingEnabled", false)) then return end
	if (localHunger < 40) then return end

	-- ponytail: full-screen tint; matches injury vignette pattern in cwu/cl_hooks.lua
	local t         = (localHunger - 40) / 60        -- 0.0 at hunger=40, 1.0 at hunger=100
	local baseAlpha = math.floor(t * 35)

	if (localHunger >= 75) then
		baseAlpha = baseAlpha + math.floor((math.sin(CurTime() * 0.8) + 1) * 8)
	end

	surface.SetDrawColor(55, 45, 35, baseAlpha)
	surface.DrawRect(0, 0, ScrW(), ScrH())
end
