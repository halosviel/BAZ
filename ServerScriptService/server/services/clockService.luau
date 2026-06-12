--[=[
	[INFO]
	author: @halosviel
	created: 2026 June 12
	
	[DESCRIPTION]
	Handles clock-related events and contains a TIME entry for other
	scripts to read from.
	
	Clients should connect to getDayData and daydataUpdated events.
]=]

-- [REQUIRES]
local zombieService = require("../services/zombieService")
local brickService = require("../services/brickService")
local events = require("@game/ReplicatedFirst/shared/modules/events")
local types = require("@game/ReplicatedFirst/shared/modules/types")

-- [TYPES]
type self = {
	-- [CONFIG]
	UPDATE_INTERVAL: number,
	UPDATE_VALUE: number,
	DAY_TIME: number,
	NIGHT_TIME: number,
	SUNRISE_TIME: number,
	BUILD_CLEAR_INTERVAL: number,
	
	-- [ENTRIES]
	time: number,
	lastHour: number,
	day: number,
	daysToReset: number,
	
	-- [FUNCTIONS]
	constructor: ( self: self ) -> nil,
	_fetchDayData: ( self: self ) -> types.DayData,
	getTime: ( self: self ) -> number,
	getRawTime: ( self: self ) -> number,
	ready: ( self: self ) -> nil
}
export type ClockService = self

-->

return {
	constructor = function(self: self)
		self.UPDATE_INTERVAL = 0.01
		self.UPDATE_VALUE = 0.025
		self.DAY_TIME = 6
		self.NIGHT_TIME = 18
		self.SUNRISE_TIME = 7
		self.BUILD_CLEAR_INTERVAL = 10 --# in days
		
		self.time = 0 --# immediately set in ready | in rounded hours
		self.lastHour = 0 --# immediately set in ready | past record of self.time
		self.day = 1
		self.daysToReset = self.BUILD_CLEAR_INTERVAL
	end,
	
	_fetchDayData = function(self: self) : types.DayData
		return {
			day = self.day,
			daysToReset = self.daysToReset
		} :: types.DayData
	end,
	
	--[[
		Returns self.time (the current hour rounded)
	]]
	getTime = function(self: self) : number
		return self.time
	end,
	
	--[[
		Returns game.Lighting.ClockTime in its raw value.
	]]
	getRawTime = function(self: self) : number
		return game.Lighting.ClockTime
	end,
	
	ready = function(self: self)
		--# initial time
		game.Lighting.ClockTime = self.SUNRISE_TIME
		
		task.defer(function()
			while true do
				game.Lighting.ClockTime += self.UPDATE_VALUE
				self.time = math.floor(self:getRawTime())
				
				--# once per-hour events
				if self.time ~= self.lastHour then
					self.lastHour = self.time
					
					--# start/stop zombie spawning (same as before, but with flags)
					if self.time == self.DAY_TIME and zombieService:isRunning() then
						zombieService:stopSpawning()
					end
					
					if self.time == self.NIGHT_TIME and not zombieService:isRunning() then
						zombieService:startSpawning()
					end
					
					--# increment days - check if sunrise happened
					if self.time == self.SUNRISE_TIME then
						self.day += 1
						self.daysToReset -= 1
					end
					
					--# reset builds (this one's fine as is!)
					if self.daysToReset == 0 then
						brickService:clearAllBricks()
						self.daysToReset = self.BUILD_CLEAR_INTERVAL
					end
					
					events.dayDataUpdated:Fire(self:_fetchDayData())
				end
				
				task.wait(self.UPDATE_INTERVAL)
			end
		end)
		
		--# return day data on request
		events.getDayData.OnServerInvoke = function(player: Player) : types.DayData
			return self:_fetchDayData()
		end
	end,
} :: self