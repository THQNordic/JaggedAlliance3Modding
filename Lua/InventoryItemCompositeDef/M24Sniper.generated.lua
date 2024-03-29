-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('M24Sniper')
DefineClass.M24Sniper = {
	__parents = { "SniperRifle" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "SniperRifle",
	ScrapParts = 14,
	Reliability = 44,
	Icon = "UI/Icons/Weapons/M24",
	DisplayName = T(672666400702, --[[InventoryItemCompositeDef M24Sniper DisplayName]] "M24"),
	DisplayNamePlural = T(703533260621, --[[InventoryItemCompositeDef M24Sniper DisplayNamePlural]] "M24s"),
	Description = T(767131106202, --[[InventoryItemCompositeDef M24Sniper Description]] "US Army sniper weapon system that replaced the M21 (based on the M14). Apparently semi-auto was still not up to par with what snipers needed in terms of reliability and accuracy that bolt action can provide. "),
	AdditionalHint = T(622433882128, --[[InventoryItemCompositeDef M24Sniper AdditionalHint]] "<bullet_point> Cumbersome (no Free Move)\n<bullet_point> Very noisy"),
	LargeItem = 1,
	Cumbersome = 1,
	UnitStat = "Marksmanship",
	Cost = 2500,
	CanAppearInShop = true,
	Tier = 2,
	CategoryPair = "Rifles",
	Caliber = "762NATO",
	Damage = 46,
	AimAccuracy = 5,
	MagazineSize = 5,
	PenetrationClass = 2,
	WeaponRange = 36,
	OverwatchAngle = 360,
	Noise = 30,
	HandSlot = "TwoHanded",
	Entity = "Weapon_M24",
	ComponentSlots = {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Stock",
			'AvailableComponents', {
				"StockHeavy",
				"StockLight",
				"StockNormal",
			},
			'DefaultComponent', "StockNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Bipod",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Bipod",
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
			'SlotType', "Scope",
			'AvailableComponents', {
				"LROptics",
				"LROpticsAdvanced",
				"ReflexSight",
				"ScopeCOG",
				"ThermalScope",
			},
			'DefaultComponent', "LROptics",
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
				"Flashlight",
				"FlashlightDot",
				"LaserDot",
				"UVDot",
			},
		}),
	},
	HolsterSlot = "Shoulder",
	PreparedAttackType = "Both",
	AvailableAttacks = {
		"SingleShot",
		"CancelShot",
	},
	ShootAP = 8000,
	ReloadAP = 3000,
}

