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

local tweenUtils = require("@game/ReplicatedFirst/shared/utils/tweenUtils")

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
		
		--# make brick transparent for localplayer
		--# naming conventions: brickTool, brickPart
		local brickTool: Tool? = game.Players.LocalPlayer.Backpack:WaitForChild("Brick")
		local brickPart: Part? = brickTool:WaitForChild("Handle")
		brickPart.Transparency = 0.7
	end,
} :: self