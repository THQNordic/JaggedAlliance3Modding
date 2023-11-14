-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System",
	'Id', "Darkness",
	'object_class', "CharacterEffect",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnUnitEnterMapVisual",
			Handler = function (self, target)
				target:SetHighlightReason("darkness", true)
			end,
		}),
	},
	'DisplayName', T(770333565093, --[[CharacterEffectCompositeDef Darkness DisplayName]] "In Darkness"),
	'Description', "",
	'OnAdded', function (self, obj)
		if IsKindOf(obj, "Unit") then
			obj:SetHighlightReason("darkness", true)
		end
	end,
	'OnRemoved', function (self, obj)
		if IsKindOf(obj, "Unit") then
			obj:SetHighlightReason("darkness", nil)
		end
	end,
	'Icon', "UI/Hud/Status effects/darkness",
})

