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
		local function onCharacterAdded(character: Model)
			local player = game.Players:GetPlayerFromCharacter(character)
			
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
		end
		
		local function onPlayerAdded(player: Player)
			player.CharacterAdded:Connect(onCharacterAdded)
			if player.Character then
				onCharacterAdded(player.Character)
			end
		end
		
		game.Players.PlayerAdded:Connect(onPlayerAdded)
		for _, player: Player in game.Players:GetPlayers() do
			onPlayerAdded(player)
		end
	end,
} :: self