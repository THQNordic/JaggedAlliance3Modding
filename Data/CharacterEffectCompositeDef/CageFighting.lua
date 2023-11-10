-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System-Quests",
	'Id', "CageFighting",
	'Comment', "Used in Landsbach",
	'object_class', "CharacterEffect",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "PreUnitTakeDamage",
			Handler = function (self, target, damage, attacker, attack_target, hit)
				if target == attack_target then
					local hpTotal = Max(0, target.HitPoints - damage)
					local maxHp = target:GetInitialMaxHitPoints()  -- without wounds
					local hpLoseAt = MulDivRound(maxHp, CageFightingLostAtPercent, 100)
					if hpTotal < hpLoseAt then
						Msg("CageFightingLose", target)
						return target.HitPoints - hpLoseAt
					end
				end
			end,
		}),
	},
})

