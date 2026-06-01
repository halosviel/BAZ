--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 25
	
	[DESCRIPTION]
	Handles the day cycle and initiates/stops zombie spawning
	via ZombieService.
]=]

-- [CONFIG]
local UPDATE_INTERVAL = 1
local UPDATE_VALUE = 0.025

local DAY_TIME = 6
local NIGHT_TIME = 18

-- [REQUIRES]
local zombieService = require("../services/zombieService")

-->

while true do
	game.Lighting.ClockTime += UPDATE_VALUE
	
	local clockTime: number = math.floor(game.Lighting.ClockTime)
	if clockTime == DAY_TIME and zombieService:isRunning() then
		print("stop")
		zombieService:stopSpawning()
	elseif clockTime == NIGHT_TIME and not zombieService:isRunning() then
		print("start")
		zombieService:startSpawning()
	end
	
	task.wait(UPDATE_INTERVAL)
end