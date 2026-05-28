--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 26
	
	[DESCRIPTION]
	
	[NOTES]
	- 
]=]

-- [REQUIRES]
local console = require("@game/ReplicatedFirst/pip/console")
local zombie = require("@self/zombie")

-- [TYPES]
type SpawningState = {
	thread: RBXScriptConnection?
}

type self = {
	-- [CONFIG]
	MAX_ZOMBIE_COUNT: number,
	ZOMBIE_SPAWN_INTERVAL: number,
	
	-- [ENTRIES]
	zombies: { zombie.Zombie },
	spawnThread: thread?,
	
	-- [FUNCTIONS]
	constructor: ( self: self ) -> nil,
	startSpawning: ( self: self ) -> nil,
	stopSpawning: ( self: self ) -> nil,
	ready: ( self: self ) -> nil
}
export type ZombieService = self

-->

local baseplate = workspace.static.Baseplate
local globalId = 0

return {
	constructor = function(self: self)
		self.MAX_ZOMBIE_COUNT = 50
		self.ZOMBIE_SPAWN_INTERVAL = { 0, 3 } -- if the max zombie count is not met, zombies will spawn every x seconds to fill the count
		
		self.zombies = {}
		self.spawnThread = nil
	end,
	
	--[[
		Repeatedly spawns zombies in a random ranged interval, only
		pausing if the max number of zombies are reached.
		
		If the max number of zombies are reached and a zombie dies/
		is removed from self.zombies, a new one will be spawned in
		its place as long as this thread is still running.
	]]
	startSpawning = function(self: self)
		if self.spawnThread then
			console.warn("Requets to start zombie spawning dropped: Thread already exists")
			return
		end
		
		self.spawnThread = task.defer(function()
			while #self.zombies < self.MAX_ZOMBIE_COUNT do
				--# spawn zombie
				globalId += 1
				
				local newZombie: zombie.Zombie = zombie.new(globalId)
				newZombie:spawn()
				
				table.insert(self.zombies, newZombie)
				
				--# wait
				local min: number = self.ZOMBIE_SPAWN_INTERVAL[1]
				local max: number = self.ZOMBIE_SPAWN_INTERVAL[2]
				local randomInterval: number = math.random(min * 10, max * 10) / 10
				
				--print("spawn", randomInterval)
				task.wait(randomInterval)
			end
		end)
	end,
	
	stopSpawning = function(self: self)
		if not self.spawnThread then
			console.warn("Request to stop zombie spawning dropped: Thread does not exist")
			return
		end

		task.cancel(self.spawnThread)
		self.spawnThread = nil
	end,
	
	ready = function(self: self)
		self:startSpawning()
	end,
} :: self