-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Wisdom",
	'Id', "LastWarning",
	'SortKey', 5,
	'Parameters', {
		PlaceObj('PresetParamPercent', {
			'Name', "panic_chance",
			'Value', 15,
			'Tag', "<panic_chance>%",
		}),
	},
	'object_class', "Perk",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnUnitAttack",
			Handler = function (self, target, attacker, action, attack_target, results, attack_args)
				local chance = self:ResolveValue("panic_chance")
				if target == attacker and attacker.team.morale > 0 and attacker:Random(100) < chance then
					for _, hit in ipairs(results) do
						local unit = IsKindOf(hit.obj, "Unit") and not hit.obj:IsIncapacitated() and hit.obj
						local damage = hit.damage or 0
						if unit and unit:IsOnEnemySide(attacker) and (hit.aoe or not hit.stray) and (damage > 0) then
							unit:AddStatusEffect("Panicked")
							unit.ActionPoints = unit:GetMaxActionPoints()
						end
					end
				end
			end,
		}),
	},
	'DisplayName', T(665390097648, --[[CharacterEffectCompositeDef LastWarning DisplayName]] "Dire Warning"),
	'Description', T(634333203160, --[[CharacterEffectCompositeDef LastWarning Description]] "When <GameTerm('Morale')> is <em>High</em> or <em>Very High</em>, gain <em><percent(panic_chance)> chance</em> to cause <GameTerm('Panic')> with each <em>attack</em> that deals damage. "),
	'Icon', "UI/Icons/Perks/LastWarning",
	'Tier', "Silver",
	'Stat', "Wisdom",
	'StatValue', 80,
})

