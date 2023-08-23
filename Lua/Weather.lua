--[[

Weather System

Weather
	a map state affecting gameplay, visuals, etc.

Time-of-day, or tod
	a map state affecting gameplay, visuals, etc, derived from the campaign time; tods are Sunrise, Day, Sunset, Night, controlled by constants in const.Satellite

Region
	overall map environment, e.g. Jungle or Savanna; it specified in the mapdata, because it's tightly connected to what is on the map
	regions have either "Dry" or "Wet" weather cycles

Weather Zone
	a set of sectors which change weather together; specified in the sector data
	all sectors with regions of the Dry weather cycle in the same zone are in the same Weather at any moment

Map state algorithm for entering a given sector at a given time:
	- look up sector's weather zone
	- look up sector's map's region
	- calculate weather from (campaign time, weather zone, region wet/dry)
	- calculate time-of-day from campaign time
	- choose a lightmode by matching (region, weather, time-of-day) against LightmodelSelectionRules
	- set region, weather, time-of-day as map states
]]

WeatherCycle = {
	Wet = {
		{ "ClearSky",  100, 24, 72 },
		{ "RainLight", 100, 12, 36 },
		{ "RainHeavy",  50, 12, 36 },
		{ "Fog",        75, 12, 36 },
	},
	Dry = {
		{ "ClearSky",  100, 24, 72 },
		{ "FireStorm",  50, 24, 48 },
		{ "DustStorm",  75, 12, 36 },
		{ "Heat",      100, 24, 48 },
	},
	CursedForest = {		
		{ "RainLight", 100, 12, 36 },
		{ "Fog",        50, 12, 24 },
	},
}

GameVar("g_vGameStateDefSounds", false)

AppendClass.GameStateDef = {
	properties = {
		{category = "Sound & Custom Effects", id = "GlobalSoundBankActivation", name = "Global Sound on Activation", 
			editor = "preset_id", default = false, preset_class = "SoundPreset"},
		{category = "Sound & Custom Effects", id = "CodeOnActivate", name = "Code on Activation",
			editor = "func", params = "self, ...", no_edit = function(self) return not self.GlobalSoundBankActivation end},
		{category = "Sound & Custom Effects", id = "CodeOnDeactivate", name = "Code on Deactivation",
			editor = "func", params = "self, ...", no_edit = function(self) return not self.GlobalSoundBankActivation end},
		{category = "Sound & Custom Effects", id = "CodeCustom", name = "Custom Code", default = empty_func,
			editor = "func", params = "self, ...", no_edit = function(self) return not self.GlobalSoundBankActivation end},
	},
	
	global_sound_bank = false,
	thread = false
}

function GameStateDef:PlayGlobalSound()
	if not self.GlobalSoundBankActivation then return end

	DeleteThread(self.thread)
	self.thread = CreateMapRealTimeThread(function()
		WaitLoadingScreenClose()
		local sound = self.GlobalSoundBankActivation
		local handle = PlaySound(sound, nil, 100, 3000)
		if handle then
			local duration = GetSoundDuration(handle)
			g_vGameStateDefSounds = g_vGameStateDefSounds or {}
			g_vGameStateDefSounds[self.id] = g_vGameStateDefSounds[self.id] or {}	
			g_vGameStateDefSounds[self.id][handle] = sound
			DbgMusicPrint(string.format("Playing %s for %dms, Handle: %d", sound, duration, handle))
		end
	end)
end

function GameStateDef:StopSounds()
	DeleteThread(self.thread)
	if g_vGameStateDefSounds and g_vGameStateDefSounds[self.id] then
		for handle, sound in pairs(g_vGameStateDefSounds[self.id]) do
			SetSoundVolume(handle, 0, 3000)
			if type(sound) == "boolean" then
				DbgMusicPrint(string.format("Stopping Handle: %d", handle))
			else
				DbgMusicPrint(string.format("Stopping %s, Handle: %d", sound, handle))
			end
		end
		g_vGameStateDefSounds[self.id] = nil
	end
end

function GameStateDef:CodeOnActivate()
	self:PlayGlobalSound()
end

function GameStateDef:CodeOnDeactivate()
	self:StopSounds()
end

function OnMsg.GameStateChanged(changed)
	if not GameStateDefs or not next(GameStateDefs) then return end
	
	for state, set in sorted_pairs(changed) do
		if not set then
			local def = GameStateDefs[state]
			if def then
				def:CodeOnDeactivate()
			end
		end
	end
	for state, set in sorted_pairs(changed) do
		if set then
			local def = GameStateDefs[state]
			if def then
				def:CodeOnActivate()
			end
		end
	end
	if changed.Combat and GameState.RainHeavy then
		local rain_heavy = GameStateDefs["RainHeavy"]
		if rain_heavy then
			rain_heavy:CodeCustom()
		end
	end
	if changed.entered_sector == false then
		if GameState["RainHeavy"] then
			GameStateDefs["RainHeavy"]:CodeOnDeactivate()
		end
		if GameState["RainLight"] then
			GameStateDefs["RainLight"]:CodeOnDeactivate()
		end
	end
end

function OnMsg.SlabsDoneLoading()
	CreateVfxControllersForAllRoomsOnMap()
end

function CalculateWeatherForSector(weather_cycle, weather_zone, time)
	local hours = time / const.Scale.h -- since campaign start
	local cycle = WeatherCycle[weather_cycle]
	local wrand = BraidRandomCreate(Game.id, weather_zone)
	local h = 0
	while true do
		for i, w in ipairs(cycle) do 
			if wrand(100) < w[2] then
				h = h + wrand(w[3], w[4])
				if hours < h then return w[1] end
			end
		end
	end
end

function GetCurrentSectorWeather(sector_id)
	if g_TestCombat and g_TestCombat.Weather ~= "Default" then
		return g_TestCombat.Weather
	end
	
	local sector = gv_Sectors[sector_id or gv_CurrentSectorId]
	local mapData = sector and MapData[sector.Map]
	if not sector or not mapData then
		return "ClearSky"
	end
	
	local region = mapData.Region
	local weather_cycle = GameStateDefs[region] and GameStateDefs[region].WeatherCycle
	if not weather_cycle then
		return 
	end
	local time_since_start = 0
	if Game and Game.Campaign and Game.CampaignTime and Game.CampaignTimeStart then
		time_since_start = Game.CampaignTime - Game.CampaignTimeStart
	end
	return CalculateWeatherForSector(weather_cycle, sector.WeatherZone, time_since_start)
end

function CalculateTimeOfDay(time)
	local hour_in_day = (time % const.Scale.day) / const.Scale.h
	local cs = const.Satellite
	if hour_in_day < cs.SunriseStartHour or hour_in_day >= cs.NightStartHour then
		return "Night"
	elseif hour_in_day >= cs.SunriseStartHour and hour_in_day < cs.DayStartHour then
		return "Sunrise"
	elseif hour_in_day >= cs.SunsetStartHour and hour_in_day < cs.NightStartHour then
		return "Sunset"
	else
		return "Day"
	end
end

function CalculateTimeFromTimeOfDay(timeOfDay)
	local cs = const.Satellite
	local halfHour = 1 * const.Scale.h / 2
	if timeOfDay == "Night" then
		return cs.NightStartHour * const.Scale.h + halfHour
	elseif timeOfDay == "Sunrise" then
		return cs.SunriseStartHour * const.Scale.h + halfHour
	elseif timeOfDay == "Sunset" then
		return cs.SunsetStartHour * const.Scale.h + halfHour
	elseif timeOfDay == "Day" then
		return cs.DayStartHour * const.Scale.h + halfHour
	elseif timeOfDay == "Any" then
		return InteractionRand(const.Scale.day, "Satellite")
	end
end

GameVar("gv_ForceWeatherTodRegion", false)

function MapDataPreset:ChooseLightmodel()
	local tod = self.Tod
	if tod == "none" then
		if Game and Game.Campaign and Game.CampaignTime then
			tod = CalculateTimeOfDay(Game.CampaignTime)
		else
			tod = "Day"
		end
	end
	
	local region = self.Region
	local weather = self.Weather
	if weather == "none" then
		if	gv_Sectors and 
			gv_CurrentSectorId and 
			gv_Sectors[gv_CurrentSectorId] and 
			gv_Sectors[gv_CurrentSectorId].Map == self.id 
		then
			weather = GetCurrentSectorWeather()
		else
			weather = "ClearSky"
		end
	end
	
	if weather == "Heat" and tod == "Night" then
		weather = "ClearSky"
	end
	
	if gv_ForceWeatherTodRegion then
		tod = gv_ForceWeatherTodRegion.tod ~= "any" and gv_ForceWeatherTodRegion.tod or tod
		weather = gv_ForceWeatherTodRegion.weather ~= "any" and gv_ForceWeatherTodRegion.weather or weather
		region = gv_ForceWeatherTodRegion.region ~= "any" and gv_ForceWeatherTodRegion.region or region
	end
	
	if weather then
		ChangeGameState{ [weather] = true, [tod] = true, [region] = true }
	else
		ChangeGameState{ [tod] = true, [region] = true }
	end
	return self.Lightmodel or SelectLightmodel(region, weather, tod)
end

function SavegameSessionDataFixups.CampaignTimeStart(data, metadata, lua_revision)
	if not data.game.CampaignTimeStart then
		local campaign = CampaignPresets[data.game.Campaign]
		data.game.CampaignTimeStart = campaign.starting_timestamp
	end
end

function OnMsg.AfterLightmodelChange(view, lightmodel, time, prev_lm, from_override)
	if from_override then return end
	if prev_lm and prev_lm.id == lightmodel.id then return end
	if FindGedApp("PresetEditor", "LightmodelSelectionRule") then return end
	
	local force_map_states = (LightmodelOverride and FindGedApp("LightmodelEditor")) or IsCameraEditorOpened()
	local in_editor = IsEditorActive()
	if force_map_states or (not in_editor) or (in_editor and lightmodel.id == mapdata.EditorLightmodel) then
		local map_states = { 
			Night = false, Sunrise = false, Day = false, Sunset = false, Rain = false,
			ClearSky = false, DustStorm = false, FireStorm = false,
			Fog = false, Heat = false, RainHeavy = false, RainLight = false,
		}
		local lightmodel_id = lightmodel.id:lower()
		if lightmodel_id:find("sunrise") then
			map_states.Sunrise = true
		elseif lightmodel_id:find("sunset") then
			map_states.Sunset = true
		elseif lightmodel.night then
			map_states.Night = true
		else
			map_states.Day = true
		end
		if lightmodel_id:find("rainstorm") then
			map_states.RainHeavy = true
		elseif lightmodel_id:find("rain") then
			map_states.RainLight = true
		elseif lightmodel_id:find("duststorm") then
			map_states.DustStorm = true
		elseif lightmodel_id:find("firestorm") then
			map_states.FireStorm = true
		elseif lightmodel_id:find("fog") or lightmodel_id:find("mist") then
			map_states.Fog = true
		elseif lightmodel_id:find("heat") then
			map_states.Heat = true
		else
			map_states.ClearSky = true
		end
		
		ChangeGameState(map_states)
		CreateGameTimeThread( function()
			C_CCMT_Reset()
			SuspendPassEdits("rebuild autoattaches")
			PauseInfiniteLoopDetection("rebuild autoattaches")
			MapForEach("map", "AutoAttachObject", function(o) 
				o:SetAutoAttachMode(o.auto_attach_mode) 
			end) 
			ResumeInfiniteLoopDetection("rebuild autoattaches")
			ResumePassEdits("rebuild autoattaches")
		end)
	end
end

function GetLightModelRegion()
	local region
	for _, data in pairs(LightmodelSelectionRules) do 
		if data.lightmodel==CurrentLightmodel[1].id then 
			region = data.region
			break
		end 
	end
	return region or mapdata.Region or CurrentLightmodel[1].group
end

function GetCheatsWeatherTOD()
	local weather_cycle = GameStateDefs[mapdata.Region] and GameStateDefs[mapdata.Region].WeatherCycle or "Dry"
	local weathers = WeatherCycle[weather_cycle]
	local tods = Presets.GameStateDef["time of day"]
	local weather_tods = {}
	for _, weather in ipairs(weathers) do
		for _, tod in ipairs(tods) do
			table.insert(weather_tods, {weather = weather[1], tod = tod.id})
		end
	end
	
	return weather_tods
end

function NetSyncEvents.TestRainHeavy()
	ChangeGameState{["RainHeavy"] = true}
end

function NetSyncEvents.CheatWeatherTOD(weather_tod)
	local region, weather, tod = mapdata.Region, weather_tod.weather, weather_tod.tod
	local lightmodel = SelectLightmodel(region, weather, tod)
	ChangeGameState{[weather] = true, [tod] = true, [region] = true}
	SetLightmodel(1, lightmodel, 0)
end