-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Quest - Weapons",
	'Id', "Galil_FlagHill",
	'Comment', "tier 4 heavy",
	'object_class', "AssaultRifle",
	'ScrapParts', 10,
	'RepairCost', 50,
	'Reliability', 77,
	'Icon', "UI/Icons/Weapons/Galil_Flaghill",
	'DisplayName', T(167758773926, --[[InventoryItemCompositeDef Galil_FlagHill DisplayName]] "The Hired Gun"),
	'DisplayNamePlural', T(887498877657, --[[InventoryItemCompositeDef Galil_FlagHill DisplayNamePlural]] "The Hired Guns"),
	'Description', T(503430285250, --[[InventoryItemCompositeDef Galil_FlagHill Description]] "Mercenary contract termination tool."),
	'AdditionalHint', T(112848820358, --[[InventoryItemCompositeDef Galil_FlagHill AdditionalHint]] "<bullet_point> Awesome Crit chance\n<bullet_point> Longer range"),
	'LargeItem', 1,
	'UnitStat', "Marksmanship",
	'Valuable', 1,
	'Cost', 2500,
	'Caliber', "762NATO",
	'Damage', 26,
	'CritChanceScaled', 50,
	'MagazineSize', 30,
	'PenetrationClass', 2,
	'WeaponRange', 30,
	'OverwatchAngle', 1440,
	'HandSlot', "TwoHanded",
	'Entity', "Weapon_Galil",
	'ComponentSlots', {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Barrel",
			'Modifiable', false,
			'AvailableComponents', {
				"BarrelNormal",
			},
			'DefaultComponent', "BarrelNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Stock",
			'Modifiable', false,
			'AvailableComponents', {
				"StockNormal",
			},
			'DefaultComponent', "StockNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'Modifiable', false,
			'AvailableComponents', {
				"MuzzleBooster",
			},
			'DefaultComponent', "MuzzleBooster",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Under",
			'Modifiable', false,
			'AvailableComponents', {
				"Bipod_Galil",
			},
			'DefaultComponent', "Bipod_Galil",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Scope",
			'Modifiable', false,
			'AvailableComponents', {
				"ReflexSightAdvanced",
			},
			'DefaultComponent', "ReflexSightAdvanced",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Magazine",
			'Modifiable', false,
			'AvailableComponents', {
				"MagNormal",
			},
			'DefaultComponent', "MagNormal",
		}),
	},
	'HolsterSlot', "Shoulder",
	'AvailableAttacks', {
		"BurstFire",
		"AutoFire",
		"SingleShot",
		"CancelShot",
	},
	'ShootAP', 6000,
	'ReloadAP', 3000,
})
