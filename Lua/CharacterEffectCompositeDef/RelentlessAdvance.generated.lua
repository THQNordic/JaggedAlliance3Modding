-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('RelentlessAdvance')
DefineClass.RelentlessAdvance = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	msg_reactions = {},
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnCalcFreeMove",
			Handler = function (self, target, data)
				if target:IsUsingCover() then 
					data.mul = data.mul * self:ResolveValue("free_move_mult") 
				end
			end,
		}),
	},
	DisplayName = T(362088226152, --[[CharacterEffectCompositeDef RelentlessAdvance DisplayName]] "Frogleaping"),
	Description = T(964212379479, --[[CharacterEffectCompositeDef RelentlessAdvance Description]] "Increased <GameTerm('FreeMove')> <em>Range</em> when starting your turn in <em>Cover</em>."),
	Icon = "UI/Icons/Perks/RelentlessAdvance",
	Tier = "Silver",
	Stat = "Agility",
	StatValue = 80,
}

