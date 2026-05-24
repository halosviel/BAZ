--[=[
	[INFO]
	author: @halosviel
	created: 2026 May 24
	
	[DESCRIPTION]
	
	[NOTES]
	- 
]=]

-- [REQUIRES]
local console = require("@game/ReplicatedFirst/pip/console")
local params = require("@game/ReplicatedFirst/pip/params")

-- [TYPES]
--# entity
type Properties = {
	spawnAt: number,
	
}
type Entity = {
	model: Model,
	staticComponents: { string },
	dynamicComponents: { string },
	properties: Properties
}

--# component
type Component = ( Entity ) -> nil
type ComponentNamesList = { string }

--# module
type self = {
	-- [CONFIG]
	TORSO_COLORS: { Color3 },
	HEADS: { number },
	
	-- [ENTRIES]
	staticComponents: { [string]: Component },
	dynamicComponents: { [string]: Component },
	entities: { [number]: Entity },
	globalId: number,
	
	-- [FUNCTIONS]
	constructor: ( self: self ) -> nil,
	addEntity: ( self: self, staticComponents: { Component }, dynamicComponents: { Component }, properties: Properties ) -> Entity,
	removeEntity: ( self: self, id: number ) -> nil,
	ready: ( self: self ) -> nil
}
export type ZombieService = self

-->

return {
	constructor = function(self: self)
		-- [CONFIG]
		self.TORSO_COLORS = {
			Color3.fromRGB(12, 70, 40), Color3.fromRGB(70, 70, 70), Color3.fromRGB(103, 103, 103),
			Color3.fromRGB(16, 16, 16), Color3.fromRGB(158, 158, 158), Color3.fromRGB(90, 14, 15),
			Color3.fromRGB(90, 14, 80), Color3.fromRGB(20, 16, 90), Color3.fromRGB(55, 77, 122),
			Color3.fromRGB(30, 122, 122), Color3.fromRGB(117, 122, 86), Color3.fromRGB(122, 100, 69),
			Color3.fromRGB(81, 69, 51),
		}
		self.HEADS = {
			48108254826353, 189682885115008, 274897006582337, 107770861134701, 40329797566983, 69132779144008, 
		}
		-->
		
		--# components that are ran once on entity creation
		self.staticComponents = {
			["RANDOM_TORSO_COLOR"] = function(entity: Entity)
				task.defer(function()
					local humanoidDescription: HumanoidDescription = entity.model:WaitForChild("HumanoidDescription")
					local humanoid: Humanoid = entity.model:WaitForChild("Humanoid")
					
					humanoidDescription.TorsoColor = self.TORSO_COLORS[math.random(1, #self.TORSO_COLORS)]
					humanoid:ApplyDescriptionAsync(humanoidDescription)
				end)
			end,
			["RANDOM_HEAD"] = function(entity: Entity)
				task.defer(function()
					local randomHeadId: string = self.HEADS[math.random(1, #self.HEADS)]
					
					local humanoidDescription: HumanoidDescription = entity.model:WaitForChild("HumanoidDescription")
					local humanoid: Humanoid = entity.model:WaitForChild("Humanoid")
					
					local itemDetails = game.AvatarEditorService:GetItemDetailsAsync(randomHeadId, Enum.AvatarItemType.Bundle)
					local bundledItems: { { AssetType: number } } = itemDetails.BundledItems --# sum type hackery >:(
					
					for _, obj in bundledItems do
						if obj.AssetType == "DynamicHead" then --# NOTE: AssetType might change
							humanoidDescription.Head = obj.Id
							break
						end
					end
					
					humanoid:ApplyDescriptionAsync(humanoidDescription)
				end)
			end,
			["SPAWN_AT"] = function(entity: Entity)
				params.expect("Vector3", entity.properties.spawnAt)
				
				entity.model.Parent = workspace.dynamic.zombies
				entity.model:PivotTo(CFrame.new(entity.properties.spawnAt))
			end,
		}
		self.dynamicComponents = {
			
		}
		
		self.entities = {}
		self.globalId = 0 --# incremented and used as the id for every new entity created
	end,
	
	--[[
		Creates a new entity with the components and properties given.
	]]
	addEntity = function(self: self, staticComponents: ComponentNamesList, dynamicComponents: ComponentNamesList, properties: Properties) : Entity
		params.expect("table", staticComponents)
		params.expect("table", dynamicComponents)
		params.expect("table", properties)
		
		local newEntity: Entity = {
			model = game.ReplicatedFirst.shared.assets.ZombieRig:Clone(),
			staticComponents = staticComponents,
			dynamicComponents = dynamicComponents,
			properties = properties
		}
		
		--# static components
		for _, componentName: string in staticComponents do
			local component: Component = self.staticComponents[componentName]
			if not component then
				console.deverr(`Static component {componentName} does not exist`)
			end
			
			component(newEntity)
		end
		
		self.globalId += 1
		self.entities[self.globalId] = newEntity
		
		return newEntity
	end,
	
	--[[
		Simply sets the index of the entity in self.entities to nil.
	]]
	removeEntity = function(self: self, id: number)
		params.expect("number", id)
		
		local index: Entity? = self.entities[id]
		if not index then
			console.warn(`Zombie remove request dropped: No zombie with id {id} found`)
			return
		end
		
		self.entities[id] = nil
	end,
	
	ready = function(self: self)
		--# dynamic components
		game.RunService.Heartbeat:Connect(function()
			for id: number, entity: Entity in self.entities do
				for _, componentName: string in entity.dynamicComponents do
					local component: Component = self.dynamicComponents[componentName]
					if not component then
						console.deverr(`Dynamic component {componentName} does not exist`)
					end
					
					component(entity)
				end
			end
		end)
		
		--# test entity!!
		self:addEntity({ "RANDOM_TORSO_COLOR", "RANDOM_HEAD", "SPAWN_AT" }, {}, { spawnAt = Vector3.new(2, 2.5, 0),  } :: Properties)
		self:addEntity({ "RANDOM_TORSO_COLOR", "RANDOM_HEAD", "SPAWN_AT" }, {}, { spawnAt = Vector3.new(2, 2.5, 0),  } :: Properties)
		self:addEntity({ "RANDOM_TORSO_COLOR", "RANDOM_HEAD", "SPAWN_AT" }, {}, { spawnAt = Vector3.new(2, 2.5, 0),  } :: Properties)
		self:addEntity({ "RANDOM_TORSO_COLOR", "RANDOM_HEAD", "SPAWN_AT" }, {}, { spawnAt = Vector3.new(2, 2.5, 0),  } :: Properties)
		self:addEntity({ "RANDOM_TORSO_COLOR", "RANDOM_HEAD", "SPAWN_AT" }, {}, { spawnAt = Vector3.new(2, 2.5, 0),  } :: Properties)
		self:addEntity({ "RANDOM_TORSO_COLOR", "RANDOM_HEAD", "SPAWN_AT" }, {}, { spawnAt = Vector3.new(2, 2.5, 0),  } :: Properties)
		self:addEntity({ "RANDOM_TORSO_COLOR", "RANDOM_HEAD", "SPAWN_AT" }, {}, { spawnAt = Vector3.new(2, 2.5, 0),  } :: Properties)
	end,
} :: self