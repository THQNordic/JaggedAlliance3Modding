-- Wind is defined as a wind grid. Each slot has wind direction and strength.
-- There are two types of wind sources:
--    * Base wind(coming from the light model)
--    * WindMarker/WindlessMarker objects spread across the map
--
-- Light model has some wind properties like base wind strength and direction which are applied for each wind grid slot.
-- This means even maps without WindMarker can have some base wind. Other wind properties from LM can affect
-- some other objects using random wind gusts, e.g. grass. Canvasses are not affected by these though. WindMarker can add
-- some wind to grid slots on a position/range basis and WindlessMarker can suppress it on the same basis. 
--
-- NOTE:	When WindMarker areas overlap the directions inside are combined and weighted corresponding to their origins.
--			Global wind direction is not taken into account but the final direction is multiplied by the global wind strength.
--			Global wind direction plays only when outside WindMarker range.

DefineClass.WindDef = {
	__parents = { "Preset" },
	properties = {
		{ category = "Wind", name = "Base wind strength", id = "baseWindStrength", editor = "number", default = 100, scale = "%", min = 0, max = 100, slider = true, help = "Base wind strength (markers can change the actual wind)"},
		{ category = "Wind", name = "Base wind angle", id = "baseWindAngle", editor = "number", default = 0, scale = "deg", min = 0, max = 360*60, slider = true, help = "Base wind angle (markers can change the actual wind)"},
		{ category = "Wind", name = "Wind gusts strength Min", id = "windGustsStrengthMin", editor = "number", scale = "%", default = 10, min = 0, max = 1000, slider = true, help = "Additional min wind from gusts"},
		{ category = "Wind", name = "Wind gusts strength Max", id = "windGustsStrengthMax", editor = "number", scale = "%", default = 20, min = 0, max = 1000, slider = true, help = "Additional max wind from gusts"},
		{ category = "Wind", name = "Wind gusts change Period", id = "windGustsChangePeriod", editor = "number", scale = "sec", default = 3000, help = "Time between gusts changes"},
		{ category = "Wind", name = "Wind gusts probability", id = "windGustsProbability", editor = "number", default = 0, scale = "%", min = 0, max = 100, slider = true, help = "Percent of time there are wind gusts"},

		{ category = "Tree Wind", name = "Tree wind scale", id = "windScale", editor = "number", default = 50, min = 10, max = 200, scale = 100, slider = true, help = "Wind strength multiplier"},
		{ category = "Tree Wind", name = "Tree wind time scale", id = "windTimeScale", editor = "number", default = 100, min = 10, max = 1000, scale = 100, slider = true, help = "Global wind timescale"},
		{ category = "Tree Wind", name = "Tree wind branch time scale", id = "windRadialTimeScale", editor = "number", default = 1000, min = 0, max = 10000, scale = 1000, slider = true},
		{ category = "Tree Wind", name = "Tree wind branch perturb scale", id = "windRadialPerturbScale", editor = "number", default = 100, min = 10, max = 1000, scale = 100, slider = true},
		{ category = "Tree Wind", name = "Tree wind branch phase shift", id = "windRadialPhaseShift", editor = "number", default = 500, min = 10, max = 1000, scale = 100, slider = true},
		{ category = "Tree Wind", name = "Tree wind perturb base", id = "windPerturbBase", editor = "number", default = 300, min = 0, max = 1000, scale = 1000, slider = true},
		{ category = "Tree Wind", name = "Tree wind perturb variation", id = "windPerturbScale", editor = "number", default = 100, min = 0, max = 1000, scale = 1000, slider = true},
		{ category = "Tree Wind", name = "Tree wind perturb frequency", id = "windPerturbFrequency", editor = "number", default = 100, min = 0, max = 1000, scale = 1000, slider = true},
		{ category = "Tree Wind", name = "Tree wind phase shift base", id = "windPhaseShiftBase", editor = "number", default = 150, min = 0, max = 300, scale = 100, slider = true},
		{ category = "Tree Wind", name = "Tree wind phase shift variation", id = "windPhaseShiftScale", editor = "number", default = 10, min = 0, max = 100, scale = 100, slider = true},
		{ category = "Tree Wind", name = "Tree wind phase shift frequency", id = "windPhaseShiftFrequency", editor = "number", default = 0, min = 0, max = 1000, scale = 100, slider = true},
		
		{ category = "Grass Wind", name = "Grass wind scale", id = "windGrassScale", editor = "number", default = 2000, min = 0, max = 10000, scale = 1000, slider = true},
		{ category = "Grass Wind", name = "Grass wind side scale", id = "windGrassSideScale", editor = "number", default = 50, min = 0, max = 1000, scale = 1000, slider = true},
		{ category = "Grass Wind", name = "Grass wind side phase", id = "windGrassSidePhase", editor = "number", default = 500, min = 0, max = 10000, scale = 1000, slider = true},
		{ category = "Grass Wind", name = "Grass wind side frequency", id = "windGrassSideFrequency", editor = "number", default = 3000, min = 0, max = 20000, scale = 1000, slider = true},
		{ category = "Grass Wind", name = "Grass wind noise scale", id = "windGrassNoiseScale", editor = "number", default = 500, min = 0, max = 1000, scale = 1000, slider = true},
		{ category = "Grass Wind", name = "Grass wind noise granularity", id = "windGrassNoiseGranularity", editor = "number", default = 400, min = 0, max = 3000, scale = 1000, slider = true},
		{ category = "Grass Wind", name = "Grass wind noise frequency", id = "windGrassNoiseFrequency", editor = "number", default = 550, min = 0, max = 5000, scale = 1000, slider = true},
		
		{ category = "Sound", name = "Wind sound", id = "sound", editor = "preset_id", default = false, preset_class = "SoundPreset" },
		{ category = "Sound", name = "Wind volume", id = "soundVolume", editor = "number", default = 1000, min = 0, max = 1000, slider = true},
		{ category = "Sound", name = "Wind gust sound", id = "soundGust", editor = "preset_id", default = false, preset_class = "SoundPreset" },
		{ category = "Sound", name = "Wind gust volume", id = "soundGustVolume", editor = "number", default = 1000, min = 0, max = 1000, slider = true},
	},
	StoreAsTable = true,
	GlobalMap = "WindDefs",
	EditorMenubarName = "Wind",
	EditorMenubar = "Editors.Art",
	EditorIcon = "CommonAssets/UI/Icons/weather windy.png",
}

if FirstLoad then
	WindOverride = false
end

function WindDef:OnEditorSelect(selection, ged)
	WindOverride = selection and self or false
end

function GetWindColorCode(strength, max_strength)
	local green = 255 - strength * 255 / max_strength
	local red = strength * 255 / max_strength
	local blue = 0
	local third = max_strength / 3
	if strength > third and strength < 2 * third then
		blue = (strength - third) * 255 * third
	end
	
	return RGB(red, green, blue)
end

DefineClass.WindAffected = {
	__parents = {"CObject"},
}

local StrongWindThreshold = const.WindMaxStrength

function OnMsg.Autorun()
	StrongWindThreshold = (const.StrongWindThreshold or 100) * const.WindMaxStrength / 100
end

function WindAffected:GetWindSamplePos()
	return self:GetPos()
end

function WindAffected:GetWindStrength()
	return terrain.GetWindStrength(self:GetWindSamplePos())
end

function WindAffected:IsStrongWind()
	return self:GetWindStrength() >= StrongWindThreshold
end

function WindAffected:UpdateWind()
end

function GetStrongWindThreshold()
	return StrongWindThreshold
end


----

DefineClass.FXBehaviorWeakWind = {
	__parents = { "FXSourceBehavior" },
	id = "WeakWind",
	CreateLabel = true,
	LabelUpdateMsg = "WindMarkersApplied",
}

function FXBehaviorWeakWind:IsFXEnabled(source, preset)
	local wind = terrain.GetWindStrength(source)
	return wind > 0 and wind < StrongWindThreshold
end

DefineClass.FXBehaviorStrongWind = {
	__parents = { "FXSourceBehavior" },
	id = "StrongWind",
	CreateLabel = true,
	LabelUpdateMsg = "WindMarkersApplied",
}

function FXBehaviorStrongWind:IsFXEnabled(source, preset)
	local wind = terrain.GetWindStrength(source)
	return wind >= StrongWindThreshold
end

----

GameVar("gv_WindNoUpdate", false)
MapVar("ForcedWindAngle", false)

function StopWindInRooms()
	if const.SlabSizeX then
		EnumVolumes(function(room)
			for i = 1, GetVolumeSubdivCount(room) do
				if room:HasAllWalls() and room:HasRoof("scan rooms above") then
					local subdiv_box = GetVolumeSubdiv(room, i - 1)
					terrain.SetWindBoxStrength(subdiv_box, point30)
				end
			end
		end)
		terrain.CompactWindGrid()
		Msg("WindRoomReset")
	end
end

function UpdateWindAffected()
	MapForEach("map", "WindAffected", function(obj)
		obj:UpdateWind()
	end)
end

function ApplyWindMarkers(ignore)
	if GetMap() == "" or gv_WindNoUpdate then return end
	
	local wind = CurrentWindAnimProps()
	local wind_dir = Rotate(point(0, wind.baseWindStrength * const.WindMaxStrength / 100), ForcedWindAngle or wind.baseWindAngle)
	terrain.SetWindStrength(wind_dir, wind.baseWindStrength, GetWindMarkers(ignore))
	Msg("WindMarkersApplied")
	StopWindInRooms()
	UpdateWindAffected()
	hr.WindTimeScale = wind.windTimeScale / 100.0
end

DefineClass.BaseWindMarker = {
	__parents = { "EditorMarker", "StripComponentAttachProperties", "EditorCallbackObject" },
	entity = "WindMarker",
	
	properties = {
		category = "Wind",
		{ id = "MaxRange", name = "Max Wind Range", editor = "number", default = 10 * guim, min = 0, max = const.WindMarkerMaxRange, slider = true, helper = "sradius", color = const.clrRed},
		{ id = "AttenuationRange", name = "Attenuation Range", editor = "number", default = 10 * guim, min = 0, max = const.WindMarkerAttenuationRange, slider = true, helper = "sradius", color = const.clrGreen},
	},
	
	dir = false,
	dir_max = false,
}

function BaseWindMarker:Init()
	if self:GetPos() ~= InvalidPos() then
		self:ShowDirection()
	end
end

function BaseWindMarker:Done()
	self:HideDirection()
end

function BaseWindMarker:GetAzimuth(range)
	return Rotate(point(range or self.AttenuationRange, 0), self:GetAngle())
end

function BaseWindMarker:HideDirection()
	DoneObject(self.dir)
	DoneObject(self.dir_max)
	self.dir = false
	self.dir_max = false
end

function BaseWindMarker:GetMarkerColor()
	return const.clrWhite
end

function BaseWindMarker:ShowDirection(ignore_editor_check)
	self:HideDirection()
	if not ignore_editor_check and not IsEditorActive() then return end
	
	local pos = self:GetPos()
	local z = pos:IsValidZ() and pos:z() or terrain.GetHeight(pos)
	pos = pos:SetZ(z + 2 * guim)
	local color = self:GetMarkerColor()
	self.dir = ShowVector(self:GetAzimuth(), pos, color)
	self.dir_max = ShowVector(self:GetAzimuth(self.MaxRange), pos, color)
	
	return pos
end

function BaseWindMarker:EditorEnter()
	self:ShowDirection("ignore editor check")
end

function BaseWindMarker:EditorExit()
	self:HideDirection()
end

function BaseWindMarker:SetPos(...)
	EditorMarker.SetPos(self, ...)
	if not ChangingMap then
		self:ShowDirection()
		DelayedCall(0, ApplyWindMarkers)
	end
end

function BaseWindMarker:SetAngle(...)
	EditorMarker.SetAngle(self, ...)
	if not ChangingMap then
		self:ShowDirection()
		DelayedCall(0, ApplyWindMarkers)
	end
end

function BaseWindMarker:UpdateWindProperty(prop_id)
	local other_helper, other_value
	if prop_id == "MaxRange" then
		other_value = Max(self.MaxRange, self.AttenuationRange)
		EditorMarker.SetProperty(self, "AttenuationRange", other_value)
		other_helper = (PropertyHelpers[self] or empty_table)["AttenuationRange"]
	elseif prop_id == "AttenuationRange" then
		other_value = Min(self.MaxRange, self.AttenuationRange)
		EditorMarker.SetProperty(self, "MaxRange", other_value)
		other_helper = (PropertyHelpers[self] or empty_table)["MaxRange"]
	end
	if other_helper then
		other_helper:Update(self, other_value)
	end
	self:ShowDirection()
	if not ChangingMap then
		DelayedCall(0, ApplyWindMarkers)
	end
end

function BaseWindMarker:SetProperty(prop_id, value)
	EditorMarker.SetProperty(self, prop_id, value)
	self:UpdateWindProperty(prop_id)
end

function BaseWindMarker:OnEditorSetProperty(prop_id)
	self:UpdateWindProperty()
end

function BaseWindMarker:EditorCallbackDelete()
	DelayedCall(0, ApplyWindMarkers)
end

BaseWindMarker.EditorCallbackPlace = BaseWindMarker.EditorCallbackDelete
BaseWindMarker.EditorCallbackClone = BaseWindMarker.EditorCallbackDelete

DefineClass.WindMarker = {
	__parents = { "BaseWindMarker" },
	
	properties = {
		{ category = "Wind", id = "Strength", name = "Strength", editor = "number", default = 50, min = 0, max = 100, slider = true},
	},
	
	strength_text = false,
}

function WindMarker:HideDirection()
	BaseWindMarker.HideDirection(self)
	DoneObject(self.strength_text)
	self.strength_text = false
end

function WindMarker:GetMarkerColor()
	return GetWindColorCode(self.Strength, 100)
end

function WindMarker:ShowDirection(ignore_editor_check)
	local pos = BaseWindMarker.ShowDirection(self, ignore_editor_check)
	if not pos then return end
	
	local text = string.format("%d", self.Strength)
	self.strength_text = PlaceText(text, pos + self:GetAzimuth() / 2)
	self.strength_text:SetColor(self:GetMarkerColor())
end

function WindMarker:UpdateWindProperty(prop_id, ...)
	if prop_id ~= "Strength" and prop_id ~= "MaxRange" and prop_id ~= "AttenuationRange" then return end
	BaseWindMarker.UpdateWindProperty(self, prop_id, ...)
end

DefineClass.WindlessMarker = {
	__parents = { "BaseWindMarker" },
	
	Strength = 0,
}

function GetWindMarkers(ignore)
	local positions, directions, max_ranges, strengths = {}, {}, {}, {}
	local WindMaxStrength = const.WindMaxStrength
	MapForEach("map", "BaseWindMarker", function(wind)
		if wind == ignore then return end
		
		local dir = wind:GetAzimuth()
		table.insert(positions, wind:GetPos())
		table.insert(directions, dir)
		table.insert(max_ranges, wind.MaxRange)
		table.insert(strengths, wind.Strength * WindMaxStrength / 100)
	end)
	
	return positions, directions, max_ranges, strengths
end

function OnMsg.EntitiesLoaded()
	local wind_axis, wind_radial, wind_modifier_strength, wind_modifier_mask = GetEntityWindParams("WayPoint") -- hopefully default
	for name,entity_data in pairs(EntityData) do
		if entity_data.entity and 
			(entity_data.entity.wind_axis or 
			 entity_data.entity.wind_radial or 
			 entity_data.entity.wind_modifier_strength or 
			 entity_data.entity.wind_modifier_mask) then
			 
			SetEntityWindParams(
				name, 
				-1, 
				entity_data.entity.wind_axis or wind_axis, 
				entity_data.entity.wind_radial or wind_radial,
				entity_data.entity.wind_modifier_strength or wind_modifier_strength,
				entity_data.entity.wind_modifier_mask or wind_modifier_mask)
		end
	end
end

function OnMsg.AfterLightmodelChange(_, lightmodel, _, prev_lightmodel, from_override)
	if ChangingMap then return end
	if from_override then return end --this is true when overriding and when removing override
	
	if not prev_lightmodel or lightmodel.wind ~= prev_lightmodel.wind then
		ApplyWindMarkers()
	end
end

function CurrentWindAnimProps()
	if type(WindOverride) == "table" then return WindOverride end
	local lm = CurrentLightmodel and CurrentLightmodel[1]
	return WindDefs[lm and lm.wind or false] or WindDef
end

if FirstLoad then
	WindSound = false
	WindSoundChannel = false
	WindSoundGust = false
	WindSoundGustChannel = false
end

local function UpdateWindSound(prev_sound, channel, sound, volume, time)
	if prev_sound ~= sound then
		if channel then
			SetSoundVolume(channel, -1, time)
		end
		channel = false
		if sound then
			channel = PlaySound(sound, volume, time)
		end
	elseif channel then
		SetSoundVolume(channel, volume, time)
	end
	return sound or false, channel or false
end

local function UpdateGrassWind(wind, scale)
	local freqScale = (scale - 1) * 0.2 + 1
	hr.WindGrassScale = wind.windGrassScale / 1000.0 * scale
	hr.WindGrassSideScale= wind.windGrassSideScale / 1000.0
	hr.WindGrassSidePhase = wind.windGrassSidePhase / 1000.0
	hr.WindGrassSideFrequency = wind.windGrassSideFrequency / 1000.0 * freqScale
	hr.WindGrassNoiseScale = wind.windGrassNoiseScale / 1000.0
	hr.WindGrassNoiseGranularity = wind.windGrassNoiseGranularity / 1000.0
	hr.WindGrassNoiseFrequency = wind.windGrassNoiseFrequency / 1000.0 * freqScale
end

local easingSinInOut = GetEasingIndex("Sin in/out")
local Lerp = Lerp
local EaseCoeff = EaseCoeff
MapVar("WindChangeTime", -1)
MapVar("WindChangeLast", 10000)
MapVar("WindChangeNext", 10000)

MapVar("WindOff", false)

local function UpdateWindParams()
	local wind = CurrentWindAnimProps()
	if not wind or WindOff then return end
	local windGustsChangePeriod = wind.windGustsChangePeriod
	local t = GameTime() - WindChangeTime
	if t < 0 or t > windGustsChangePeriod then -- period is over, generate new
		WindChangeLast = WindChangeNext
		WindChangeTime = GameTime()
		local gust = 0
		if InteractionRand(100, "WindGustChance") < wind.windGustsProbability then -- wind gust
			gust = InteractionRand(1000, "WindGust")
			WindChangeNext = 10000 + 100 * Lerp(wind.windGustsStrengthMin, wind.windGustsStrengthMax, gust, 1000)
		else
			WindChangeNext = 10000
		end
		WindChangeNext = wind.windScale * WindChangeNext / 100
		t = 0
		WindSound, WindSoundChannel = UpdateWindSound(WindSound, WindSoundChannel, wind.sound, wind.soundVolume, windGustsChangePeriod)
		WindSoundGust, WindSoundGustChannel = UpdateWindSound(WindSoundGust, WindSoundGustChannel, wind.soundGust, gust * wind.soundGustVolume / 1000, windGustsChangePeriod / 2)
	end
	local newScale = Lerp(WindChangeLast, WindChangeNext, EaseCoeff(easingSinInOut, t, windGustsChangePeriod), windGustsChangePeriod) / 10000.0
	hr.WindScale = newScale
	hr.WindTimeScale = wind.windTimeScale / 100.0
	hr.WindRadialTimeScale = wind.windRadialTimeScale / 1000.0
	hr.WindRadialPerturbScale = wind.windRadialPerturbScale / 1000.0
	hr.WindRadialPhaseShift = wind.windRadialPhaseShift / 1000.0
	
	UpdateGrassWind(wind, newScale * 100 / wind.windScale)
end

MapGameTimeRepeat("WindChange", 50, UpdateWindParams)

MapRealTimeRepeat("WindAnim", 16, function()
	local wind = CurrentWindAnimProps()
	if not wind or WindOff then return end
	local now = RealTime()
	hr.WindPerturbScale = wind.windPerturbBase / 1000.0 + wind.windPerturbScale / 1000.0 * sin(now * wind.windPerturbFrequency / 100) / 4096.0
	hr.WindPhaseShift = wind.windPhaseShiftBase / 1000.0 + wind.windPhaseShiftScale / 1000.0 * sin(now * wind.windPhaseShiftFrequency / 100) / 4096.0
end)

function OnMsg.PostNewMapLoaded()
	ApplyWindMarkers()
end

function OnMsg.LoadGame()
	ApplyWindMarkers()
	UpdateWindParams()
end

function OnMsg.DoneMap()
	if WindSoundChannel then
		StopSound(WindSoundChannel)
		WindSoundChannel = false
	end
	WindSound = false
	WindSoundGust = false
	if WindSoundGustChannel then
		StopSound(WindSoundGustChannel)
		WindSoundGustChannel = false
	end
end

for i, name in ipairs(const.WindModifierMaskFlags) do
	local flag = 1 << (i - 1)
	const["WindModifierMask" .. name] = flag
	table.insert(const.WindModifierMaskComboItems, { text = name, value = flag })
end


OnMsg.DoneMap = terrain.ClearWindModifiers
