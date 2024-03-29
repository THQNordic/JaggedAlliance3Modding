-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Id', "Exhausted",
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "ap_loss",
			'Value', -3,
			'Tag', "<ap_loss>",
		}),
		PlaceObj('PresetParamNumber', {
			'Name', "duration",
			'Value', 12,
			'Tag', "<duration>",
		}),
	},
	'object_class', "StatusEffect",
	'msg_reactions', {},
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnBeginTurn",
			Handler = function (self, target)
				target:ConsumeAP(-self:ResolveValue("ap_loss") * const.Scale.AP)
			end,
		}),
	},
	'DisplayName', T(707410221892, --[[CharacterEffectCompositeDef Exhausted DisplayName]] "Exhausted"),
	'Description', T(787484805512, --[[CharacterEffectCompositeDef Exhausted Description]] "Penalty of <em><ap_loss> is applied to your maximum AP</em>. Cannot gain <em>Free Move</em>. Recover by being idle for <duration> hours in Sat View."),
	'OnAdded', function (self, obj)
		obj:AddStatusEffectImmunity("FreeMove", self.class)
	end,
	'OnRemoved', function (self, obj)
		obj:RemoveStatusEffectImmunity("FreeMove", self.class)
	end,
	'type', "Debuff",
	'Icon', "UI/Hud/Status effects/exhausted",
	'Shown', true,
	'ShownSatelliteView', true,
	'HasFloatingText', true,
})

