--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 25
	
	[DESCRIPTION]
	Handles the day cycle and:
	- Initiates/stops zombie spawning via ZombieService.
	- Handles day increment
	- Handles build clearing signal
]=]

-- [CONFIG]
local UPDATE_INTERVAL = 0.001
local UPDATE_VALUE = 0.025

local DAY_TIME = 6
local NIGHT_TIME = 18
local SUNRISE_TIME = 7
local BUILD_CLEAR_INTERVAL = 10

-- [REQUIRES]
local zombieService = require("../services/zombieService")
local brickService = require("../services/brickService")

-->

--# initial values
game.Lighting.ClockTime = SUNRISE_TIME
game.ReplicatedFirst.shared.values.Days.Value = 1
game.ReplicatedFirst.shared.values.DaysToReset.Value = BUILD_CLEAR_INTERVAL

local lastHour = game.Lighting.ClockTime

while true do
	game.Lighting.ClockTime += UPDATE_VALUE
	local currentHour: number = math.floor(game.Lighting.ClockTime)
	
	if currentHour ~= lastHour then
		lastHour = currentHour
		
		--# start/stop zombie spawning (same as before, but with flags)
		if currentHour == DAY_TIME and zombieService:isRunning() then
			zombieService:stopSpawning()
		end
		
		if currentHour == NIGHT_TIME and not zombieService:isRunning() then
			zombieService:startSpawning()
		end
		
		--# increment days - check if sunrise happened
		if currentHour == SUNRISE_TIME then
			game.ReplicatedFirst.shared.values.Days.Value += 1
			game.ReplicatedFirst.shared.values.DaysToReset.Value -= 1
			warn(game.ReplicatedFirst.shared.values.Days.Value, game.ReplicatedFirst.shared.values.DaysToReset.Value)
		end
		
		--# reset builds (this one's fine as is!)
		if game.ReplicatedFirst.shared.values.DaysToReset.Value == 0 then
			brickService:clearAllBricks()
			game.ReplicatedFirst.shared.values.DaysToReset.Value = BUILD_CLEAR_INTERVAL
		end
	end
	
	task.wait(UPDATE_INTERVAL)
end