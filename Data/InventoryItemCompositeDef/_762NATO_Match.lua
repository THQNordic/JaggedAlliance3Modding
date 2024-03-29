-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Ammo",
	'Id', "_762NATO_Match",
	'object_class', "Ammo",
	'Icon', "UI/Icons/Items/762_nato_bullets_match",
	'DisplayName', T(519353641191, --[[InventoryItemCompositeDef _762NATO_Match DisplayName]] "7.62 mm NATO Match"),
	'DisplayNamePlural', T(900333933922, --[[InventoryItemCompositeDef _762NATO_Match DisplayNamePlural]] "7.62 mm NATO Match"),
	'colorStyle', "AmmoMatchColor",
	'Description', T(411071812202, --[[InventoryItemCompositeDef _762NATO_Match Description]] "7.62 NATO ammo for Assault Rifles, Rifles, and Machine Guns."),
	'AdditionalHint', T(898089454154, --[[InventoryItemCompositeDef _762NATO_Match AdditionalHint]] "<bullet_point> Increased bonus from Aiming"),
	'Cost', 200,
	'CanAppearInShop', true,
	'Tier', 3,
	'MaxStock', 5,
	'RestockWeight', 25,
	'CategoryPair', "762NATO",
	'ShopStackSize', 30,
	'MaxStacks', 500,
	'Caliber', "762NATO",
	'Modifications', {
		PlaceObj('CaliberModification', {
			mod_add = 2,
			target_prop = "AimAccuracy",
		}),
	},
	'ammo_type_icon', "UI/Icons/Items/ta_match.png",
})

