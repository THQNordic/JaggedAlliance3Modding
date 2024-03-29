-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('BreachAndClear')
DefineClass.BreachAndClear = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnUnitAttackResolved",
			Handler = function (self, target, attacker, attack_target, action, attack_args, results, can_retaliate, combat_starting)
				if target == attacker and IsKindOfClasses(results.weapon, "Grenade", "Shotgun") then
					if g_Combat then
						attacker:AddStatusEffect("FreeMove")
					elseif g_StartingCombat or combat_starting then
						attacker:AddStatusEffect("FreeMoveOnCombatStart")
					end
				end
			end,
		}),
	},
	DisplayName = T(609540599823, --[[CharacterEffectCompositeDef BreachAndClear DisplayName]] "Breach and Clear"),
	Description = T(853841959476, --[[CharacterEffectCompositeDef BreachAndClear Description]] "Gain <GameTerm('FreeMove')> after throwing <em>Grenades</em> or making <em>Shotgun</em> attacks."),
	Icon = "UI/Icons/Perks/BreachAndClear",
	Tier = "Bronze",
	Stat = "Strength",
	StatValue = 70,
}

