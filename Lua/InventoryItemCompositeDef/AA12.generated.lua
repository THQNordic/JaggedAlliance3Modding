-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('AA12')
DefineClass.AA12 = {
	__parents = { "Shotgun" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Shotgun",
	ScrapParts = 12,
	RepairCost = 50,
	Reliability = 80,
	Icon = "UI/Icons/Weapons/AA12",
	DisplayName = T(845020864842, --[[InventoryItemCompositeDef AA12 DisplayName]] "AA12"),
	DisplayNamePlural = T(738216506503, --[[InventoryItemCompositeDef AA12 DisplayNamePlural]] "AA12s"),
	Description = T(553979887379, --[[InventoryItemCompositeDef AA12 Description]] "Firing from an open bolt, the AA12 has more similarity with some machine guns than with other shotguns. Boasting reduced recoil for a 12-gauge round, it is made for sustained fire."),
	AdditionalHint = T(721901751495, --[[InventoryItemCompositeDef AA12 AdditionalHint]] "<bullet_point> Decreased bonus from Aiming\n<bullet_point> Special firing mode: Buckshot Burst"),
	LargeItem = 1,
	UnitStat = "Marksmanship",
	Valuable = 1,
	Cost = 5200,
	CanAppearInShop = true,
	Tier = 3,
	CategoryPair = "Shotguns",
	Caliber = "12gauge",
	Damage = 26,
	ObjDamageMod = 150,
	MagazineSize = 15,
	WeaponRange = 8,
	PointBlankBonus = 1,
	OverwatchAngle = 1200,
	BuckshotConeAngle = 1200,
	HandSlot = "TwoHanded",
	Entity = "Weapon_AA12",
	ComponentSlots = {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Barrel",
			'AvailableComponents', {
				"BarrelNormal",
				"BarrelLongShotgun",
			},
			'DefaultComponent', "BarrelNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Magazine",
			'AvailableComponents', {
				"MagNormal",
				"MagLarge",
			},
			'DefaultComponent', "MagNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Scope",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"ReflexSight",
				"ReflexSightAdvanced",
				"ScopeCOGQuick",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Side",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Flashlight_aa12",
				"LaserDot_aa12",
				"FlashlightDot_aa12",
				"UVDot_aa12",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Suppressor",
				"Compensator",
			},
		}),
	},
	HolsterSlot = "Shoulder",
	AvailableAttacks = {
		"BuckshotBurst",
		"Buckshot",
		"CancelShotCone",
	},
	ShootAP = 5000,
	ReloadAP = 3000,
}

