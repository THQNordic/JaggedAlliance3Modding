-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Id', "Choking",
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "damage",
			'Value', 30,
			'Tag', "<damage>",
		}),
	},
	'Comment', "environmental effect (toxic gas)",
	'object_class', "CharacterEffect",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnBeginTurn",
			Handler = function (self, target)
				if target:IsMerc() then
					PlayVoiceResponse(target, "GasAreaSelection")
				else
					PlayVoiceResponse(target, "AIGasAreaSelection")
				end
			end,
		}),
		PlaceObj('UnitReaction', {
			Event = "OnEndTurn",
			Handler = function (self, target)
				if not target:IsDead() then
					EnvEffectToxicGasTick(target, nil, "end turn")
				end
			end,
		}),
	},
	'DisplayName', T(720153419307, --[[CharacterEffectCompositeDef Choking DisplayName]] "Choking"),
	'Description', T(120652127957, --[[CharacterEffectCompositeDef Choking Description]] "This character will <em>take <damage> damage</em> at the end of their turn. The character also <em>loses Energy</em>."),
	'AddEffectText', T(478064574365, --[[CharacterEffectCompositeDef Choking AddEffectText]] "<em><DisplayName></em> is choking"),
	'OnAdded', function (self, obj)
		self:SetParameter("choking_start_time", GameTime())
		if obj:IsMerc() then
			PlayVoiceResponse(obj, "GasAreaSelection")
		else
			PlayVoiceResponse(obj, "AIGasAreaSelection")
		end
	end,
	'type', "Debuff",
	'Icon', "UI/Hud/Status effects/choking",
	'RemoveOnEndCombat', true,
	'RemoveOnSatViewTravel', true,
	'RemoveOnCampaignTimeAdvance', true,
	'Shown', true,
	'HasFloatingText', true,
})

