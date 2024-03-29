-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('DoubleBarrelShotgun')
DefineClass.DoubleBarrelShotgun = {
	__parents = { "Shotgun" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Shotgun",
	ScrapParts = 8,
	RepairCost = 50,
	Reliability = 50,
	Icon = "UI/Icons/Weapons/Double-barrelled Shotgun",
	DisplayName = T(354097123587, --[[InventoryItemCompositeDef DoubleBarrelShotgun DisplayName]] "Double-Barrel"),
	DisplayNamePlural = T(178360690641, --[[InventoryItemCompositeDef DoubleBarrelShotgun DisplayNamePlural]] "Double-Barrels"),
	Description = T(563332952231, --[[InventoryItemCompositeDef DoubleBarrelShotgun Description]] "A simple hunting weapon. Fancier combat shotguns can shoot semi and fully automatic but only the double-barrel can shoot two shells at once. "),
	AdditionalHint = T(345329597555, --[[InventoryItemCompositeDef DoubleBarrelShotgun AdditionalHint]] "<bullet_point> High Crit chance\n<bullet_point> Limited ammo capacity\n<bullet_point> Greatly decreased bonus from Aiming\n<bullet_point> Special firing mode: Double Barrel"),
	LargeItem = 1,
	UnitStat = "Marksmanship",
	Cost = 700,
	CanAppearInShop = true,
	MaxStock = 5,
	RestockWeight = 120,
	CategoryPair = "Shotguns",
	Caliber = "12gauge",
	Damage = 28,
	ObjDamageMod = 150,
	AimAccuracy = 1,
	CritChanceScaled = 30,
	MagazineSize = 2,
	WeaponRange = 8,
	PointBlankBonus = 1,
	OverwatchAngle = 1200,
	BuckshotConeAngle = 1200,
	HandSlot = "TwoHanded",
	Entity = "Weapon_DBShotgun",
	ComponentSlots = {
		PlaceObj('WeaponComponentSlot', {
			'SlotType', "Barrel",
			'AvailableComponents', {
				"BarrelLongShotgun",
				"BarrelNormal",
				"BarrelShortShotgun",
			},
			'DefaultComponent', "BarrelNormal",
		}),
	},
	HolsterSlot = "Shoulder",
	ModifyRightHandGrip = true,
	AvailableAttacks = {
		"Buckshot",
		"DoubleBarrel",
		"CancelShotCone",
	},
	ShootAP = 5000,
	ReloadAP = 3000,
}

