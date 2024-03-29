-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('LightningReactionNPC')
DefineClass.LightningReactionNPC = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnFirearmAttackStart",
			Handler = function (self, target, attacker, attack_target, action, attack_args)
				if target == attack_target and not self:ResolveValue("used") or not target:IsAware() then
					if target:LightningReactionCheck(self) then
						self:SetParameter("used", true)
						attack_args.chance_to_hit = 0
					end
				end
			end,
		}),
		PlaceObj('UnitReaction', {
			Event = "OnCombatEnd",
			Handler = function (self, target)
				self:SetParameter("used", false)
			end,
		}),
	},
	DisplayName = T(324416282125, --[[CharacterEffectCompositeDef LightningReactionNPC DisplayName]] "Lightning Reactions"),
	Description = T(909336375572, --[[CharacterEffectCompositeDef LightningReactionNPC Description]] "<em>Dodge</em> the first successful enemy attack by falling <GameTerm('Prone')>.\n\nOnce per combat"),
	Icon = "UI/Icons/Perks/LightningReaction",
}

