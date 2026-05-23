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

local dataService = require("./dataService")

-- [TYPES]
type self = {
	constructor: ( self: self ) -> nil,
	ready: ( self: self ) -> nil
}
export type Service = self

-->

return {
	constructor = function(self: self)
		-- [CONFIG]
		
		-- [ENTRIES]
		
		-- [FUNCTIONS]
	end,
	
	ready = function(self: self)
		
		--# validate default brick
		if game.ReplicatedFirst.shared.bricks:FindFirstChild("Default") == nil then
			console.error("Bricks folder missing default brick")
		end
		
		--# give player brick on join
		--# naming conventions: brickTool, brickPart
		game.Players.PlayerAdded:Connect(function(player: Player)
			dataService:read(player, "brickSkin"):andThen(function(brickSkin: string)
				local brickPart: Part? = game.ReplicatedFirst.shared.bricks:FindFirstChild(brickSkin)
				if not brickPart then
					console.warn(`Brick "{brickSkin}" not found. Unable to give to @{tostring(player)}`)
					return
				end
				
				local brickTool = Instance.new("Tool")
				brickTool.Name = "Brick" --# WARNING: The client yields for this string. Update client too when changing!
				brickTool.CanBeDropped = false
				
				brickPart = brickPart:Clone()
				brickPart.Name = "Handle"
				brickPart.Anchored = false
				brickPart.Parent = brickTool
				
				brickTool.Parent = player.Backpack
			end)
		end)
	end,
} :: self