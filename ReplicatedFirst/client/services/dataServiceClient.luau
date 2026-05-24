--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 19
	
	[DESCRIPTION]
	The client-side of the data system.
	
	When the client joins, a packet is sent to the server to fetch
	the player's data. The client then stores the copy as self.data
	and resolves all yielding fetch requests.
	
	[NOTES]
	- When the server changes a player's data on join, updatePlayerData
	  might not fire, but the initial fetch request has most probably
	  captured the changed data - No action required.
]=]

-- [REQUIRES]
local console = require("@game/ReplicatedFirst/pip/console")
local params = require("@game/ReplicatedFirst/pip/params")
local processTimer = require("@game/ReplicatedFirst/pip/processTimer")

local events = require("@game/ReplicatedFirst/shared/events")
local dataTemplate = require("@game/ReplicatedFirst/shared/dataTemplate")

local promise = require("@game/ReplicatedFirst/shared/libs/promise")
local signal = require("@game/ReplicatedFirst/shared/libs/cuteSignal")
local maid = require("@game/ReplicatedFirst/shared/libs/maid")

-- [TYPES]
export type Signal = signal.Signal

type self = {
	-- [CONFIG]
	LONG_REQUEST: number,
	
	-- [ENTRIES]
	data: dataTemplate.Data?,
	dataFetchedSignal: Signal,
	
	signals: { [string]: Signal },
	
	-- [FUNCTIONS]
	constructor: ( self: self ) -> nil,
	fetchData: ( self: self ) -> promise.Promise,
	read: ( self: self, key: string ) -> promise.Promise,
	listen: ( self: self, key: string ) -> promise.Promise,
	ready: ( self: self ) -> nil
}
export type DataServiceClient = self

-->

return {
	constructor = function(self: self)
		-- [CONFIG]
		self.LONG_REQUEST = 10
		-->
		
		self.data = nil
		self.dataFetchedSignal = signal.new()
		
		self.signals = {}
	end,
	
	--[[
		Return the player's data. If self.data is immediately found, it
		will return it. Otherwise it will connect to dataFetchedSignal and
		wait until it is fired.
	]]
	fetchData = function(self: self) : promise.Promise
		return promise.new(function(resolve: ( ...any ) -> ( dataTemplate.Data ))
			if self.data then
				resolve(self.data)
			else
				self.dataFetchedSignal:Wait()
				resolve(self.data)
			end
		end)
	end,
	
	--[[
		Waits for the data and returns the value of the given key.
		
		[NOTES]
		- Returns the absolute value of the data as dictated by the
		  server (it can return nil).
	]]
	read = function(self: self, key: string) : promise.Promise
		params.expect("string", key)
		if dataTemplate[key] == nil then
			console.deverr(`"{key}" is not a valid key`)
			return
		end

		return self:fetchData():andThen(function(data: dataTemplate.Data) : any
			return data[key]
		end)
	end,
	
	--[[
		Returns a promise that resolve with a signal, which the
		caller can connect to to listen for value updates.
	]]
	listen = function(self: self, key: string) : promise.Promise
		params.expect("string", key)
		if dataTemplate[key] == nil then
			console.deverr(`"{key}" is not a valid key`)
			return
		end
		
		return self:fetchData():andThen(function(data: dataTemplate.Data) : any
			local _signal: Signal = self.signals[key]
			if not _signal then
				_signal = signal.new()
				self.signals[key] = _signal
			end

			return _signal
		end)
	end,
	
	ready = function(self: self)
		--[[
			Fires the fetchPlayerData event to the server, which the server
			fires back the event, passing the data. The data is then stored
			as self.data, and all yielding processes are resolved.
		]]
		local startTimestamp = os.clock()
		local requestReceived = false --# only once per session
		local _maid = maid.new()
		
		local timer: processTimer.ProcessTimer?
		timer = processTimer.new("INITIAL_DATA_FETCH", function()
			timer = nil
		end)
		
		local con: RBXScriptConnection?
		con = events.fetchPlayerData.OnClientEvent:Connect(function(data: dataTemplate.Data)
			if requestReceived then
				return
			end
			requestReceived = true
			
			if con then
				con:Disconnect()
				con = nil
			end
			
			if timer then
				timer:exit()
			end
			
			self.data = data
			self.dataFetchedSignal:Fire()
			self.dataFetchedSignal:Destroy()
			self.dataFetchedSignal = nil
		end)
		
		events.fetchPlayerData:Fire()
		
		--[[
			Handles data sync between the client and the server.
			
			When the server data updates, it fires to the client, which is
			handled here. When the event is received, data is first fetched
			to confirm it exists, then overwrites it from self.
		]]
		events.updatePlayerData.OnClientEvent:Connect(function(key: string, newValue: any)
			self:fetchData():andThen(function(data: dataTemplate.Data)
				self.data[key] = newValue
				
				local signal: Signal? = self.signals[key]
				if signal then
					signal:Fire(newValue)
				end
			end)
		end)
	end,
} :: self