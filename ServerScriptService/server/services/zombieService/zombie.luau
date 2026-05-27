--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 27
	
	[DESCRIPTION]
	
	[NOTES]
	- 
]=]

-- [REQUIRES]
local class = require("@game/ReplicatedFirst/pip/class")
local chunkService = require("../chunkService")

-- [TYPES]
type self = {
	-- [CONFIG]
	SPAWN_RAYCAST_Y: number,
	
	-- [ENTRIES]
	model: Model,
	
	-- [FUNCTIONS]
	new: ( self: self ) -> nil,
	spawn: ( self: self ) -> nil,
	ready: ( self: self ) -> nil
}
export type Zombie = self

-->

return class {
	new = function(self: self)
		self.SPAWN_RAYCAST_Y = 999
		
		self.model = game.ReplicatedFirst.shared.assets.ZombieRig:Clone()
	end,
	
	spawn = function(self: self)
		local spawned = false
		repeat
			task.wait()
			print("repeat")
			
			local chunksWithoutPlayers: { chunkService.Chunk } = chunkService:getChunksWithoutPlayers()
			local randomChunk: chunkService.Chunk = chunksWithoutPlayers[math.random(1, #chunksWithoutPlayers)]
			
			local chunkTopRight = Vector3.new(randomChunk.X + chunkService.CHUNK_SIZE / 2, 0, randomChunk.Z + chunkService.CHUNK_SIZE / 2)
			local chunkBottomLeft = Vector3.new(randomChunk.X - chunkService.CHUNK_SIZE / 2, 0, randomChunk.Z - chunkService.CHUNK_SIZE / 2)
			
			local raycastOrigin = Vector3.new(
				chunkService.seed:NextNumber(chunkTopRight.X, chunkBottomLeft.X),
				self.SPAWN_RAYCAST_Y,
				chunkService.seed:NextNumber(chunkTopRight.Z, chunkBottomLeft.Z)
			)
			local result: RaycastResult = workspace:Raycast(raycastOrigin, Vector3.new(0, -self.SPAWN_RAYCAST_Y - 1, 0))
			if not result or result and not result.Instance then
				continue
			end
			if result.Instance ~= workspace.static.Baseplate then
				continue
			end
			
			self.model:PivotTo(CFrame.new(result.Position) + Vector3.new(0, 2, 0))
			self.model.Parent = workspace.dynamic.zombies
			
			spawned = true
			
			--[[
			
			--# part test
			local part = Instance.new("Part")
			part.Position = raycastOrigin
			part.Anchored = true
			part.Parent = workspace
			
			]]
		until spawned == true
	end,
	
	ready = function(self: self)
		
	end,
} :: self