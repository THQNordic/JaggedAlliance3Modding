-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Tired')
DefineClass.Tired = {
	__parents = { "StatusEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "StatusEffect",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnCalcStartTurnAP",
			Handler = function (self, target, value)
				return value + self:ResolveValue("ap_loss") * const.Scale.AP
			end,
		}),
	},
	DisplayName = T(299677471612, --[[CharacterEffectCompositeDef Tired DisplayName]] "Tired"),
	Description = T(689241800564, --[[CharacterEffectCompositeDef Tired Description]] "Penalty of <em><ap_loss> is applied to your maximum AP</em>. Cannot gain <em>Free Move</em>. Recovers by being idle for <duration> hours in the Sat View."),
	AddEffectText = T(488444599414, --[[CharacterEffectCompositeDef Tired AddEffectText]] "<em><DisplayName></em> is tired"),
	OnAdded = function (self, obj)
		obj:RemoveStatusEffect("FreeMove")
	end,
	type = "Debuff",
	Icon = "UI/Hud/Status effects/tired",
	Shown = true,
	ShownSatelliteView = true,
	HasFloatingText = true,
}

