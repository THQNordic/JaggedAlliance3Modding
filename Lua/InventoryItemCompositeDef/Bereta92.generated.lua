-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('Bereta92')
DefineClass.Bereta92 = {
	__parents = { "Pistol" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Pistol",
	ScrapParts = 6,
	RepairCost = 70,
	Reliability = 20,
	Icon = "UI/Icons/Weapons/Beretta92F",
	DisplayName = T(913137394341, --[[InventoryItemCompositeDef Bereta92 DisplayName]] "Beretta 92F"),
	DisplayNamePlural = T(134586456394, --[[InventoryItemCompositeDef Bereta92 DisplayNamePlural]] "Beretta 92Fs"),
	Description = T(474903442437, --[[InventoryItemCompositeDef Bereta92 Description]] "The weapon that replaced the iconic 1911. Tough act to follow but the slick Italian manages to impress. "),
	AdditionalHint = T(997833648446, --[[InventoryItemCompositeDef Bereta92 AdditionalHint]] "<bullet_point> High Crit chance\n<bullet_point> Increased bonus from Aiming\n<bullet_point> Less noisy"),
	UnitStat = "Marksmanship",
	Cost = 700,
	CanAppearInShop = true,
	CategoryPair = "Handguns",
	Caliber = "9mm",
	Damage = 15,
	AimAccuracy = 6,
	CritChanceScaled = 30,
	MagazineSize = 15,
	WeaponRange = 14,
	PointBlankBonus = 1,
	OverwatchAngle = 2160,
	Noise = 10,
	Entity = "Weapon_Beretta92F",
	ComponentSlots = {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Scope",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"ReflexSight",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"ImprovisedSuppressor",
				"Suppressor",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Magazine",
			'AvailableComponents', {
				"MagLarge",
				"MagNormal",
			},
			'DefaultComponent', "MagNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Barrel",
			'AvailableComponents', {
				"BarrelLong",
				"BarrelNormal",
			},
			'DefaultComponent', "BarrelNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Side",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Flashlight",
				"LaserDot",
				"FlashlightDot",
			},
		}),
	},
	HolsterSlot = "Leg",
	AvailableAttacks = {
		"SingleShot",
		"DualShot",
		"CancelShot",
		"MobileShot",
	},
	ShootAP = 5000,
	ReloadAP = 3000,
}

