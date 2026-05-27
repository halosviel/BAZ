--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 26
	
	[DESCRIPTION]
	
	[NOTES]
	- 
]=]

-- [REQUIRES]
local stateMachine = require("@game/ReplicatedFirst/shared/utils/stateMachine")
local chunkService = require("./chunkService")
local zombie = require("@self/zombie")

-- [TYPES]
type self = {
	-- [CONFIG]
	MAX_ZOMBIE_COUNT: number,
	ZOMBIE_SPAWN_INTERVAL: number,
	
	-- [ENTRIES]
	stateMachine: stateMachine.StateMachine,
	zombies: { zombie.Zombie },
	
	-- [FUNCTIONS]
	constructor: ( self: self ) -> nil,
	ready: ( self: self ) -> nil
}
export type ZombieService = self

-->

local baseplate = workspace.static.Baseplate

return {
	constructor = function(self: self)
		self.MAX_ZOMBIE_COUNT = 50
		self.ZOMBIE_SPAWN_INTERVAL = { 1, 3 } -- if the max zombie count is not met, zombies will spawn every x seconds to fill the count
		
		self.zombies = {}
		self.stateMachine = stateMachine.new("ZOMBIE_STATE_MACHINE", {
			
		})
	end,
	
	ready = function(self: self)
		
	end,
} :: self