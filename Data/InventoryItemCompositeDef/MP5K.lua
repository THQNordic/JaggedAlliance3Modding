-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Firearm - SMG",
	'Id', "MP5K",
	'Comment', "tier 3 subvariant",
	'object_class', "SubmachineGun",
	'ScrapParts', 8,
	'Reliability', 85,
	'Icon', "UI/Icons/Weapons/MP5K",
	'DisplayName', T(271982946642, --[[InventoryItemCompositeDef MP5K DisplayName]] "MP5K"),
	'DisplayNamePlural', T(879832194807, --[[InventoryItemCompositeDef MP5K DisplayNamePlural]] "MP5Ks"),
	'Description', T(254086057863, --[[InventoryItemCompositeDef MP5K Description]] "Brutally short MP5 designed for close quarters engagements and personal defense. There is even a suitcase with a trigger on the handle for covert escort jobs."),
	'AdditionalHint', T(261800415516, --[[InventoryItemCompositeDef MP5K AdditionalHint]] "<bullet_point> Increased bonus from Aiming\n<bullet_point> Less noisy"),
	'LargeItem', 1,
	'UnitStat', "Marksmanship",
	'Cost', 2800,
	'CanAppearInShop', true,
	'Tier', 2,
	'RestockWeight', 40,
	'CategoryPair', "SubmachineGuns",
	'Caliber', "9mm",
	'Damage', 16,
	'AimAccuracy', 5,
	'MagazineSize', 30,
	'PointBlankBonus', 1,
	'OverwatchAngle', 1440,
	'Noise', 10,
	'HandSlot', "TwoHanded",
	'Entity', "Weapon_MP5",
	'ComponentSlots', {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Under",
			'AvailableComponents', {
				"VerticalGrip",
			},
			'DefaultComponent', "VerticalGrip",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Barrel",
			'AvailableComponents', {
				"BarrelShort",
			},
			'DefaultComponent', "BarrelShort",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Magazine",
			'AvailableComponents', {
				"MagNormal",
				"MagLarge",
				"MagQuick",
			},
			'DefaultComponent', "MagNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Stock",
			'AvailableComponents', {
				"StockNormal",
				"StockHeavy",
				"StockNo",
			},
			'DefaultComponent', "StockNo",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Side",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Flashlight",
				"LaserDot",
				"FlashlightDot",
				"UVDot",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Scope",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"ReflexSight",
				"ReflexSightAdvanced",
				"ScopeCOG",
				"ScopeCOGQuick",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Compensator",
				"Suppressor",
				"ImprovisedSuppressor",
			},
		}),
	},
	'HolsterSlot', "Leg",
	'AvailableAttacks', {
		"BurstFire",
		"AutoFire",
		"SingleShot",
		"RunAndGun",
		"CancelShot",
	},
	'ShootAP', 5000,
	'ReloadAP', 3000,
})

