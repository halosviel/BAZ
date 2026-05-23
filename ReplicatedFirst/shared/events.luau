--[=[
	[INFO]
	author: halosviel
	created: 2026 May 16
	
	[DESCRIPTION]
	Contains all of the game's packets.
]=]

local packet = require("./libs/packet")

return {
	fetchPlayerData = packet("fetchPlayerData", packet.Any), --# dataService, dataServiceClient
	updatePlayerData = packet("updatePlayerData", packet.String, packet.Any), --# dataService, dataServiceClient
}