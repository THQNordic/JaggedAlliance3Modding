-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('HeavyArmorTorso')
DefineClass.HeavyArmorTorso = {
	__parents = { "Armor" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Armor",
	ScrapParts = 4,
	Degradation = 6,
	Icon = "UI/Icons/Items/heavy_armor",
	DisplayName = T(269180326225, --[[InventoryItemCompositeDef HeavyArmorTorso DisplayName]] "Heavy Armor"),
	DisplayNamePlural = T(167239210459, --[[InventoryItemCompositeDef HeavyArmorTorso DisplayNamePlural]] "Heavy Armors"),
	AdditionalHint = T(243929025325, --[[InventoryItemCompositeDef HeavyArmorTorso AdditionalHint]] "<bullet_point> Cumbersome (no Free Move)"),
	Cumbersome = 1,
	Valuable = 1,
	Cost = 5500,
	CanAppearInShop = true,
	Tier = 2,
	MaxStock = 2,
	RestockWeight = 50,
	CategoryPair = "Heavy",
	PenetrationClass = 4,
	AdditionalReduction = 40,
	ProtectedBodyParts = set( "Arms", "Torso" ),
}

