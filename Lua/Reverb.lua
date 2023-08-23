MapVar("g_ReverbIndoor", false)
MapVar("g_ReverbOutdoor", false)

function ReverbUpdate(force)
	if not config.UseReverb then return end
	
	-- per map is the highest priority
	local reverb_outdoor = mapdata.ReverbOutdoor ~= "default from Region" and mapdata.ReverbOutdoor
	local reverb_indoor = mapdata.ReverbIndoor ~= "default from Region" and mapdata.ReverbIndoor
	
	-- then the region
	local region = Presets.GameStateDef["region"][mapdata.Region]
	if region then
		reverb_indoor = reverb_indoor or region.ReverbIndoor
		reverb_outdoor = reverb_outdoor or region.ReverbOutdoor
	end
	
	if force or g_ReverbIndoor ~= reverb_indoor then
		g_ReverbIndoor = reverb_indoor
		local reverb_props = Presets.ReverbDef.Default[reverb_indoor]
		ApplyReverbPreset(reverb_props, const.Sound.ReverbPresetInterpolationTime, 1)
	end
	if force or g_ReverbOutdoor ~= reverb_outdoor then
		g_ReverbOutdoor = reverb_outdoor
		local reverb_props = Presets.ReverbDef.Default[reverb_outdoor]
		ApplyReverbPreset(reverb_props, const.Sound.ReverbPresetInterpolationTime, 0)
	end
end

OnMsg.NewMapLoaded = FillVolumeReverbs
OnMsg.LoadSector = FillVolumeReverbs

function OnMsg.DestructionPassDone()
	if not GameState.loading_savegame then
		FillVolumeReverbs()
	end
end

MapRealTimeRepeat("Reverb", const.Sound.ReverbPresetUpdateTime, function(time) ReverbUpdate(not "force") end)

function OnMsg.GedClosed(ged_editor)
	if ged_editor and ged_editor.context and ged_editor.context.PresetClass == "ReverbDef" then
		ReverbUpdate("force")
	end
end

if FirstLoad then
	s_DrySoundCache = {}
end

local pos_volume_offset = point(0, 0, const.vsInsideVolumeZOffset)

function ActionFXSound:GetProjectReplace(sound, actor)
	local pos = IsValid(actor) and IsKindOf(actor, "Object") and actor:GetPos() or actor
	if not IsPoint(pos) then
		return sound
	end
	
	local cached_sound = s_DrySoundCache[sound]
	if cached_sound then
		return cached_sound
	end
	
	pos = pos + pos_volume_offset
	if GetReverbIndex(pos) == 1 then
		for _, group in ipairs(Presets.SoundPreset) do
			if table.find(group, "id", sound) then
				local room_sound = sound .. "-room"
				if table.find(group, "id", room_sound) then
					s_DrySoundCache[sound] = room_sound
					return room_sound
				end
			end
		end
	end
	
	return sound
end

DefineClass.ReverbSoundTest = {
	__parents = {"SoundSourceBaseImpl"},
	entity = "SpotHelper",
	
	thread = false,
}

function ReverbSoundTest:GameInit()
	self.thread = CreateGameTimeThread(function()
		while true do
			self:PlaySound()
			Sleep(1000 + self:Random(1000))
		end
	end)
end

function ReverbSoundTest:Done()
	DeleteThread(self.thread)
end

function ReverbSoundTest:PlaySound()
	local sound_bank = Presets.SoundPreset["AMBIENT-LIFE"]["ReverbTest"]
	if sound_bank then
		PlaySound(sound_bank.id, sound_bank.type, nil, nil, nil, self, sound_bank.loud_distance)
	end
end
