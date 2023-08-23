MapVar("g_EnvSound", false)
MapVar("g_EnvSoundChannel", false)
MapVar("g_EnvSoundTimeEnd", 0)
MapVar("g_EnvSoundFadeOut", 3000)

if FirstLoad then
	g_EnvSndDebugPrints = false
end

function ToggleEnvSndDebugPrints()
	g_EnvSndDebugPrints = not g_EnvSndDebugPrints
end

function EnvSndDebugPrint(...)
	if g_EnvSndDebugPrints then
		print(...)
	end
end

local listener_size = point(const.SlabSizeX, const.SlabSizeY, 0)

function IsPointInsideRoom(pos)
	return not not EnumVolumes("Room", sizebox(pos - listener_size, listener_size * 2))
end

function IsListenerInsideRoom(listener_pos)
	return IsPointInsideRoom(listener_pos or GetListenerPos())
end

local function GetEnvObjects(pos)
	local pos_zero_Z = pos:SetZ(0)
	local max_range = GetLocationMaxRange()
	local pt_range = point(max_range, max_range, const.SanePosMaxZ)
	local box_range = box(pos_zero_Z - pt_range, pos_zero_Z + pt_range)
	
	return MapGet(box_range)
end

MapVar("g_LastEnvLocations", false)
MapVar("g_LastEnvLocationsPos", false)

function EnvironmentSoundUpdate()
	if IsEditorActive() then return end

	local pos = GetListenerPos()
	local cam_pos = camera.GetPos()
	local high = cam_pos:z() - pos:z() > 8 * guim and "High" or "Low"
	
	local locations = g_LastEnvLocations
	if not g_LastEnvLocations or not g_LastEnvLocationsPos or g_LastEnvLocationsPos:Dist(pos) > guim then
		local objs = GetEnvObjects(pos)
	
		locations = GetEnvironmentLocation(pos, objs)
		g_LastEnvLocations = locations
		g_LastEnvLocationsPos = pos
	end
	
	local sound, env_sound_fade, env_sound_volume = GetAtmosphericSound(locations, high)
	if env_sound_volume then
		env_sound_volume = MulDivTrunc(env_sound_volume, 1000, 100)
		env_sound_volume = IsListenerInsideRoom(pos) and (env_sound_volume / 2) or env_sound_volume
	end

	if g_EnvSound ~= sound then
		if g_EnvSoundChannel then
			SetSoundVolume(g_EnvSoundChannel, -1, g_EnvSoundFadeOut)
			EnvSndDebugPrint(string.format("Stopping '%s', Fade Out: %d", g_EnvSound, g_EnvSoundFadeOut))
		end
		g_EnvSoundChannel = false
		if sound then
			g_EnvSoundChannel = PlaySound(sound, env_sound_volume, g_EnvSoundFadeOut)
			local duration = GetSoundDuration(g_EnvSoundChannel) or 0
			g_EnvSoundTimeEnd = RealTime() + duration
			EnvSndDebugPrint(string.format("Playing '%s' for %d, '%s' Fade Out: %d", sound, duration, g_EnvSound, g_EnvSoundFadeOut))
		end
	elseif g_EnvSoundChannel then
		SetSoundVolume(g_EnvSoundChannel, env_sound_volume, g_EnvSoundFadeOut)
		if RealTime() - g_EnvSoundTimeEnd >= 0 then
			SetSoundVolume(g_EnvSoundChannel, -1, g_EnvSoundFadeOut)
			g_EnvSoundChannel = PlaySound(sound, env_sound_volume, g_EnvSoundFadeOut)
			local duration = GetSoundDuration(g_EnvSoundChannel) or 0
			g_EnvSoundTimeEnd = RealTime() + duration
			EnvSndDebugPrint(string.format("Re-Playing '%s' for %d, Fade Out: %d", sound, duration, g_EnvSoundFadeOut))
		end
	end
	g_EnvSound = sound
	g_EnvSoundFadeOut = env_sound_fade or 3000
end

function OnMsg.DoneMap()
	if g_EnvSoundChannel then
		StopSound(g_EnvSoundChannel)
	end
end

function OnMsg.GameEnterEditor()
	EnvSndDebugPrint(string.format("Stopping environmental sounds in editor"))
	StopSound(g_EnvSoundChannel)
	g_EnvSound = false
	g_EnvSoundChannel = false
end

MapGameTimeRepeat("EnvSound", 333, EnvironmentSoundUpdate)

function OnMsg.GatherSounds(used_sounds)
	local atmo_sounds = Presets.SoundPreset.ATMOSPHERIC or {}
	for _, preset in ipairs(atmo_sounds) do
		if not preset.Regions or table.find(preset.Regions, "Jungle") or table.find(preset.Regions, "Underground") then
			for _, bank in ipairs(preset) do
				used_sounds[bank.file] = true
			end
		end
	end
end