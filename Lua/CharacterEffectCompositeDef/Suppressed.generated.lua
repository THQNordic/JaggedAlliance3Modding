-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Suppressed')
DefineClass.Suppressed = {
	__parents = { "StatusEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "StatusEffect",
	msg_reactions = {},
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnCalcStartTurnAP",
			Handler = function (self, target, value)
				return value + self:ResolveValue("ap_loss") * const.Scale.AP
			end,
		}),
	},
	DisplayName = T(741267773678, --[[CharacterEffectCompositeDef Suppressed DisplayName]] "Suppressed"),
	Description = T(748124520136, --[[CharacterEffectCompositeDef Suppressed Description]] "Penalty of <em><ap_loss> is applied to your maximum AP</em> for this turn. This character cannot <em>Flank</em> enemies."),
	AddEffectText = T(882347159665, --[[CharacterEffectCompositeDef Suppressed AddEffectText]] "<em><DisplayName></em> is suppressed"),
	OnAdded = function (self, obj)
		obj:ConsumeAP(-self:ResolveValue("ap_loss") * const.Scale.AP)
	end,
	type = "Debuff",
	lifetime = "Until End of Turn",
	Icon = "UI/Hud/Status effects/suppressed",
	RemoveOnEndCombat = true,
	Shown = true,
	HasFloatingText = true,
}

