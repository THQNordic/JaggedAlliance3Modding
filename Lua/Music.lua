if FirstLoad then
	g_PlaylistMood = false
end

function SetSectorMusicOverride(sector, mood, playlist)
	g_PlaylistMood = g_PlaylistMood or {}
	g_PlaylistMood[sector] = g_PlaylistMood[sector] or {}
	g_PlaylistMood[sector][mood] = playlist or nil
end

function GetSectorMusicOverride(mood)
	return g_PlaylistMood and g_PlaylistMood[gv_CurrentSectorId] and g_PlaylistMood[gv_CurrentSectorId][mood]
end

function GetSectorMusic(mood)
	return gv_Sectors and gv_Sectors[gv_CurrentSectorId] and gv_Sectors[gv_CurrentSectorId][mood]
end

function GetSectorCombatStation()
	return GetSectorMusicOverride("MusicCombat") or GetSectorMusic("MusicCombat")
end

function GetSectorConflictStation()
	return GetSectorMusicOverride("MusicConflict") or GetSectorMusic("MusicConflict")
end

function GetSectorExplorationStation()
	return GetSectorMusicOverride("MusicExploration") or GetSectorMusic("MusicExploration")
end

function GetSectorStation()
	if GameState.Combat then
		return GetSectorCombatStation()
	elseif GameState.Conflict then
		return GetSectorConflictStation()
	elseif GameState.Exploration then
		return GetSectorExplorationStation()
	end	
end

function ResetSectorStation()
	if GameState.Combat then
		return StartRadioStation(GetSectorCombatStation(), nil, "force")
	elseif GameState.Conflict then
		return StartRadioStation(GetSectorConflictStation(), nil, "force")
	elseif GameState.Exploration then
		return StartRadioStation(GetSectorExplorationStation(), nil, "force")
	end	
end

function CheckSectorRadioStations(sector)
	if not sector.MusicCombat then
		StoreErrorSource(sector, "Sector Radio Station playlist for Combat is missing")
	end
	if not sector.MusicConflict then
		StoreErrorSource(sector, "Sector Radio Station playlist for Conflict is missing")
	end
	if not sector.MusicCombat then
		StoreErrorSource(sector, "Sector Radio Station playlist for Exploration is missing")
	end
end

function OnMsg.PreGameMenuOpen()
	StartRadioStation("PreGameMenu", nil, "force")
end

function OnMsg.NewMapLoaded()
	if GetDialog("Intro") then
		SetMusicPlaylist()
	else
		SetMusicPlaylist("Radio")
	end
end

function StartExplorationRadioDelayed()
	StartRadioStation(GetSectorExplorationStation(), const.Radio.StartNewStationDelay)
end

function OnMsg.ConflictStart()
	if not (g_Combat or g_StartingCombat) then
		StartRadioStation(GetSectorConflictStation())
	end
end

OnMsg.ConflictEnd = StartExplorationRadioDelayed

function OnMsg.CombatStart()
	StartRadioStation(GetSectorCombatStation())
end

function OnMsg.CombatEnd()
	if GameState.Conflict then
		StartRadioStation(GetSectorConflictStation())
	else
		StartExplorationRadioDelayed()
	end
end

function OnMsg.EnterSector(game_start)
	StartRadioStation(GetSectorStation(), not game_start and const.Radio.StartNewStationDelay)
end

function OnMsg.OpenSatelliteView()
	if not GetDialog("Intro") then
		StartRadioStation("SatelliteRadio", const.Radio.StartNewStationDelay)
	end
end

function OnMsg.ClosePDA()
	StartRadioStation(GetSectorStation())
end

function OnMsg.IntroClosed()
	SetMusicPlaylist("Radio")
	StartRadioStation("SatelliteRadio")
end

function OnMsg.GameStateChanged(changed)
	local required_station = GetSectorStation() or false
	if required_station and ActiveRadioStation ~= required_station then
		StartRadioStation(required_station)
	end
end

function RadioPlaylistCombo(radio)
	local station = Presets.RadioStationPreset["Default"][radio]
	if not station then return end
	
	local playlist = PlaylistCreate(station.Folder)
	
	local tracks = {}
	for _, track in ipairs(playlist) do
		table.insert(tracks, track.path)
	end
	
	return tracks, playlist
end

AppendClass.RadioStationPreset = {
	properties = {
		{ category = "Zulu Specific", id = "Files", name = "Files", editor = "nested_list",
			default = false, base_class = "RadioPlaylistTrack",
		},
	},
}

function RadioStationPreset:GetPlaylist()
	local playlist = PlaylistCreate(self.Folder)
	for _, entry in ipairs(self.Files) do
		table.insert(playlist, {
			path = entry.Track,
			frequency = entry.Frequency,
			empty = entry.EmptyTrack or nil,
			duration = entry.EmptyTrack and entry.Duration or nil,
		})
	end
	
	playlist.SilenceDuration = self.SilenceDuration
	playlist.Volume = self.Volume
	playlist.FadeOutTime = self.FadeOutTime
	playlist.FadeOutVolume = self.FadeOutVolume
	playlist.mode = self.Mode
	
	return playlist
end

function GatherMusic(radio, used_music)
	local preset = FindPreset("RadioStationPreset", radio)
	for _, entry in ipairs(preset.Files) do
		used_music[entry.Track] = true
	end
end

function OnMsg.GatherMusic(used_music)
	for _, group in ipairs(Presets.CampaignPreset or empty_table) do
		for _, campaign in ipairs(group or empty_table) do
			for _, sector in ipairs(campaign.Sectors or empty_table) do
				if IsDemoSector(sector.id) then
					GatherMusic(sector.MusicExploration, used_music)
					GatherMusic(sector.MusicCombat, used_music)
					GatherMusic(sector.MusicConflict, used_music)
				end
			end
		end
	end
end
