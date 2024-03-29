-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Dexterity",
	'Id', "Virtuoso",
	'SortKey', 9,
	'Parameters', {
		PlaceObj('PresetParamPercent', {
			'Name', "virtuosoStealthKillChance",
			'Value', 15,
			'Tag', "<virtuosoStealthKillChance>%",
		}),
	},
	'object_class', "Perk",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnCalcStealthKillChance",
			Handler = function (self, target, value, attacker, attack_target, weapon, target_spot_group, aim)
				if target == attacker and IsFullyAimedAttack(aim) then
					return value + self:ResolveValue("virtuosoStealthKillChance")
				end
			end,
		}),
	},
	'DisplayName', T(273806123408, --[[CharacterEffectCompositeDef Virtuoso DisplayName]] "Assassination"),
	'Description', T(368382559050, --[[CharacterEffectCompositeDef Virtuoso Description]] "Increased chance for <GameTerm('StealthKills')> for attacks with 3+ Aim levels made while <GameTerm('Sneaking')>."),
	'Icon', "UI/Icons/Perks/Virtuoso",
	'Tier', "Gold",
	'Stat', "Dexterity",
	'StatValue', 90,
})

