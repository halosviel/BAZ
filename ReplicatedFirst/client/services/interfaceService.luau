--[=[
	@halosviel | 2026 May 16
]=]

-- [REQUIRES]
local console = require("@game/ReplicatedFirst/pip/console")
local params = require("@game/ReplicatedFirst/pip/params")

local signal = require("@game/ReplicatedFirst/shared/libs/cuteSignal")
local maid = require("@game/ReplicatedFirst/shared/libs/maid")
local config = require("@game/ReplicatedFirst/shared/modules/config")

local events = require("@game/ReplicatedFirst/shared/modules/events")
local types = require("@game/ReplicatedFirst/shared/modules/types")

-- [TYPES]
type Offset = {
	x: number,
	y: number
}
type ButtonConfig = {
	offset: {
		small: Offset,
		large: Offset
	},
	size: {
		small: number,
		large: number
	}
}

type TouchJump = {
	isSmallScreen: boolean,
	isSmallScreenChanged: typeof(require("@game/ReplicatedFirst/shared/libs/cuteSignal").new())
}

type self = {
	PLACE_BUTTON_CONFIG: ButtonConfig,
	ROTATE_BUTTON_CONFIG: ButtonConfig,
	THROW_BUTTON_CONFIG: ButtonConfig,
	DAYS_TEXT: string,
	DAYS_TO_RESET_TEXT: string,
	
	buttons: { ImageButton },
	mobileControlsEnabledChanged: signal.Signal,
	
	constructor: ( self: self ) -> nil,
	setMobileControlsEnabled: ( self: self, enabled: boolean ) -> nil,
	mobileControlsEnabled: boolean,
	ready: ( self: self ) -> nil
}
export type InterfaceService = self

-->

return {
	constructor = function(self: self)
		-- sizes are 70% of jump button
		self.PLACE_BUTTON_CONFIG = {
			offset = {
				small = { x = 80, y = 120 },
				large = { x = 150, y = 250 }
			},
			size = {
				small = 50,
				large = 80
			}
		}
		self.ROTATE_BUTTON_CONFIG = {
			offset = {
				small = { x = 10, y = 120 },
				large = { x = 40, y = 250 }
			},
			size = {
				small = 50,
				large = 80
			}
		}
		self.THROW_BUTTON_CONFIG = {
			offset = {
				small = { x = 130, y = 30 },
				large = { x = 220, y = 100 }
			},
			size = {
				small = 50,
				large = 80
			}
		}
		self.DAYS_TEXT = ("DAY %i")
		self.DAYS_TO_RESET_TEXT = ("clearing builds in %i days")
		
		self.buttons = {}
		self.mobileControlsEnabledChanged = signal.new()
		self.mobileControlsEnabled = false
	end,
	
	--[[
		Used by brickServiceClient to enable/disable as the
		tool is equipped/unequipped.
	]]
	setMobileControlsEnabled = function(self: self, enabled: boolean)
		params.expect("boolean", enabled)
		--warn("mobile controls", enabled)
		for _, button: ImageButton in self.buttons do
			button.Visible = enabled
		end
		self.mobileControlsEnabled = enabled
		self.mobileControlsEnabledChanged:Fire(enabled)
	end,
 	
	ready = function(self: self)
		local startTimestamp = os.clock()
		
		local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
		local main: typeof(game.StarterGui.main) = playerGui:WaitForChild("main")
		
		--# Mobile Controls
		do
			local touchJump: TouchJump = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule").ControlModule.TouchJump)
			
			--[[
				Updates the button's size and position depending on
				device size, which is imported from the forked
				TouchJump module.
				
				NOTE: The function can fire multiple times, but is
				negligible for now.
			]]
			local function _updateMobileControls(isSmallScreen: boolean?)
				if isSmallScreen == nil then
					isSmallScreen = touchJump.isSmallScreen
				end
				--warn(isSmallScreen)
				
				for _, button: ImageButton in self.buttons do
					local actionName: string = button.Name:match("^[A-Z][a-z]*") --# "Place", "Rotate", "Throw"
					local buttonConfig: ButtonConfig = self[`{actionName:upper()}_BUTTON_CONFIG`]
					if not buttonConfig then
						console.deverr(`Button config for action "{actionName}" does not exist`)
					end
					
					local sizeXY: number = isSmallScreen and buttonConfig.size.small or buttonConfig.size.large
					local offset: Offset = isSmallScreen and buttonConfig.offset.small or buttonConfig.offset.large
					
					button.Size = UDim2.fromOffset(sizeXY, sizeXY)
					button.Position = UDim2.new(1, -sizeXY - offset.x, 1, -sizeXY - offset.y)
				end
			end
			
			local function createMobileControls()
				for _, button: ImageButton in main.dynamic.mobileControlButtons:GetChildren() do
					table.insert(self.buttons, button)
				end
				
				--# initial update + dynamic update since it takes time for the
				--  variable to be actually set.
				_updateMobileControls()
				touchJump.isSmallScreenChanged:Connect(function(newValue: number)
					_updateMobileControls(newValue)
				end)
			end
			
			local function setMobileControlsVisible()
				--# do NOT use self:setMobileControlsEnabled() -> will fire signal on loop and crash
				if game.UserInputService.PreferredInput == Enum.PreferredInput.Touch then
					for _, button: ImageButton in self.buttons do
						button.Visible = true
					end
				else
					for _, button: ImageButton in self.buttons do
						button.Visible = false
					end
				end
			end
			
			local maid: maid.Maid = maid.new()
			self.mobileControlsEnabledChanged:Connect(function(newValue: boolean)
				if newValue == true then
					maid:GiveTask(game.UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(setMobileControlsVisible))
					setMobileControlsVisible()
				else
					maid:DoCleaning()
				end
			end)
			
			createMobileControls()
			self:setMobileControlsEnabled(false)
		end
		
		--# Desktop Controls Label
		do
			local function isGuiStillValid() : boolean
				if not main then
					return false
				end
				if not main:FindFirstChild("dynamic") then
					return false
				end
				if not main.dynamic:FindFirstChild("DesktopControlLabels") then
					return false
				end
				return true
			end
			
			self.mobileControlsEnabledChanged:Connect(function(newValue: boolean)
				if not isGuiStillValid() then
					return
				end
				
				if newValue == true then
					if game.UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse then
						main.dynamic.DesktopControlLabels.Visible = true
					end
				else
					main.dynamic.DesktopControlLabels.Visible = false
				end
			end)
			
			game.UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function(value)
				if not isGuiStillValid() then
					return
				end
				
				if value == Enum.PreferredInput.KeyboardAndMouse then
					if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild(config.BUILD_TOOL_NAME) then
						main.dynamic.DesktopControlLabels.Visible = true
					end
				else
					main.dynamic.DesktopControlLabels.Visible = false
				end
			end)

			main.dynamic.DesktopControlLabels.Visible = false
		end
		
		--# Days UI
		do
			local function updateDaysLabel(day: number)
				main.static.Days.Text = self.DAYS_TEXT:format(day)
			end
			
			local function updateDaysToResetLabel(daysToReset: number)
				main.static.DaysToReset.Text = self.DAYS_TO_RESET_TEXT:format(daysToReset)
			end
			
			local function _updateLabels(dayData: types.DayData)
				if not dayData or typeof(dayData) ~= "table" then
					console.warn("Invalid response for dayData received from the server", `Received value: {tostring(dayData)}`, "Expected table")
					return
				end
				--print("update", dayData.day, dayData.daysToReset)
				updateDaysLabel(dayData.day)
				updateDaysToResetLabel(dayData.daysToReset)
			end
			
			-->
			
			events.dayDataUpdated.OnClientEvent:Connect(_updateLabels)
			task.defer(function()
				local dayData: types.DayData = events.getDayData:Fire()
				_updateLabels(dayData)
			end)
		end
	end,
} :: self