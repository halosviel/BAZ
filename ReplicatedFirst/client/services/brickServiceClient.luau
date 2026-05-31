--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 23
	
	[DESCRIPTION]
	
	[NOTES]
	- naming conventions:
		brick - the physical brick in workspace
	    brickTool - the building tool
	    brickPart - the part/handle in tool
	    brickSkin - the part in bricks folder
	    brickSkinName - the brickSkin data str
	    brickPreview - the client-rendered part
]=]

-- [REQUIRES]
local console = require("@game/ReplicatedFirst/pip/console")

local dataServiceClient = require("@game/ReplicatedFirst/client/services/dataServiceClient")

local config = require("@game/ReplicatedFirst/shared/modules/config")
local events = require("@game/ReplicatedFirst/shared/modules/events")

local tweenUtils = require("@game/ReplicatedFirst/shared/utils/tweenUtils")
local soundUtils = require("@game/ReplicatedFirst/shared/utils/soundUtils")
local maid = require("@game/ReplicatedFirst/shared/libs/maid")

-- [TYPES]
type self = {
	-- [CONFIG]

	-- [ENTRIES]
	mouse: Mouse,
	activeBrickTool: Tool?,
	brickPreview: Part?,
	brickRotation: number,
	lastBuildTimestamp: number,
	requestPending: boolean,
	maid: maid.Maid,
	
	-- [FUNCTIONS]
	constructor: ( self: self ) -> nil,
	enterBuildMode: ( self: self ) -> nil,
	exitBuildMode: ( self: self ) -> nil,
	ready: ( self: self ) -> nil
}
export type BrickServiceClient = self

-->

return {
	constructor = function(self: self)
		self.mouse = game.Players.LocalPlayer:GetMouse()
		self.activeBrickTool = nil
		self.brickPreview = nil
		self.brickRotation = 0
		self.lastBuildTimestamp = os.clock()
		self.requestPending = false -- flag to disable inputs while waiting for a place event response
		self.maid = maid.new()
	end,
	
	enterBuildMode = function(self: self)
		dataServiceClient:read("brickSkin"):andThen(function(brickSkinName: string)
			--# create brick preview
			
			local brickSkin: Part? = game.ReplicatedFirst.assets.bricks:FindFirstChild(brickSkinName)
			if not brickSkin then
				brickSkin = game.ReplicatedFirst.assets.bricks:FindFirstChild("Default")
			end
			
			self.brickPreview = brickSkin:Clone()
			self.brickPreview.Transparency = config.buildPreviewTransparency
			self.brickPreview.CanCollide = false
			self.brickPreview.Parent = workspace.dynamic
			self.maid:GiveTask(self.brickPreview)
			--# position brick preview
			
			self.maid:GiveTask(game.RunService.RenderStepped:Connect(function()
				
				--# validation
				
				local character: Model? = game.Players.LocalPlayer.Character
				if not character then
					return
				end
				
				local root: Part? = character:FindFirstChild("HumanoidRootPart")
				if not root then
					return
				end
				
				local camera: Camera? = workspace.CurrentCamera
				if not camera then
					return
				end
				
				--# raycast
				--[[
					If for some reason the result or its Instance is nil (in the void/out
					of range perhaps), then the brick will be positioned at 0, 0, 0.
					
					TODO: fix jittering when hovering over far walls. 
					
					also half clanker code
				]]
				
				local params = RaycastParams.new()
				params.ExcludeInstances = { character, camera, self.brickPreview }
				
				local mouseDirection: Vector3 = (self.mouse.Hit.Position - camera.CFrame.Position).Unit
				local mouseHit: Vector3 = self.mouse.Hit.Position
				
				local result = workspace:Raycast(
					camera.CFrame.Position,
					mouseDirection * config.buildPreviewRadius,
					params
				)
				
				if not result or not result.Instance then
					local groundOrigin = Vector3.new(mouseHit.X, root.Position.Y + 50, mouseHit.Z)
					result = workspace:Raycast(groundOrigin, Vector3.new(0, -100, 0), params)
				end
				
				if not result or result and not result.Instance then
					return
				end
				
				--# calculate offset accounting for rotation
				local brickRotationCFrame = CFrame.Angles(0, math.rad(self.brickRotation), 0)
				local localNormal = brickRotationCFrame:VectorToObjectSpace(result.Normal)
				local halfSize = self.brickPreview.Size / 2
				local offset = math.abs(localNormal.X) * halfSize.X
					+ math.abs(localNormal.Y) * halfSize.Y
					+ math.abs(localNormal.Z) * halfSize.Z
				
				local resultPos: Vector3
				if math.abs(result.Normal.Y) > 0.5 then
					resultPos = result.Position + Vector3.new(0, result.Normal.Y * offset, 0)
				else
					resultPos = result.Position + result.Normal * offset
				end
				
				--# color
				--# ( based on distance )
				if self.brickPreview then
					if (root.Position - resultPos).Magnitude >= config.buildRadius then
						self.brickPreview.Color = config.buildInvalidColor
					else
						self.brickPreview.Color = brickSkin.Color
					end
				end
				
				--# place preview
				--# ( rounded )
				if self.brickPreview then
					local snappedPos = Vector3.new(
						math.round(resultPos.X / config.gridSize) * config.gridSize,
						math.round(resultPos.Y / config.gridSize) * config.gridSize,
						math.round(resultPos.Z / config.gridSize) * config.gridSize
					)
					self.brickPreview.CFrame = CFrame.new(snappedPos) * brickRotationCFrame
				end
			end))
			
			--# keybinds
			
			self.maid:GiveTask(game.ReplicatedFirst.assets.inputs.BrickControls.RotateBrick.Pressed:Connect(function()
				if self.brickPreview then
					self.brickRotation = (self.brickRotation + 90) % 360
				end
			end))
			
			self.maid:GiveTask(game.ReplicatedFirst.assets.inputs.BrickControls.PlaceBrick.Pressed:Connect(function()
				if os.clock() - self.lastBuildTimestamp < config.buildCooldown then
					return
				end
				
				if self.requestPending then
					return
				end
				self.requestPending = true
				
				if self.brickPreview then
					--# no faulty types. any modification is 100% tampering
					local placeSuccess: boolean, message: string? = events.placeBrick:Fire(self.brickPreview.CFrame)
					if placeSuccess then
						soundUtils.wrap("PlaceBrick")
							:clone()
							:setParent(game.SoundService)
							:autoDestroy()
							:setRandomPitch(0.1)
							:play()
						
						self.lastBuildTimestamp = os.clock()
					else
						if message then
							console.warn(`Brick place request rejected: {message}`)
						end
					end
					self.requestPending = false
				end
			end))
		end)
	end,
	
	exitBuildMode = function(self: self)
		if self.maid then
			self.maid:DoCleaning()
		end
	end,
	
	ready = function(self: self)
		
		--[[
			Look for a brick tool when the player joins, and subscribe to future
			initBrickTool events fired from the server.
		]]
		local function initBrickTool(brickTool: Tool)
			if not brickTool then
				console.warn("Unable to initiate brick tool: Nothing passed", "Check: Did the server pass anything?", "Doing nothing...")
				return
			end
			if not brickTool:IsA("Tool") then
				return
			end
			if brickTool.Name ~= config.buildToolName then
				return
			end
			if brickTool == self.activeBrickTool then
				print("same")
				return
			end
			self.activeBrickTool = brickTool
			
			local brickPart: Part? = brickTool:WaitForChild("Handle")
			brickPart.Transparency = 0.7
			
			brickTool.Equipped:Connect(function()
				self:enterBuildMode()
			end)
			
			brickTool.Unequipped:Connect(function()
				self:exitBuildMode()
			end)
			
			brickTool.AncestryChanged:Connect(function(_: Instance, parent: Instance)
				if parent ~= game.Players.LocalPlayer.Backpack and parent ~= game.Players.LocalPlayer.Character then
					console.warn("Brick tool was moved/removed. Exiting build mode...")
					self.activeBrickTool = nil
					self:exitBuildMode()
				end
			end)
		end
		
		events.initBrickTool.OnClientEvent:Connect(initBrickTool)
		for _, obj: Instance in game.Players.LocalPlayer.Backpack:GetChildren() do
			initBrickTool(obj)
		end
	end,
} :: self