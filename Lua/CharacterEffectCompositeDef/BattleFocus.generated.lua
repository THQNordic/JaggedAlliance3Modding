-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('BattleFocus')
DefineClass.BattleFocus = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnDamageTaken",
			Handler = function (self, target, attacker, dmg, hit_descr)
				self:SetParameter("activated", true)
			end,
		}),
		PlaceObj('UnitReaction', {
			Event = "OnCombatEnd",
			Handler = function (self, target)
				self:SetParameter("activated", false)
			end,
		}),
		PlaceObj('UnitReaction', {
			Event = "OnCalcStartTurnAP",
			Handler = function (self, target, value)
				if self:ResolveValue("activated") then
					return value + self:ResolveValue("battleFocusAP") * const.Scale.AP
				end
			end,
		}),
	},
	DisplayName = T(822626767198, --[[CharacterEffectCompositeDef BattleFocus DisplayName]] "Battle Focus"),
	Description = T(235322784555, --[[CharacterEffectCompositeDef BattleFocus Description]] "Gain <em><battleFocusAP></em> <em>AP</em> when <em>hit</em> by an enemy for the <em>first</em> time.\n\nEnds at the end of combat."),
	Icon = "UI/Icons/Perks/BattleFocus",
	Tier = "Gold",
	Stat = "Health",
	StatValue = 90,
}

