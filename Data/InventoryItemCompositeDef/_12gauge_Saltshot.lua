-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Ammo",
	'Id', "_12gauge_Saltshot",
	'object_class', "Ammo",
	'Icon', "UI/Icons/Items/12_gauge_bullets_saltshot",
	'DisplayName', T(267395126102, --[[InventoryItemCompositeDef _12gauge_Saltshot DisplayName]] "12-gauge Saltshot"),
	'DisplayNamePlural', T(598926526992, --[[InventoryItemCompositeDef _12gauge_Saltshot DisplayNamePlural]] "12-gauge Saltshot"),
	'colorStyle', "AmmoTracerColor",
	'Description', T(865200495495, --[[InventoryItemCompositeDef _12gauge_Saltshot Description]] "12-gauge ammo for Shotguns."),
	'AdditionalHint', T(331667140330, --[[InventoryItemCompositeDef _12gauge_Saltshot AdditionalHint]] "<bullet_point> Low damage\n<bullet_point> Shorter range\n<bullet_point> Wide attack cone\n<bullet_point> Inflicts <em>Inaccurate</em>"),
	'Cost', 100,
	'CanAppearInShop', true,
	'Tier', 2,
	'MaxStock', 5,
	'RestockWeight', 80,
	'ShopStackSize', 12,
	'MaxStacks', 500,
	'Caliber', "12gauge",
	'Modifications', {
		PlaceObj('CaliberModification', {
			mod_mul = 500,
			target_prop = "Damage",
		}),
		PlaceObj('CaliberModification', {
			mod_mul = 1700,
			target_prop = "BuckshotConeAngle",
		}),
		PlaceObj('CaliberModification', {
			mod_add = -2,
			target_prop = "WeaponRange",
		}),
		PlaceObj('CaliberModification', {
			mod_mul = 1700,
			target_prop = "OverwatchAngle",
		}),
	},
	'AppliedEffects', {
		"Inaccurate",
	},
})

