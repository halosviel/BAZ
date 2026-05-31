--[=[
	[INFO]
	author: halosviel
	created: 2026 May 18
	
	[DESCRIPTION]
	The service for managing player data. It uses a promise-based approach so
	that proceeding events can reliably happen only after a given function
	executes (i.e, give rewards only if data writes successfully).
	
	[EXAMPLES]
	(1)
	dataService:getProfile(player):andThen(function(profile: dataService.Profile)
		print(profile)
	end):catch(warn)
	
	(2)
	dataService:read(player, "coins"):andThen(function(value: number)
		print(value)
	end):catch(warn)
	
	(3)
	dataService:write(player, "coins", function(currentValue: number)
		return currentValue + 1
	end):catch(warn)
	
	(4)
	dataService:listen(player, "coins"):andThen(function(signal: dataService.Signal)
		signal:Connect(function(newValue)
			print(newValue)
		end)
	end)
	
	[NOTES]
	- Error handlers should only be used in the calling scripts.
	- Never pass console functions directly into the error handler - Put it in a new
	  function so that the stack is accurate.
	- The promise-based architecture puts limits and constraints during practical use.
	- No validation is performed on profiles and signals. The system simply assumes
	  from my code.
	- Same-value writes are automatically ignored.
	- Data cannot be nil!
	- Read the notes from the API, they have their own notes...
]=]

-- [REQUIRES]
local console = require("@game/ReplicatedFirst/pip/console")
local params = require("@game/ReplicatedFirst/pip/params")
local processTimer = require("@game/ReplicatedFirst/pip/processTimer")

local dataTemplate = require("@game/ReplicatedFirst/shared/modules/dataTemplate")
local events = require("@game/ReplicatedFirst/shared/modules/events")

local profileStore = require("@game/ReplicatedFirst/shared/libs/profileStore")
local promise = require("@game/ReplicatedFirst/shared/libs/promise")
local signal = require("@game/ReplicatedFirst/shared/libs/cuteSignal")

-- [TYPES]
--# for external scripts so they don't have to require the libs to use types
export type Profile = profileStore.Profile<any> & { pipSignals: {} }
export type Signal = signal.Signal

type self = {
	-- [CONFIG]
	TEST_DATASTORE: string,
	LIVE_DATASTORE: string,
	PROFILE_FETCH_TIMEOUT: number,
	NIL_WRITES_ALLOWED: boolean,
	CROSS_TYPE_WRITES_ALLOWED: boolean,
	
	-- [ENTRIES]
	session: typeof(profileStore.New()),
	profiles: { [Player]: Profile },
	profileFetchSignals: { [Player]: Signal },
	
	-- [FUNCTIONS]
	constructor: ( self: self ) -> nil,
	_initialisePlayer: ( self: self, player: Player, data: dataTemplate.Data ) -> nil,
	fetchProfile: ( self: self, player: Player ) -> promise.Promise,
	read: ( self: self, player: Player, key: string ) -> promise.Promise,
	write: ( self: self, player: Player, callback: ( any ) -> any ) -> promise.Promise,
	listen: ( self: self, player: Player, key: string ) -> promise.Promise,
	ready: ( self: self ) -> nil
}
export type DataService = self

-->

return {
	constructor = function(self: self)
		self.TEST_DATASTORE = "Test_1"
		self.LIVE_DATASTORE = "Live_1"
		self.PROFILE_FETCH_TIMEOUT = 10
		self.NIL_WRITES_ALLOWED = false
		self.CROSS_TYPE_WRITES_ALLOWED = false
		
		local serverStore: string = game.RunService:IsStudio() and self.TEST_DATASTORE or self.LIVE_DATASTORE
		self.session = profileStore.New(serverStore, dataTemplate) --# the server proile store
		self.profiles = {} --# where player profiles are cached
		self.profileFetchSignals = {}
	end,
	
	_initialisePlayer = function(self: self, player: Player, data: dataTemplate.Data)
		--# ...
	end,
	
	--[[
		Returns a promise that resolves if the player's profile is 
		found. If no profile is found, it will create a new signal
		for the player in self.profileFetchSignals, which the PlayerAdded
		event will search for the player's signal and fire their
		profile as a parameter once it has loaded their profile.
		
		Also starts a process timer if the profile was not initially
		found.
		
		[NOTES]
		- Does not validate the profile. It will return what it finds
		  in self.profiles or what it is given.
		- Does not timeout whatsoever. Yields forever.
		- Expect profileFetchSignals to populate with a player for a
		  split second before disappearing.
	]]
	fetchProfile = function(self: self, player: Player) : promise.Promise
		params.expect("Player", player)
		
		return promise.new(function(resolve: ( ...any ) -> ( Profile ))
			if self.profiles[player] ~= nil then
				resolve(self.profiles[player])
			else
				local timer: processTimer.ProcessTimer?
				timer = processTimer.new(`PROFILE_FETCH_{tostring(player)}`, function()
					timer = nil
				end)
				
				local _signal: Signal = self.profileFetchSignals[player]
				if _signal == nil then
					_signal = signal.new()
					self.profileFetchSignals[player] = _signal
				end
				
				_signal:Once(function(profile: Profile)
					if timer then
						timer:exit()
					end
					
					resolve(profile)
				end)
			end
		end)
	end,
	
	--[[
		Returns a promise which resolves with the value of the given
		key.
	]]
	read = function(self: self, player: Player, key: string) : promise.Promise
		params.expect("Player", player)
		params.expect("string", key)
		
		if dataTemplate[key] == nil then
			console.deverr(`"{key}" is not a valid key`)
			return
		end
		
		return self:fetchProfile(player):andThen(function(profile: Profile) : any
			local value: any = profile.Data[key]
			if value == nil then
				console.warn(`Read request dropped for @{tostring(player)}: Key "{key}" has no value`)
				return
			end
			
			return value
		end)
	end,
	
	--[[
		Updates the value of a key in a profile.
		
		[NOTES]
		- Writing to a nil value is permitted, as long as the key
		  is valid.
	]]
	write = function(self: self, player: Player, key: string, callback: ( value: any ) -> any) : promise.Promise
		params.expect("Player", player)
		params.expect("string", key)
		params.expect("function", callback)
		
		if dataTemplate[key] == nil then
			console.deverr(`"{key}" is not a valid key`)
			return
		end
		
		return self:fetchProfile(player):andThen(function(profile: Profile) : any
			local oldValue: any = profile.Data[key]
			local newValue: any = callback(oldValue)
			
			if oldValue == newValue then
				console.warn(`Write request dropped for @{tostring(player)}: Same value ({key}, {newValue})`)
			end
			
			if newValue == nil and self.NIL_WRITES_ALLOWED == false then
				--# warn since promise attaches traceback - we don't want that here
				console.warn(`ERROR :: Write request dropped for @{tostring(player)}: Illegal nil write to {key}`)
				return
			end
			
			if typeof(oldValue) ~= typeof(newValue) and self.CROSS_TYPE_WRITES_ALLOWED == false then
				console.warn(
					`ERROR :: Write request dropped for @{tostring(player)}: Illegal cross-type write to {key}`
						..` ({typeof(oldValue)} expected, got {typeof(newValue)})`
				)
				return
			end
			
			--# update value
			profile.Data[key] = newValue
			
			--# update listeners
			if profile.pipSignals and profile.pipSignals[key] then
				profile.pipSignals[key]:Fire(newValue)
			end
			
			--# update client
			events.updatePlayerData:FireClient(player, key, newValue)
		end)
	end,
	
	--[[
		Returns a signal which is fired when the data from
		the profile updates.
		
		Uses lazy loading to load in signals as they're used.
		
		[NOTES]
		- Automatically fires the current value of the key
		  immediately after being called.
		- Writing immediately after setting up a listener may
		  cause the write to be missed by the listener due to
		  race conditions. Mitigate this by repeating whatever
		  was in the listener outside of it. This limitation
		  does not apply to the client.
	]]
	listen = function(self: self, player: Player, key: string) : promise.Promise
		params.expect("Player", player)
		params.expect("string", key)
		
		if dataTemplate[key] == nil then
			console.deverr(`"{key}" is not a valid key`)
			return
		end
		
		return self:fetchProfile(player):andThen(function(profile: Profile) : any
			local signals: { [string]: Signal } = profile.pipSignals
			if not signals then
				profile.pipSignals = {}
				signals = profile.pipSignals
			end
			
			local _signal: Signal = signals[key]
			if not _signal then
				_signal = signal.new()
				profile.pipSignals[key] = _signal
			end
			
			return _signal
		end)
	end,
	
	ready = function(self: self)
		
		--[[
			Contains the PlayerAdded & PlayerRemoving events for ProfileStore
			handling. Also adds and removes players to/from the playerWhoFetchedData
			variable which the next section uses to only allow singular fetch
			requests per player session.
		]]
		local playersWhoFetchedData: { [Player]: number } = {}
		
		local function onPlayerAdded(player: Player)
			task.spawn(function()
				playersWhoFetchedData[player] = 0
				
				local profile = self.session:StartSessionAsync(`Player_{player.UserId}`, {
					Cancel = function()
						return player.Parent ~= game.Players
					end,
				})
				
				if profile == nil then
					console.warn(`@{tostring(player)} was kicked (Profile not found on join)`)
					player:Kick("An unexpected error has occurred, we apologise for any inconvenience.\n\nPlease rejoin.\n")
					return
				end
				
				profile:AddUserId(player.UserId)
				profile:Reconcile()
				
				profile.OnSessionEnd:Connect(function()
					self.profiles[player] = nil
					player:Kick(self.NO_PROFILE_KICK_MESSAGE)
				end)
				
				if player.Parent == game.Players then
					self.profiles[player] = profile
					self:_initialisePlayer(player, profile.Data)
					
					if self.profileFetchSignals[player] then
						self.profileFetchSignals[player]:Fire(profile)
						self.profileFetchSignals[player]:Destroy()
						self.profileFetchSignals[player] = nil
					end
				else
					profile:EndSession()
				end
			end)
		end
		
		game.Players.PlayerAdded:Connect(onPlayerAdded)
		for _, player: Player in game.Players:GetPlayers() do
			onPlayerAdded(player)
		end
		
		game.Players.PlayerRemoving:Connect(function(player: Player)
			
			--# Remove from caches.
			
			playersWhoFetchedData[player] = nil
			
			if self.profileFetchSignals[player] then
				self.profileFetchSignals[player]:Destroy()
				self.profileFetchSignals[player] = nil
			end
			
			--# Profile cleanup
			
			local profile: Profile = self.profiles[player]
			if not profile then
				console.warn(`@{tostring(player)} was kicked (Profile not found on leave)`)
				return
			end
			
			profile:EndSession()
			self.profiles[player] = nil
		end)
		
		--[[
			Returns the player's data when they requset it on join. Also
			limits each player to one request per session, which is
			validated here but controlled by the section above.
		]]
		events.fetchPlayerData.OnServerEvent:Connect(function(player: Player)
			local fetchCount: number = playersWhoFetchedData[player]
			playersWhoFetchedData[player] += 1
			
			if fetchCount and fetchCount > 1  then
				console.warn(`Received duplicate data fetch request from @{tostring(player)} (x{fetchCount})`)
				return
			end
			
			self:fetchProfile(player):andThen(function(profile: Profile)
				events.fetchPlayerData:FireClient(player, profile.Data)
				playersWhoFetchedData[player] += 1
			end)
		end)
	end,
} :: self