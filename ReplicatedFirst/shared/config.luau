--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 23
	
	[DESCRIPTION]
	A module that stores configs both the server and client use.
]=]

return {
	--# build system
	gridSize = 1, -- snap
	buildToolName = "Brick",
	buildRadius = 15, -- how far from the HRP a player can build from
	buildCooldown = 0.5,
	buildPreviewRadius = 45, -- how far a build preview will travel (lowk dk if keep or not, might be redundant)
	buildPreviewTransparency = 0.5,
	buildInvalidColor = Color3.fromRGB(255, 61, 64)
}