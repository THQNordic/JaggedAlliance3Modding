-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Berserk')
DefineClass.Berserk = {
	__parents = { "CharacterEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "CharacterEffect",
	Conditions = {
		PlaceObj('CombatIsActive', {}),
	},
	DisplayName = T(420777563903, --[[CharacterEffectCompositeDef Berserk DisplayName]] "Berserk"),
	Description = T(392582028996, --[[CharacterEffectCompositeDef Berserk Description]] "Uncontrollable. Recklessly attacks nearby enemies."),
	AddEffectText = T(473269787540, --[[CharacterEffectCompositeDef Berserk AddEffectText]] "<em><DisplayName></em> went Berserk"),
	RemoveEffectText = T(463610360293, --[[CharacterEffectCompositeDef Berserk RemoveEffectText]] "<em><DisplayName></em> is no longer Berserk"),
	OnAdded = function (self, obj)
		obj:RemoveStatusEffect("Panicked")
		obj:InterruptPreparedAttack()
		if g_Teams[g_CurrentTeam] == obj.team then
			ScheduleMoraleActions()
		end
	end,
	lifetime = "Until End of Next Turn",
	Icon = "UI/Hud/Status effects/rage",
	RemoveOnEndCombat = true,
	Shown = true,
	HasFloatingText = true,
}

