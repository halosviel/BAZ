--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 25
	
	[DESCRIPTION]
	Handles the day cycle.
]=]

-- [CONFIG]
local UPDATE_INTERVAL = 1

-->

while true do
	game.Lighting.ClockTime += 0.1
	task.wait(UPDATE_INTERVAL)
end