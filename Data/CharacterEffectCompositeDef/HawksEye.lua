-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Perk-Personal",
	'Id', "HawksEye",
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "pindownCostOverwrite",
			'Value', 1,
			'Tag', "<pindownCostOverwrite>",
		}),
	},
	'Comment', "Scope - PinDown bonuses; Cookies",
	'object_class', "Perk",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnMercHired",
			Handler = function (self, target, price, days, alreadyHired)
				if days > 0 then
					local canPlaceError = CanPlaceItemInInventory("Cookie", days, target)
					if canPlaceError then
						CombatLog("important", T(667077082306, "Scope has baked some biscuits. Unfortunately the inventory is full. "))
						return
					end
					CombatLog("important",T(754424382903, "Scope has baked some biscuits"))
					PlaceItemInInventory("Cookie", days, target)
				end
			end,
		}),
	},
	'DisplayName', T(930669061773, --[[CharacterEffectCompositeDef HawksEye DisplayName]] "Eagle Eye"),
	'Description', T(161077132582, --[[CharacterEffectCompositeDef HawksEye Description]] "<GameTerm('PinDown')> applies <GameTerm('Exposed')> to the target.\n\n<GameTerm('PinDown')> minimum <em>AP</em> cost is reduced to <em><pindownCostOverwrite> AP</em>.\n\nScope also makes <GameTerm('Biscuits')>."),
	'Icon', "UI/Icons/Perks/HawksEye",
	'Tier', "Personal",
})

