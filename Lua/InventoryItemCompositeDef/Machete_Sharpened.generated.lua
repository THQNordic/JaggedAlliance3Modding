-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('Machete_Sharpened')
DefineClass.Machete_Sharpened = {
	__parents = { "MacheteWeapon" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "MacheteWeapon",
	ScrapParts = 2,
	Reliability = 50,
	Icon = "UI/Icons/Weapons/Machete",
	SubIcon = "UI/Icons/Weapons/sharpened",
	DisplayName = T(304405191155, --[[InventoryItemCompositeDef Machete_Sharpened DisplayName]] "Sharpened Machete"),
	DisplayNamePlural = T(403544043005, --[[InventoryItemCompositeDef Machete_Sharpened DisplayNamePlural]] "Sharpened Machetes"),
	Description = T(652975152618, --[[InventoryItemCompositeDef Machete_Sharpened Description]] "This blade can be your best tool for navigating the jungle and handling what's in it."),
	AdditionalHint = T(651122664679, --[[InventoryItemCompositeDef Machete_Sharpened AdditionalHint]] "<bullet_point> Increased damage bonus from Strength\n<bullet_point> Sharpened - high damage"),
	LargeItem = 1,
	UnitStat = "Dexterity",
	Cost = 1300,
	CanAppearInShop = true,
	Tier = 3,
	MaxStock = 2,
	RestockWeight = 15,
	CategoryPair = "MeleeWeapons",
	BaseChanceToHit = 100,
	BaseDamage = 24,
	AimAccuracy = 15,
	PenetrationClass = 4,
	DamageMultiplier = 150,
	WeaponRange = 0,
	Charge = true,
	AttackAP = 4000,
	MaxAimActions = 1,
	Noise = 1,
	NeckAttackType = "lethal",
	Entity = "Weapon_Machete_03",
	HolsterSlot = "Shoulder",
	CanAppearUsed = false,
}

