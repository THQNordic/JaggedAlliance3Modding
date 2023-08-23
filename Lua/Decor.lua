DefineClass("Tree", "EntityClass")

DefineClass.BaseFlag = {
	__parents = { "Object" },
}

function BaseFlag:Init()
	-- commented variants do not produce good results (half of the placed objects have animations phase very close to each other)
	--local phase = BraidRandom(EncodeVoxelPos(self) % max_int, duration)
	--local phase = BraidRandom(point_pack(self:GetPosXYZ()) % max_int, duration)

	local duration = GetAnimDuration(self:GetEntity(), self:GetAnim())
	local phase = AsyncRand(duration)
	self:SetAnimPhase(1, phase)
end

function OnMsg.ClassesGenerate()
	table.iappend(Light.properties, {
		{category = "Visuals", id = "NightOnly", name = "Night Only", editor = "bool", default = false},
	})
end

function GetStoredNightOnlyIntensity0(self)
	return self._nightonly_intensity0
end

function SetStoredNightOnlyIntensity0(self, intensity)
	self._nightonly_intensity0 = intensity
end

function GetStoredNightOnlyIntensity1(self)
	return self._nightonly_intensity1
end

function SetStoredNightOnlyIntensity1(self, intensity)
	self._nightonly_intensity1 = intensity
end

function ApplyNightOnly(night)
	MapForEach("map", "Light", function(light)
		if light.NightOnly then
			if night then
				if rawget(light, "_nightonly_intensity0") then
					light.SetIntensity0, light.GetIntensity0 = nil, nil
					light.SetIntensity1, light.GetIntensity1 = nil, nil
					light:SetIntensity0(light._nightonly_intensity0)
					light:SetIntensity1(light._nightonly_intensity1)
					light._nightonly_intensity0 = false
					light._nightonly_intensity1 = false
				end
			else
				if not rawget(light, "_nightonly_intensity0") then
					light._nightonly_intensity0 = light:GetIntensity0()
					light._nightonly_intensity1 = light:GetIntensity1()
					light:SetIntensity0(0)
					light:SetIntensity1(0)
					light.GetIntensity0, light.SetIntensity0 = GetStoredNightOnlyIntensity0, SetStoredNightOnlyIntensity0
					light.GetIntensity1, light.SetIntensity1 = GetStoredNightOnlyIntensity1, SetStoredNightOnlyIntensity1
				end
			end
		end
	end)
end

function OnMsg.GameEnterEditor()
	ApplyNightOnly(true)
end

function OnMsg.GameExitEditor()
	ApplyNightOnly(GameState.Night)
end

function OnMsg.GameStateChanged(changed)
	if changed.Night then
		ApplyNightOnly(true)
	elseif changed.Day or changed.Sunrise or changed.Sunset then
		ApplyNightOnly(false)
	end
end

function OnMsg.NewMapLoaded()
	if GameState.Night then
		ApplyNightOnly(true)
	elseif GameState.Day or GameState.Sunrise or GameState.Sunset then
		ApplyNightOnly(false)
	end
end

--[[
	To create objects which play sound depending on which state they are placed on the map:
	- manually create a class for them inheriting DecorStateFXObject, or set DecorStateFXObject as parent class for them in the ArtSpec
	- in the FX editor, create a new ActionFXSound for each of the states you want to associate with sounds, with the following properties
		- Action: DecorState
		- Moment: start
		- Actor: choose the class of the object
		- Target: type the name of the state
		- Sound: choose the sound bank from the list
		- AttachToObj: check
	- if you want the sound to stop when the object switches to another state:	
		- in EndRules: click "Add", then in EndMoment add "end"
]]

local function GetParticlesType(pattern)
	local items = {}
	for name in pairs(ParticleSystemPresets) do
		if string.match(name, pattern) then
			table.insert(items, name)
		end
	end
	table.insert(items, "")
	table.sort(items)
	return items
end

DefineClass.DecorGameStatesFilter = {
	__parents = {"Object", "EditorTextObject"},

	properties = {
		{ category = "DecorStateFXObject", id = "ActivationRequiredStates", name = "Map States", 
			editor = "set", three_state = true, default = false,
			items = function() return GetGameStateFilter() end,
			buttons = {{name = "Check Game States", func = "PropertyDefGameStatefSetCheck"}},
			help = "Click once for the states required to be enabled(green), twice for the states required to be disabled(red). All other states are don't care.",
		},
	},
	
	editor_text_offset = point(0, 0, 150 * guic),

	old_map_states = false,	-- objects's map states we are interested in during the last GameState
	activated = false,
}

function DecorGameStatesFilter:GameInit()
	self.old_map_states = {}
	for state in pairs(self.ActivationRequiredStates) do
		self.old_map_states[state] = not not GameState[state]
	end
	self:UpdateGameState()
end

function DecorGameStatesFilter:UpdateGameState()
	if not self.old_map_states then return end

	local is_destroyed = IsGenericObjDestroyed(self)
	local should_be_active = not is_destroyed
	if should_be_active then
		for state, required_value in pairs(self.ActivationRequiredStates) do
			local game_state_value = not not GameState[state]
			should_be_active = should_be_active and (required_value == game_state_value)
			if game_state_value ~= self.old_map_states[state] then
				self.old_map_states[state] = game_state_value
				PlayFX(state, game_state_value and "start" or "end", self, self:GetStateText())
			end
		end
	end
	self.activated = should_be_active
	self:OnGameStateUpdated()
	self:EditorTextUpdate()
end

local efVisible = const.efVisible
local efVisibleNot = bnot(efVisible)

function DecorGameStatesFilter:SetEnumFlags(flags)
	if band(flags, efVisible) ~= 0 then
		if not IsEditorActive() and self:GetEntity() == "ParticleSoundPlaceholder" then
			flags = band(flags , efVisibleNot)
		end
	end
	Object.SetEnumFlags(self, flags)
end

function DecorGameStatesFilter:OnGameStateUpdated()
	if self:GetNumStates() == 0 then
		if self.activated and IsEditorActive() then
			self:SetEnumFlags(efVisible)
		else
			self:ClearEnumFlags(efVisible)
		end
	end
end

function DecorGameStatesFilter:EditorEnter()
	EditorTextObject.EditorEnter(self)
	if self:GetNumStates() == 0 then
		self:SetEnumFlags(efVisible)	
	end
end

function DecorGameStatesFilter:EditorExit()
	EditorTextObject.EditorExit(self)
	self:UpdateGameState()
end

function DecorGameStatesFilter:EditorGetText()
	local text = ""
	
	if not MatchGameState(self.ActivationRequiredStates) then
		local mismatch_states = {"Mismatch States:"}
		for state, active in pairs(self.ActivationRequiredStates) do
			local game_state_active = not not GameState[state]
			if active ~= game_state_active then
				table.insert(mismatch_states, state) 
			end
		end
		text = string.format("%s\n%s", text, table.concat(mismatch_states, " "))
	end
	
	return text
end

function DecorGameStatesFilter:EditorGetTextColor()
	return MatchGameState(self.ActivationRequiredStates) and EditorTextObject.EditorGetTextColor(self) or const.clrRed
end

DefineClass.DecorStateFXObject = {
	__parents = { "Object", "FXObject", "DecorGameStatesFilter" },
	
	properties = {
		{ id = "Pos",  name = "Pos",    editor = "point",  default = InvalidPos(),     help = "in meters", scale = "m" },
		{ id = "Angle", editor = "number", default = 0, min = 0, max = 360*60 - 1, slider = true, scale = "deg"},
		{ category = "DecorStateFXObject", id = "Preset", editor = "dropdownlist", default = "",
			items = function(self) return GetParticlesType(self.particles_pattern) end,
		},
	},
	
	place_category = false,
	place_name = false,
	
	particles_pattern = "",
	entity_scale = 100,
	
	particles = false,
}

function DecorStateFXObject:Init()
	self:SetScale(self.entity_scale)
end

function DecorStateFXObject:GameInit()
	CreateGameTimeThread(function()
		Sleep(1) -- workaround for sound FX being disabled during map load, pending investigation
		if IsValid(self) then
			self:SetState(self:GetState())
			self:ForEachAttach("Light", Stealth_HandleLight)
			ResetVoxelStealthParamsCache()
		end
	end)
	self:PlaceParticles()
end

function DecorStateFXObject:Done()
	self:DestroyParticles()
end

function DecorStateFXObject:SetPos(pos, ...)
	Object.SetPos(self, pos, ...)
	if self.particles then
		self.particles:SetPos(pos, ...)
	end
end

function DecorStateFXObject:SetAngle(angle, ...)
	Object.SetAngle(self, angle, ...)
	if self.particles then
		self.particles:SetAngle(angle, ...)
	end
end

function DecorStateFXObject:DestroyParticles()
	if not self.particles then return end
	
	DoneObject(self.particles)
	self.particles = false
end

function DecorStateFXObject:PlaceParticles()
	if not ParticleSystemPresets[self.Preset] then return end
	
	self.particles = PlaceParticles(self.Preset)
	self.particles.HelperEntity = false
	self.particles:SetPos(self:GetPos())	
	self.particles:SetAngle(self:GetAngle())
end

function DecorStateFXObject:OnEditorSetProperty(prop_id)
	if prop_id == "Preset" then
		self:DestroyParticles()
		self:PlaceParticles()
	end
end

function DecorStateFXObject:SetState(...)
	PlayFX("DecorState", "end", self, self:GetStateText())
	Object.SetState(self, ...)
	if self:GetEnumFlags(efVisible) ~= 0 then
		if not self:IsKindOf("AutoAttachObject") or self:GetAutoAttachMode() ~= "OFF" then
			-- NOTE: some lights are playng their sounds on their single "idle" anim despite beiing turner OFF
			PlayFX("DecorState", "start", self, self:GetStateText())
		end
	end
end

function DecorStateFXObject:OnGameStateUpdated()
	DecorGameStatesFilter.OnGameStateUpdated(self)
	if self.particles then	
		if self.activated then
			self.particles:SetEnumFlags(efVisible)
		else
			self.particles:ClearEnumFlags(efVisible)
		end
	end
end

function DecorStateFXObject:EditorEnter()
	DecorGameStatesFilter.EditorEnter(self)
	if self.particles then
		self.particles:SetEnumFlags(efVisible)
	end
end

function DecorStateFXObject:OnXFilterSetVisible(visible)
	if self.particles then
		if visible then
			self.particles:SetEnumFlags(efVisible)
		else
			self.particles:ClearEnumFlags(efVisible)
		end
	end
end

function OnMsg.GatherPlaceCategories(list)
	ClassDescendants("DecorStateFXObject", function(class_name, class)
		if class.place_category or class.place_name then
			local place_name = class.place_name or class_name
			local category = class.place_category or "Effects"
			table.insert(list, {class_name, place_name, "Common", category})
		end
	end)
end

DefineClass.DecorStateFXObjectNoSound = {
	__parents = {"DecorStateFXObject", "EditorVisibleObject", "EditorTextObject", "StripCObjectProperties"},
	entity = "ParticleSoundPlaceholder",
	entity_scale = 10,
	color_modifier = RGB(100, 100, 0),
}

function DecorStateFXObjectNoSound:Init()
	self:SetColorModifier(self.color_modifier)
end

DefineClass.DecorStateFXObjectWithSound = {
	__parents = {"DecorStateFXObject", "SoundSource"},
	
	properties = {
		-- Required for map saving purposes only.
		{ id = "CollectionIndex", name = "Collection Index", editor = "number", default = 0, read_only = true },
		{ id = "CollectionName", name = "Collection Name", editor = "choice",
			items = GetCollectionNames, default = "", dont_save = true,
			buttons = {{ name = "Collection Editor", func = function(self)
				if self:GetRootCollection() then
					OpenCollectionEditorAndSelectCollection(self)
				end
			end }},
		},
	},
	
	entity = "ParticleSoundPlaceholder",
	entity_scale = 10,
	sounds_pattern = "",
	editor_text_offset = point(0, 0, 150 * guic),
}

function DecorStateFXObjectWithSound:EditorGetText()
	return string.format("%s\n%s", DecorGameStatesFilter.EditorGetText(self), SoundSource.EditorGetText(self))
end


function DecorStateFXObjectWithSound:EditorGetTextColor()
	return MatchGameState(self.ActivationRequiredStates) and DecorStateFXObject.EditorGetTextColor(self) or const.clrRed
end

function DecorStateFXObjectWithSound:Init()
	local sounds = self:GetProperty("Sounds")
	if sounds then return end
	
	local sounds = {}
	for _, entry in ipairs(Presets.SoundPreset.ENVIRONMENT) do
		if string.match(entry.id, self.sounds_pattern) then
			table.insert(sounds, entry.id)
		end
	end
	self:AddSoundsEntry(sounds[1 + self:Random(#sounds)], nil, self.ActivationRequiredStates)
end

function DecorStateFXObjectWithSound:GetAvailableSounds(ignore_editor)
	if not self.activated then
		return
	end
	return SoundSourceBase.GetAvailableSounds(self, ignore_editor)
end

function OnMsg.GameStateChanged(changed)
	if CurrentMap == "" or ChangingMap then return end
	
	MapForEach("map", "DecorGameStatesFilter", function(decor)
		decor:UpdateGameState()
	end)
end

function OnMsg.GatherFXActions(list)
	list[#list+1] = "DecorState"
end

DefineClass.DecorStateFXAutoAttachObject = {
	__parents = {"DecorStateFXObject", "AutoAttachObject"},
}

function DecorStateFXAutoAttachObject:SetState(...)
	-- NOTE: DecorStateFXObject expects GetStateText() to have the old anim so it needs to be called first
	DecorStateFXObject.SetState(self, ...)
	AutoAttachObject.SetState(self, ...)
end


DefineClass.ShadowOnlyObject = {
	__parents = {"EditorObject", "Object"},
}

function ShadowOnlyObject:Init()
	self:Hide()
end

function ShadowOnlyObject:Hide()
	self:SetGameFlags(const.gofSolidShadow)
	self:SetOpacity(0)
end

function ShadowOnlyObject:Show()
	self:ClearGameFlags(const.gofSolidShadow)
	self:SetOpacity(100)
end

function ShadowOnlyObject:EditorEnter()
	self:Show()
end

function ShadowOnlyObject:EditorExit()
	self:Hide()
end

-- use CreateShadowOnlyVersion as parent in ArtSpec to create ShadowOnly version using the same entity
DefineClass.CreateShadowOnlyVersion = {}

function OnMsg.ClassesGenerate(classdefs)
	for class_name, classdef in pairs(classdefs) do
		local idx = table.find(classdef.__parents, "CreateShadowOnlyVersion")
		if idx then
			local parents = table.copy(classdef.__parents)
			parents[idx] = "ShadowOnlyObject"
			local new_class_def = DefineClass(class_name .. "_ShadowOnly", table.unpack(parents))
			new_class_def.entity = classdef.entity or class_name
		end
	end
end

-------------- specific objects --------------

DefineClass.Laptop = {
	__parents = { "DecorStateFXObject" },
	entity = "Corp_Laptop_01",
}

DefineClass.WW2_Flag = {
	__parents = { "DecorStateFXObject" },
	fx_actor_class = "WW2_Flag",
}

DefineClass("WW2_FlagHill_France", "WW2_Flag")
DefineClass("WW2_FlagHill_Legion", "WW2_Flag")

DefineClass.Shanty_WindTower = {
	__parents = {"GroundAlignedObj", "Canvas", "DecorStateFXObject"},
	fx_actor_class = "Shanty_WindTower",
}

local function SetMaterialTypeToClassDef(cls)
	local def = g_Classes[cls]
	if def then
		def.material_type = table.get(EntityData, cls, "entity", "material_type")
	end
end

function OnMsg.EntitiesLoaded()
	local lst = ClassDescendantsList("WW2_Flag")
	for _, cls in ipairs(lst or empty_table) do
		SetMaterialTypeToClassDef(cls)
	end
end

DefineClass("SatelliteViewWater", "WaterObj")

DefineClass.WalkableEntity = {
	__parents = { "CObject" },
	flags = {efPathSlab = true},
}

DefineClass.Vehicle = {
	__parents = { "CombatObject", "AutoAttachObject" },
}

DefineClass.HorizonObject = {
	__parents = { "CObject" },
	max_allowed_radius = 200 * guim,
	flags = { gofAlwaysRenderable = true, efSelectable = false, cofComponentCollider = false },
}