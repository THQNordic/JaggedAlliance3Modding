-- ========== GENERATED BY StatGainingPrerequisite Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('StatGainingPrerequisite', {
	Comment = "Moved a distance of at least <voxelsToMove> voxels after they were attacked in the previous turn",
	group = "Agility",
	id = "Fleeing",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "DamageDone",
			Handler = function (self, attacker, target, dmg, hit_descr)
				-- start tracking when attaked
				if not g_Combat or not IsMerc(target) then return end
				
				local state = GetPrerequisiteState(target, self.id)
				if not state then
					state = {UnitsMoved = 0}
					SetPrerequisiteState(target, self.id, state)
				end
			end,
		}),
		PlaceObj('MsgReaction', {
			Event = "UnitMovementDone",
			Handler = function (self, unit, action_id, prev_pos)
				-- track amount of movement if attacked
				if not g_Combat or not IsMerc(unit) or not prev_pos then return end
				
				local state = GetPrerequisiteState(unit, self.id)
				if state and state.UnitsMoved then
					-- calc movement and add to state
					state.UnitsMoved = state.UnitsMoved + unit:GetDist(prev_pos)
					if state.UnitsMoved / const.SlabSizeX >= self:ResolveValue("voxelsToMove") then
						SetPrerequisiteState(unit, self.id, state, "gain")
					else
						SetPrerequisiteState(unit, self.id, state)
					end
				end
			end,
		}),
		PlaceObj('MsgReaction', {
			Event = "TurnEnded",
			Handler = function (self, teamEnded)
				-- stop tracking on turn end
				local team = g_Teams[teamEnded]
				if team and team.player_team and team.units then
					for i, unit in ipairs(team.units) do
						SetPrerequisiteState(unit, self.id, false)
					end
				end
			end,
		}),
	},
	oncePerMapVisit = true,
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "voxelsToMove",
			'Value', 7,
			'Tag', "<voxelsToMove>",
		}),
	},
	relatedStat = "Agility",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Opened a combat while Hidden.",
	group = "Agility",
	id = "HiddenInitiation",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "CombatStart",
			Handler = function (self, dynamic_data)
				if g_Combat.stealth_attack_start then
					local unit = g_Combat.starting_unit
					if IsMerc(unit) then
						SetPrerequisiteState(unit, self.id, true, "gain")
					end
				end
			end,
		}),
	},
	relatedStat = "Agility",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Accumulated <APToSpend> AP of movement in combat (including free move)",
	group = "Agility",
	id = "MovementAPSpent",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "UnitAPChanged",
			Handler = function (self, unit, action_id, change)
				if not (g_Combat and IsMerc(unit) and action_id == "Move" and change and change < 0) then return end
				
				local state = GetPrerequisiteState(unit, self.id)
				if not state or not state.APSpent then
					state = {APSpent = 0}
				end
					
				state.APSpent = state.APSpent + abs(change)
				if state.APSpent < self:ResolveValue("APToSpend") * const.Scale.AP then
					SetPrerequisiteState(unit, self.id, state)
				else
					SetPrerequisiteState(unit, self.id, state, "gain")
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "APToSpend",
			'Value', 20,
			'Tag', "<APToSpend>",
		}),
	},
	relatedStat = "Agility",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Killed with an aimed shot (at least one aim)",
	failChance = 75,
	group = "Dexterity",
	id = "AimedKill",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and target and attacker:IsOnEnemySide(target) and action and action.ActionType == "Ranged Attack" then
					if results.aim and results.aim > 0 then
						if results.killed_units and #results.killed_units > 0 and table.find(results.killed_units, target) then
							SetPrerequisiteState(attacker, self.id, true, "gain")
						end
					end
				end
			end,
		}),
	},
	relatedStat = "Dexterity",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Killed with an aimed melee attack (at least one aim)",
	failChance = 50,
	group = "Dexterity",
	id = "AimedMeleeKill",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and target and attacker:IsOnEnemySide(target) and action and action.ActionType == "Melee Attack" then
					if results.aim and results.aim > 0 then
						if results.killed_units and #results.killed_units > 0 and table.find(results.killed_units, target) then
							SetPrerequisiteState(attacker, self.id, true, "gain")
						end
					end
				end
			end,
		}),
	},
	relatedStat = "Dexterity",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Successful stealth kill",
	failChance = 25,
	group = "Dexterity",
	id = "StealthKill",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and attacker:HasStatusEffect("Hidden") then
					if EnemiesKilled(attacker, results) > 0 then
						SetPrerequisiteState(attacker, self.id, true, "gain")
					end
				end
			end,
		}),
	},
	relatedStat = "Dexterity",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Killed with a throwing knife",
	group = "Dexterity",
	id = "ThrowingKnifeKill",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and results.weapon and IsKindOf(results.weapon, "MeleeWeapon") then
					if action and action.ActionType == "Ranged Attack" then
						if EnemiesKilled(attacker, results) > 0 then
							SetPrerequisiteState(attacker, self.id, true, "gain")
						end
					end
				end
			end,
		}),
	},
	relatedStat = "Dexterity",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Hit <enemiesToHit>+ enemies with a single grenade/heavy weapon shot",
	failChance = 10,
	group = "Explosives",
	id = "ExplosiveMultiHit",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if not IsMerc(attacker) then return end
				if results.weapon and IsKindOfClasses(results.weapon, "Grenade", "HeavyWeapon", "Ordnance") and results.hit_objs then
					local hitEnemies = 0
					for i, obj in ipairs(results.hit_objs) do
						if IsKindOf(obj, "Unit") and attacker:IsOnEnemySide(obj) then
							hitEnemies = hitEnemies + 1
						end
					end
					if hitEnemies >= self:ResolveValue("enemiesToHit") then
						SetPrerequisiteState(attacker, self.id, true, "gain")
					end
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "enemiesToHit",
			'Value', 2,
			'Tag', "<enemiesToHit>",
		}),
	},
	relatedStat = "Explosives",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Successfully craft explosives",
	group = "Explosives",
	id = "ExplosivesCraft",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "CombineItemsSuccess",
			Handler = function (self, unit, skill_type)
				if not IsMerc(unit) then return end
				if skill_type == "Explosives" then
					SetPrerequisiteState(unit, self.id, true, "gain")
				end
			end,
		}),
	},
	relatedStat = "Explosives",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Disarmed an explosive trap",
	group = "Explosives",
	id = "TrapDisarmExplosives",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "TrapDisarm",
			Handler = function (self, trap, unit, success, stat)
				if not IsMerc(unit) then return end
				if success and stat == "Explosives" then
					SetPrerequisiteState(unit, self.id, true, "gain")
				end
			end,
		}),
	},
	oncePerMapVisit = true,
	relatedStat = "Explosives",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Accumulated <damageToAccumulate> HP of damage.",
	group = "Health",
	id = "LostHealth",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "DamageDone",
			Handler = function (self, attacker, target, dmg, hit_descr)
				if not g_Combat or not IsMerc(target) or dmg <= 0 then return end
				
				local state = GetPrerequisiteState(target, self.id)
				if not state or type(state) ~= "table" or not state.LostHealth then
					state = {LostHealth = 0}
				end
				
				state.LostHealth = state.LostHealth  + dmg
				if state.LostHealth < self:ResolveValue("damageToAccumulate") then
					SetPrerequisiteState(target, self.id, state)
				else
					SetPrerequisiteState(target, self.id, state, "gain")
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "damageToAccumulate",
			'Value', 80,
			'Tag', "<damageToAccumulate>",
		}),
	},
	relatedStat = "Health",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Recovered from a wound",
	failChance = 10,
	group = "Health",
	id = "WoundRecovery",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				if IsMerc(obj) and id == "Wounded" and stacks > 0 and reason ~= "death" then
					SetPrerequisiteState(obj, self.id, true, "gain")
				end
			end,
		}),
	},
	relatedStat = "Health",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Spent at least <hoursToSpend> hours to train mercs (activity)",
	group = "Leadership",
	id = "MercTraining",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OperationChanged",
			Handler = function (self, unit, oldOperation, newOperation, prevProfession, interrupted)
				if IsMerc(unit) then
				-- Track start time of training activity
					if newOperation and newOperation.id == "TrainMercs" and unit.OperationProfession == "Teacher" then
						local state = GetPrerequisiteState(unit, self.id) or {}
						state.startTime = Game.CampaignTime
						SetPrerequisiteState(unit, self.id, state)
				-- Accumulate time spent at end of activity
					elseif oldOperation and oldOperation.id == "TrainMercs" and unit.OperationProfession ~= "Teacher" then
						local state = GetPrerequisiteState(unit, self.id) or {}
						if not state.startTime or state.startTime == 0 then return end
						state.timeSpent = (state.timeSpent or 0) + (Game.CampaignTime - state.startTime)
						state.startTime = 0
						if DivRound(state.timeSpent, const.Scale.h) >= self:ResolveValue("hoursToSpend") then
							SetPrerequisiteState(unit, self.id, state, "gain")
						else
							SetPrerequisiteState(unit, self.id, state)
						end
					end
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "hoursToSpend",
			'Value', 12,
			'Tag', "<hoursToSpend>",
		}),
	},
	relatedStat = "Leadership",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Spent at least <hoursToSpend> hours to train militia (activity)",
	group = "Leadership",
	id = "MilitiaTraining",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OperationChanged",
			Handler = function (self, unit, oldOperation, newOperation, prevProfession, interrupted)
				if IsMerc(unit) then
				-- Track start time of training activity
					if newOperation and newOperation.id == "MilitiaTraining" and unit.OperationProfession == "Trainer" then
						local state = GetPrerequisiteState(unit, self.id) or {}
						state.startTime = Game.CampaignTime
						SetPrerequisiteState(unit, self.id, state)
				-- Accumulate time spent at end of activity
					elseif oldOperation and oldOperation.id == "MilitiaTraining" and unit.OperationProfession ~= "Trainer" then
						local state = GetPrerequisiteState(unit, self.id) or {}
						if not state.startTime or state.startTime == 0 then return end
						state.timeSpent = (state.timeSpent or 0) + (Game.CampaignTime - state.startTime)
						state.startTime = 0
						if DivRound(state.timeSpent, const.Scale.h) >= self:ResolveValue("hoursToSpend") then
							SetPrerequisiteState(unit, self.id, state, "gain")
						else
							SetPrerequisiteState(unit, self.id, state)
						end
					end
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "hoursToSpend",
			'Value', 12,
			'Tag', "<hoursToSpend>",
		}),
	},
	relatedStat = "Leadership",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Accumulated <damageToAccumulate> inflicted damage to enemies with firearms",
	group = "Marksmanship",
	id = "FirearmDamageDone",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and target and attacker:IsOnEnemySide(target) and IsKindOf(results.weapon, "Firearm") and results.total_damage and not results.miss then
					local state = GetPrerequisiteState(attacker, self.id)
					if not state or not state.FirearmDamage then
						state = {FirearmDamage = 0}
					end
					
					state.FirearmDamage = state.FirearmDamage + results.total_damage
					if state.FirearmDamage < self:ResolveValue("damageToAccumulate") then
						SetPrerequisiteState(attacker, self.id, state)
					else
						SetPrerequisiteState(attacker, self.id, state, "gain")
					end
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "damageToAccumulate",
			'Value', 110,
			'Tag', "<damageToAccumulate>",
		}),
	},
	relatedStat = "Marksmanship",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Kill an enemy with precise attack against him at <=<maxChanceToHit>% hit chance.",
	group = "Marksmanship",
	id = "PreciseKill",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if not IsMerc(attacker) or not target or not IsKindOf(target, "Unit") or not attacker:IsOnEnemySide(target) then return end
				if results.weapon and IsKindOf(results.weapon, "Firearm") and results.chance_to_hit and results.chance_to_hit <= self:ResolveValue("maxChanceToHit") and results.fired and results.fired == 1 then
					if results.killed_units and table.find(results.killed_units, target) then
						SetPrerequisiteState(attacker, self.id, true, "gain")
					end
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamPercent', {
			'Name', "maxChanceToHit",
			'Value', 30,
			'Tag', "<maxChanceToHit>%",
		}),
	},
	relatedStat = "Marksmanship",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Finished a mechanical activity in the satellite view lasting <hoursToSpend>+ hours",
	group = "Mechanical",
	id = "Mechanic",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OperationChanged",
			Handler = function (self, unit, oldOperation, newOperation, prevProfession, interrupted)
				if IsMerc(unit) then
				-- Track start time of training activity
					if newOperation and newOperation.id == "RepairItems" and unit.OperationProfession == "Repair" then
						local state = GetPrerequisiteState(unit, self.id) or {}
						state.startTime = Game.CampaignTime
						SetPrerequisiteState(unit, self.id, state)
				-- Accumulate time spent at end of activity
					elseif oldOperation and oldOperation.id == "RepairItems" and unit.OperationProfession ~= "Repair" then
						local state = GetPrerequisiteState(unit, self.id) or {}
						if not state.startTime or state.startTime == 0 then return end
						state.timeSpent = (state.timeSpent or 0) + (Game.CampaignTime - state.startTime)
						state.startTime = 0
						if DivRound(state.timeSpent, const.Scale.h) >= self:ResolveValue("hoursToSpend") then
							SetPrerequisiteState(unit, self.id, state, "gain")
						else
							SetPrerequisiteState(unit, self.id, state)
						end
					end
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "hoursToSpend",
			'Value', 24,
			'Tag', "<hoursToSpend>",
		}),
	},
	relatedStat = "Mechanical",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Disarmed a mechanical trap",
	group = "Mechanical",
	id = "TrapDisarmMechanical",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "TrapDisarm",
			Handler = function (self, trap, unit, success, stat)
				if not IsMerc(unit) then return end
				if success and stat == "Mechanical" then
					SetPrerequisiteState(unit, self.id, true, "gain")
				end
			end,
		}),
	},
	oncePerMapVisit = true,
	relatedStat = "Mechanical",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Upgraded a weapon.",
	group = "Mechanical",
	id = "WeaponModification",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "WeaponModifiedSuccessSync",
			Handler = function (self, weapon, owner, modAdded, mechanic)
				if IsMerc(mechanic) then
					SetPrerequisiteState(mechanic, self.id, true, "gain")
				end
			end,
		}),
	},
	relatedStat = "Mechanical",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Finished a Doctor activity in the satellite view lasting <hoursToSpend>+ hours",
	group = "Medical",
	id = "Doctor",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OperationChanged",
			Handler = function (self, unit, oldOperation, newOperation, prevProfession, interrupted)
				if IsMerc(unit) then
				-- Track start time of training activity
					if newOperation and newOperation.id == "TreatWounds" and unit.OperationProfession == "Doctor" then
						local state = GetPrerequisiteState(unit, self.id) or {}
						state.startTime = Game.CampaignTime
						SetPrerequisiteState(unit, self.id, state)
				-- Accumulate time spent at end of activity
					elseif oldOperation and oldOperation.id == "TreatWounds" and unit.OperationProfession ~= "Doctor" then
						local state = GetPrerequisiteState(unit, self.id) or {}
						if not state.startTime or state.startTime == 0 then return end
						state.timeSpent = (state.timeSpent or 0) + (Game.CampaignTime - state.startTime)
						state.startTime = 0
						if DivRound(state.timeSpent, const.Scale.h) >= self:ResolveValue("hoursToSpend") then
							SetPrerequisiteState(unit, self.id, state, "gain")
						else
							SetPrerequisiteState(unit, self.id, state)
						end
					end
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "hoursToSpend",
			'Value', 24,
			'Tag', "<hoursToSpend>",
		}),
	},
	relatedStat = "Medical",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Accumulated <healingToAccumulate> health healed with Bandage.",
	group = "Medical",
	id = "Healing",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnBandage",
			Handler = function (self, healer, target, healAmount)
				if IsMerc(healer) then
					local state = GetPrerequisiteState(healer, self.id)
					if not state or not state.HealingDone then
						state = {HealingDone = 0}
					end
					
					state.HealingDone = state.HealingDone + healAmount
					if state.HealingDone < self:ResolveValue("healingToAccumulate") then
						SetPrerequisiteState(healer, self.id, state)
					else
						SetPrerequisiteState(healer, self.id, state, "gain")
					end
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "healingToAccumulate",
			'Value', 25,
			'Tag', "<healingToAccumulate>",
		}),
	},
	relatedStat = "Medical",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Revived a downed teammate.",
	group = "Medical",
	id = "RallyDowned",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnDownedRally",
			Handler = function (self, healer, target)
				if IsMerc(healer) then
					SetPrerequisiteState(healer, self.id, true, "gain")
				end
			end,
		}),
	},
	relatedStat = "Medical",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Killed with a melee crit",
	group = "Strength",
	id = "MeleeCritKill",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and results.weapon and IsKindOf(results.weapon, "MeleeWeapon") then
					if action and action.ActionType == "Melee Attack" then
						if EnemiesKilled(attacker, results) > 0 then 
							if table.find(results.hits, "critical", true) then
								SetPrerequisiteState(attacker, self.id, true, "gain")
							end
						end
					end
				end
			end,
		}),
	},
	relatedStat = "Strength",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Accumulated <damageToAccumulate> inflicted damage to enemies with melee weapons.",
	group = "Strength",
	id = "MeleeDamageDone",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and target and attacker:IsOnEnemySide(target) and results.melee_attack and results.total_damage then
					local state = GetPrerequisiteState(attacker, self.id)
					if not state or not state.MeleeDamage then
						state = {MeleeDamage = 0}
					end
					
					state.MeleeDamage = state.MeleeDamage + results.total_damage
					if state.MeleeDamage < self:ResolveValue("damageToAccumulate") then
						SetPrerequisiteState(attacker, self.id, state)
					else
						SetPrerequisiteState(attacker, self.id, state, "gain")
					end
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "damageToAccumulate",
			'Value', 50,
			'Tag', "<damageToAccumulate>",
		}),
	},
	relatedStat = "Strength",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Killed <toKill> enemies in melee within the same combat.",
	group = "Strength",
	id = "MeleeDoubleKill",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and results.weapon and IsKindOf(results.weapon, "MeleeWeapon") then
					if action and action.ActionType == "Melee Attack" then
						local killed = EnemiesKilled(attacker, results)
						if killed > 0 then
								local state = (GetPrerequisiteState(attacker, self.id) or {KilledInMelee = 0})
								state.KilledInMelee = state.KilledInMelee + killed
								if state.KilledInMelee >= self:ResolveValue("toKill") then
									SetPrerequisiteState(attacker, self.id, state, "gain")
								else
									SetPrerequisiteState(attacker, self.id, state)
								end
						end
					end
				end
			end,
		}),
		PlaceObj('MsgReaction', {
			Event = "CombatEnd",
			Handler = function (self, combat, anyEnemies)
				local units = GetPlayerMercsInSector(gv_CurrentSectorId)
				
				for _, unitId in ipairs(units) do
					local unit = gv_SatelliteView and gv_UnitData[unitId] or g_Units[unitId]
					if unit then
						SetPrerequisiteState(unit, self.id, false)
					end
				end
			end,
		}),
	},
	parameters = {
		PlaceObj('PresetParamNumber', {
			'Name', "toKill",
			'Value', 2,
			'Tag', "<toKill>",
		}),
	},
	relatedStat = "Strength",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Discovered hidden herbs/parts",
	group = "Wisdom",
	id = "ResourceDiscovery",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "GrantMarkerDiscovered",
			Handler = function (self, unit, marker)
				if IsMerc(unit) then
					SetPrerequisiteState(unit, self.id, true, "gain")
				end
			end,
		}),
	},
	oncePerMapVisit = true,
	relatedStat = "Wisdom",
})

PlaceObj('StatGainingPrerequisite', {
	Comment = "Discovered a trap (e.g. mine)",
	group = "Wisdom",
	id = "TrapDiscovery",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "TrapDiscovered",
			Handler = function (self, trap, unit)
				if IsMerc(unit) then
					SetPrerequisiteState(unit, self.id, true, "gain")
				end
			end,
		}),
	},
	oncePerMapVisit = true,
	relatedStat = "Wisdom",
})

