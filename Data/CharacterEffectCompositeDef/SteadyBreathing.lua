-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Agility",
	'Id', "SteadyBreathing",
	'SortKey', 3,
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "freeMoveBonusAp",
			'Value', 3,
			'Tag', "<freeMoveBonusAp>",
		}),
	},
	'object_class', "Perk",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnCalcFreeMove",
			Handler = function (self, target, data)
				local armourItems = target:GetEquipedArmour()
				for _, item in ipairs(armourItems) do
					if item.PenetrationClass > 2 then
						return
					end
				end
				data.add = data.add + self:ResolveValue("freeMoveBonusAp")
			end,
		}),
	},
	'DisplayName', T(169594503293, --[[CharacterEffectCompositeDef SteadyBreathing DisplayName]] "Fast Runner"),
	'Description', T(727749516634, --[[CharacterEffectCompositeDef SteadyBreathing Description]] "Increased <GameTerm('FreeMove')> <em>Range</em> when wearing <em>Light Armor</em> or not wearing any Armor."),
	'Icon', "UI/Icons/Perks/SteadyBreathing",
	'Tier', "Bronze",
	'Stat', "Agility",
	'StatValue', 70,
})

