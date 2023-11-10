-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Armor - Flak",
	'Id', "FlakArmor_CeramicPlates",
	'Comment', "All upgraded armors should only appear used in Bobby Ray's",
	'object_class', "TransmutedArmor",
	'ScrapParts', 4,
	'Degradation', 6,
	'Icon', "UI/Icons/Items/flak_armor",
	'SubIcon', "UI/Icons/Items/plates",
	'DisplayName', T(977066896029, --[[InventoryItemCompositeDef FlakArmor_CeramicPlates DisplayName]] "Flak Armor"),
	'DisplayNamePlural', T(195720969644, --[[InventoryItemCompositeDef FlakArmor_CeramicPlates DisplayNamePlural]] "Flak Armors"),
	'AdditionalHint', T(800327779807, --[[InventoryItemCompositeDef FlakArmor_CeramicPlates AdditionalHint]] "<bullet_point> Damage reduction improved by Ceramic Plates\n<bullet_point> The ceramic plates will break after taking <GameColorG><RevertConditionCounter></GameColorG> hits"),
	'Cost', 2400,
	'CanAppearInShop', true,
	'MaxStock', 1,
	'RestockWeight', 35,
	'CategoryPair', "Light",
	'CanAppearStandard', false,
	'PenetrationClass', 2,
	'DamageReduction', 40,
	'AdditionalReduction', 20,
	'ProtectedBodyParts', set( "Arms", "Torso" ),
})

