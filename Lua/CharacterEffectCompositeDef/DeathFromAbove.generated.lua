-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('DeathFromAbove')
DefineClass.DeathFromAbove = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnModifyCTHModifier",
			Handler = function (self, target, id, attacker, attack_target, action, weapon1, weapon2, data)
				if target == attacker and id == "GroundDifference" and data.base_chance > 0 and action.ActionType == "Ranged Attack" then
					data.mod_add = data.mod_add + self:ResolveValue("highground_cth_bonus")
					data.meta_text[#data.meta_text + 1] = T{776394275735, "Perk: <name>", name = self.DisplayName}
				end
			end,
		}),
	},
	DisplayName = T(733285334670, --[[CharacterEffectCompositeDef DeathFromAbove DisplayName]] "Vantage Point"),
	Description = T(755928290476, --[[CharacterEffectCompositeDef DeathFromAbove Description]] "<em>Better Accuracy</em> when shooting from <em>high ground</em>.\n\n<em>Cheaper AP</em> cost when climbing up and down <em>ladders</em>."),
	Icon = "UI/Icons/Perks/DeathFromAbove",
	Tier = "Silver",
	Stat = "Agility",
	StatValue = 80,
}

