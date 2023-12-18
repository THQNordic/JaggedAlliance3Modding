DefineClass.HeavyWeapon = {
	__parents = { "HeavyWeaponProperties", "BaseWeapon", "Firearm" },
	trajectory_type = false,
	base_skill = "Explosives", -- they don't have chance to hit, but mishap chance is based on Explosives so it makes sense for the AI
	
	trajectory_attack_action = {
		["line"] = "RocketLauncherFire",
		["parabola"] = "GrenadeLauncherFire",
		["bombard"] = "Bombard"
	}
}

function HeavyWeapon:GetBaseAttack()
	return self.trajectory_attack_action[self.trajectory_type]
end

function HeavyWeapon:GetBaseDamage()
	if self.ammo then
		return self.ammo.BaseDamage
	end
	return self.BaseDamage
end

function HeavyWeapon:GetMaxRange()
	return self.WeaponRange * const.SlabSizeX
end

function HeavyWeapon:ValidatePos(explosion_pos)
	return explosion_pos
end

function HeavyWeapon:GetJamChance()
	return 0
end

function HeavyWeapon:GetAttackResults(action, attack_args)
	local attacker = attack_args.obj
	local prediction = attack_args.prediction
	local trajectory, stealth_kill
	local lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group or "Torso")
	local lof_data = (attack_args.lof or empty_table)[lof_idx or 1]
	local target_pos = attack_args.target_pos or lof_data and lof_data.target_pos or (IsValid(attack_args.target) and attack_args.target:GetPos())
	local ordnance = self.ammo

	if not target_pos:IsValidZ() then
		target_pos = target_pos:SetTerrainZ()
	end

	-- mishap & stealth kill checks
	local mishap
	if not prediction and not attack_args.explosion_pos and IsKindOf(self, "MishapProperties") then
		local chance = self:GetMishapChance(attacker, target_pos)
		if CheatEnabled("AlwaysMiss") or attacker:Random(100) < chance then
			local dv = self:GetMishapDeviationVector(attacker, target_pos)
			mishap = true
			target_pos = target_pos + dv
			attacker:ShowMishapNotification(action)
		end
	end

	if self.trajectory_type == "line" then
		attack_args.max_pierced_objects = 0
		attack_args.can_use_covers = false
		if not prediction then
			attack_args.prediction = false
			attack_args.can_use_covers = false
			attack_args.seed = attacker:Random()
			local attack_data = GetLoFData(attacker, target_pos, attack_args)
			attack_args.lof = attack_data.lof
			lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group or "Torso")
			lof_data = attack_args.lof[lof_idx or 1]
		end
		-- trajectory from lof (shot origin -> first hit/target_pos)
		if lof_data then
			local hits = lof_data.hits or empty_table
			local hit_pos
			if #hits > 0 then
				hit_pos = hits[1].pos
			else
				hit_pos = target_pos
			end
			hit_pos = attack_args.explosion_pos or hit_pos
			local dist = lof_data.attack_pos:Dist(hit_pos)
			local time = MulDivRound(dist, 1000, const.Combat.RocketVelocity)
			trajectory = {
				{ pos = lof_data.attack_pos, t = 0 },
				{ pos = hit_pos, t = time },
			}
		end
	elseif self.trajectory_type == "parabola" then
		attack_args.can_bounce = ordnance and ordnance.CanBounce
		trajectory = Grenade:GetTrajectory(attack_args, nil, target_pos)
	elseif self.trajectory_type == "bombard" then
		-- no parabola for bombard
	else
		assert(false, string.format("unknown trajectory type '%s' used in heavy weapon '%s' of class %s", tostring(self.trajectory_type), self.class, self.class))
	end
	
	if not attack_args.explosion_pos and ((not trajectory or #trajectory == 0) and self.trajectory_type ~= "bombard" or not self.ammo or self.ammo.Amount <= 0) then
		return {}
	end
	
	local jammed, condition = false, false
	if prediction then
		attack_args.jam_roll = 0
		attack_args.condition_roll = 0
	else
		attack_args.jam_roll = attack_args.jam_roll or (1 + attacker:Random(100))
		attack_args.condition_roll = attack_args.condition_roll or (1 + attacker:Random(100))
		jammed, condition = self:ReliabilityCheck(attacker, 1, attack_args.jam_roll, attack_args.condition_roll)
	end
	
	if jammed then
		return {jammed = true, condition = condition}
	end
	local impact_pos = attack_args.explosion_pos or (trajectory and #trajectory > 0 and trajectory[#trajectory].pos) or target_pos
	local aoe_params = self:GetAreaAttackParams(action.id, attacker, impact_pos)
	aoe_params.stealth_kill = stealth_kill
	if attack_args.stealth_attack then
		aoe_params.stealth_attack_roll = not prediction and attacker:Random(100) or 100
	end

	aoe_params.prediction = prediction
	local results = GetAreaAttackResults(aoe_params, nil, not prediction and ordnance.AppliedEffects)
	results.trajectory = trajectory
	results.ordnance = ordnance
	results.weapon = ordnance
	results.jammed = jammed
	results.condition = condition
	results.fired = not jammed and 1
	results.mishap = mishap
	results.burn_ground = ordnance.BurnGround
	if self.trajectory_type == "bombard" then
		results.explosion_pos = target_pos
		if not jammed then
			results.fired = Min(attack_args.bombard_shots, ordnance.Amount)
		end
	elseif self.trajectory_type == "line" then
		-- add cone aoe behind attacker
		assert(#trajectory > 1)
		
		local range = self.BackfireRange
		local step_pos = attack_args.step_pos
		local target_pos = step_pos + SetLen(trajectory[1].pos - trajectory[2].pos, range * const.SlabSizeX)	
		
		local cone_params = {
			can_be_damaged_by_attack = false,			
			cone_angle = self.BackfireConeAngle,
			max_range = range,
			target_pos = target_pos,
			attacker = attacker,
			step_pos = step_pos,
			explosion = true,
			weapon = aoe_params.weapon,
			damage_override = self.BackfireDamage,
			damage_mod = 100,
			attribute_bonus = 0,
			prediction = prediction,
		}
		
		
		local cone_results = GetAreaAttackResults(cone_params)
		
		-- merge results from the cone attack into 'results'
		for _, hit in ipairs(cone_results) do
			hit.backfire = true
			results[#results + 1] = hit			
		end
		for _, obj in ipairs(cone_results.hit_objs) do
			results.hit_objs = results.hit_objs or {}
			table.insert_unique(results.hit_objs, obj)
		end
		
		results.total_damage = (results.total_damage or 0) + (cone_results.total_damage or 0)
		results.friendly_fire_dmg = (results.friendly_fire_dmg or 0) + (cone_results.friendly_fire_dmg or 0)
	end
	CompileKilledUnits(results)
	return results
end

function HeavyWeapon:GetAreaAttackParams(action_id, attacker, target_pos, step_pos)
	target_pos = target_pos or attacker:GetVisualPos()
	
	local ordnance = self.ammo
	
	local params = {
		attacker = false,
		weapon = ordnance or nil,
		target_pos = target_pos,
		step_pos = step_pos or target_pos,
		stance = "Prone",
		min_range = ordnance and ordnance.AreaOfEffect or 0,
		max_range = ordnance and ordnance.AreaOfEffect or 0,
		center_range = ordnance and ordnance.CenterAreaOfEffect or 0,
		aoe_type = ordnance and ordnance.aoeType or nil,
		damage_mod = 100,
		attribute_bonus = 0,
		can_be_damaged_by_attack = true,
		explosion = true, -- damage dealt depends on target stance
		explosion_fly = ordnance and ordnance.DeathType == "BlowUp" or false,
		used_ammo = 1,
	}
	if IsKindOf(attacker, "Unit") then
		params.attacker = attacker
		params.attribute_bonus = GetGrenadeDamageBonus(attacker)
	end
	if self.trajectory_type == "bombard" then
		-- increase range with the size of the bombard (weapon property)
		params.max_range = params.max_range + self.BombardRadius
	end
	return params
end

function MishapChanceByDist(item, attacker, target, async)
	local chance = MishapProperties.GetMishapChance(item, attacker, target, async)
	local range = item.WeaponRange * const.SlabSizeX
	local dist = attacker:GetDist(target)
	if dist > range / 2 then
		chance = Min(100, chance + MulDivRound(dist - range/2, 100 - chance, range/2))
	end
	return chance
end

function MishapDeviationVectorByDist(item, attacker, target)
	local dv = MishapProperties.GetMishapDeviationVector(item, attacker, target)
	local range = item.WeaponRange * const.SlabSizeX
	local dist = attacker:GetDist(target)
	if dist > range / 2 then
		local mod = Min(100, MulDivRound(dist - range/2, 100, range/2))
		dv = MulDivRound(dv, 100 + mod, 100)
	end
	return dv
end

DefineClass.RocketLauncher = { 
	__parents = {"HeavyWeapon"}, 
	properties = {
		{ category = "Combat", id = "BackfireRange", editor = "number", min = 0, default = 3, template = true, },
		{ category = "Combat", id = "BackfireConeAngle", editor = "number", min = 0, scale = "deg", default = 30*60, template = true, },
		{ category = "Combat", id = "BackfireDamage", editor = "number", min = 0, default = 10, template = true, },
	},
	trajectory_type = "line", 
	WeaponType = "MissileLauncher", 
	RolloverClassTemplate = "HeavyWeapon",
}

DefineClass.GrenadeLauncher = { __parents = {"HeavyWeapon"}, trajectory_type = "parabola", WeaponType = "GrenadeLauncher", RolloverClassTemplate = "HeavyWeapon"}
DefineClass.Mortar = { __parents = {"HeavyWeapon"}, trajectory_type = "bombard", WeaponType = "Mortar", RolloverClassTemplate = "HeavyWeapon"}

GrenadeLauncher.GetMishapChance = MishapChanceByDist
GrenadeLauncher.GetMishapDeviationVector = MishapDeviationVectorByDist
RocketLauncher.GetMishapChance = MishapChanceByDist
RocketLauncher.GetMishapDeviationVector = MishapDeviationVectorByDist

function GrenadeLauncher:GetBaseDegradePerShot()
	return const.Weapons.DegradePerShot_GrenadeLauncher
end

function RocketLauncher:GetBaseDegradePerShot()
	return const.Weapons.DegradePerShot_RocketLauncher
end

function Mortar:GetBaseDegradePerShot()
	return const.Weapons.DegradePerShot_Mortar
end


function RocketLauncher:UpdateRocket()
	local visual_obj = self.visual_obj
	if not IsValid(visual_obj) then return end
	
	visual_obj:DestroyAttaches("OrdnanceVisual")
	if self.ammo and self.ammo.Amount > 0 then
		local rocket = PlaceObject("OrdnanceVisual", {fx_actor_class = self.ammo.class})
		visual_obj:Attach(rocket, visual_obj:GetSpotBeginIndex("Muzzle"))
	end
end

function RocketLauncher:OnUnloadWeapon()
	self:UpdateRocket()
end

function RocketLauncher:Reload(...)
	Firearm.Reload(self, ...)
	self:UpdateRocket()
end

function RocketLauncher:UpdateVisualObj(...)
	Firearm.UpdateVisualObj(self, ...)
	self:UpdateRocket()
end