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
local console = require("@game/ReplicatedFirst/pip/console")
local try = require("@game/ReplicatedFirst/pip/try")

local stateMachine = require("@game/ReplicatedFirst/shared/utils/stateMachine")
local chunkService = require("../chunkService")

-- [TYPES]
type BundledItems = { { AssetType: number } } --# sum type hackery bc roblox returns generic dict >:(

type self = {
	-- [CONFIG]
	SPAWN_RAYCAST_Y: number,
	
	-- [ENTRIES]
	id: number,
	model: Model,
	stateMachine: stateMachine.StateMachine,
	
	-- [FUNCTIONS]
	new: ( self: self ) -> nil,
	_applyStyles: ( self: self ) -> nil,
	spawn: ( self: self ) -> nil,
	ready: ( self: self ) -> nil
}
export type Zombie = self

-->

-- [CONFIG]
local TORSO_COLORS = {
	Color3.fromRGB(12, 70, 40), Color3.fromRGB(70, 70, 70), Color3.fromRGB(103, 103, 103),
	Color3.fromRGB(16, 16, 16), Color3.fromRGB(158, 158, 158), Color3.fromRGB(90, 14, 15),
	Color3.fromRGB(90, 14, 80), Color3.fromRGB(20, 16, 90), Color3.fromRGB(55, 77, 122),
	Color3.fromRGB(30, 122, 122), Color3.fromRGB(117, 122, 86), Color3.fromRGB(122, 100, 69),
	Color3.fromRGB(81, 69, 51),
}
local HEADS = {
	48108254826353, 189682885115008, 274897006582337, 107770861134701, 40329797566983, 69132779144008, 
}

-->

return class {
	new = function(self: self, id: number)
		self.SPAWN_RAYCAST_Y = 999
		
		self.id = id
		self.model = game.ReplicatedFirst.shared.assets.ZombieRig:Clone()
		self.stateMachine = stateMachine.new(`ZOMBIE_{id}`, {
			idle = {
				enter = function()
					
				end,
			}
		})
	end,
	
	--[[
		Dress the rig.
	]]
	_applyStyles = function(self: self)
		local humanoidDescription: HumanoidDescription = self.model:WaitForChild("HumanoidDescription")
		local humanoid: Humanoid = self.model:WaitForChild("Humanoid")
		
		--# torso color
		humanoidDescription.TorsoColor = TORSO_COLORS[math.random(1, #TORSO_COLORS)]
		
		--# head
		local randomHeadId: string = HEADS[math.random(1, #HEADS)]
		
		local done: boolean, itemDetails: { BundledItems: BundledItems } = try {
			function()
				return game.AvatarEditorService:GetItemDetailsAsync(randomHeadId, Enum.AvatarItemType.Bundle)
			end,
			function(err: string)
				console.warn("Failed to fetch head info via GetItemDetailsAsync()", err)
			end,
		}
		if not done then
			return
		end
		
		local bundledItems: BundledItems = itemDetails.BundledItems
		for _, obj in bundledItems do
			if obj.AssetType == "DynamicHead" then --# NOTE: AssetType might change
				humanoidDescription.Head = obj.Id
				break
			end
		end
		
		--# apply changes
		humanoid:ApplyDescriptionAsync(humanoidDescription)
	end,
	
	spawn = function(self: self)
		local spawned = false
		repeat
			task.wait()
			--print("repeat")
			
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
			self:_applyStyles()
			
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
		self.stateMachine:setState("idle")
	end,
} :: self