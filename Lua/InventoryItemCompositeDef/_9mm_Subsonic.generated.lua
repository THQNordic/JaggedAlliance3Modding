-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('_9mm_Subsonic')
DefineClass._9mm_Subsonic = {
	__parents = { "Ammo" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "Ammo",
	Icon = "UI/Icons/Items/9mm_bullets_subsonic",
	DisplayName = T(416825324724, --[[InventoryItemCompositeDef _9mm_Subsonic DisplayName]] "9 mm Subsonic"),
	DisplayNamePlural = T(676522769844, --[[InventoryItemCompositeDef _9mm_Subsonic DisplayNamePlural]] "9 mm Subsonic"),
	colorStyle = "AmmoMatchColor",
	Description = T(571319448676, --[[InventoryItemCompositeDef _9mm_Subsonic Description]] "9 mm ammo for Handguns and SMGs."),
	AdditionalHint = T(368177980365, --[[InventoryItemCompositeDef _9mm_Subsonic AdditionalHint]] "<bullet_point> Less noisy"),
	Cost = 45,
	CanAppearInShop = true,
	Tier = 3,
	MaxStock = 5,
	RestockWeight = 25,
	CategoryPair = "9mm",
	ShopStackSize = 30,
	MaxStacks = 500,
	Caliber = "9mm",
	Modifications = {
		PlaceObj('CaliberModification', {
			mod_mul = 500,
			target_prop = "Noise",
		}),
	},
}

