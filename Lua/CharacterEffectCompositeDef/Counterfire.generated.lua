-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Counterfire')
DefineClass.Counterfire = {
	__parents = { "Perk" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "Perk",
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnUnitAttack",
			Handler = function (self, target, attacker, action, attack_target, results, attack_args)
				if target == attacker and attack_args and attack_args.opportunity_attack_type == "Overwatch" and not results.miss then
					local count = self:ResolveValue("counter") + 1
					if count >= self:ResolveValue("hitsRequired") then
						target:AddStatusEffect("Inspired")
						count = 0
					end
					self:SetParameter("counter", count)
				end
			end,
		}),
		PlaceObj('UnitReaction', {
			Event = "OnBeginTurn",
			Handler = function (self, target)
				self:SetParameter("counter", 0)
			end,
		}),
	},
	DisplayName = T(680739063564, --[[CharacterEffectCompositeDef Counterfire DisplayName]] "Fire Routine"),
	Description = T(857967049165, --[[CharacterEffectCompositeDef Counterfire Description]] "Become <GameTerm('Inspired')> after you land <em><hitsRequired> hits</em> while in <GameTerm('Overwatch')>."),
	OnAdded = function (self, obj)
		self:SetParameter("counter", 0)
	end,
	Icon = "UI/Icons/Perks/Counterfire",
	Tier = "Silver",
	Stat = "Dexterity",
	StatValue = 80,
}

