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

local dataService = require("./dataService")

local config = require("@game/ReplicatedFirst/shared/config")
local events = require("@game/ReplicatedFirst/shared/events")

-- [TYPES]
type self = {
	-- [CONFIG]
	BUILD_RADIUS_FORGIVEABLE: number,
	
	-- [ENTRIES]
	
	-- [FUNCTIONS]
	constructor: ( self: self ) -> nil,
	placeBrick: ( self: self, player: Player, brickCFrame: CFrame ) -> nil,
	ready: ( self: self ) -> nil
}
export type BrickService = self

-->

return {
	constructor = function(self: self)
		-- [CONFIG]
		self.BUILD_RADIUS_FORGIVEABLE = 4 -- how far outside config.buildRadius the player can build
		-->
	end,
	
	placeBrick = function(self: self, player: Player, brickCFrame: CFrame)
		dataService:read(player, "brickSkin"):andThen(function(brickSkinName: string)
			local brickSkin: Part? = game.ReplicatedFirst.shared.bricks:FindFirstChild(brickSkinName)
			if not brickSkin then
				brickSkin = game.ReplicatedFirst.shared.bricks:FindFirstChild("Default")
			end
			
			local brick = brickSkin:Clone()
			brick:SetAttribute("Owner", player.UserId)
			brick:SetAttribute("Health", 100) --# might scale with more bricks in future, hmm
			
			--# snap the inconsistencies
			
			local position = brickCFrame.Position
			local rotationX: number, rotationY: number, rotationZ: number = brickCFrame:ToEulerAnglesXYZ()
			
			local snappedPos = Vector3.new(
				math.round(position.X / config.gridSize) * config.gridSize,
				math.round(position.Y / config.gridSize) * config.gridSize,
				math.round(position.Z / config.gridSize) * config.gridSize
			)
			
			local snappedRx = math.round(math.deg(rotationX) / 90) * 90
			local snappedRy = math.round(math.deg(rotationY) / 90) * 90
			local snappedRz = math.round(math.deg(rotationZ) / 90) * 90
			
			brick:PivotTo(
				CFrame.new(snappedPos) * CFrame.Angles(
					math.rad(snappedRx),
					math.rad(snappedRy),
					math.rad(snappedRz)
				)
			)
			
			-->
			
			brick.Parent = workspace.dynamic.bricks
		end)
	end,
	
	ready = function(self: self)
		
		--# handle place requests
		events.placeBrick.OnServerInvoke = function(player: Player, brickCFrame: CFrame) : ( boolean, string? )
			--# 100% tampering, no possible dev errs on client
			if typeof(brickCFrame) ~= "CFrame" then
				console.warn(`Given brickCFrame was not a CFrame ({typeof(brickCFrame)})`, "Remote tampering")
				player:Kick("Remote tampering")
				return false, "Illegal placement"
			end
			
			--# checks
			local character: Model? = player.Character
			if not character then
				return false, "No Character found"
			end
			
			local rootPart: Part? = character:FindFirstChild("HumanoidRootPart")
			if not rootPart then
				return false, "No HumanoidRootPart found"
			end
			
			local humanoid: Humanoid? = character:FindFirstChild("Humanoid")
			if not humanoid then
				return false, "No Humanoid found"
			end
			
			if humanoid.Health == 0 then
				return false, "Dead"
			end
			
			if (rootPart.Position - brickCFrame.Position).Magnitude > config.buildRadius + self.BUILD_RADIUS_FORGIVEABLE then
				return false, "Out of range"
			end
			
			self:placeBrick(player, brickCFrame)
			return true
		end
		
		--# validate default brick
		if game.ReplicatedFirst.shared.bricks:FindFirstChild("Default") == nil then
			console.error("Bricks folder missing default brick")
		end
		
		--# give player brick on join
		local function onCharacterAdded(character: Model)
			local player = game.Players:GetPlayerFromCharacter(character)
			
			dataService:read(player, "brickSkin"):andThen(function(brickSkinName: string)
				local brickPart: Part? = game.ReplicatedFirst.shared.bricks:FindFirstChild(brickSkinName)
				if not brickPart then
					console.warn(`Brick "{brickSkinName}" not found. Unable to give to @{tostring(player)}`)
					return
				end
				
				local brickTool = Instance.new("Tool")
				brickTool.Name = config.buildToolName
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