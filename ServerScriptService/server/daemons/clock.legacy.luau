--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 25
	
	[DESCRIPTION]
	Handles the day cycle.
]=]

-- [CONFIG]
local UPDATE_INTERVAL = 1
local UPDATE_VALUE = 0.025

-->

while true do
	game.Lighting.ClockTime += UPDATE_VALUE
	task.wait(UPDATE_INTERVAL)
end