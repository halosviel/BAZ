--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 26
	
	[DESCRIPTION]
	Contains entries and functions to do with chunks.
	
	[NOTES]
	- 
]=]

-- [REQUIRES]

-- [TYPES]
export type Chunk = Vector3

type self = {
	-- [CONFIG]
	CHUNK_SIZE: number,
	CHUNK_RADIUS: number,
	
	-- [ENTRIES]
	seed: Random,
	chunks: { Chunk },
	
	-- [FUNCTIONS]
	constructor: ( self: self ) -> nil,
	_cacheChunks: ( self: self ) -> nil,
	getChunksWithPlayers: ( self: self ) -> { Chunk },
	getChunksWithoutPlayers: ( self: self ) -> { Chunk },
	ready: ( self: self ) -> nil
}
export type ChunkService = self

-->

return {
	constructor = function(self: self)
		self.CHUNK_SIZE = 50
		self.CHUNK_RADIUS = 5 -- how many chunks in each direction will be generated
		
		self.seed = Random.new() -- a random number used for zombie spawning
		self.chunks = {}
	end,
	
	--[[
		Calculates chunks from 0, 0, 0 and stores them as Vector3s
		in self.chunks.
		
		[NOTES]
		- Should only be called once.
		- clanker code
	]]
	_cacheChunks = function(self: self)
		local origin = Vector3.new(0, 0, 0)
		for x: number = -self.CHUNK_RADIUS, self.CHUNK_RADIUS do
			for z = -self.CHUNK_RADIUS, self.CHUNK_RADIUS do
				table.insert(self.chunks, Vector3.new(x * self.CHUNK_SIZE, 0, z * self.CHUNK_SIZE))
			end
		end
	end,
	
	--[[
		Returns an array of chunks with players by querying each
		chunk's bounds with every player's position.
	]]
	getChunksWithPlayers = function(self: self): { Chunk }
		--# clanker code
		local occupiedChunks: { Chunk } = {}
		for _, chunk: Chunk in self.chunks do
			for _, player in game.Players:GetPlayers() do
				local character: Model? = player.Character
				if not character then
					continue
				end
				
				local root: Part? = character:FindFirstChild("HumanoidRootPart")
				if not root then
					continue
				end
				
				local half = self.CHUNK_SIZE / 2
				local dx = math.abs(root.Position.X - chunk.X)
				local dz = math.abs(root.Position.Z - chunk.Z)
				
				if dx <= half and dz <= half then
					table.insert(occupiedChunks, chunk)
					break
				end
			end
		end
		
		return occupiedChunks
	end,
	
	--[[
		Returns an array of chunks with on players by comapring
		self.chunks with the result of getChunksWithPlayers.
	]]
	getChunksWithoutPlayers = function(self: self): { Chunk }
		local chunksWithPlayers: { Chunk } = self:getChunksWithPlayers()
		local chunksWithoutPlayers: { Chunk } = {}
		
		for _, chunk: Chunk in self.chunks do
			if table.find(chunksWithPlayers, chunk) then
				continue
			end
			table.insert(chunksWithoutPlayers, chunk)
		end
		
		return chunksWithoutPlayers
	end,
	
	ready = function(self: self)
		self:_cacheChunks()
		
		--# chunk visual test
		--[[for _, pos in self.chunks do
			local p = Instance.new("Part")
			p.Anchored = true
			p.Position = pos
			p.Parent = workspace
		end]]
	end,
} :: self