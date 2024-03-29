-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('PipeBomb')
DefineClass.PipeBomb = {
	__parents = { "ThrowableTrapItem" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "ThrowableTrapItem",
	Repairable = false,
	Reliability = 100,
	Icon = "UI/Icons/Weapons/PipeBomb",
	ItemType = "Grenade",
	DisplayName = T(642346688869, --[[InventoryItemCompositeDef PipeBomb DisplayName]] "Pipe Bomb"),
	DisplayNamePlural = T(494920208733, --[[InventoryItemCompositeDef PipeBomb DisplayNamePlural]] "Pipe Bombs"),
	AdditionalHint = T(155469163103, --[[InventoryItemCompositeDef PipeBomb AdditionalHint]] "<bullet_point> Explodes after 1 turn (or 5 seconds out of combat)\n<bullet_point> High mishap chance\n<bullet_point> Inflicts Bleeding"),
	UnitStat = "Explosives",
	Cost = 100,
	CanAppearInShop = true,
	RestockWeight = 50,
	CategoryPair = "Grenade",
	MinMishapChance = 2,
	MaxMishapChance = 30,
	MaxMishapRange = 6,
	CenterUnitDamageMod = 130,
	CenterAppliedEffects = {
		"Bleeding",
	},
	AttackAP = 3000,
	BaseRange = 3,
	ThrowMaxRange = 12,
	Entity = "Explosive_TNT",
	ActionIcon = "UI/Icons/Hud/pipe_bomb",
	TriggerType = "Timed",
	ExplosiveType = "BlackPowder",
}

