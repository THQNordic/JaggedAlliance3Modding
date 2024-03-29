-- ========== GENERATED BY InventoryItemCompositeDef Editor (Ctrl-Alt-Y) DO NOT EDIT MANUALLY! ==========

UndefineClass('SkillMag_Leadership')
DefineClass.SkillMag_Leadership = {
	__parents = { "MiscItem" },
	__generated_by_class = "InventoryItemCompositeDef",


	object_class = "MiscItem",
	Repairable = false,
	Icon = "UI/Icons/Items/mag_puntastic_dad_jokes",
	DisplayName = T(624085403180, --[[InventoryItemCompositeDef SkillMag_Leadership DisplayName]] "Puntastic Dad Jokes"),
	DisplayNamePlural = T(542345156012, --[[InventoryItemCompositeDef SkillMag_Leadership DisplayNamePlural]] "Puntastic Dad Jokes"),
	Description = T(437039053771, --[[InventoryItemCompositeDef SkillMag_Leadership Description]] "Why is issue six afraid of issue seven?"),
	AdditionalHint = T(787629043274, --[[InventoryItemCompositeDef SkillMag_Leadership AdditionalHint]] "<bullet_point> Used through the Item Menu\n<bullet_point> Single use\n<bullet_point> Increases Leadership"),
	UnitStat = "Leadership",
	Valuable = 1,
	Cost = 1500,
	CanAppearInShop = true,
	Tier = 2,
	MaxStock = 1,
	RestockWeight = 10,
	effect_moment = "on_use",
	Effects = {
		PlaceObj('UnitStatBoost', {
			Amount = 1,
			Stat = "Leadership",
		}),
	},
	action_name = T(134463686670, --[[InventoryItemCompositeDef SkillMag_Leadership action_name]] "READ"),
	destroy_item = true,
}

