-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('M41Shotgun')
DefineClass.M41Shotgun = {
	__parents = { "Shotgun" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Shotgun",
	ScrapParts = 10,
	RepairCost = 50,
	Reliability = 71,
	Icon = "UI/Icons/Weapons/M1014",
	DisplayName = T(194836117430, --[[InventoryItemCompositeDef M41Shotgun DisplayName]] "M1014"),
	DisplayNamePlural = T(503116404323, --[[InventoryItemCompositeDef M41Shotgun DisplayNamePlural]] "M1014s"),
	Description = T(767574925569, --[[InventoryItemCompositeDef M41Shotgun Description]] "12-gauge semi-auto slick Italian. Boasting little need for maintenance and high level of reliability, it is loved by law enforcement and military alike."),
	AdditionalHint = T(961473257481, --[[InventoryItemCompositeDef M41Shotgun AdditionalHint]] "<bullet_point> Longer range\n<bullet_point> Increased bonus from Aiming"),
	LargeItem = 1,
	UnitStat = "Marksmanship",
	Cost = 2700,
	CanAppearInShop = true,
	Tier = 2,
	CategoryPair = "Shotguns",
	Caliber = "12gauge",
	Damage = 32,
	ObjDamageMod = 150,
	AimAccuracy = 5,
	MagazineSize = 6,
	WeaponRange = 12,
	PointBlankBonus = 1,
	OverwatchAngle = 1200,
	BuckshotConeAngle = 1200,
	HandSlot = "TwoHanded",
	Entity = "Weapon_Benelli_M4",
	ComponentSlots = {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Barrel",
			'AvailableComponents', {
				"BarrelNormal",
				"BarrelShortShotgun_Benelli",
			},
			'DefaultComponent', "BarrelNormal",
		}),
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Scope",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"ScopeCOG",
				"LROptics",
				"ReflexSight",
				"ThermalScope",
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
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Muzzle",
			'CanBeEmpty', true,
			'AvailableComponents', {
				"Compensator",
			},
		}),
	},
	HolsterSlot = "Shoulder",
	AvailableAttacks = {
		"Buckshot",
		"CancelShotCone",
	},
	ShootAP = 5000,
	ReloadAP = 3000,
}

