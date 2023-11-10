-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Ammo",
	'Id', "_762NATO_AP",
	'object_class', "Ammo",
	'Icon', "UI/Icons/Items/762_nato_bullets_armor_piercing",
	'DisplayName', T(451239732490, --[[InventoryItemCompositeDef _762NATO_AP DisplayName]] "7.62 mm NATO Armor Piercing"),
	'DisplayNamePlural', T(987128655410, --[[InventoryItemCompositeDef _762NATO_AP DisplayNamePlural]] "7.62 mm NATO Armor Piercing"),
	'colorStyle', "AmmoAPColor",
	'Description', T(241536180521, --[[InventoryItemCompositeDef _762NATO_AP Description]] "7.62 NATO ammo for Assault Rifles, Rifles, and Machine Guns."),
	'AdditionalHint', T(850324784601, --[[InventoryItemCompositeDef _762NATO_AP AdditionalHint]] "<bullet_point> Improved armor penetration"),
	'Cost', 200,
	'CanAppearInShop', true,
	'Tier', 2,
	'MaxStock', 5,
	'RestockWeight', 25,
	'CategoryPair', "762NATO",
	'ShopStackSize', 30,
	'MaxStacks', 500,
	'Caliber', "762NATO",
	'Modifications', {
		PlaceObj('CaliberModification', {
			mod_add = 2,
			target_prop = "PenetrationClass",
		}),
	},
})

