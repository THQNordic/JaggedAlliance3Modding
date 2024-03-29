-- ========== GENERATED BY GameStateDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('GameStateDef', {
	Comment = "all autosave requests will be ignored",
	MapState = false,
	group = "custom scripting",
	id = "disable_autosave",
})

PlaceObj('GameStateDef', {
	Comment = "disabled satellite view, the inventory, squad management, merc info etc",
	group = "custom scripting",
	id = "disable_pda",
})

PlaceObj('GameStateDef', {
	Comment = "prevents a conflict on the sector from starting in tactical view, by default combat will initiate a conflict",
	group = "custom scripting",
	id = "disable_tactical_conflict",
})

PlaceObj('GameStateDef', {
	Comment = "suspends checks for gameover due to the player having no mercs",
	group = "custom scripting",
	id = "no_gameover",
})

PlaceObj('GameStateDef', {
	Comment = "causes the neutral turn in combat to behave like any other team's turn, preventing civilians running around etc",
	group = "custom scripting",
	id = "skip_civilian_run",
})

PlaceObj('GameStateDef', {
	AutoSet = {
		PlaceObj('CheckOR', {
			Conditions = {
				PlaceObj('CheckGameState', {
					GameState = "Night",
				}),
				PlaceObj('CheckGameState', {
					GameState = "Underground",
				}),
			},
		}),
	},
	description = T(432831225467, --[[GameStateDef LightsOn description]] "The lights are turned at night and underground."),
	display_name = T(806247880285, --[[GameStateDef LightsOn display_name]] "Lights turned on"),
	group = "other",
	id = "LightsOn",
})

PlaceObj('GameStateDef', {
	AutoSet = {
		PlaceObj('CheckOR', {
			Conditions = {
				PlaceObj('CheckGameState', {
					GameState = "RainHeavy",
				}),
				PlaceObj('CheckGameState', {
					GameState = "RainLight",
				}),
			},
		}),
	},
	description = T(631461945070, --[[GameStateDef RainAny description]] "When there is light or heavy Rain."),
	display_name = T(707727914088, --[[GameStateDef RainAny display_name]] "Any Rain"),
	group = "other",
	id = "RainAny",
})

PlaceObj('GameStateDef', {
	AutoSet = {
		PlaceObj('CheckGameState', {
			GameState = "FireStorm",
		}),
	},
	SortKey = 4000,
	display_name = T(742874174855, --[[GameStateDef Burning display_name]] "Burning"),
	group = "other",
	id = "Burning",
})

PlaceObj('GameStateDef', {
	SortKey = 4000,
	group = "other",
	id = "Combat",
})

PlaceObj('GameStateDef', {
	SortKey = 4000,
	group = "other",
	id = "Conflict",
})

PlaceObj('GameStateDef', {
	SortKey = 4000,
	group = "other",
	id = "ConflictScripted",
})

PlaceObj('GameStateDef', {
	WeatherCycle = "CursedForest",
	display_name = T(973521625755, --[[GameStateDef CursedForest display_name]] "Cursed Forest"),
	group = "region",
	id = "CursedForest",
})

PlaceObj('GameStateDef', {
	Color = 4279654092,
	Icon = "UI/Hud/Weather/Underground",
	ReverbIndoor = "Underground",
	ReverbOutdoor = "Underground",
	SortKey = 5000,
	display_name = T(718196821279, --[[GameStateDef Cave_Dry display_name]] "Caves"),
	group = "region",
	id = "Cave_Dry",
})

PlaceObj('GameStateDef', {
	Color = 4279654092,
	SortKey = 5000,
	WeatherCycle = "Dry",
	group = "region",
	id = "Coastal",
})

PlaceObj('GameStateDef', {
	Color = 4284598698,
	SortKey = 5000,
	WeatherCycle = "Wet",
	group = "region",
	id = "Farmlands",
})

PlaceObj('GameStateDef', {
	Color = 4282347790,
	SortKey = 5000,
	WeatherCycle = "Wet",
	group = "region",
	id = "Jungle",
})

PlaceObj('GameStateDef', {
	Color = 4290039375,
	SortKey = 5000,
	WeatherCycle = "Wet",
	group = "region",
	id = "Marshlands",
})

PlaceObj('GameStateDef', {
	Color = 4291594547,
	SortKey = 5000,
	WeatherCycle = "Dry",
	group = "region",
	id = "Savanna",
})

PlaceObj('GameStateDef', {
	AutoSet = {
		PlaceObj('CheckOR', {
			Conditions = {
				PlaceObj('CheckGameState', {
					GameState = "Cave_Dry",
				}),
				PlaceObj('CheckGameState', {
					GameState = "Underground",
				}),
			},
		}),
	},
	Color = 4279654092,
	Icon = "UI/Hud/Weather/Underground",
	ReverbIndoor = "Underground",
	ReverbOutdoor = "Underground",
	SortKey = 5000,
	description = T(363150960472, --[[GameStateDef Underground description]] "Enemies in darkness are harder to notice. Ranged attacks against them suffer a low visibility penalty, except at point blank range."),
	display_name = T(122326940582, --[[GameStateDef Underground display_name]] "Underground"),
	group = "region",
	id = "Underground",
})

PlaceObj('GameStateDef', {
	Color = 4291876232,
	SortKey = 5000,
	WeatherCycle = "Dry",
	group = "region",
	id = "Wastelands",
})

PlaceObj('GameStateDef', {
	Icon = "UI/Hud/Weather/ClearSky",
	SortKey = 1000,
	description = T(601696550398, --[[GameStateDef ClearSky description]] "No special gameplay effects."),
	display_name = T(413258994286, --[[GameStateDef ClearSky display_name]] "Clear Weather"),
	group = "weather",
	id = "ClearSky",
})

PlaceObj('GameStateDef', {
	Color = 4287528815,
	Icon = "UI/Hud/Weather/DustStorm",
	SortKey = 1000,
	description = T(447311153176, --[[GameStateDef DustStorm description]] "Movement costs are increased. Cover is more effective. Enemies become concealed at certain distance. Ranged attacks against concealed foes may become grazing hits."),
	display_name = T(805901151708, --[[GameStateDef DustStorm display_name]] "Dust Storm"),
	group = "weather",
	id = "DustStorm",
})

PlaceObj('GameStateDef', {
	Color = 4292700458,
	Icon = "UI/Hud/Weather/FireStorm",
	SortKey = 1000,
	description = T(680282265106, --[[GameStateDef FireStorm description]] "Visual range is reduced. Characters may lose Energy and eventually collapse when standing close to a fire in combat."),
	display_name = T(506683792990, --[[GameStateDef FireStorm display_name]] "Fire Storm"),
	group = "weather",
	id = "FireStorm",
})

PlaceObj('GameStateDef', {
	Color = 4288524727,
	Icon = "UI/Hud/Weather/Fog",
	SortKey = 1000,
	description = T(875091520439, --[[GameStateDef Fog description]] "Visual range is reduced and enemies become concealed at certain distance. Ranged attacks against concealed foes may become grazing hits."),
	display_name = T(736288989376, --[[GameStateDef Fog display_name]] "Fog"),
	group = "weather",
	id = "Fog",
})

PlaceObj('GameStateDef', {
	Color = 4289404937,
	Icon = "UI/Hud/Weather/Heat",
	SortKey = 1000,
	description = T(156684039427, --[[GameStateDef Heat description]] "When receiving a Wound, characters may lose Energy and eventually collapse."),
	display_name = T(152546781442, --[[GameStateDef Heat display_name]] "Heat"),
	group = "weather",
	id = "Heat",
})

PlaceObj('GameStateDef', {
	CodeCustom = function (self, ...)
		local _, lookat = cameraTac.GetPosLookAt()
		local pos = Rotate(point(30 * guim, 0, 0), AsyncRand(60 * 360))
		pos = (lookat + pos):SetTerrainZ() + point(0, 0, 30 * guim)
		PlayFX("LightningStrike", "start", pos, pos, pos)
	end,
	CodeOnActivate = function (self, ...)
		self:PlayGlobalSound()
		self.thread = CreateGameTimeThread(function()
			PlayRoofFX()
			Sleep(1000 * 15)
			while true do
				Sleep(1000*(15 + AsyncRand(30)))
				
				if AsyncRand(100) < 40 then
					self:CodeCustom()
				else
					-- distant thunder
					local sound = "thunder_distant"
					local handle, err = PlaySound(sound, "EnvironmentNonPositional", 100, 0)
					if handle then
						local duration = GetSoundDuration(handle)
						g_vGameStateDefSounds[self.id][handle] = sound
						DbgMusicPrint(string.format("Playing %s for %dms, Handle: %d", sound, duration, handle))
						Sleep(duration)
						g_vGameStateDefSounds[self.id][handle] = nil
					else
						print("once", "attempt to play thunder_distant", err)
					end
				end
			end
		end)
	end,
	CodeOnDeactivate = function (self, ...)
		self:StopSounds()
		StopRoofFX()
	end,
	Color = 4280709547,
	GlobalSoundBankActivation = "rain_heavy",
	Icon = "UI/Hud/Weather/HeavyRainOrThunderstorm",
	SortKey = 1000,
	description = T(722420801448, --[[GameStateDef RainHeavy description]] "Aiming costs are increased. Hearing is impaired. Weapons lose condition and jam more often. Throwable items tend to mishap."),
	display_name = T(361632970912, --[[GameStateDef RainHeavy display_name]] "Heavy Rain"),
	group = "weather",
	id = "RainHeavy",
})

PlaceObj('GameStateDef', {
	Color = 4282158492,
	GlobalSoundBankActivation = "rain_medium",
	Icon = "UI/Hud/Weather/LightRain",
	SortKey = 1000,
	description = T(158698953226, --[[GameStateDef RainLight description]] "Hearing is impaired. Weapons lose condition and jam more often."),
	display_name = T(776337888549, --[[GameStateDef RainLight display_name]] "Rain"),
	group = "weather",
	id = "RainLight",
})

PlaceObj('GameStateDef', {
	Color = 4281761720,
	SortKey = 3000,
	display_name = T(270397676709, --[[GameStateDef Day display_name]] "Day"),
	group = "time of day",
	id = "Day",
})

PlaceObj('GameStateDef', {
	Color = 4280356778,
	Icon = "UI/Hud/Weather/Night",
	SortKey = 3000,
	description = T(466554117657, --[[GameStateDef Night description]] "Enemies in darkness are harder to notice. Ranged attacks against them suffer a low visibility penalty, except at point blank range."),
	display_name = T(263043614867, --[[GameStateDef Night display_name]] "Night"),
	group = "time of day",
	id = "Night",
})

PlaceObj('GameStateDef', {
	Color = 4291121856,
	SortKey = 3000,
	display_name = T(106283220809, --[[GameStateDef Sunrise display_name]] "Sunrise"),
	group = "time of day",
	id = "Sunrise",
})

PlaceObj('GameStateDef', {
	Color = 4289795598,
	SortKey = 3000,
	display_name = T(652190990891, --[[GameStateDef Sunset display_name]] "Sunset"),
	group = "time of day",
	id = "Sunset",
})

