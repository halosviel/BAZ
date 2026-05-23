--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 23
	
	[DESCRIPTION]
	
	[NOTES]
	- naming conventions: 
	    brickTool (tool)
	    brickPart (part/handle in tool)
	    brickSkin (part in bricks folder)
	    brickSkinName (brickSkin data str)
	    brickPreview (the client-rendered part)
]=]

-- [REQUIRES]
local console = require("@game/ReplicatedFirst/pip/console")

local dataServiceClient = require("@game/ReplicatedFirst/client/services/dataServiceClient")

local config = require("@game/ReplicatedFirst/shared/config")
local tweenUtils = require("@game/ReplicatedFirst/shared/utils/tweenUtils")

-- [TYPES]
type self = {
	-- [CONFIG]

	-- [ENTRIES]
	mouse: Mouse,
	renderCon: RBXScriptSignal?,
	brickPreview: Part?,
	
	-- [FUNCTIONS]
	constructor: ( self: self ) -> nil,
	enterBuildMode: ( self: self ) -> nil,
	exitBuildMode: ( self: self ) -> nil,
	ready: ( self: self ) -> nil
}
export type Service = self

-->

return {
	constructor = function(self: self)
		self.mouse = game.Players.LocalPlayer:GetMouse()
		self.renderCon = nil
		self.brickPreview = nil
	end,
	
	enterBuildMode = function(self: self)
		dataServiceClient:read("brickSkin"):andThen(function(brickSkinName: string)
			
			--# create brick preview
			
			local brickSkin: Part? = game.ReplicatedFirst.shared.bricks:FindFirstChild(brickSkinName)
			if not brickSkin then
				brickSkin = game.ReplicatedFirst.shared.bricks:FindFirstChild("Default")
			end
			
			self.brickPreview = brickSkin:Clone()
			self.brickPreview.Transparency = config.buildPreviewTransparency
			self.brickPreview.CanCollide = false
			self.brickPreview.Parent = workspace.dynamic
			
			--# position brick preview
			
			self.renderCon = game.RunService.RenderStepped:Connect(function()
				
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
				
				local resultPos = result.Position + result.Normal * (self.brickPreview.Size / 2)
				local normalOffset = result.Normal * (self.brickPreview.Size / 2)

				if math.abs(result.Normal.Y) > 0.5 then
					resultPos = result.Position + Vector3.new(0, normalOffset.Y, 0)
				else
					resultPos = result.Position + Vector3.new(normalOffset.X, 0, normalOffset.Z)
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
					self.brickPreview.Position = Vector3.new(
						math.round(resultPos.X / config.gridSize) * config.gridSize,
						math.round(resultPos.Y / config.gridSize) * config.gridSize,
						math.round(resultPos.Z / config.gridSize) * config.gridSize
					)
				end
			end)
		end)
	end,
	
	exitBuildMode = function(self: self)
		if self.renderCon then
			self.renderCon:Disconnect()
			self.renderCon = nil
		end
		
		if self.brickPreview then
			self.brickPreview:Destroy()
			self.brickPreview = nil
		end
	end,
	
	ready = function(self: self)
		
		--# make brick transparent for localplayer
		local function initTool(brickTool: Tool)
			if brickTool.Name ~= "Brick" then
				return
			end
			
			local brickPart: Part? = brickTool:WaitForChild("Handle")
			brickPart.Transparency = 0.7
			
			--# events
			
			brickTool.Equipped:Connect(function()
				self:enterBuildMode()
			end)
			
			brickTool.Unequipped:Connect(function()
				self:exitBuildMode()
			end)
			
			brickTool.AncestryChanged:Connect(function(_: Instance, parent: Instance)
				if parent ~= game.Players.LocalPlayer.Backpack and parent ~= game.Players.LocalPlayer.Character then
					console.warn("Brick tool was moved/removed. Exiting build mode...")
					self:exitBuildMode()
				end
			end)
		end
		
		--# dynamic init for more flexibility
		game.Players.LocalPlayer.Backpack.ChildAdded:Connect(initTool)
		local brickTool: Tool? = game.Players.LocalPlayer.Backpack:FindFirstChild("Brick")
		if brickTool then
			initTool(brickTool)
		end
	end,
} :: self