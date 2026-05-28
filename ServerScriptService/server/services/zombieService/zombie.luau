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
local params = require("@game/ReplicatedFirst/pip/params")
local try = require("@game/ReplicatedFirst/pip/try")

local chunkService = require("../chunkService")

local ragdollService = require("@game/ReplicatedFirst/shared/libs/ragdollService")
local stateMachine = require("@game/ReplicatedFirst/shared/utils/stateMachine")
local TweenUtils = require("@game/ReplicatedFirst/shared/utils/tweenUtils")
local maid = require("@game/ReplicatedFirst/shared/libs/maid")

-- [TYPES]
type BundledItems = { { AssetType: number } } --# sum type hackery bc roblox returns generic dict >:(

type IdleState = {
	thread: thread?
}
type RoamingState = {
	maid: maid.Maid
}
type AttackingState = {}
type BurningState = {}
type DeadState = {}

type self = {
	-- [ENTRIES]
	id: number,
	spawned: boolean,

	model: Model,
	root: Part,
	humanoid: Humanoid,
	
	walkSpeed: number,
	runSpeed: number,
	path: Path,
	raycastParams: RaycastParams,
	stateMachine: stateMachine.StateMachine,
	
	-- [FUNCTIONS]
	new: ( self: self ) -> nil,
	_setup: ( self: self ) -> nil,
	_setWalkSpeed: ( self: self, walkSpeed: number ) -> nil,
	_playAnimation: ( self: self, animationName: string ) -> nil,
	_stopAnimation: ( self: self, animationName: string ) -> nil,
	spawn: ( self: self ) -> nil,
	Destroy: ( self: self ) -> nil,
	ready: ( self: self ) -> nil
}
export type Zombie = self

-- [CONFIG]
--# outside self bc its a class, not a singleton
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
local SPAWN_RETRY_INTERVAL = 1
local SPAWN_RAYCAST_Y = 999
local IDLE_DURATION = { min = 1, max = 4 }
local WALK_SPEED = { min = 2, max = 6 }
local RUN_SPEED = { min = 8, max = 18 }
local ROAM_RADIUS = 40
local SEARCH_RADIUS = 30 -- player search radius
local DESTROY_DELAY = 3 -- how long the zombie will stay after dying before being deleted

-->

return class {
	new = function(self: self, id: number)
		--# data
		self.id = id
		self.spawned = false
		
		--# model
		self.model = game.ReplicatedFirst.shared.assets.ZombieRig:Clone()
		self.model.Name = `Zombie_{id}`
		self.root = self.model:WaitForChild("HumanoidRootPart")
		self.humanoid = self.model:WaitForChild("Humanoid")
		
		--# behaviour
		self.walkSpeed = math.random(WALK_SPEED.min, WALK_SPEED.max)
		self.runSpeed = math.random(RUN_SPEED.min, RUN_SPEED.max)
		self.path = game.PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentJumpHeight = 7,
			AgentMaxSlope = 45
		})
		self.raycastParams = RaycastParams.new()
		self.raycastParams.ExcludeInstances = { self.model }
		self.stateMachine = stateMachine.new(`ZOMBIE_{id}`, {
			idle = {
				thread = nil,
				enter = function(state: stateMachine.State & IdleState)
					--warn("idle")
					
					--[[
						Waits for a few seconds, then changes state to roaming.
					]]
					local waitDuration = math.random(IDLE_DURATION.min * 10, IDLE_DURATION.max * 10) / 10
					state.thread = task.delay(waitDuration, function()
						self.stateMachine:setState("roaming")
					end)
				end,
				exit = function(state: stateMachine.State & IdleState)
					if state.thread then
						task.cancel(state.thread)
						state.thread = nil
					end
				end
			},
			roaming = {
				maid = maid.new(),
				
				--[[
					Picks a random point around the model to go to. It raycasts
					to see if the point is traversable. If so, it will use
					MoveTo() directly, otherwise pathfinding is used.
					
					Once the destination is reached, the state is set
					to idle.
				]]
				enter = function(state: stateMachine.State & RoamingState)
					--warn("roaming")
					self:_setWalkSpeed(self.walkSpeed)
					
					--# search for point
					local randomPoint: Vector3 = self.root.Position + Vector3.new(
						math.random(-ROAM_RADIUS, ROAM_RADIUS),
						0,
						math.random(-ROAM_RADIUS, ROAM_RADIUS)
					)
					
					local result: RaycastResult = workspace:Raycast(
						self.root.Position, randomPoint - self.root.Position, self.raycastParams
					)
					if result then
						--# Pathfind
						--# if pathfind fails, it will change state to idle
						--print("pathfind")
						self.path:ComputeAsync(self.root.Position, randomPoint)
						if self.path.Status == Enum.PathStatus.NoPath then
							self.stateMachine:setState("idle")
							return
						end
						
						state.maid:GiveTask(self.path.Blocked:Connect(function()
							self.stateMachine:setState("idle")
						end))
						
						state.maid:GiveTask(task.defer(function()
							local waypoints: { PathWaypoint } = self.path:GetWaypoints()
							local currentWaypoint = 1
							
							state.maid:GiveTask(self.humanoid.MoveToFinished:Connect(function()
								currentWaypoint += 1
								local nextWaypoint: PathWaypoint? = waypoints[currentWaypoint]
								if nextWaypoint then
									self.humanoid:MoveTo(nextWaypoint.Position)
								else
									self.stateMachine:setState("idle")
								end
							end))

							self.humanoid:MoveTo(waypoints[1].Position)
						end))
					else
						--# MoveTo
						--print("moveto")
						self.humanoid:MoveTo(randomPoint)
						state.maid:GiveTask(self.humanoid.MoveToFinished:Once(function()
							self.stateMachine:setState("idle")
						end))
					end
				end,
				exit = function(state: stateMachine.State & RoamingState)
					if state.maid then
						state.maid:DoCleaning()
					end
				end,
			},
			attacking = {
				enter = function(state: stateMachine.State & AttackingState)
					self:_setWalkSpeed(self.runSpeed)
				end,
				exit = function(state: stateMachine.State & AttackingState)
					
				end,
			},
			burning = {
				enter = function(state: stateMachine.State & BurningState)
					
				end,
				exit = function(state: stateMachine.State & BurningState)
					
				end,
			},
			dead = {
				enter = function(state: stateMachine.State & DeadState)
					--# stop anims
					self:_stopAnimation("ZombieWalk")
					self:_stopAnimation("ZombieArmIdle")
					
					--# ragdoll
					--[[
						If the model falls into the void, Died fires and tries to ragdoll
						then errors bc of RagdollService. Check for root Y pos to avoid err.
						
						Try operation for clean err
					]]
					if self.root.Position.Y > -50 then
						try {
							function()
								ragdollService.Ragdoll(self.model)
							end,
							function(err: string)
								console.warn("Caught unhandled RagdollService error", err, "Doing nothing...")
							end,
						}
					end
				end,
			}
		})
	end,
	
	_setup = function(self: self)
		--# Dress the rig
		do
			--# NOTE: humanoidDesc in Humanoid & Character behaviour weirdly. Test to see which one works best
			local humanoidDescription: HumanoidDescription = self.model:WaitForChild("HumanoidDescription")
			
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
			for _, item: { AssetType: string, Id: number} in bundledItems do
				if item.AssetType == "DynamicHead" then --# NOTE: AssetType might change
					humanoidDescription.Head = item.Id
					break
				end
			end
			
			--# apply styles
			self.humanoid:ApplyDescriptionAsync(humanoidDescription)
		end
		
		--# Animations
		do
			--# walking anim
			local isWalking = false
			local currentSpeed = 0
			
			self.humanoid.Running:Connect(function(speed)
				if speed > 0 and not isWalking then
					--# play walk anim
					isWalking = true
					currentSpeed = speed
					self:_playAnimation("ZombieWalk", 1 / 16 * speed)
				elseif speed > 0 and speed ~= currentSpeed then
					--# adjust walk anim speed
					currentSpeed = speed
					local animationTrack = self.humanoid:FindFirstChild("Animator"):GetTrackByAnimationId(
						game.ReplicatedFirst.shared.animations.ZombieWalk.AnimationId
					)
					
					if animationTrack then
						animationTrack:AdjustSpeed(1 / 16 * speed)
					end
				elseif speed == 0 and isWalking then
					--# stop walk anim
					isWalking = false
					currentSpeed = 0
					
					self:_stopAnimation("ZombieWalk")
				end
			end)
			
			self:_playAnimation("ZombieArmIdle")
		end
		
		--# Player detection
		do
			
		end
		
		--# Ragdoll
		ragdollService.SetupRagdoll(self.model)
		
		--# Death events
		self.humanoid.Died:Connect(function()
			self.stateMachine:setState("dead")
		end)
	end,
	
	_setWalkSpeed = function(self: self, walkSpeed: number)
		params.expect("number", walkSpeed)
		if self.humanoid.WalkSpeed == walkSpeed then
			return
		end
		self.humanoid.WalkSpeed = walkSpeed
	end,
	
	--[[
		Plays an animation.
	]]
	_playAnimation = function(self: self, animationName: string)
		local animation: Animation = game.ReplicatedFirst.shared.animations:FindFirstChild(animationName)
		if not animation then
			console.deverr(`Animation "{animationName} does not exist`)
		end
		
		local animator: Animator = self.humanoid:FindFirstChild("Animator")
		local animationTrack: AnimationTrack? = animator:GetTrackByAnimationId(animation.AnimationId)
		
		if not animationTrack then
			try {
				function()
					animationTrack = animator:LoadAnimation(animation)
				end,
				function(err: string)
					console.warn(`Failed to load animation "{animationName}"`, `Err: {err}`)
				end,
			}
		end
		
		if animationTrack.IsPlaying then
			return
		end
		
		--print("playing", animationTrack, animator:GetFullName())
		animationTrack:Play()
	end,
	
	--[[
		Stops an animation with no fail states/handling.
	]]
	_stopAnimation = function(self: self, animationName: string)
		local animation: Animation = game.ReplicatedFirst.shared.animations:FindFirstChild(animationName)
		if not animation then
			console.deverr(`Animation "{animationName} does not exist`)
		end
		
		local animator: Animator = self.humanoid:FindFirstChild("Animator")
		local animationTrack: AnimationTrack? = animator:GetTrackByAnimationId(animation.AnimationId)
		
		if animationTrack and animationTrack.IsPlaying == true then
			animationTrack:Stop()
		end
	end,
	
	--[[
		Spawn the model into the world.
		
		1. fetches all chunks without players. Fail -> retry
		2. randomises between them
		3. raycast down from within the chunk's bounds from y999
		4. if baseplate is hit then spawn
		
		Should only be called once!!
	]]
	spawn = function(self: self)
		task.defer(function()
			if self.spawned then
				console.deverr("Cannot call spawn() twice")
			end
			
			repeat
				task.wait(SPAWN_RETRY_INTERVAL)
				--print("repeat")
				
				local spawnableChunks: { chunkService.Chunk } = chunkService:getChunksWithoutPlayers()
				if not spawnableChunks or spawnableChunks and #spawnableChunks == 0 then
					console.warn("No spawning chunks found", "Skipping...")
					continue
				end
				
				local randomChunk: chunkService.Chunk = spawnableChunks[math.random(1, #spawnableChunks)]
				local chunkTopRight = Vector3.new(randomChunk.X + chunkService.CHUNK_SIZE / 2, 0, randomChunk.Z + chunkService.CHUNK_SIZE / 2)
				local chunkBottomLeft = Vector3.new(randomChunk.X - chunkService.CHUNK_SIZE / 2, 0, randomChunk.Z - chunkService.CHUNK_SIZE / 2)
				
				local raycastOrigin = Vector3.new(
					chunkService.seed:NextNumber(chunkTopRight.X, chunkBottomLeft.X),
					SPAWN_RAYCAST_Y,
					chunkService.seed:NextNumber(chunkTopRight.Z, chunkBottomLeft.Z)
				)
				local result: RaycastResult = workspace:Raycast(raycastOrigin, Vector3.new(0, -SPAWN_RAYCAST_Y - 1, 0))
				if not result or result and not result.Instance then
					continue
				end
				if result.Instance ~= workspace.static.Baseplate then
					continue
				end
				
				self.model:PivotTo(CFrame.new(result.Position) + Vector3.new(0, 2, 0))
				self.model.Parent = workspace.dynamic.zombies
				
				self.spawned = true
				
				--[[
				
				--# part test
				local part = Instance.new("Part")
				part.Position = raycastOrigin
				part.Anchored = true
				part.Parent = workspace
				
				]]
			until self.spawned == true
			
			--# post-spawn events
			task.wait()
			self:_setup()
			self.stateMachine:setState("idle")
		end)
	end,
	
	Destroy = function(self: self)
		task.delay(DESTROY_DELAY, function()
			if self.model then
				self.model:Destroy()
				self.model = nil
			end
			if self.stateMachine then
				self.stateMachine:Destroy()
				self.stateMachine = nil
			end
			
			setmetatable(self, nil)
			table.clear(self)
		end)
	end,
	
	ready = function(self: self)
	end,
} :: self