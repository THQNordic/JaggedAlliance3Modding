-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-Personal",
	'Id', "HaveABlast",
	'Comment', "Red - retaliation with grenades",
	'object_class', "Perk",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnCombatEnd",
			Handler = function (self, target)
				target:SetEffectValue("HaveABlast", nil)
			end,
		}),
	},
	'DisplayName', T(728433872060, --[[CharacterEffectCompositeDef HaveABlast DisplayName]] "Have at Ye"),
	'Description', T(697763462310, --[[CharacterEffectCompositeDef HaveABlast Description]] "When activated, Red <em>retaliates</em> with <em>Grenades</em> when hit during the enemy turn.\n\nWill not trigger while <em>Taking Cover</em> or being in <em>Overwatch</em>."),
	'Icon', "UI/Icons/Perks/HaveABlast",
	'Tier', "Personal",
})

