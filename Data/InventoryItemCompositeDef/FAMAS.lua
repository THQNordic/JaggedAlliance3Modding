-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Firearm - Assault",
	'Id', "FAMAS",
	'Comment', "tier 1 light",
	'object_class', "AssaultRifle",
	'ScrapParts', 10,
	'Reliability', 70,
	'Icon', "UI/Icons/Weapons/FAMAS",
	'DisplayName', T(535915752603, --[[InventoryItemCompositeDef FAMAS DisplayName]] "FAMAS"),
	'DisplayNamePlural', T(468242262916, --[[InventoryItemCompositeDef FAMAS DisplayNamePlural]] "FAMAS's"),
	'Description', T(782243912175, --[[InventoryItemCompositeDef FAMAS Description]] "Bullpup design with utility and ergonomics in mind. The magazines were designed to be single-use and disposable. But no design survives contact with reality - soldiers started reusing them and running into all sorts of problems. A durable mag was later introduced. "),
	'AdditionalHint', T(313092155901, --[[InventoryItemCompositeDef FAMAS AdditionalHint]] "<bullet_point> Low damage\n<bullet_point> Increased bonus from Aiming\n<bullet_point> Low attack costs\n<bullet_point> Increased Reload cost\n<bullet_point> Less noisy"),
	'LargeItem', 1,
	'UnitStat', "Marksmanship",
	'Cost', 2500,
	'CanAppearInShop', true,
	'CategoryPair', "AssaultRifles",
	'Caliber', "556",
	'Damage', 16,
	'AimAccuracy', 4,
	'MagazineSize', 25,
	'PenetrationClass', 2,
	'WeaponRange', 24,
	'OverwatchAngle', 1440,
	'Noise', 10,
	'HandSlot', "TwoHanded",
	'Entity', "Weapon_FAMAS",
	'ComponentSlots', {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Under",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"VerticalGrip",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Bipod",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Bipod",
			},
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
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Scope",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"LROptics",
				"ReflexSight",
				"ScopeCOGQuick",
				"ScopeCOG",
				"ThermalScope",
			},
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'AvailableComponents', {
				"Compensator",
				"Suppressor",
				"ImprovisedSuppressor",
			},
			'DefaultComponent', "Compensator",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Magazine",
			'Modifiable', false,
			'CanBeEmpty', true,
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
	'ShootAP', 5000,
	'ReloadAP', 4000,
})

