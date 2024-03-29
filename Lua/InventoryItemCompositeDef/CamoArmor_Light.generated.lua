-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('CamoArmor_Light')
DefineClass.CamoArmor_Light = {
	__parents = { "Armor" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Armor",
	ScrapParts = 4,
	Degradation = 6,
	Icon = "UI/Icons/Items/camo_armor_light",
	DisplayName = T(623928157955, --[[InventoryItemCompositeDef CamoArmor_Light DisplayName]] "Light Camo Armor"),
	DisplayNamePlural = T(728180263372, --[[InventoryItemCompositeDef CamoArmor_Light DisplayNamePlural]] "Light Camo Armors"),
	AdditionalHint = T(990395288798, --[[InventoryItemCompositeDef CamoArmor_Light AdditionalHint]] "<bullet_point> Harder to detect by enemies\n<bullet_point> Aiming is less effective against camouflaged targets\n<bullet_point> Can't be combined with weave or ceramics"),
	Cost = 4500,
	CanAppearInShop = true,
	Tier = 2,
	MaxStock = 1,
	RestockWeight = 25,
	CategoryPair = "Light",
	PenetrationClass = 2,
	AdditionalReduction = 20,
	ProtectedBodyParts = set( "Torso" ),
	Camouflage = true,
}

