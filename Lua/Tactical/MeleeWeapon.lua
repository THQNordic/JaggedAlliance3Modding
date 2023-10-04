DefineClass.MeleeWeapon = {
	__parents = { "InventoryItem", "MeleeWeaponProperties", "BaseWeapon" },
	WeaponType = "MeleeWeapon",
	ImpactForce = 2,
	base_skill = "Dexterity",
	base_action = "MeleeAttack",

	ComponentSlots = {},
	Color = "Default",
	components = {},
	
	neck_attack_descriptions = {
		["choke"] = T(545528819211, "<newline><newline>Unarmed: Inflicts <em>Choking</em> on hit."),
		["bleed"] = T(251225177855, "<newline><newline>Knife: Inflicts <em>Bleeding</em> on hit."),
		["lethal"] = T(775626326541, "<newline><newline>Machete: Chance for a lethal attack based on your Strength."),
	},
}

function MeleeWeapon:GetRolloverType()
	return self.ItemType or "MeleeWeapon"
end

function MeleeWeapon:GetAccuracy(dist, unit, action, ranged)
	if not ranged then
		return self.BaseChanceToHit
	end
	return GetRangeAccuracy(self, dist, unit, action)
end

function MeleeWeapon:GetBaseAttack(unit, force)
	return self.base_action
end

function MeleeWeapon:GetCustomNeckAttackDescription()
	return self.neck_attack_descriptions[self.NeckAttackType]
end

function MeleeWeapon:PrecalcDamageAndStatusEffects(attacker, target, attack_pos, damage, hit, effect, attack_args, record_breakdown, action, prediction)
	local effects = EffectsTable(effect)
	local strMod = MulDivRound(attacker.Strength, self.DamageMultiplier, 100)
	if record_breakdown then record_breakdown[#record_breakdown + 1] = { name = T(162618960967, "Strength"), value = strMod } end
	local mod = 100 + strMod
	mod = mod + (hit.damage_bonus or 0)

	local actionType = hit.actionType
	if actionType == "Melee Attack" then
		local drunk = attacker:GetStatusEffect("Drunk")
		if drunk then
			local drunkBonus = drunk:ResolveValue("melee_damage_mod")
			mod = mod + drunkBonus
			if record_breakdown then record_breakdown[#record_breakdown + 1] = { name = drunk.DisplayName, value = drunkBonus } end
		end
		
		if IsKindOf(target, "Unit") then
			if target.species == "Human" and target.stance == "Prone" then
				local value = const.Combat.MeleeAttackProneMod
				mod = mod + value
				if record_breakdown then record_breakdown[#record_breakdown + 1] = { name = T(848625832174, "Prone Target"), value = value } end
			end
		end
	end
	damage = MulDivRound(damage, mod, 100)
	BaseWeapon.PrecalcDamageAndStatusEffects(self, attacker, target, attack_pos, damage, hit, effects, attack_args, record_breakdown, action, prediction)
end

function MeleeWeapon:GetAttackResults(action, attack_args)
	-- unpack some params & init default values
	local attacker = attack_args.obj
	local attack_pos = attack_args.step_pos
	local target = attack_args.target or attack_args.target_pos

	local prediction = attack_args.prediction
	local stealth_kill_chance = attack_args.stealth_kill_chance or 0
	local stealth_crit_chance = attack_args.stealth_bonus_crit_chance or 0

	-- attack/crit rolls
	local attack_results = {}
	attack_results.crit_chance = attacker:CalcCritChance(self, target, attack_args.aim, attack_pos, attack_args.target_spot_group) + stealth_crit_chance
	
	if action.AlwaysHits then
		attack_results.chance_to_hit = 100
	elseif attack_args.cth_breakdown then
		local cth, baseCth, modifiers = attacker:CalcChanceToHit(target, action, attack_args)
		attack_results.chance_to_hit = cth
		attack_results.chance_to_hit_modifiers = modifiers
	else
		attack_results.chance_to_hit = attacker:CalcChanceToHit(target, action, attack_args, "chance_only")
	end
	if IsKindOf(target, "Unit") and action.id == "UnarmedAttack" then
		attack_results.knockdown_chance = Max(0, 20 + attacker.Strength - target.Agility)
	else
		attack_results.knockdown_chance = 0
	end	
	if attack_args.chance_only and not attack_args.damage_breakdown then return attack_results end

	if prediction then
		attack_results.attack_roll = -1
		attack_results.knockdown_roll = 101
		attack_results.crit_roll = 101
		if stealth_kill_chance > 0 then
			attack_args.stealth_kill_roll = 101
		end
	else
		attack_results.attack_roll = attack_args.attack_roll or attacker:Random(100) -- todo: remove the random, assert there's a valid roll
		attack_results.crit_roll = attack_args.crit_roll or attacker:Random(100)
		if stealth_kill_chance > 0 then
			attack_args.stealth_kill_roll = attack_args.stealth_kill_roll or attacker:Random(100)
		end
		if attack_results.knockdown_chance > 0 then
			attack_results.knockdown_roll = attacker:Random(100)
		else
			attack_results.knockdown_roll = 100
		end
	end

	local miss = attack_results.attack_roll >= attack_results.chance_to_hit
	local crit = attack_results.crit_roll < attack_results.crit_chance
	local knockdown = attack_results.knockdown_roll < attack_results.knockdown_chance
	local kill
	if not miss and stealth_kill_chance > 0 then
		kill = attack_args.stealth_kill_roll < stealth_kill_chance
	end

	attack_results.weapon = self
	attack_results.crit = crit
	attack_results.stealth_attack = attack_args.stealth_attack
	attack_results.stealth_kill_chance = stealth_kill_chance
	attack_results.stealth_kill = kill
	attack_results.num_hits = miss and 0 or 1
	attack_results.friendly_fire_dmg = 0
	attack_results.killed_units = false	
	attack_results.attack_pos = attack_pos
	attack_results.hit_objs = {}
	attack_results.aim = attack_args.aim
	attack_results.dmg_breakdown = attack_args.damage_breakdown and {} or false
	attack_results.lof = attack_args.lof

	local target_grazing_hit, stuck
	if action.ActionType == "Ranged Attack" then -- throw
		-- create trajectory and store in attack_results.trajectory
		local lof_params = {
			obj = attacker,
			output_collisions = true,
			range = range,
			max_pierced_objects = 0,
			target_spot_group = "Torso",
			action_id  = action.id,
			seed = prediction and 0 or attacker:Random(),
			step_pos = attack_args.step_pos or nil,
		}
		local attack_data = GetLoFData(attacker, target, lof_params)
		assert(attack_data)
		local lof_idx = table.find(attack_data.lof, "target_spot_group", attack_data.target_spot_group)
		local lof_data = attack_data.lof[lof_idx or 1]

		if not lof_data or lof_data.stuck then
			attack_results.chance_to_hit = 0
			stuck = true
			local mods = attack_results.chance_to_hit_modifiers or {}
			mods[#mods + 1] = {
				{
					id = "NoLineOfFire",
					name = T(604792341662, "No Line of Fire"),
					value = 0
				}
			}
		end

		local attack_pos = lof_data.attack_pos
		local hit_pos = lof_data.target_pos
		target_grazing_hit = not lof_data.stuck and lof_data.target_grazing_hit

		if miss and not prediction then
			local dispersion = Firearm:GetMaxDispersion(attacker:GetDist(target))
			local misses = Firearm:CalcMissVectors(attacker, action.id, target, attack_pos, hit_pos, dispersion, 10*guic)

			local main, backup = misses.clear, misses.obstructed
			local tbl = #main > 0 and main or backup
			assert(#tbl > 0)

			-- overwrite hit_pos to create a different first part of the trajectory
			hit_pos = table.interaction_rand(tbl, "Combat")					
		end

		-- create the first part of the trajectory (attack_pos -> hit_pos)
		local throw_velocity = const.Combat.KnifeThrowVelocity
		local dist = attack_pos:Dist(hit_pos)
		local tth = MulDivRound(dist, 1000, throw_velocity)
		attack_results.trajectory = {
			{ pos = attack_pos, t = 0 },
			{ pos = hit_pos, t = tth },
		}

		-- add parabolic bounce movement on miss
		if miss and hit_pos:IsValidZ() and hit_pos:z() > terrain.GetHeight(hit_pos) then
			local throw_vector = hit_pos - attack_pos
			if throw_vector:Len() == 0 then
				throw_vector = Rotate(point(guim, 0, 0), attacker:GetAngle())
			end
			local bounce_diminish = const.Combat.KnifeBounceVelocityLoss
			local trajectory = CalcBounceParabolaTrajectory(hit_pos, SetLen(throw_vector, throw_velocity), const.Combat.Gravity, 10000, 20, 0, bounce_diminish)
			for _, step in ipairs(trajectory) do
				if step.t > 0 then -- skip starting position as it is already in attack_results.trajectory
					step.t = step.t + tth
					attack_results.trajectory[#attack_results.trajectory + 1] = step
				end
			end
		end
		miss = miss or not lof_data or lof_data.stuck
	else -- not a throw
		attack_results.melee_attack = true
	end

	local total_damage = 0
	if not miss then
		local hit = { 
			obj = target, 
			stealth_kill = kill, 
			stealth_crit = crit and (stealth_crit_chance > 0), 
			weapon = self,
			critical = crit,
			spot_group = attack_args.target_spot_group,
			actionType = action.ActionType,
			damage_bonus = attack_args.damage_bonus,
			impact_force = self:GetImpactForce(),
			melee_attack = attack_results.melee_attack,
			grazing = target_grazing_hit,
		}

		local record_breakdown = attack_results.dmg_breakdown
		if record_breakdown and attack_args.damage_bonus then
			record_breakdown[#record_breakdown + 1] = { name = action and action.DisplayName or T(328963668848, "Base"), value = attack_args.damage_bonus }
		end

		local damage = attacker:GetBaseDamage(self, nil, attack_results.dmg_breakdown)
		if not prediction then
			damage = RandomizeWeaponDamage(damage)
		end
		local effects = attack_args.applied_status
		if knockdown then
			effects = EffectsTable(effects)
			EffectTableAdd(effects, "KnockDown")
		end
		if attack_args.target_spot_group == "Neck" then
			if self.NeckAttackType == "choke" then
				effects = EffectsTable(effects)
				EffectTableAdd(effects, "Choking")
			elseif self.NeckAttackType == "bleed" then
				effects = EffectsTable(effects)
				EffectTableAdd(effects, "Bleeding")
			elseif self.NeckAttackType == "lethal" and kill then
				attack_results.decapitate = true
			end
		end
		self:PrecalcDamageAndStatusEffects(attacker, target, attack_pos, damage, hit, effects, attack_args, record_breakdown, action, prediction)
		total_damage = total_damage + hit.damage
		if kill then
			hit.damage = MulDivRound(target:GetTotalHitPoints(), 125, 100)
		end
		attack_results.hits = { hit }
		attack_results[1] = hit
		attack_results.hit_objs[#attack_results.hit_objs + 1] = target
		attack_results.hit_objs[target] = true
		attack_results.unit_damage = { [target] = hit.damage }
		if IsKindOf(target, "Unit") and not target:IsDead() and hit.damage >= target:GetTotalHitPoints() then
			attack_results.killed_units = {target}
		end
	elseif stuck then
		local hit = { 
			obj = target, 
			weapon = self,
			damage = 0,
			spot_group = attack_args.target_spot_group,
			actionType = action.ActionType,
			damage_bonus = attack_args.damage_bonus,
			impact_force = self:GetImpactForce(),
			melee_attack = attack_results.melee_attack,
			stuck = true,
			effects = {},
		}
		attack_results.hits = { hit }
		attack_results[1] = hit		
	end

	attack_results.total_damage = total_damage
	attack_results.miss = miss
	attack_results.target_hit = not miss
	return attack_results
end

function MeleeWeapon:CreateVisualObj(owner)
	return self:CreateVisualObjEntity(owner, IsValidEntity(self.Entity) and self.Entity or "Weapon_FC_AMZ_Knife_01")
end

DefineClass.StackableMeleeWeapon = {
	__parents = { "MeleeWeapon", "InventoryStack" },
	properties = {
		--strip condition related stuff
		{ id = "Condition" },
		{ id = "RepairCost" },
		{ id = "Repairable" },
		{ category = "Scrap", id = "ScrapParts", name = "Scrap Parts", help = "The number for Parts that are given to the player when its scraped", 
			editor = "number", default = 0, template = true, min = 0, max = 1000, },
	}
}

DefineClass.UnarmedWeapon = {
	__parents = { "MeleeWeapon" },
	base_action = "UnarmedAttack",
}

DefineClass.CrocodileWeapon = {
	__parents = { "MeleeWeapon" },
	base_action = "CrocodileBite",
}

DefineClass.HyenaWeapon = {
	__parents = { "MeleeWeapon" },
	base_action = "HyenaBite",
}
