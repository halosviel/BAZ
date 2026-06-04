--[=[
	@halosviel | 2026 May 16
]=]

-- [REQUIRES]
local console = require("@game/ReplicatedFirst/pip/console")
local params = require("@game/ReplicatedFirst/pip/params")

-- [TYPES]
type TouchJump = {
	isSmallScreen: boolean,
	isSmallScreenChanged: typeof(require("@game/ReplicatedFirst/shared/libs/cuteSignal").new())
}
type self = {
	SMALL_BUTTON_SIZE: number,
	LARGE_BUTTON_SIZE: number,
	
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
				Updates the mobile control styling depending on device size,
				which is imported from the forked TouchJump module.
				
				NOTE: Currently only supports one style and one size. So all
				mobile controls are expected to be the same size across dev-
				ices.
			]]
			local function _updateMobileControls(button: ImageButton)
				params.expect("ImageButton", button)
				
				local isSmallScreen = touchJump.isSmallScreen
				button.Size = isSmallScreen and self.SMALL_BUTTON_SIZE or self.LARGE_BUTTON_SIZE
				
				warn(isSmallScreen)
			end
			
			local function createMobileControls()
				local placeButton = Instance.new("ImageButton")
				placeButton.BackgroundTransparency = 1
				
				--# initial update + dynamic update since it takes time for the
				--  variable to be actually set.
				_updateMobileControls(placeButton)
				touchJump.isSmallScreenChanged:Connect(_updateMobileControls)
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