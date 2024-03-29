-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('Warhead_Frag')
DefineClass.Warhead_Frag = {
	__parents = { "Ordnance" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Ordnance",
	Icon = "UI/Icons/Items/warhead_frag",
	DisplayName = T(341598730187, --[[InventoryItemCompositeDef Warhead_Frag DisplayName]] "HE Rocket"),
	DisplayNamePlural = T(736624913078, --[[InventoryItemCompositeDef Warhead_Frag DisplayNamePlural]] "HE Rockets"),
	Description = T(604680579328, --[[InventoryItemCompositeDef Warhead_Frag Description]] "Ordnance ammo for Rocket Launchers."),
	AdditionalHint = T(699837764540, --[[InventoryItemCompositeDef Warhead_Frag AdditionalHint]] "<bullet_point> Inflicts Suppressed in the epicenter"),
	Cost = 400,
	CanAppearInShop = true,
	Tier = 3,
	MaxStock = 5,
	RestockWeight = 50,
	CategoryPair = "Ordnance",
	CenterUnitDamageMod = 130,
	CenterObjDamageMod = 500,
	CenterAppliedEffects = {
		"Suppressed",
	},
	AreaOfEffect = 2,
	AreaObjDamageMod = 500,
	DeathType = "BlowUp",
	Caliber = "Warhead",
	BaseDamage = 50,
	Noise = 30,
}

