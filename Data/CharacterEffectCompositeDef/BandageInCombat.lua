-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System",
	'Id', "BandageInCombat",
	'Comment', "handles the logic for the unit bandaging a downed unit",
	'object_class', "StatusEffect",
	'unit_reactions', {
		PlaceObj('UnitReaction', {
			Event = "OnBeginTurn",
			Handler = function (self, target)
				local patient = target:GetBandageTarget()
				local medicine = target:GetBandageMedicine()
				if not patient or not medicine or patient.command == "Die" or patient:IsDead() or patient.HitPoints >= patient.MaxHitPoints then
					target:RemoveStatusEffect("BandageInCombat")
				end
			end,
		}),
		PlaceObj('UnitReaction', {
			Event = "OnEndTurn",
			Handler = function (self, target)
				local patient = target:GetBandageTarget()
				local medicine = target:GetBandageMedicine()
				if not IsValid(patient) or patient.command == "Die" or patient:IsDead() or patient.HitPoints >= patient.MaxHitPoints then
					target:RemoveStatusEffect(self.class)
					return
				end
				if patient:IsDowned() then
					local stabilized = patient:GetStatusEffect("Stabilized")
					stabilized = stabilized and stabilized:ResolveValue("stabilized")
					if stabilized or RollSkillCheck(target, "Medical") then
						patient:SetCommand("DownedRally", target, medicine)
					else
						patient:AddStatusEffect("Stabilized")
					end
				else
					patient:GetBandaged(medicine, target)
					if patient.HitPoints >= patient.MaxHitPoints then
						patient:RemoveStatusEffect("BeingBandaged")
						target:RemoveStatusEffect(self.class)
					end
				end
			end,
		}),
	},
	'DisplayName', T(725524260335, --[[CharacterEffectCompositeDef BandageInCombat DisplayName]] "Treating"),
	'Description', T(829769124050, --[[CharacterEffectCompositeDef BandageInCombat Description]] "Bandaging an ally. No more actions available this turn. Effectiveness of the action depends on Medical skill."),
	'OnAdded', function (self, obj)
		local target = obj:GetBandageTarget()
		if target then
			target:RemoveStatusEffect("Downed")
			target:RemoveStatusEffect("BleedingOut")
		end
		obj:RemoveStatusEffect("FreeMove")
	end,
	'OnRemoved', function (self, obj)
		local target = obj:GetBandageTarget()
		if not target or not g_Combat then return end
		target:RemoveStatusEffect("BeingBandaged")
		if target and not target:IsDead() and target:IsDowned() and not target:HasStatusEffect("Unconscious") then
			target:RemoveStatusEffect("Stabilized")
			target:AddStatusEffect("BleedingOut")
		end
		
		if not obj:IsDead() then
			obj:ClearBehaviors("Bandage")
			if CurrentThread() == obj.command_thread then
				obj:QueueCommand("EndCombatBandage") -- make sure it does not break the RemoveStatusEffect call
			else
				obj:SetCommand("EndCombatBandage")
			end
		end
	end,
	'Icon', "UI/Hud/Status effects/treating",
	'RemoveOnSatViewTravel', true,
	'Shown', true,
})

