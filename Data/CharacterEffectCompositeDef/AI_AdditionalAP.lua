-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-NPC",
	'Id', "AI_AdditionalAP",
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "bonus",
			'Value', 8,
			'Tag', "<bonus>",
		}),
	},
	'object_class', "CharacterEffect",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnCalcStartTurnAP",
			Handler = function (self, target, value)
				if not self:ResolveValue("applied") then
					return value + self:ResolveValue("bonus") * const.Scale.AP
				end
			end,
		}),
	},
	'Conditions', {
		PlaceObj('CheckExpression', {
			Expression = function (self, obj) return g_Combat and IsKindOf(obj, "Unit") and not obj:HasStatusEffect("Inspired") end,
		}),
	},
	'DisplayName', T(905544012922, --[[CharacterEffectCompositeDef AI_AdditionalAP DisplayName]] "Inspired"),
	'Description', T(912592808613, --[[CharacterEffectCompositeDef AI_AdditionalAP Description]] "Gain <em><bonus> AP</em>."),
	'AddEffectText', T(409912479847, --[[CharacterEffectCompositeDef AI_AdditionalAP AddEffectText]] "<em><DisplayName></em> is inspired"),
	'OnAdded', function (self, obj)
		if g_Teams[g_CurrentTeam] == obj.team then
			obj:GainAP(self:ResolveValue("bonus") * const.Scale.AP)
			self:SetParameter("applied", true)
		end
	end,
	'type', "Buff",
	'lifetime', "Until End of Turn",
	'Icon', "UI/Hud/Status effects/inspired",
	'RemoveOnEndCombat', true,
})

