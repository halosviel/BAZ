--[=[
	[INFO]
	author: @halosviel
	created: 2026 June 15
	
	[DESCRIPTION]
	Initiates ragdoll deaths for players.
]=]

-- [REQUIRES]
local ragdollService = require("@game/ReplicatedFirst/shared/libs/ragdollService")
local applyKnockback = require("@game/ReplicatedFirst/shared/utils/applyKnockback")

-->

local function onCharacterAdded(character: Model)
	ragdollService.SetupRagdoll(character)
	
	local humanoid: Humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		ragdollService.Ragdoll(character)
		
		local rootPart: Part? = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			applyKnockback(rootPart, -rootPart.CFrame.LookVector, 10, 0)
		end
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