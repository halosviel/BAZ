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
	buildRadius = 15, -- how far from the HRP a player can build from
	buildPreviewRadius = 45, -- how far a build preview will travel (do not let it go into void)
	buildPreviewTransparency = 0.5,
	buildInvalidColor = Color3.fromRGB(255, 61, 64),
}