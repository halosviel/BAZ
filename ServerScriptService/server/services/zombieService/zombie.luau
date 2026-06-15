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
local soundUtils = require("@game/ReplicatedFirst/shared/utils/soundUtils")

local signal = require("@game/ReplicatedFirst/shared/libs/cuteSignal")
local maid = require("@game/ReplicatedFirst/shared/libs/maid")

-- [TYPES]
type BundledItems = { { AssetType: number } } --# sum type hackery bc roblox returns generic dict >:(

type IdleState = {
	thread: thread?
}
type RoamingState = {
	maid: maid.Maid?
}
type AttackingState = {
	maid: maid.Maid?
}
type BurningState = {}
type DeadState = {}

type self = {
	-- [ENTRIES]
	id: number,
	spawned: boolean,

	model: Model,
	head: Part,
	root: Part,
	humanoid: Humanoid,

	maid: maid.Maid,
	target: Model?,
	searchCoroutine: thread?,
	lastDamage: number,
	lastNoise: number,
	
	walkSpeed: number,
	runSpeed: number,
	path: Path,
	raycastParams: RaycastParams,
	stateMachine: stateMachine.StateMachine,
	
	-- [FUNCTIONS]
	new: ( self: self ) -> nil,
	_spawn: ( self: self ) -> nil,
	_setup: ( self: self ) -> nil,
	_setWalkSpeed: ( self: self, walkSpeed: number ) -> nil,
	_playAnimation: ( self: self, animationName: string ) -> nil,
	_stopAnimation: ( self: self, animationName: string ) -> nil,
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
local SPAWN_RETRY_INTERVAL = 1 -- if spawn fails, retry after this time
local SPAWN_RAYCAST_Y = 999 -- how far up the spawn raycast starts from (adjust for tall terrain)
local IDLE_DURATION = { min = 1, max = 4 } -- how long the zombie will stand still for while idle
local WALK_SPEED = { min = 2, max = 6 }
local RUN_SPEED = { min = 8, max = 18 }
local ROAM_RADIUS = 40 -- how far from itself the zombie will traverse during roaming
local SEARCH_RADIUS = 50 -- player search/chase radius
local SEARCH_SLOW_INTERVAL = 1 -- search update interval with no target
local SEARCH_FAST_INTERVAL = 0.2 -- search update interval while chasing target
local DESTROY_DELAY = 3 -- how long the zombie will stay after dying before being deleted
local DAMAGE = { min = 5, max = 20 } -- randomised per hit
local DAMAGE_INTERVAL = 1
local NOISE_INTERVAL = { min = 5, max = 15 } -- how often the zombie will make noises
local BURN_CHECK_INTERVAL = 1
local BURN_DAMAGE = 15
local MAX_BURNING_LIMBS = { min = 1, max = 2 } -- the random number of body parts that will catch fire when burning 

-->

return class {
	new = function(self: self, id: number)
		--# data
		self.id = id
		self.spawned = false
		
		--# model
		self.model = game.ReplicatedFirst.assets.models.ZombieRig:Clone()
		self.model.Name = `Zombie_{id}`
		self.head = self.model:WaitForChild("Head")
		self.root = self.model:WaitForChild("HumanoidRootPart")
		self.humanoid = self.model:WaitForChild("Humanoid")
		
		--# state
		self.maid = maid.new()
		self.target = nil
		self.searchCoroutine = nil
		self.lastDamage = os.clock()
		self.lastNoise = os.clock()
		
		--# behaviour
		self.walkSpeed = math.random(WALK_SPEED.min, WALK_SPEED.max)
		self.runSpeed = math.random(RUN_SPEED.min, RUN_SPEED.max)
		self.path = game:GetService("PathfindingService"):CreatePath({
			AgentRadius = 2,
			AgentHeight = 3,
			AgentCanJump = false,
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
				maid = nil,
				
				--[[
					Picks a random point around the model to go to. It raycasts
					to see if the point is traversable. If so, it will use
					MoveTo() directly, otherwise pathfinding is used.
					
					Once the destination is reached, the state is set
					to idle.
				]]
				enter = function(state: stateMachine.State & RoamingState)
					--warn("roaming")
					state.maid = maid.new() --# cleaning ts is tricky if we just create it once. TODO: optimize later
					self.maid:GiveTask(state.maid)
					self:_setWalkSpeed(self.walkSpeed)
					
					--# search for point
					local randomPoint: Vector3 = self.root.Position + Vector3.new(
						math.random(-ROAM_RADIUS, ROAM_RADIUS),
						0,
						math.random(-ROAM_RADIUS, ROAM_RADIUS)
					)
					
					local result: RaycastResult = workspace:Raycast(
						self.head.Position, randomPoint - self.root.Position, self.raycastParams
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
						
						if not state.maid then
							print("NO MAIDENS?!?!?!", state)
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
									--# path finished
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
					--# cancel movement??
					--# chasing *should* overwrite and use its own moveto, so probs dont need ts
					--self.humanoid:MoveTo(self.root.Position)
					
					if state.maid then
						state.maid:DoCleaning()
						state.maid = nil
					end
				end,
			},
			
			--# NOTE: duplicate logic, so just read notes from roaming state above ^^
			attacking = {
				maid = nil,
				enter = function(state: stateMachine.State & AttackingState)
					state.maid = maid.new()
					self.maid:GiveTask(state.maid)
					self:_setWalkSpeed(self.runSpeed)
					
					--# helpers
					local pathfindingTask: thread?
					local pathfindingCon: RBXScriptConnection?
					local pathfindingFinished = false --# flag set within pathfinding() for loop to cancel pathfinding
					
					local function exit()
						--warn("exit")
						self.stateMachine:setState("idle")
					end
					
					local function moveToTarget()
						local rootPart: Part? = self.target:FindFirstChild("HumanoidRootPart")
						if not rootPart then
							return
						end
						
						--# clean pathfinding
						
						if pathfindingTask then
							task.cancel(pathfindingTask)
							pathfindingTask = nil
						end
						if pathfindingCon then
							pathfindingCon:Disconnect()
							pathfindingCon = nil
						end
						
						--# move to target
						
						--warn("moveto")
						self.humanoid:MoveTo(rootPart.Position)
					end
					
					local function pathfindToTarget()
						local rootPart: Part? = self.target:FindFirstChild("HumanoidRootPart")
						if not rootPart then
							return
						end
						
						self.path:ComputeAsync(self.root.Position, rootPart.Position)
						if self.path.Status == Enum.PathStatus.NoPath then
							--warn("no path")
							pathfindingFinished = true
							return
						end
						
						state.maid:GiveTask(self.path.Blocked:Connect(function()
							--warn("path blocked")
							pathfindingFinished = true
						end))
						
						pathfindingTask = task.defer(function()
							local waypoints: { PathWaypoint } = self.path:GetWaypoints()
							if waypoints == nil
								or waypoints and #waypoints == 0
								or waypoints and waypoints[1] == nil
							then
								--warn("no waypoints")
								pathfindingFinished = true
								return
							end
							
							local currentWaypoint = 2 --# override to waypoint 2 due to back flickering
							
							--# must make new con var; dont give to maid -> cancelling task does not clean connections
							pathfindingCon = self.humanoid.MoveToFinished:Connect(function()
								currentWaypoint += 1
								local nextWaypoint: PathWaypoint? = waypoints[currentWaypoint]
								if nextWaypoint then
									self.humanoid:MoveTo(nextWaypoint.Position)
								else
									--# path finished
									pathfindingFinished = true
									--warn("path finished")
									return
								end
							end)
							
							--warn("pathfind")
							state.maid:GiveTask(pathfindingCon)
							self.humanoid:MoveTo(waypoints[currentWaypoint].Position)
						end)
					end
					
					--[[
						LOGIC:
						
						Every SEARCH_FAST_INTERVAL seconds:
						- check to see if target exists/is valid/in range
						- raycast to see if they are in line of sight
						- if they are, cancel any current pathfinding task and MoveTo() them
						- if not, then pathfind to them
						
						The loop should run as long as the state is active.
					]]
					state.maid:GiveTask(task.defer(function()
						--# maid snapshot to fix nil maid in roaming state. see if statement under task.wait
						local localMaid: maid.Maid? = state.maid
						
						while true do
							task.wait(SEARCH_FAST_INTERVAL)
							if not localMaid or state.maid ~= localMaid then
								return
							end
							
							--# Validate target
							
							if not self.target then
								exit()
								return
							end
							
							local rootPart: Part? = self.target:FindFirstChild("HumanoidRootPart")
							if not rootPart then
								exit()
								return
							end
							if (self.root.Position - rootPart.Position).Magnitude >= SEARCH_RADIUS then
								exit()
								return
							end
							
							local humanoid: Humanoid? = self.target:FindFirstChild("Humanoid")
							if not humanoid then
								exit()
								return
							end
							if humanoid.Health == 0 then
								exit()
								return
							end
							
							--# Raycast
							
							local result: RaycastResult = workspace:Raycast(
								self.head.Position, rootPart.Position - self.root.Position, self.raycastParams
							)
							
							--# MoveTo conditions
							
							if not result then --# no obstruction
								moveToTarget()
								continue
							end
							
							if result and not result.Instance then --# no obstruction
								moveToTarget()
								continue
							end
							
							if result and result.Instance:IsDescendantOf(self.target) then --# direct line of sight
								moveToTarget()
								continue
							end
							
							--# Pathfind
							
							if pathfindingFinished then --# pathfinding finished/blocked/failed, reset it.
								if pathfindingTask then
									task.cancel(pathfindingTask)
									pathfindingTask = nil
								end
								if pathfindingCon then
									pathfindingCon:Disconnect()
									pathfindingCon = nil
								end
							end
							
							if pathfindingTask or pathfindingCon then
								continue
							end
							
							pathfindToTarget()
						end
					end))
				end,
				exit = function(state: stateMachine.State & AttackingState)
					if state.maid then
						state.maid:DoCleaning()
						state.maid = nil
					end
					
					if state.subMaid then
						state.subMaid:DoCleaning()
						state.subMaid = nil
					end
					
					self.target = nil
					
					--# resume player search thread
					if self.searchCoroutine then
						coroutine.resume(self.searchCoroutine)
					end
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
					
					--# sound
					if self.head then
						soundUtils.wrap("ZombieAttack")
							:clone()
							:setParent(self.head)
							:setRandomPitch(0.2)
							:autoDestroy()
							:play()
					end
					
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
	
	--[[
		Spawn the model into the world.
		
		1. fetches all chunks without players. Fail -> retry
		2. randomises between them
		3. raycast down from within the chunk's bounds from y999
		4. if baseplate is hit then spawn
		
		Should only be called once!!
	]]
	_spawn = function(self: self)
		self.maid:GiveTask(task.defer(function()
			if self.spawned then
				console.deverr("Cannot call spawn() twice")
			end
			
			repeat
				task.wait(SPAWN_RETRY_INTERVAL)
				--print("repeat")
				
				local spawnableChunks: { chunkService.Chunk } = chunkService:getChunksWithoutPlayers()
				if not spawnableChunks or spawnableChunks and #spawnableChunks == 0 then
					console.warn("No spawnable chunks found", "Skipping...")
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
			self:_setup()
			self.stateMachine:setState("idle")
		end))
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
			
			--# if head fetch fails, allow the humanoid to still apply desc for
			--# torso color -> do not return end
			if done then
				local bundledItems: BundledItems = itemDetails.BundledItems
				for _, item: { AssetType: string, Id: number} in bundledItems do
					if item.AssetType == "DynamicHead" then --# NOTE: AssetType might change
						humanoidDescription.Head = item.Id
						break
					end
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
						game.ReplicatedFirst.assets.animations.ZombieWalk.AnimationId
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
		--[[
			LOGIC:
			- Start a new thread that searches for the first player in range every
			  SEARCH_SLOW_INTERVAL seconds.
			- If a player is found, it will set the player's character as self.target
			  and switches state to attacking.
			- The thread will pause itself, and the attacking state handles all chasing
			  and block breaking logic.
			- The thread continues once the attacking state changes state from within
			  itself.
		]]
		do
			--# construct the thread
			self.searchCoroutine = coroutine.create(function()
				while true do
					--print("looking for players")
					task.wait(SEARCH_SLOW_INTERVAL)
					
					if self.target then
						continue
					end
					
					--# look for a target
					--# searches for the first player within range
					--# ( save some performance against table.sort i guess + intentionally weirder behaviour :D )
					for _, player in game.Players:GetPlayers() do
						local character: Model? = player.Character
						if not character then
							continue
						end
						
						local rootPart: Part? = character:FindFirstChild("HumanoidRootPart")
						if not rootPart then
							continue
						end
						
						local humanoid: Humanoid? = character:FindFirstChild("Humanoid")
						if not humanoid then
							continue
						end
						if humanoid.Health == 0 then
							continue
						end
						
						if (self.root.Position - rootPart.Position).Magnitude >= SEARCH_RADIUS then
							continue
						end
						--print("player found")
						
						self.target = character
						self.stateMachine:setState("attacking")
						
						--# yield the thread
						coroutine.yield()
						break
					end
				end
			end)
			
			--# pass it to maid & start thread
			self.maid:GiveTask(self.searchCoroutine)
			coroutine.resume(self.searchCoroutine)
		end
		
		--# Hit detection
		do
			self.maid:GiveTask(self.root.Touched:Connect(function(hit: Instance)
				if not self.target then
					return
				end
				if not hit:IsDescendantOf(self.target) then
					return
				end
				
				local humanoid: Humanoid? = self.target:FindFirstChild("Humanoid")
				if not humanoid then
					return
				end
				
				if self.humanoid.Health == 0 then
					return
				end
				
				if os.clock() - self.lastDamage < DAMAGE_INTERVAL then
					return
				end
				self.lastDamage = os.clock()
				
				--# deal damage
				local damage: number = math.random(DAMAGE.min, DAMAGE.max)
				humanoid.Health -= damage
				
				--# anim
				self:_playAnimation("ZombieArmAttack")
				
				--# sound
				soundUtils.wrap("ZombieAttack")
					:clone()
					:setParent(self.head)
					:setRandomPitch(0.2)
					:autoDestroy()
					:play()
			end))
		end
		
		--# damage detection
		do
			local damageSounds: { Sound } = game.SoundService.sfx.zombie.damage:GetChildren()
			local lastHealth: number = self.humanoid.Health
			
			self.maid:GiveTask(self.humanoid:GetPropertyChangedSignal("Health"):Connect(function()
				--# dead
				if self.humanoid.Health == 0 then
					self.stateMachine:setState("dead")
					--# ^ ragdoll + end the zombie lifecycle
					return
				end
				
				--# took damage
				if self.humanoid.Health < lastHealth then
					--# sound
					local randomSound: Sound = damageSounds[math.random(1, #damageSounds)]
					soundUtils.wrap("ZombieDamage")
						:clone()
						:setParent(self.head)
						:setRandomPitch(0.2)
						:autoDestroy()
						:play()
				end
				
				lastHealth = self.humanoid.Health
			end))
		end
		
		--# interval sounds
		do
			local noises: { Sound } = game.SoundService.sfx.zombie.noises:GetChildren()
			
			self.maid:GiveTask(task.defer(function()
				while true do
					local randomInterval: number = math.random(NOISE_INTERVAL.min, NOISE_INTERVAL.max)
					task.wait(randomInterval)
					
					local randomSound: Sound = noises[math.random(1, #noises)]
					soundUtils.wrap(randomSound)
						:clone()
						:setParent(self.head)
						:setRandomPitch(0.2)
						:autoDestroy()
						:play()
				end
			end))
		end
		
		--# Burning
		--[[
			if a raycast from high above hits the zombie, then they are
			considered to have nothing over their head and will burn.
		]]
		do
			local onFire = false
			local particles: { ParticleEmitter } = {}
			
			local function addFire()
				if onFire then
					return
				end
				
				local limbs: { Part } = {}
				for _, obj: Instance in self.model:GetChildren() do
					if not obj:IsA("BasePart") then
						continue
					end
					if obj == self.root then
						continue
					end
					
					table.insert(limbs, obj)
				end
				
				for i = 1, math.random(MAX_BURNING_LIMBS.min, MAX_BURNING_LIMBS.max) do
					local randomLimb: Part = limbs[math.random(1, #limbs)]
					
					local fireParticles: ParticleEmitter = game.ReplicatedFirst.assets.models.FireParticles:Clone()
					fireParticles.Parent = randomLimb
					
					table.insert(particles, fireParticles)
				end
				
				onFire = true
			end
			
			local function removeFire()
				if not onFire then
					return
				end
				
				for _, fireParticles: ParticleEmitter in particles do
					fireParticles:Destroy()
				end
				
				table.clear(particles)
				onFire = false
			end
			
			self.maid:GiveTask(task.defer(function()
				while true do
					task.wait(BURN_CHECK_INTERVAL)
					
					local origin = self.root.Position + Vector3.new(0, SPAWN_RAYCAST_Y, 0)
					local result: RaycastResult? = workspace:Raycast(origin, self.root.Position - origin)
					
					if not result then
						return
					end
					
					if not result.Instance then
						return
					end
					
					--# roof! :D
					if not result.Instance:IsDescendantOf(self.model) then
						removeFire()
						return
					end
					
					--# BURNNNNNN
					--# WARNING: hardcoded bc cyclic dependency to clockService
					if game.Lighting.ClockTime > 7 and game.Lighting.ClockTime < 17 then
						--# add fire (has cd)
						addFire()
						
						--# take damage
						self.humanoid.Health -= BURN_DAMAGE
					else
						removeFire() --# also has cd
					end
				end
			end))
		end
		
		--# Ragdoll setup
		do
			ragdollService.SetupRagdoll(self.model)
		end
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
		local animation: Animation = game.ReplicatedFirst.assets.animations:FindFirstChild(animationName)
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
		local animation: Animation = game.ReplicatedFirst.assets.animations:FindFirstChild(animationName)
		if not animation then
			console.deverr(`Animation "{animationName} does not exist`)
		end
		
		local animator: Animator = self.humanoid:FindFirstChild("Animator")
		local animationTrack: AnimationTrack? = animator:GetTrackByAnimationId(animation.AnimationId)
		
		if animationTrack and animationTrack.IsPlaying == true then
			animationTrack:Stop()
		end
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
			if self.maid then
				self.maid:DoCleaning()
				self.maid = nil
			end
			
			setmetatable(self, nil)
			table.clear(self)
		end)
	end,
	
	ready = function(self: self)
		self:_spawn()
	end,
} :: self