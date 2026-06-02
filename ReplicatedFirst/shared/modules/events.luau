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
	fetchPlayerData = packet("fetchPlayerData", packet.Any),
	updatePlayerData = packet("updatePlayerData", packet.String, packet.Any),
	
	--# build system
	initBrickTool = packet("initBrickTool", packet.Instance),
	placeBrick = packet("placeBrick", packet.CFrameF24U8):Response(packet.Boolean8, packet.Any),
	throwBrick = packet("throwBrick", packet.Vector3F24, packet.Vector3F24):Response(packet.Boolean8, packet.Any)
}