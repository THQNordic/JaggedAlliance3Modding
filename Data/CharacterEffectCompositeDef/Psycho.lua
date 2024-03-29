-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-Personality",
	'Id', "Psycho",
	'SortKey', 10,
	'Parameters', {
		PlaceObj('PresetParamPercent', {
			'Name', "procChance",
			'Value', 3,
			'Tag', "<procChance>%",
		}),
	},
	'Comment', "randomly replace single shot with burst or burst fire with auto (3% chance), keeping the original AP cost.",
	'object_class', "Perk",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnFirearmAttackStart",
			Handler = function (self, target, attacker, attack_target, action, attack_args)
				if target == attacker and (action.id == "SingleShot" or action.id == "BurstFire") then
					if attacker:Random(100) < self:ResolveValue("procChance") then
						local weapon = action:GetAttackWeapons(attacker)
						if action.id == "SingleShot" and table.find(weapon.AvailableAttacks, "BurstFire") then
							attack_args.replace_action = "BurstFire"
							PlayVoiceResponse(attacker, "Psycho")
						elseif action.id == "BurstFire" and table.find(weapon.AvailableAttacks, "AutoFire") then
							attack_args.replace_action = "AutoFire"
							PlayVoiceResponse(attacker, "Psycho")
						end
					end
				end
			end,
		}),
	},
	'DisplayName', T(256373672615, --[[CharacterEffectCompositeDef Psycho DisplayName]] "Psycho"),
	'Description', T(966163673727, --[[CharacterEffectCompositeDef Psycho Description]] "Can decide to use a more vicious attack than the one selected.\n\nAdditional <em>conversation options</em>."),
	'Icon', "UI/Icons/Perks/Psycho",
	'Tier', "Personality",
})

