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

local maid = require("@game/ReplicatedFirst/shared/libs/maid")
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
	isRunning: ( self: self ) -> boolean,
	startSpawning: ( self: self, maxZombieCount: number?, zombieSpawnInterval: number?, spawnInPlayerChunk: boolean? ) -> nil,
	stopSpawning: ( self: self ) -> nil,
	ready: ( self: self ) -> nil
}
export type ZombieService = self

-->

local baseplate = workspace.static.Baseplate
local globalId = 0

return {
	constructor = function(self: self)
		self.MAX_ZOMBIE_COUNT = 100
		self.ZOMBIE_SPAWN_INTERVAL = { 0, 4 } -- if the max zombie count is not met, zombies will spawn every x seconds to fill the count
		
		self.zombies = {}
		self.spawnThread = nil
	end,
	
	isRunning = function(self: self) : boolean
		return self.spawnThread ~= nil
	end,
	
	--[[
		Repeatedly spawns zombies in a random ranged interval, only
		pausing if the max number of zombies are reached.
		
		If the max number of zombies are reached and a zombie dies/
		is removed from self.zombies, a new one will be spawned in
		its place as long as this thread is still running.
		
		NOTE: All params are test params  that will override the
			  config -> for centralised testing.
	]]
	startSpawning = function(self: self, maxZombieCount: number?, zombieSpawnInterval: number?, spawnInPlayerChunk: boolean?)
		if self:isRunning() then
			console.warn("Request to start zombie spawning dropped: Thread already exists")
			return
		end
		
		--print("started spawning")
		self.spawnThread = task.defer(function()
			while #self.zombies < (maxZombieCount or self.MAX_ZOMBIE_COUNT) do
				--# spawn zombie
				globalId += 1
				
				local newZombie: zombie.Zombie = zombie.new(globalId, spawnInPlayerChunk)
				table.insert(self.zombies, newZombie)
				
				--# lifecycle management
				local zombieMaid: maid.Maid = maid.new()
				zombieMaid:GiveTask(newZombie)
				
				local function cleanup()
					if not newZombie then
						return
					end
					
					--print(`cleaned zombie {newZombie.id}`)
					table.remove(self.zombies, table.find(self.zombies, newZombie))
					
					zombieMaid:DoCleaning()
					zombieMaid = nil
					newZombie = nil
				end
				
				zombieMaid:GiveTask(newZombie.humanoid.Died:Connect(cleanup))
				zombieMaid:GiveTask(newZombie.model.Destroying:Connect(cleanup))
				zombieMaid:GiveTask(newZombie.root.AncestryChanged:Connect(function(child: Instance, parent: Instance)
					if child == nil or parent == nil then
						cleanup()
					end
				end))
				
				--# wait
				local min: number = zombieSpawnInterval or self.ZOMBIE_SPAWN_INTERVAL[1]
				local max: number = zombieSpawnInterval or self.ZOMBIE_SPAWN_INTERVAL[2]
				local randomInterval: number = math.random(min * 10, max * 10) / 10
				--print("spawn", randomInterval)
				task.wait(randomInterval)
			end
		end)
	end,
	
	stopSpawning = function(self: self)
		if not self:isRunning() then
			console.warn("Request to stop zombie spawning dropped: Thread does not exist")
			return
		end
		
		--print("spawning stopped")
		task.cancel(self.spawnThread)
		self.spawnThread = nil
	end,
	
	ready = function(self: self)
		--# TESTING
		self:startSpawning(1, 1, true)
	end,
} :: self