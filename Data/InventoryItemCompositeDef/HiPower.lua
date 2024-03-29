-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Firearm - Handgun",
	'Id', "HiPower",
	'Comment', "tier 1",
	'object_class', "Pistol",
	'ScrapParts', 6,
	'RepairCost', 70,
	'Reliability', 50,
	'Icon', "UI/Icons/Weapons/Browning HiPower",
	'DisplayName', T(796605924344, --[[InventoryItemCompositeDef HiPower DisplayName]] "Hi-Power"),
	'DisplayNamePlural', T(376748831554, --[[InventoryItemCompositeDef HiPower DisplayNamePlural]] "Hi-Powers"),
	'Description', T(718446064072, --[[InventoryItemCompositeDef HiPower Description]] "Used by both the Nazis and Allies during WWII. The hammer has a tendency to bite. "),
	'AdditionalHint', T(583470356503, --[[InventoryItemCompositeDef HiPower AdditionalHint]] "<bullet_point> High damage\n<bullet_point> Decreased bonus from Aiming\n<bullet_point> Limited customization options"),
	'UnitStat', "Marksmanship",
	'Cost', 500,
	'CanAppearInShop', true,
	'CategoryPair', "Handguns",
	'CanAppearStandard', false,
	'Caliber', "9mm",
	'Damage', 18,
	'MagazineSize', 15,
	'WeaponRange', 14,
	'PointBlankBonus', 1,
	'OverwatchAngle', 2160,
	'Entity', "Weapon_Browning_HP",
	'ComponentSlots', {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"ImprovisedSuppressor",
				"Suppressor",
				"Compensator",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Magazine",
			'AvailableComponents', {
				"MagLarge",
				"MagNormal",
				"MagLargeFine",
				"MagNormalFine",
			},
			'DefaultComponent', "MagNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Barrel",
			'AvailableComponents', {
				"BarrelNormal",
				"BarrelNormalImproved",
				"BarrelShort",
				"BarrelShortImproved",
				"BarrelLong",
				"BarrelLongImproved",
			},
			'DefaultComponent', "BarrelNormal",
		}),
	},
	'HolsterSlot', "Leg",
	'AvailableAttacks', {
		"SingleShot",
		"DualShot",
		"CancelShot",
		"MobileShot",
	},
	'ShootAP', 5000,
	'ReloadAP', 3000,
})

