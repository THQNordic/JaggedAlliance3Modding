-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Ammo",
	'Id', "_9mm_Shock",
	'object_class', "Ammo",
	'Icon', "UI/Icons/Items/9mm_bullets_shock",
	'DisplayName', T(527113359889, --[[InventoryItemCompositeDef _9mm_Shock DisplayName]] "9 mm Shock"),
	'DisplayNamePlural', T(592944604182, --[[InventoryItemCompositeDef _9mm_Shock DisplayNamePlural]] "9 mm Shock"),
	'colorStyle', "AmmoMatchColor",
	'Description', T(923881615835, --[[InventoryItemCompositeDef _9mm_Shock Description]] "9 mm ammo for Handguns and SMGs."),
	'AdditionalHint', T(205583625720, --[[InventoryItemCompositeDef _9mm_Shock AdditionalHint]] "<bullet_point> Reduced range\n<bullet_point> No armor penetration\n<bullet_point> High Crit chance\n<bullet_point> Hit enemies are <em>Exposed</em> and lose the benefits of Cover\n<bullet_point> Inflicts <em>Bleeding</em>"),
	'Cost', 90,
	'CanAppearInShop', true,
	'Tier', 2,
	'MaxStock', 5,
	'RestockWeight', 25,
	'CategoryPair', "9mm",
	'ShopStackSize', 30,
	'MaxStacks', 500,
	'Caliber', "9mm",
	'Modifications', {
		PlaceObj('CaliberModification', {
			mod_add = 50,
			target_prop = "CritChance",
		}),
		PlaceObj('CaliberModification', {
			mod_add = -4,
			target_prop = "PenetrationClass",
		}),
		PlaceObj('CaliberModification', {
			mod_add = -4,
			target_prop = "WeaponRange",
		}),
	},
	'AppliedEffects', {
		"Exposed",
		"Bleeding",
	},
})

