-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-Personal",
	'Id', "SteroidPunch",
	'Comment', "Steroid - SMASH",
	'object_class', "Perk",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnCalcStimmedTiredness",
			Handler = function (self, target, value)
				return 0 -- Steroid is immune to this effect
			end,
		}),
	},
	'DisplayName', T(971977283112, --[[CharacterEffectCompositeDef SteroidPunch DisplayName]] "Steroid Smash!"),
	'Description', T(406627212484, --[[CharacterEffectCompositeDef SteroidPunch Description]] "An <em>Unarmed Attack</em> that sends the target flying and inflicts collateral damage to the nearby objects.\n\n<em>Accuracy</em> is based on<em> Strength</em> instead of Dexterity.\n\nSteroid is immune to negative effects from using <em>Combat Stims</em>."),
	'Icon', "UI/Icons/Perks/SteroidPunch",
	'Tier', "Personal",
})

