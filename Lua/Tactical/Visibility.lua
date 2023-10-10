const.LOFIgnoreHitDistance = const.SlabSizeX
const.MaxLOFRange = 141 * const.SlabSizeX -- limit by playable map size (100 tiles x sqrt(2))
const.CombatObjectMaxRadius = 2 * const.SlabSizeX
const.UnitHitRadius = const.SlabSizeX / 3

const.LOSCoverMaxConeAngle = 120 * 60
const.LOSSlabMaxConeAngle = 160 * 60
const.LOSProneHeight = 40*guic
const.LOSCrouchHeight = 90*guic
const.LOSStandingHeight = 130*guic
const.LOSPointsDistForward = const.SlabSizeX / 3
const.LOSPointsDistAside = const.SlabSizeX / 10

const.AreaAttackStandingSpots = { "Head", "Torso", "Elbowl", "Elbowr" }
const.AreaAttackProneSpots = { "Head" }

const.ConeAttackGroundMin = 20*guic -- hit prone units (do not hit floor slabs)
const.ConeAttackGroundMax = 200*guic -- 3 slabs height (do not hit ceiling slabs)

const.DefaultTargetSpots = { "Hit" }

const.uvVisible = 1
const.uvNPC = 2
const.uvRevealed = 4

-- sight condition consts
const.usObscured = 1
const.usConcealed = 2

MapVar("TargetDummies", {}, weak_keys_meta)

DefineClass.HittableObject= {
	__parents = {"CObject"},
}

local function SetDefaultTargetSpots()
	-- Prone area attack targets
	local prone_points = {}
	local prone_heights = {30*guic}
	local prone_radius = 30*guic
	local x = 40*guic
	for i, h in ipairs(prone_heights) do
		table.insert(prone_points, point(x, 0, h))
		table.insert(prone_points, point(x, prone_radius, h))
		table.insert(prone_points, point(x, -prone_radius, h))
	end
	SetAreaAttackProneHitPos(prone_points)

	-- Standing area attack targets
	local standing_points = {}
	local standing_heights = {80*guic,130*guic}
	local standing_radius = 30*guic
	for i, h in ipairs(standing_heights) do
		table.insert(standing_points, point(x, 0, h))
		table.insert(standing_points, point(x, standing_radius, h))
		table.insert(standing_points, point(x, -standing_radius, h))
	end
	SetAreaAttackStandingHitPos(standing_points)
end

SetDefaultTargetSpots()

OnMsg.EntitiesLoaded = UpdateUnitColliders
OnMsg.DataLoaded = UpdateUnitColliders
OnMsg.PresetSave = UpdateUnitColliders

local immune_to_half_area_damage_classes = {"Landmine"}

function GetAreaAttackHitModifier(obj, los_value)
	if (los_value or 0) == 0 then
		return 0
	elseif obj:IsInvulnerable() then
		return 0
	elseif los_value == 1 then
		if IsKindOf(obj, "Unit") then
			if obj.stance == "Prone" then
				return 0
			end
		elseif IsKindOfClasses(obj, immune_to_half_area_damage_classes) then
			return 0
		end
		return 50
	end
	return 100
end

function GetAreaAttackHitModifiers(action_id, attack_args, targets)
	local action = CombatActions[action_id]
	local cone_angle = action.AimType == "cone" and attack_args.cone_angle or -1
	if not attack_args.distance then
		attack_args.distance = attack_args.max_range and attack_args.max_range * const.SlabSizeX or -1
	end
	local maxvalue, los_values = CheckLOS(targets, attack_args.step_pos, attack_args.distance, attack_args.stance, cone_angle, attack_args.target, false, attack_args.min_distance_2d)
	local modifiers = {}
	for i, target in ipairs(targets) do
		modifiers[i] = GetAreaAttackHitModifier(target, los_values and los_values[i])
	end
	return modifiers
end

function GetAOETiles(step_pos, stance, distance, cone_angle, target, force2d)
	local step_positions, step_objs = GetStepPositionsInArea(step_pos, distance, 0, cone_angle, target, force2d)
	local maxvalue, los_values = CheckLOS(step_positions, step_pos, -1, stance, -1, false, false)
	return step_positions, step_objs, los_values or empty_table
end

function GetAreaAttackResults(aoe_params, damage_bonus, applied_status, damage_override)
	local prediction = aoe_params.prediction
	local attacker = aoe_params.attacker
	local step_pos = aoe_params.step_pos or IsValid(attacker) and attacker:GetPos()
	local occupied_pos = aoe_params.occupied_pos or IsKindOf(attacker, "Unit") and attacker:GetOccupiedPos()
	local stance = aoe_params.stance or IsKindOf(attacker, "Unit") and attacker.stance or "Standing"
	local target_pos = aoe_params.target_pos or step_pos
	local explosion = aoe_params.explosion
	
	local cone_angle = aoe_params.cone_angle or -1
	local range
	if aoe_params.max_range and aoe_params.min_range and aoe_params.max_range ~= aoe_params.min_range then
		range = Clamp(attacker:GetDist(target_pos), aoe_params.min_range * const.SlabSizeX, aoe_params.max_range * const.SlabSizeX)
	else
		range = aoe_params.max_range and aoe_params.max_range * const.SlabSizeX or -1
	end
	local min_range_2d = 0
	local weapon = aoe_params.weapon
	local dont_destroy_covers = aoe_params.dont_destroy_covers

	local targets, los_values = GetAreaAttackTargets(step_pos, stance, prediction, range, min_range_2d, cone_angle, target_pos, occupied_pos, dont_destroy_covers)
	targets = table.ifilter(targets, function(idx, target) return not IsKindOf(target, "Landmine") end)
	
	if IsValid(attacker) and not aoe_params.can_be_damaged_by_attack then
		local idx = table.find(targets, attacker)
		if idx then
			table.remove(targets, idx)
			table.remove(los_values, idx)
		end
	end
	local results = { start_pos = step_pos, target_pos = target_pos, range = range, cone_angle = cone_angle, aoe_type = aoe_params.aoe_type, explosion =  explosion}
	if #targets == 0 then
		return results, 0, 0, {}
	end
	local total_damage, friendly_fire_dmg = 0, 0
	if not step_pos:IsValidZ() then
		step_pos = step_pos:SetTerrainZ()
	end
	local impact_force = weapon:GetImpactForce()
	for i, obj in ipairs(targets) do
		local dmg_mod = aoe_params.damage_mod
		local nominal_dmg = (attacker and IsKindOf(attacker, "Unit")) and attacker:GetBaseDamage(weapon, obj) or weapon.BaseDamage
		if aoe_params.damage_override then
			nominal_dmg = aoe_params.damage_override
		end
		if not prediction then
			nominal_dmg = RandomizeWeaponDamage(nominal_dmg)
		end
	
		local hit = {}
		results[i] = hit
		hit.obj = obj
		hit.aoe = true
		hit.area_attack_modifier = GetAreaAttackHitModifier(obj, los_values[i])
		if explosion then
			local center_range = aoe_params.center_range or 1
			if center_range > 1 then
				hit.explosion_center = obj:GetDist(target_pos) <= (center_range * const.SlabSizeX)
			else
				hit.explosion_center = GetPassSlab(target_pos) == GetPassSlab(obj)
			end
		end
		
		if hit.area_attack_modifier > 0 then
			local dmg = 0
			if dmg_mod ~= "no damage" then
				dmg_mod = dmg_mod + aoe_params.attribute_bonus
				dmg = MulDivRound(nominal_dmg, Max(0, dmg_mod), 100)
			end
			
			if dmg > 0 and not explosion and IsValid(attacker) and aoe_params.falloff_damage and aoe_params.falloff_start then
				local dist = attacker:GetDist(obj)
				local falloff_factor = Clamp(0, 100, MulDivRound(dist, 100, range) - aoe_params.falloff_start)
				if falloff_factor > 0 then
					local damage_start, damage_end = dmg, MulDivRound(dmg, aoe_params.falloff_damage, 100)
					dmg = Max(1, MulDivRound(damage_start, 100 - falloff_factor, 100) + MulDivRound(damage_end, falloff_factor, 100))
				end
			end
			
			weapon:PrecalcDamageAndStatusEffects(attacker, obj, step_pos, dmg, hit, applied_status, nil, nil, nil, prediction)
			local damage
			if damage_override then
				damage = damage_override
			else
				damage = MulDivRound(hit.damage, 100 + (damage_bonus or 0), 100)
			end
			local dmg_mod = hit.area_attack_modifier
			if explosion and IsKindOf(obj, "Unit") then
				if obj.stance == "Prone" then
					dmg_mod = dmg_mod + const.Combat.ExplosionProneDamageMod
					if HasPerk(obj, "HitTheDeck") then
						local mod = CharacterEffectDefs.HitTheDeck:ResolveValue("explosiveLessDamage")
						dmg_mod = dmg_mod - mod
					end
				elseif obj.stance == "Crouch" then
					dmg_mod = dmg_mod + const.Combat.ExplosionCrouchDamageMod
				end
			end
			damage = MulDivRound(damage, Max(0, dmg_mod), 100)
			if aoe_params.stealth_attack_roll and IsKindOf(attacker, "Unit") and IsKindOf(obj, "Unit") and not obj.villain and not obj:IsDead() then
				if aoe_params.stealth_attack_roll < attacker:CalcStealthKillChance(weapon, obj) then
					damage = MulDivRound(obj:GetTotalHitPoints(), 100 + obj:Random(50), 100)
					hit.stealth_kill = true
				end
				hit.stealth_kill_chance = attacker:CalcStealthKillChance(weapon, obj)
			end
			hit.damage = damage
			if IsKindOf(attacker, "Unit") and IsKindOf(obj, "Unit") then
				total_damage = total_damage + damage
				if not obj:IsOnEnemySide(attacker) then
					friendly_fire_dmg = friendly_fire_dmg + damage
				end
			end
			hit.impact_force = impact_force + weapon:GetDistanceImpactForce(obj:GetDist(step_pos))
		else
			hit.damage = 0
			hit.stuck = true
			hit.armor_decay = empty_table
			hit.effects = empty_table
		end
		if aoe_params.explosion_fly and IsKindOf(hit.obj, "Unit") and hit.damage >= const.Combat.GrenadeMinDamageForFly then
			hit.explosion_fly = true
		end
	end
	results.total_damage = total_damage
	results.friendly_fire_dmg = friendly_fire_dmg
	results.hit_objs = targets
	return results, total_damage, friendly_fire_dmg, targets
end

if FirstLoad then
	g_InvisibleUnitOpacity = 0
	g_ExperimentalModeLOS = "slab block only"
end

-- TODO: remove this when experimenting with LOS is finished
config.SlabEntityList = ""

function DbgCycleExperimentalLOS()
	config.SlabEntityList = ""
	if not g_ExperimentalModeLOS then
		g_ExperimentalModeLOS = "all visible"
		print("LOS: All enemies are visibles")
	elseif g_ExperimentalModeLOS == "all visible" then
		g_ExperimentalModeLOS = "slab block only"
		config.SlabEntityList = "Floor,Stairs,WallExt,WallInt,Door,TallDoor,Window,WindowBig,WindowVent,Roof"
		print("LOS: Only Slab objects block vision")
	else
		g_ExperimentalModeLOS = false
		print("LOS: Normal mode.")
	end
end

local function IsVisibleTo(self, other)
	if g_ExperimentalModeLOS == "all visible" then
		return true
	end
	if not other.team:IsEnemySide(self.team) then
		return true
	end
	if self:CanSee(other) then
		return true
	end
	return false
end

MapVar("g_Visibility", {})
MapVar("g_SightConditions", {})
MapVar("g_RevealedUnits", {})	-- [team] -> list of units known to the team regardless of visibility (lasts until the end of team's turn)
MapVar("g_VisibilityUpdated", false)
MapVar("g_SetpieceFullVisibility", false)

function NetSyncEvents.RevealToTeam(unit, teamId)
	unit:RevealTo(g_Teams[teamId])
end

function Unit:RevealTo(obj, combat)
	combat = combat or g_Combat
	if not combat then return end
	
	-- Dont reveal traps
	if not IsKindOfClasses(obj, "Unit", "CombatTeam") then return end

	local team = IsValid(obj) and obj.team or obj
		
	-- add ourselves to g_RevealedUnits for the sake of consequent visibility/diplomacy updates
	g_RevealedUnits[team] = g_RevealedUnits[team] or {}
	table.insert_unique(g_RevealedUnits[team], self)
	self:RemoveStatusEffect("Spotted")
	self:RemoveStatusEffect("Hidden")
	self:AddStatusEffect("Revealed")
		
	-- add ourselves to target team visibility
	if not HasVisibilityTo(team, self) then
		g_Visibility[team] = g_Visibility[team] or {}
		table.insert(g_Visibility[team], self)
	end
	g_Visibility[team][self] = bor(g_Visibility[team][self] or 0, const.uvRevealed)
	
	InvalidateDiplomacy() -- update unit enemy lists
	if g_Combat then
		g_Combat:ApplyVisibility()
	end
	
	-- trigger unaware units who can now see us
	for _, unit in ipairs(team.units) do
		if VisibilityCheckAll(unit, self, nil, const.uvVisible) and unit:HasStatusEffect("Unaware") then
			PushUnitAlert("sight", unit, self)
		end
	end
	AlertPendingUnits()
end

function VisibilityCheckAll(observer, other, visibility, mask)
	if IsKindOf(other, "Unit") then
		local vis = (visibility or g_Visibility)[observer]
		return band(vis and vis[other] or 0, mask) == mask
	elseif IsKindOf(other, "Trap") then
		assert((observer.team and observer.team.side == "player1") or observer.side == "player1")
		local trapVis = g_AttackableVisibility[observer]
		trapVis = trapVis and trapVis[other] and const.uvVisible or 0
		return band(trapVis, mask) == mask
	end
	return true
end

function VisibilityCheckAny(observer, other, visibility, mask)
	if IsKindOf(other, "Unit") then
		local vis = (visibility or g_Visibility)[observer]
		return band(vis and vis[other] or 0, mask) ~= 0
	elseif IsKindOf(other, "Trap") then
		assert((observer.team and observer.team.side == "player1") or observer.side == "player1")
		local trapVis = g_AttackableVisibility[observer]
		trapVis = trapVis and trapVis[other] and const.uvVisible or 0		
		return band(trapVis, mask) ~= 0
	end
	return true
end

function HasVisibilityTo(observer, other, visibility)
	if IsKindOf(other, "Unit") then
		local vis = (visibility or g_Visibility)[observer]
		return (vis and vis[other] or 0) >= const.uvVisible
	elseif IsKindOf(other, "Trap") then
		assert((observer.team and observer.team.side == "player1") or observer.side == "player1")
		local trapVis = g_AttackableVisibility[observer]
		return trapVis and trapVis[other]
	end
	return true
end

function VisibilityGetValue(observer, other, visibility)
	if IsKindOf(other, "Unit") then
		local vis = (visibility or g_Visibility)[observer]
		return vis and vis[other] or 0
	elseif IsKindOf(other, "Trap") then
		assert((observer.team and observer.team.side == "player1") or observer.side == "player1")
		local trapVis = g_AttackableVisibility[observer]
		return trapVis and trapVis[other] and const.uvVisible or 0
	end
	return const.uvVisible
end

function IsFullVisibility()
	return CheatEnabled("FullVisibility")
end

function CheckSightCondition(observer, other, condition)
	local value = (g_SightConditions[observer] or empty_table)[other] or 0	
	return band(value, condition) == condition
end

local function HandleSortFunction(a, b)
	return a.handle < b.handle
end

function Unit:ComputeVisibleUnits()
	local unit_visibility = {}
	local uvVisible = const.uvVisible
	local uvVisibleNPC = bor(uvVisible, const.uvNPC)
	local team = self.team
	for i, other in ipairs(g_UnitsLOS[self]) do
		local vis_value = uvVisible
		if not other.team:IsEnemySide(team) then
			if other:IsNPC() and not other:HasStatusEffect("HiddenNPC") then
				vis_value = uvVisibleNPC
			end
		end
		unit_visibility[i] = other
		unit_visibility[other] = vis_value
	end
	return unit_visibility
end

-- called from C++
function GetMaxSightRadius()
	return MulDivRound(const.Combat.AwareSightRange, const.SlabSizeX * const.Combat.SightModMaxValue, 100)
end

local function UpdateUnitsLOS(unitsLOS)
	local player_units = {}
	local enemy_units = {}
	local neutral_units = {} -- units that do not need LOS info (only players could check LOS to them for free aim attack)
	local dead_units = {}  -- enemies alarm checks
	local enemyNeutral_Side = GameState.Conflict and "enemy1" or "neutral"
	local script_target_groups

	for group, mods in pairs(gv_AITargetModifiers) do
		for target_group, value in pairs(mods) do
			if not script_target_groups then script_target_groups = {} end
			script_target_groups[target_group] = true
		end
	end

	local insert = table.insert
	local clear = table.clear
	local IsValidPos = Unit.IsValidPos
	local IsDead = Unit.IsDead

	for _, team in ipairs(g_Teams) do
		local side = team.side
		if side == "enemyNeutral" then
			side = enemyNeutral_Side
		end
		if side == "neutral" then
			for _, unit in ipairs(team.units) do
				local has_los_tbl
				if IsValidPos(unit) and not IsDead(unit) then
					local is_script_target
					if script_target_groups then
						for _, group in ipairs(unit.Groups) do
							if script_target_groups[group] then
								is_script_target = true
								break
							end
						end
					end
					if is_script_target then
						insert(enemy_units, unit)
						has_los_tbl = true
					else
						insert(neutral_units, unit)
					end
				end
				if has_los_tbl then
					local los_tbl = unitsLOS[unit]
					if los_tbl then clear(los_tbl) else los_tbl = {} unitsLOS[unit] = los_tbl end
					los_tbl[1] = unit
					los_tbl[unit] = 2
				else
					unitsLOS[unit] = nil
				end
			end
		elseif team.player_team then
			for _, unit in ipairs(team.units) do
				if IsValidPos(unit) and not IsDead(unit) then
					insert(player_units, unit)
					local los_tbl = unitsLOS[unit]
					if los_tbl then clear(los_tbl) else los_tbl = {} unitsLOS[unit] = los_tbl end
					los_tbl[1] = unit
					los_tbl[unit] = 2
				else
					unitsLOS[unit] = nil
				end
			end
		else
			for _, unit in ipairs(team.units) do
				local has_los_tbl
				if IsValidPos(unit) then
					if IsDead(unit) then
						insert(dead_units, unit)
					else
						insert(enemy_units, unit)
						has_los_tbl = true
					end
				end
				if has_los_tbl then
					local los_tbl = unitsLOS[unit]
					if los_tbl then clear(los_tbl) else los_tbl = {} unitsLOS[unit] = los_tbl end
					los_tbl[1] = unit
					los_tbl[unit] = 2
				else
					unitsLOS[unit] = nil
				end
			end
		end
	end

	local src_units, target_units = {}, {}
	for i, unit1 in ipairs(player_units) do
		for j, unit2 in ipairs(player_units) do
			if unit1 ~= unit2 then
				insert(src_units, unit1)
				insert(target_units, unit2)
			end
		end
		for j, unit2 in ipairs(enemy_units) do
			insert(src_units, unit1)
			insert(target_units, unit2)
		end
		for j, unit2 in ipairs(neutral_units) do
			insert(src_units, unit1)
			insert(target_units, unit2)
		end
	end
	for i, unit1 in ipairs(enemy_units) do
		for j, unit2 in ipairs(player_units) do
			insert(src_units, unit1)
			insert(target_units, unit2)
		end
		local side1 = unit1.team.side
		if side1 == "enemyNeutral" then side1 = enemyNeutral_Side end
		for j, unit2 in ipairs(enemy_units) do
			local side2 = unit2.team.side
			if side2 == "enemyNeutral" then side2 = enemyNeutral_Side end
			if side1 ~= side2 then
				insert(src_units, unit1)
				insert(target_units, unit2)
			end
		end
		for j, unit2 in ipairs(dead_units) do
			local side2 = unit2.team.side
			if side2 == "enemyNeutral" then side2 = enemyNeutral_Side end
			if side1 == side2 then
				insert(src_units, unit1)
				insert(target_units, unit2)
			end
		end
	end
	if #src_units > 0 then
		local los_any, result = CheckLOS(target_units, src_units)
		local uvVisible = const.uvVisible
		for i, target in ipairs(target_units) do
			local value = result and result[i]
			if value then
				local los_tbl = unitsLOS[src_units[i]]
				insert(los_tbl, target)
				los_tbl[target] = value
			end
		end
	end
end

function ComputeUnitsVisibility()
	UpdateUnitsLOS(g_UnitsLOS)

	local visibility = {}
	local visual_contact_change = {}
	local uvVisible = const.uvVisible
	local uvRevealed = const.uvRevealed
	local insert = table.insert

	-- init team visibility
	for _, team in ipairs(g_Teams) do
		if team.side == "neutral" then -- neutral units don't care about combat visibility
			-- update visibility for the script units
			for _, unit in ipairs(team.units) do
				if g_UnitsLOS[unit] then
					local unit_visibility = unit:ComputeVisibleUnits()
					visibility[unit] = unit_visibility
				end
			end
		else
			local team_visibility = {}
			visibility[team] = team_visibility
			for i, ru in ipairs(g_RevealedUnits[team]) do
				if not ru:IsDead() then
					insert(team_visibility, ru)
					team_visibility[ru] = uvRevealed
				end
			end
			for _, unit in ipairs(team.units) do
				if unit.enemy_visual_contact then
					insert(visual_contact_change, unit)
					visual_contact_change[unit] = 1
				end
				unit.enemy_visual_contact = false
				if IsValid(unit) and unit:IsValidPos() and not unit:IsDead() then
					local unit_visibility = unit:ComputeVisibleUnits()
					visibility[unit] = unit_visibility
					-- build team visibility
					for i, other in ipairs(unit_visibility) do
						--NetUpdateHash("CompVis1", other)
						local prev_val = team_visibility[other] or 0
						local tval = bor(prev_val, unit_visibility[other])
						if tval ~= prev_val then
							if prev_val == 0 then
								insert(team_visibility, other)
							end
							team_visibility[other] = tval
						end
					end
				end
			end
		end
	end

	-- share visibility to allies
	for j, team in ipairs(g_Teams) do
		local vis = visibility[team]
		if vis and #vis > 0 then
			for k, team2 in ipairs(g_Teams) do
				if team ~= team2 and team:IsAllySide(team2) then
					local vis2 = visibility[team2]
					for i, other in ipairs(vis) do
						if not vis2[other] then
							insert(vis2, other)
							vis2[other] =  const.uvRevealed
						end
					end
				end
			end
		end
	end

	-- update visual contact & sight conditions
	g_SightConditions = {}
	local FogUnkownFoeDistance = GameState.Fog and const.EnvEffects.FogUnkownFoeDistance
	local DustStormUnkownFoeDistance = GameState.DustStorm and const.EnvEffects.DustStormUnkownFoeDistance
	local current_player_team = g_Combat and g_Teams[g_CurrentTeam] and g_Teams[g_CurrentTeam].player_team and g_Teams[g_CurrentTeam]

	for _, team in ipairs(g_Teams) do
		if team.side ~= "neutral" then
			for _, unit in ipairs(team.units) do
				local unit_sight_conditions
				if unit:IsAware("pending") then -- visual contact
					for _, other in ipairs(visibility[unit]) do
						if other.team:IsEnemySide(team) then
							if not other.enemy_visual_contact then
								other.enemy_visual_contact = true
								local prev = visual_contact_change[other]
								visual_contact_change[other] = (prev or 0) | 2
								if not prev then
									insert(visual_contact_change, other)
								end
							end
							if other.team == current_player_team and other.in_combat_movement and other:HasStatusEffect("Hidden") then
								other:AddStatusEffect("Spotted")
								other:SetEffectValue("Spotted-" .. team.side, true)
							end
						end
					end
				end
				if FogUnkownFoeDistance or DustStormUnkownFoeDistance then
					for _, other in ipairs(visibility[team]) do
						if not other.indoors then
							local value = 0
							if FogUnkownFoeDistance and not IsCloser(unit, other, FogUnkownFoeDistance) then
								value = const.usConcealed
							end
							if DustStormUnkownFoeDistance and not IsCloser(unit, other, DustStormUnkownFoeDistance) then
								value = bor(value, const.usObscured)
							end
							if value ~= 0 then
								if not unit_sight_conditions then
									unit_sight_conditions = {}
									g_SightConditions[unit] = unit_sight_conditions
								end
								local oldVal = unit_sight_conditions[other]
								unit_sight_conditions[other] = value
								if oldVal ~= value then
									ObjModified(other)
								end
							end
						end
					end
				end
			end
		end
	end

	-- update HiddenNPC status
	for _, team in ipairs(g_Teams) do
		if team.player_team then
			for _, unit in ipairs(visibility[team]) do
				if unit:HasStatusEffect("HiddenNPC") then
					if VisibilityCheckAll(team, unit, visibility, uvVisible) then
						unit:RemoveStatusEffect("HiddenNPC")
					end
				end
			end
		end
	end

	for _, unit in ipairs(visual_contact_change) do
		if visual_contact_change[unit] ~= 3 then
			unit:UpdateHidden()
			Msg("UnitStealthChanged", unit)
		end
	end

	g_VisibilityUpdated = true
	return visibility
end

local function Visibility_UnitsHash()
	local hash
	for _, unit in ipairs(g_Units) do
		local sight = unit:GetSightRadius()
		local stance_idx = StancesList[unit.stance]
		if unit:IsValidPos() then
			hash = xxhash(stance_pos_pack(unit, stance_idx), sight, hash)
		end
		if unit.visibility_override then
			hash = xxhash(stance_pos_pack(unit.visibility_override.pos, stance_idx), sight, hash)
		end
	end
		
	for _, list in ipairs(g_RevealedUnits) do
		for _, unit in ipairs(list) do
			hash = xxhash(unit:GetHandle(), hash)
		end
	end
	return hash
end

local function Visibility_ResultsHash()
	local hash
	for _, unit in ipairs(g_Units) do
		local uvis = g_Visibility[unit]
		hash = xxhash(unit.handle, hash)
		for _, target in ipairs(uvis) do
			hash = xxhash(target.handle, uvis[target], hash)
		end
	end
	return hash
end

function Combat:UpdateVisibility()
	local hash = Visibility_UnitsHash()
	if hash == self.visibility_update_hash then return end
	self.visibility_update_hash = hash --includes only unit changes
	
	--DbgClearVectors()
	local prev_visibility = g_Visibility

	g_Visibility = ComputeUnitsVisibility()

	for ti, team in ipairs(g_Teams) do
		-- notify the team for visibility changes
		if prev_visibility then
			local prev = prev_visibility[team] or empty_table
			for _, unit in ipairs(prev) do
				if IsValid(unit) and not unit:IsDead() and unit.team ~= team and unit.team:IsEnemySide(team) then
					if not HasVisibilityTo(team, unit) then
						team:OnEnemyLost(unit)
					end
				end
			end
			for _, unit in ipairs(g_Visibility[team]) do
				if unit.team:IsEnemySide(team) then
					if not HasVisibilityTo(team, unit, prev_visibility) then
						if unit:HasStatusEffect("Spotted") then
							unit:SetEffectValue("Spotted-" .. team.side, true)
						else
							team:OnEnemySighted(unit)
							unit:RevealTo(team) 
						end
					end
				end
			end
		end
	end
	
	if prev_visibility then
		for _, unit in ipairs(g_Units) do
			for _, other in ipairs(g_Visibility[unit]) do
				if unit:IsOnEnemySide(other) and not HasVisibilityTo(unit, other, prev_visibility) then
					unit:OnEnemySighted(other)
				end
			end
		end
	end
	
	Msg("CombatComputedVisibility")
end

local function IsInsideClosedVolume(unit)
	local volume = EnumVolumes(unit, "smallest")
	local building = volume and volume.building
	if building then
		local open_floor = VT2TouchedBuildings and VT2TouchedBuildings[building]
		return not open_floor or (open_floor ~= volume.floor)
	end					
end

function IsOnFadedSlab(obj)
	local uz 
	if IsValid(obj) then
		uz = select(3, obj:GetPosXYZ())
	elseif IsPoint(obj) then
		uz = obj:z()
	end
	local slab = uz and MapGetFirst(obj, const.SlabSizeX/2, "FloorSlab", "RoofSlab", const.efVisible,
		function(slab, uz)
			local sz = select(3, slab:GetPosXYZ())
			if sz and abs(uz - sz) < const.SlabSizeZ / 2 then
				local cmt_state = C_CCMT_GetObjCMTState(slab)
				if cmt_state == const.cmtHidden or cmt_state == const.cmtFadingOut then
					return true
				end
			end
		end, uz)
	if slab then
		return true
	end
	return false
end

local CameraObscureSpots = {
	-- list of spots to check on different settings
	["High"] = {"Head", "Torso", "Elbowl", "Elbowr", "Kneel", "Kneer"},
	["Medium"] = {"Head", "Torso", "Elbowl", "Elbowr"},

	-- fallback list if none of the above applies
	[false] = { "Torso" }, 
}

function OnMsg.SetObjectDetail(action, params)
	if action == "done" then
		SetCameraObscureSpots(CameraObscureSpots[EngineOptions.ObjectDetail] or CameraObscureSpots[false])
	end
end

function ApplyUnitVisibility(active_units, pov_team, visibility, force)
	local innerInfo = gv_CurrentSectorId and g_Units.Livewire and g_Units.Livewire.team == pov_team and gv_Sectors[gv_CurrentSectorId].intel_discovered -- Livewire's perk enabled
	active_units = IsKindOf(active_units, "Unit") and {active_units} or active_units
	local observers = g_Combat and {SelectedObj or nil} or (Selection or {})
	local full_visibility = IsFullVisibility()
	local sector = (gv_DeploymentStarted or gv_Deployment) and gv_Sectors[gv_CurrentSectorId]
	local pov_team_hidden = sector and sector.enabled_auto_deploy and pov_team.control == "UI"
	local is_current_team_pov_team = g_Teams[g_CurrentTeam] == pov_team
	local uvVisible = const.uvVisible
	local deployment_markers
	local camera_visibility_check_list = {}

	for i, unit in ipairs(g_Units) do
		if not IsValid(unit) then
		elseif unit:HasStatusEffect("SetpieceHidden") or unit:HasStatusEffect("ScriptingHidden") or IsValid(unit.death_fx_object) then
			unit:SetVisible(false, "force")
			unit:SetHighlightReason("visibility", nil)
		elseif gv_Deployment and IsMerc(unit) then
		elseif full_visibility then
			unit:SetVisible(true)
			unit:SetHighlightReason("visibility", false)
			unit:SetHighlightReason("concealed", false)
			unit:SetHighlightReason("obscured", false)
			unit:SetHighlightReason("faded", false)
		elseif not IsSetpieceActor(unit) then
			if IsValid(unit.prepared_attack_obj) then
				if unit.team:IsEnemySide(pov_team) then
					unit.prepared_attack_obj:SetColorFromTextStyle("PreparedAttackEnemy")
				else
					unit.prepared_attack_obj:SetColorFromTextStyle("PreparedAttackFriendly")
				end
			end
			if unit.team == pov_team then
				if unit.on_die_hit_descr and unit.on_die_hit_descr.death_explosion then
					unit:SetVisible(false)
					unit:SetHighlightReason("visibility", nil)
				elseif IsOnFadedSlab(unit) then
					unit:SetVisible(not pov_team_hidden)
					unit:SetHighlightReason("visibility", true)
				else
					unit:SetVisible(not pov_team_hidden)
					table.insert(camera_visibility_check_list, unit)
				end
			elseif unit:IsDead() then
				if unit.on_die_hit_descr and unit.on_die_hit_descr.death_explosion then
					unit:SetVisible(false, "force")
					unit:SetHighlightReason("visibility", nil)
				elseif IsOnFadedSlab(unit) then
					local interaction
					for _, au in ipairs(active_units) do
						if unit:GetInteractionCombatAction(au) then
							interaction = true
							break
						end
					end
					if interaction then
						unit:SetVisible(true)
						unit:SetHighlightReason("visibility", true)
					else
						unit:SetVisible(false, "force")
						unit:SetHighlightReason("visibility", nil)
					end
				else
					unit:SetVisible(true)
					unit:SetHighlightReason("visibility", nil)
				end
				-- weather fx
				unit:SetHighlightReason("concealed", unit:UIConcealed("skip"))
				unit:SetHighlightReason("obscured", unit:UIObscured())
			else
				local seen_by_player = innerInfo or HasVisibilityTo(pov_team, unit) and not unit:HasStatusEffect("Hidden")
				if not seen_by_player then
					if deployment_markers == nil then
						deployment_markers = (gv_DeploymentStarted or gv_Deployment) and GetAvailableDeploymentMarkers() or empty_table
						if #deployment_markers == 0 then deployment_markers = false end
					end
					if deployment_markers and IsUnitSeenByAnyDeploymentMarker(unit, deployment_markers) then
						seen_by_player = true
					end
				end
				if seen_by_player then
					-- actually seen by one of the player units
					unit:SetVisible(true)

					local los_active
					local on_faded_slab = IsOnFadedSlab(unit)
					if not on_faded_slab then
						if is_current_team_pov_team then
							for _, observer in ipairs(active_units) do
								if VisibilityCheckAll(observer, unit, nil, uvVisible) then
									los_active = true
									break
								end
							end
						else
							-- out of player turn do not use unit-based highlights
							los_active = true
						end
					end
					-- weather fx
					unit:SetHighlightReason("concealed", unit:UIConcealed("skip"))
					unit:SetHighlightReason("obscured", unit:UIObscured())

					if on_faded_slab or not los_active then
						unit:SetHighlightReason("visibility", true)
					else
						table.insert(camera_visibility_check_list, unit)
					end
					unit:SetHighlightReason("faded", on_faded_slab)
				elseif unit:HasStatusEffect("DiamondCarrier") then
					unit:SetVisible(true)
					unit:SetHighlightReason("visibility", true)
				else
					-- not seen at all
					unit:SetVisible(false)
				end
			end
		end
	end

	if #camera_visibility_check_list > 0 then
		local camera_visibility = IsVisibleFromCamera(camera_visibility_check_list)
		for i, unit in ipairs(camera_visibility_check_list) do
			unit:SetHighlightReason("visibility", not camera_visibility[i])
		end
	end
end

function Combat:ApplyVisibility(active_unit)
	active_unit = active_unit or SelectedObj or self.starting_unit
	
	local pov_team = GetPoVTeam()
	local playerControlled = g_Teams[g_CurrentTeam]:IsPlayerControlled() -- if player controlled but no selected obj, apply visibility for all as it is an edge case on turn end/start that causes flicker of object markings
	if pov_team ~= g_Teams[g_CurrentTeam] or (playerControlled and not SelectedObj) then -- during the turn of other teams use all units from PoV team to decide visibility
		active_unit = pov_team.units
	end
	
	ApplyUnitVisibility(active_unit, pov_team, g_Visibility)
	NetUpdateHash("CombatApplyVisibility", GameTime())
	Msg("CombatApplyVisibility", pov_team)
end

function Combat:ShouldEndDueToNoVisibility()
	if Game and Game.game_type == "PvP" then
		return
	end

	self.turns_no_visibility = self.turns_no_visibility + #g_Teams
	for _, t in ipairs(g_Teams) do
		for _, obj in ipairs(g_Visibility[t]) do
			if IsKindOf(obj, "Unit") and obj.team and obj.team:IsEnemySide(t) then
				self.turns_no_visibility = 0
				return false
			end
		end
	end
	
	return self.turns_no_visibility > 2 * #g_Teams
end

MapVar("g_VisibilityUpdateThread", false)
MapVar("g_UnitsLOS", {}, weak_keys_meta)

function InvalidateUnitLOS(unit)
	g_UnitsLOS[unit] = nil
	for u, los_tbl in pairs(g_UnitsLOS) do
		if los_tbl[unit] then
			los_tbl[unit] = nil
			table.remove_value(los_tbl, unit)
		end
	end
	VisibilityUpdate()
end

function InvalidateVisibility(force)
	g_UnitsLOS = setmetatable({}, weak_keys_meta)
	VisibilityUpdate(force)
end

MapVar("g_VisibilityLastUpdateTime", 0)
MapVar("g_VisiblityUpdatesCount", 0)
MapVar("g_VisiblityUpdatesTime", 0)
MapVar("g_VisiblityUpdatesReportTime", GetPreciseTicks()) -- For debug
MapVar("g_VisibilityUpdateSuspendReasons", {})
MapVar("ReportVisibilityUpdates", false)

-- Visibility in exploration can be a big performance hit,
-- so it is throttled to be invalidated in specific increments.
MapVar("g_VisibilityExplorationTick", false)
MapVar("g_VisibilityExplorationDirty", false)

MapGameTimeRepeat("ExplorationVisibilityUpdate", 500, function()
	if not g_VisibilityExplorationDirty then 
		return
	end
	g_VisibilityExplorationTick = true
	InvalidateVisibility()
	g_VisibilityExplorationDirty = false
	g_VisibilityExplorationTick = false
end)

function SuspendVisibiltyUpdates(reason)
	g_VisibilityUpdateSuspendReasons[reason] = true
end

function ResumeVisibiltyUpdates(reason)
	g_VisibilityUpdateSuspendReasons[reason] = nil
	if next(g_VisibilityUpdateSuspendReasons) == nil then
		VisibilityUpdate()
		return true
	end
end

function OnMsg.CombatActionStart(unit)
	if not g_Combat then return end
	SuspendVisibiltyUpdates(unit)
end

function OnMsg.CombatActionEnd(unit)
	if not g_Combat then return end
	CreateGameTimeThread(function()
		if	ResumeVisibiltyUpdates(unit) then
			WaitMsg("VisibilityUpdate")
		end
		if g_Combat then
			g_Combat:EndCombatCheck()
		end
	end)
end

local function lExplorationVisibilityApply()
	if g_Combat or g_StartingCombat or IsSetpiecePlaying() then
		return
	end
	
	local prev_visibility = g_Visibility or empty_table
	g_Visibility = ComputeUnitsVisibility()
	local pov_team = GetPoVTeam()
	if not pov_team then return end
	local active_units = Selection
	if not active_units or (#active_units == 0) then
		active_units = SelectedObj
	end
	
	ApplyUnitVisibility(active_units, pov_team, g_Visibility)
	
	local sees_enemy
	for _, seen in ipairs(g_Visibility[pov_team]) do
		if seen.team and pov_team:IsEnemySide(seen.team) and not seen:IsDead() then
			if not HasVisibilityTo(pov_team, seen, prev_visibility) then
				Msg("EnemySightedExploration", seen)
			end
			sees_enemy = true
		end
	end
	
	if g_TestCombat and sees_enemy then
		NetSyncEvent("ExplorationStartCombat")
	end
end

function VisibilityUpdate(force)
	local cleanup = {}
	for reason, _ in sorted_handled_obj_key_pairs(g_VisibilityUpdateSuspendReasons) do
		if IsKindOf(reason, "Unit") and reason:IsDead() then
			cleanup[#cleanup + 1] = reason
		end
	end
	for _, reason in ipairs(cleanup) do
		g_VisibilityUpdateSuspendReasons[reason] = nil
	end
	NetUpdateHash("VisibilityUpdate()", GameTime(), #table.keys(g_VisibilityUpdateSuspendReasons), force)
	if next(g_VisibilityUpdateSuspendReasons) ~= nil and not force then
		return
	end
	-- run in a thread to avoid overly aggressive updates 
	if not IsValidThread(g_VisibilityUpdateThread) then
		if not g_Combat then
			g_VisibilityExplorationDirty = true
			if not g_VisibilityExplorationTick then 
				return 
			end
		end
		g_VisibilityLastUpdateTime = GameTime()
		g_VisibilityUpdateThread = CreateGameTimeThread(function(force)
			local tStart = GetPreciseTicks()

			if g_Combat then
				if force then
					g_Combat.visibility_update_hash = false
				end
				g_Combat:UpdateVisibility()
				g_Combat:ApplyVisibility()
			else
				lExplorationVisibilityApply()
			end

			NetUpdateHash("VisibilityUpdate", GameTime(), Visibility_UnitsHash(), Visibility_ResultsHash())
			Msg("VisibilityUpdate")
			ObjModified("VisibilityUpdate")
			g_VisibilityUpdateThread = false
			
			if ReportVisibilityUpdates then
				local time_now = GetPreciseTicks()
				local update_time = time_now - tStart
				g_VisiblityUpdatesCount = g_VisiblityUpdatesCount + 1
				g_VisiblityUpdatesTime = g_VisiblityUpdatesTime + update_time

				if time_now - g_VisiblityUpdatesReportTime > 1000 then
					printf("%d visibility updates in the last second, %d ms spent updating in total, %d ms per call", 
						g_VisiblityUpdatesCount, g_VisiblityUpdatesTime, g_VisiblityUpdatesTime / g_VisiblityUpdatesCount)

					g_VisiblityUpdatesCount = 0
					g_VisiblityUpdatesTime = 0
					g_VisiblityUpdatesReportTime = time_now
				end
			end
		end, force)
	end
end

function NetSyncEvents.RecalcVisibility()
	WaitRecalcVisibility = false
	if g_Combat then
		g_Combat:UpdateVisibility()
		g_Combat:ApplyVisibility()
	end
end

MapVar("WaitRecalcVisibility", false) --flag used to stop flickering of objects on selection change by early out in UpdateHighlightMarking
function OnMsg.SelectionChange()
	if g_Combat and g_Combat.combat_started then
		WaitRecalcVisibility = true
		NetSyncEvent("RecalcVisibility")
	end
end

function OnMsg.UnitMovementDone(unit)
	 -- update .indoors first so ApplyVisibility -> Obscured/ConcealedCheck work on correct data
	UpdateIndoors(unit)
	InvalidateUnitLOS(unit)
end

OnMsg.CombatGotoStep = InvalidateUnitLOS
OnMsg.UnitStanceChanged = InvalidateUnitLOS
function OnMsg.UnitDieStart(...)
	if g_Combat then
		g_Combat.visibility_update_hash = false
	end

	InvalidateUnitLOS(...)

	-- Used by the "FullVisibility" cheat. We dont want dead units in visibility
	g_VisibilityUpdated = false
end

function OnMsg.LoadSessionData()
	g_VisibilityExplorationTick = true
	InvalidateVisibility("force")
	g_VisibilityExplorationTick = false
end

function OnMsg.OnPassabilityChanged()
	-- Doors opening etc
	if IsEditorActive() then return end
	InvalidateVisibility("force")
end
OnMsg.OverwatchChanged = function() NetUpdateHash("VU_OverwatchChanged"); VisibilityUpdate(); end
OnMsg.GameExitEditor = InvalidateVisibility
OnMsg.UnitAwarenessChanged = InvalidateUnitLOS
OnMsg.UnitStealthChanged = InvalidateVisibility
OnMsg.GroupChangeSide = function() NetUpdateHash("VU_GroupChangeSide"); VisibilityUpdate(); end
OnMsg.DiplomacyInvalidated = function() NetUpdateHash("VU_DiplomacyInvalidated"); VisibilityUpdate(); end

function OnMsg.TurnStart(team)
	team = g_Teams[team]
	
	-- clear Revealed for our units
	for _, unit in ipairs(team.units) do
		for _, list in pairs(g_RevealedUnits) do
			table.remove_value(list, unit)			
		end
		unit:RemoveStatusEffect("Revealed")
	end
	
	-- mark all visible units as revealed until the end of their turn to make sure they don't disappear or gain Hidden passively
	local units = g_Visibility[team]
	g_RevealedUnits[team] = g_RevealedUnits[team] or {}
	for _, unit in ipairs(units) do
		if team:IsEnemySide(unit.team) then
			assert(not unit:HasStatusEffect("Hidden"))
			unit:RevealTo(team)
		end
	end
end

function ReapplyUnitVisibility(force)
	local pov_team = GetPoVTeam()
	if not pov_team then return end
	local active_units = Selection
	if not active_units or (#active_units == 0) then
		active_units = SelectedObj or pov_team.units
	end
	ApplyUnitVisibility(active_units, pov_team, g_Visibility, force)
end

function OnMsg.WallVisibilityChanged()
	NetSyncEvent("ReapplyUnitVisibility")
end

function OnMsg.SetObjectDetail(stage)
	if stage == "done" then
		NetSyncEvent("ReapplyUnitVisibility")
	end
end

local last_camera_hash = 0
MapRealTimeRepeat("unit_visibility", 250, function()
	if not cameraTac.IsActive() then return end
	
	local eye, lookat = cameraTac.GetPosLookAt()
	local hash = xxhash(GetMap(), eye, lookat)
	if hash ~= last_camera_hash then
		NetSyncEvent("ReapplyUnitVisibility")
		last_camera_hash = hash
	end
end)

function NetSyncEvents.ReapplyUnitVisibility()
	ReapplyUnitVisibility()
end

function OnMsg.EntitiesLoaded()
	SetupEntityObstructionMasks()
end

AppendClass.EntitySpecProperties = {
	properties = {
		{ id = "obstruction", name = "Blocks line of sight", editor = "bool", category = "Misc", default = false, entitydata = true, },
		{ id = "provide_cover", name = "Provide cover", editor = "bool", default = true, entitydata = true, },
	},
}

function SetupEntityObstructionMasks()
	local obstruction_entities = {}
	local cover_entities = {}
	local materials = Presets.ObjMaterial.Default
	for k in pairs(GetAllEntities()) do
		local t = EntityData[k]
		if t then
			local entity = t.entity
			local material = entity and materials[entity.material_type]
			if	t.editor_category == "Slab" and t.editor_subcategory ~= "Window" and t.editor_subcategory ~= "Door" or 
				t.editor_category == "Rock" or
				entity and entity.obstruction or
				material and material.impenetrable or
				k:find("WallExt") or
				k:find("WallInt") or
				k:find("Floor") or
				k:find("Roof") or
				k:find("Stairs") or
				k:find("Vehicle") or
				k:find("WaterPlane")
			then
				obstruction_entities[#obstruction_entities+1] = k
			end
			if entity and entity.provide_cover ~= false then
				cover_entities[#cover_entities + 1] = k
			end
		end
	end
	SetEntityObstructionMasks(obstruction_entities, cover_entities)
end

