-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Flanked')
DefineClass.Flanked = {
	__parents = { "StatusEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "StatusEffect",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnCalcDamageAndEffects",
			Handler = function (self, target, attacker, attack_target, action, weapon, attack_args, hit, data)
				if target == attack_target then
					local flankBonus = self:ResolveValue("bonus")
					data.base_damage = MulDivRound(data.base_damage, 100 + flankBonus, 100)
					data.breakdown[#data.breakdown + 1] = { name = self.DisplayName, value = flankBonus }
				end
			end,
		}),
	},
	DisplayName = T(529722665638, --[[CharacterEffectCompositeDef Flanked DisplayName]] "Flanked"),
	Description = T(938831848548, --[[CharacterEffectCompositeDef Flanked Description]] "Threatened from both sides. Attacks against this character have <em>+<percent(bonus)> increased damage</em>."),
	OnAdded = function (self, obj)
		if not obj:IsMerc() and IsNetPlayerTurn() then
			PlayVoiceResponse(obj, "AIFlanked")
		end
	end,
	type = "Debuff",
	Icon = "UI/Hud/Status effects/flanked",
	RemoveOnEndCombat = true,
	Shown = true,
}

