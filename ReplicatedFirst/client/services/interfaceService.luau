--[=[
	@halosviel | 2026 May 16
]=]

-- [REQUIRES]
local console = require("@game/ReplicatedFirst/pip/console")
local params = require("@game/ReplicatedFirst/pip/params")

-- [TYPES]
type Offset = {
	x: number,
	y: number
}

type TouchJump = {
	isSmallScreen: boolean,
	isSmallScreenChanged: typeof(require("@game/ReplicatedFirst/shared/libs/cuteSignal").new())
}

type self = {
	SMALL_BUTTON_SIZE: number,
	LARGE_BUTTON_SIZE: number,
	PLACE_BUTTON_OFFSET: Offset,
	
	constructor: ( self: self ) -> nil,
	ready: ( self: self ) -> nil
}
export type InterfaceService = self

-->

return {
	constructor = function(self: self)
		-- sizes are 70% of jump button
		self.SMALL_BUTTON_SIZE = 42
		self.LARGE_BUTTON_SIZE = 90
		self.PLACE_BUTTON_OFFSET = { x = 10, y = 10 }
	end,
	
	ready = function(self: self)
		local startTimestamp = os.clock()
		
		local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
		local main: typeof(game.StarterGui.main) = playerGui:WaitForChild("main")
		
		--# Mobile Controls
		do
			local isMobileControlsEnabled  = false
			local touchJump: TouchJump = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule").ControlModule.TouchJump)
			
			--[[
				Updates the button's size and position depending on
				device size, which is imported from the forked
				TouchJump module.
				
				NOTE: The function can fire multiple times, but is
				negligible for now.
			]]
			local function _updateMobileControls(button: ImageButton, offset: Offset, isSmallScreen: boolean?)
				params.expect("ImageButton", button)
				params.expect("table", offset)
				params.expect("number", offset.x)
				params.expect("number", offset.y)
				
				if isSmallScreen == nil then
					isSmallScreen = touchJump.isSmallScreen
				end
				local sizeXY: number = isSmallScreen and self.SMALL_BUTTON_SIZE or self.LARGE_BUTTON_SIZE
				
				--# TODO: CORRECT POSITIONING
				button.Size = UDim2.fromOffset(sizeXY, sizeXY)
				button.Position = UDim2.fromScale(1 - sizeXY - offset.x, -1 + sizeXY + offset.y)
				
				warn(isSmallScreen)
			end
			
			local function createMobileControls()
				local placeButton = Instance.new("ImageButton")
				placeButton.Name = "PlaceBrick"
				placeButton.BackgroundTransparency = 1
				placeButton.AnchorPoint = Vector2.new(0, 0)
				placeButton.Parent = main.dynamic
				
				--# initial update + dynamic update since it takes time for the
				--  variable to be actually set.
				_updateMobileControls(placeButton, self.PLACE_BUTTON_OFFSET)
				touchJump.isSmallScreenChanged:Connect(function(newValue: number)
					_updateMobileControls(placeButton, self.PLACE_BUTTON_OFFSET, newValue)
				end)
			end
			
			local function showMobileControls()
				if isMobileControlsEnabled then
					return
				end
				isMobileControlsEnabled = true
				
				
			end
			
			local function hideMobileControls()
				if not isMobileControlsEnabled then
					return
				end
				isMobileControlsEnabled = false
				
				
			end
			
			createMobileControls()
			
			game.UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(showMobileControls)
			if game.UserInputService.PreferredInput == Enum.PreferredInput.Touch then
				showMobileControls()
			else
				hideMobileControls()
			end
		end
	end,
} :: self