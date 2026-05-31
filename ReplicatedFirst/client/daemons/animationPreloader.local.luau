--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 27
	
	[DESCRIPTION]
	Preloads animations
]=]

-- [REQUIRES]
local console = require("@game/ReplicatedFirst/pip/console")
local try = require("@game/ReplicatedFirst/pip/try")

-->

local animations: { Animation } = {}
for _, animation: Animation in game.ReplicatedFirst.assets.animations:GetChildren() do
	if not animation:IsA("Animation") then
		return
	end
	table.insert(animations, animation)
end

try {
	function()
		game.ContentProvider:PreloadAsync(animations)
	end,
	function(err: string)
		console.warn("Error while preloading animations", err)
	end,
}