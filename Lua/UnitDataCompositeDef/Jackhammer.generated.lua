-- ========== GENERATED BY UnitDataCompositeDef Editor (Ctrl-Alt-M) DO NOT EDIT MANUALLY! ==========

UndefineClass('Jackhammer')
DefineClass.Jackhammer = {
	__parents = { "UnitData" },
	__generated_by_class = "UnitDataCompositeDef",


	object_class = "UnitData",
	Health = 95,
	Agility = 90,
	Dexterity = 70,
	Strength = 90,
	Wisdom = 80,
	Marksmanship = 88,
	Mechanical = 30,
	Explosives = 0,
	Medical = 0,
	Portrait = "UI/NPCsPortraits/Jackhammer",
	BigPortrait = "UI/NPCs/Jackhammer",
	Name = T(869890661830, --[[UnitDataCompositeDef Jackhammer Name]] "Jackhammer"),
	Randomization = true,
	Affiliation = "Legion",
	StartingLevel = 7,
	ImportantNPC = true,
	villain = true,
	neutral_retaliate = true,
	role = "Commander",
	MaxAttacks = 2,
	Lives = 1,
	DefeatBehavior = "Defeated",
	RetreatBehavior = "None",
	StartingPerks = {
		"BeefedUp",
		"BattleFocus",
		"Shatterhand",
		"InstantAutopsy",
		"Deadeye",
		"AutoWeapons",
		"CQCTraining",
		"Ironclad",
	},
	AppearancesList = {
		PlaceObj('AppearanceWeight', {
			'Preset', "Jackhammer",
		}),
	},
	Equipment = {
		"Jackhammer",
	},
	gender = "Male",
	PersistentSessionId = "NPC_Jackhammer",
	VoiceResponseId = "Jackhammer",
}

