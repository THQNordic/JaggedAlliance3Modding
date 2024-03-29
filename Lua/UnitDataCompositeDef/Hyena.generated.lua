-- ========== GENERATED BY UnitDataCompositeDef Editor (Ctrl-Alt-M) DO NOT EDIT MANUALLY! ==========

UndefineClass('Hyena')
DefineClass.Hyena = {
	__parents = { "UnitData" },
	__generated_by_class = "UnitDataCompositeDef",


	object_class = "UnitData",
	Health = 69,
	Agility = 78,
	Dexterity = 83,
	Strength = 50,
	Wisdom = 50,
	Marksmanship = 78,
	Mechanical = 15,
	Explosives = 0,
	Medical = 15,
	Portrait = "UI/NPCsPortraits/HyenaGilbert",
	BigPortrait = "UI/NPCs/HyenaGilbert",
	Name = T(704953525085, --[[UnitDataCompositeDef Hyena Name]] '"Hyena" Gilbert'),
	Randomization = true,
	Affiliation = "Other",
	ImportantNPC = true,
	neutral_retaliate = true,
	AIKeywords = {
		"Sniper",
	},
	role = "Marksman",
	CanManEmplacements = false,
	AlwaysUseOpeningAttack = true,
	OpeningAttackType = "PinDown",
	PinnedDownChance = 100,
	MaxAttacks = 2,
	RewardExperience = 0,
	MaxHitPoints = 60,
	AppearancesList = {
		PlaceObj('AppearanceWeight', {
			'Preset', "Hyena",
		}),
	},
	Equipment = {
		"HyenaNPC",
	},
	gender = "Male",
}

