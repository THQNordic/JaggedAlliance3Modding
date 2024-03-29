-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Grenade - Explosive",
	'Id', "RemoteTNT",
	'Comment', "high mishap",
	'object_class', "ThrowableTrapItem",
	'Repairable', false,
	'Reliability', 100,
	'Icon', "UI/Icons/Items/remote_tnt",
	'ItemType', "Grenade",
	'DisplayName', T(814310721881, --[[InventoryItemCompositeDef RemoteTNT DisplayName]] "Remote TNT"),
	'DisplayNamePlural', T(850557903938, --[[InventoryItemCompositeDef RemoteTNT DisplayNamePlural]] "Remote TNT"),
	'AdditionalHint', T(934007885412, --[[InventoryItemCompositeDef RemoteTNT AdditionalHint]] "<bullet_point> Explodes when triggered by a remote Detonator switch\n<bullet_point> High mishap chance"),
	'UnitStat', "Explosives",
	'Cost', 600,
	'CanAppearInShop', true,
	'Tier', 2,
	'MaxStock', 1,
	'RestockWeight', 10,
	'CategoryPair', "Grenade",
	'MinMishapChance', 2,
	'MaxMishapChance', 30,
	'MaxMishapRange', 6,
	'AttackAP', 4000,
	'BaseRange', 3,
	'ThrowMaxRange', 12,
	'CanBounce', false,
	'Noise', 30,
	'Entity', "Explosive_TNT",
	'ActionIcon', "UI/Icons/Hud/throw_remote_explosive",
	'TriggerType', "Remote",
})

