-- ========== GENERATED BY BanterDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "DrGruselheim",
			'Text', T(621798286078, --[[BanterDef Gruselheim_Anywhere_01 Text section:DLC_U-Bahn_Local/Gruselheim_Anywhere_01 voice:DrGruselheim]] "Ach, it's so good to be able to go out in the sun! Not that I have the time for that."),
		}),
	},
	conditions = {
		PlaceObj('IsCurrentMap', {
			MapFile = "K-11U - Cryolabor",
			Negate = true,
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_Anywhere_01",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', 'Reference to "Dr. Strangelove"',
			'Character', "DrGruselheim",
			'Text', T(251358538156, --[[BanterDef Gruselheim_Anywhere_02 Text section:DLC_U-Bahn_Local/Gruselheim_Anywhere_02 Reference to "Dr. Strangelove" voice:DrGruselheim]] "I feel some strange love to this country that fate has bound me to. This is my new Mutterland."),
		}),
	},
	conditions = {
		PlaceObj('IsCurrentMap', {
			MapFile = "K-11U - Cryolabor",
			Negate = true,
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_Anywhere_02",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', "Reference to Vonnegut's \"Mother Night\"",
			'Character', "DrGruselheim",
			'Text', T(354640048983, --[[BanterDef Gruselheim_Anywhere_03 Text section:DLC_U-Bahn_Local/Gruselheim_Anywhere_03 Reference to Vonnegut's "Mother Night" voice:DrGruselheim]] "It doesn't feel right that no one remembers the War. As if it didn't happen! Sometimes I feel the snow of the years creeping in to bury me. "),
		}),
	},
	conditions = {
		PlaceObj('IsCurrentMap', {
			MapFile = "K-11U - Cryolabor",
			Negate = true,
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_Anywhere_03",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "DrGruselheim",
			'Text', T(141609322693, --[[BanterDef Gruselheim_Anywhere_04 Text section:DLC_U-Bahn_Local/Gruselheim_Anywhere_04 voice:DrGruselheim]] "Siegfried?!..."),
		}),
		PlaceObj('BanterLine', {
			'Annotation', 'Reference to "Idiocracy".',
			'Character', "DrGruselheim",
			'Text', T(962199999153, --[[BanterDef Gruselheim_Anywhere_04 Text section:DLC_U-Bahn_Local/Gruselheim_Anywhere_04 Reference to "Idiocracy". voice:DrGruselheim]] "...Ach, it's you. I tend to get confused. Sometimes I'm not sure who I am anymore."),
		}),
	},
	conditions = {
		PlaceObj('IsCurrentMap', {
			MapFile = "K-11U - Cryolabor",
			Negate = true,
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_Anywhere_04",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', 'Reference to "Iron Sky"',
			'Character', "DrGruselheim",
			'Text', T(685735491004, --[[BanterDef Gruselheim_Anywhere_06 Text section:DLC_U-Bahn_Local/Gruselheim_Anywhere_06 Reference to "Iron Sky" voice:DrGruselheim]] "I wonder what happened to my friend Dr. Richter and his Helium-3 project."),
		}),
	},
	conditions = {
		PlaceObj('IsCurrentMap', {
			MapFile = "K-11U - Cryolabor",
			Negate = true,
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_Anywhere_06",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "DrGruselheim",
			'Text', T(460455332986, --[[BanterDef Gruselheim_DieselClinic_02 Text section:DLC_U-Bahn_Local/Gruselheim_DieselClinic_02 voice:DrGruselheim]] "The Diesel Klinik is doing well. All parameters are optimal. "),
		}),
	},
	conditions = {
		PlaceObj('PlayerIsInSectors', {
			Sectors = {
				"B12",
				"B12_Underground",
			},
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_DieselClinic_02",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "DrGruselheim",
			'Text', T(211903370943, --[[BanterDef Gruselheim_DieselClinic_03 Text section:DLC_U-Bahn_Local/Gruselheim_DieselClinic_03 voice:DrGruselheim]] "I restored the production of <em>Wunderfrostschutzmittel</em>. It has so many medical uses! In a few years, we may turn this country into a leader in the field of cryotechnology ."),
		}),
	},
	conditions = {
		PlaceObj('PlayerIsInSectors', {
			Sectors = {
				"B12",
				"B12_Underground",
			},
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_DieselClinic_03",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', 'Vague reference to "Idiocracy".',
			'Character', "DrGruselheim",
			'Text', T(285849596464, --[[BanterDef Gruselheim_DieselClinic_04 Text section:DLC_U-Bahn_Local/Gruselheim_DieselClinic_04 Vague reference to "Idiocracy". voice:DrGruselheim]] "When we finally harness the regenerative properties of <em>Wunderfrostschutzmittel</em>, natural selection will stop playing a definitive role in human evolution."),
		}),
	},
	conditions = {
		PlaceObj('PlayerIsInSectors', {
			Sectors = {
				"B12",
				"B12_Underground",
			},
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_DieselClinic_04",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Annotation', 'Reference to "Oppenheimer".',
			'Character', "DrGruselheim",
			'Text', T(257067425329, --[[BanterDef Gruselheim_DieselClinic_05 Text section:DLC_U-Bahn_Local/Gruselheim_DieselClinic_05 Reference to "Oppenheimer". voice:DrGruselheim]] "Sometimes I worry that with <em>Wunderfrostschutzmittel</em>, I have started a chain reaction that might destroy the entire world."),
		}),
	},
	conditions = {
		PlaceObj('PlayerIsInSectors', {
			Sectors = {
				"B12",
				"B12_Underground",
			},
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_DieselClinic_05",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "DrGruselheim",
			'Text', T(819931890871, --[[BanterDef Gruselheim_Sanatorium_02 Text section:DLC_U-Bahn_Local/Gruselheim_Sanatorium_02 voice:DrGruselheim]] "I can handle the science, we already have a vaccine! But I can't handle people. How could they not care about their health?!"),
		}),
	},
	conditions = {
		PlaceObj('PlayerIsInSectors', {
			Sectors = {
				"H12",
				"H12_Underground",
			},
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_Sanatorium_02",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "DrGruselheim",
			'Text', T(808037963116, --[[BanterDef Gruselheim_Sanatorium_03 Text section:DLC_U-Bahn_Local/Gruselheim_Sanatorium_03 voice:DrGruselheim]] "People just refuse to vaccinate. I'm thinking of an ultimate solution based on aerosol formula that can be delivered by spraying from a plane."),
		}),
	},
	conditions = {
		PlaceObj('PlayerIsInSectors', {
			Sectors = {
				"H12",
				"H12_Underground",
			},
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_Sanatorium_03",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "DrGruselheim",
			'Text', T(676044642159, --[[BanterDef Gruselheim_Sanatorium_04 Text section:DLC_U-Bahn_Local/Gruselheim_Sanatorium_04 voice:DrGruselheim]] "The methods of Dr. Kronenberg have proven to be remarkably effective, especially considering her limited resources at the time."),
		}),
	},
	conditions = {
		PlaceObj('PlayerIsInSectors', {
			Sectors = {
				"H12",
				"H12_Underground",
			},
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_Sanatorium_04",
})

PlaceObj('BanterDef', {
	KillOnAnyActorAware = true,
	Lines = {
		PlaceObj('BanterLine', {
			'Character', "DrGruselheim",
			'Text', T(649260226885, --[[BanterDef Gruselheim_Sanatorium_06 Text section:DLC_U-Bahn_Local/Gruselheim_Sanatorium_06 voice:DrGruselheim]] "<em>Dr. Kronenberg's</em> medical proficiency is only matched by her people skills. Ach, the tricks she would come up with in order to convince people to take the shot!"),
		}),
	},
	conditions = {
		PlaceObj('PlayerIsInSectors', {
			Sectors = {
				"H12",
				"H12_Underground",
			},
		}),
		PlaceObj('QuestIsVariableBool', {
			QuestId = "Sanatorium",
			Vars = set({
	MangelKilled = false,
}),
			__eval = function ()
				local quest = gv_Quests['Sanatorium'] or QuestGetState('Sanatorium')
				return not quest.MangelKilled
			end,
		}),
	},
	disabledInConflict = true,
	group = "DLC_U-Bahn_Local",
	id = "Gruselheim_Sanatorium_06",
})

