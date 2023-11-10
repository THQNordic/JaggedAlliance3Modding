-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System-Quests",
	'Id', "Unwell",
	'Parameters', {
		PlaceObj('PresetParamPercent', {
			'Name', "range_cth_mod",
			'Value', -20,
			'Tag', "<range_cth_mod>%",
		}),
	},
	'Comment', "Used in Camp Barrierre guardpost objective",
	'object_class', "CharacterEffect",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnCalcChanceToHit",
			Handler = function (self, target, attacker, action, attack_target, weapon1, weapon2, data)
				if action.ActionType == "Ranged Attack" then
					data.mod_add = data.mod_add + self:ResolveValue("range_cth_mod")
				end
			end,
		}),
	},
	'DisplayName', T(728202676649, --[[CharacterEffectCompositeDef Unwell DisplayName]] "Unwell"),
	'Description', T(664298829629, --[[CharacterEffectCompositeDef Unwell Description]] "Lower <em>Accuracy</em> with <em>Ranged Attacks</em>\n"),
	'Icon', "UI/Hud/Status effects/drunk",
	'RemoveOnEndCombat', true,
	'Shown', true,
	'HasFloatingText', true,
})

