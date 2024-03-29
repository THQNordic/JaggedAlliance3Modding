-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('BleedingOut')
DefineClass.BleedingOut = {
	__parents = { "CharacterEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "CharacterEffect",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnEndTurn",
			Handler = function (self, target)
				if not IsInCombat() then return end
				if not RollSkillCheck(target, "Health", nil, target.downed_check_penalty) then
					CombatLog("important", T{290150299208, "<em><LogName></em> has <em>bled out</em>", target})
					target:TakeDirectDamage(target:GetTotalHitPoints())
				else
					target.downed_check_penalty = target.downed_check_penalty + self:ResolveValue("add_penalty")
					CombatLog("short", T{333799512710, "<em><LogName></em> is <em>bleeding</em>", target})
				end
			end,
		}),
	},
	Conditions = {
		PlaceObj('CombatIsActive', {}),
	},
	DisplayName = T(833314215129, --[[CharacterEffectCompositeDef BleedingOut DisplayName]] "Downed"),
	Description = T(588355193847, --[[CharacterEffectCompositeDef BleedingOut Description]] "This character is in <em>Critical condition</em> and will bleed out unless treated with the <em>Bandage</em> action. The character remains alive if a successful check against Health is made next turn."),
	OnAdded = function (self, obj)  end,
	Icon = "UI/Hud/Status effects/bleedingout",
	Shown = true,
}

