-- ========== GENERATED BY UnitDataCompositeDef Editor (Ctrl-Alt-M) DO NOT EDIT MANUALLY! ==========

UndefineClass('EraserHead')
DefineClass.EraserHead = {
	__parents = { "UnitData" },
	__generated_by_class = "UnitDataCompositeDef",


	object_class = "UnitData",
	Agility = 100,
	Dexterity = 100,
	Strength = 70,
	Wisdom = 50,
	Leadership = 35,
	Marksmanship = 55,
	Mechanical = 25,
	Explosives = 20,
	Medical = 0,
	Name = T(490563359915, --[[UnitDataCompositeDef EraserHead Name]] "Eraser Head"),
	Affiliation = "Other",
	StartingLevel = 5,
	neutral_retaliate = true,
	archetype = "Brute",
	MaxAttacks = 1,
	StartingPerks = {
		"ColdHeart",
		"BloodScent",
	},
	AppearancesList = {
		PlaceObj('AppearanceWeight', {
			'Preset', "EraserHead",
		}),
	},
	Equipment = {
		"Civilian_Unarmed",
	},
	pollyvoice = "Russell",
	gender = "Male",
	PersistentSessionId = "NPC_EraserHead",
}

