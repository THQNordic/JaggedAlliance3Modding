-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Id', "Wounded",
	'Parameters', {
		PlaceObj('PresetParamNumber', {
			'Name', "MaxHpReductionPerStack",
			'Value', 10,
			'Tag', "<MaxHpReductionPerStack>",
		}),
		PlaceObj('PresetParamPercent', {
			'Name', "MinMaxHp",
			'Value', 30,
			'Tag', "<MinMaxHp>%",
		}),
		PlaceObj('PresetParamNumber', {
			'Name', "HpLossToAddStack",
			'Value', 16,
			'Tag', "<HpLossToAddStack>",
		}),
		PlaceObj('PresetParamPercent', {
			'Name', "WoundsImmunityThreshold",
			'Value', 80,
			'Tag', "<WoundsImmunityThreshold>%",
		}),
	},
	'Comment', "effects implemented in RecalcMaxHitPoints;",
	'object_class', "StatusEffect",
	'msg_reactions', {},
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnStatusEffectAdded",
			Handler = function (self, target, id, stacks)
				if self.class == id then
					-- handle add/remove stacks
					RecalcMaxHitPoints(target)
				end
			end,
		}),
		PlaceObj('UnitReaction', {
			Event = "OnStatusEffectRemoved",
			Handler = function (self, target, id, stacks_remaining)
				if self.class == id and stacks_remaining > 0 then
					-- handle add/remove stacks
					RecalcMaxHitPoints(target)	
				end
			end,
		}),
	},
	'DisplayName', T(646181611891, --[[CharacterEffectCompositeDef Wounded DisplayName]] "Wounded"),
	'Description', T(625596846196, --[[CharacterEffectCompositeDef Wounded Description]] "Maximum <em>HP reduced by <MaxHpReductionPerStack></em> per wound. Cured by the <em>Treat Wounds</em> Operation in the Sat View.\n\n<if(IsGameRuleActive('HeavyWounds'))>Wounds also progressively impair <em>Accuracy</em> and <em>Free Move</em> due to the Heavy Wounds game rule.</if>"),
	'OnAdded', function (self, obj)
		RecalcMaxHitPoints(obj)
		
		if not IsKindOf(obj, "Unit") then
			return
		end
		
		if not obj:HasStainType("Blood") then
			local spot = obj:GetEffectValue("wounded_stain_spot")
			if spot then
				obj:AddStain("Blood", spot)
			end
		end
		
		if not obj.wounded_this_turn and GameState.Heat then
			if not RollSkillCheck(obj, "Health") then
				obj:ChangeTired(1)
			end
		end
		local attackObj = obj.hit_this_turn and obj.hit_this_turn[#obj.hit_this_turn]
		local friendlyFire = attackObj and attackObj.team and obj.team and attackObj.team :IsAllySide(obj.team)
		local effect = obj:GetStatusEffect("Wounded")
		if effect.stacks >= 4 and obj:IsMerc() and not friendlyFire then
			PlayVoiceResponse(obj, "SeriouslyWounded")
		elseif not friendlyFire then
			PlayVoiceResponse(obj, "Wounded")
		end
		obj.wounded_this_turn = true
	end,
	'OnRemoved', function (self, obj)
		RecalcMaxHitPoints(obj)
		if obj:IsKindOf("Unit") and not obj:IsDead() then
			obj:ClearStains("Blood")
		end
	end,
	'type', "Debuff",
	'Icon', "UI/Hud/Status effects/wounded",
	'max_stacks', 999,
	'Shown', true,
	'ShownSatelliteView', true,
})

