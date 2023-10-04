-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "Health",
	'Id', "BattleFocus",
	'SortKey', 9,
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "battleFocusAP",
			'Value', 2,
			'Tag', "<battleFocusAP>",
		}),
	},
	'object_class', "Perk",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "target",
			Event = "DamageTaken",
			Handler = function (self, attacker, target, dmg, hit_descr)
				
				local function exec(self, attacker, target, dmg, hit_descr)
				target:AddStatusEffect("BattleFocusBuff")
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "DamageTaken" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, attacker, target, dmg, hit_descr)
				end
				
				if self:VerifyReaction("DamageTaken", reaction_def, target, attacker, target, dmg, hit_descr) then
					exec(self, attacker, target, dmg, hit_descr)
				end
			end,
			HandlerCode = function (self, attacker, target, dmg, hit_descr)
				target:AddStatusEffect("BattleFocusBuff")
			end,
		}),
	},
	'DisplayName', T(822626767198, --[[CharacterEffectCompositeDef BattleFocus DisplayName]] "Battle Focus"),
	'Description', T(235322784555, --[[CharacterEffectCompositeDef BattleFocus Description]] "Gain <em><battleFocusAP></em> <em>AP</em> when <em>hit</em> by an enemy for the <em>first</em> time.\n\nEnds at the end of combat."),
	'Icon', "UI/Icons/Perks/BattleFocus",
	'Tier', "Gold",
	'Stat', "Health",
	'StatValue', 90,
})
