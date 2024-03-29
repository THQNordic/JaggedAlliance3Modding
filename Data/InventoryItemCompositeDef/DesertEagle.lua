-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Firearm - Handgun",
	'Id', "DesertEagle",
	'Comment', "tier 5",
	'object_class', "Pistol",
	'ScrapParts', 10,
	'RepairCost', 70,
	'Reliability', 20,
	'Icon', "UI/Icons/Weapons/DesertEagle",
	'DisplayName', T(275314808651, --[[InventoryItemCompositeDef DesertEagle DisplayName]] "Desert Eagle"),
	'DisplayNamePlural', T(975125699386, --[[InventoryItemCompositeDef DesertEagle DisplayNamePlural]] "Desert Eagles"),
	'Description', T(587004777006, --[[InventoryItemCompositeDef DesertEagle Description]] "Everybody knows the Desert Eagle as a .50 caliber hand cannon but the .44 barrel can make it much more practical and affordable to shoot. "),
	'AdditionalHint', T(883485222965, --[[InventoryItemCompositeDef DesertEagle AdditionalHint]] "<bullet_point> High damage\n<bullet_point> Improved armor penetration\n<bullet_point> Shorter range\n<bullet_point> Very noisy"),
	'UnitStat', "Marksmanship",
	'Valuable', 1,
	'Cost', 4800,
	'CanAppearInShop', true,
	'Tier', 3,
	'CategoryPair', "Handguns",
	'Caliber', "44CAL",
	'Damage', 30,
	'ObjDamageMod', 200,
	'AimAccuracy', 3,
	'MagazineSize', 15,
	'PenetrationClass', 2,
	'WeaponRange', 12,
	'PointBlankBonus', 1,
	'OverwatchAngle', 2160,
	'Entity', "Weapon_DesertEagle",
	'ComponentSlots', {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Scope",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"ReflexSight",
				"ReflexSightAdvanced",
				"ImprovedIronsight",
			},
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
			'SlotType', "Barrel",
			'AvailableComponents', {
				"BarrelLong",
				"BarrelNormal",
				"Barrel50BMG_DesertEagle",
			},
			'DefaultComponent', "BarrelNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Suppressor",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Side",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"FlashlightDot",
				"Flashlight",
				"LaserDot",
				"UVDot",
			},
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

