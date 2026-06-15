--[=[
	[INFO]
	author: @halosviel
	created: 2026 June 15
	
	[DESCRIPTION]
	A shared module to circumvent circular module dependencies.
]=]

-- [REQUIRES]
local console = require("@game/ReplicatedFirst/pip/console")
local params = require("@game/ReplicatedFirst/pip/params")

local soundUtils = require("@game/ReplicatedFirst/shared/utils/soundUtils")

-->

local decalFaces: { Enum.NormalId } = {
	Enum.NormalId.Front,
	Enum.NormalId.Back,
	Enum.NormalId.Left,
	Enum.NormalId.Right,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom
}

return {
	--[[
		Handles bricks taking damage from other bricks or
		from zombies.
		
		Handles lifecycle, sounds, & textures.
	]]
	damageBrick = function(brick: BasePart, damage: number, bitten: boolean?)
		--# we are dealing with dynamic objects, dont use params
		if typeof(brick) ~= "Instance" then
			console.warn("Request to damage brick failed: Given brick was not a BasePart", `Got {typeof(brick)}`)
			return
		end
		if not brick:IsA("BasePart") then
			console.warn("Request to damage brick failed: Given brick was not a BasePart", `Got {brick.ClassName}`)
			return
		end
		
		params.expect("number", damage)
		
		if bitten ~= nil then
			params.expect("boolean", bitten)
		end
		
		--# get heatlh
		local health: number = brick:GetAttribute("Health") or 100
		local newHealth: number = math.floor(health - damage)
		
		if newHealth <= 0 then
			--# destroy
			local brickPosition: VectorForce = brick.Position
			brick:Destroy()

			local soundPart = Instance.new("Part")
			soundPart.Size = Vector3.new(1, 1, 1)
			soundPart.Transparency = 1
			soundPart.CanCollide = false
			soundPart.CanQuery = false
			soundPart.CanTouch = false
			soundPart.Position = brickPosition
			soundPart.Anchored = true
			soundPart.Parent = workspace.dynamic

			soundUtils.wrap("BrickBroken")
				:clone()
				:setParent(soundPart)
				:autoDestroy()
				:setRandomPitch(0.1)
				:play()
				:onDestroy(function()
					--# destroy part
					soundPart:Destroy()
				end)

			game.Debris:AddItem(soundPart, 3) --# fallback
		else
			--# damage/breaking sound
			soundUtils.wrap(bitten and "BrickBreaking" or "BrickDamaged")
				:clone()
				:setParent(brick)
				:autoDestroy()
				:setRandomPitch(0.1)
				:play()
		end
		
		--# update health
		brick:SetAttribute("Health", newHealth)
		
		--# textures
		local texture: Content | false = newHealth <= 33 and Content.fromUri(game.ReplicatedFirst.assets.decals.BrickLowHealth.ColorMapContent.Uri)
			or newHealth <= 66 and Content.fromUri(game.ReplicatedFirst.assets.decals.BrickMediumHealth.ColorMapContent.Uri)
		if not texture or texture == false then
			return
		end
		
		if brick:FindFirstChildOfClass("Decal") then
			--# just update
			for _, decal: Decal in brick:GetChildren() do
				if not decal:IsA("Decal") then
					continue
				end
				decal.ColorMapContent = texture
			end
		else
			--# create new textures
			for _, face: Enum.NormalId in decalFaces do
				local newDecal: Decal = Instance.new("Decal")
				newDecal.ColorMapContent = texture
				newDecal.Face = face
				newDecal.Parent = brick
			end
		end
	end,
}