-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('_40mmFlashbangGrenade')
DefineClass._40mmFlashbangGrenade = {
	__parents = { "Ordnance" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Ordnance",
	Icon = "UI/Icons/Items/40mm_flashbang_grenade",
	DisplayName = T(805412560134, --[[InventoryItemCompositeDef _40mmFlashbangGrenade DisplayName]] "40 mm Flashbang"),
	DisplayNamePlural = T(753721174279, --[[InventoryItemCompositeDef _40mmFlashbangGrenade DisplayNamePlural]] "40 mm Flashbangs"),
	Description = T(637064167762, --[[InventoryItemCompositeDef _40mmFlashbangGrenade Description]] "40 mm ordnance ammo for Grenade Launchers."),
	AdditionalHint = T(222515823004, --[[InventoryItemCompositeDef _40mmFlashbangGrenade AdditionalHint]] "<bullet_point> Reduces target Energy in the epicenter (once per battle)\n<bullet_point> Inflicts <em>Suppressed</em>\n<bullet_point> Less noisy"),
	Cost = 400,
	CanAppearInShop = true,
	Tier = 2,
	MaxStock = 5,
	RestockWeight = 25,
	CategoryPair = "Ordnance",
	CenterUnitDamageMod = 130,
	CenterObjDamageMod = 10,
	CenterAppliedEffects = {
		"IncreaseTiredness",
		"Suppressed",
	},
	AreaObjDamageMod = 10,
	AreaAppliedEffects = {
		"Suppressed",
	},
	PenetrationClass = 1,
	BurnGround = false,
	Caliber = "40mmGrenade",
	BaseDamage = 5,
	Noise = 5,
	Entity = "Weapon_MilkorMGL_Shell",
}

