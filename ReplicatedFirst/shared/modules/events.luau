--[=[
	[INFO]
	author: halosviel
	created: 2026 May 16
	
	[DESCRIPTION]
	Contains all of the game's packets.
]=]

local packet = require("../libs/packet")

return {
	--# data
	fetchPlayerData = packet("fetchPlayerData", packet.Any), --# dataService, dataServiceClient
	updatePlayerData = packet("updatePlayerData", packet.String, packet.Any), --# dataService, dataServiceClient
	
	--# build system
	initBrickTool = packet("initBrickTool", packet.Instance), --# brickService, brickServiceClient
	placeBrick = packet("placeBrick", packet.CFrameF24U8):Response(packet.Boolean8, packet.Any) --# brickService, brickServiceClient
}