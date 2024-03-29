-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-Personal",
	'Id', "NailsPerk",
	'Comment', "Nails - bloodthirsty after first kill",
	'object_class', "Perk",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnUnitKill",
			Handler = function (self, target, killedUnits)
				target:AddStatusEffect("Bloodthirst")
			end,
		}),
	},
	'DisplayName', T(399524807633, --[[CharacterEffectCompositeDef NailsPerk DisplayName]] "Nailed It"),
	'Description', T(365161980518, --[[CharacterEffectCompositeDef NailsPerk Description]] "Gains <GameTerm('Bloodthirst')> after<em> first kill</em> in combat."),
	'Icon', "UI/Icons/Perks/NailsPerk",
	'Tier', "Personal",
})

