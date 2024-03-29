-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Ambidextrous')
DefineClass.Ambidextrous = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnModifyCTHModifier",
			Handler = function (self, target, id, attacker, attack_target, action, weapon1, weapon2, data)
				if target == attacker and id == "TwoWeaponFire" then
					data.mod_add = data.mod_add + self:ResolveValue("PenaltyReduction")
					data.meta_text[#data.meta_text + 1] = T{756119910645, "Perk: <perkName>", perkName = self.DisplayName}
				end
			end,
		}),
	},
	Modifiers = {},
	DisplayName = T(572344361258, --[[CharacterEffectCompositeDef Ambidextrous DisplayName]] "Ambidextrous"),
	Description = T(810486500317, --[[CharacterEffectCompositeDef Ambidextrous Description]] "Reduced <em>Accuracy</em> penalty when <em>Dual-Wielding</em> Firearms."),
	Icon = "UI/Icons/Perks/Ambidextrous",
	Tier = "Quirk",
}

