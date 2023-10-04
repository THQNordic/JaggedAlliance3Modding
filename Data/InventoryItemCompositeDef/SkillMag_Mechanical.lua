-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

PlaceObj('InventoryItemCompositeDef', {
	'Group', "Magazines",
	'Id', "SkillMag_Mechanical",
	'object_class', "MiscItem",
	'Repairable', false,
	'Icon', "UI/Icons/Items/mag_screw_you",
	'DisplayName', T(593394887790, --[[InventoryItemCompositeDef SkillMag_Mechanical DisplayName]] "Nuts and Bolts Magazine"),
	'DisplayNamePlural', T(115283650556, --[[InventoryItemCompositeDef SkillMag_Mechanical DisplayNamePlural]] "Nuts and Bolts Magazine"),
	'Description', T(882249328783, --[[InventoryItemCompositeDef SkillMag_Mechanical Description]] "Not to be confused with the NSFW magazine with the same name."),
	'AdditionalHint', T(594623778604, --[[InventoryItemCompositeDef SkillMag_Mechanical AdditionalHint]] "<bullet_point> Used through the Item Menu\n<bullet_point> Single use\n<bullet_point> Increases Mechanical"),
	'UnitStat', "Mechanical",
	'Valuable', 1,
	'effect_moment', "on_use",
	'Effects', {
		PlaceObj('UnitStatBoost', {
			Amount = 1,
			Stat = "Mechanical",
		}),
	},
	'action_name', T(196171082016, --[[InventoryItemCompositeDef SkillMag_Mechanical action_name]] "READ"),
	'destroy_item', true,
})
