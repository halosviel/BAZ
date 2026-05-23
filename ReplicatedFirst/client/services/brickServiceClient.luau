--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 23
	
	[DESCRIPTION]
	
	[NOTES]
	- 
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
		dataServiceClient:read("brickSkin"):andThen(function(brickSkin: string)
			
			--# create brick preview
			
			local brickPart: Part? = game.ReplicatedFirst.shared.bricks:FindFirstChild(brickSkin)
			if not brickPart then
				brickPart = game.ReplicatedFirst.shared.bricks:FindFirstChild("Default")
			end
			
			self.brickPreview = brickPart:Clone()
			self.brickPreview.Transparency = config.buildPreviewTransparency
			self.brickPreview.Parent = workspace.dynamic
			
			--# generate preview
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

				local result = workspace:Raycast(
					camera.CFrame.Position,
					(self.mouse.Hit.Position - camera.CFrame.Position).Unit * config.buildPreviewRadius,
					params
				)
				
				if not result then
					if self.brickPreview then
						self.brickPreview.Position = Vector3.new(0, 0, 0)
					end
					return
				end
				
				if not result.Instance then
					if self.brickPreview then
						self.brickPreview.Position = Vector3.new(0, 0, 0)
					end
					return
				end
				
				local resultPos: Vector3 = result.Position
				
				--# color
				--# ( based on distance )
				if self.brickPreview then
					if (root.Position - resultPos).Magnitude >= config.buildRadius then
						self.brickPreview.Color = config.buildInvalidColor
					else
						self.brickPreview.Color = brickPart.Color
					end
				end

				--# place preview
				
				if self.brickPreview then
					self.brickPreview.Position = resultPos
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
		--# naming conventions: brickTool, brickPart
		local brickTool: Tool? = game.Players.LocalPlayer.Backpack:WaitForChild("Brick")
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
			if parent == nil then
				self:exitBuildMode()
			end
		end)
	end,
} :: self