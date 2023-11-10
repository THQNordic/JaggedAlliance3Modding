-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Inspired')
DefineClass.Inspired = {
	__parents = { "CharacterEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "CharacterEffect",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnBeginTurn",
			Handler = function (self, target)
				if not self:ResolveValue("applied") then
					target:GainAP(self:ResolveValue("bonus") * const.Scale.AP)
				end
			end,
		}),
	},
	Conditions = {
		PlaceObj('CheckExpression', {
			Expression = function (self, obj) return g_Combat and IsKindOf(obj, "Unit") end,
		}),
	},
	DisplayName = T(122953001800, --[[CharacterEffectCompositeDef Inspired DisplayName]] "Inspired"),
	Description = T(853696490891, --[[CharacterEffectCompositeDef Inspired Description]] "Gain <em><bonus> AP</em>."),
	AddEffectText = T(811015193839, --[[CharacterEffectCompositeDef Inspired AddEffectText]] "<em><DisplayName></em> is inspired"),
	OnAdded = function (self, obj)
		if g_Teams[g_CurrentTeam] == obj.team then
			obj:GainAP(self:ResolveValue("bonus") * const.Scale.AP)
			self:SetParameter("applied", true)
		end
	end,
	type = "Buff",
	lifetime = "Until End of Turn",
	Icon = "UI/Hud/Status effects/inspired",
	RemoveOnEndCombat = true,
	Shown = true,
	HasFloatingText = true,
}

