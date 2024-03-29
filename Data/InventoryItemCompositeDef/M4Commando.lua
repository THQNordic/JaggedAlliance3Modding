-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Firearm - SMG",
	'Id', "M4Commando",
	'Comment', "tier 5",
	'object_class', "SubmachineGun",
	'ScrapParts', 10,
	'Reliability', 80,
	'Icon', "UI/Icons/Weapons/Commando",
	'DisplayName', T(106857539418, --[[InventoryItemCompositeDef M4Commando DisplayName]] "Commando"),
	'DisplayNamePlural', T(434250307019, --[[InventoryItemCompositeDef M4Commando DisplayNamePlural]] "Commandos"),
	'Description', T(346391822201, --[[InventoryItemCompositeDef M4Commando Description]] "How would you make a short barrel M16 work? Answer - lower muzzle velocity and huge muzzle flash."),
	'AdditionalHint', T(679443019604, --[[InventoryItemCompositeDef M4Commando AdditionalHint]] "<bullet_point> High Crit chance\n<bullet_point> Increased bonus from Aiming"),
	'LargeItem', 1,
	'UnitStat', "Marksmanship",
	'Valuable', 1,
	'Cost', 8700,
	'CanAppearInShop', true,
	'Tier', 3,
	'RestockWeight', 40,
	'CategoryPair', "SubmachineGuns",
	'Caliber', "556",
	'Damage', 17,
	'AimAccuracy', 4,
	'CritChanceScaled', 30,
	'MagazineSize', 30,
	'PenetrationClass', 2,
	'PointBlankBonus', 1,
	'OverwatchAngle', 1440,
	'Noise', 15,
	'HandSlot', "TwoHanded",
	'Entity', "Weapon_CAR15",
	'ComponentSlots', {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Under",
			'AvailableComponents', {
				"Handguard_Commando",
				"VerticalGrip_Commando",
				"GrenadeLauncher_Commando",
			},
			'DefaultComponent', "Handguard_Commando",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Magazine",
			'AvailableComponents', {
				"MagNormal",
				"MagNormalFine",
				"MagLarge",
				"MagLargeFine",
				"MagQuick",
			},
			'DefaultComponent', "MagNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Stock",
			'AvailableComponents', {
				"StockNormal",
				"StockLight",
			},
			'DefaultComponent', "StockNormal",
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
				"LROptics",
				"ReflexSight",
				"ScopeCOG",
				"ThermalScope",
				"ReflexSightAdvanced",
				"ScopeCOGQuick",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Compensator",
				"MuzzleBooster",
				"Suppressor",
				"ImprovisedSuppressor",
			},
			'DefaultComponent', "Compensator",
		}),
	},
	'HolsterSlot', "Shoulder",
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

