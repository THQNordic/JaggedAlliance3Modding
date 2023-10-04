-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('LuckyStreak')
DefineClass.LuckyStreak = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	msg_reactions = {
		PlaceObj('MsgActorReaction', {
			ActorParam = "attacker",
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				
				local function exec(self, attacker, action, target, results, attack_args)
				if results.crit and IsKindOf(target, "Unit") then
					attacker:AddStatusEffect("LuckyStreakBuff")
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "OnAttack" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, attacker, action, target, results, attack_args)
				end
				
				if self:VerifyReaction("OnAttack", reaction_def, attacker, attacker, action, target, results, attack_args) then
					exec(self, attacker, action, target, results, attack_args)
				end
			end,
			HandlerCode = function (self, attacker, action, target, results, attack_args)
				if results.crit and IsKindOf(target, "Unit") then
					attacker:AddStatusEffect("LuckyStreakBuff")
				end
			end,
		}),
	},
	DisplayName = T(838318520600, --[[CharacterEffectCompositeDef LuckyStreak DisplayName]] "Lucky Streak"),
	Description = T(350209296951, --[[CharacterEffectCompositeDef LuckyStreak Description]] "Become <GameTerm('Inspired')> when you make <em><crits_number></em> <GameTerm('Crits')> in the <em>same</em> turn."),
	Icon = "UI/Icons/Perks/LuckyStreak",
	Tier = "Gold",
	Stat = "Agility",
	StatValue = 90,
}
