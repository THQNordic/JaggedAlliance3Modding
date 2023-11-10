-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('SingularPurpose')
DefineClass.SingularPurpose = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnCombatEnd",
			Handler = function (self, target)
				self:SetParameter("bonus_active", false)
			end,
		}),
		PlaceObj('UnitReaction', {
			Event = "OnUnitAttack",
			Handler = function (self, target, attacker, action, attack_target, results, attack_args)
				if target == attacker and results.miss then
					self:SetParameter("bonus_active", false)
				end
			end,
		}),
		PlaceObj('UnitReaction', {
			Event = "OnUnitKill",
			Handler = function (self, target, killedUnits)
				self:SetParameter("bonus_active", true)
			end,
		}),
		PlaceObj('UnitReaction', {
			Event = "OnCalcDamageAndEffects",
			Handler = function (self, target, attacker, attack_target, action, weapon, attack_args, hit, data)
				if self:ResolveValue("bonus_active") then
					local damageBonus = self:ResolveValue("damageBonus")
					data.base_damage = MulDivRound(data.base_damage, 100 + damageBonus, 100)
					data.breakdown[#data.breakdown + 1] = { name = self.DisplayName, value = damageBonus }
				end
			end,
		}),
	},
	DisplayName = T(899667530546, --[[CharacterEffectCompositeDef SingularPurpose DisplayName]] "Total Concentration"),
	Description = T(699634025627, --[[CharacterEffectCompositeDef SingularPurpose Description]] "Attacks deal <em><percent(damageBonus)></em> extra <em>Damage</em> after a <em>kill</em>.\n\nEnds when you <em>miss</em> or at the end of combat."),
	Icon = "UI/Icons/Perks/SingularPurpose",
	Tier = "Gold",
	Stat = "Agility",
	StatValue = 90,
}

