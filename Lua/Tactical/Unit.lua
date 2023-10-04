const.AnimChannel_RightHandGrip = 2
const.AnimChannel_Pain = 3
const.PathTurnAnimChnl = 4
--const.AnimChannel_VerticalGrip

const.PainAnimWeight = 1000
const.PainAnimGrazingWeight = 300
const.PainAnimWeightMoment = 100
local PainEasing = GetEasingIndex("Sin in/out")

const.StopAnimCrossfadeTime = 400

DefineConstInt("Camera", "BufferSizeNoCameraMov", 30, 1, "Defines how much buffer (100% - the_value % from each side) of the screen will NOT be taken into account when deciding if camera should snap from one point to another.")

if FirstLoad then
	g_LocPollyActors = {
		{ value = "Nicole", text = "Nicole (female)", },
		{ value = "Amy", text = "Amy (female)", },
		{ value = "Emma", text = "Emma (female)", },
		{ value = "Aditi", text = "Aditi (female)", },
		{ value = "Raveena", text = "Raveena (female)", },
		{ value = "Joanna", text = "Joanna (female)", },
		{ value = "Kendra", text = "Kendra (female)", },
		{ value = "Kimberly", text = "Kimberly (female)", },
		{ value = "Salli", text = "Salli (female)", },
		-- { value = "Tatyana", text = "Tatyana (female)", }, -- disabled because other Russian-accent voice, Maxim below, produces garbled voice, don't use without checking it it's fixed by Amazon
		{ value = "Russell", text = "Russell (male)", },
		{ value = "Brian", text = "Brian (male)", },
		{ value = "Joey", text = "Joey (male)", },
		{ value = "Matthew", text = "Matthew (male)", },
		{ value = "Geraint", text = "Geraint (male)", },
		-- { value = "Maxim", text = "Maxim (male)" }, -- produces garbled voice, don't use without checking it it's fixed by Amazon
		{ value = "Ivy", text = "Ivy (child)", },
		{ value = "Justin", text = "Justin (child)", },
	}
	g_LocPollyActorsMatchTable = {}
	g_StanceActionDefault = "do not change"
end

local RandomWalkAnimBehaviors = {
	["Visit"] = true,
	["Roam"] = true,
	["RoamSingle"] = true,
	["Ambient"] = true,
}

HpToText = {
	Hidden = T{""},
	Dead = T(541985975283, "Dead"),
	Dying = T(179713645915, "Almost dead"),
	Critical = T(127741862032, "Severely Wounded"),
	Wounded = T(811971736433, "Wounded"),
	Poor = T(121790238609, "Weak"),
	Healthy = T(150774995803, "Healthy"),
	Strong = T(830864531146, "Strong"),
	Excellent = T(341748793018, "Very strong"),
	Uninjured = T(586026778443, "Uninjured"),
}

DieChanceToText = {
	None = T(971598159331, --[[chance to die]] "None"),
	Low = T(283826279782, --[[chance to die]] "Low"),
	Moderate = T(904355103349, --[[chance to die]] "Moderate"),
	High = T(295409078209, --[[chance to die]] "High"),
	VeryHigh = T(426026245987, --[[chance to die]] "Very High"),
}

local KeepAimIKCommands = {
	Idle = true,
	AimIdle = true,
	OpportunityAttack = true,
	PreparedAttackIdle = true,
	ExecFirearmAttacks = true,
	HeavyWeaponAttack = true,
	FirearmAttack = true,
}

DefineClass.Unit = {
	__parents = { "Movable", "CombatObject", "UnitProperties", "UnitInventory", "StatusEffectObject",
		"GameDynamicSpawnObject", "AppearanceObject", "Interactable", "StepObject", "SyncObject", "ComponentSound",
		"SpawnFXObject", "HittableObject", "ComponentCustomData", "CombatTaskOwner", "AmbientLifeZoneUnit",
	},
	
	properties = {
		{category = "Ambient Life", id = "ViewPerpetual", editor = "buttons", default = false,
			no_edit = function(self) return not self.perpetual_marker end,
			buttons = {
				{ name = "View Perpetual Marker", func = function(self)
					ViewObject(self.perpetual_marker)
				end},
				{ name = "Select Perpetual Marker", func = function(self)
					editor.ClearSel()
					editor.AddObjToSel(self.perpetual_marker)
				end},
			},
		},
		{category = "Ambient Life", id = "ViewSpawner", editor = "buttons", default = false,
			no_edit = function(self) return not self.spawner end,
			buttons = {
				{ name = "View Spawner", func = function(self)
					ViewObject(self.spawner)
				end},
				{ name = "Select  Spawner", func = function(self)
					editor.ClearSel()
					editor.AddObjToSel(self.spawner)
				end},
			},
		},
		{category = "Ambient Life", id = "ViewRoutineSpawner", editor = "buttons", default = false,
			no_edit = function(self) return not self.routine_spawner end,
			buttons = {
				{ name = "View Routine Spawner", func = function(self)
					ViewObject(self.routine_spawner)
				end},
				{ name = "Select Routine Spawner", func = function(self)
					editor.ClearSel()
					editor.AddObjToSel(self.routine_spawner)
				end},
			},
		},
		-- hidden overridden properties
		{id = "animWeight"},
		{id = "animBlendTime"},
		{id = "anim2"},
		{id = "anim2BlendTime"},
	},
	
	flags = { efUnit = true, cofComponentColorizationMaterial = true, gofUnitLighting = true, gofOnRoof = false, gofAdjustZ = true },
	pfclass = 3,
	pfflags = const.pfmDestlockSmart + const.pfmCollisionAvoidance + const.pfmImpassableSource + const.pfmVoxelAligned + const.pfmOrient,
	pfclass_overwritten = false,
	ground_orient = false,
	anim_moments_single_thread = true,
	material_type = "Flesh",
	species = "Human",
	body_type = "Human",
	default_move_style = false,
	cur_move_style = false,
	cur_idle_style = false,
	move_step_fx = false,
	move_stop_anim_len = 0,
	move_stop_foot_left_anim = false,
	move_stop_foot_right_anim = false,

	-- Do not forget to add new class members to Get/SetDynamicData function to save in Game state (see GetCurrentGameVarValues)

	Appearance = false,
	-- reference to the corresponding UnitData in gv_UnitData[unit.session_id], all units (except setpiece testing clones) have this
	session_id = false,
	team = false,

	collision_radius = const.SlabSizeX/3,
	radius = const.SlabSizeX/4,

	stance = "Standing",
	unitdatadef_id = false, -- id in UnitDataDefs
	group = false, -- from UnitDataDefs[self.unitdatadef_id]
	target_dummy = false,
	cover_last_face_time = false,
	last_attack_session_id = false,
	current_weapon = "Handheld A",
	modify_animations_ar = false,

	aim_action_id = false,
	aim_action_params = false,
	aim_results = false,
	aim_attack_args = false,
	aim_fx_target = false,
	aim_fx_thread = false,
	aim_rotate_last_angle = false,
	aim_rotate_cooldown_time = false,
	action_visual_weapon = false,
	weapon_light_fx = false,

	return_pos = false,
	play_sequential_actions = false,
	command_specific_params = false,
	prepared_attack_obj = false,
	melee_threat_contour = false,
	prepared_bombard_zone = false,
	bombard_weapon = false,
	queued_action_id = false,
	queued_action_visual = false,
	queued_action_pos = false,

	is_melee_aim_last_turn = false,
	downing_action_start_time = false,

	last_turn_movement = false,
	last_turn_damaged = false,
	start_turn_pos = false,
	reposition_dest = false,
	reposition_path = false,
	reposition_marker = false,
	last_orientation_angle = false,

	god_mode = false,
	infinite_ammo = false,
	infinite_ap = false,
	infinite_dmg = false,
	infinite_condition = false,

	action_command = false,
	actions_nettravel = 0,  -- sent but not received yet
	ui_reserved_ap = 0,
	ui_override_ap = false, -- when set to something GetUIActionPoints will return this value to hide underlying AP shenanigans
	free_move_ap = 0,
	start_move_total_ap = 0,
	start_move_cost_ap = 0,
	start_move_free_ap = 0,

	combat_path = false,
	combat_path_obj = false,
	using_cumbersome = false, -- has any equipped Cumbersome items (cached, no need to save/load)
	attacked_this_turn = false,
	hit_this_turn = false,
	performed_action_this_turn = false,
	wounded_this_turn = false,
	downed_check_penalty = 0,

	ai_context = false,

	interruptable = true,
	interrupted = false,
	goto_interrupted = false,
	interrupt_callback = false,
	action_interrupt_callback = false,

	is_moving = false,
	goto_target = false,
	goto_stance = false,
	goto_hide = false,
	in_combat_movement = false,
	visibility_override = false,
	traverse_tunnel = false,
	tunnel_blockers = false,
	fallback_walk_speed = 3*guim, -- when the walk anim has no step
	perks_activated = false,
	attack_reason = false, -- additional prefix text to attack log entry (e.g. retaliation, overwatch, etc)
	opportunity_attack = false,
	effect_values = false, -- storage for status effect data/state
	enemy_visual_contact = false, -- does any enemy has visual contact with this unit
	alerted_by_enemy = false,
	last_known_enemy_pos = false, -- last location an enemy unit was seen
	marked_target_attack_args = false,
	
	pending_aware_state = false,
	pending_awareness_role = false,	 -- used for awareness visualization; not persisted
	suspicion = false,
	suspicious_body_seen = false,
	aware_reason = false,
	auto_face = true, -- the unit look at the nearest enemy
	reorientation_thread = false,
	setik_thread = false,

	spawner = false,  --NPC

	synced_anim = false,
	synced_anim_time = 0,
	synced_angle = 0,
	die_anim_prefix = false,
	on_die_attacker = false,
	on_die_hit_descr = false,
	death_explosion_played = false,
	death_fx_object = false,
	interacting_unit = false,
	killed_stance = false,

	combat_badge = false,
	ui_badge = false,
	ui_actions = false,
	combat_cache = false,
	villain_defeated = false,
	retreating = false,
	angle_before_interaction = false,
	highlight_reasons = false,

	banters = false,
	banters_played_lines = false,
	sequential_banter = false,
	approach_banters = false,
	approach_banters_distance = false,
	approach_banters_cooldown_id = false,
	last_played_banter_id = false, -- No need to serialize this
	
	visible = true,
	interactable_highlight_ctr = false,
	highlight_collection = false,
	
	-- general (out-of-combat) behaviors
	behavior = false, -- command to set
	behavior_params = false, -- parameters to set

	-- in-combat behaviors
	combat_behavior = false, -- command to set
	combat_behavior_params = false, -- parameters to set

	entrance_marker = false,

	neutral_ai_dont_move = false,
	neutral_retal_attacked = false,

	pain_thread = false,
	update_attached_weapons_thread = false,

	routine = "StandStill",
	routine_area = "self",
	routine_spawner = false,
	ephemeral = false,
	perpetual_marker = false,
	teleport_allowed_once = false,
	conflict_ignore = false,
	visit_command = false,
	visit_marker = false,
	visit_reached = false,
	cower_from = false,
	cower_angle = false,
	cower_cooldown = false,
	last_roam = false,
	last_visit = false,
	dead_markers_tried = false,
	mourn = false,
	maraud = false,
	enter_map_wait_time = false,
	enter_map_pos = false,
	seen_bodies = false,
	visit_test = false,
	carry_flare = false,
	infected = false,
	innerInfoRevealed = false, --used to mark the unit when revealed from the perk innerinfo

	fx_in_water = false,
	indoors = false,
	unarmed_weapon = false,
	warned_traps_pos = false,
	move_follow_target = false,
	move_follow_dest = false,
	move_attack_target = false,
	move_attack_action_id = false,
	move_attack_in_progress = false,
	waiting_attack = false,

	last_idle_aiming_time = false,

	place_wind_mod_trails = false,
	stain_update_times = false, -- async, visual, not saved

	__toluacode = empty_func,
	PrePlay = empty_func,
	PostPlay = empty_func,
	
	throw_died_message = false,
	is_despawned = false -- Set briefly in Unit:Despawn before it is destroyed but after the sync with unitdata.
}

local function StoreBehaviorParamTbl(tbl)
	if not tbl then return end
	local stored, stored_handles
	for k, v in pairs(tbl) do
		if IsKindOf(v, "Object") then
			if not stored_handles then
				stored_handles = {}
				stored = stored or {}
				stored.__stored_obj_value = stored_handles
			end
			stored[k] = v.handle
			stored_handles[k] = true
		elseif type(v) == "table" then
			local new_value = StoreBehaviorParamTbl(v)
			if new_value ~= v then
				if not stored then
					stored = {}
				end
				stored[k] = new_value
			end
		end
	end
	if not stored then
		return tbl
	end
	-- copy the skipped values
	for k, v in pairs(tbl) do
		if stored[k] == nil then
			stored[k] = v
		end
	end
	return stored
end

local function RestoreBehaviorParamTbl(stored)
	if not stored then return end
	local stored_handles = stored.__stored_obj_value
	if stored_handles then
		stored.__stored_obj_value = nil
	end
	for k, v in pairs(stored) do
		if type(v) == "table" then
			RestoreBehaviorParamTbl(v)
		end
	end
	for k in pairs(stored_handles) do
		stored[k] = HandleToObject[ stored[k] ]
	end
end

function Unit:GetDynamicData(data)
	local class = g_Classes[self.class]
	data.session_id = self.session_id or nil
	data.unitdatadef_id = self.unitdatadef_id or nil
	data.ground_orient = self.ground_orient or nil
	data.stance  = self.stance ~= class.stance and self.stance or nil
	data.return_pos = self.return_pos or nil
	data.current_weapon = self.current_weapon ~= class.current_weapon and self.current_weapon or nil
	data.perks_activated = next(self.perks_activated) and self.perks_activated or nil
	data.Groups = #(self.Groups or "") > 0 and self.Groups or nil
	data.villain_defeated = self.villain_defeated or nil
	data.retreating = self.retreating or nil
	if self.command == "BanterIdle" then
		data.command = "Idle"
	end
	data.command_specific_params = next(self.command_specific_params) and self.command_specific_params or nil
	data.last_attack_session_id = self.last_attack_session_id or nil
	data.banters_played_lines = self.banters_played_lines or nil
	data.free_move_ap = self.free_move_ap ~= 0 and self.free_move_ap or nil
	data.neutral_ai_dont_move = self.neutral_ai_dont_move or nil
	data.enemy_visual_contact = self.enemy_visual_contact or nil
	data.effect_values = next(self.effect_values) and self.effect_values or nil
	data.is_melee_aim_last_turn = self.is_melee_aim_last_turn or nil
	data.performed_action_this_turn = self.performed_action_this_turn or nil
	data.carry_flare = self.carry_flare or nil

	for i, unit in ipairs(self.attacked_this_turn) do
		data.attacked_this_turn = data.attacked_this_turn or {}
		data.attacked_this_turn[i] = unit.handle
	end
	for i, unit in ipairs(self.hit_this_turn) do
		data.hit_this_turn = data.hit_this_turn or {}
		data.hit_this_turn[i] = unit.handle
	end
	for unit, _ in pairs(self.seen_bodies) do
		data.seen_bodies = data.seen_bodies or {}
		data.seen_bodies[unit:GetHandle()] = true
	end
	data.visit_test = self.visit_test or nil
	data.wounded_this_turn = self.wounded_this_turn or nil
	data.downed_check_penalty = self.downed_check_penalty ~= 0 and self.downed_check_penalty or nil
	data.last_known_enemy_pos = self.last_known_enemy_pos or nil
	data.last_turn_damaged = self.last_turn_damaged or nil

	if self.target_dummy then
		data.pos = self.target_dummy:GetPos()
		data.vpos = nil
		data.vpos_time = nil
	elseif self.traverse_tunnel then
		data.pos = self.traverse_tunnel.end_point
		data.vpos = nil
		data.vpos_time = nil
	end
	if self.behavior then
		data.behavior = self.behavior
		data.behavior_params = StoreBehaviorParamTbl(self.behavior_params)
		if data.behavior == "ExitMap" and data.behavior_params[2] then
			data.behavior_params[2] = Max(0, data.behavior_params[2] - GameTime())
		end
	end
	if self.combat_behavior then
		data.combat_behavior = self.combat_behavior
		data.combat_behavior_params = StoreBehaviorParamTbl(self.combat_behavior_params)
	end
	if self.marked_target_attack_args then
		data.marked_target_attack_args = StoreBehaviorParamTbl(self.marked_target_attack_args)
	end
	if self.spawner then
		data.spawner = self.spawner.handle
	end
	if IsValid(self.prepared_bombard_zone) then
		data.prepared_bombard_zone = self.prepared_bombard_zone.handle
	end

	if next(self.banters) then
		data.banters = self.banters
		data.sequential_banter = self.sequential_banter or nil
	end
	if next(self.approach_banters) then
		data.approach_banters = self.approach_banters
		data.approach_banters_distance = self.approach_banters_distance or nil
		data.approach_banters_cooldown_id = self.approach_banters_cooldown_id or nil
	end
	data.die_anim_prefix = self.die_anim_prefix or nil

	data.aware = self:IsAware() or nil
	data.pending_aware_state = self.pending_aware_state or nil
	data.suspicion = (self.suspicion or 0) > 0 and self.suspicion or nil
	data.suspicious_body_seen = self.suspicious_body_seen or nil
	if IsValid(self.alerted_by_enemy) then
		data.alerted_by_enemy = self.alerted_by_enemy.handle
	end

	data.routine = (self.routine ~= class.routine) and self.routine or nil
	data.routine_area = (self.routine_area ~= class.routine_area) and self.routine_area or nil
	data.routine_spawner = self.routine_spawner and self.routine_spawner.handle or nil
	data.zone = self.zone and self.zone.handle or nil
	data.ephemeral = self.ephemeral or nil
	data.perpetual_marker = self.perpetual_marker and self.perpetual_marker.handle or nil
	data.teleport_allowed_once = self.teleport_allowed_once or nil
	data.conflict_ignore =self.conflict_ignore or nil
	data.visit_command = self.visit_command or nil
	data.visit_reached = self.visit_reached or nil
	data.max_dead_slot_tiles = self.max_dead_slot_tiles or nil
	if self.visit_marker then
		data.visit_marker = self.visit_marker.handle
	end
	if self.cower_from then
		data.cower_from = self.cower_from
		data.cower_angle = self.cower_angle or nil
	end
	data.cower_cooldown = self.cower_cooldown or nil
	data.last_roam = self.last_roam and self.last_roam.handle or nil
	data.last_visit = self.last_visit and self.last_visit.handle or nil
	data.dead_markers_tried = self.dead_markers_tried or nil
	data.mourn = self.mourn and self.mourn.handle or nil
	data.maraud = self.maraud and self.maraud.handle or nil
	data.enter_map_wait_time = self.enter_map_wait_time and (self.enter_map_wait_time - GameTime()) or nil
	data.enter_map_pos = self.enter_map_pos or nil

	local unit_data = UnitDataDefs[self.unitdatadef_id]
	if self.Name ~= (unit_data and unit_data.Name) then
		data.Name = self.Name
	end
	data.default_move_style = self.default_move_style or nil
	data.cur_move_style = self.cur_move_style or nil
	data.cur_idle_style = self.cur_idle_style or nil
	data.on_die_hit_descr = self.on_die_hit_descr or nil
	data.death_explosion_played = self.death_explosion_played or nil
	data.infected = self.infected or nil
	data.innerInfoRevealed = self.innerInfoRevealed or nil
	data.throw_died_message = self.throw_died_message or nil
	data.lastFiringMode = self.lastFiringMode or nil
	data.queued_action_id = self.queued_action_id or nil
end

function Unit:SetDynamicData(data)
	self.session_id = data.session_id
	self.unitdatadef_id = data.unitdatadef_id or data.template_name

	self.spawner = HandleToObject[data.spawner]
--[[	if self.spawner then
		self.spawner.object = self
	end]]
	self.target_dummy = HandleToObject[data.target_dummy]

	-- these are needed to be restored before calling EnterMap command of AL
	self.zone = HandleToObject[data.zone] or false
	for _, group_name in ipairs(data.Groups) do
		self:AddToGroup(group_name)
	end
	self.enter_map_wait_time = data.enter_map_wait_time or false
	self.enter_map_pos = data.enter_map_pos or false
	if data.combat_behavior then
		RestoreBehaviorParamTbl(data.combat_behavior_params)
		self:SetCombatBehavior(data.combat_behavior, data.combat_behavior_params)
	end
	if data.behavior then
		RestoreBehaviorParamTbl(data.behavior_params)
		if data.behavior == "OverwatchAction" or data.behavior == "PinDown" then
			self:SetCombatBehavior(data.behavior, data.behavior_params)
			self:SetBehavior(data.behavior, data.behavior_params)
		elseif data.behavior == "Dead" or data.behavior == "VillainDefeat" or data.behavior == "Hang" then
			self:SetCombatBehavior(data.behavior, data.behavior_params)
			self:SetBehavior(data.behavior, data.behavior_params)
		elseif data.behavior == "ExitMap" then
			if data.behavior_params[2] then
				data.behavior_params[2] = GameTime() + data.behavior_params[2]
			end
			self:SetBehavior(data.behavior, data.behavior_params)
		else
			self:SetBehavior(data.behavior, data.behavior_params)
		end
	end
	if data.marked_target_attack_args then
		self.marked_target_attack_args = RestoreBehaviorParamTbl(data.marked_target_attack_args)
	end
	 -- this needs to be after restoring self.spawner - long chain of invocations that ultimately results in a neutral unit
	if self.enter_map_wait_time and not IsKindOf(self.zone, "AmbientZoneMarker") then
		-- NOTE: old save with new map source for which unit's spawner zone has been deleted from the map
		DoneObject(self)
		return
	end
	self.last_roam = HandleToObject[data.last_roam] or false
	self.last_visit = HandleToObject[data.last_visit] or false
	self.perpetual_marker = HandleToObject[data.perpetual_marker] or false	-- needed to restore Visit cmd
	self.visit_reached = data.visit_reached or false
	self:FillMerc()

	self.stance = self.species ~= "Human" and "" or data.stance
	
	-- Weird save game compat
	if self.stance and type(self.stance) == "boolean" then
		self.stance = self.species ~= "Human" and "" or "Standing"
	end
	
	self.return_pos = data.return_pos
	self.current_weapon = data.current_weapon
	self.perks_activated = data.perks_activated or {}
	self.villain_defeated = data.villain_defeated
	self.retreating = data.retreating
	self.command_specific_params = data.command_specific_params
	self.last_attack_session_id = data.last_attack_session_id
	self.free_move_ap = data.free_move_ap
	self.neutral_ai_dont_move = data.neutral_ai_dont_move
	self.effect_values = table.copy(data.effect_values or data.effect_expirations or {}) -- savegame compat support (effect_expirations)
	self.is_melee_aim_last_turn = data.is_melee_aim_last_turn or false
	self.enemy_visual_contact = data.enemy_visual_contact
	self.suspicion = data.suspicion
	self.suspicious_body_seen = data.suspicious_body_seen
	self.pending_aware_state = data.pending_aware_state
	if self.pending_aware_state == "reposition" then
		self.pending_aware_state = nil
	end
	self.max_dead_slot_tiles = data.max_dead_slot_tiles or false
	if data.aware then
		self:RemoveStatusEffect("Unaware")
		self:RemoveStatusEffect("Suspicious")
	end
	self.alerted_by_enemy = HandleToObject[data.alerted_by_enemy]
	self.last_known_enemy_pos = data.last_known_enemy_pos
	self.last_turn_damaged = data.last_turn_damaged
	self.performed_action_this_turn = data.performed_action_this_turn
	if data.carry_flare then
		self:RoamAttachFlare()
	end

	self.attacked_this_turn = {}
	for i, handle in ipairs(data.attacked_this_turn) do
		self.attacked_this_turn[i] = HandleToObject[handle]
	end
	self.hit_this_turn = {}
	for i, handle in ipairs(data.hit_this_turn) do
		self.hit_this_turn[i] = HandleToObject[handle]
	end
	self.seen_bodies = {}
	for handle, _ in pairs(data.seen_bodies) do
		local unit = HandleToObject[handle] or false
		self.seen_bodies[unit] = true
	end
	self.visit_test = data.visit_test or false
	self.wounded_this_turn = data.wounded_this_turn
	self.downed_check_penalty = data.downed_check_penalty	
	
	if data.prepared_bombard_zone then
		self.prepared_bombard_zone = HandleToObject[data.prepared_bombard_zone]
	end

	self.die_anim_prefix = data.die_anim_prefix
	self:UpdateMoveAnim()
	self:OnGearChanged("isLoad")

	-- shuffle looping animations
	if self:IsAnimLooping(1) then
		local phase = self:Random(GetAnimDuration(self:GetEntity(), self:GetAnim(1)))
		self:SetAnimPhase(1, phase)
	end

	self.banters = data.banters
	self.sequential_banter = data.sequential_banter or false
	self.banters_played_lines = data.banters_played_lines or false
	self.approach_banters = data.approach_banters
	self.approach_banters_distance = data.approach_banters_distance
	self.approach_banters_cooldown_id = data.approach_banters_cooldown_id

	self.routine = data.routine or "StandStill"
	self.routine_area = data.routine_area or "self"
	self.routine_spawner = HandleToObject[data.routine_spawner] or false
	self.ephemeral = data.ephemeral or false
	self.teleport_allowed_once = data.teleport_allowed_once or false
	self.conflict_ignore = data.conflict_ignore or false
	self.visit_command = data.visit_command or false
	self.visit_marker = HandleToObject[data.visit_marker] or false
	self.cower_from = data.cower_from or false
	self.cower_angle = data.cower_angle or false
	self.cower_cooldown = data.cower_cooldown or false
	self.dead_markers_tried = data.dead_markers_tried or false
	self.mourn = HandleToObject[data.mourn] or false
	self.maraud = HandleToObject[data.maraud] or false

	if data.Name then
		self.Name = data.Name
	end
	if data.ground_orient then
		self:SetFootPlant(true, 0)
	else
		self:SetAxis(axis_z)
	end
	self.default_move_style = data.default_move_style or false
	self.cur_move_style = data.cur_move_style or false
	self.cur_idle_style = data.cur_idle_style or false
	self.on_die_hit_descr = data.on_die_hit_descr or false
	if data.death_explosion_played then
		self.death_explosion_played = data.death_explosion_played
		self:PlaceDeathFXObject(true)
	end
	self.infected = data.infected or false
	self.innerInfoRevealed = data.innerInfoRevealed or false
	if self.command == "Idle" and self:IsValidPos() then
		local x, y, z = GetPassSlabXYZ(self)
		if not x or not CanDestlock(self, x, y, z) then
			local has_path, pos = pf.HasPosPath(self, self)
			if pos then
				self:SetPos(pos)
			end
		end
	end
	
	self.throw_died_message = data.throw_died_message or false
	self.lastFiringMode = data.lastFiringMode or false
	self.queued_action_id = data.queued_action_id or false
end

function OnMsg.UnitCreated(self)
	if self.unitdatadef_id and next(UnitDataDefs[self.unitdatadef_id].AdditionalGroups) then
		self:AddAdditionalGroups()
	end
end

function Unit:SetQueuedAction(id)
	self.queued_action_id = id or false
	if self.ui_badge then
		self.ui_badge:UpdateEnemyVisibility()
	end
	if not self.queued_action_id then
		if IsValid(self.queued_action_visual) then
			DoneObject(self.queued_action_visual)
			self.queued_action_visual = false
		end
		self.queued_action_pos = false
	end	
end

function Unit:AddAdditionalGroups()
	if next(self.additional_groups) then 
		for _, group in ipairs(self.additional_groups) do
			self:AddToGroup(group)
		end
	else
		self.additional_groups = {}
		local exclusiveTable = {}
		for _, group in ipairs(UnitDataDefs[self.unitdatadef_id].AdditionalGroups) do
			if group.Exclusive then
				table.insert(exclusiveTable, {Name = group.Name, Weight = group.Weight})
			else
				local roll = InteractionRand(100, "BanterGroup")
				if roll < group.Weight then
					self:AddToGroup(group.Name) 
					table.insert(self.additional_groups, group.Name)
				end
			end
		end
		
		if next(exclusiveTable) then
			local exclusiveGroup = table.weighted_rand(exclusiveTable, "Weight", InteractionRand(1000000, "BanterGroup"))
			self:AddToGroup(exclusiveGroup.Name)
			table.insert(self.additional_groups, exclusiveGroup.Name)
		end
	end
end

function Unit:Init()
	-- copy base values from material def
	if self.unitdatadef_id then
		self:AddToGroup(self.unitdatadef_id)
	end
	if not self.command_specific_params then
		self.command_specific_params = {}
		if self.spawner then
			local params = {
				weapon_anim_prefix = not self.spawner.use_weapons and "civ_" or nil,
			}
			params.idle_stance = self.spawner.idle_stance ~= g_StanceActionDefault and self.spawner.idle_stance or nil
			params.idle_action = self.spawner.idle_action ~= g_StanceActionDefault and self.spawner.idle_action or nil
			self:SetCommandParams("Idle", params)
			self:SetCommandParams("Visit", params)
			self:SetCommandParams("Roam", params)
			self:SetCommandParams("RoamSingle", params)
		end
	end
	if self.session_id then
		self:InitMerc()
		self:UpdateOutfit()
		self.retreating = nil -- spawning anew resets this status
		if self.villain then
			self:AddToGroup("Villains")
		end
	end
	self.perks_activated = {}
	self.seen_bodies = {}
	self.stain_update_times = {}
	self.AIKeywords = table.copy(self.AIKeywords)
	if IsMerc(self) then
		self.fx_actor_class = "ImportantUnit"
	end
	Msg("UnitCreated", self)
end

function Unit:InitFromMaterialPreset(preset)
end

function Unit:Done()
	self:RemoveALDeadMarkers()
	if self.team then
		table.remove_value(self.team.units, self)
	end
	table.remove_value(g_Units, self)
	if self.session_id and g_Units[self.session_id] == self then
		g_Units[self.session_id] = nil
	end
	if self.unarmed_weapon then
		self.unarmed_weapon = nil
	end
	if self.bombard_weapon then
		DoneObject(self.bombard_weapon)
	end
	SelectionRemove(self)
	SetCombatActionState(self, nil)
	DeleteBadgesFromTarget(self)
	DeleteThread(self.pain_thread)
	DeleteThread(self.update_attached_weapons_thread)
	DeleteThread(self.setik_thread)
	if self:IsSyncObject() then
		Msg("UnitDespawned", self)
	end
	self:FreeVisitable()
	if self.perpetual_marker then
		self.perpetual_marker.perpetual_unit = false
	end
	self:SetTargetDummy(false)
	InvalidateUnitLOS(self)
	local idx = g_AIExecutionController and next(g_AIExecutionController.group_to_follow) and table.find(g_AIExecutionController.group_to_follow, "session_id", self.session_id)
	if idx then
		table.remove(g_AIExecutionController.group_to_follow, idx)
	end
end

function Unit:SetBehavior(behavior, params)
	self.behavior = behavior
	self.behavior_params = params
	
	if self.carry_flare and behavior and behavior ~= "Roam" and behavior ~= "RoamSingle" then
		self:RoamDropFlare()
	end
end

function Unit:SetCombatBehavior(behavior, params)
	self.combat_behavior = behavior
	self.combat_behavior_params = params
end

function CopyPropertiesShallow(to,source, properties, copy_values)
	assert(IsKindOf(to, "Modifiable") and IsKindOf(source, "Modifiable"))
	local mods = source.modifications or empty_table
	for i = 1, #properties do
		local prop = properties[i]
		if prop_eval(prop.dont_save, source, prop) then goto continue end
		
			local prop_id = prop.id
			if prop.modifiable then
				to:SetBase(prop_id, source["base_" .. prop_id])
			else
				local value = source:GetProperty(prop_id)
				local source_value_is_dest_default = value == nil or value == to:GetDefaultPropertyValue(prop_id, prop)
				local to_value = to:GetProperty(prop_id)
				local dest_value_is_default = to_value == nil or to_value == value
				local is_default = source_value_is_dest_default and dest_value_is_default
				if is_default then goto continue end
				
				if copy_values and type(to_value) == "table" then
					table.clear(to_value)
					local copy = table.copy(value)
					for key, val in pairs(copy) do
						if IsKindOf(val, "PropertyObject") then
							to_value[key] = val:Clone()
						else
							to_value[key] = val
						end
					end
				else
					to:SetProperty(prop_id, value)
				end
			end
		
		::continue::
	end
end

function Unit:InitMerc()
	g_UnarmedWeapon = g_UnarmedWeapon or PlaceInventoryItem("Unarmed")
	local unitData = gv_UnitData[self.session_id]
	
	if unitData.species ~= "Human" then
		self.stance = ""
	end
	self.fallback_body = unitData.gender or self.fallback_body

	self:SyncWithSession("session")

	self:InitMercWeaponsAndActions()
	self:OnGearChanged()

	ObjModified(self)
end

function Unit:InitMercWeaponsAndActions()
	self:ReloadAllEquipedWeapons()
	self:RecalcUIActions()
self:SetCommand("Idle")
end

function Unit:GetSide(reset_teams)
	local side = not reset_teams and self.team and self.team.side or false
	
	-- If the unit is not a part of any team, decide his team based on his campaign side.
	assert(self.session_id) -- all units should be represented in gv_UnitData
	local unit_data = self.session_id and gv_UnitData[self.session_id]

	if unit_data then 
		if unit_data.Squad and gv_Squads[unit_data.Squad] then
			side = side or gv_Squads[unit_data.Squad].Side
		elseif unit_data.CurrentSide ~= "" then 
			-- The unit could've changed sides
			side = side or unit_data.CurrentSide
		end
	end
		
	if not side and self.spawner then
		side = self.spawner.Side
	end

	-- Ephemeral units
	side = side or "neutral"
	
	return side
end

function Unit:FillMerc()
	local ud = gv_UnitData[self.session_id]
	if ud then ud:StatusEffectsCleanUp() end
	self:SyncWithSession("session")
	
	self:UpdateOutfit()
	self:OnGearChanged("isLoad")
	CombatPathReset(self)
	self:UpdateStatusEffectIndex()
	self:UpdateSignatureRecharges()
	
	if self.enter_map_wait_time then
		self.zone:InitUnit(self)
		self:SetCommand("EnterMap", self.zone, self.enter_map_pos, self.enter_map_wait_time)
	elseif self.behavior == "Hang" then
		self:SetCommand("Hang")
	elseif self.behavior == "Visit" then
		local marker = self.behavior_params[1] and self.behavior_params[1][1]
		if marker then
			local new_visitable = marker:GetVisitable()
			new_visitable.reserved = self.handle
			self.behavior_params[1] = new_visitable
			if marker.tool_attached then
				-- Tool is not a permanent object so it needs to be respawned
				if IsKindOf(marker, "AL_Carry") then
					self:SetState(marker.VisitIdle)
				end
				marker:SpawnTool(self)
			end
			if not (marker and marker:CanVisit(self, "for perpetual")) then
				self:ResetAmbientLife()
			elseif self.visit_reached then	-- walking to the marker can fail do to PF issues
				self:SetCommand("Visit", new_visitable, self.perpetual_marker)
			elseif IsKindOf(marker, "AL_Carry") then
				self:SetCommand("Visit", new_visitable, marker, "already in perpetual")
			end
		else
			-- persisted marker is deleted from the map
			self:SetBehavior()
			self:SetCommand("Idle")
		end
	else
		assert(self:IsValidPos())
		if self:IsValidPos() then
			self:SetCommand("Idle")
		end
	end
	ObjModified(self)
end

function Unit:SyncWithSession(source) -- sync map objects with session data
	if not self.session_id then -- early out for setpiece testing, done with Unit clones with no session_id
		return
	end
	local unit_data = self.session_id and gv_UnitData[self.session_id]
	if not unit_data then
		assert(false, string.format("All units should have corresponding unit data: session_id (%s), template name (%s)", self.session_id or "", self.unitdatadef_id or ""))
		return
	end
	
	local from, to
	if source == "map" then
		from = self
		to = unit_data
	elseif source == "session" then
		from = unit_data
		to = self
	end
	CopyPropertiesShallow(to, from, UnitProperties:GetProperties())
	CopyPropertiesShallow(to, from, UnitInventory:GetProperties())
	 -- StatusEffects table reference shouldn't be changed as it is observed by various UI at any given point.
	CopyPropertiesShallow(to, from, StatusEffectObject:GetProperties(), "copy_values")
	
	to:ApplyModifiersList(self.applied_modifiers)
	if source == "session" then
		to:OnSetActiveWeapon()
		to.AIKeywords = table.copy(to.AIKeywords)
	end	
	if (not g_Combat and self.behavior == "Dead") or (g_Combat and self.combat_behavior == "Dead") then
		self.HitPoints = 0
	end
	
	ObjModified(from)
	ObjModified(to)
	ObjModified(to.StatusEffects)
	ObjModified(from.StatusEffects)
end

function NetSyncEvents.SyncUnitProperties(source)
	SyncUnitProperties(source)
end

function SyncUnitProperties(source)
	if not GameState.entered_sector then return end
	
	for _, unit in ipairs(g_Units) do
		unit:SyncWithSession(source)
	end
	Msg("UnitPropertiesSynced")
end

function OnMsg.LoadSessionData()
	SyncUnitProperties("session")
	-- apply modifiers on load for units that are not on current map and have no g_Unit 
	--(syncwith session apply the modifiers for g_Units)
	for session_id, unit in pairs(gv_UnitData) do
		if not g_Units[session_id] then
			unit:ApplyModifiersList(unit.applied_modifiers)
		end	
	end	
end

function OnMsg.GatherSessionData()
	if not gv_SatelliteView then -- in satellite view units session data is updated
		SyncUnitProperties("map")
	end
end

local function restore_default_props(unit, data, properties)
	for id, prop in ipairs(properties) do
		local id = prop.id
		local editor = prop_eval(prop.editor, unit, prop)
		if editor and not prop_eval(prop.dont_save, unit, prop) then
			local value, default = unit:GetProperty(id), data:GetProperty(id)
			if value ~= default and (type(value) == "function" or type(value) == "table" and data:IsDefaultPropertyValue(id, prop, value)) then
				unit:SetProperty(id, default)
			end
		end
	end
end

-- On Lua reload, put the defaults from UnitData classes back into Unit instances
-- (important for function values, so they don't get saved)
function OnMsg.Autorun()
	for _, unit in ipairs(g_Units) do
		local unit_data = unit.session_id and gv_UnitData[unit.session_id]
		if unit_data then
			restore_default_props(unit, unit_data, UnitProperties:GetProperties())
		end
	end
end

function Unit:GetSatelliteSquad()
	local squad
	if self:IsDead() then
		squad = self.Squad
	else
		local unitData = gv_UnitData[self.session_id]
		squad = unitData and unitData.Squad
	end
	return gv_Squads and gv_Squads[squad] or false
end

function Unit:GameInit()
	local side = self.team and self.team.side	
	if CheatEnabled("GodMode", side) then
		self:GodMode("god_mode", true)
	end
	if CheatEnabled("InfiniteAP", side) then
		self:GodMode("infinite_ap", true)
	end
	if CheatEnabled("OneHpEnemies") and (side == "enemy1" or side == "enemy2") then
		self.HitPoints = 1
	end
	if self:HasStatusEffect("ManningEmplacement") then
		local handle = self:GetEffectValue("hmg_emplacement")
		local obj = HandleToObject[handle]
		if obj then
			self:EnterEmplacement(obj, true) -- instant take the right position
		end
	end
	self:UpdateBandageConsistency()
	
	self:SetContourOuterOccludeRecursive(true)
	self:UpdateGroundOrientParams()
	if not self:IsDead() then
		self:SetTargetDummyFromPos()
	end
end

function Unit:GetSyncedAnim()
	if self.synced_anim then
		return self.synced_anim, GameTime() - self.synced_anim_time
	end
	return self:GetStateText(), self:GetAnimPhase()
end

function Unit:GetStaticSpotPos(spot)
	local obj = self.target_dummy or self
	if type(spot) == "string" then
		local first, last = obj:GetSpotRange(obj:GetAnim(), spot)
		if first < 0 or last < 0 then
			return obj:GetRelativePoint(0, 0, guim)
		end
		spot = first
	end
	return obj:GetSpotLocPos(obj:GetAnim(), obj:GetAnimPhase(), spot)
end

function Unit:TriggerAction(cmd, ...)
	--[[if not g_Combat and cmd == "ChangeStance" then
		return self:InterruptCommand(cmd, ...)
	end--]]
	self:QueueCommand(cmd, ...)
end

function Unit:ReviveOnHealth(hp)
	self.HitPoints = hp or self.MaxHitPoints
	self:RemoveStatusEffect("Bleeding")
	self:NetUpdateHash("Revive", self.HitPoints)
	self:ClearHierarchyGameFlags(const.gofOnRoof)
	if self.behavior == "Dead" or self.behavior == "VillainDefeat" then
		self:SetBehavior()
		self:SetCombatBehavior()
	end
	InvalidateDiplomacy()
	self:FlushCombatCache()
	ObjModified(self)
end

function Unit:DropLoot(container)
	local is_npc = self:IsNPC()
	
	local debugText =  _InternalTranslate(self.Name) .. " dropping loot: (roll must be lower)"
	
	-- Locked items never drop.
	-- Go over the equipped items, drop them to "Inventory" based on their drop chance,
	-- Equipped items from Mercs always drop(except locked items). Otherwise check the drop chance.
	local droped_items = 0
	self:ForEachItem(function(item, slot_name)
		if slot_name == "InventoryDead" then return end
		self:RemoveItem(slot_name, item)	
		
		local dropped
		local roll = self:Random(100)
		local slot = container and "Inventory" or "InventoryDead"
		
		debugText = debugText .. "\n " ..  _InternalTranslate(item.DisplayName) .. ": roll " .. roll .. "/" .. item.drop_chance .. "% chance" 

		if not item.locked and (not is_npc or roll < item.drop_chance) then
			local addTo = container or self
			
			local pos, err = addTo:CanAddItem(slot, item)
			assert(pos, "Couldn't FIND pos in Inventory to place dropped item. Err: '" .. err .. "'")
			if pos then
				dropped, err = addTo:AddItem(slot, item, point_unpack(pos))
				assert(dropped, "Couldn't PLACE dropped item in Inventory. Err: '" .. err .. "'")
			end
		end
		
		if not dropped then
			DoneObject(item)
		elseif slot == "InventoryDead" then
			droped_items = droped_items + (item:IsLargeItem() and 2 or 1)
		end 
	end)
	if droped_items > 0 then
		self.max_dead_slot_tiles = droped_items
	end
	
	CombatLog("debug", debugText)
end

function OnMsg.UnitDiedOnSector(unit, sector_id)
	local sector = gv_Sectors[sector_id]
	sector.dead_units = sector.dead_units or {}
	table.insert(sector.dead_units, unit.session_id)  
end

function Unit:DropAllItemsInAContainer(fall_pos)
	if not self:GetItem() then return end
	local container = GetDropContainer(self,fall_pos)
	self:ForEachItem(function(item, slot)
		self:RemoveItem(slot, item)
		
		if not container:AddItem("Inventory", item) then
			-- Fallback for too many items
			container = PlaceObject("ItemDropContainer")
			local drop_pos = terrain.FindPassable(container, 0, const.SlabSizeX/2)
			container:SetPos(drop_pos or self:GetPos())
			container:SetAngle(container:Random(360*60))
			container:AddItem("Inventory", item)
		end
	end)
		
	return container
end

function Unit:ShouldGetDowned(hit_descr)
	if not self:IsMerc() or not self.team or not self.team.player_team or (hit_descr and hit_descr.was_downed) then 
		return false 
	end
	if self.team and self.team:IsDefeated() then
		return false
	end
	if IsGameRuleActive("LethalWeapons") then
		return false
	end
	if IsGameRuleActive("ForgivingMode") then
		return true
	end
	if hit_descr then
		local value = GameDifficulties[Game.game_difficulty]:ResolveValue("InstantDeathHp") or -50
		if hit_descr.prev_hit_points - hit_descr.raw_damage <= value then
			return false
		end
	end
	if g_Combat then
		return not self:IsDowned()
	end
	return hit_descr and hit_descr.prev_hit_points > 1
end

function Unit:OnDie(attacker, hit_descr)
	CombatActionInterruped(self)
	RemoveFloatingTextsFrom(self, "DamageFloatingText")
	self.on_die_attacker = IsKindOf(attacker, "Trap") and attacker.attacker or attacker
	self.on_die_hit_descr = table.copy(hit_descr)
	self.on_die_hit_descr.armor_decay = nil
	self.on_die_hit_descr.armor_pen = nil
	
	if self:ShouldGetDowned(hit_descr) then
		hit_descr.explosion_fly = nil -- never do this when downing
		self.HitPoints = 1 -- make sure the unit is not considered dead and evicted from the UI
		local value = GameDifficulties[Game.game_difficulty]:ResolveValue("DownedTempHp") or 30
		if g_Combat then self:ApplyTempHitPoints(value) end
		--count downed units for tacticalsituation vr
		if attacker and IsKindOf(attacker, "Unit") and attacker.team.side ~= self.team.side then
			self.team.tactical_situations_vr.downedUnits = self.team.tactical_situations_vr.downedUnits and self.team.tactical_situations_vr.downedUnits 
			attacker.team.tactical_situations_vr.downedUnitsByTeam = attacker.team.tactical_situations_vr.downedUnitsByTeam and attacker.team.tactical_situations_vr.downedUnitsByTeam + 1 or 1
			PlayVoiceResponseTacticalSituation(table.find(g_Teams, attacker.team), "now")
		end
		self:SetCommand("GetDowned")
	else
		--printf("%s dies", _InternalTranslate(self.Name or ""))
		self.on_die_hit_descr = self.on_die_hit_descr or {}
		 -- Roam is considered visiting but doesn't have a last_visit
		 if self:IsVisiting() and self.last_visit and self.visit_reached then
			self.on_die_hit_descr.die_pos = self.last_visit:GetPos()
		end
		if string.match(self.session_id, "ClonedFootballPartner") then
			self.SetCommand = Unit.SetCommand
			self.zone.player_killed = true
		end
		if IsKindOf(self.last_visit, "AL_Football") then
			self.last_visit.player_killed = true
		end
		self:SetCommand("Die")
	end
end

function Unit:SetTired(value)
	UnitProperties.SetTired(self, value)
	
	if value==3 then
		self:SetCommand("GetDowned", "tired")	
	end
end

function Unit:IsGettingDowned()
	return self.command == "GetDowned"
end

function Unit:IsDowned()
	return self.command == "Downed" or self.combat_behavior == "Downed"
end

function Unit:IsIncapacitated()
	return self:IsDead() or self:IsDowned() or self:IsGettingDowned() or self.command == "Die"
end

function Unit:CanContinueCombat()
	local isDead = self.command == "Die" or self:IsDead()
	local isDowned = self:IsDowned()
	local isTempUncontrollable = (self:HasStatusEffect("Unconscious") or self:HasStatusEffect("Stabilized")) and (not self:HasStatusEffect("Downed") or not self:HasStatusEffect("BleedingOut"))
	return not isDead and (not isDowned or isTempUncontrollable)
end

MapVar("g_NextUnitThread", false)
MapVar("g_LastUnitToShoot", false)

function Unit:GetDowned(tired, skip_anim)
	if not tired then
		self.HitPoints = 1 -- restore hp so Downed can be applied
		--printf("%s is downed", _InternalTranslate(self.Name or ""))
	end
	self.ActionPoints = 0
	self.stance = self:GetValidStance("Prone")
	self:InterruptPreparedAttack()
	self:RemovePreparedAttackVisuals()
	self:RemoveEnemyPindown()
	self:AlignOnDeath()
	self:RemoveStatusEffect("FreeMove")
	self:RemoveStatusEffect("Bleeding")
	self:RemoveStatusEffect("BandageInCombat")
	self:RemoveStatusEffect("StationedMachineGun")
	self:AddWounds(1)
	
	CombatActionInterruped(self)
	ObjModified(self)
	self:ClearPath()
	self:SetTargetDummyFromPos()
	if not tired then
		PlayVoiceResponse(self, "Downed")
	end
	SetCombatActionState(self, nil)

	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCommonUnitControl") and Selection and table.find(Selection, self) then
		dlg:NextUnit()
	end

	if IsMerc(self) then
		PlayFX("MercDowned", "start")
	end

	self.combat_behavior = "GetDowned"
	CheckGameOver()
	local base_idle = self:TryGetActionAnim("Idle", "Downed")
	if not (base_idle and IsAnimVariant(self:GetStateText(), base_idle)) then
		local pos = self:GetPos()
		if ShouldDoDestructionPass() then
			WaitMsg("DestructionPassDone", 1000) --wait for destro if slabs beneath us get destroyed, so we can get a falldown point
		end
		local dstPos = FindFallDownPos(pos) or pos
		if dstPos ~= pos then
			self:FallDown(dstPos)
			pos = self:GetPos()
		end
		local angle = self:GetOrientationAngle()
		self:SetPos(pos)
		if not skip_anim then
			local base_anim = self:GetActionBaseAnim("Downed", self.stance)
			local anim = self:GetStateText()
			if IsAnimVariant(anim, base_anim) then
				Sleep(self:TimeToAnimEnd())
			else
				anim = self:GetNearbyUniqueRandomAnim(base_anim)
				self:MovePlayAnim(anim, pos, pos, 0, nil, true, angle)
			end
		end
		if base_idle then
			if not IsAnimVariant(self:GetStateText(), base_idle) then
				local anim = self:GetNearbyUniqueRandomAnim(base_idle)
				self:SetState(anim)
			end
		else
			-- missing downed idle animation support
			local base_anim = self:GetActionBaseAnim("Downed", self.stance)
			local anim = self:GetStateText()
			if not IsAnimVariant(anim, base_anim) then
				anim = self:GetNearbyUniqueRandomAnim(base_anim)
			end
			local duration = GetAnimDuration(self:GetEntity(), anim)
			self:SetState(anim, 0, 0)
			self:SetAnimPhase(1, duration - 1)
		end
		self:SetGroundOrientation(angle, 0)
	end
	self.combat_behavior = false

	if not g_Combat and not self:IsDead() then
		Sleep(5000)
		self:SetCommand("DownedRally")
		return
	end
	if g_Combat and self == SelectedObj and not IsValidThread(g_NextUnitThread) then
		g_NextUnitThread = CreateMapRealTimeThread(function()
			-- Somebody could be panicking, during which units cannot be controlled.
			while g_AIExecutionController do
				WaitMsg("ExecutionControllerDeactivate", 50)
			end
			-- If the last unit is killed combat will be ended.
			if g_Combat then g_Combat:NextUnit(nil, "force") end
		end)
	end
	self.return_pos = nil

	if tired then
		self:AddStatusEffect("Unconscious")
	else
		MoraleModifierEvent("UnitDowned", self)
		self:AddStatusEffect("Downed")
	end
end

function Unit:Downed()
	Msg("UnitDowned", self)
	local base_idle = self:TryGetActionAnim("Idle", "Downed")
	if base_idle then
		if not IsAnimVariant(self:GetStateText(), base_idle) then
			local anim = self:GetNearbyUniqueRandomAnim(base_idle)
			self:SetState(anim)
		end
	else
		-- missing downed idle animation support
		local base_anim = self:GetActionBaseAnim("Downed", self.stance)
		local anim = self:GetStateText()
		if not IsAnimVariant(anim, base_anim) then
			anim = self:GetNearbyUniqueRandomAnim(base_anim)
		end
		local duration = GetAnimDuration(self:GetEntity(), anim)
		self:SetState(anim, 0, 0)
		self:SetAnimPhase(1, duration - 1)
	end
	self:SetFootPlant(true, 0)
	self:SetCombatBehavior("Downed")
	local target_dummy_phase = GetAnimDuration(self:GetEntity(), self:GetState())
	self:SetTargetDummy(nil, nil, nil, target_dummy_phase) -- current position, animation phase 0
	Halt()
end

local HeadshotHideParts = { "Head", "Hat", "Hat2", "Hair" }

function Unit:SetHeadshot(value)
	self.Headshot = value
	if not self.parts or self.species ~= "Human" then
		return
	end
	for i, name in ipairs(HeadshotHideParts) do
		local part = self.parts[name]
		if part then
			if value then
				part:ClearEnumFlags(const.efVisible)
			else
				part:SetEnumFlags(const.efVisible)
			end
		end
	end
	if value then
		local headshot_entity
		if self.gender == "Male" then
			headshot_entity = "FX_HeadMale_Headshot"
		elseif self.gender == "Female" then
			headshot_entity = "FX_HeadFemale_Headshot"
		end
		if headshot_entity then
			local part = PlaceObject("AppearanceObjectPart")
			if self:GetGameFlags(const.gofRealTimeAnim) ~= 0 then
				part:SetGameFlags(const.gofRealTimeAnim)
			end
			part:ChangeEntity(headshot_entity)
			self:Attach(part, self.parts.Head:GetAttachSpot())
			self.parts.Headshot = part
		end
	else
		DoneObject(self.parts.Headshot)
		self.parts.Headshot = nil
	end
end

function Unit:AlignOnDeath(dont_snap)
	local pos = self:GetVoxelSnapPos()
	if pos and self:GetDist(pos) > 0 and (not (self.on_die_hit_descr and self.on_die_hit_descr.die_pos)) then
		if not dont_snap then
			self:SetPos(pos)
		end
		-- make sure the unit dies on place in this case
		self.on_die_attacker = nil
		self.on_die_hit_descr = nil
	end
end

function Unit:Die(skip_anim)
	local attacker = self.on_die_attacker
	local hit_descr = self.on_die_hit_descr or {}
	local target_spot_group = hit_descr.spot_group
	local headshot = target_spot_group == "Head"
	local attack_action_id = attacker and CombatActions_LastStartedAction and CombatActions_LastStartedAction.unit == attacker and CombatActions_LastStartedAction.action_id
	local zoom_in = (self:IsLocalPlayerControlled() or headshot or attack_action_id == "KnifeThrow") and attacker and CurrentActionCamera and CurrentActionCamera[1] ~= self and CurrentActionCamera[2] == self and not self.villain
	local results = {}

	self:AlignOnDeath("don't snap in voxel")
	self:RoamDropFlare()

	if not skip_anim then
		if zoom_in then
			ZoomActionCamera()
		end

		-- Action camera should wait for this to be over before closing.
		if CurrentActionCamera then
			CurrentActionCamera.wait_signal = true
		end
	end
	
	if self.reincarnate then
		self:PlayDying()
		self:ReviveOnHealth()
		self:SetBehavior()
		self:SetCombatBehavior()
		self:SetCommand("Idle")
		return
	elseif self.immortal then
		self:ReviveOnHealth()
		self:AddStatusEffect("Unconscious")
		return
	end
	
	self.HitPoints = 0 -- needs to be before RemoveAllStatusEffects so that Wounded can detect the death and leave any blood stains on
	self:RemoveAllStatusEffects("death")
	if self.villain then
		local attackerMerc = attacker and IsMerc(attacker)
		
		if self.DefeatBehavior == "Defeated" then
			self:SetBehavior("VillainDefeat")
			self:SetCombatBehavior("VillainDefeat")
			self.villain_defeated = true
			self:SetCommand("VillainDefeat")
		elseif self.DefeatBehavior == "Dead" then
			if attackerMerc and SideIsEnemy(self.team.side, attacker.team.side) then
				PlayVoiceResponse(self, "DramaticDeath")
			end
			Msg("VillainDefeated", self, attacker)
			self.villain_defeated = true
		end
	end
	self.HitPoints = 0 -- in case statuses do some shenanigans I guess
	self.time_of_death = Game.CampaignTime
	self.throw_died_message = true
	self.pending_aware_state = nil
	self.killed_stance = self.stance

	Msg("UnitDieStart", self, attacker)
	Msg("UnitDiedOnSector", self, gv_CurrentSectorId)
	self:InterruptPreparedAttack()
	self:EndInterruptableMovement()
	CombatActionInterruped(self)
	for _, unit in ipairs(g_Units) do
		if unit:GetBandageTarget() == self then
			unit:SetCommand("EndCombatBandage")
		end
	end	
	local stealth_kill = hit_descr.stealth_kill
	if not attacker then
		CombatLog("debug", T{Untranslated("  <em><name></em> was <em>killed</em>"), name = self:GetLogName()})
	end

	results.glory_kill = not self.immortal and not hit_descr.grazing and self:Random(100) < const.Combat.GloryKillChance
	
	local death_explosion = hit_descr.death_explosion
	if self:GetItemInSlot("Inventory", "Valuables") or self:GetItemInSlot("Inventory", "QuestItem") then
		death_explosion = false
		hit_descr.death_explosion = false
	end

	if death_explosion then
		PlayFX("DeathExplosion", "start", self, target_spot_group)
	elseif results.glory_kill and IsKindOf(hit_descr.weapon, "Firearm") and not self.immortal and headshot and self.species == "Human" and self.parts.Head then
		self:SetHeadshot(true)
		PlayFX("Death", "start", self, "Headshot")
	else
		PlayFX("Death", "start", self, target_spot_group)
	end
	
	if IsMerc(self) then
		PlayFX("MercDeath", "start", self)
	end

	self:SetPos(self:GetVisualPos())
	self:SetHierarchyGameFlags(const.gofOnRoof) --hide with roofs and walls if too close to one
	self:ClearPath()
	self:ClearEnumFlags(const.efResting)
	self:SetTargetDummy(false)
	SetCombatActionState(self, nil)
	-- Remember the anim prefix when the unit died as it will drop its items
	self.die_anim_prefix = self:GetWeaponAnimPrefix()

	local container
	if not self.immortal then
		if death_explosion then
			container = GetDropContainer(self)
			container:SetVisible(false)
		end
		self:DropLoot(container)
		if container and not container:HasItem() then
			DoneObject(container)
			container = false
		end
	end
	self:SyncWithSession("map")

	if self.villain and self.DefeatBehavior == "Dead" then
		MoraleModifierEvent("LieutenantDefeated", self)
	else
		MoraleModifierEvent("UnitDied", self)
		if attacker and self.team.side ~= "neutral" and self.team.side ~= "player1" and self.team.side ~= "player2" and results.glory_kill then
			MoraleModifierEvent("SpectacularKill", attacker)
		end
	end

	-- alerts: noise (non-stealth only) and killed (always)
	local alerted, suspicious = PushUnitAlert("death", self)
	if not stealth_kill then
		local noise_alerted, noise_suspicious = PushUnitAlert("noise", self, const.Combat.DeathNoiseRange, Presets.NoiseTypes.Default.Pain.display_name)
		alerted, suspicious = alerted + noise_alerted, suspicious + noise_suspicious
	end
	if g_Combat and IsKindOf(attacker, "Unit") and not g_Combat:ShouldEndCombat() then
		if stealth_kill and alerted == 0 then
			PlayVoiceResponse(attacker, "OpponentKilledStealth")
		end
	end

	-- skip end combat check if the death made someone suspicious or alert
	-- note: a stealth kill attack wouldn't alert/raise suspicion in other units except through the "death" trigger
	local end_combat_check = g_Combat and suspicious + alerted == 0 and not g_AIExecutionController

	self:PushDestructor(function(self)
		self:RemovePreparedAttackVisuals()
		Msg("ActionCameraWaitSignalEnd")
		if container then
			container:SetVisible(true)
		end
	end)
	self:PushDestructor(function(self)
		assert(not self.command and not self:IsValid(), "Die command should not be interrupted (new command: " .. tostring(self.command) .. ").")
	end)
	-- wait a bit for possible destruction around or below the unit (bullets and explosions might destroy stuff after the unit)
	if not skip_anim then
		Sleep(100)
		self:StopPain()
	end
	self:PlayDying(skip_anim, end_combat_check)
	self:PopDestructor()
	self:PopAndCallDestructor()

	ObjModified(self)
	Msg("UnitDied", self, attacker, results)
	self.throw_died_message = false
	
	if IsValid(self) then
		self:BeginInterruptableMovement()
		self:SetCommand("Dead")
	end
end

local FX_Explosion_Variants = {
	"FX_Explosion_Human_01",
	"FX_Explosion_Human_02",
	"FX_Explosion_Human_03",
}

function Unit:PlaceDeathFXObject(quick_play, pos, angle)
	pos = pos or self:GetPos()
	pos = FindFallDownPos(pos) or pos
	angle = angle or self:GetOrientationAngle()
	self:SetOpacity(0)
	local o = self.death_fx_object
	if not IsValid(o) then
		if not FX_Explosion_Variants[self.death_explosion_played] then
			self.death_explosion_played = 1 + self:Random(#FX_Explosion_Variants)
		end
		o = PlaceObject(FX_Explosion_Variants[self.death_explosion_played])
		o:SetStateText("idle")
		self.death_fx_object = o
	end
	if quick_play then
		o:SetAnimPhase(1, GetAnimDuration(o:GetEntity(), o:GetAnim(1)) - 1)
	end
	local orient_time = quick_play and 0 or 500
	if not o:IsValidPos() then
		o:SetPos(pos)
	end
	o:SetPos(pos, orient_time) -- fall down when destruction
	o:SetGroundOrientation(angle, orient_time, const.SlabSizeX * 40 / 100) -- one tile inclination
end

function Unit:PlayDying(quick_play, end_combat_check, anim, pos, angle, break_obj)
	local in_dead_anim
	local hit_descr = self.on_die_hit_descr
	local death_explosion = hit_descr and hit_descr.death_explosion or self.species == "Hen"
	local falldown_callback = hit_descr and hit_descr.falldown_callback and _G[hit_descr.falldown_callback]
	if death_explosion or string.match(self:GetStateText(), "Death") then
		in_dead_anim = true
		anim = self:GetStateText()
	end
	if not in_dead_anim and ShouldDoDestructionPass() then
		WaitMsg("DestructionPassDone", 1000)
	end
	if not anim and not death_explosion then
		anim, pos, angle, break_obj = GetRandomDeathAnim(self, { attacker = self.on_die_attacker, hit_descr = hit_descr } )
	end
	pos = pos or self:GetPos()
	pos = FindFallDownPos(pos) or pos
	angle = angle or self:GetOrientationAngle()
	local orient_time = quick_play and 0 or 500
	self:DestroyAttaches("WeaponVisual")

	local behavior_params = { anim, angle }
	self:SetBehavior("Dead", behavior_params)
	self:SetCombatBehavior("Dead", behavior_params)

	if death_explosion then
		if self.death_explosion_played then
			quick_play = true
		end
		if not quick_play then
			Sleep(const.Combat.DeathExplosion_AnimationDelay)
		end
		self:SetBehavior("Despawn", behavior_params)
		self:SetCombatBehavior("Despawn", behavior_params)
		if self.species == "Hen" then
			local dlg = GetInGameInterfaceModeDlg()
			if IsKindOf(dlg, "IModeCombatAttackBase") and dlg:GetAttackTarget() == self then
				if g_Combat or g_StartingCombat then
					SetInGameInterfaceMode("IModeCombatMovement")
				else
					SetInGameInterfaceMode("IModeExploration")
				end
			end
			self:QueueCommand("Despawn")
			return
		end
		if IsValid(self.death_fx_object) then
			self:PlaceDeathFXObject(true, pos, angle)
			return
		end
		self:PlaceDeathFXObject(quick_play, pos, angle)
		if end_combat_check and g_Combat then
			g_Combat:EndCombatCheck()
		end
		if not quick_play and IsValid(self.death_fx_object) then
			Sleep(self.death_fx_object:TimeToAnimEnd())
		end
		return
	end

	if in_dead_anim then
		-- unconscious
		if end_combat_check and g_Combat then
			g_Combat:EndCombatCheck()
		end
		if quick_play then
			self:SetAnimPhase(1, GetAnimDuration(self:GetEntity(), anim) - 1)
		else
			Sleep(self:TimeToAnimEnd())
		end
		return
	end

	if quick_play then
		self:SetState(anim, 0, 0)
		local duration = GetAnimDuration(self:GetEntity(), anim)
		self:SetAnimPhase(1, duration - 1)
		self:SetPos(pos)
		self:SetFootPlant(true, 0)
		self:SetOrientationAngle(angle)
		if falldown_callback then
			falldown_callback(self.on_die_attacker, self, pos)
		end
		if IsValid(break_obj) and break_obj.pass_through_state == "intact" then
			break_obj:SetWindowState("broken")
		end
		if end_combat_check and g_Combat then
			g_Combat:EndCombatCheck()
		end
		return
	end
	local thread1, thread2
	self:PushDestructor(function(self)
		DeleteThread(thread1)
		DeleteThread(thread2)
		if IsValid(self) then
			self:PlayDying(true, false, anim, pos, angle, break_obj)
		end
	end)
	if falldown_callback then
		local delay = self:GetAnimMoment(anim, "hit") or self:GetAnimMoment(anim, "end") or self:GetAnimDuration(anim) - 1
		thread1 = CreateGameTimeThread(function(self, delay, pos, end_combat_check)
			Sleep(delay)
			local hit_descr = self.on_die_hit_descr
			local falldown_callback = hit_descr.falldown_callback and _G[hit_descr.falldown_callback]
			if falldown_callback then
				falldown_callback(self.on_die_attacker, self, pos)
			end
			if end_combat_check and g_Combat then
				g_Combat:EndCombatCheck()
			end
		end, self, delay, pos, end_combat_check)
	end
	if break_obj then
		local delay = self:GetAnimMoment(anim, "explosion") or 0
		thread2 = CreateGameTimeThread(function(delay, obj, end_combat_check)
			Sleep(delay)
			if IsValid(obj) and obj.pass_through_state == "intact" then
				obj:SetWindowState("broken")
			end
			if end_combat_check and g_Combat then
				g_Combat:EndCombatCheck()
			end
		end, delay, break_obj, end_combat_check)
	else
		if end_combat_check and g_Combat then
			g_Combat:EndCombatCheck()
		end
	end
	self:MovePlayAnim(anim, self:GetPos(), pos, 0, nil, true, angle)
	self:PopDestructor()
end

Unit.IsDead = UnitProperties.IsDead

function Unit:IsDefeatedVillain()
	return self.villain and self.villain_defeated
end

function Unit:RemoveEnemyPindown()
	if g_Combat then
		for attacker, descr in pairs(g_Pindown) do
			if descr.target == self then
				attacker:InterruptPreparedAttack()
			end
		end
	end
end

DefineClass.DecFXBlood_01 = {__parents = {"Object"}}

function Unit:PlaceBlood()
	if self:HasPassedTimeAfterDeath(const.Satellite.RemoveBloodAfter) then
		--do not place blood if const.Satellite.RemoveBloodAfter has passed
		return
	end
	local blood_pos = self:GetSpotVisualPos(self:GetSpotBeginIndex("Blood"))
	blood_pos = blood_pos:SetZ(self:GetVisualPos():z())
	local blood = PlaceObject("DecFXBlood_01")
	blood:SetGameFlags(const.gofDecalOpacityAlphaTest)
	blood:SetPos(blood_pos)
	blood:SetAngle(self:Random(360 * 60))
	blood:SetOpacity(0)
	blood:SetOpacity(95, 4000 + self:Random(2000))
end

function Unit:Dead(anim, angle)
	local behavior = g_Combat and self.combat_behavior or self.behavior
	if behavior == "Despawn" then
		return
	end
	
	-- This can happen when a save is made while the unit was running the "Die" command.
	-- Upon load the unit will be dead (go straight here) without having thrown the message,
	-- which could mean that the conflict isn't resolved.
	if self.throw_died_message then
		local killer = self.on_die_attacker
		Msg("UnitDied", self, killer, empty_table)
		self.throw_died_message = false
	end
	
	-- some Die command code is repeated here for the cases when the Die command was skipped (load a game)
	self:SetHierarchyGameFlags(const.gofOnRoof) --hide with roofs and walls if too close to one
	self:ClearPath()
	self:ClearEnumFlags(const.efResting)
	self:SetTargetDummy(false)
	SetCombatActionState(self, nil)
	self:RemoveEnemyPindown()
	if self.species == "Human" then
		self.stance = "Prone"
	end

	if not anim and self.behavior == "Dead" then
		anim, angle = table.unpack(self.behavior_params or empty_table)
	end
	self:PlayDying(true, false, anim, self:GetPos(), angle)
	self:PlaceALDeadMarkers()

	Halt()
end

function Unit:Hang()
	SetCombatActionState(self, nil)
	self:SetBehavior("Hang")
	self:SetCombatBehavior("Hang")
	
	local ropes = MapGet("map", "World_HangingRope") or empty_table
	if #ropes ~= 1 then
		StoreErrorSource(point30, "There should be one rope on the map.")
		return
	end
	local rope = ropes[1]
	local hanging_spot_idx = rope:GetSpotBeginIndex("Hanging")
	if hanging_spot_idx == -1 then
		StoreErrorSource(rope, "Rope missing Hanging spot")
		return
	end
	rope.SetAutoAttachMode = empty_func
	rope:Attach(self, hanging_spot_idx)
	self:SetState("nw_Hanging", 0, 0)
	self.HitPoints = 0
	self.immortal = false
	InvalidateDiplomacy()
	Msg("UnitDieStart", self)
	Halt()
end

function Unit:IsPersistentDead()
	return self.command == "Hang"
end

function Unit:VillainDefeat()
	if not self.villain or not self.villain_defeated then
		if self.behavior == "VillainDefeat" then
			self:SetBehavior()
		end
		if self.combat_behavior == "VillainDefeat" then
			self:SetCombatBehavior()
		end
		return
	end
	
	SetCombatActionState(self, nil)
	if SideIsEnemy(self.team.side, "player1") then
		PlayVoiceResponse(self, "VillainDefeated")
	end
	
	self:SetBehavior("VillainDefeat")
	self:SetCombatBehavior("VillainDefeat")
	
	self.invulnerable = true
	self.conflict_ignore = true -- prevent ambient life from messing around with this unit
	self.neutral_retaliate = false
	self.HitPoints = 1
	self:DoChangeStance("Crouch")
	self.ActionPoints = 0
	self.villain_defeated = true
	self:ClearPath()

	self:InterruptPreparedAttack()
	self:RemoveAllStatusEffects()
	
	local squad = gv_Squads[self.Squad]
	if squad then
		local newSquadId = SplitSquad(squad, {self.session_id})
		assert(self.Squad == newSquadId)
		SetSatelliteSquadSide(self.Squad, "neutral")
	end
	self:SetSide("neutral")
	
	MoraleModifierEvent("LieutenantDefeated", self)

	if g_Combat and not g_AIExecutionController then
		g_Combat:EndCombatCheck()
	end

	self:RemoveEnemyPindown()

	-- temporary anim
	self.command_specific_params = self.command_specific_params or {}
	self.command_specific_params.VillainDefeat = { weapon_anim_prefix = "civ_" }
	self:SetRandomAnim(self:GetIdleBaseAnim("Crouch"), const.eKeepComponentTargets, 0)
	self:SyncWithSession("map")
	Msg("VillainDefeated", self, self.on_die_attacker)
	Halt()
end

function Unit:Despawn()
	self:AutoRemoveCombatEffects()
	self:InterruptPreparedAttack()
	self:RemoveEnemyPindown()
	
	--remove crosshair on despawned unit
	local dlg = GetInGameInterfaceModeDlg()
	local crosshair = dlg and dlg.crosshair
	if crosshair and crosshair.context.target == self then
		dlg:RemoveCrosshair("Despawn")
		if g_Combat then
			if g_Combat:ShouldEndCombat() then
				g_Combat:EndCombatCheck(true)
			else
				SetInGameInterfaceMode("IModeCombatMovement")
			end
		else
			SetInGameInterfaceMode("IModeExploration", {suppress_camera_init = true})
		end
	end
	
	if not self:IsAmbientUnit() then self:SyncWithSession("map") end
	self.is_despawned = true
	--self:RemoveAllStatusEffects()
	if SelectedObj == self then
		SelectObj()
	end

	if self.Squad then
		local squad = gv_Squads[self.Squad]
		if squad and (squad.Side == "enemy1" or squad.Side == "enemy2") then
			RemoveUnitFromSquad(gv_UnitData[self.session_id])
		end
	elseif not IsMerc(self) and not self.PersistentSessionId then
		gv_UnitData[self.session_id] = nil
	end
	
	if g_Combat and  not self:IsLocalPlayerControlled() and CountAnyEnemies()==1 then
		g_Combat.retreat_enemies = true
	end
	DoneObject(self)
	
	if g_Combat and not g_AIExecutionController then
		g_Combat:EndCombatCheck("force")
	end
end

function Unit:CanActivatePerk(id)
	return HasPerk(self, id) and not self.perks_activated[id] and not self:IsDead()
end

function Unit:ActivatePerk(id)
	if self.perks_activated then
		self.perks_activated[id] = true
	end
end

function Unit:GetUIActionPoints()
	return self.ui_override_ap or Max(0, (self.ActionPoints or 0) - self.ui_reserved_ap - self.free_move_ap)
end

function Unit:GetUIAdjustedActionCost(ap, movement, use_free_move)
	local ap_scale = const.Scale.AP
	local ap_now = self:GetUIActionPoints() / ap_scale
	local free
	if movement then
		local unit_ap = self.ActionPoints
		if not use_free_move then
			unit_ap = Max(0, unit_ap - SelectedObj.free_move_ap)
		end
		local ap_after = Max(0, unit_ap - ap) / ap_scale
		if ap_after >= ap_now then
			ap = 0
			if use_free_move and ap <= self.free_move_ap then
				free = true
			end
		else
			ap = ap_now - ap_after
		end
	else
		ap = ap / const.Scale.AP
	end
	
	return ap, ap_now, free
end

function Unit:UIHasAP(ap, action_id, args)
	return self:HasAP((ap or 0) + self.ui_reserved_ap, action_id, args)
end

function Unit:HasAP(ap, action_id, args)
	if not g_Combat and not g_StartingCombat and not g_TestingSaveLoadSystem then
		return true
		--self.ActionPoints = self:GetMaxActionPoints()
	end
	local move_ap = 0
	local action = CombatActions[action_id]
	if action and action.UseFreeMove then
		if args and args.ap_cost_breakdown then
			move_ap = args.ap_cost_breakdown.move_cost or ap
		else
			move_ap = ap
		end
	else
		move_ap = args and args.goto_ap or 0
	end
	-- available ap for the action are the base AP + free move ap up to move_ap (when 0, that's the base AP only)
	local available = Max(0, (self.ActionPoints or 0) - self.free_move_ap) + Min(move_ap, self.free_move_ap)	
	return (available or 0) >= (ap or 0), (ap or 0) - (available or 0)
end

function Unit:GainAP(ap)
	if not g_Combat or (ap or 0) <= 0 then
		return
	end
	if g_Pindown[self] or (g_Overwatch[self] and not g_Overwatch[self].permanent) or self:IsDowned() then
		return
	end
	if self:HasStatusEffect("Panicked") or self:HasStatusEffect("Berserk") or self:HasStatusEffect("Protected") then
		return
	end
	if self:HasStatusEffect("SpentAP") and (self:GetEffectValue("spent_ap") or 0) >= self:GetMaxActionPoints() then
		return
	end

	self.ActionPoints = self.ActionPoints + ap
	CombatPathReset(self)
	Msg("UnitAPChanged", self)
	ObjModified(self)
end

function Unit:ConsumeAP(ap, action_id, args)
	ap = ap or 0
	if action_id and ap > 0 then
		local action = CombatActions[action_id]
		if action then
			self.performed_action_this_turn = true
			if action.ActionType ~= "Ranged Attack" and action.ActionType ~= "Melee Attack" then
				self:RemoveStatusEffect("Focused")
			end
			if action.ActionType == "Ranged Attack" or action.ActionType ==  "Melee Attack" then
				self:RemoveStatusEffect("Mobile")
				self:RemoveStatusEffect("FreeMove")
			end
		end
	end
	local move_ap = 0
	local action = CombatActions[action_id]
	if action and action.UseFreeMove then
		move_ap = ap
	else
		move_ap = args and args.goto_ap or 0
	end
	if move_ap > 0 then
		self.start_move_total_ap = self.ActionPoints
		self.start_move_cost_ap = move_ap
		self.start_move_free_ap = self.free_move_ap
	
		local reduce = Min(move_ap, self.free_move_ap)
		self.free_move_ap = self.free_move_ap - reduce
	end
	
	if not g_Combat or ap <= 0 or self.infinite_ap then
		return
	end
	self.ActionPoints = Max(0, self.ActionPoints - ap)
	Msg("UnitAPChanged", self, action_id, -ap)
	ObjModified(self)
end

function OnMsg.UnitAPChanged()
	if not GetDialog("PDADialogSatellite") then
		ObjModified("combat_bar")
	end
end

function OnMsg.CombatActionEnd(unit)
	unit.start_move_total_ap = nil
	unit.start_move_cost_ap = nil
	unit.start_move_free_ap = nil
end

function Unit:AddStatusEffect(effect, ...)
	NetUpdateHash("AddStatusEffect", self, effect)
	if self:IsDead() then return end
	if effect == "Bleeding" and self:IsDead() then
		return
	end
	if effect == "Tired" or effect == "Exhausted" and not g_Combat then
		PlayVoiceResponse(self, effect)
	end
	return StatusEffectObject.AddStatusEffect(self, effect, ...)
end

function Unit:RemoveStatusEffect(effect, ...)
	if self.StatusEffects[effect] then
		NetUpdateHash("RemoveStatusEffect", self, effect)
	end
	return StatusEffectObject.RemoveStatusEffect(self, effect, ...)
end

function NetEvents.UnitAddPerk(session_id, perk_id)
	local unit = g_Units[session_id]
	if unit then
		unit:AddStatusEffect(perk_id)
	end
	local unit = gv_UnitData[session_id]
	if unit then
		unit:AddStatusEffect(perk_id)
	end
end

function Unit:TakeDamage(dmg, attacker, hit_descr, ...)
	if g_Combat then
		g_Combat:OnUnitDamaged(self, attacker)
	end

	-- lose Hidden and alert units around visually and vocally (unless killed from stealth)
	self:RemoveStatusEffect("Hidden")
	if not hit_descr.stealth_kill and not hit_descr.melee_attack and not hit_descr.setpiece then
		TriggerUnitAlert("noise", self, const.Combat.PainNoiseRangeStealthKill, Presets.NoiseTypes.Default.Gunshot.display_name, attacker)
	end
	
	if IsKindOf(attacker, "Unit") then
		self.hit_this_turn = self.hit_this_turn or {}
		table.insert(self.hit_this_turn, attacker)
	end

	if self:IsInvulnerable() and not hit_descr.setpiece then
		CreateFloatingText(self:GetVisualPos(), T(759740141426, "Invulnerable"))
		CombatLog("debug", T{Untranslated("<name> has ignored <num> damage (invulnerable)"), name = self:GetLogName(), num = dmg})
		return
	end

	return CombatObject.TakeDamage(self, dmg, attacker, hit_descr, ...)
end

function Unit:TakeDirectDamage(dmg, floating, log_type, log_msg, attacker, hit_descr)
	hit_descr = hit_descr or {}
	-- ignore damage from the same action that downed us
	if self:IsDowned() and self.downing_action_start_time == CombatActions_LastStartedAction.start_time then
		return
	end

	local data = { dmg = dmg, hit_descr = hit_descr }
	Msg("PreUnitDamaged", attacker, self, data)
	dmg = data.dmg
	if dmg <= 0 then return end
	
	local hp = self.HitPoints
	local tempHp = self.TempHitPoints
	hit_descr.was_downed = self:IsDowned()
	CombatObject.TakeDirectDamage(self, dmg, floating, log_type, log_msg, attacker, hit_descr)
	self.last_turn_damaged = true

	if not self:IsDead() then
		local healthDamageTaken = self.HitPoints < hp or (dmg > 0 and (self.invulnerable or CheatEnabled("WeakDamage")))
		local gritDamageTaken = self.TempHitPoints < tempHp or (dmg > 0 and (self.invulnerable or CheatEnabled("WeakDamage")))
		if healthDamageTaken then
			MoraleModifierEvent("UnitDamaged", self, hp - self.HitPoints)
			if not (hit_descr and hit_descr.grazing) then
				self:AccumulateDamageTaken(hp - self.HitPoints)
			end
		end
		if healthDamageTaken or gritDamageTaken or hit_descr.setpiece then
			if not hit_descr.grazing then
				self:Pain(hit_descr, attacker)
			end
			self:RemoveStatusEffect("Hidden")
		end
	end

	if hit_descr and hit_descr.explosion_fly and not self:IsMerc() then
		if not self:IsDead() then
			self:Interrupt()
		end
		self:InterruptCommand("ExplosionFly", hp)
	end

	ObjModified(self)
end

function Unit:OnHPLoss(hp, attacker)
	if g_Combat and g_Combat.hp_loss then
		g_Combat.hp_loss[self.session_id] = (g_Combat.hp_loss[self.session_id] or 0) + hp
	end
end

function Unit:StopPain()
	if self.pain_thread then
		self:ClearAnim(const.AnimChannel_Pain)
		DeleteThread(self.pain_thread)
		self.pain_thread = false
	end
end

function Unit:WaitPain()
	while IsValidThread(self.pain_thread) do
		WaitMsg(self.pain_thread, 1000)
	end
end

function Unit:PlayPainAnim(alert_units)
	self:SetPos(self:GetVisualPos())
	self:SetAngle(self:GetVisualAngle())
	local anim = self:GetRandomAnim("pain")
	self:SetState(anim)
	repeat until not WaitWakeup(self:TimeToAnimEnd())
	self:SetState(self:GetIdleBaseAnim())
	if alert_units then
		AlertPendingUnits()
	end
end

local function GetPainAnim(unit, prefix, stance, variant)
	local anim = string.format("%s_%s_Pain%s", prefix, stance, variant == 1 and "" or variant)
	if IsValidAnim(unit, anim) then
		return anim
	end
	if variant > 1 then
		anim = string.format("%s_%s_Pain", prefix, stance)
		if IsValidAnim(unit, anim) then
			return anim
		end
	end
end

function Unit:Pain(hit_descr, attacker)
	local setpiece = hit_descr and hit_descr.setpiece
	local alert_units = not setpiece
	if alert_units then
		TriggerUnitAlert("noise", self, const.Combat.PainNoiseRange, Presets.NoiseTypes.Default.Pain.display_name, attacker) -- dead units do not play pain
	end

	if self.species ~= "Human" then
		DeleteThread(self.pain_thread)
		if self.interrupted then
			self.pain_thread = CreateGameTimeThread(function(self, alert_units)
				self:PlayPainAnim(alert_units)
				self.pain_thread = false
				Msg(CurrentThread())
			end, self, alert_units)
		elseif self:IsInterruptable() and CurrentThread() ~= self.command_thread then
			self:SetCommand("PlayPainAnim", alert_units)
		elseif alert_units then
			AlertPendingUnits()
		end
		return
	end

	local anim
	if self:HasAnimMask("PainMask") then   --"UpperBodyMask"
		local prefix = string.match(self:GetStateText(), "^(%a+)_%a+_.*") 
		if not prefix and setpiece then
			prefix = string.match(self:GetWeaponAnimPrefix(), "^(%a+)_")
		end
		local target_spot_group = hit_descr and hit_descr.spot_group
		local variant = target_spot_group == "Head" and 3 or 1 + self:Random(2)
		local stance = self.infected and "Standing" or self.stance
		anim = GetPainAnim(self, prefix, stance, variant)
		if not anim and prefix == "arg" then
			anim = GetPainAnim(self, "ar", stance, variant)
		end
		if not anim and prefix == "inf" then
			anim = GetPainAnim(self, "nw", stance, variant)
		end
	end
	if not (anim and IsValidAnim(self, anim)) then
		if alert_units then
			AlertPendingUnits()
		end
		return
	end

	local channel = const.AnimChannel_Pain
	local pain_anim_weight = hit_descr and hit_descr.grazing and const.PainAnimGrazingWeight or const.PainAnimWeight
	self:SetAnimMask(channel, "PainMask") --"UpperBodyMask"
	self:SetAnim(channel, anim, 0, -1, 1000, 0)
	self:SetAnimWeight(channel, pain_anim_weight, const.PainAnimWeightMoment, PainEasing)
	self:SetAnimBlendComponents(channel, false, true, false)
	DeleteThread(self.pain_thread)
	self.pain_thread = CreateGameTimeThread(function(self, anim, alert_units)
		Sleep(const.PainAnimWeightMoment)
		local channel = const.AnimChannel_Pain
		repeat
			local t = self:TimeToAnimEnd(channel)
			self:SetAnimWeight(channel, 0, t, 1, PainEasing)
		until not WaitWakeup(t)
		self:ClearAnim(channel)
		self.pain_thread = false
		if alert_units then
			AlertPendingUnits()
		end
		Msg(CurrentThread())
	end, self, anim, alert_units)
end

function Unit:KnockDown()
	if self.species ~= "Human" or self:IsDead() then
		return
	end
	local base_anim = self:GetActionBaseAnim("Downed", self.stance)
	local anim = self:GetStateText()
	if not IsAnimVariant(anim, base_anim) then
		anim = self:GetNearbyUniqueRandomAnim(base_anim)
	end
	--self:PushDestructor(function(self)
		self.return_pos = nil
		self:InterruptPreparedAttack() -- force interrupt when the unit gets knocked down
		if self:GetStateText() ~= anim then
			local pos = FindFallDownPos(self) or self:GetPos()
			local angle = self:GetOrientationAngle()
			self:SetOrientationAngle(angle, 300)
			self:MovePlayAnim(anim, pos, pos, 0, nil, true, angle)
		end
		local variation_suffix = string.match(anim, "(%d+)$") -- there are no variations for now
		local idle_anim = self:TryGetActionAnim("Idle", "Downed", variation_suffix)
		if idle_anim then
			self:SetState(idle_anim, 0, 0)
		end
		self.stance = self:GetValidStance("Prone")
		self:SetFootPlant(true)
		self:SetTargetDummy(nil, nil, nil, 0) -- current position, animation phase 0
		--self:DoChangeStance("Prone")
		self:RemoveStatusEffect("KnockDown")
		self:RemoveStatusEffect("Protected") -- lose cover
	--end)
	--self:PopAndCallDestructor()
	if self:HasStatusEffect("Unconscious") then
		self:SetCommand("Downed")
	end
end

function Unit:Dodge()
	self:SetFootPlant(true)
	local anim = self:GetActionRandomAnim("Dodge", self.stance)
	self:SetState(anim, const.eKeepComponentTargets)
	Sleep(self:TimeToAnimEnd())
end

function Unit:BeginTurn(new_turn)
	NetUpdateHash("BeginTurn_Start")
	self:SetAttackReason()
	local should_interrupt = true
	local pindown = g_Pindown[self]
	local overwatch = g_Overwatch[self]
	if pindown and IsValidTarget(pindown.target) and self:HasPindownLine(pindown.target, pindown.target_spot_group) then
		-- pindown will be handled differently when the attack is executed
		should_interrupt = false
	elseif overwatch and (overwatch.permanent or not g_Combat or overwatch.expiration_turn > g_Combat.current_turn) then
		should_interrupt = false
	elseif self.prepared_bombard_zone then
		should_interrupt = false
	end	
	if new_turn and should_interrupt then 
		self:InterruptPreparedAttack("begin turn")
		pindown = false
	end
	self:UpdateMeleeTrainingVisual()
	self:IsThreatened() -- update the is_melee_aim_last_turn flag for the vr
	
	if self.is_melee_aim_last_turn and IsMerc(self) then		
		PlayVoiceResponse(self, "MeleeEnemiesClosing")
		self.is_melee_aim_last_turn = false
	end

	self.perks_activated = {}
	NetUpdateHash("BeginTurn_Progress")
	if new_turn then
		self:RemoveStatusEffect("FreeMove")
		if g_Overwatch[self] and not g_Overwatch[self].permanent then
			self.ActionPoints = 0 -- special-case for carrying an overwatch from exploration mode
		else
			self.ActionPoints = self:GetMaxActionPoints()
--			if g_Combat.current_turn == 1 and self:IsMerc() then --use this to test lower AP during the first turn
--				self.ActionPoints = MulDivRound(self.ActionPoints, 75, 100)
--			end
		end
		if g_Overwatch[self] then
			table.clear(g_Overwatch[self].triggered_by) -- reset triggers in case somebody already triggered in our turn
			if self:HasStatusEffect("ManningEmplacement") or self:HasStatusEffect("StationedMachineGun") then
				g_Overwatch[self].num_attacks = self:GetNumMGInterruptAttacks()
				self:UpdateOverwatchVisual()
			end
		end
		g_Pindown[self] = nil -- clear from the global table to stop the prepared attack blocking any AP gains
		self.ui_reserved_ap = 0
		
		if self:GetEffectValue("missed_by_kill_shot") and not self:IsDead() and not self:IsDowned() then
			PlayVoiceResponse(self, "MissedByKillShot")
			self:SetEffectValue("missed_by_kill_shot", nil)
		end
		self:SetEffectValue("HaveABlast", nil)
		
		local protected = self:GetStatusEffect("Protected") -- handle this separately before the others to unblock AP gain
		if protected and g_Combat and (g_Combat.current_turn > 1 or not self:IsMerc()) then
			local ap = self:GetEffectValue("protected_ap_carry") or 0
			self:RemoveStatusEffect("Protected")
			self:GainAP(ap)
		end
		
		self:UpdateHidden()
		
		local voxels = self:GetVisualVoxels()
		local fire, dist = AreVoxelsInFireRange(voxels)
		if fire then
			local min, max = const.BurnDamageMin, const.BurnDamageMax
			local damage = self:RandRange(min, max)
			self:TakeDirectDamage(damage)
			if not self:IsIncapacitated() and not self:HasStatusEffect("Unconscious") and not RollSkillCheck(self, "Health") then
				self:ChangeTired(1)
			end
			if dist < const.SlabSizeX then
				self:AddStatusEffect("Burning")
			end
		end
		
		self.attacked_this_turn = false
		self.hit_this_turn = false
		self.wounded_this_turn = false
		NetUpdateHash("BeginTurn", self, self.using_cumbersome, HasPerk(self, "KillingWind"),
								HasPerk(self, "Ironclad"))
		if not self.using_cumbersome or HasPerk(self, "KillingWind") then
			self:AddStatusEffect("FreeMove")
		elseif self:CanUseIroncladPerk() then
			self:AddStatusEffect("FreeMove")
			self:ConsumeAP(DivRound(self.free_move_ap, 2), "Move")
		end
		
		Msg("UnitBeginTurn", self)
		
		local morale = self:GetPersonalMorale()
		if morale > 0 then
			self:GainAP(morale * const.Scale.AP)
		elseif morale < 0 then
			self:ConsumeAP(Min(self.ActionPoints, -morale * const.Scale.AP))
		end
		
		if self:GetItemInSlot("Head", "GasMask") then
			self:ConsumeAP(const.Scale.AP)
		end
		
		-- needs to be after all potential start-of-turn AP losses
		self.performed_action_this_turn = false
		
		-- special-case: if the unit dies as a result of a status effect, show them and wait the command to end
		-- doing this here makes sure the camera will not immediately jump to another unit (dying or selected)
		-- similarly, executing the pindown attack has to be waited until it finishes
		if self.command == "Die" then
			SnapCameraToObj(self)
			while self.command == "Die" do
				WaitMsg("UnitDied", 20) -- can also go in VillainDefeat instead, so wait with timeout
			end
		elseif pindown then
			pindown.target:ProvokeOpportunityAttack_Pindown(self, pindown)
		elseif self.prepared_bombard_zone then
			self:StartBombard()
		end
	end
	
	if self.dummy or self:IsDowned() then
		self.ActionPoints = 0
	end

	self.start_turn_pos = self:GetVisualPos()
		
	NetUpdateHash("BeginTurn", self, self:GetPos())
	
	Msg("UnitAPChanged", self)
end

function AdjustWoundsToHP(obj,stacks)
	local effect = obj:GetStatusEffect("Wounded")
	local maxhp = obj:GetInitialMaxHitPoints()
	local value = Wounded:ResolveValue("MaxHpReductionPerStack")
	local maxreduce = Wounded:ResolveValue("MinMaxHp")
	local min = MulDivRound(maxhp, maxreduce, 100)
	local cur_stacks = effect and effect.stacks or 0
	local count = stacks and (cur_stacks + stacks) or cur_stacks
	while count>=0 do
		if maxhp - count * value >= min then
			if stacks then
				return count - cur_stacks
			end
			return count
		end
		count = count - 1
	end
	if stacks then
		return count - cur_stacks
	end
	return count
end

function RecalcMaxHitPoints(unit) -- unit can be Unit or UnitData
	local count = AdjustWoundsToHP(unit)
	if count and count>0 then
		local effect = unit:GetStatusEffect("Wounded")
		local to_remove = effect.stacks - count
		if to_remove>0 then
			unit:RemoveStatusEffect("Wounded", to_remove)
		end
	end
	local maxhp = unit:GetModifiedMaxHitPoints()
	local prev_maxhp = unit.MaxHitPoints
	unit.MaxHitPoints = maxhp
	if maxhp > prev_maxhp then
		unit.HitPoints = unit.HitPoints + maxhp - prev_maxhp
	end
	unit.HitPoints = Min(unit.HitPoints, unit.MaxHitPoints)
	ObjModified(unit)
end

function GetMedsAndOwners(units, healer, healed)
	local total_amount = 0
	local list, meds_list = {}, {}

	local function add_meds(unit, list)
		local meds = unit:GetItem("Meds")
		if meds then
			total_amount = total_amount + meds.Amount
			list[#list + 1] = meds
			list[#list + 1] = unit
			meds_list[unit.session_id] = (meds_list[unit.session_id] or 0) + meds.Amount
		end
	end

	if healer then
		add_meds(healer, list)
	end
	if healed and healed ~= healer then
		add_meds(healed, list)
	end

	for _, unit in ipairs(units) do
		if unit ~= healer and unit ~= healed then
			add_meds(unit, list)
		end
	end
	local squad_id = units and units[1] and units[1].Squad
	if squad_id then
		for _, meds in ipairs(GetSquadBag(squad_id)) do
			if meds.class == "Meds" then
				total_amount = total_amount + meds.Amount
				list[#list + 1] = meds
				list[#list + 1] = squad_id
				meds_list[squad_id] = (meds_list[squad_id] or 0) + meds.Amount
			end
		end
	end
	
	return total_amount, list, meds_list
end

function Unit:CalcHealAmount(medkit, target)
	if not medkit then return 0 end
	local base_heal = CombatActions.Bandage:ResolveValue("base_heal")
	local medical_heal = CombatActions.Bandage:ResolveValue("medical_max_heal")
	local selfheal = CombatActions.Bandage:ResolveValue("selfheal")

	local heal_percent = base_heal + MulDivRound(self.Medical, medical_heal, 100)
		
	if HasPerk(self, "Savior") then
		heal_percent = heal_percent + CharacterEffectDefs.Savior:ResolveValue("bandageBonus")
	end	
	
	if target == self then
		heal_percent = MulDivRound(heal_percent, selfheal, 100)
	end	
	
	local heal_mod = heal_percent
	if IsKindOf(medkit, "Medkit") then
		heal_mod = heal_mod + 25
	end
	
	-- convert to raw hp
	local max = IsValid(target) and target.MaxHitPoints or self.MaxHitPoints
	return MulDivRound(max, heal_mod, 100), MulDivRound(heal_percent, 100, heal_mod)
end

function Unit:OnEndTurn()
	self:RemoveStatusEffect("FreeMove") -- cleanup unused free move ap
	if self.start_turn_pos then -- Units hired during this turn don't have start_turn_pos
		self.last_turn_movement = self:GetVisualPos() - self.start_turn_pos
	else
		self.last_turn_movement = nil
	end
	self.last_turn_damaged = nil -- reset here, we're tracking damage done between the end of our turn and the start of our next one
	SetCombatActionState(self, false)
	
	-- add attacks from remaining AP to permanent overwatch
	self:UpdateNumOverwatchAttacks()
	
	Msg("UnitEndTurn", self)
	for i = #self.StatusEffects, 1, -1 do
		local effect = self.StatusEffects[i]
		if effect.lifetime ~= "Indefinite" then
			local expiration = self:GetEffectExpirationTurn(effect.class, "expiration")
			if g_Combat and g_Combat.current_turn >= expiration then
				self:RemoveStatusEffect(effect.class, "all")
			end
		end
	end
		
	-- special-case: if the unit dies as a result of a status effect, show them and wait the command to end
	-- doing this here makes sure the camera will not immediately jump to another unit (dying or selected)
	if self.command == "Die" then
		SnapCameraToObj(self)
		while self.command == "Die" do
			WaitMsg("UnitDied", 20) -- can also go in VillainDefeat instead, so wait with timeout
		end
	end
end

function Unit:OnCommandStart()
	if self.interrupted then
		self:InterruptEnd()
	end
	self.cur_idle_style = false
	self.cur_move_style = false
	self.goto_target = false
	self.goto_stance = false
	self.goto_hide = false
	self.visibility_override = false
	self.passed_interrupts = nil
	self:TunnelsUnblock()
	self.action_visual_weapon = false
	if IsValid(self) then
		self:SetGravity(0)
		self:StopMoving()
		self.interrupted = false
		if not self:IsDead() and not IsActivePaused() then
			self:ClearPath()
			if self.traverse_tunnel then
				local tpos = self.traverse_tunnel:GetExit()
				if tpos then
					local pos = GetPassSlab(tpos) or FindPassable(tpos, 0, -1, -1, const.pfmVoxelAligned) or tpos
					self:SetPos(pos)
				end
			end
		end
		if not KeepAimIKCommands[self.command] then
			self:SetWeaponLightFx(false)
			self:SetIK("AimIK", false)
		end
		self:SetIK("LookAtIK", false)
		if not self.interruptable and self.command then
			self:BeginInterruptableMovement()
		end
		self:SetFootPlant(true)
	end
	self.traverse_tunnel = false
	self:SetAimFX(false, self.command and "delayed")
	if self.action_command then
		SetCombatActionState(self, self.command == self.action_command and "start" or nil)
	end
end

function Unit:SetActionCommand(command, ...)
	-- the interface should clear the visualisations
	DbgClearVectors()
	DbgClearTexts()

	if IsActivePaused() then
		if CombatActions_RunningState[self] then
			SetCombatActionState(self)
		else
			self:SetQueuedAction()
		end
	end

	self.action_command = command
	SetCombatActionState(self, "wait")

	self:InterruptCommand(command, ...)
end

function Unit:IsLocalPlayerControlled(player_control_mask)
	return IsControlledByLocalPlayer(self.team and self.team.side, player_control_mask or self.ControlledBy)
end

function Unit:IsLocalPlayerTeam()
	if not netInGame then
		return self:IsLocalPlayerControlled()
	else
		local squad = self.team
		if not squad then return true end
		return squad.side == NetPlayerSide(netUniqueId)
	end
end

function Unit:IsControlledBy(mask)
	return self.ControlledBy & mask ~= 0
end

function Unit:IsDisabled()
	--the unit is in an uncontrollable state
	return self:IsIncapacitated() or self:HasStatusEffect("Panicked") or self:HasStatusEffect("Berserk")
end

function Unit:CanBeControlled(player_control_mask)
	if not IsValid(self) then return false end
	if GetDialog("ConversationDialog") then return false end

	--disabled units cannot be controlled
	if self:IsIncapacitated() then return false end
	--is it an AI team?
	if not self.team or self.team.control ~= "UI" then return false end
	
	--can it be controlled by the local player network wise?
	if not self:IsLocalPlayerControlled(player_control_mask) then return false end
	
	-- Don't do further checks in deployment mode.
	if gv_DeploymentStarted then return true end
	
	if g_AIExecutionController or g_UnitAwarenessPending == "alert" then -- AI units taking actions
		return false
	end

	if g_Combat then
		if g_Combat.camera_use or not g_Combat.combat_started then -- combat is currently doing shenanigans with camera
			return false
		end
		-- Not current team in combat
		if not g_Combat:HasTeamTurnStarted(self.team) then
			return false
		end
		if g_Combat:IsLocalPlayerEndTurn() then
			return false, "not_local_turn"
		end
	end

	return true
end

function Unit:TunnelBlock(tunnel_entrance, tunnel_exit)
	for i, o in ipairs(self.tunnel_blockers) do
		if o.tunnel_end_point == tunnel_exit and tunnel_entrance:Equal(o:GetPosXYZ()) then
			return
		end
	end
	local o = PlaceObject("TunnelBlocker")
	o.owner = self
	o.tunnel_end_point = tunnel_exit
	pf.SetCollisionRadius(o, self:GetCollisionRadius())
	o:SetPos(tunnel_entrance)
	if not self.tunnel_blockers then
		self.tunnel_blockers = {}
	end
	table.insert(self.tunnel_blockers, o)
	if not (g_Combat and self:IsAware()) then
		MapForEach(tunnel_exit, 0, "Unit", function(o)
			if o:GetEnumFlags(const.efResting) == 0 or o:IsDead() then
				return
			end
			if o.command == "Idle" then
				o:SetCommand("GotoSlab", tunnel_exit)
			end
		end)
	end
end

function Unit:TunnelUnblock(tunnel_entrance, tunnel_exit)
	for i, o in ipairs(self.tunnel_blockers) do
		if o.tunnel_end_point == tunnel_exit and tunnel_entrance:Equal(o:GetPosXYZ()) then
			table.remove(self.tunnel_blockers, i)
			DoneObject(o)
			break
		end
	end
end

function Unit:TunnelsUnblock()
	local list = self.tunnel_blockers
	if not list or #list == 0 then
		return
	end
	for i, o in ipairs(list) do
		DoneObject(o)
	end
	table.iclear(list)
end

local function CheckInterruptCombatGotoPos(x, y, z, unit, ignore_pos)
	if not CanOccupy(unit, x, y, z) then
		return false
	end
	if ignore_pos and ignore_pos:Equal(x, y, z) then
		return false
	end
	local cost = unit.combat_path_obj:GetAP(point_pack(x, y, z))
	if not cost or cost >= (unit.combat_path_obj:GetAP(unit.combat_path[1]) or 0) then
		return false
	end
	return true
end

function Unit:GetInterruptCombatPath()
	local path = self.combat_path
	if not path or #path == 0 then
		return
	end
	local idx = #path
	local cur_pos
	if self.traverse_tunnel then
		cur_pos = point(point_unpack(path[idx]))
		idx = idx - 1
	else
		cur_pos = self:GetVisualPos()
		if not self:IsValidZ() then
			cur_pos = cur_pos:SetInvalidZ()
		end
	end
	for i = idx, 1, -1 do
		local x, y, z = point_unpack(path[i])
		local next_pos = point(x, y, z)
		local back_pos
		if i == idx and not self.traverse_tunnel then
			local pass_pos = GetPassSlab(self)
			if pass_pos and pass_pos ~= cur_pos then
				local a1 = CalcOrientation(cur_pos, next_pos)
				local a2 = CalcOrientation(cur_pos, pass_pos)
				if abs(AngleDiff(a1, a2)) > 90 * 60 then
					back_pos = pass_pos
				end
			end
		end
		local interrupt_pos
		if cur_pos ~= next_pos and not pf.GetTunnel(cur_pos, next_pos) then
			interrupt_pos = RasterizeSegmentPassSlabs(cur_pos, next_pos, CheckInterruptCombatGotoPos, self, back_pos)
		elseif SnapToVoxel(next_pos) == next_pos and CheckInterruptCombatGotoPos(x, y, z, self, back_pos) then
			interrupt_pos = next_pos
		end
		if interrupt_pos then
			if i == 1 and interrupt_pos == next_pos then
				return
			end
			local new_path = { point_pack(interrupt_pos) }
			for j = i + 1, #path do
				table.insert(new_path, path[j])
			end
			return new_path
		end
		cur_pos = next_pos
	end
end

function Unit:CombatGotoInterrupt(new_pos, restore_ap_only)
	if not self.combat_path or not self.combat_path_obj or self:IsDead() then
		return
	end
	local prev_pos = self.combat_path[1]
	local prev_cost = self.combat_path_obj:GetAP(prev_pos) or 0

	local interrupt_path
	if new_pos then
		if IsPoint(new_pos) then
			new_pos = point_pack(new_pos)
		end
		interrupt_path = { new_pos }
	else
		interrupt_path = self:GetInterruptCombatPath()
		if not interrupt_path then
			return
		end
		new_pos = interrupt_path[1]
	end
	local new_cost = self.combat_path_obj:GetAP(new_pos) or 0
	self.combat_path_obj = false
	self.combat_path = false
	if new_cost < prev_cost then
		self:GainAP(prev_cost - new_cost)
		if self.start_move_free_ap > 0 then
			-- restore ap -> free move ap
			local start_ui_ap = self.start_move_total_ap - self.start_move_free_ap
			self.free_move_ap = Max(0, self.ActionPoints - start_ui_ap)
			ObjModified(self)
		end
	end
	if restore_ap_only then
		return
	end
	SetCombatActionState(self, false)
	RunCombatAction("Move", self, new_cost, { goto_pos = point(point_unpack(new_pos)), path = interrupt_path })
end

local function ForEachWalkStep(p0, p1, f, ...)
	local step = const.SlabSizeX
	local x0, y0, z0 = p0:xyz()
	local x1, y1, z1 = p1:xyz()
	local dx = x1 - x0
	local dy = y1 - y0
	if abs(dx) >= abs(dy) then
		local step = step * (x1 >= x0 and 1 or -1)
		for x = x0 + step, x1, step do
			local y = y0 + MulDivRound(x - x0, dy, dx)
			f(point(x, y, z0), ...)
		end
	else
		local step = step * (y1 >= y0 and 1 or -1)
		for y = y0 + step, y1, step do
			local x = x0 + MulDivRound(y - y0, dx, dy)
			f(point(x, y, z0), ...)
		end
	end
end

function Unit:CanQuickPlayInCombat(noQuickPlay)
	return g_Combat and not noQuickPlay and not self.visible and self.team and not self.team.player_team
end

local function IsSamePos(p1, p2)
	if not p1 ~= not p2 then return false end
	local x1, y1, z1 = p1:xyz()
	local x2, y2, z2 = p2:xyz()
	z1 = z1 or terrain.GetHeight(x1, y1)
	z2 = z2 or terrain.GetHeight(x2, y2)
	return (x1 == x2) and (y1 == y2) and (z1 == z2)
end

function Unit:CombatGoto(action_id, cost_ap, pos, interrupt_path, forced_run, stanceAtStart, stanceAtEnd, fallbackMoveTracking, visibleMovement)
	Msg("UnitAnyMovementStart", self, pos, stanceAtStart, stanceAtEnd)
	
	self:RemovePreparedAttackVisuals()
	if interrupt_path then
		self.combat_path = interrupt_path
		pos = point(point_unpack(interrupt_path[1]))
	else
		self.combat_path_obj = GetCombatPath(self, stanceAtStart, cost_ap, stanceAtEnd)
		self.combat_path = self.combat_path_obj:GetCombatPathFromPos(pos)
		
		if not stanceAtStart and self.combat_path and self.combat_path_obj.destination_stances and pos then
			stanceAtStart = self.combat_path_obj.destination_stances[point_pack(pos)]
		end
		
		local new_cost = self.combat_path_obj:GetAP(pos)
		if not new_cost or new_cost > cost_ap then
			self:GainAP(cost_ap)
			CombatActionInterruped(self)
			return false
		end
		if new_cost < cost_ap then
			self:GainAP(cost_ap - new_cost)
			cost_ap = new_cost
		end
	end
	if not self.combat_path then
		self:GainAP(cost_ap)
		return true
	end
	if self.combat_path_obj then
		self:SetActionInterruptCallback("CombatGotoInterrupt")
	end
	local thread_RunStop
	self:PushDestructor(function(self)
		DeleteThread(thread_RunStop)
		if IsValid(self) then
			if self.combat_path then
				self:CombatGotoInterrupt(nil, "restore_ap_only")
			end
			self:SetActionInterruptCallback()
		end
		self.combat_path_obj = false
		self.combat_path = false
		self.in_combat_movement = false
	end)
	self.in_combat_movement = true

	if stanceAtStart and self.stance ~= stanceAtStart then
		self:ChangeStance("Stance" .. stanceAtStart, 0, stanceAtStart)
	end

	-- update move anim
	local path = self.combat_path
	local pfclass = self:GetPfClass() + 1
	local tunnel_mask = pathfind[pfclass].tunnel_mask
	local GetTunnel = pf.GetTunnel
	local run_dist = 0
	local px, py, pz = self:GetPosXYZ()
	for i = #path, 1, -1 do
		if terrain.GetPassType(px, py, pz) == pathfind_water_pass_type_idx then
			break
		end
		local px2, py2, pz2 = point_unpack(path[i])
		local tunnel = GetTunnel(px, py, pz, px2, py2, pz2, tunnel_mask)
		if tunnel and not tunnel:CanSprintThrough() then
			break
		end
		run_dist = run_dist + GetLen(px - px2, py - py2, pz and pz2 and pz - pz2 or 0)
		px, py, pz = px2, py2, pz2
	end

	local move_anim_type
	if self.species == "Human" then
		if self.stance == "Standing" and (forced_run or run_dist >= 5 * const.SlabSizeX) then
			move_anim_type = "Run"
		end
	end

	local has_closed_door = false
	local px, py, pz = self:GetPosXYZ()
	local closed_door_mask = const.TunnelMaskClosedDoor
	for i = #path, 1, -1 do
		local px2, py2, pz2 = point_unpack(path[i])
		local tunnel = GetTunnel(px, py, pz, px2, py2, pz2, closed_door_mask)
		if tunnel then
			has_closed_door = true
			break
		end
		px, py, pz = px2, py2, pz2
	end

	self:SetIK("AimIK", false)
	self:SetFootPlant(true)
	local base_idle = self:GetIdleBaseAnim()
	local goto_dummies = self:GenerateTargetDummiesFromPath(self.combat_path)
	for _, dummy in ipairs(goto_dummies) do
		if dummy.insert_idx then
			dummy.insert_before_pos = self.combat_path[dummy.insert_idx] or "limit"
		end
	end

	local known_traps
	local all_move_interrupts = self:CheckProvokeOpportunityAttacks("move", goto_dummies, true, "all")
	for i, t in ipairs(all_move_interrupts) do
		if t[1] == "trap" then
			known_traps = known_traps or {}
			table.insert(known_traps, t[2])
		end
	end

	local provoke_idx, provoke_pos, interrupts
	local UpdateProvokePos = function(init)
		if provoke_idx then
			for i = 1, provoke_idx do
				table.remove(goto_dummies, 1)
			end
		elseif not init then
			return
		end
		interrupts, provoke_idx = self:CheckProvokeOpportunityAttacks("move", goto_dummies, nil, nil, nil, known_traps)
		provoke_pos = provoke_idx and goto_dummies[provoke_idx].pos
		if provoke_pos then
			-- add the provoke point in the path if not present
			local insert_idx
			local insert_marker = goto_dummies[provoke_idx].insert_before_pos
			if insert_marker == "limit" then
				insert_idx = #self.combat_path + 1
			else
				local pp = point_pack(provoke_pos)
				for i, ppos in ipairs(self.combat_path) do
					if ppos == pp then
						insert_idx = false
						break
					elseif insert_marker == ppos then
						insert_idx = i
						break
					end
				end
			end
			
			if insert_idx then
				table.insert(self.combat_path, insert_idx, point_pack(provoke_pos))
			end
			return
		end
		local goto_pos, angle
		if not next(self.combat_path)  then
			goto_pos = self:GetPos()
		else
			goto_pos = point(point_unpack(self.combat_path[1]))
			if self.combat_path[2] then
				angle = CalcOrientation(point(point_unpack(self.combat_path[2])), goto_pos)
			end
		end
		angle = angle or self:GetOrientationAngle()
		self:SetTargetDummy(goto_pos, angle, base_idle, 0)
		self.target_dummy:SetEnumFlags(const.efResting)
		-- update occupy in advance to allow parallel unit movements
		if action_id and not has_closed_door and CombatActions[action_id].SimultaneousPlay and not fallbackMoveTracking then
			SetCombatActionState(self, "PostAction")
		end
	end
	UpdateProvokePos(true)
	if provoke_pos then
		WaitOtherCombatActionsEnd(self)
	end

	-- If was visible at the start of movement, should be visible throughout
	local povTeam = GetPoVTeam()
	if povTeam then
		if HasVisibilityTo(povTeam, self) then
			self.visibility_override = goto_dummies[1]
		end
	end

	-- If will enter overwatch, show me as if there.
	if not self.visibility_override then
		for i, int in ipairs(interrupts) do
			if int[1] == "overwatch" then
				self.visibility_override = goto_dummies[provoke_idx]
			end
		end
	end

	-- Update visibility as if at final pos otherwise.
	if not self.visibility_override then
		self.visibility_override = goto_dummies[#goto_dummies]
	end

	local distanceMove = GetCombatPathLen(path, self)
	local is_hidden	 = self:HasStatusEffect("Hidden")
	local isPanickedOrBerserked = self:HasStatusEffect("Panicked") or self:HasStatusEffect("Berserk")
	if not isPanickedOrBerserked and (distanceMove >= const.SlabSizeX * 3) and (self.command == "CombatGoto") and self:IsLocalPlayerControlled() then
		PlayVoiceResponse(self, is_hidden and "CombatMovementStealth" or "CombatMovement")	
	end

	local cur_pos = GetPassSlab(self) or self:GetVisualPos()
	if provoke_pos then
		self:SetTargetDummy(false) -- the target used for opportunity attacks
		if IsSamePos(provoke_pos, cur_pos) then
			self:ProvokeOpportunityAttacksFromList(interrupts)
			UpdateProvokePos()
		end
	end

	local next_pt = point(point_unpack(path[#path]))
	if self:GetDist2D(next_pt) == 0 then
		next_pt = #path > 1 and point(point_unpack(path[#path - 1])) or nil
		if next_pt and not next_pt:IsValid() then
			next_pt = #path > 2 and point(point_unpack(path[#path - 2])) or nil
		end
	end
	self:ClearEnumFlags(const.efResting)
	self:UpdateMoveAnim(action_id, move_anim_type, next_pt)
	local start_angle = next_pt and CalcOrientation(self, next_pt)
	local move_anim = GetStateName(self:GetMoveAnim())
	self:PlayTransitionAnims(move_anim, start_angle)
	self:GotoTurnOnPlace(next_pt)

	VisibilityUpdate()
	self:StartMoving()

	-- follow path
	local prev_pos = cur_pos
	Msg("UnitMovementStart", self, cur_pos)
	local stop_anim_pos = self:CombatGoto_GetStopAnimPos()
	local play_stop_dist
	while true do
		self:UpdateMoveSpeed()
		self:UpdateInWaterFX()
		if IsSamePos(provoke_pos, cur_pos) then
			self:ProvokeOpportunityAttacksFromList(interrupts)
			UpdateProvokePos()
		end
		local next_pos = point(point_unpack(path[#path]))
		if next_pos == cur_pos then
			path[#path] = nil
			if #path == 0 then
				break
			end
			next_pos = point(point_unpack(path[#path]))
		end
		local quick_play = self:CanQuickPlayInCombat(visibleMovement)
		if cur_pos == stop_anim_pos and not provoke_pos and not quick_play then
			play_stop_dist = self:StartPlayRunStop(path)
		end
		if play_stop_dist then
			local anim = self:GetStateText()
			local has_end_phase, end_phase = self:IterateMoments(anim, 0, 1, "end")
			if not has_end_phase then
				end_phase = GetAnimDuration(self:GetEntity(), anim) - 1
			end
			if not thread_RunStop then
				thread_RunStop = CreateGameTimeThread(function(self, pos, end_phase)
					local has_hit_phase, hit_phase = self:IterateMoments(anim, 0, 1, "hit")
					if not has_hit_phase then
						hit_phase = end_phase
					end
					local next_hit_time = self:TimeToPhase(1, hit_phase)
					if next_hit_time then
						Sleep(next_hit_time)
					end
					local surface_fx_type, surface_pos = GetObjMaterial(pos:IsValidZ() and pos or pos:SetTerrainZ())
					PlayFX("RunStop", "hit", self, surface_fx_type, surface_pos)
				end, self, next_pos, end_phase)
			end
			local next_pos_time
			if #path == 1 then
				next_pos_time = self:TimeToPhase(1, end_phase)
			else
				local phase = self:GetAnimPhase(1)
				local next_step_dist = self:GetStepVector(anim, 0, phase, end_phase - phase):Len2D() * self:GetVisualDist2D(next_pos) / play_stop_dist
				local min = phase
				local max = end_phase
				while max - min > 10 do
					local m = min + (max - min) / 2
					local len = self:GetStepVector(anim, 0, phase, m - phase):Len2D()
					if len < next_step_dist then
						min = m
					else
						max = m
					end
				end
				next_pos_time = self:TimeToPhase(1, min)
			end
			self:SetPos(next_pos, next_pos_time or 0)
			if next_pos_time then
				Sleep(next_pos_time)
			end
			if #path == 1 then
				local surface_fx_type, surface_pos = GetObjMaterial(next_pos:IsValidZ() and next_pos or next_pos:SetTerrainZ())
				PlayFX("RunStop", "end", self, surface_fx_type, surface_pos)
			end
		else
			local tunnel = GetTunnel(cur_pos, next_pos, tunnel_mask)
			if tunnel then
				local can_use_tunnel
				can_use_tunnel, quick_play = self:InteractTunnel(tunnel, quick_play)
				if not can_use_tunnel then
					self:Interrupt(nil, cur_pos) -- locked door
					break
				end
				if not IsValid(tunnel) then
					-- the open door erased the tunnel
					tunnel = GetTunnel(cur_pos, next_pos, tunnel_mask)
				end
				if tunnel then
					self:TraverseTunnel(tunnel, cur_pos, next_pos, false, quick_play)
					if quick_play and self:GetStateText() ~= move_anim then
						self:SetState(move_anim, const.eKeepComponentTargets, 0)
					end
				elseif IsPassSlabStep(cur_pos, next_pos, 0, self:GetPfClass()) then
					next_pos = cur_pos
				else
					self:Interrupt() -- the path is no more valid
					break
				end
			else
				if self:GetStateText() ~= move_anim then
					self:SetState(move_anim, const.eKeepComponentTargets, quick_play and 0 or -1)
					self:SetFootPlant(true)
				end
				local angle = CalcOrientation(cur_pos, next_pos)
				local max_step_len = 5 * const.SlabSizeX
				local step_dist = cur_pos:Dist2D(next_pos)
				if step_dist > max_step_len then
					table.insert(path, point_pack(next_pos))
					next_pos = RotateRadius(max_step_len, angle, cur_pos)
					step_dist = cur_pos:Dist2D(next_pos)
				end
				if quick_play then
					self:SetPos(next_pos)
					self:SetOrientationAngle(angle)
				else
					while step_dist > 0 do
						local time = MulDivRound(step_dist, 1000, Max(1, self:GetSpeed()))
						self:SetPos(next_pos, time)
						if self.ground_orient then
							local steps = 1 + step_dist / (const.SlabSizeX / 2)
							for i = 1, steps do
								local t = time * i / steps - time * (i-1) / steps
								self:SetOrientationAngle(angle, t)
								if WaitWakeup(t) then
									break
								end
							end
						else
							self:SetOrientationAngle(angle, 300)
							WaitWakeup(time)
						end
						step_dist = self:GetVisualDist2D(next_pos)
					end
				end
			end
		end
		cur_pos = next_pos
		Msg("CombatGotoStep", self)
	end
	
	if stanceAtEnd and self.stance ~= stanceAtEnd then
		self:ChangeStance("Stance" .. stanceAtEnd, 0, stanceAtEnd)
	end

	self.combat_path_obj = false
	self.combat_path = false
	self:PopAndCallDestructor()
	Msg("UnitMovementDone", self, action_id, prev_pos)
	return true
end

function Unit:CombatGoto_GetStopAnimPos()
	if self.species ~= "Human" or self.stance == "Prone" or self.infected then
		return
	end
	local path = self.combat_path
	local pfclass = self:GetPfClass() + 1
	local tunnel_mask = pathfind[pfclass].tunnel_mask
	if path[#path] ~= point_pack(self:GetPosXYZ()) then
		table.insert(path, point_pack(self:GetPos()))
	end
	if #path < 2 then
		return
	end
	local p1 = point(point_unpack(path[1]))
	local p2 = point(point_unpack(path[2]))
	local tunnel = pf.GetTunnel(p2, p1, tunnel_mask)
	if tunnel then
		local tunnel_type = pf.GetTunnelType(tunnel)
		if tunnel_type ~= (tunnel_type & const.TunnelMaskWalk) then
			return
		end
	end
	local dir_pos = RotateRadius(const.SlabSizeX, CalcOrientation(p2, p1), p1)
	if GetCoverFrom(p1, dir_pos) == 0 then
		return -- there should be a cover ahead of us
	end

	local move_anim = GetStateName(self:GetMoveAnim())
	local is_running = string.match(move_anim, ".*_CombatRun.*") and true or false
	local stop_distance, min_stop_distance
	if is_running then
		stop_distance = 5*guim
		min_stop_distance = stop_distance
	else
		stop_distance = 2*guim
		min_stop_distance = stop_distance
	end

	local start_stop_anim_pos = p1
	local start_stop_anim_idx = 1
	for i = 2, #path do
		local prev = point(point_unpack(path[i]))
		local tunnel = pf.GetTunnel(prev, start_stop_anim_pos, tunnel_mask)
		if tunnel then
			local tunnel_type = pf.GetTunnelType(tunnel)
			if tunnel_type ~= (tunnel_type & const.TunnelMaskWalk) then
				break
			end
		end
		if i > 2 and DistSegmentToPt2D(p1, p2, prev) >= 2 then
			break
		end
		start_stop_anim_pos = prev
		start_stop_anim_idx = i
		if not IsCloser2D(p1, start_stop_anim_pos, stop_distance) then
			break
		end
	end
	if IsCloser2D(p1, start_stop_anim_pos, min_stop_distance) then
		return
	end
	if not IsCloser2D(p1, start_stop_anim_pos, stop_distance) then
		if p1:IsValidZ() or start_stop_anim_pos:IsValidZ() then
			if not p1:IsValidZ() then p1 = p1:SetTerrainZ() end
			if not start_stop_anim_pos:IsValidZ() then start_stop_anim_pos = start_stop_anim_pos:SetTerrainZ() end
		end
		start_stop_anim_pos = p1 + SetLen(start_stop_anim_pos - p1, stop_distance)
		table.insert(path, start_stop_anim_idx, point_pack(start_stop_anim_pos))
	end
	return start_stop_anim_pos
end

function Unit:StartPlayRunStop(path)
	local move_anim = GetStateName(self:GetMoveAnim())
	local stop_anim = string.match(move_anim, "(.*_Combat%a*).*")
	if stop_anim then
		stop_anim = self:GetRandomAnim(stop_anim .. "Stop")
	end
	if not stop_anim or not IsValidAnim(self, stop_anim) then
		return false
	end

	local moments = self:GetAnimMoments(stop_anim)
	moments = table.ifilter(moments, function(_, m) return m.Type == "FootLeft" or m.Type == "FootRight" end)
	if #moments == 0 then
		print("once", string.format('missing "FootLeft" and "FootRight" moments in anim %s for %s (%s)', stop_anim, self.unitdatadef_id, self:GetEntity()))
	end

	local cur_anim = GetStateName(self:GetAnim(1))
	local cur_phase = self:GetAnimPhase(1)
	local has_moment1, t1 = self:IterateMoments(cur_anim, cur_phase, 1, "FootLeft", false, true)
	local has_moment2, t2 = self:IterateMoments(cur_anim, cur_phase, 1, "FootRight", false, true)
	if not has_moment1 or not has_moment2 then
		t1 = false
		t2 = false
	end

	local next_moment_type, prc
	if not t1 or not t2 or t1 == t2 or #moments < 2 then
		prc = 0
	elseif t1 < t2 then
		next_moment_type = "FootLeft"
		prc = MulDivRound(t1, 1000, t2 - t1)
	else
		next_moment_type = "FootRight"
		prc = MulDivRound(t2, 1000, t1 - t2)
	end

	local dist_to_stop = 0
	local stop_pos = self:GetPos()
	for i = #path, 1, -1 do
		local p2 = point(point_unpack(path[i]))
		dist_to_stop = dist_to_stop + stop_pos:Dist2D(p2)
		stop_pos = p2
	end
	local duration = GetAnimDuration(self:GetEntity(), stop_anim)
	local start_idx = (not next_moment_type or moments[1].Type == next_moment_type) and 1 or 2
	local step = next_moment_type and 2 or 1
	local best_phase, best_value
	for i = start_idx, #moments, step do
		local phase = moments[i].Time
		if prc > 0 then
			local d = i == 1 and moments[2].Time - phase or phase - moments[i-1].Time
			phase = phase - MulDivRound(d, prc, 1000)
		end
		if phase >= 0 then
			local len = self:GetStepVector(stop_anim, 0, phase, duration - phase):Len2D()
			local value = abs(len - dist_to_stop)
			if not best_value or value < best_value then
				best_phase = phase
				best_value = value
			end
		end
	end
	self:SetAnimChannel(1, stop_anim, 0, -1, 100, const.StopAnimCrossfadeTime)
	self:SetAnimPhase(1, best_phase or 0)
	self:Face(stop_pos, 200)
	return dist_to_stop
end

function Unit:Teleport(pos, angle)
	self:LeaveEmplacement(true)
	self:HolsterBombardWeapon()
	self.return_pos = false
	if not pos then
		pos = pos or GetPassSlab(self) or SnapToVoxel(self:GetPos())
	end
	self:SetPos(pos)
	if self:IsDead() then
		self:SetFootPlant(true, 0)
	else
		Msg("UnitAnyMovementStart", self)
		local orientation_angle = self:GetPosOrientation(pos, angle, self.stance, true, true)
		local base_idle = self:GetIdleBaseAnim()
		self:SetRandomAnim(base_idle, 0, 0, true)
		self:SetOrientationAngle(orientation_angle, 0)
		self:SetFootPlant(true, 0)
		self:SetTargetDummy(pos, orientation_angle, base_idle, 0)
		CombatPathReset(self)
		self:ProvokeOpportunityAttacks("move")
		Msg("UnitMovementDone", self)
		RedeploymentCheckDelayed()
	end
end

function Unit:UpdateMoveAnimFromStyle(move_style_id, next_pt)
	move_style_id = move_style_id or self.cur_move_style
	local move_style = GetAnimationStyle(self, move_style_id)
	if not move_style then
		return false
	end
	local anim, rotation_time
	if self:GetStepLength() == 0 then
		if next_pt and (move_style.MoveStart_Left or "") ~= "" and (move_style.MoveStart_Right or "") ~= "" then
			local start_angle = self:GetVisualOrientationAngle()
			local angle = CalcOrientation(self, next_pt)
			local angle_diff = AngleDiff(angle, start_angle)
			if abs(angle_diff) >= 30*60 then
				local rotate_anim = angle_diff < 0 and move_style.MoveStart_Left or move_style.MoveStart_Right
				if rotate_anim and IsValidAnim(self, rotate_anim) then
					anim = rotate_anim
					rotation_time = GetAnimDuration(self:GetEntity(), anim)
				end
			end
		end
		if not anim and move_style.MoveStart and IsValidAnim(self, move_style.MoveStart) then
			anim = move_style.MoveStart
		end
	end
	if not anim then
		anim = self:GetStateText()
		if self:GetAnimPhase() == 0 or self:IsAnimEnd() or not move_style:HasMoveAnim(anim) then
			anim = move_style:GetRandomMoveAnim(self)
			if not anim or not IsValidAnim(self, anim) then
				local msg = string.format('Missing animation style "%s - %s" animation "%s". Gender: "%s". Entity: "%s". Appearance: %s', move_style.group, move_style.Name, anim or "", self.gender, self:GetEntity(), self.Appearance or "false")
				StoreErrorSource(self, msg)
				return false
			end
		end
	end
	if self:GetStepLength(anim) == 0 then
		local msg = string.format('Animation step is ziro! animation "%s". Entity: "%s"', anim or "", self:GetEntity())
		StoreErrorSource(self, msg)
		return false
	end
	self:SetMoveAnim(anim)
	self:SetRotationTime(rotation_time or 0)
	self:SetMoveTurnAnim(nil, nil)
	self:ChangePathFlags(const.pfAnimEnd)
	if (move_style.StepFX or "") ~= "" then
		self.move_step_fx = move_style.StepFX
	else
		if string.match(move_style.VariationGroup, "Run") then
			self.move_step_fx = "StepRun"
		else
			self.move_step_fx = "StepWalk"
		end
	end
	self.move_stop_anim_len = 0
	self.move_stop_foot_left_anim = false
	self.move_stop_foot_right_anim = false
	if (move_style.MoveStop_FootLeft or "") ~= "" and IsValidAnim(self, move_style.MoveStop_FootLeft) then
		self.move_stop_anim_len = self:GetStepLength(move_style.MoveStop_FootLeft)
		self.move_stop_foot_left_anim = move_style.MoveStop_FootLeft
		if (move_style.MoveStop_FootRight or "") ~= "" and IsValidAnim(self, move_style.MoveStop_FootRight) then
			self.move_stop_foot_right_anim = move_style.MoveStop_FootRight
		else
			self.move_stop_foot_right_anim = self.move_stop_foot_left_anim
		end
	end
	return true
end

function Unit:UpdateMoveAnim(action_id, anim_type, next_pt)
	if IsRealTimeThread() then
		--this func does interact rands
		--it is called in a rt when loading session data due to cascade onsetwhatevers
		--seems safe to ignore such calls, in fact it also asserts when called like that ->
		--turn_l and turn_r remain nil when move_anim doesn't
		return
	end
	NetUpdateHash("Unit:UpdateMoveAnim", action_id, anim_type, next_pt)
	local use_combat_anims
	self.cur_move_style = false
	if g_Combat and self:IsAware() then
		use_combat_anims = true
	elseif self.species == "Human" then
		local move_style = self:GetCommandParam("move_style")
		if not move_style then
			if self:IsVisiting() then
				move_style = self:GetDefaultMoveStyle()
			elseif not move_style and const.MercWalkStyle and self:IsMerc() then
				move_style = const.MercWalkStyle
				if type(move_style) ~= "string" or not GetAnimationStyle(self, move_style) then
					move_style = self:GetDefaultMoveStyle()
				end
			end
		end
		if move_style and self:UpdateMoveAnimFromStyle(move_style, next_pt) then
			self.cur_move_style = move_style
		end
	end
	NetUpdateHash("Unit:UpdateMoveAnim01", self.cur_move_style)
	if not self.cur_move_style or self.carry_flare then
		self:ChangePathFlags(0, const.pfAnimEnd)
		-- anim_type can be: Run, Walk, WalkSlow
		anim_type = anim_type or self:GetCommandParam("move_anim")
		local move_anim, turn_l, turn_r
		if self.species ~= "Human" then
			if anim_type ~= "Run" and use_combat_anims and g_Combat then
				anim_type = "Run"
			end
			move_anim = anim_type == "Run" and "run" or "walk"
			if IsValidAnim(self, move_anim) then
				NetUpdateHash("Unit:UpdateMoveAnim0", move_anim)
				move_anim = self:GetRandomAnim(move_anim)
			end
			if self.species == "Crocodile" or self.species == "Hyena" then
				if anim_type == "Run" then
					turn_l, turn_r = "run_Turn_L", "run_Turn_R"
				else
					turn_l, turn_r = "walk_Turn_L", "walk_Turn_R"
				end
			end
		elseif self.carry_flare then
			move_anim = "nw_Standing_Patrol_Flare"
			anim_type = "Walk"
		elseif use_combat_anims then
			local prefix = self:GetWeaponAnimPrefix()
			if action_id == "Charge" and prefix == "mk_" then
				local weapon, weapon2 = self:GetActiveWeapons()
				if IsKindOf(weapon, "MacheteWeapon") then
					move_anim = "mk_Standing_Machete_Run"
					anim_type = "Run"
				end
			end
			if not move_anim or not IsValidAnim(self, move_anim) then
				if self.stance == "Standing" then
					if anim_type == "Run" then
						move_anim = string.format("%sStanding_CombatRun", prefix)
					elseif anim_type == "Walk" or anim_type == "WalkSlow" then
						move_anim = string.format("%sStanding_CombatWalk", prefix)
					end
				elseif self.stance == "Crouch" then
					move_anim = string.format("%sStanding_CombatWalk", prefix)
					anim_type = "Walk"
				end
			end
			if move_anim and IsValidAnim(self, move_anim) then
				local cur_anim = self:GetStateText()
				NetUpdateHash("Unit:UpdateMoveAnim1", cur_anim, move_anim, IsAnimVariant(cur_anim, move_anim))
				move_anim = IsAnimVariant(cur_anim, move_anim) and cur_anim or self:GetRandomAnim(move_anim)
			end
		end
		if not move_anim or not IsValidAnim(self, move_anim) then
			local default_walk_style = (use_combat_anims or IsMerc(self) or self.stance ~= "Standing") and "Run" or "Walk"
			if not anim_type or (anim_type == "Walk" or anim_type == "WalkSlow") and self.stance ~= "Standing" then
				anim_type = default_walk_style
			end
			move_anim = self:GetActionBaseAnim(anim_type or default_walk_style, self.stance)
			if not move_anim and anim_type ~= default_walk_style then
				move_anim = self:GetActionBaseAnim(default_walk_style, "Standing")
			end
			if move_anim and (not self.behavior or RandomWalkAnimBehaviors[self.behavior]) then
				local cur_anim = self:GetStateText()
				NetUpdateHash("Unit:UpdateMoveAnim1", cur_anim, move_anim, IsAnimVariant(cur_anim, move_anim))
				move_anim = IsAnimVariant(cur_anim, move_anim) and cur_anim or self:GetRandomAnim(move_anim)
			end
		end
		self.move_step_fx =
			self.stance == "Prone" and "StepRunProne" or
			self.stance == "Crouch" and "StepRunCrouch" or
			anim_type == "Run" and "StepRun" or "StepWalk"
		local base_idle = self:GetIdleBaseAnim()
		self:SetMoveAnim(move_anim or self:GetIdleBaseAnim())
		self:SetRotationTime(0)
		self:SetMoveTurnAnim(turn_l, turn_r)
	end
	self:SetWaitAnim(self:GetIdleBaseAnim())
	self:UpdateMoveSpeed()
	self:UpdatePFClass()
end

function Unit:GetDefaultMoveStyle()
	if self.carry_flare then
		return GetRandomAnimationStyle(self, "Flare")
	end
	if not self.default_move_style then
		local style = self:GetRandomMoveStyle()
		if style then
			self.default_move_style = style.Name
		end
	end
	return self.default_move_style
end

function Unit:CalcMoveSpeedModifier()
	local modifier = 1000
	if terrain.GetPassType(self:GetVisualPosXYZ()) == pathfind_water_pass_type_idx then
		modifier = modifier + 10 * Presets.ConstDef["Action Point Costs"].WaterMoveSpeedModifier.value
	end
	if self:HasStatusEffect("Hidden") then 
		modifier = MulDivRound(modifier, 700, 1000)
	end
	local command_move_speed_modifier = self:GetCommandParam("move_speed_modifier")
	if command_move_speed_modifier then
		modifier = MulDivRound(modifier, command_move_speed_modifier, 1000)
	end
	return modifier
end

function Unit:UpdateMoveSpeed()
	local modifier = self:CalcMoveSpeedModifier()
	local speed
	if not g_Combat and self:IsMerc() then
		local move_anim = GetStateName(self:GetMoveAnim())
		local is_running = string.match(move_anim, ".*Run.*") and true or false
		if is_running then
			-- fixed speed for mercs
			if self.stance == "Standing" then
				speed = const.UnitMoveSpeed.MercStandingStance
			elseif self.stance == "Crouch" then
				speed = const.UnitMoveSpeed.MercCrouchStance
			elseif self.stance == "Prone" then
				speed = const.UnitMoveSpeed.MercProneStance
			end
		else
			if self.stance == "Standing" then
				speed = const.UnitMoveSpeed.MercWalk
			end
		end
	end
	if speed then
		local mod = MulDivRound(modifier, self:GetAnimSpeedModifier(), 1000)
		speed = MulDivRound(speed, mod, 1000)
		self:SetSpeed(speed)
	else
		self:SetMoveSpeed(modifier)
	end
	-- debug set speed on zero speed animations
	if self:GetSpeed() == 0 then
		self:SetSpeed(self.fallback_walk_speed)
	end
end

function Unit:UpdateInWaterFX()
	local fx_in_water = not self:IsDead() and terrain.GetPassType(self:GetVisualPosXYZ()) == pathfind_water_pass_type_idx
	if self.fx_in_water ~= fx_in_water then
		if fx_in_water then
			PlayFX("UnitInWater", "start", self)
		else
			PlayFX("UnitInWater", "end", self)
		end
		self.fx_in_water = fx_in_water
	end
end

function Unit:StartMoving()
	self.is_moving = true
	local team = self.team
	if not (team and team.neutral and EngineOptions.ObjectDetail == "Low") then
		PlaceUnitWindModifierTrail(self)
	end
end

function Unit:StopMoving()
	self.is_moving = false
	RemoveUnitWindModifierTrail(self)
end

function Unit:GetMovementNoise()
	local stance = self.species == "Human" and self.stance or "Standing"
	return Presets.CombatStance.Default[stance].Noise
end

function Unit:InteractTunnel(tunnel, quick_play)
	return tunnel:InteractTunnel(self, quick_play)
end

-- collision avoidance. offset pos2 to the right pass cell corner
function GetTunnelExitCollisionAvoidPos(pos1, pos2)
	local x1, y1, z1 = SnapToVoxel(pos1:xyz())
	local x2, y2, z2 = SnapToVoxel(pos2:xyz())
	if x1 == x2 and y1 == y2 then
		return pos2
	end
	local offset = const.SlabSizeX / 4
	if x1 == x2 then
		if y1 < y2 then
			x2 = x2 - offset
			--y2 = y2 - offset
		elseif y1 > y2 then
			x2 = x2 + offset - 1
			--y2 = y2 + offset - 1
		end
	elseif y1 == y2 then
		if x1 < x2 then
			--x2 = x2 - offset
			y2 = y2 + offset - 1
		elseif x1 > x2 then
			--x2 = x2 + offset - 1
			y2 = y2 - offset
		end
	elseif x1 < x2 then
		if y1 < y2 then
			x2 = x2 - offset
		elseif y1 > y2 then
			y2 = y2 + offset - 1
		end
	elseif x1 > x2 then
		if y1 > y2 then
			x2 = x2 + offset - 1
		elseif y1 < y2 then	
			y2 = y2 - offset
		end
	end
	if z2 then
		z2 = GetVoxelStepZ(x2, y2, z2)
	end
	return point(x2, y2, z2)
end

MapVar("__unit_step_target_dummies", {{phase = 0}})

function Unit:TraverseTunnel(tunnel, pos1, pos2, collision_avoidance, quick_play, use_stop_anim)
	local tunnel_entrance = tunnel:GetEntrance()
	local tunnel_exit = tunnel:GetExit()
	if not pos1 then
		pos1 = tunnel_entrance
	end
	if not pos2 then
		pos2 = tunnel_exit
	end
	-- check for a dead end way
	local dead_end
	if not g_Combat and (tunnel.tunnel_type & const.TunnelMaskWalk) == 0 then
		local side = self.team and self.team.side
		if side == "player1" or side == "player2" then
			local tunnel_mask = pathfind[self:GetPfClass() + 1].tunnel_mask
			local reverse_tunnel = pf.GetTunnel(tunnel_exit, tunnel_entrance, tunnel_mask)
			if not reverse_tunnel then
				if IsStuckedMercPos(self, pos2) then
					dead_end = true
					if self:IsInterruptable() then
						self:Interrupt()
						return
					end
				end
			end
		end
	end
	if collision_avoidance ~= false and self:GetPathFlags(const.pfmCollisionAvoidance) ~= 0 and terrain.IsPassable(pos2) then
		local pcount = self:GetPathPointCount()
		local next_pos = pcount > 1 and self:GetPathPoint(pcount - 1)
		if next_pos and next_pos:IsValid() and (tunnel.tunnel_type & const.TunnelTypeLadder) == 0 and not CanDestlock(pos2, 300) then
			pos2 = GetTunnelExitCollisionAvoidPos(pos1, pos2) -- offset pos2 to the right pass cell corner
			pf.SetPathPoint(self, -1, pos2) -- the path execution expects the unit to be at the last position of the path
		end
	end
	local interrupts
	if not self.combat_path and self.team and self.team.side ~= "neutral" then
		local target_dummy = __unit_step_target_dummies[1]
		target_dummy.obj = self
		target_dummy.anim = self:GetWaitAnim()
		interrupts = self:CheckProvokeOpportunityAttacks("move", __unit_step_target_dummies)
		if interrupts then
			self:ProvokeOpportunityAttacksWarning("move", interrupts)
		end
	end
		local wasInterruptable = self.interruptable
		if wasInterruptable then
			self:EndInterruptableMovement()
		end
	if not quick_play and (tunnel.tunnel_type & const.TunnelMaskTraverseWait) ~= 0 then
		self:TunnelBlock(tunnel_entrance, tunnel_exit)
		self:TunnelBlock(tunnel_exit, tunnel_entrance)
	end
	self.traverse_tunnel = tunnel
	tunnel:TraverseTunnel(self, pos1, pos2, quick_play, use_stop_anim)
	self.traverse_tunnel = false
	if not quick_play and (tunnel.tunnel_type & const.TunnelMaskTraverseWait) ~= 0 then
		self:TunnelUnblock(tunnel_exit, tunnel_entrance)
		self:TunnelUnblock(tunnel_entrance, tunnel_exit)
	end
	self:SetFootPlant(true)
	if dead_end then
		RedeploymentCheckDelayed()
	end
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
	if interrupts then
		self:ProvokeOpportunityAttacksFromList(interrupts)
	end
end

function Unit:GotoStopCheck(stop_anim_tunnel_idx)
	if self.move_stop_anim_len == 0 then
		return false
	end
	if not stop_anim_tunnel_idx then
		stop_anim_tunnel_idx = pf.GetPathNextTunnelIdx(self, const.TunnelMaskWalkStopAnim) or 1
	end
	local pcount = self:GetPathPointCount()
	if pcount <= stop_anim_tunnel_idx + 4 then
		local pathlen = self:GetPathLen(false, stop_anim_tunnel_idx)
		local step_dist = self:GetVisualDist2D(self:GetPosXYZ()) 
		if pathlen - step_dist < self.move_stop_anim_len then
			local dest = self:GetPathPoint(stop_anim_tunnel_idx)
			if dest and not dest:IsValid() then
				stop_anim_tunnel_idx = stop_anim_tunnel_idx - 1
				dest = self:GetPathPoint(stop_anim_tunnel_idx)
			end
			if not dest or not dest:IsValid() then
				return false
			end
			-- clear path points before dest
			for i = self:GetPathPointCount(), stop_anim_tunnel_idx + 1, -1 do
				pf.SetPathPoint(self, i)
			end
			local wait_time = pathlen > self.move_stop_anim_len and pf.GetMoveTime(self, pathlen - self.move_stop_anim_len) or 0
			if wait_time > 0 then
				Sleep(wait_time)
			end
			self:GotoStop(dest)
			return true
		end
	end
	return false
end

function Unit:GotoStop(dest)
	local l1 = self:TimeToMoment(1, "FootLeft", -1)
	local l2 = self:TimeToMoment(1, "FootLeft", 1)
	local r1 = self:TimeToMoment(1, "FootRight", -1)
	local r2 = self:TimeToMoment(1, "FootRight", 1)
	local t1, t2, anim, anim1, anim2
	if l1 and (not r1 or l1 < r1) then
		t1, anim1 = l1, self.move_stop_foot_left_anim
	else
		t1, anim1 = r1, self.move_stop_foot_right_anim
	end
	if l2 and (not r2 or l2 < r2) then
		t2, anim2 = l2, self.move_stop_foot_left_anim
	else
		t2, anim2 = r2, self.move_stop_foot_right_anim
	end
	if t1 and t2 then
		local t = t1 + t2
		local perc = t > 0 and t1 * 100 / t or 0
		if perc < const.AmbientLife.WalkStopMomentProximity then
			anim = anim1
		else
			anim = anim2
		end
	elseif t1 then
		anim = anim1
	else
		anim = anim2
	end
	anim = anim or self.move_stop_foot_left_anim or self.move_stop_foot_right_anim
	self:SetState(anim)
	repeat
		self:SetAnimSpeed(1, self:GetMoveSpeed())
		local t = self:TimeToAnimEnd()
		self:SetPos(dest or self:GetPos(), t)
	until not WaitWakeup(t)
end

function Unit:MoveSleep(time)
	local end_time = now() + time
	repeat until not WaitWakeup(end_time - now()) or self:GetPathFlags(const.pfDirty) ~= 0
	if self.cur_move_style and (self:GetAnimPhase() == 0 or self:IsAnimEnd()) then
		self:UpdateMoveAnimFromStyle()
	end
end

function Unit:GotoTurnOnPlace(next_pos)
	if not next_pos then
		return
	end
	local move_style = GetAnimationStyle(self, self.cur_move_style)
	if move_style then
		if move_style.MoveStart_Left or move_style.MoveStart_Right then
			return -- move turn animations will be played if necessary
		end
		local angle = CalcOrientation(self, next_pos)
		self:AnimatedRotation(angle)
		return
	end
	if self:IsVisiting() then
		return -- move style support civilian
	end
	if self.stance ~= "Prone" then
		return
	end
	local angle = CalcOrientation(self, next_pos)
	local angle_diff = AngleDiff(angle, self:GetVisualOrientationAngle())
	local min_turn_angle
	if self:GetState() == self:GetMoveAnim() then
		min_turn_angle = const.GotoTurnOnPlaceMovingAngle
	else
		min_turn_angle = const.GotoTurnOnPlaceAngle
	end
	if abs(angle_diff) > min_turn_angle then
		self:AnimatedRotation(angle)
	end
end

DefineConstInt("AmbientLife", "ForbidVisitEnemyDist", 2, "m", "If player around this distance the enemy AL won't use chairs to sit(coming close will also interrupt this behavior normally)")

function Unit:IdleForcingDist(other)
	if self.waiting_attack then return true end
	
	local dist = self:GetDist(other)
	if dist <= const.AmbientLife.ForbidSitChairEnemyDist and IsSittingUnit(self) then
		return true
	end
	if dist <= const.AmbientLife.ForbidWallLeanEnemyDist and IsWallLeaningUnit(self) then
		return true
	end
	if dist <= const.AmbientLife.ForbidVisitEnemyDist and (self.routine == "Ambient" or self.routine == "Patrol") then
		return true
	end
end

function Unit:ShouldBeIdle(other)
	if self.command == "Die" or self.command == "Dead" then return false end
	
	if g_Combat or GameState.sync_loading or self.team and self.team.player_team then
		return true
	end
	if not g_Combat and (self.neutral_retal_attacked) then
		return true
	end
	if not IsValid(other) then
		local enemies = GetAllEnemyUnits(self)
		for _, unit in ipairs(enemies) do
			if self:ShouldBeIdle(unit) then
				return true
			end
		end
	else
		if self:IdleForcingDist(other) then
			return true
		end
	end
end

function Unit:GotoAction()
	if self.carry_flare then
		ResetVoxelStealthParamsCache() -- todo: partial invalidate would be cool (prev pos + current pos)
	end
	
	self:InvalidatePindownLinesCache()
	
	if not g_Combat and self:HasStatusEffect("Suspicious") then
		self:SetCommand("Idle")
		return
	end
	
	if self.goto_stance then
		self:GotoChangeStance(self.goto_stance)
		self.goto_stance = false
		if self:IsInterruptable() then
			self:BeginInterruptableMovement()
		end
	end
	if self.goto_hide then
		self.goto_hide = false
		self:Hide()
		if self:IsInterruptable() then
			self:BeginInterruptableMovement()
		end
	end	

	if self.team then
		local enemies = GetAllEnemyUnits(self)
		if self.team.player_team then	
			for _, unit in ipairs(enemies) do
				if unit:ShouldBeIdle(self) then
					unit:SetCommandParamValue("Idle", "idle_forcing_dist", self)
					unit:SetCommand("Idle")
				end
			end
		end
		if self.team.player_enemy then
			for _, unit in ipairs(enemies) do
				if self:ShouldBeIdle(unit) then
					self:SetCommandParamValue("Idle", "idle_forcing_dist", unit)
					self:SetCommand("Idle")
				end
			end
		end
		for _, enemy in ipairs(enemies) do
			local attacker, target
			if self.marked_target_attack_args and self.marked_target_attack_args.target == enemy then
				attacker, target = self, enemy
			elseif enemy.marked_target_attack_args and enemy.marked_target_attack_args.target == self then
				attacker, target = enemy, self
			end
			if attacker and target then
				local action = attacker:GetDefaultAttackAction()
				local weapon = action:GetAttackWeapons(attacker)
				if not IsKindOfClasses(weapon, "MeleeWeapon", "UnarmedWeapon") then
					attacker.marked_target_attack_args = nil
				elseif attacker:CanAttack(target, weapon, action) and IsMeleeRangeTarget(attacker, nil, nil, target) then
					local args = attacker.marked_target_attack_args
					TutorialHintsState.SneakMode = not not args
					TutorialHintsState.SneakApproach = not not args
					NetStartCombatAction(action.id, attacker, 0, args)
					break
				end
			end
		end
	end	
end

local pfFinished = const.pfFinished
local pfFailed = const.pfFailed
local pfDestLocked = const.pfDestLocked
local pfTunnel = const.pfTunnel
local gofRealTimeAnimMask = const.gofRealTimeAnim | const.gofEditorSelection

function Unit:GotoSlab(pos, distance, min_distance, move_anim_type, follow_target, use_stop_anim, interrupted)
	assert(self:GetGameFlags(gofRealTimeAnimMask) == 0)
	Msg("UnitAnyMovementStart", self)
	if use_stop_anim == nil then
		use_stop_anim = true
	end
	if use_stop_anim ~= false and self.move_stop_anim_len == 0 then
		use_stop_anim = false
	end

	self:SetTargetDummy(false)
	if self:TimeToPosInterpolationEnd() > 0 then
		local cur_pos = self:GetVisualPos()
		if not self:IsValidZ() then
			cur_pos = cur_pos:SetInvalidZ()
		end
		self:SetPos(cur_pos)
	end
	local dest, follow_pos
	if not pos and IsValid(follow_target) then
		dest = self:GetClosestMeleeRangePos(follow_target)
		follow_pos = follow_target:GetPos()
	elseif not pos then
		local tunnel_param = {
			unit = self,
			player_controlled = self.team and self.team:IsPlayerControlled(),
		}
		dest = GetCombatPathDestinations(self, nil, nil, nil, tunnel_param, nil, 2 * const.SlabSizeX, false, false, true)
		for i, packed_pos in ipairs(dest) do
			dest[i] = point(point_unpack(packed_pos))
		end
	elseif IsPoint(pos) then
		if self:GetPathFlags(const.pfmVoxelAligned) ~= 0 then
			dest = self:GetVoxelSnapPos(pos)
		end
	elseif self:GetPathFlags(const.pfmVoxelAligned) ~= 0 then
		for i = 1, #pos do
			local pt = self:GetVoxelSnapPos(pos[i])
			if pt then
				dest = dest or {}
				table.insert_unique(dest, pt)
			end
		end
	end
	dest = dest or pos

	local status = self:FindPath(dest, distance, min_distance)
	if self:GetPathPointCount() == 0 then
		if status == 0 then
			return true
		end
		return
	end

	-- cleanup stuff that prevents moving
	if self:HasStatusEffect("StationedMachineGun") then
		self:MGPack()
	elseif self:HasStatusEffect("ManningEmplacement") then
		self:LeaveEmplacement()
	elseif self:HasPreparedAttack() then
		self:InterruptPreparedAttack()
	end

	-- the target used for opportunity attacks
	self:SetTargetDummy(false)
	self:SetActionInterruptCallback(function(self)
		if not IsActivePaused() then
			self:SetCommand("GotoSlab")
		else
			self:SetQueuedAction()
			self:SetCommand("Idle")
		end
	end)
	self.goto_interrupted = interrupted
	self:PushDestructor(function(self)
		self:SetActionInterruptCallback()
		self.move_follow_target = nil
		self.move_follow_dest = nil
		self.goto_interrupted = nil
	end)
	self.move_follow_target = follow_target
	self.move_follow_dest = dest

	self:SetFootPlant(true)

	self.goto_target = pos

	local pfStep = self.Step
	local pfSleep = self.MoveSleep

	local target, target_time
	local is_moving = false

	Msg("UnitGoToStart", self)
	if IsActivePaused() then
		Sleep(1)
	end
	while true do
		self:TunnelsUnblock()
		if follow_pos and IsValid(follow_target) then
			if IsKindOf(follow_target.traverse_tunnel, "SlabTunnelLadder") then
				follow_target = false
				break
			end
			if follow_target:GetDist(follow_pos) > 0 then
				dest = self:GetClosestMeleeRangePos(follow_target)
				target = false
				follow_pos = follow_target:GetPos()
				self.move_follow_dest = dest
			end
		end
		if not target or self:GetPathPointCount() == 0 then
			status = self:FindPath(dest, distance, min_distance)
			if self:GetPathPointCount() == 0 then
				if status == 0 then
					status = pfFinished
				end
				break
			end
			local tunnel_start_idx = pf.GetPathNextTunnelIdx(self, const.TunnelMaskTraverseWait)
			if tunnel_start_idx then
				local tunnel_entrance = pf.GetPathPoint(self, tunnel_start_idx)
				local tunnel_exit = pf.GetPathPoint(self, tunnel_start_idx - 2)
				local last_target = target or self:GetPos()
				target = nil
				if last_target == tunnel_entrance or type(last_target) == "table" and table.find(last_target, tunnel_entrance) then
					if CanUseTunnel(tunnel_entrance, tunnel_exit, self) then
						self:TunnelBlock(tunnel_entrance, tunnel_exit)
						self:TunnelBlock(tunnel_exit, tunnel_entrance)
						local tunnel_start_idx2 = pf.GetPathNextTunnelIdx(self, const.TunnelMaskTraverseWait, tunnel_start_idx - 2)
						if tunnel_start_idx2 then
							local tunnel_entrance2 = pf.GetPathPoint(self, tunnel_start_idx2)
							local tunnel_exit2 = pf.GetPathPoint(self, tunnel_start_idx2 - 2)
							target = GetAlternateRoutesStartPoints(self, tunnel_entrance2, tunnel_exit2, const.TunnelMaskTraverseWait)
						else
							target = dest
						end
					end
				end
				if not target then
					target = GetAlternateRoutesStartPoints(self, tunnel_entrance, tunnel_exit, const.TunnelMaskTraverseWait)
				end
			elseif target ~= dest then
				target = dest
			end
			target_time = now()
			if target ~= dest then
				self:FindPath(target)
			end
			local pcount = self:GetPathPointCount()
			local next_pt = pcount > 1 and pf.GetPathPoint(self, pcount - 1) or nil
			if next_pt and not next_pt:IsValid() then
				next_pt = pcount > 2 and pf.GetPathPoint(self, pcount - 2) or nil
			end
			local angle = next_pt and CalcOrientation(self.target_dummy or self, next_pt)
			self:UpdateMoveAnim(nil, move_anim_type, next_pt)
			local move_anim = GetStateName(self:GetMoveAnim())
			self:PlayTransitionAnims(move_anim, angle)
			self:GotoTurnOnPlace(next_pt) -- face next target point
		end
		local target_distance, target_min_distance
		if target == dest then
			target_distance = distance
			target_min_distance = min_distance
		else
			-- approaching tunnel. the tunnel can be destlocked, so the unit should destlock and wait
		end
		local wait
		status = pfStep(self, target, target_distance, target_min_distance)
		if status > 0 then
			if not is_moving then
				is_moving = true
				self:StartMoving()
			end
			while status > 0 do
				if not use_stop_anim or not self:GotoStopCheck() then
					pfSleep(self, status)
				end
				self:GotoAction()
				if follow_pos and IsValid(follow_target) and follow_target:GetDist(follow_pos) > 0 then
					if IsKindOf(follow_target.traverse_tunnel, "SlabTunnelLadder") then
						status = pfFinished
						dest = self:GetPos()
						target = dest
						break
					end
					local newdest = self:GetClosestMeleeRangePos(follow_target)
					if newdest ~= dest then
						dest = newdest
						target = newdest
					end
				end
				status = pfStep(self, target, target_distance, target_min_distance)
			end
		end
		if status == pfFinished and target == dest then
			break
		elseif status == pfFinished and target_time ~= now() then
			target = nil
		elseif status == pfTunnel then
			self:ClearEnumFlags(const.efResting) -- resting flag block the later ClearPath()
			local tunnel = pf.GetTunnel(self)
			if not tunnel then
				status = pfFailed
				break
			end
			if not self:InteractTunnel(tunnel) then
				status = pfFailed
				break
			end
			if not IsValid(tunnel) then
				tunnel = pf.GetTunnel(self)
			end
			local tunnel_in_use = IsValid(tunnel) and (tunnel.tunnel_type & const.TunnelMaskTraverseWait) ~= 0
				and not CanUseTunnel(tunnel:GetEntrance(), tunnel:GetExit(), self)
			if IsValid(tunnel) and not tunnel_in_use then
				if not is_moving then
					is_moving = true
					self:StartMoving()
				end
				local use_stop_anim = self.move_stop_anim_len > 0 and (pf.GetPathNextTunnelIdx(self, const.TunnelMaskWalkStopAnim) or 1) == self:GetPathPointCount()
				self:TraverseTunnel(tunnel, nil, nil, true, false, use_stop_anim)
				self:GotoAction()
			else
				target = nil -- the path is invalid, a new one should be cast
				wait = tunnel_in_use
			end
		elseif target ~= dest then
			wait = true
		else
			break
		end
		if wait then
			local anim = self:GetWaitAnim()
			if self:GetState() ~= anim then
				self:SetState(anim, const.eKeepComponentTargets)
			end
			local target_pos
			if IsPoint(target) then
				target_pos = target
			elseif IsValid(target) then
				target_pos = target:GetPos()
			else
				for i, p in ipairs(target) do
					if i == 1 or IsCloser(self, p, target_pos) then
						target_pos = p
					end
				end
			end
			if target_pos and not target_pos:Equal2D(self:GetPosXYZ()) then
				self:Face(target_pos)
			end
			if is_moving then
				is_moving = false
				self:StopMoving()
			end
			self:ClearPath()
			pfSleep(self, 200)
			self:GotoAction()
		end
	end

	self:PopAndCallDestructor()
	self.goto_target = false
	if is_moving then
		self:StopMoving()
	end
	Msg("UnitMovementDone", self)
	Msg("UnitGoTo", self)
	ObjModified(self)
	return status == pfFinished
end

function Unit:UninterruptableGoto(pos, straight_line)
	local wasInterruptable = self.interruptable
	if wasInterruptable then
		self:EndInterruptableMovement()
	end
	pos = self:GetVoxelSnapPos(pos) or pos
	assert(not self.goto_target) -- should be a top level Goto
	self.goto_target = pos
	self:UpdateMoveAnim()
	if straight_line then
		self:Goto(pos, "sl")
	else
		self:Goto(pos)
	end
	self.goto_target = false
	Msg("UnitMovementDone", self)
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
end

function Unit:Step(...)
	self:UpdateMoveSpeed()
	local status = AnimMomentHook.Step(self, ...)
	if status > 0 then
		if not self.combat_path and self.team and self.team.side ~= "neutral" then
			local target_dummy = __unit_step_target_dummies[1]
			target_dummy.obj = self
			target_dummy.anim = self:GetWaitAnim()
			local interrupts = self:CheckProvokeOpportunityAttacks("move", __unit_step_target_dummies)
			self:ProvokeOpportunityAttacksWarning("move", interrupts)
			self:ProvokeOpportunityAttacks("move", target_dummy) -- traps
		end
		self:UpdateInWaterFX()
	end
	return status
end

function Unit:Goto(...)
	local pfStep = self.Step
	self:SetTargetDummy(false)
	self:UpdateMoveAnim()
	local status = pfStep(self, ...)
	if status >= 0 or status == pfTunnel then
		local topmost_goto, is_moving
		if not self.goto_target then
			topmost_goto = true
			self.goto_target = ...
		end
		local pfSleep = self.MoveSleep
		while true do
			if status > 0 then
				if not is_moving then
					is_moving = true
					self:StartMoving()
				end
				pfSleep(self, status)
			elseif status == pfTunnel then
				local tunnel = pf.GetTunnel(self)
				if not tunnel then
					status = pfFailed
					break
				end
				if not is_moving then
					is_moving = true
					self:StartMoving()
				end
				if not self:InteractTunnel(tunnel) then
					status = pfFailed
					break
				end
				if IsValid(tunnel) then
					self:TraverseTunnel(tunnel)
				end
			else
				break
			end
			status = pfStep(self, ...)
		end
		if is_moving then
			self:StopMoving()
		end
		if topmost_goto then
			self.goto_target = false
		end
		CombatPathReset(self)
		ObjModified(self)
	end

	local res = status == pfFinished
	Msg("UnitGoTo", self)
	return res
end

function Unit:IsInterruptable()
	if self.interruptable then
		if not self.goto_stance and not self.goto_hide then
			return true
		end
	end
	if self:IsIdleCommand() or self:HasQueuedAction() then
		return true
	end
	return false
end

function Unit:IsInterruptableMovement()
	return self.interruptable and (self.goto_target or self.move_attack_in_progress)
end

function Unit:InterruptCommand(...)
	self:Interrupt("SetCommand", ...)
end

function NetSyncEvents.InterruptCommand(unit, ...)
	unit:InterruptCommand(...)
end

function Unit:SetActionInterruptCallback(func)
	self.action_interrupt_callback = func
end

function Unit:Interrupt(func, ...)
	if self:IsInterruptable() then
		if not func and self.action_interrupt_callback then
			func = self.action_interrupt_callback
			self.action_interrupt_callback = false
		end
		if not func then
			return
		end
		if type(func) ~= "function" then
			func = self[func]
		end
		assert(func)
		if func then
			func(self, ...)
		end
		return
	end
	self.interrupt_callback = pack_params(func or false, ...)
end

function Unit:BeginInterruptableMovement()
	self.interruptable = true
	local callback = self.interrupt_callback
	if callback then
		self.interrupt_callback = false
		self:Interrupt(unpack_params(callback))
	end
end

function Unit:EndInterruptableMovement()
	self.interruptable = false
end

function Unit:IsEnemyPresent()
	if g_Combat then
		return true
	end
	local dlg = GetInGameInterfaceModeDlg()
	if dlg and dlg:HasMember("teams") then
		for i, t in ipairs(dlg.teams) do
			if not t.player_ally then
				return true
			end
		end
	end
	return false
end

function Unit:GetVoxelSnapPos(pos, angle, stance)
	pos = pos or self:GetPos()
	if not pos or not pos:IsValid() then
		return
	end
	stance = stance or self.stance
	local face_pos = pos + RotateRadius(const.SlabSizeX, angle or self:GetAngle(), pos)
	pos = SnapToPassSlabSegment(pos, face_pos, const.TunnelMaskWalk)
	if not pos then
		return
	elseif stance == "Prone" then
		local prone_angle = FindProneAngle(self, pos, angle)
		return pos, prone_angle
	end
	return pos, angle or self:GetAngle()
end

function Unit:GetGridCoords()
	local x, y, z = self:GetPosXYZ()
	return PosToGridCoords(x, y, z)
end

function PosToGridCoords(x, y, z)
	z = z or terrain.GetHeight(x, y)
	local gx, gy, gz = WorldToVoxel(x, y, z)
	
	while true do
		local wx, wy, wz = VoxelToWorld(gx, gy, gz)
		if wz < z then
			gz = gz + 1
		else
			break
		end
	end	
	return gx, gy, gz
end

function Unit:EnterCombat()
	local wasInterruptable = self.interruptable
	if wasInterruptable then
		self:EndInterruptableMovement()
	end
	self:UninterruptableGoto(self:GetVisualPos()) -- stop on the nearest free slab
	self:SetTargetDummyFromPos()
	self:UpdateAttachedWeapons()
	
	if HasPerk(self, "SharpInstincts") then
		if self.stance == "Standing" then self:DoChangeStance("Crouch") end
		self:ApplyTempHitPoints(CharacterEffectDefs.SharpInstincts:ResolveValue("tempHP"))
	end
	
	if self:HasStatusEffect("ManningEmplacement") and self == SelectedObj then
		self:FlushCombatCache()
		self:RecalcUIActions(true)
		ObjModified("combat_bar")
	end
	Msg("UnitEnterCombat", self)
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
end

function Unit:AutoReload()
	local weapon = self:GetActiveWeapons("Firearm")
	local weapons = self:GetEquippedWeapons(self.current_weapon, "Firearm")
	local needs_reload
	local i = 1
	while not needs_reload and (i <= #weapons) do
		local w = weapons[i]
		if w and (w.ammo and w.ammo.Amount or 0) < w.MagazineSize then
			weapon = w
			needs_reload = true
			break
		end
		for slot, sub in sorted_pairs(weapons[i].subweapons) do
			if IsKindOf(sub, "Firearm") then
				weapons[#weapons + 1] = sub
			end
		end
		i = i + 1
	end
	
	--if weapon and (weapon.ammo and weapon.ammo.Amount or 0) < weapon.MagazineSize then
	if needs_reload then
		Sleep(self:Random(1000))
		local _, err = CombatActions.Reload:GetUIState({self})
		if err == AttackDisableReasons.NoAmmo then
			if not weapon.ammo or weapon.ammo.Amount == 0 then
				PlayVoiceResponse(self, "NoAmmo")
			else
				PlayVoiceResponse(self, "AmmoLow")
			end
		else
			RunCombatAction("ReloadMultiSelection", self, 0, {reload_all = true})
		end
	end
end

function Unit:ExitCombat()
	if self:IsNPC() and not self.dummy and (not self:IsDead() or self.immortal) then
		if self.retreating then
			local markers = MapGetMarkers("Entrance")
			local nearest, dist
			for _, marker in ipairs(markers) do
				local d = self:GetDist(marker)
				if not nearest or d < dist then
					nearest, dist = marker, d
				end
			end
			assert(nearest)
			self:SetCommand("ExitMap", nearest)
		end
	end
	
	self.ActionPoints = self:GetMaxActionPoints() -- reset AP so the units has all their actions available to initiate combat

	if self:IsDowned() then
		self:SetCommand("DownedRally")
	elseif not self:IsDead() then
		self:PushDestructor(function()
			self:AutoReload()
		end)
		
		self:LeaveEmplacement(false, "exit combat")

		if self.combat_behavior == "Bandage" then
			self:EndCombatBandage(nil, "instant")
		elseif self.behavior == "Bandage" then
			self:SetBehavior()
		end
		
		if g_Pindown[self] then
			self:InterruptPreparedAttack()
		end

		if self:IsNPC() then
			if self.spawner then
				local x, y, z = self:GetGridCoords()
				local sx, sy, sz = PosToGridCoords(self.spawner:GetPosXYZ())
				if x == sx and y == sy and z == sz then
					local spawner_angle = self.spawner:GetAngle()
					self:SetAngle(spawner_angle)
				end
			end
		end
		
		if self:IsMerc() then 
			local allEnemies = GetAllEnemyUnits(self)
			local aliveEnemies = 0
			for _, enemy in ipairs(allEnemies) do 
				if not enemy:IsDead() and not enemy:IsDefeatedVillain() then
					aliveEnemies = aliveEnemies + 1
				end
			end
			if aliveEnemies == 0 then 
				self:DoChangeStance("Standing")
			end
		elseif self.species == "Human" and self.stance ~= "Standing" then
			self:DoChangeStance("Standing")
		end
		
		self:PopAndCallDestructor()
		
		if self:IsIdleCommand() then
			self:SetCommand("Idle") -- force restart to reevaluate the use of combat/civilian anims
		end
		self:UpdateAttachedWeapons()
	elseif self.immortal then
		self:ReviveOnHealth()
		self:ChangeStance(false, 0, "Standing")
		self:SetCommand("Idle")
	end
end

function Unit:GetStepActionFX()
	return self.is_moving and (self.move_step_fx or "StepRun") or "StepWalk"
end

function Unit:OnAnimMoment(moment, anim)
	anim = anim or GetStateName(self)
	
	-- Some animations play gendered fx. In them the actor is substituted by the unit gender.
	-- Try to play those before falling back to default Unit as actor.
	local couldBeGendered = not self.fx_actor_class and moment == "start"
	local animFxName = FXAnimToAction(anim)
	local fxTarget = self.anim_moment_fx_target or nil
	if not couldBeGendered or not PlayFX(animFxName, moment, self.gender, fxTarget) then
		PlayFX(animFxName, moment, self, fxTarget)
	end

	local anim_moments_hook = self.anim_moments_hook
	if type(anim_moments_hook) == "table" and anim_moments_hook[moment] then
		local method = moment_hooks[moment]
		return self[method](self, anim)
	end
end

-- behaviors
function Unit:GetCommandParam(name, command)
	command = command or self.command
	return self.command_specific_params and self.command_specific_params[command] and self.command_specific_params[command][name]
end

function Unit:GetCommandParamsTbl(command)
	command = command or self.command
	self.command_specific_params = self.command_specific_params or {}
	self.command_specific_params[command] = self.command_specific_params[command] or {}
	return self.command_specific_params[command]
end

function Unit:SetCommandParamValue(command, param, value)
	local param_tbl = self:GetCommandParamsTbl(command)
	param_tbl[param] = value
end

function Unit:SetCommandParams(command, params)
	command = command or self.command
	self.command_specific_params = self.command_specific_params or {}
	if params then
		self.command_specific_params[command] = params
		if params.weapon_anim_prefix then
			self:UpdateAttachedWeapons()
		end
	end
end

local idle_commands = {
	[false] = true,
	["Idle"] = true,
	["IdleSuspicious"] = true,
	["AimIdle"] = true,
	["PreparedAttackIdle"] = true,
	["PreparedBombardIdle"] = true,
	["Dead"] = true,
	["VillainDefeat"] = true,
	["Hang"] = true,
	["Downed"] = true,
	["Cower"] = true,
	["CombatBandage"] = true,
	["ExitMap"] = true,
	["OverheardConversationHeadTo"] = true
}

local prepared_attacks = {
	OverwatchAction = true,
	PinDown = true,
}

function Unit:IsUsingPreparedAttack()
	return prepared_attacks[self.combat_behavior]
end

function Unit:IsIdleCommand(check_pending)
	return idle_commands[self.command or false] and (not check_pending or (not self.pending_aware_state and not HasCombatActionInProgress(self)))
end

function Unit:HasQueuedAction()
	local action = CombatActions[self.queued_action_id]
	return action and (action.ActivePauseBehavior == "queue") and IsActivePaused()
end

function Unit:Idle()
	assert(self:IsValidPos())
	NetUpdateHash("sync loading state", GameState.sync_loading)
	SetCombatActionState(self, nil)
	self.being_interacted_with = false
	if not self.move_attack_in_progress then
		self.move_attack_target = nil
	end	
	self:SetQueuedAction()
	ExplorationClearExclusiveAction(self)

	if self:IsDead() then
		if self.behavior == "Despawn" then
			self:SetCommand("Despawn")
		elseif self.behavior ~= "Hang" and self.behavior ~= "Dead" then
			self:SetBehavior("Dead")
			self:SetCombatBehavior("Dead")
		end
	else
		if self.stance == "Prone" and self:GetValidStance("Prone") ~= "Prone" then
			self:DoChangeStance("Crouch")
		end
		if g_Combat and self:CanCower() and (self.team.side == "neutral" or self:HasStatusEffect("ForceCower")) and not g_Combat:ShouldEndCombat() then
			self:SetCommand("Cower")
		end
	end
	self:UpdateInWaterFX()

	if self:IsDead() then
		if self.behavior == "Hang" then
			self:SetCommand("Hang")
		else
			assert(not self.Squad or IsMerc(self))
			self:SetCommand("Dead")
		end
	elseif self:HasStatusEffect("Unconscious") then
		self:SetCommand("Downed")
	elseif IsSetpieceActor(self) then
		self:SetCommand("SetpieceIdle", true)
	elseif self:HasStatusEffect("Suspicious") then
		if g_Combat then
			self:RemoveStatusEffect("Suspicious")
		else
			return self:SuspiciousRoutine()
		end
	elseif self:HasCommandsInQueue() then
		return
	elseif g_Combat and self.combat_behavior then
		self:SetCommand(self.combat_behavior, table.unpack(self.combat_behavior_params or empty_table))
	elseif not g_Combat and self.behavior and not self:HasStatusEffect("Suspicious") then
		local enemy = self:GetCommandParam("idle_forcing_dist")
		if not IsValid(enemy) or not self:IdleForcingDist(enemy) then
			self:SetCommandParamValue(self.command, "idle_forcing_dist", nil)
			self:SetCommand(self.behavior, table.unpack(self.behavior_params or empty_table))
		end
	end

	-- setup target dummy
	local anim_style = self:GetIdleStyle()
	local base_idle = anim_style and anim_style:GetMainAnim() or self:GetIdleBaseAnim()
	local can_reposition = not (g_Combat and self:IsAware()) -- if large units can change angle (occupied tiles)
	local pos, orientation_angle
	if self.return_pos and not self.play_sequential_actions then
		pos = self.return_pos
		local voxel = SnapToVoxel(self)
		if not pos:Equal2D(voxel) then
			orientation_angle = CalcOrientation(pos, voxel)
		end
	else
		pos = GetPassSlab(self) or self:GetPos()
	end
	local dummy_orientation_angle = self:GetPosOrientation(pos, nil, self.stance, true, can_reposition)
	if not orientation_angle then
		orientation_angle = self.auto_face and dummy_orientation_angle or self:GetPosOrientation(pos, nil, self.stance, false, can_reposition)
	end
	self:SetTargetDummy(pos, dummy_orientation_angle, base_idle, 0)

	if g_Combat and (not self:IsNPC() or self:IsAware()) then
		Msg("Idle", self)
	end
	if self.aim_action_id and not HasCombatActionInProgress(self) then
		self:SetCommand("AimIdle")
	end
	self:SetWeaponLightFx(false)
	self:SetIK("AimIK", false)
	if self.play_sequential_actions then
		self:SetCommand("SequentialActionsIdle")
	end

	-- orient
	self:EndInterruptableMovement()
	self:PlayTransitionAnims(base_idle, orientation_angle)
	self:AnimatedRotation(orientation_angle, base_idle)
	self:BeginInterruptableMovement()

	self:SetCommandParamValue("Idle", "move_anim", "WalkSlow")
	if self:ShouldBeIdle() then
		-- one animation cycle
		-- play current style end animation
		self.cur_idle_style = anim_style and anim_style.Name or nil
		if anim_style then
			local anim = self:GetStateText()
			if anim_style:HasAnimation(anim) then
				if self:GetAnimPhase() ~= 0 and not self:IsAnimEnd() then
					Sleep(self:TimeToAnimEnd())
				end
			elseif anim == anim_style.Start then
				Sleep(self:TimeToAnimEnd())
			elseif (anim_style.Start or "") ~= "" and IsValidAnim(self, anim_style.Start) then
				self:SetState(anim_style.Start, const.eKeepComponentTargets)
				Sleep(self:TimeToAnimEnd())
			end
			self:SetState(anim_style:GetRandomAnim(self), const.eKeepComponentTargets)
		else
			if self:GetAnimPhase(1) == 0 or self:IsAnimEnd() or not IsAnimVariant(self:GetStateText(), base_idle) then
				self:SetRandomAnim(base_idle, const.eKeepComponentTargets, nil, true)
			end
		end
		Sleep(self:TimeToAnimEnd())
	else
		self:IdleRoutine()
	end
end

function Unit:IdleSuspicious()
	if self.stance == "Standing" and self.species == "Human" then
		local anim
		if self.gender == "Male" then
			anim = self:TryGetActionAnim("IdlePassive2", self.stance)
		else
			local weapon = self:GetWeaponAnimPrefix()
			if weapon == "nw" or self.carry_flare then
				anim = self:TryGetActionAnim("IdlePassive", self.stance)				
			elseif weapon == "mk" then
				anim = self:TryGetActionAnim("IdlePassive6", self.stance)
			else
				anim = self:TryGetActionAnim("IdlePassive2", self.stance)
			end
		end
		if self.carry_flare then
			anim = string.gsub(anim, "^%a*_", "nw_")
		end
		anim = self:ModifyWeaponAnim(anim)
		self:SetState(anim)
		Sleep(self:TimeToAnimEnd())
	end
	self:SetCommand("Idle")
end

function Unit:TakeSlabExploration()
	local pos, angle = self:GetVoxelSnapPos()
	if not pos then
		return
	end
	local vx, vy = SnapToVoxel(self:GetVisualPosXYZ())
	if not pos:Equal2D(vx, vy) then
		self:Goto(pos, "sl")
		pos, angle = self:GetVoxelSnapPos()
	end
	self:SetPos(pos)
	self:SetOrientationAngle(angle)
end

function OnMsg.GatherFXMoments(list)
	table.insert_unique(list, "start")
	table.insert_unique(list, "end")
	table.insert(list, "action_start")
	table.insert(list, "action_end")
	table.insert(list, "WeaponGripStart")
	table.insert(list, "WeaponGripEnd")
	table.insert(list, "OrientationStart")
	table.insert(list, "OrientationEnd")
end

function Unit:OnMomentWeaponGripStart()
	self:SetWeaponGrip(true)
end

function Unit:OnMomentWeaponGripEnd()
	self:SetWeaponGrip(false)
end

function Unit:SequentialActionsStart()
	self.play_sequential_actions = true
end

function Unit:SequentialActionsEnd()
	if not self.play_sequential_actions then
		return
	end
	self.play_sequential_actions = false
	if self.command == "SequentialActionsIdle" then
		self:SetCommand("Idle")
	end
end

function Unit:SequentialActionsIdle()
	Halt()
end

function Unit:ReturnToCover(prefix)
	local pos = self.return_pos
	if not pos then
		return false
	end
	if not IsCloser(self, pos, const.SlabSizeX/2) and CanOccupy(self, pos) and IsPassSlabStep(self, pos) then
		local voxel = SnapToVoxel(self)
		local angle = pos:Equal2D(voxel) and self:GetAngle() or CalcOrientation(pos, voxel)
		self:SetTargetDummyFromPos(pos, angle)
		local side = AngleDiff(self:GetVisualOrientationAngle(), angle) < 0 and "Left" or "Right"
		prefix = prefix or string.match(self:GetStateText(), "^(%a+_).*") or self:GetWeaponAnimPrefix()
		local anim = string.format("%s%s_Aim_End", prefix, side)
		self:SetIK("AimIK", false)
		self:SetFootPlant(true)
		if IsValidAnim(self, anim) then
			if self:CanQuickPlayInCombat() then
				self:SetPos(pos)
				self:SetOrientationAngle(angle)
			else
				anim = self:ModifyWeaponAnim(anim)
				self:SetPos(pos, self:GetAnimDuration(anim))
				self:RotateAnim(angle, anim)
			end
		else
			local msg = string.format('Missing animation "%s" for "%s"', anim, self.unitdatadef_id)
			StoreErrorSource(self, msg)
			self:SetPos(pos)
			self:SetOrientationAngle(angle)
		end
	end
	self.return_pos = false
	return true
end

function Unit:MovePlayAnimSpeedUpdate(anim, anim_flags, crossfade, dest)
	self:SetState(anim, anim_flags or 0, crossfade or -1)
	repeat
		self:SetAnimSpeed(1, self:CalcMoveSpeedModifier())
		local t = self:TimeToAnimEnd()
		if dest then
			self:SetPos(dest, t)
		end
	until not WaitWakeup(t)
end

function Unit:MovePlayAnim(anim, pos1, pos2, anim_flags, crossfade, ground_orient, angle, start_offset, end_offset, sleep_mod, acceleration)
	if not anim or not self:HasState(anim) then
		self:SetPos(pos2)
		self:SetFootPlant(true)
		return
	end
	if not angle then
		if pos1:Equal2D(pos2) then
			angle = self:GetAngle()
		else
			angle = CalcOrientation(pos1, pos2)
		end
	end
	if not pos1:IsValidZ() then
		pos1 = pos1:SetTerrainZ()
	end
	local pos2_3d = pos2:IsValidZ() and pos2 or pos2:SetTerrainZ()
	local t = self:GetVisualDist(pos1) == 0 and 100 or 0
	self:SetPos(pos1)
	self:SetFootPlant(false, t)
	self:SetOrientationAngle(angle, t)
	-- animation movement can be scaled only between "start" and "end" moments
	self:SetState(anim, anim_flags or const.eKeepComponentTargets, crossfade or -1)

	local anim_full_step = GetEntityStepVector(self:GetEntity(), anim)
	local use_animation_step = pos1 ~= pos2_3d and anim_full_step:Len() > 10*guic
	local duration = GetAnimDuration(self:GetEntity(), anim)
	local phase1 = self:GetAnimMoment(anim, "start") or 0
	local phase2 = self:GetAnimMoment(anim, "end")
	if not phase2 then
		local hit = self:GetAnimMoment(anim, "hit")
		phase2 = (hit or duration) - 200
	end
	if phase2 < phase1 then
		phase2 = phase1
	end
	start_offset = start_offset or point30
	end_offset = end_offset or point30

	if phase1 > 0 then
		-- [0 - action_start] - adjust the unit at proper action start position
		local action_phase1 = self:GetAnimMoment(anim, "action_start")
		if action_phase1 then
			action_phase1 = Min(action_phase1, phase1)
		else
			action_phase1 = phase1 / 2
		end
		if action_phase1 > 0 then
			local v = use_animation_step and self:GetStepVector(anim, angle, 0, action_phase1) or point30
			local dest = pos1 + v + start_offset
			local t = self:TimeToPhase(1, action_phase1) or 0
			self:SetPos(dest, t)
			Sleep(t)
		end
		-- [action_start - start scale] - play the animation as it is
		local v = use_animation_step and self:GetStepVector(anim, angle, 0, phase1) or point30
		local dest = pos1 + v + start_offset
		local t = self:TimeToPhase(1, phase1) or 0
		self:SetPos(dest, t)
		Sleep(t)
	end

	-- [scale] - the unit should reach the proper end position at the proper phase2 (the unit should be in the air)
	local v = use_animation_step and self:GetStepVector(anim, angle, phase2, duration - phase2) or point30
	local phase2_pos = pos2_3d - v + end_offset
	local t = phase2 > phase1 and self:TimeToPhase(1, phase2) or 0

	if t == 0 then
		self:SetPos(phase2_pos)
		if ground_orient then
			self:SetGroundOrientation(angle, t)
		end
	else
		local anim_speed, new_anim_speed
		if use_animation_step and self:IsCommandThread() then
			local extra_step_z = pos2_3d:z() - (pos1:z() + anim_full_step:z())
			local scale = 1000
			if anim_full_step:Len2D() > abs(anim_full_step:z()) then
				-- horizontal scale
				local extra_dist_2d = pos1:Dist2D(pos2) - anim_full_step:Len2D()
				if extra_dist_2d > const.SlabSizeX/4 then
					local anim_dist2d = abs(self:GetStepVector(anim, 0, phase1, phase2 - phase1):x())
					scale = anim_dist2d > 0 and MulDivRound(1000, anim_dist2d + extra_dist_2d, anim_dist2d) or 1000000
					scale = Min(scale, 1500) -- fix bugged animations with vely small steps
				end
				local fall_time = extra_step_z < 0 and self:GetGravityFallTime(abs(pos2_3d:z() - pos1:z()), -4000, const.Combat.Gravity) or 0
				if fall_time > phase2 - phase1 then
					scale = Max(scale, MulDivRound(1000, fall_time, phase2 - phase1))
				end
			else
				if extra_step_z < 0 and anim_full_step:z() <= -const.SlabSizeZ/2 then
				-- vertical scale
					scale = MulDivRound(1000, pos2_3d:z() - pos1:z(), anim_full_step:z())
				end
			end
			if scale ~= 1000 then
				anim_speed = self:GetAnimSpeed(1)
				new_anim_speed = MulDivRound(anim_speed, 1000, scale)
				self:SetAnimSpeed(1, new_anim_speed)
				t = self:TimeToPhase(1, phase2) or 0
			end
		end
		local acc = acceleration and self:GetAccelerationAndStartSpeed(phase2_pos, 0, t) or 0
		self:SetAcceleration(acc)
		self:SetPos(phase2_pos, t)
		if ground_orient then
			self:SetGroundOrientation(angle, t)
		end
		if acceleration or anim_speed then
			self:PushDestructor(function(self)
				if IsValid(self) then
					self:SetAcceleration(0)
					if anim_speed and self:GetAnimSpeed(1) == new_anim_speed then
						self:SetAnimSpeed(1, anim_speed)
					end
				end
			end)
		end
		Sleep(t)
		if acceleration or anim_speed then
			self:PopAndCallDestructor()
		end
	end

	-- [end scale - action end] - play the animation as it is
	local action_phase2 = self:GetAnimMoment(anim, "action_end")
	if action_phase2 then
		action_phase2 = Max(action_phase2, phase2)
	else
		action_phase2 =  phase2
	end
	if action_phase2 > phase2 then
		local v = self:GetStepVector(anim, angle, action_phase2, duration - action_phase2)
		local dest = pos2_3d - v + end_offset
		local t = self:TimeToPhase(1, action_phase2) or 0
		self:SetPos(dest, t)
		Sleep(t)
	end

	-- [action end - animation end] - reach pos2 to the animation end
	t = self:TimeToAnimEnd()
	if t >= 999999999 then
		assert(t < 999999999) -- can happen using editor
		t = 0
	end
	if sleep_mod then t = MulDivRound(t, sleep_mod, 100) end
	self:SetPos(pos2_3d, t)
	Sleep(t)
	self:SetPos(pos2)
	self:SetFootPlant(true)
end

function Unit:CanFaceEnemy(enemy)
	return not (enemy:IsDead() or enemy:IsDowned() or enemy:HasStatusEffect("Hidden"))
end

function Unit:IsConsideredEnemy(unit)
	if self:IsOnEnemySide(unit) then return true end
	for _, groupname in ipairs(self.Groups) do
		local group_modifiers = gv_AITargetModifiers[groupname]
		for group, _ in pairs(group_modifiers) do
			if table.find(unit.Groups, group) then
				return true
			end
		end
	end
end

function Unit:GetClosestEnemy(pos)
	if not IsValid(self) then return end
	pos = SnapToVoxel(pos or self)
	local face_targets = {}
	local threshold = const.SlabSizeX / 2
	local closest_enemy, min_dist
	-- check directly visible enemies
	local visibility = g_Visibility[self]
	for _, unit in ipairs(visibility) do
		if IsValid(unit) and (not min_dist or IsCloser(unit, pos, min_dist)) then
			local enemy = self:IsConsideredEnemy(unit)
			if IsValidTarget(unit) and enemy and self:CanFaceEnemy(unit) then
				table.insert(face_targets, unit)
				local dist = unit:GetDist(pos)
				if not closest_enemy or dist < min_dist then
					closest_enemy = unit
					min_dist = dist + threshold
				end
			end
		end
	end
	if not closest_enemy then
		return
	end
	if #face_targets > 1 then
		-- prefer targets closer to our current facing
		local cur_angle = self:GetAngle()
		local closest_adiff = abs(AngleDiff(CalcOrientation(pos, closest_enemy), cur_angle))
		for _, unit in ipairs(face_targets) do
			if unit ~= closest_enemy and IsCloser(unit, pos, min_dist) then
				local adiff = abs(AngleDiff(CalcOrientation(pos, unit), cur_angle))
				if adiff < closest_adiff then
					closest_enemy = unit
					closest_adiff = adiff
				end
			end
		end
	end
	return closest_enemy
end

function Unit:IsUsingCover()
	local cover = GetHighestCover(self)	
	return cover and (cover == 2 or cover == 1 and self.stance ~= "Standing")
end

function Unit:GetCoverToClosestEnemy(pos)
	pos = pos or self:GetVoxelSnapPos()
	if not pos or not pos:IsValid() then
		return
	end
	local enemies = table.copy(GetEnemies(self))
	local closest_enemy, closest_angle, closest_face_target, closest_dist
	local ow_target = self:GetOverwatchTarget()
	
	-- check for script-driven enemy relations
	for _, groupname in ipairs(self.Groups) do
		local group_modifiers = gv_AITargetModifiers[groupname]
		for target_group, mod in pairs(group_modifiers) do
			for _, obj in ipairs(Groups[target_group]) do
				if IsKindOf(obj, "Unit") then
					table.insert_unique(enemies, obj)
				end
			end
		end
	end	

	local function update_closest(check_pos, angle)
		for _, enemy in ipairs(enemies) do
			local dist = IsValid(enemy) and enemy:GetDist(check_pos)
			if dist and (not closest_dist or dist < closest_dist) then
				closest_enemy = enemy
				closest_dist = dist
				closest_angle = angle
				closest_face_target = check_pos
			end
		end
	end

	local covers
	if self:IsEnemyPresent() then
		covers = GetCoversAt(pos)
	end

	if not next(covers) then
		if ow_target then
			return false, ow_target
		end
		if #enemies == 0 then
			-- no covers, no enemies - nothing to face
			return
		else
			-- no covers - face the closest enemy
			update_closest(pos or self:GetPos())
			return false, closest_enemy
		end
	end

	local covers_count = table.count(covers)
	if covers_count == 1 then
		-- single cover only - face it no matter the enemies
		local angle, cover = next(covers)
		return cover, pos + GetCoverOffset(angle)
	end

	-- multiple covers
	if #enemies == 0 then
		local angle, cover = next(covers)	-- for now choose the 1st cover
		return cover, pos + GetCoverOffset(angle)
	end

	-- multiple covers, enemies around - choose the cover which center has the closest enemy
	for angle, cover in sorted_pairs(covers) do
		local cover_center = pos + GetCoverOffset(angle)
		update_closest(cover_center, angle)
	end
	local cover = covers[(closest_angle + 180*60) % (360*60)]

	return cover, closest_face_target
end

function Unit:GetPosOrientation(pos, angle, stance, auto_face, can_reposition)
	if not pos then
		pos = GetPassSlab(self) or self:GetPos()
	end
	if not pos:IsValid() then
		return 0
	end
	local bandage_target = self:GetBandageTarget()

	if not angle then
		 -- subsequent calls of self:GetOrientationAngle() can lead to small rotation
		angle = self:GetVisualOrientationAngle()
		if self.last_orientation_angle and abs(AngleDiff(angle, self.last_orientation_angle)) < 5*60 then
			angle = self.last_orientation_angle
		end
	end
	stance = stance or self.stance
	if self:HasStatusEffect("ManningEmplacement") then
		auto_face = false
	elseif IsValid(bandage_target) then
		auto_face = true
	end
	if auto_face == nil then
		auto_face = self.auto_face
	end

	-- face the nearest enemy and orient to high cover
	if g_Combat
		and auto_face
		and self:IsAware()
		and not self:HasStatusEffect("Exposed")
	then
		local to_face = IsValid(bandage_target) and bandage_target or self:GetClosestEnemy(pos)
		if to_face then
			angle = CalcOrientation(pos, to_face.return_pos or to_face)
		end
		if self.species == "Human" and (stance == "Standing" or stance == "Crouch") and GetHighestCover(pos) == const.CoverHigh then
			local face_angle
			if to_face then
				-- face the cover attack step out position
				local action = self:GetDefaultAttackAction("ranged")
				if action and action.AimType ~= "melee" then
					local lof_args = {
						action_id = action.id,
						obj = self,
						step_pos = pos,
						stance = "Standing",
						aimIK = false,
						prediction = true,
					}
					local lof_data = CheckLOF(to_face, lof_args)
					if lof_data and not IsCloser2D(pos, lof_data.step_pos, const.SlabSizeX/2) then
						face_angle = CalcOrientation(pos, lof_data.step_pos)
					end
				end
			end
			if not face_angle then
				face_angle = GetUnitOrientationToHighCover(pos, angle)
			end
			if face_angle then
				angle = face_angle
			end
		end
	end

	-- adjust angle of lying units to not collide with other units or environment
	if self.body_type == "Large animal" then
		local can_reposition = can_reposition ~= false or not self:IsEqualPos(pos)
		local snap_angle, fallback = FindLargeUnitAngle(self, pos, angle, can_reposition)
		angle = snap_angle or fallback or angle
	elseif self.species == "Human" and stance == "Prone" then
		angle = FindProneAngle(self, pos, angle)
	end
	return angle
end

function Unit:SetTargetDummyFromPos(pos, angle, can_reposition)
	pos = pos or GetPassSlab(self) or self:GetPos()
	if not pos:IsValid() or self:IsDead() then
		return self:SetTargetDummy(false)
	end
	local orientation_angle = self:GetPosOrientation(pos, angle, self.stance, true, can_reposition)
	local anim_style = GetAnimationStyle(self, self.cur_idle_style)
	local base_idle = anim_style and anim_style:GetMainAnim() or self:GetIdleBaseAnim()
	return self:SetTargetDummy(pos, orientation_angle, base_idle, 0)
end

function Unit:SetTargetDummy(pos, orientation_angle, anim, phase, stance, ground_orient)
	local dummy = self.target_dummy
	if dummy and dummy.locked then
		return
	end
	local changed
	if pos ~= false then
		pos = pos or GetPassSlab(self) or self:GetPos()
		--assert(CanOccupy(self, pos)) -- hit when loading savegames with units on impassable
		if not orientation_angle then
			orientation_angle = self:GetOrientationAngle()
			if self.stance == "Prone" then
				orientation_angle = FindProneAngle(self, nil, orientation_angle, 60*60)
			end
		end
		anim = anim or self:GetStateText()
		phase = phase or self:GetAnimPhase()
		stance = stance or self.stance
		if ground_orient == nil then
			ground_orient = select(2, self:GetFootPlantPosProps(stance))
		end
		if not dummy then
			if self.body_type == "Large animal" then
				dummy = PlaceObject("TargetDummyLargeAnimal", { obj = self })
			else
				dummy = PlaceObject("TargetDummy", { obj = self })
			end
			self.target_dummy = dummy
			changed = changed or "uninit"
		end
		-- pos
		if changed or not dummy:IsEqualPos(pos) then
			dummy:SetPos(pos)
			changed = changed or "pos"
		end
		-- animation / phase
		if changed or dummy:GetStateText() ~= anim then
			dummy:SetState(anim)
			dummy:SetAnimSpeed(1, 0)
			changed = changed or "animation"
		end
		if changed or dummy:GetAnimPhase() ~= phase then
			dummy:SetAnimPhase(1, phase)
			changed = changed or "phase"
		end
		-- orientation
		local prev_angle, prev_axisx, prev_axisy, prev_axisz
		if not changed then
			prev_angle, prev_axisx, prev_axisy, prev_axisz = dummy:GetAngle(), dummy:GetVisualAxisXYZ()
		end
		if dummy.stance ~= stance then
			dummy.stance = stance
			changed = changed or "stance"
		end
		if ground_orient then
			dummy:ChangePathFlags(const.pfmGroundOrient)
			dummy:SetGroundOrientation(orientation_angle, 0)
		else
			dummy:ChangePathFlags(0, const.pfmGroundOrient)
			dummy:SetAxisAngle(axis_z, orientation_angle)
		end
		if not changed then
			local new_angle, new_axisx, new_axisy, new_axisz = dummy:GetAngle(), dummy:GetVisualAxisXYZ()
			if new_angle ~= prev_angle or new_axisx ~= prev_axisx or new_axisy ~= prev_axisy or new_axisz ~= prev_axisz then
				changed = true
			end
		end
		dummy:ClearEnumFlags(const.efResting)
		-- notify changed
	elseif dummy then
		changed = true
		DoneObject(dummy)
		self.target_dummy = false
	end
	if changed then
		Msg("TargetDummiesChanged", self)
		return true
	end
	return false
end

function Unit:GenerateTargetDummiesFromPath(path)
	path = path or self.combat_path
	local dummies = {}
	local base_idle = self:GetIdleBaseAnim(self.stance)

	local function AddDummyPos(pos, angle, insert_idx, last_step_pos)
		if pos ~= last_step_pos then
			table.insert(dummies, { obj = self, anim = base_idle, phase = 0, pos = pos, angle = angle, stance = self.stance, insert_idx = insert_idx })
		end
	end

	local p1 = self:GetPos()
	local angle = self:GetOrientationAngle()
	local dummy = self.target_dummy
	if dummy and dummy:GetPos() == p1 then
		table.insert(dummies, { obj = self, anim = dummy:GetStateText(), phase = dummy:GetAnimPhase(1), pos = dummy:GetPos(), angle = dummy:GetAngle(), insert_idx = #path + 1 })
	else
		AddDummyPos(p1, angle)
	end
	for i = #path, 1, -1 do
		local p0 = p1
		p1 = point(point_unpack(path[i]))
		if p0 ~= p1 then
			if not p0:Equal2D(p1) then
				angle = CalcOrientation(p0, p1)
			end
			local tunnel = pf.GetTunnel(p0, p1)
			if not tunnel then
				ForEachWalkStep(p0, p1, AddDummyPos, angle, i + 1, p1)
			end
			AddDummyPos(p1, angle)
		end
	end
	return dummies
end

function Unit:IsOnEnemySide(other)
	return self.team and other.team and band(self.team.enemy_mask, other.team.team_mask) ~= 0
end

function Unit:IsOnAllySide(other)
	return self.team and other.team and band(self.team.ally_mask, other.team.team_mask) ~= 0
end

function Unit:IsPlayerAlly()
	return self.team and self.team.player_ally
end

function Unit:ReportStatusEffectsInLog()
	--return not (self.team and self.team.side == "neutral")
	return const.DbgStatusEffects and not (self.team and self.team.side == "neutral")
end

local visibility_spots = {
	"Head", "Neck", --head
	"Shoulderl", "Shoulderr", --torso
	"Ribsupperl", "Ribsupperr",
	"Ribslowerl", "Ribslowerr",
	"Pelvisl", "Pelvisr",
	"Groin", --groin
	"Shoulderl", "Shoulderr", --arms
	"Elbowl", "Elbowr",
	"Wristl", "Wristr",
	"Kneel", "Kneer", --legs
	"Anklel", "Ankler",
}
local visibility_spot_indices = {}
function Unit:GetVisibilitySpotIndices()
	local entity = self:GetEntity()
	local current_state = self:GetState()
	
	local states = visibility_spot_indices[entity]
	local indices = states and states[current_state]
	
	if not indices then
		states = states or { }
		visibility_spot_indices[entity] = states
		
		indices = { }
		local n = 1
		for i=1,#visibility_spots do
			local spot_name = visibility_spots[i]
			local first, last = GetSpotRange(entity, 0, spot_name)
			for idx=first,last do
				indices[n] = idx
				n = n + 1
			end
		end
		states[current_state] = indices
	end
	
	return indices or empty_table
end

function Unit:IsNPC()
	local unit_data = UnitDataDefs[self.unitdatadef_id]
	return not unit_data or not unit_data.IsMercenary
end

function Unit:IsMerc()
	local unit_data = UnitDataDefs[self.unitdatadef_id]
	return unit_data and unit_data.IsMercenary
end

function Unit:IsCivilian()
	return self.team and self.team.side and self.team.side == "neutral" and self.species == "Human"
end

function Unit:GetSightRadius(other, base_sight, step_pos)
	-- base sight radius, based on awareness (in-combat only) and illumination	
	local modifier = 100
	local hidden = IsKindOf(other, "Unit") and other:HasStatusEffect("Hidden")
	local sight = base_sight or ((self:IsAware() and not hidden) and const.Combat.AwareSightRange or const.Combat.UnawareSightRange)
	local night_time = GameState.Night or GameState.Underground
	
	if IsIlluminated(other, nil, nil, step_pos) then
		night_time = false
	end
	local distracted = self:HasStatusEffect("Distracted") and (not IsKindOf(other, "Unit") or (self.team ~= other.team))
	
	if distracted or self:HasStatusEffect("Blinded") then
		return MulDivRound(sight, const.Combat.SightModMinValue, 100) * const.SlabSizeX, hidden, night_time
	elseif self:HasStatusEffect("Suspicious") then
		modifier = modifier + (self:GetEffectValue("suspicious_sight_mod") or 0)
	elseif not self:IsAware() and self:HasStatusEffect("HighAlert") then
		modifier = modifier + (CharacterEffectDefs.Suspicious:ResolveValue("sight_modifier_max") or 0)
	end
	
	if IsKindOf(other, "Unit") and not other:IsDead() and not other:IsDowned() then
		if hidden then
			-- add (clamped) attrib difference as modifier
			local steath_mod = Max(0, MulDivRound(other.Agility - self.Wisdom, const.Combat.SightModStealthStatDiff, 100))		
			if other.stance == "Prone" then
				steath_mod = steath_mod + const.Combat.SightModHiddenProne
			end
			local perk = other:GetStatusEffect("Stealthy")
			if perk then
				steath_mod = steath_mod + perk:ResolveValue("stealthy_detection")
			end					
			modifier = modifier - steath_mod
		end
		if HasPerk(other, "NaturalCamouflage") then
			modifier = modifier + CharacterEffectDefs.NaturalCamouflage:ResolveValue("sight_mod")
		end
		local armor = other:GetItemInSlot("Torso", "Armor")
		if armor and armor.Camouflage then
			modifier = modifier - const.Combat.CamoSightPenalty
		end
	end
	
	
	-- environmental factors
	local env_factors = other and GetVoxelStealthParams(step_pos or other) or 0
	if band(env_factors, const.vsFlagTallGrass) ~= 0 then
		modifier = modifier + const.EnvEffects.BrushSightMod
	end	
	if night_time and other then
		local darknessMod = const.EnvEffects.DarknessSightMod
		if self:HasNightVision() then
			local penaltyReduce = CharacterEffectDefs.NightOps:ResolveValue("night_vision_penalty_reduction")
			darknessMod = MulDivRound(darknessMod, penaltyReduce, 100)
		end
		modifier = modifier + darknessMod
	end	
	if GameState.Fog then
		modifier = modifier + const.EnvEffects.FogSightMod
	end
	if GameState.DustStorm then
		modifier = modifier + const.EnvEffects.DustStormSightMod
	end
	if GameState.FireStorm then
		modifier = modifier + const.EnvEffects.FireStormSightMod
	end
	if IsKindOf(other, "Unit") then	-- height difference check
		local ox, oy, oz
		if step_pos then
			ox, oy, oz = PosToGridCoords(step_pos:xyz())
		else
			ox, oy, oz = other:GetGridCoords()
		end
		local x, y, z = self:GetGridCoords()
		if oz >= z + const.EnvEffects.SightHeightDiffThreshold then
			modifier = modifier + const.EnvEffects.SightHeightDiffMod
		elseif g_Exploration and oz + const.EnvEffects.SightHeightDiffThreshold < z  then
			modifier = modifier + -(const.EnvEffects.SightHeightDiffMod * 2)
		end
	end
	
	modifier = Clamp(modifier, const.Combat.SightModMinValue, const.Combat.SightModMaxValue)
	
	local sightAmount = MulDivRound(sight, modifier, 100) * const.SlabSizeX
	
	-- Prevent going in and out of sus state due to Pos/VisualPos differences.
	if self.command == "IdleSuspicious" then
		sightAmount = sightAmount + const.SlabSizeX / 4
	end
	
	return sightAmount, hidden, night_time
end

function Unit:CanSee(other, overridePos, overrideStance)
	local sight = self:GetSightRadius(other)
	local target = other
	if IsKindOf(other, "Unit") and other.visibility_override then
		target = stance_pos_pack(other.visibility_override.pos, StancesList[other.stance])
	elseif IsPoint(overridePos) then
		self = stance_pos_pack(overridePos, StancesList[overrideStance or self.stance])
	end
	if CheckLOS(target, self, sight) then
		return true
	end
	return false
end

function Unit:Face(...)
	if self.ground_orient then
		self:SetGroundOrientation(...)
	else
		CObject.Face(self, ...)
	end
end

function Unit:SetOrientationAngle(angle, ...)
	if self.ground_orient then
		self:SetGroundOrientation(angle, ...)
		self.last_orientation_angle = angle
	else
		CObject.SetAngle(self, angle, ...)
		self.last_orientation_angle = nil
	end
end

function Unit:GetOccupiedPos()
	return self.target_dummy and self.target_dummy:GetPos()
end

function Unit:GetVisualVoxels(pos, stance, voxels)
	local x, y, z 
	voxels = voxels or {}
	if pos then
		if type(pos) == "number" then
			x, y, z = point_unpack(pos)
		elseif IsPoint(pos) and pos:IsValid() then
			x, y, z = pos:xyz()
		else
			return voxels
		end
	else
		if not self:IsValidPos() then
			return voxels
		end
		x, y, z = self:GetPosXYZ()
	end
	if not z then
		z = terrain.GetHeight(x, y)
	end
	local snapped_z = select(3, VoxelToWorld(WorldToVoxel(x, y, z)))
	if z - snapped_z > const.SlabSizeZ / 2 then
		z = z + const.SlabSizeZ
	end
	x, y, z = WorldToVoxel(x, y, z)
	voxels[1] = point_pack(x, y, z)
	local head_voxel
	if self.species == "Human" then
		if (stance or self.stance) == "Prone" then
			head_voxel = voxels[1]
		else
			head_voxel = point_pack(x, y, z + 1)
			voxels[#voxels + 1] = head_voxel
		end
	elseif self.species == "Crocodile" then
		local angle = self:GetOrientationAngle()
		local sina, cosa = sincos(angle)
		local slabsize = const.SlabSizeX
		local dx = MulDivRound(slabsize, cosa, 4096)
		local dy = MulDivRound(slabsize, sina, 4096)
		if dx > slabsize/2 then dx = 1 elseif dx < -slabsize/2 then dx = -1 end
		if dy > slabsize/2 then dy = 1 elseif dy < -slabsize/2 then dy = -1 end
		voxels[#voxels + 1] = point_pack(x + dx, y + dy, z)
		voxels[#voxels + 1] = point_pack(x - dx, y - dy, z)
	end
	return voxels, head_voxel or voxels[1]
end

function Unit:ChangeStance(action_id, cost_ap, stance, args)
	if self.stance == stance then
		return
	end
	if self.species ~= "Human" then
		return
	end
	local pfclass = CalcPFClass(self.team and self.team.side, stance, self.body_type)
	local pos = GetPassSlab(self, pfclass)
	if not pos then
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return
	end
	self:SetPos(pos)
	local wasInterruptable = self.interruptable
	if wasInterruptable then
		self:EndInterruptableMovement()
	end
	PlayFX("ChangeStance", "start", self)
	self:PushDestructor(function(self)
		PlayFX("ChangeStance", "end", self)
	end)
	local angle = args and args.angle
	if stance == "Prone" then
		angle = FindProneAngle(self, nil, angle)
	end
	if angle then
		self:SetOrientationAngle(angle, 100)
	end
	self:DoChangeStance(stance)
	self:PopAndCallDestructor() -- FX
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
end

local AnimationStance = {
	nw_Standing_MortarIdle = "Crouch",
	nw_Standing_MortarFire = "Crouch",
}

function Unit:GetHitStance()
	return AnimationStance[self:GetStateText()] or self.stance
end

function Unit:CanStealth(stance)
	if not self.team or self.team.side == "neutral"
		or not self:IsValidPos()
		or self:IsDead()
		or self:IsDowned()
		or self.command == "ExitCombat" and not self:HasStatusEffect("Hidden")
	then
		return false
	end
	stance = stance or self.stance
	local is_stealthy_stance
	if self.species == "Human" then
		is_stealthy_stance = stance ~= "Standing"
		if HasPerk(self, "FleetingShadow") then
			is_stealthy_stance = true
		end
	elseif self.species == "Crocodile" then
		is_stealthy_stance = true
	end
	if not is_stealthy_stance then
		return false
	end
	
	-- in combat allow Spotted units to remain Hidden for the duration of the effect
	local effects = self.StatusEffects
	local visual_contact = self.enemy_visual_contact
	if g_Combat and effects.Spotted then 
		visual_contact = false
	elseif not self:HasStatusEffect("Hidden") then
		local enemies = GetAllEnemyUnits(self)
		for _, enemy in ipairs(enemies) do
			visual_contact = visual_contact or HasVisibilityTo(enemy, self)
		end
	end
	if visual_contact then
		return false
	end
	if effects.BandagingDowned or effects.Revealed or effects.StationedMachineGun or effects.ManningEmplacement then
		return false
	end
	return true
end

function Unit:GetStanceToStealth(stance)
	stance = stance or self.stance
	if self.species == "Human" and stance == "Standing" and not HasPerk(self, "FleetingShadow") then
		return "Crouch"
	end
	return stance
end

function Unit:Hide()
	local stance = self:GetStanceToStealth()
	if not self:CanStealth(stance) then return end
	local wasInterruptable
	if stance ~= self.stance then
		wasInterruptable = self.interruptable
		if wasInterruptable then
			self:EndInterruptableMovement()
		end
		self:DoChangeStance(stance)
	end
	self:AddStatusEffect("Hidden")
	self:UpdateMoveAnim()
	PlayVoiceResponse(self, "BecomeHidden")
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
end

function Unit:Unhide()
	self.goto_hide = false
	self.goto_stance = false
	--self.marked_target_attack_args = false
	self:RemoveStatusEffect("Hidden")
	self:UpdateMoveAnim()
	if self:IsInterruptable() then
		self:BeginInterruptableMovement()
	end
end

function Unit:CanTakeCover()
	return self.species == "Human" and self.stance ~= "Prone" and (GetHighestCover(self.return_pos or self) or 0) > 0
end

function Unit:TakeCover()
	if not self:CanTakeCover() then
		return
	end
	self:InterruptPreparedAttack()
	self:AddStatusEffect("Protected")
	UpdateTakeCoverAction()
	self:DoChangeStance("Crouch")

	ObjModified(self)
end

function OnMsg.UnitAnyMovementStart(unit)
	unit:RemoveStatusEffect("Protected")
	UpdateTakeCoverAction()
end

function OnMsg.UnitStanceChanged(unit)
	if unit.stance ~= "Crouch" then
		unit:RemoveStatusEffect("Protected")
	end
end

local sneak_ui_update_thread = false

function OnMsg.UnitStealthChanged(obj)
	if obj == SelectedObj or table.find(Selection or empty_table, obj) then
		sneak_ui_update_thread = sneak_ui_update_thread or CreateGameTimeThread(function()
			while obj.command == "ExitCombat" do
				Sleep(100)
			end
		
			ObjModified("combat_bar")
			sneak_ui_update_thread = false
		end)
	end
end

function Unit:UpdateHidden()
	if self:HasStatusEffect("Hidden") then
		if not self:CanStealth() then
			self:RemoveStatusEffect("Hidden")
			self:UpdateFXClass()
		end
	elseif self.species ~= "Human" then
		if self:CanStealth() then
			self:AddStatusEffect("Hidden")
			PlayVoiceResponse(self, "BecomeHidden")
			self:UpdateFXClass()
		end
	end
end

-- used to control the fx actor class of the unit based on his Hidden status and self.visible
function Unit:UpdateFXClass()
	if not self.visible then
		self.fx_actor_class = "Hidden"
	elseif IsMerc(self) then
		self.fx_actor_class = "ImportantUnit"
	elseif self.species ~= "Human" then
		self.fx_actor_class = self.species
	elseif self:IsAmbientUnit() then
		self.fx_actor_class = "AmbientUnit"
	else
		self.fx_actor_class = nil
	end
end

function OnMsg.GetCustomFXInheritActorRules(rules)
	rules[#rules + 1] = "ImportantUnit"
	rules[#rules + 1] = "Unit"
end

local function UpdateHiddenUnits()
	for _, team in ipairs(g_Teams) do
		if team.side ~= "neutral" then
			for _, unit in ipairs(team.units) do
				unit:UpdateHidden()
			end
		end
	end
end

function OnMsg.UnitMovementDone(obj)
	if GameState.sync_loading then return end
	obj:RemoveStatusEffect("Focused")
	UpdateHiddenUnits()
	NetUpdateHash("UnitMovement", obj, obj:GetPosXYZ())
end

OnMsg.SyncLoadingDone = UpdateHiddenUnits
OnMsg.ExplorationStart = UpdateHiddenUnits

function Unit:GotoChangeStance(stance)
	if not stance or self.stance == stance then
		return
	end
	if not self:CanSwitchStance(stance) then
		return
	end
	local prev_stance = self.stance
	self.stance = stance
	ObjModified(self)
	self:UpdateMoveAnim()
	self:ChangePathFlags(const.pfDirty)
	self:UpdateHidden()
	ObjModified(self)
	if stance == "Prone" or prev_stance == "Prone" then
		local base_idle = self:GetIdleBaseAnim()
		PlayTransitionAnims(self, base_idle)
	end
	Msg("UnitStanceChanged", self)
end

function Unit:DoChangeStance(stance)
	assert(self.species == "Human" or stance == "")
	self.stance = HasPerk(self, "ZombiePerk") and "Standing" or stance
	self.aim_results = false
	self.aim_attack_args = false
	ObjModified(self)
	self:SetFootPlant(true)
	self:SetTargetDummyFromPos()
	self:UpdateMoveAnim()
	local base_idle = self:GetIdleBaseAnim()
	local angle = (self.target_dummy or self):GetAngle()
	PlayTransitionAnims(self, base_idle, angle)
	if not g_Combat and self.command ~= "ExitCombat" and self.command ~= "TakeCover" then
		self:GotoSlab(self:GetPos())
	end
	self:UpdateHidden()
	ObjModified(self)
	Msg("UnitStanceChanged", self)
end

local stance_to_stance_def
function FindStanceToStanceDef(start_stance, end_stance)
	stance_to_stance_def = nil
	ForEachPresetInGroup("StanceToStanceAP", "Default", function(def, group, start_stance, end_stance)
		if def.start_stance == start_stance and def.end_stance == end_stance then
			stance_to_stance_def = def
		end
	end, start_stance, end_stance)
	return stance_to_stance_def
end

function GetStanceToStanceAP(start_stance, end_stance)
	if start_stance == end_stance then
		return 0
	end
	local def = FindStanceToStanceDef(start_stance, end_stance)
	if def then
		return def.ap_cost
	end
end

function Unit:GetStanceToStanceAP(stance, ownStanceOverride)
	local currentStance = ownStanceOverride or self.stance
	if stance == currentStance then 
		return -1 
	end
	
	if HasPerk(self, "HitTheDeck") and stance == "Prone" then return 0 end
	
	return GetStanceToStanceAP(currentStance, stance) or 0	
end

function Unit:GetArchetype()	
	local arch = Archetypes[self.script_archetype]
	if arch then
		return arch
	end
	return Archetypes[self.current_archetype] or Archetypes.Soldier
end

function Unit:GetCurrentArchetype()
	return Archetypes[self.current_archetype] or Archetypes.Soldier
end

-- equipped items wihtout weapons, like Grenade, Medicine...
function Unit:GetEquippedQuickItems(class, slot_name)
	local items = {}
	self:ForEachItemInSlot(slot_name,class,function(item, s, l,t, items)
		if not item:IsWeapon() then
			items[#items+1] = item
		end	
	end, items)
	return items
end

function Unit:GetActiveWeapons(class, strict_order)
	if class == "UnarmedWeapon" then
		self.unarmed_weapon = self.unarmed_weapon or g_UnarmedWeapon
		return self.unarmed_weapon, nil, { self.unarmed_weapon }
	end

	if self:GetStatusEffect("ManningEmplacement") then
		local handle = self:GetEffectValue("hmg_emplacement")
		local obj = HandleToObject[handle]
		if obj and obj.weapon and (not class or IsKindOf(obj.weapon, class)) then
			obj.weapon.emplacement_weapon = true
			return obj.weapon, nil, { obj.weapon }
		end
	end

	self.combat_cache = self.combat_cache or {}
	local key = string.format("active_weapons_%s%s", class or "all", strict_order and "-strict" or "")
	local weapons = self.combat_cache[key]
	if not weapons then
		weapons = {}
		local firearms = {}
		self.combat_cache[key] = weapons
		local equipped 
		if IsSetpiecePlaying() and IsSetpieceActor(self) then
			equipped = self:GetEquippedWeapons("SetpieceWeapon")
		end
		if not equipped or #equipped == 0 then
			equipped = self:GetEquippedWeapons(self.current_weapon)
		end		
		for _, o in ipairs(equipped) do
			local match = not class or (class ~= "Firearm") or not IsKindOfClasses(o, "HeavyWeapon", "FlareGun")
			match = match and (not class or IsKindOf(o, class))
			if match then
				table.insert(weapons, o)
			end
			if IsKindOf(o, "FirearmBase") then
				table.insert(firearms, o)
			end
		end		
		-- second pass to add subweapons at the end of the list
		for _, item in ipairs(firearms) do
			for slot, weapon in sorted_pairs(item.subweapons) do
				local match = not class or (class ~= "Firearm") or not IsKindOfClasses(weapon, "HeavyWeapon", "FlareGun")
				match = match and (not class or IsKindOf(weapon, class))
				if match then
					table.insert(weapons, weapon)
				end
			end
		end
	end
	
	-- If weapon1 is exhausted and weapon 2 isnt then weapon2 is the main weapon
	if not strict_order then
		local weapon1Exhausted = not self:CanUseWeapon(weapons[1])
		local weapon2Exhausted = not self:CanUseWeapon(weapons[2])
		local weapon2IsntSubWeapon = weapons[1] and weapons[2] and not weapons[2].parent_weapon
		if weapons[1] and weapons[2] and weapon1Exhausted and not weapon2Exhausted and weapon2IsntSubWeapon then
			weapons[1], weapons[2] = weapons[2], weapons[1]
		end
	end
	
	return weapons[1], weapons[2], weapons
end

function FindWeaponInSlotById(unit, slot, item_id)
	local weapons = unit:GetEquippedWeapons(slot)
	for _, weapon in ipairs(weapons) do
		if weapon.id == item_id then 
			return weapon
		end
		if IsKindOf(weapon, "Firearm") then
			for slot, sub in sorted_pairs(weapon.subweapons) do
				if sub.id == item_id then
					return sub
				end
			end
		end
	end
end

function UnitProperties:GetWeaponByDefIdOrDefault(class, def_id, packed_pos, item_id)
	if packed_pos then
		local weapon = self:GetItemAtPackedPos(packed_pos)
		return weapon
	else	
		local weapons = self:GetEquippedWeapons(self.current_weapon)
		local alt_slot = self.current_weapon == "Handheld A" and "Handheld B" or "Handheld A"
		table.iappend(weapons, self:GetEquippedWeapons(alt_slot))
		table.iappend(weapons, self:GetEquippedWeapons("Inventory"))
		local n = #weapons
		for i = 1, n do
			local weapon = weapons[i]
			if IsKindOf(weapon, "FirearmBase") then
				for _, sub in sorted_pairs(weapon.subweapons) do
					weapons[#weapons + 1] = sub
				end
			end
		end
		local matched
		if def_id then
			matched = table.ifilter(weapons, function(idx, item) return IsKindOf(item, def_id) end)
		end
		if #(matched or empty_table) == 0 then
			matched = weapons
		end
		if item_id then
			for _, weapon in ipairs(matched) do
				if weapon.id == item_id then
					return weapon
				end
			end
		end
		return matched[1]
	end
end

function Unit:OutOfAmmo(weapon, amount)
	weapon = weapon or self:GetActiveWeapons()
	return weapon and weapon:HasMember("ammo") and (not weapon.ammo or weapon.ammo.Amount < (amount or 1))
end

function Unit:GetSector()
	return gv_Sectors[gv_CurrentSectorId]
end

function Unit:IsWeaponJammed(weapon)
	weapon = weapon or self:GetActiveWeapons()
	return IsKindOf(weapon, "Firearm") and weapon.jammed
end

function Unit:CanUseWeapon(weapon, num_shots)
	if not weapon then
		return false, AttackDisableReasons.NoWeapon
	elseif weapon.Condition <= 0 then
		return false, AttackDisableReasons.WeaponBroken
	end
	if IsKindOf(weapon, "Firearm") then
		if weapon.jammed then
			return false, AttackDisableReasons.WeaponJammed
		elseif not weapon.ammo or weapon.ammo.Amount < (num_shots or 1) then
			return false, AttackDisableReasons.OutOfAmmo
		end
	end
	return true
end

AttackDisableReasons = {
	NoAP = T(526265371339, "<error>Insufficient AP</error>"),
	NoWeapon = T(379423324402, "<error>No active weapon</error>"),
	WeaponJammed = T(522229430242, "<error>The weapon is jammed</error>"),
	WeaponBroken = T(187856566334, "<error>The weapon is broken</error>"),
	OutOfAmmo = T(694516627561, "<error>Out of ammo</error>"),
	InsufficientAmmo = T(48284763278, "<error>Not enough ammo</error>"),
	InvalidTarget = T(332327094836, "<error>Invalid target</error>"),
	InvalidSelfTarget = T(858041242091, "<error>Cannot target self</error>"),
	NoTeamSight = T(308212362965, "<error>Out of team sight</error>"),
	NoTeamSightLivewire = T(316258123370, "<error>Out of sight (Livewire)</error>"),
	NoTarget = T(282471750002, "<error>No target</error>"),
	NoBandageTarget = T(409300745676, "<error>No target. Mercs with lowered max HP are healed in the Sat View.</error>"),
	OutOfRange = T(460146513440, "<error>Out Of Range</error>"),
	ExtremeRange = T(990882650338, "<error>Extreme range</error>"),
	CantReach = T(533577783995, "<error>Can't reach</error>"),
	NoLoS = T(871138850086, "<error>No line of sight</error>"),
	InsufficientMeds = T(589775173410, "<error>Not enough Meds</error>"),
	FullHP = T(270490338639, "<error>At full health</error>"),
	NoLockpick = T(179588362502, "<error>Can't pick a lock without a lockpick</error>"),
	NoCrowbar = T(871669664824, "<error>You need a crowbar to attempt to break this</error>"),
	NoCutters = T(457726671611, "<error>You need a wire cutter.</error>"),
	OnlyStanding = T(589960103330, "<error>Only available in Standing stance</error>"),
	Cooldown = T(591766545566, "<error>This action can be used once per turn</error>"),
	BandagingDowned = T(216477918933, "<error>Currently treating a downed ally</error>"),
	NoAmmo = T(958927508781, "<error>Out of ammo for this weapon</error>"),
	FullClip = T(342527613232, "<error>This weapon is already fully loaded</error>"),
	FullClipHaveOther = T(193803534966, "<error>This weapon is already fully loaded. You can change the ammo type from the inventory.</error>"),
	SignatureRecharge = T(422255119652, "<error>Can only be used once per conflict</error>"),
	SignatureRechargeOnKill = T(895217484195, "<error>Recharges on kill with another attack.</error>"),
	Water = T(389919921473, "<error>Not allowed in water</error>"),
	Stairs = T(377843918366, "<error>Not allowed on stairs</error>"),
	Impassable = T(150460717914, "<error>Impassable</error>"),
	Occupied = T(173250243531, "<error>Occupied</error>"),
	Indoors = T(927774491188, "<error>Cannot use indoors</error>"),
	InEnemySight = T(749326574456, "<error>You cannot sneak while in enemy sight.</error>"),
	Revealed = T(393250883796, "<error>You revealed yourself to the enemies and cannot sneak this turn.</error>"),
	CannotSneak = T(637272145762, "<error>You cannot sneak at this time.</error>"),
	WrongWeapon = T(734977105577, "<error>Wrong active weapon.</error>"),
	RangedWeapon = T(464635588615, "<error>Requires a Firearm.</error>"),
	MacheteWeapon = T(899395755721, "<error>Requires a Machete.</error>"),
	KnifeWeapon = T(270404087675, "<error>Requires a Knife.</error>"),
	CombatOnly = T(607543203128, "<error>Must be used during combat</error>"), 
	RequiresMachineGun = T(293921437394, "<error>Requires a Machine Gun</error>"), 
	RequiresUnarmed = T(252038182681, "<error>Must be Unarmed</error>"),
	NotInCover = T(553368221470, "<error>Only available in cover spots</error>"),
	AlreadyActive = T(492570194020, "Already active"),
	NotInMeleeRange = T(863084049025, "<error>Approach to attack</error>"),
	NotInBandageRange = T(576945352567, "<error>Approach to bandage</error>"),
	NotSneaking = T(465045630742, "<error>Must be sneaking</error>"),
	MinDist =  T(753745088840, "<error>Too close</error>"),
	NoLine =  T(127026985840, "<error>Straight path required</error>"),
	TooFar = T(137552442717, "<error>Too Far</error>"),
	UsingMachineGun = T(504207281345, "<error>Currently operating a machine gun</error>"),
	NoFireArc = T(698332993342, "<error>No fire arc</error>"),
}

function GetUnitNoApReason(unit)
	if unit:GetBandageTarget() then
		return AttackDisableReasons.BandagingDowned
	end
	return AttackDisableReasons.NoAP
end

function Unit:SetEffectValue(id, value)
	self.effect_values = self.effect_values or {}
	self.effect_values[id] = value
end

function Unit:GetEffectValue(id)
	return self.effect_values and self.effect_values[id]
end

function Unit:GetEffectExpirationTurn(id, key)
	local store_key = string.format("%s:%s", id, key)
	return self.effect_values and self.effect_values[store_key] or -1
end

function Unit:SetEffectExpirationTurn(id, key, turn)
	local store_key = string.format("%s:%s", id, key)
	self.effect_values = self.effect_values or {}
	self.effect_values[store_key] = Max(turn, self.effect_values[store_key] or -1)
end

function Unit:CanAttack(target, weapon, action, aim, goto_pos, skip_ap_check, is_free_aim)
	if GetInGameInterfaceMode() == "IModeDeployment" then
		return false
	end
	if action.ActionType ~= "Melee Attack" and action.ActionType ~= "Ranged Attack" then 
		return false
	end
	local args
	if action then
		if action.ActionType == "Melee Attack" and target == self then
			return false, AttackDisableReasons.InvalidSelfTarget
		end
		if (action.ActionType == "Melee Attack" and action.AimType ~= "melee-charge") and IsValid(target) then
			if IsKindOf(target.traverse_tunnel, "SlabTunnelLadder") then
				return false, AttackDisableReasons.InvalidTarget
			end
			if not IsMeleeRangeTarget(self, goto_pos, nil, target) then
				local attack_pos = self:GetClosestMeleeRangePos(target)
				if not attack_pos or (IsKindOf(target, "Unit") and not IsMeleeRangeTarget(self, attack_pos, nil, target)) then
					return false, AttackDisableReasons.CantReach
				end
				local reason = g_Combat and AttackDisableReasons.CantReach or AttackDisableReasons.TooFar
				--[[if attack_pos then
					local cpath = GetCombatPath(self)
					local ap = cpath and cpath:GetAP(attack_pos)
					if ap and action:GetAPCost(self, args) <= self.ActionPoints - ap then
						reason = AttackDisableReasons.NotInMeleeRange
					end
				end
				return false, reason--]]
				if attack_pos then
					--local cpath = GetCombatPath(self)
					--local ap = cpath and cpath:GetAP(attack_pos)
					--if not ap or action:GetAPCost(self, args) > self.ActionPoints - ap then
					args = args or { target = target, goto_pos = goto_pos, aim = aim, ap_cost_breakdown = {} }
					local cost = action:GetAPCost(self, args)
					if cost < 0 or cost > self.ActionPoints then
						return false, reason
					end
				else
					return false, reason
				end
			end
		end
		if action.ActionType == "Ranged Attack" and target == self then -- no
			return false, AttackDisableReasons.InvalidTarget
		end
		if action.id == "UnarmedAttack" or action.id == "ExplodingPalm" or (action.id == "Brutalize" and not weapon) or action.id == "MarkTarget" then
			weapon = self:GetActiveWeapons("UnarmedWeapon")
		end
		if action.group == "SignatureAbilities" then
			local recharge = self:GetSignatureRecharge(action.id)
			if recharge then
				if recharge.on_kill then
					return false, AttackDisableReasons.SignatureRechargeOnKill
				end
				return false, AttackDisableReasons.SignatureRecharge
			end
		end
		if g_Combat and self:GetEffectExpirationTurn(action.id, "cooldown") >= g_Combat.current_turn then
			return false, AttackDisableReasons.Cooldown
		elseif not skip_ap_check and (g_Combat or g_StartingCombat or g_TestingSaveLoadSystem) then
			args = args or { target = target, goto_pos = goto_pos, aim = aim, ap_cost_breakdown = {} }
			local cost = action:GetAPCost(self, args)
			if not self:HasAP(cost, action.id, args) then
				return false, GetUnitNoApReason(self)
			end
		end
		if action.id == "OnMyTarget" then
			return true
		elseif action.id == "MGBurstFire" then
			if target and not CombatActionTargetFilters.MGBurstFire(target, {self}) then
				return false, AttackDisableReasons.OutOfRange
			end
		elseif action.id == "Bombard" or action.id == "FireFlare" then
			if self.indoors then
				return false, AttackDisableReasons.Indoors
			end
		elseif action.id == "PinDown" then
			if not CombatActionTargetFilters.Pindown(target, self, weapon) then
				return false, AttackDisableReasons.InvalidTarget
			end
		end
	end

	if not weapon then
		return false, AttackDisableReasons.NoWeapon
	elseif (weapon.Condition or 100) <= 0 then
		return false, AttackDisableReasons.WeaponBroken
	end

	if IsKindOf(weapon, "Grenade") or (IsKindOf(weapon, "HeavyWeapon") and weapon.trajectory_type == "parabola") then
		if action and target then
			local range = action:GetMaxAimRange(self, weapon)
			if goto_pos then
				if goto_pos:Dist(target) > range * const.SlabSizeX then
					return false, AttackDisableReasons.OutOfRange
				end 
			else
				if self:GetDist(target) > range * const.SlabSizeX then
					return false, AttackDisableReasons.OutOfRange
				end
			end

			args = args or { target = target, goto_pos = goto_pos, aim = aim, ap_cost_breakdown = {} }
			local results = action:GetActionResults(self, args)
			if not results.trajectory or #results.trajectory == 0 then
				return false, AttackDisableReasons.NoFireArc
			end
		end
		return true
	end

	local fireArm = IsKindOf(weapon, "Firearm")
	if fireArm and weapon.jammed then
		return false, AttackDisableReasons.WeaponJammed
	end

	local ammo_amount = fireArm and weapon:GetAutofireShots(action) or 1
	local min_ammo_amount = action:ResolveValue("min_shots")
	if fireArm and not ammo_amount then
		local params = weapon:GetAreaAttackParams(action.id, self)
		ammo_amount = params and params.used_ammo
	end
	ammo_amount = Min(ammo_amount or 1, min_ammo_amount or ammo_amount or 1)
	if action.ActionType ~= "Other" and self:OutOfAmmo(weapon, ammo_amount) then -- Non-attack actions dont require ammo
		return false, AttackDisableReasons.OutOfAmmo
	end

	if IsKindOf(weapon, "MeleeWeapon") and action.ActionType == "Ranged Attack" and target then
		local range = action:GetMaxAimRange(self, weapon)
		local attack_pos = goto_pos or self:GetPos()
		local target_pos = IsPoint(target) and target or target:GetPos()
		if attack_pos:Dist(target_pos) > range * const.SlabSizeX then
			return false, AttackDisableReasons.OutOfRange
		end
	end

	-- If you give me a target I will check it no matter whether you require one.
	local optionalTargetAndNoTarget = not action.RequireTargets and not target
	local invalidObjectTarget = not action.RequireTargets and not IsValid(target) and not IsPoint(target)
	local pointTarget = not action.RequireTargets and IsPoint(target)
	 
	if optionalTargetAndNoTarget or invalidObjectTarget or pointTarget then return true end
	local targetIsUnit = IsKindOf(target, "Unit")
	local targetIsTrap = IsKindOf(target, "Trap")
	local freeAimMeleeTarget = IsValid(target) and is_free_aim and action.ActionType == "Melee Attack"

	if not target and action.RequireTargets then
		return false, AttackDisableReasons.NoTarget
	end
	
	if not targetIsUnit and action.id == "Brutalize" then
		return false, AttackDisableReasons.InvalidTarget
	end

	if not targetIsUnit and not targetIsTrap and not freeAimMeleeTarget then
		return false, AttackDisableReasons.InvalidTarget
	end

	-- all attacks should be able to target all units except dead/defeated
	if targetIsUnit and (target:IsDead() or target:IsDefeatedVillain()) then
		return false, AttackDisableReasons.InvalidTarget
	end

	return true, false
end

function Unit:GetMoveModifier(stance, action_id)
	stance = stance or self.stance
	action_id = action_id or "Move"

	local modValue = 0

	local effectId = self:HasStatusEffect("Slowed")
	if effectId then
		modValue = modValue + (self.StatusEffects[effectId]:ResolveValue("move_ap_modifier") or 0)
	end

	effectId = self:HasStatusEffect("Mobile")
	if effectId and action_id == "Move" then
		modValue = modValue - (self.StatusEffects[effectId]:ResolveValue("move_ap_modifier") or 0)
	end
	
	if self:HasStatusEffect("Hidden") then
		modValue = modValue + Hidden:ResolveValue("ap_cost_modifier")
	end

	if GameState.DustStorm then
		modValue = modValue + const.EnvEffects.DustStormMoveCostMod
	end

	return modValue
end

function Unit:GetUIScaledAP()
	return self:GetUIActionPoints() / const.Scale.AP
end

function Unit:GetUIScaledAPMax()
	local max = Max(self:GetMaxActionPoints(), self:GetUIActionPoints())
	return max / const.Scale.AP
end

function Unit:GatherCTHModifications(id, value, data)
	if not id then return end
	
	data.meta_text = data.meta_text or {}
	data.mod_mul = 100
	data.mod_add = 0
	data.base_chance = value
	data.enabled = true

	Msg("GatherCTHModifications", self, id, data.action.id, data.target, data.weapon1, data.weapon2, data)
	value = data.enabled and MulDivRound(value + data.mod_add, data.mod_mul, 100) or 0
	return value
end

function Unit:CalcChanceToHit(target, action, args, chance_only)
	-- Argument validation and fallbacks
	if not (IsPoint(target) or IsValid(target) and IsKindOf(target, "CombatObject")) then
		return 0
	end
	local weapon1, weapon2 = action:GetAttackWeapons(self)
	local weapon = args and args.weapon or weapon1
	if not weapon or IsKindOf(weapon, "Medicine") then
		return 0
	end
	
	if CheatEnabled("AlwaysHit") then
		return 100
	elseif CheatEnabled("AlwaysMiss") then
		return 0
	end

	local target_spot_group = args and args.target_spot_group or nil
	if type(target_spot_group) == "table" then
		target_spot_group = target_spot_group.id
	end
	target_spot_group = target_spot_group or g_DefaultShotBodyPart
	if type(target_spot_group) == "string" then
		target_spot_group = Presets.TargetBodyPart.Default[target_spot_group]
	end

	local aim = args and args.aim or 0
	local opportunity_attack = args and args.opportunity_attack
	local attacker_pos = args and (args.step_pos or args.goto_pos) or self:GetPos()
	local target_pos = args and args.target_pos or IsPoint(target) and target or target:GetPos()

	local base = 0
	local modifiers = not chance_only and {}

	-- Base CTH
	local skill = self[weapon.base_skill]
	if action.id == "SteroidPunch" then
		skill = self["Strength"]
	end
	base = base + skill
	
	if args and not args.prediction then
		local effects = {}
		for i, effect in ipairs(self.StatusEffects) do
			effects[i] = effect.class
		end
		effects = table.concat(effects, ",")
		local target_effects = "-"
		if IsKindOf(target, "Unit") then
			target_effects = {}
			for i, effect in ipairs(target.StatusEffects) do
				target_effects[i] = effect.class
			end
			target_effects = table.concat(target_effects, ",")
		end
		NetUpdateHash("CalcChanceToHit_Base", self, target, action.id, weapon.class, weapon.id, base, effects, target_effects,
			weapon1 and weapon1.class, weapon1 and weapon1.id, weapon1 and weapon1.Condition, weapon1 and weapon1.MaxCondition,
			weapon2 and weapon2.class, weapon2 and weapon2.id, weapon2 and weapon2.Condition, weapon2 and weapon2.MaxCondition
		)
	end
	
	if modifiers then
		self.combat_cache = self.combat_cache or {}
		local key = "base_cth_" .. weapon.base_skill
		local skillmod = self.combat_cache[key]
		if not skillmod then
			local prop_meta = self:GetPropertyMetadata(weapon.base_skill)
			if prop_meta then
				skillmod =
				{
					name = prop_meta.name,
					value = skill
				}
			else
				assert(false, "weapon base skill '" .. weapon.base_skill .. "' property metadata not found!")
				skillmod =
				{
					name = T(462143455900, "Marksmanship"),
					value = skill
				}
			end
			self.combat_cache[key] = skillmod
		end
		table.insert(modifiers, skillmod)
	end

	local mod_data = {
		attacker = self,
		target = target,
		target_spot_group = target_spot_group,
		action = action, 
		weapon1 = weapon1, 
		weapon2 = weapon2, 
		aim = aim, 
		opportunity_attack = opportunity_attack, 
		attacker_pos = attacker_pos, 
		target_pos = target_pos,
	}


	-- Evaluate all modifiers
	ForEachPreset("ChanceToHitModifier", function(mod)
		if mod.RequireTarget and not IsValidTarget(target) then
			return
		end
		local req_action = mod.RequireActionType
		if req_action == "Any Attack" then
			if action.ActionType == "Other" then
				return
			end
		elseif req_action == "Any Melee Attack" then
			if action.ActionType ~= "Melee Attack" then
				return
			end
		elseif req_action == "Any Ranged Attack" then
			if action.ActionType ~= "Ranged Attack" then
				return
			end
		elseif req_action ~= action.id then
			return
		end
		
		local lof = false -- Currently unused by any modifier
		local apply, value, nameOverride, metaText, idOverride = mod:CalcValue(self, target, target_spot_group, action, weapon, weapon2, lof, aim, opportunity_attack, attacker_pos, target_pos)
		if args and not args.prediction then
			NetUpdateHash("CalcChanceToHit_Modifier", mod.id, apply, value)
		end
		if not apply then
			return
		end
		-- automated GatherCTHModifications provide a standard mechanism for replacing display name & adding meta text (only for the applicable mods)
		mod_data.display_name = nameOverride or mod.display_name
		mod_data.meta_text = (IsT(metaText) and {metaText} or metaText) or nil
		value = self:GatherCTHModifications(mod.id, value, mod_data)
		if args and not args.prediction then
			NetUpdateHash("CalcChanceToHit_Modifier_Mods", mod.id, value)
		end
		local nameOverride = mod_data.display_name
		local metaText = #mod_data.meta_text > 0 and mod_data.meta_text
		base = base + value
		if mod_data.enabled and modifiers then
			table.insert(modifiers, 
			{ 
				name = nameOverride or mod.display_name,
				value = value,
				id = idOverride or mod.id,
				metaText = metaText
			})
		end
	end)
	
	-- cycle status effects, running GatherCTHModifications() for every one of them, using the effect class/id as mod id
		-- this way status effects can implement their own cth modifiers via the same mechanism
	for _, effect in ipairs(self.StatusEffects) do
		mod_data.display_name = effect.DisplayName
		mod_data.meta_text = nil
		local value = self:GatherCTHModifications(effect.class, 0, mod_data)
		if args and not args.prediction then
			NetUpdateHash("CalcChanceToHit_Effect_Mods", effect.class, value)
		end
		if value and value ~= 0 then
			base = base + value
			if mod_data.enabled and modifiers then
				table.insert(modifiers, 
				{ 
					name = mod_data.display_name,
					value = value,
					id = effect.id,
					metaText = mod_data.meta_text
				})
			end
		end
	end
	
	-- process weaponcomponenteffects
	mod_data.weapon1 = nil
	mod_data.weapon2 = nil
	local weapons = {weapon1, weapon2}
	for _, weapon in ipairs(weapons) do
		if IsKindOf(weapon, "Firearm") then		
			for slot_id, component_id in sorted_pairs(weapon.components) do
				local def = WeaponComponents[component_id]
				local effects = def and def.ModificationEffects or empty_table
				if next(effects) ~= nil then
					mod_data.weapon1 = weapon
					mod_data.display_name = def.DisplayName
					mod_data.meta_text = nil
					local value = self:GatherCTHModifications(component_id, 0, mod_data)
					if args and not args.prediction then
						NetUpdateHash("CalcChanceToHit_Component_Mods", weapon.id, component_id, value)
					end
					if value and value ~= 0 then
						base = base + value
						if mod_data.enabled and modifiers then
							table.insert(modifiers, 
							{ 
								name = mod_data.display_name,
								value = value,
								id = component_id,
								metaText = mod_data.meta_text
							})
						end
					end
				end
			end
		end
	end
	
	base = Max(0, base)

	local target_pos = IsPoint(target) and target or target:GetPos()
	local knife_throw = IsKindOf(weapon, "MeleeWeapon") and (action.ActionType == "Ranged Attack")
	local penalty = weapon:GetAccuracy(attacker_pos:Dist(target_pos), self, action, knife_throw) - 100
	
	-- Hide lightning reactions from prediction
	if action.ActionType == "Ranged Attack" then
		if HasPerk(target, "LightningReaction") and target.stance ~= "Prone" and not target:HasStatusEffect("LightningReactionCounter") then
			if modifiers then
				modifiers[#modifiers + 1] = {
					name = T(530719772440, "Lightning Reactions"),
					value = -base,
					id = "Accuracy",
					uiHidden = true
				}
			end
			base = 0
		end
	end
	
	local final = Clamp(base + penalty, 0, 100)
	
	if HasPerk(self, "Spiritual") then
		local minAcc = CharacterEffectDefs.Spiritual:ResolveValue("minAccuracy")
		final = Clamp(final, minAcc, 100)
	end
	
	if args and not args.prediction then
		NetUpdateHash("CalcChanceToHit_Final", final)
	end
	
	if chance_only then
		return final
	end
	if penalty ~= 0 then
		if action.ActionType == "Melee Attack" then
			modifiers[#modifiers + 1] = {
				name = T(660754354729, "Weapon Accuracy"),
				value = penalty,
				id = "Accuracy"
			}
		elseif penalty <= -100 then
			modifiers[#modifiers + 1] = {
				name = T(162704513413, "Out of Range"),
				value = penalty,
				id = "Range"
			}
		else
			modifiers[#modifiers + 1] = {
				name = T(301586030557, "Range"),
				value = penalty,
				id = "Range"
			}
		end
	end
	return final, base, modifiers, penalty
end

-- unused
function Unit:GetBestChanceToHit(target, action, args, lof)
	local best_idx, best_hit_chance
	local list = attack_data.lof
	for i, hit_data in ipairs(list) do
		if i == 1 or hit_data.ally_hits_count <= list[best_idx].ally_hits_count then
			args.target_spot_group = hit_data.target_spot_group
			local hit_chance = self:CalcChanceToHit(target, action, args, "chance_only")
			if i == 1 or hit_data.ally_hits_count < list[best_idx].ally_hits_count or hit_chance > best_hit_chance then
				best_idx, best_hit_chance = i, hit_chance
			end
		end
	end
	return best_hit_chance, best_idx
end

function Unit:IsPointBlankRange(target)
	if not IsValid(target) then
		return false
	end
	return IsCloser(target, self, const.Weapons.PointBlankRange * const.SlabSizeX + 1)
end

function Unit:IsArmorPiercedBy(weapon, aim, target_spot_group, action) -- Can Crit
	local pierced = true
	if target_spot_group == "Head" then
		local helm = self:GetItemInSlot("Head")
		if helm and IsKindOf(helm, "IvanUshanka") then
			return false
		end
	end
	if action and action.id == "KalynaPerk" then
		return true, "ignored"
	end
	if action and action.ActionType == "Melee Attack" then
		return true, "ignored"
	end
	self:ForEachItem("Armor", function(item, slot)
		if slot ~= "Inventory" and item.Condition > 0 and weapon.PenetrationClass < item.PenetrationClass and (item.ProtectedBodyParts or empty_table)[target_spot_group] then
			pierced = false
			return "break"
		end
	end)
	return pierced
end

function Unit:CalcCritChance(weapon, target, aim, attack_pos, target_spot_group, action)
	if not IsKindOfClasses(weapon, "Firearm", "MeleeWeapon") then
		return 0
	end
	
	target_spot_group = target_spot_group or g_DefaultShotBodyPart
	if IsKindOf(target, "Unit") and not target:IsArmorPiercedBy(weapon, aim, target_spot_group, action) then
		return 0
	end
	local critChance = self:GetBaseCrit(weapon)
	aim = aim or 0
	local data = {
		crit_chance = critChance,
		action_id = action and action.id,
		weapon = weapon,
		aim = aim,
		crit_per_aim = const.Combat.AimCritBonus,
		target_spot_group = target_spot_group,
		guaranteed_crit = false,
		guaranteed_noncrit = false,
	}
	
	Msg("GatherCritChanceModifications", self, target, action and action.id, weapon, data)
	
	if data.guaranteed_noncrit then return 0 end
	if data.guaranteed_crit then return 100 end

	local critChance = data.crit_chance + aim * data.crit_per_aim

	local extra = GetComponentEffectValue(weapon, "CritBonusSameTarget", "bonus_crit")
	if self:GetLastAttack() == target and extra then
		critChance = critChance + extra
	end
	local extraAimed = IsFullyAimedAttack(aim) and GetComponentEffectValue(weapon, "CritBonusWhenFullyAimed", "bonus_crit")
	if extraAimed then
		critChance = critChance + extraAimed
	end

	return Clamp(critChance, 0, 100)
end

function TFormat.AimAPCost()
	local igi = GetInGameInterfaceModeDlg()
	if not igi then return -1 end
	
	local attacker = igi.attacker
	local action = igi.action
	if not action then return -1 end
	
	local weapon = action:GetAttackWeapons(attacker)
	local crosshair = igi.crosshair
	local aimLevel = crosshair and crosshair.aim or 0
	
	local actionCost, aimCost = attacker:GetAttackAPCost(action, weapon, nil, aimLevel + 1, action.ActionPointDelta)
	return aimCost / const.Scale.AP
end

function Unit:GetAttackAPCost(action, weapon, action_ap_cost, aim, delta)
	if not weapon then 
		return 0
	end
	
	local min, max = self:GetBaseAimLevelRange(action, weapon)
	aim = Clamp(aim or 0, min, max) - min -- only charge for aiming above min level
	delta = delta or 0
	local aimCost = const.Scale.AP
	if GameState.RainHeavy then
		aimCost = MulDivRound(aimCost, 100 + const.EnvEffects.RainAimingMultiplier, 100)
	end
	
	local ap = 0
	if IsKindOf(weapon, "HeavyWeapon") then
		ap = action_ap_cost or weapon.AttackAP
		if HasPerk(self, "HeavyWeaponsTraining") then
			ap = HeavyWeaponsTrainingCostMod(ap)
		end
	elseif IsKindOf(weapon, "Firearm") then
		ap = action_ap_cost or weapon.ShootAP
		if IsKindOf(weapon, "MachineGun") and HasPerk(self, "HeavyWeaponsTraining") then
			ap = HeavyWeaponsTrainingCostMod(ap)
		end
		ap = ap + aim * aimCost + delta
	elseif IsKindOf(weapon, "Grenade") then
		ap = (action_ap_cost or weapon.AttackAP) + aim * aimCost + delta
		if self:HasStatusEffect("FirstThrow") then
			local costReduction = CharacterEffectDefs.Throwing:ResolveValue("FirstThrowCostReduction") * const.Scale.AP
			ap = Max(1 * const.Scale.AP, ap - costReduction)
		end
	elseif IsKindOf(weapon, "MeleeWeapon") then
		ap = (action_ap_cost or weapon.AttackAP) + delta
		if self:HasStatusEffect("FirstThrow") and action.ActionType == "Ranged Attack" then
			local costReduction = CharacterEffectDefs.Throwing:ResolveValue("FirstThrowCostReduction") * const.Scale.AP
			ap = Max(1 * const.Scale.AP, ap - costReduction)
		end
		ap = ap + aim * aimCost
	else
		ap = -1
	end
	
	-- legal cheat: during heavy rain last possible aim costs 1 AP regardless of the penalty
	local remainingAP = (self:GetUIActionPoints() / 1000) * 1000
	if GameState.RainHeavy and ap > remainingAP and aim > 0 then 
		local diff = abs(remainingAP - ap)
		if diff < aimCost and diff >= const.Scale.AP then
			ap = remainingAP
			aimCost = 1000
		end
	end
	
	return ap, aimCost
end

function Unit:ResolveAttackParams(action_id, target, lof_params)
	local action = action_id and CombatActions[action_id]
	if action and action.AimType == "melee" then
		local attack_data = {
			obj = self,
			step_pos = self:GetOccupiedPos() or GetPassSlab(self) or self:GetPos(),
			target = target
		}
		return attack_data
	end
	lof_params = lof_params or {}
	lof_params.obj = self
	if not lof_params.action_id then
		lof_params.action_id = action_id
	end
	if lof_params.weapon == nil then
		lof_params.weapon = action and action:GetAttackWeapons(self) or false
	end
	if not lof_params.step_pos then
		lof_params.step_pos = self:GetOccupiedPos()
	end
	if lof_params.can_use_covers == nil then
		lof_params.can_use_covers = true
	end
	lof_params.prediction = true
	local attack_data = GetLoFData(self, target, lof_params)
	if not attack_data then
		attack_data = {
			obj = self,
			step_pos = self:GetOccupiedPos() or GetPassSlab(self) or self:GetPos(),
			target = target,
			stuck = true,
		}
	end
	return attack_data
end

function Unit:PrepareToAttack(attack_args, attack_results)
	if not self.visible then
		local targetIsUnit = attack_args.target and IsKindOf(attack_args.target, "Unit") and attack_args.target
		if targetIsUnit and targetIsUnit.visible then
			SnapCameraToObj(targetIsUnit, "force", GetFloorOfPos(SnapToPassSlab(targetIsUnit:GetVisualPosXYZ())))
		else
			return
		end
	end
	local showMiddle
	local dontMoveCamera, ccAttacker = StopCinematicCombatCamera()
	local updateLastUnitShoot = false
	if dontMoveCamera then updateLastUnitShoot = ccAttacker end
	local targetPos = not IsPoint(attack_args.target) and attack_args.target:GetVisualPos() or attack_args.target
	local notInGivenCommand = self.command ~= "OverwatchAction" and self.command ~= "MGSetup" and self.command ~= "MGTarget"
	local attackerPos = self:GetVisualPos()
	local isRetaliation = attack_args.opportunity_attack_type and attack_args.opportunity_attack_type == "Retaliation"
	local isAIControlled = not ActionCameraPlaying and not self:IsMerc() and g_AIExecutionController and 
		(not self.opportunity_attack or #g_CombatCamAttackStack == 0)
	local mercPlayingAsAI = self:IsMerc() and g_AIExecutionController and g_AIExecutionController.units_playing and g_AIExecutionController.units_playing[self]
	local isAIControlledMerc = not ActionCameraPlaying and (isRetaliation or attack_args.gruntyPerk or mercPlayingAsAI)
	local cameraPosChanged

	--Show attacker
	local movedToShowAttacker
	if isAIControlled or isAIControlledMerc then
		--handle camera
		if g_LastUnitToShoot ~= self and not dontMoveCamera then
			local midPoint = (attackerPos + targetPos) / 2
			local diffFloors = GetFloorOfPos(SnapToPassSlab(self)) ~= GetFloorOfPos(SnapToPassSlab(attack_args.target))
			showMiddle = not diffFloors and notInGivenCommand and DoPointsFitScreen({ attackerPos, targetPos }, midPoint, 10)
			local posToShow = showMiddle and midPoint or attackerPos
			local cameraIsNear = DoPointsFitScreen({posToShow}, nil, const.Camera.BufferSizeNoCameraMov)
			if cameraIsNear and showMiddle then
				cameraIsNear = DoPointsFitScreen({ attackerPos, targetPos }, nil, 10)
			end
			
			if not cameraIsNear then
				movedToShowAttacker = true
				SnapCameraToObj(posToShow, "force", GetFloorOfPos(SnapToPassSlab(showMiddle and targetPos or attackerPos)))
				if not self:CanQuickPlayInCombat() then Sleep(1000) end
			elseif not IsVisibleFromCamera(self) or GetFloorOfPos(SnapToPassSlab(self)) > cameraTac.GetFloor() then
				--no movement of camera should still take into account the floor
				cameraTac.SetFloor(GetFloorOfPos(SnapToPassSlab(self)), hr.CameraTacInterpolatedMovementTime * 10, hr.CameraTacInterpolatedVerticalMovementTime * 10)
			end
			updateLastUnitShoot = self
		end
	elseif not ActionCameraPlaying and self.opportunity_attack and not isRetaliation then
		movedToShowAttacker = not DoPointsFitScreen({ targetPos }, nil, const.Camera.BufferSizeNoCameraMov)
		CombatCam_ShowAttackNew(self, attack_args.target, nil, attack_results, dontMoveCamera)
	end
	
	--handle badges
	if not g_AITurnContours[self.handle] and (isAIControlled or isAIControlledMerc or (self.opportunity_attack and not isRetaliation)) then
		local enemy = self.team.side == "enemy1" or self.team.side == "enemy2" or self.team.side == "neutralEnemy"
		g_AITurnContours[self.handle] = SpawnUnitContour(self, enemy and "CombatEnemy" or "CombatAlly")
		ShowBadgeOfAttacker(self, true)
	end

	self:AimTarget(attack_args, attack_results, true)

	--delay after aim
	if not self:CanQuickPlayInCombat() and movedToShowAttacker and (g_AIExecutionController or isRetaliation or attack_args.gruntyPerk or self.opportunity_attack) then
		local delay
		local consecutiveDelay = not dontMoveCamera and g_LastUnitToShoot == self

		if dontMoveCamera then
			delay = const.Combat.ShootDelayAfterAimCinematic
		elseif consecutiveDelay then
			delay = const.Combat.ConsecutiveShootDelayAfterAim
		else
			delay = const.Combat.ShootDelayAfterAim
		end
		Sleep(delay)
	end

	self:SetTargetDummy(nil, nil, attack_args.anim, 0, attack_args.stance)

	--Show target
	if not showMiddle then cameraPosChanged = not DoPointsFitScreen({targetPos}, nil, const.Camera.BufferSizeNoCameraMov) end
	if isAIControlled and notInGivenCommand and g_LastUnitToShoot ~= self or isAIControlledMerc then
		local interrupts = self:CheckProvokeOpportunityAttacks("attack interrupt", {self.target_dummy or self})
		local targetNotVisible = showMiddle and IsKindOf(attack_args.target, "Unit") and not IsVisibleFromCamera(attack_args.target)
		CombatCam_ShowAttackNew(self, attack_args.target, interrupts, attack_results, dontMoveCamera or showMiddle, targetNotVisible)
	elseif self:IsMerc() and not ActionCameraPlaying and not g_AIExecutionController then
		--edge case where merc/player shoots but he is in overwatch so the overwatch will be shown first and then his attack
		local interrupts = self:CheckProvokeOpportunityAttacks("attack interrupt", {self.target_dummy or self})
		if interrupts then
			CombatCam_ShowAttackNew(self, attack_args.target, interrupts, attack_results)
		else
			local cameraIsNear = DoPointsFitScreen({targetPos}, nil, const.Camera.BufferSizeNoCameraMov)
			if g_Combat and attack_results.explosion and (not attack_args.action_id or attack_args.action_id ~= "Bombard") and not cameraIsNear then
				SnapCameraToObj(targetPos, nil, GetFloorOfPos(SnapToPassSlab(targetPos)), 500)
				Sleep(500)
			end
		end
	end

	--delay before shooting
	if not self:CanQuickPlayInCombat() then
		if g_AIExecutionController or isRetaliation or self.opportunity_attack then
			local delay
			local consecutiveDelay = not dontMoveCamera and g_LastUnitToShoot == self
			
			if dontMoveCamera then
				delay = const.Combat.ShootDelayCinematic
			elseif not cameraPosChanged then
				delay = const.Combat.ShootDelayTargetOnScreen
			elseif consecutiveDelay then
				delay = const.Combat.ConsecutiveShootDelay
			else
				delay = const.Combat.ShootDelay
			end
			Sleep(delay)
		elseif self.command ~= "PrepareBombard" and self.command ~= "OverwatchAction" then
			if cameraPosChanged then
				Sleep(const.Combat.ShootDelayNonAI)
			else
				Sleep(const.Combat.ShootDelayTargetOnScreen)
			end
		end
	end
	if updateLastUnitShoot then
		g_LastUnitToShoot = updateLastUnitShoot
	end
end

function Unit:CalcStealthKillChance(weapon, target, target_spot_group, aim)
	if not IsValidTarget(target) or not IsKindOf(target, "Unit") or not weapon then return 0 end

	local chance = Max(0, self.Dexterity - target.Wisdom)
	local min_chance = 1

	if HasPerk(target, "StealthKillDefense") then
		chance = chance - CharacterEffectDefs.StealthKillDefense:ResolveValue("kill_chance_mod")
	end
	if target_spot_group == "Head" or target_spot_group == "Neck" then
		chance = chance + const.Combat.HeadshotStealthKillChanceMod
	end
	if HasPerk(self, "Virtuoso") and IsFullyAimedAttack(aim) then
		chance = chance + CharacterEffectDefs.Virtuoso:ResolveValue("virtuosoStealthKillChance") 
	end
	if HasPerk(self, "Infiltrator") then
		chance = chance + CharacterEffectDefs.Infiltrator:ResolveValue("stealthkill_chance")
	end
	if HasPerk(self, "Stealthy") then
		chance = chance + CharacterEffectDefs.Stealthy:ResolveValue("stealthkill")
		min_chance = CharacterEffectDefs.Stealthy:ResolveValue("stealthkill_minchance")
	end

	local stealthKillBonus = GetComponentEffectValue(weapon, "StealthKillBonusPerAim", "stealth_kill_bonus")
	if stealthKillBonus then
		chance = chance + (aim or 0) * (stealthKillBonus or 0)
	end
	
	if target:IsAware() then
		chance = MulDivRound(chance, 75, 100)
	elseif target:HasStatusEffect("Surprised") or target:HasStatusEffect("Suspicious") then
		chance = MulDivRound(chance, Max(0, 100 + CharacterEffectDefs.Surprised:ResolveValue("stealthkill_modifier")), 100)
	end
	
	if CheatEnabled("SkillCheck") then
		chance = 100
	end
	
	local weapon_pen_class = weapon:HasMember("PenetrationClass") and weapon.PenetrationClass or 1
	local armor_class = 0
	target:ForEachItem("Armor", function(item, slot)
		if slot ~= "Inventory" and item.ProtectedBodyParts and item.ProtectedBodyParts[target_spot_group] then
			armor_class = Max(armor_class, item.PenetrationClass)
		end
	end)
	if weapon_pen_class < armor_class and chance > 0 then
		chance = chance / 2
	end
	
	chance = Clamp(chance, min_chance, 100)
	return chance
end

function Unit:PrepareAttackArgs(action_id, args)
	action_id = action_id or self:GetDefaultAttackAction("ranged")
	args = args or empty_table
	local action = CombatActions[action_id]
	local weapon = args.weapon or action and action:GetAttackWeapons(self)
	local target = args.target
	local prediction = args.prediction or args.prediction == nil
	local aim_type = action and action.AimType
	local thermal_aim = IsKindOf(weapon, "Firearm") and IsFullyAimedAttack(args) and weapon:HasComponent("IgnoreGrazingHitsWhenFullyAimed")

	local attack_args = table.copy(args)
	attack_args.action_id = action_id
	attack_args.obj = self
	attack_args.weapon = weapon
	attack_args.target_pos = attack_args.target_pos or IsPoint(target) and target
	attack_args.step_pos = attack_args.step_pos or self.return_pos or self:GetOccupiedPos() or GetPassSlab(self) or self:GetPos()
	attack_args.ignore_smoke = thermal_aim
	if attack_args.fire_relative_point_attack == nil then
		attack_args.fire_relative_point_attack = self.WeaponType == "Shotgun"
	end
	attack_args.prediction = prediction

	if aim_type ~= "melee" then
		attack_args.prediction = true
		local attack_data
		if IsPoint(target) and attack_args.target_height_range then
			if not target:IsValidZ() then
				target = target:SetTerrainZ()
			end
			local min_dist
			for h = 0, attack_args.target_height_range, guim/2 do
				local pt = target:SetZ(target:z() + h)
				local data = GetLoFData(self, pt, attack_args)
				if data then
					local dist
					for _, lof_data in ipairs(data.lof) do
						for _, hit in ipairs(lof_data.hits) do
							local d = target:Dist(hit.pos)
							if not dist or dist > d then
								dist = d
							end
						end
					end
					if dist and (not attack_data or min_dist > dist) then
						attack_data, min_dist = data, dist
					end
				end
			end
		else
			attack_data = GetLoFData(self, target, attack_args)
		end
		if attack_data then
			for k, v in pairs(attack_data) do
				attack_args[k] = v
			end
		else
			attack_args.stuck = true
		end
		attack_args.prediction = prediction
	end

	attack_args.num_shots = attack_args.num_shots or 1 -- number of direct shots (with simulated projectiles
	attack_args.aoe_action_id = attack_args.aoe_action_id or false -- defines cone area for collateral/aoe damage (as used in Firearm:GetAreaAttackParams)
	attack_args.aoe_fx_action = attack_args.aoe_fx_action or false -- fx action to play for the aoe part of the attack, if any
	attack_args.aoe_damage_type = attack_args.aoe_damage_type or "default" -- "default", "fixed" or "percent", defines how the aoe damage is calculated
	attack_args.aoe_damage_value = attack_args.aoe_damage_value or false -- when "fixed" or "percent" type is used
	attack_args.applied_status = attack_args.applied_status or false -- status effect on hit
	attack_args.damage_bonus = attack_args.damage_bonus or false -- bonus damage applied by the attack (0/false = no change, 100 = x2, -100 = x0)
	attack_args.consumed_ammo = attack_args.consumed_ammo or false -- defaults to num_shots/used_ammo (from aoe params)
	attack_args.aoe_damage_bonus = attack_args.aoe_damage_bonus or false -- same as above for collateral/aoe damage
	attack_args.cth_loss_per_shot = attack_args.cth_loss_per_shot or false -- for attacks with num_shots > 1, defines the accuracy of the follow-up shots based on the attack roll
	attack_args.fx_action = attack_args.fx_action or false -- fx action to play in the hit moment(s) of the attack anim (defaults to WeaponFire)
	attack_args.single_fx = attack_args.single_fx or false -- if set to true, attacks will not play their fx_action more than once per attack

	if weapon and aim_type == "cone" then
		local aoe_params = weapon:GetAreaAttackParams(action_id, self, attack_args.target_pos, attack_args.step_pos)
		for k, v in pairs(aoe_params) do
			attack_args[k] = v
		end
	end

	-- Stealth kill
	local is_stealth = attack_args.stealth_attack or self:HasStatusEffect("Hidden")
	local lethal_weapon = (attack_args.target_spot_group == "Neck") and IsKindOf(weapon, "MeleeWeapon") and (weapon.NeckAttackType == "lethal")
	if action and (is_stealth or lethal_weapon)  then
		local stealth_targeted = is_stealth and action.StealthAttack and IsKindOf(target, "Unit") and IsValidTarget(target)
		local stealth_aoe, chance
		if stealth_targeted or stealth_aoe then
			local crosshair = GetInGameInterfaceModeDlg().crosshair
			local aim = args.aim or (crosshair and crosshair.aim) or 0
			chance = self:CalcStealthKillChance(weapon, target, attack_args.target_spot_group, aim)
			attack_args.stealth_attack = true
		end
		if lethal_weapon then
			local lethal_chance = 5 + Max(0, (self.Strength - target.Health) / 2)
			chance = Max(chance or 0, lethal_chance)
		end
		if stealth_targeted or lethal_weapon then
			if target:IsNPC() and not target.villain then
				attack_args.stealth_kill_chance = chance
				attack_args.stealth_bonus_crit_chance = 0
			else
				attack_args.stealth_kill_chance = 0
				attack_args.stealth_bonus_crit_chance = chance
			end
		end
	end

	return attack_args
end

function Unit:StartFireAnim(shot, attack_args, aim_pos, shotAnimDelay)
	if self:CanAimIK(attack_args.weapon) then
		if not aim_pos then
			aim_pos = shot and (shot.lof_pos2 or shot.target_pos) or attack_args.target_pos
		end
		if aim_pos then
			self:SetIK("AimIK", aim_pos) -- the unit should be in aim or fire state
			if shotAnimDelay then
				Sleep(shotAnimDelay)
				shotAnimDelay = 0
			else
				Sleep(200)
			end
		end
	end
	if (shotAnimDelay or 0) > 0 then
		Sleep(shotAnimDelay)
	end
	local hit_moment = shot and shot.hit_moment or "hit" -- todo: make sure DualShot passes the correct hit moments
	local anim = self:ModifyWeaponAnim(attack_args.anim)
	self:SetState(anim, const.eKeepComponentTargets, 0)
	local time_to_hit = self:TimeToMoment(1, hit_moment)
	if time_to_hit then
		Sleep(time_to_hit)
	end
end

function Unit:GetAttackRolls(num_shots, multishot, atk_value, crit_value)
	local attack_roll, crit_roll
	if not multishot or ((num_shots or 1) <= 1) then
		attack_roll = atk_value or (1 + self:Random(100))
		crit_roll = crit_value or (1 + self:Random(100))
	else
		attack_roll, crit_roll = {}, {}
		for i = 1, num_shots do
			attack_roll[i] = atk_value or (1 + self:Random(100))
			crit_roll[i] = crit_value or (1 + self:Random(100))
		end
	end
	return attack_roll, crit_roll
end

function FXAnimToAction(anim)
	return "Anim:" .. anim
end

function FXActionToAnim(action)
	return remove_prefix(action, "Anim:") or action
end

function Unit:GetLogName()
	return self:GetDisplayName()
end

function Unit:SetAttackReason(reason, opportunity_attack)
	self.attack_reason = reason
	self.opportunity_attack = opportunity_attack
end

function Unit:GetAttackReasonText()
	return self.attack_reason and T{295729060245, "<em><name></em>: ", name = self.attack_reason} or ""
end

function Unit:GetBaseDamage(weapon, target, breakdown)
	if self.infinite_dmg then
		return 10000
	end
	weapon = weapon or self:GetActiveWeapons()
	local mod = 100
	local base_damage = 0
			
	if IsKindOf(weapon, "Firearm") then
		base_damage = weapon.Damage
		if IsValidTarget(target) and self:GetDist(target) <= weapon.WeaponRange * const.SlabSizeX / 2  then
			local damageIncrease = GetComponentEffectValue(weapon, "HalfRangeDmgIncrease", "base_dmg_bonus")
			if damageIncrease then
				base_damage = base_damage + damageIncrease
			end
		end
	elseif IsKindOf(weapon, "Grenade") then
		if IsKindOf(weapon, "ThrowableTrapItem") then
			base_damage = weapon:GetBaseDamage()
		else
			base_damage = weapon.BaseDamage
		end
		mod = 100 + GetGrenadeDamageBonus(self)
	elseif IsKindOfClasses(weapon, "MeleeWeapon", "Ordnance") then
		base_damage = weapon.BaseDamage
	end
	
	local data = { base_damage = base_damage, modifier = mod, breakdown = breakdown or {} }
	Msg("CalcBaseDamage", self, weapon, target, data)
	return MulDivRound(data.base_damage, data.modifier, 100)
end

function Unit:GodMode(mode, state)
	mode = mode or "god_mode"
	if state == nil then 
		state = true 
	end
	self[mode] = state
	if mode == "god_mode" then
		self.infinite_ap = state
		self.infinite_ammo = state
		self.infinite_dmg = state
		self.infinite_condition = state
		self.invulnerable = state
	end
	if self.infinite_ap then
		self:GainAP(self:GetMaxActionPoints())
	end
end

function Unit:ReloadAllEquipedWeapons(ammo_type)
	local reloaded
	self:ForEachItemInSlot("Handheld A", "Firearm", function(gun)
		if ammo_type or not gun.ammo or gun.ammo.Amount < gun.MagazineSize then 
			reloaded = self:ReloadWeapon(gun, ammo_type) or reloaded 
		end
	end)
	self:ForEachItemInSlot("Handheld B", "Firearm", function(gun)
		if ammo_type or not gun.ammo or gun.ammo.Amount < gun.MagazineSize then
			reloaded = self:ReloadWeapon(gun, ammo_type) or reloaded
		end
	end)
	return reloaded
end

function Unit:GetCoverPercentage(attackerPos, target_pos, stance)
	if g_Combat and self.combat_path then
		return false, false, 0 -- unit is moving in combat and does not benefit from cover
	end
	return GetCoverPercentage(target_pos or self:GetPos(), attackerPos, stance or self.stance)
end

function Unit:SetVisible(visible, force)
	visible = visible or (not force and IsSetpiecePlaying() and g_SetpieceFullVisibility)

	NetUpdateHash("Unit:SetVisible", self, visible, force, IsSetpiecePlaying(), g_SetpieceFullVisibility)

	if visible then
		if g_Exploration  and not self:IsDead() then
			if not self.visible then
				self:SetOpacity(100, 500)
			end
		else
			self:SetOpacity(100)
		end

		local hidden_parts = self.Headshot and self.species == "Human" and HeadshotHideParts
		self:SetEnumFlags(const.efVisible)
		for name, body_part in pairs(self.parts) do
			if hidden_parts and table.find(hidden_parts, name) then
				body_part:ClearEnumFlags(const.efVisible)
			else
				body_part:SetEnumFlags(const.efVisible)
			end
		end
		if self.prepared_attack_obj then
			self.prepared_attack_obj:SetEnumFlags(const.efVisible)
		end
	else
		if g_Exploration and not self:IsDead() then
			if self.visible then
				self:SetOpacity(0, 2000)
			end
		else
			self:ClearEnumFlags(const.efVisible)
			for _, body_part in pairs(self.parts) do
				body_part:ClearEnumFlags(const.efVisible)
			end
		end

		if self.prepared_attack_obj then
			self.prepared_attack_obj:ClearEnumFlags(const.efVisible)
		end
	end
	
	if self.melee_threat_contour then
		self.melee_threat_contour:SetVisible(visible)
	end
	
	if self.ui_badge then
		local badgeVisible = visible and not self:IsDead()
		self.ui_badge:SetVisible(badgeVisible, "unit")
	end
	
	if self.visible ~= visible then
		self:SetSoundMute(not visible)
		self:ForEachAttach("GrenadeVisual", function(obj) 
			obj:SetSoundMute(not visible)
		end)
		self.visible = visible
		ObjModified(self)
	end
	
	if self.carry_flare then
		self:UpdateOutfit()
	end
	
	self:UpdateFXClass()
end

function Unit:GetVisibleEnemies()
	local visible = {}
	
	if self.team then
		-- Add all enemies visible by my team.
		local team_visible = g_Visibility[self.team] or empty_table
		for _, u in ipairs(team_visible) do
			if IsValidTarget(u) and self:IsOnEnemySide(u) then
				table.insert_unique(visible, u)
			end
		end
	end
		
	return visible
end

function Unit:OnGearChanged(isLoad)
	self.using_cumbersome = false
	NetUpdateHash("CumbersomeReset", self)
	self:ForEachItem(false, function(item, slot)
		if slot ~= "Inventory" and item:IsCumbersome() then
			self.using_cumbersome = true
			NetUpdateHash("CumbersomeSet", self)
		end
		item:ApplyModifiersList(item.applied_modifiers)
	end)
	if self.using_cumbersome and not HasPerk(self, "KillingWind") then
		if self:CanUseIroncladPerk() then
			if not isLoad then
				self:ConsumeAP(DivRound(self.free_move_ap, 2), "Move")
			end
		else
			self:RemoveStatusEffect("FreeMove")
		end
	end
	Msg("UnitAPChanged", self)
	ObjModified(self)
	ObjModified(self.Inventory)
end

function Unit:CanUseIroncladPerk()
	local canUse = HasPerk(self, "Ironclad")

	if canUse then
		local weapons = self:GetHandheldItems()
		for _, weapon in ipairs(weapons) do
			if weapon:IsCumbersome() then
				canUse = false
				break
			end
		end
	end
	
	return canUse
end

local function is_attack_available(unit, action, sync)
	local can_use = action:GetUIState({unit}) == "enabled"
	if sync then
		NetUpdateHash("is_attack_available", unit, action.id, can_use)
	end
	return can_use
end

function Unit:GetDefaultAttackAction(force_ranged, force_ungrouped, weapon, sync, ignore_stealth)
	local weapon2
	if not weapon then
		weapon, weapon2 = self:GetActiveWeapons()
	end
	local id
	
	local weaponAttacks = IsKindOf(weapon, "Firearm") and not IsKindOfClasses(weapon, "HeavyWeapon", "FlareGun") and weapon.AvailableAttacks or empty_table
	local weapon2Attacks = IsKindOf(weapon2, "Firearm") and not IsKindOfClasses(weapon2, "HeavyWeapon", "FlareGun") and weapon2.AvailableAttacks or empty_table
	
	-- If stealth then always prefer single shot
	if not ignore_stealth and self:HasStatusEffect("Hidden") and (table.find(weaponAttacks, "SingleShot") or table.find(weapon2Attacks, "SingleShot")) then
		id = "SingleShot"
	end
	
	-- Check if dual shot.
	if #weaponAttacks > 0 and #weapon2Attacks > 0 then
		local dualShotAvail = table.find(weaponAttacks, "DualShot") and table.find(weapon2Attacks, "DualShot")
		id = dualShotAvail and "DualShot" or id
	end

	if IsKindOf(weapon, "MeleeWeapon") and force_ranged and weapon.CanThrow then
		id = "KnifeThrow"
	end
	if IsKindOf(weapon, "FlareGun") then
		weapon = nil
		if weapon2 and not IsKindOf(weapon2, "FlareGun") then
			weapon = weapon2
			weapon2 = nil
		end
	end
	
	if not id then
		id = weapon and weapon:GetBaseAttack(self, force_ranged) or "UnarmedAttack"
	end	
	
	local action = CombatActions[id]
	if force_ungrouped and is_attack_available(self, action, sync) then
		if sync then NetUpdateHash("GetDefaultAttackAction", self, id) end
		return action 
	end
	
	local firingMode = action and action.FiringModeMember
	if firingMode and CombatActions[firingMode]:GetUIState({self}) == "enabled" then
		if not force_ungrouped then
			if sync then NetUpdateHash("GetDefaultAttackAction", self, firingMode) end
			return CombatActions[firingMode]
		end
		local action_id = self:ResolveDefaultFiringModeAction(CombatActions[firingMode], false, sync)
		if action_id then
			return CombatActions[action_id]
		end
	end
	if sync then	NetUpdateHash("GetDefaultAttackAction", self, action.id) end
	return action
end

function Unit:ResolveDefaultFiringModeAction(firingMode, ui, sync)
	local actions = {}
	local hidden = self:HasStatusEffect("Hidden")
	local def_id
	
	local weapon = firingMode:GetAttackWeapons(self)
	local attack_ids
	if IsKindOf(weapon, "Firearm") then
		attack_ids = table.icopy(weapon.AvailableAttacks)
	else
		attack_ids = {}
		for id, action in pairs(CombatActions) do
			if action.FiringModeMember == firingMode.id then
				attack_ids[#attack_ids + 1] = action.id
			end
		end
	end
	
	-- special casea
	if firingMode.id == "AttackDual" then
		table.insert_unique(attack_ids, "LeftHandShot")
		table.insert_unique(attack_ids, "RightHandShot")
	elseif firingMode.id == "Attack" and weapon:HasComponent("EnableFullAuto") then
		table.insert_unique(attack_ids, "AutoFire")
	end
	
	local available = {}
	for _, id in ipairs(attack_ids) do
		local action = CombatActions[id]
		if action.FiringModeMember == firingMode.id then			
			actions[#actions + 1] = action
			available[id] = is_attack_available(self, action, sync)
			if hidden and id == "SingleShot" then
				def_id = id
			elseif ui and self.lastFiringMode and id == self.lastFiringMode and available[id] and self:HasAP(action:GetAPCost(self), id) then
				def_id = def_id or id
			end
		end		
	end
	table.sort(actions, function(a, b)
		return a.SortKey < b.SortKey
	end)
	if def_id then
		return def_id, actions
	end
	def_id = actions[1] and actions[1].id
	for _, ca in ipairs(actions) do
		if available[ca.id] then
			if not ui or self:HasAP(ca:GetAPCost(self), ca.id) then
				return ca.id, actions
			end
		end
	end
	return def_id, actions
end

local function ResetIdleLookAt(unit)
	if not g_Combat then
		return
	end
	for _, team in ipairs(g_Teams) do
		if team.side ~= "neutral" then
			for _, u in ipairs(team.units) do
				if u.command == "Idle" and u.target_dummy and u:IsAware() then
					local pos = GetPassSlab(u.target_dummy) or u.target_dummy:GetPos()
					if u:SetTargetDummyFromPos(pos, nil, false) then
						u:SetCommand("Idle")
					end
				end
			end
		end
	end
end

function UpdateIndoors(unit)
	if GameState.Underground then
		unit.indoors = true
		return
	end
	local volume = EnumVolumes(unit, "smallest")
	--unit.indoors = volume and not volume.dont_use_interior_lighting
	unit.indoors = not not volume
end

OnMsg.UnitMovementDone = ResetIdleLookAt
OnMsg.UnitDied = ResetIdleLookAt
OnMsg.VisibilityUpdate = ResetIdleLookAt
OnMsg.CoversChanged = ResetIdleLookAt
OnMsg.CombatObjectDied = ResetIdleLookAt

function OnMsg.EnterSector()
	for _, unit in ipairs(g_Units) do
		UpdateIndoors(unit)
		if HasPerk(unit, "ZombiePerk") then
			unit.stance = "Standing"
		end
	end
end

function OnMsg.UnitDied(dead_unit) -- bandage target death handler
	dead_unit:PlaceBlood()
	if not g_Combat then return end
	for _, unit in ipairs(g_Units) do
		if unit.combat_behavior == "CombatBandage" then
			local target = unit.combat_behavior_params[1]
			if target == dead_unit then
				unit:EndCombatBandage()
			end
		end
	end
end

local function UnitsUpdateCovers(bbox)
	MapForEach(bbox or "map", "Unit", function(u)
		if u:IsDead() or not u:IsAware() then
			return
		end
		if u:HasStatusEffect("Protected") and not GetCoversAt(u) then
			u:RemoveStatusEffect("Protected")
		end
		if u.command == "Idle" then
			u:SetCommand("Idle")
		end
	end)
end
OnMsg.CoversChanged = UnitsUpdateCovers
function OnMsg.CombatObjectDied(obj, bbox)
	UnitsUpdateCovers(bbox)
end

function Unit:SetHighlightColorModifier(visible)
	if not IsValid(self) then return "break" end
	if not visible then
		self.interactable_highlight_ctr = SpawnUnitContour(false, false, self.interactable_highlight_ctr)
	end

	local dead = self:IsDead()
	if not self:IsNPC() and not dead then return "break" end
	if dead then
		return Interactable.SetHighlightColorModifier(self, visible)
	end

	if visible == not not self.interactable_highlight_ctr then return "break" end
	self.interactable_highlight_ctr = SpawnUnitContour(self, "Interact", self.interactable_highlight_ctr)
	return "break"
end

if Platform.developer then
	function TestSpawnNPC(class, pos)
		local session_id = GenerateUniqueUnitDataId("TestNPC", gv_CurrentSectorId or "A1", class)
		return SpawnUnit(class, session_id, pos or GetCursorPos())
	end
end

TFormat.ap = function(context_obj, value)
	return T{747393774818, "<num> AP", num = value/const.Scale.AP}
end

TFormat.apn = function(context_obj, value)
	return T{867764319678, "<num>", num = type(value) == "number" and value/const.Scale.AP or value or ""}
end

function Unit:UpdatePFClass()
	if self.pfclass_overwritten then
		return
	end
	local side = self.team and self.team.side
	if (side == "player1" or side == "player2") and (self:HasStatusEffect("Panicked") or self:HasStatusEffect("Berserk")) then
		side = "enemy1" -- player units controlled by AI use the same pathfinding rules as the AI units
	end
	local pfclass = CalcPFClass(side, self.stance, self.body_type)
	self:SetPfClass(pfclass)
end

function Unit:OverwritePFClass(pfclass)
	if pfclass then
		self.pfclass_overwritten = pfclass
		self:SetPfClass(pfclass)
	elseif self.pfclass_overwritten then
		self.pfclass_overwritten = false
		self:UpdatePFClass()
	end
end

SuppressTeamUpdate = false

function Unit:SetTeam(team)
	local old_team = self.team
	local aware = self:IsAware()
	self.team = team
	self:UpdatePFClass()
	
	if old_team and team ~= old_team and old_team.side == "neutral" and not team.player_team then
		self:AddStatusEffect("Unaware")
	end
	
	if old_team and team ~= old_team and IsValidTarget(self) then
		local next_unit
		if table.find(Selection or empty_table, self) then
			SelectionRemove(self)
			if #Selection == 0 then
				next_unit = true
			end
		end
		if SelectedObj == self or next_unit then
			local igi = GetInGameInterfaceModeDlg()
			if igi then
				igi:NextUnit()
			end
		end
		if aware and team.side ~= "player1" and team.side ~= "player2" and team.side ~= "neutral" and team.side ~= old_team.side then
			if g_Combat then
				self:AddStatusEffect("Surprised")
			else
				self:AddStatusEffect("Suspicious")
			end
			if old_team and not GameState.loading and not GameState.loading_savegame then
				for _, unit in ipairs(old_team.units) do
					PushUnitAlert("discovered", unit)
				end
				AlertPendingUnits()
			end
		end
	end

	Msg("UnitSideChanged", self, team)
	if not SuppressTeamUpdate then Msg("TeamsUpdated") end
end

function Unit:SetSide(side)
	if not g_Teams or #g_Teams == 0 then SetupDummyTeams() end

	local new_team = table.find_value(g_Teams, "side", side)
	SendUnitToTeam(self, new_team)
	self.CurrentSide = side
	if side ~= "neutral" then
		-- remove forced weapon anim prefix
		for command, params in pairs(self.command_specific_params) do
			params.weapon_anim_prefix = nil
		end
	end
	self:SyncWithSession("map")
end

function Unit:GetCombatMoveCost(pos)
	if point_pack(SnapToVoxel(pos:xyz())) == point_pack(SnapToVoxel(self:GetPosXYZ())) then
		return 0 -- the unit is in the same slab with the destination
	end
	local combatPath = GetCombatPath(self)
	local ap = combatPath:GetAP(pos)
	return ap
end

function Unit:GetClosestMeleeRangePos(target, stance, interaction)
	local closest_pos
	if g_Combat then
		local combatPath = GetCombatPath(self, stance)
		closest_pos = combatPath:GetClosestMeleeRangePos(target, true, interaction)
	else
		if target.behavior == "Visit" and IsKindOf(target.last_visit, "AL_SitChair") then
			return target.last_visit:GetPos()
		end
		local positions = GetMeleeRangePositions(self, target, nil, true)
		if positions then
			for i, packed_pos in ipairs(positions) do
				positions[i] = point(point_unpack(packed_pos))
			end
			local has_path, pf_closest_pos = pf.HasPosPath(self, positions)
			if has_path and table.find(positions, pf_closest_pos) and (interaction or not IsKindOf(target, "Unit") or IsMeleeRangeTarget(self, pf_closest_pos, stance, target)) then
				closest_pos = pf_closest_pos
			end
		end
	end
	return closest_pos
end

function Unit:CalcAttackCostRange(action, target, item_id)
	if action.group == "FiringModeMetaAction" then
		local _, firingModeActions = GetUnitDefaultFiringModeActionFromMetaAction(self, action)
		local max, min = 0, 1000 * const.Scale.AP
		for i, fm in ipairs(firingModeActions) do
			local mode_min, mode_max = self:CalcAttackCostRange(fm, target)
			max = Max(max, mode_max)
			min = Min(min, mode_min)
		end
		return min, max
	end
	
	local min_aim, max_aim = self:GetBaseAimLevelRange(action)
	local args = {target = target, item_id = item_id}
	local min, max, display_cost
	
	for aim = min_aim, max_aim do
		args.aim = aim
		local ap = action:GetAPCost(self, args)
		if ap > 0 then
			min = Min(min, ap)
			max = Max(max, ap)
		end
	end
	return min, max
end

-- Returns the maximum aim level the unit can use to execute the provided action
function Unit:GetBaseAimLevelRange(action, target)
	if not action.IsAimableAttack then return 0, 0 end
	local actionWep = action:GetAttackWeapons(self)
	local min, max = 0, 0
	if IsKindOfClasses(actionWep, "Firearm", "MeleeWeapon") then
		max = actionWep.MaxAimActions
	end
	if max > 0 then
		if HasPerk(self, "Instagib") and self:HasStatusEffect("InstagibBuff") then
			max = max + CharacterEffectDefs.Instagib:ResolveValue("bonusAims")
		end
		
		-- weapon components
		if IsKindOf(actionWep, "Firearm") then
			if actionWep:HasComponent("MinAim") then
				min = Max(min, GetComponentEffectValue(actionWep, "MinAim", "min_aim"))
			end
			
			local startedCombat = g_Combat and g_Combat.current_turn == 1 and IsKindOf(g_AttackSpentAPQueue[1], "Unit") and g_AttackSpentAPQueue[1].session_id == self.session_id
			local firstShotBoost = not self.performed_action_this_turn and not startedCombat and not IsOverwatchAction(action.id) and
										GetComponentEffectValue(actionWep, "FirstShotIncreasedAim", "min_aim")
			if firstShotBoost then
				max = Max(max, firstShotBoost)
				min = Min(max, firstShotBoost)
			end
		end
	end
	
	return min, max
end

function Unit:GetAimLevelRange(action, target, goto_pos, is_free_aim)
	local minAim, maxCurrent, maxTotal
	minAim, maxTotal = self:GetBaseAimLevelRange(action, target)
		
	for i = 1, maxTotal do
		if action:GetUIState({self}, { target = target, aim = i, goto_pos = goto_pos, free_aim = is_free_aim }) ~= "enabled" then
			maxCurrent = i - 1
			break
		end
	end
	
	return minAim, (maxCurrent or maxTotal), maxTotal
end

function Unit:JoinSquadAs(merc_id, squad)
	local unit = SpawnUnit(merc_id, merc_id, self:GetPos(), self:GetAngle())
	unit:ApplyAppearance(self.Appearance)
	unit:SetState(self:GetState(), 0, 0)
	unit:SetAnimPhase(1, self:GetAnimPhase())
	unit.stance  = self.stance
	unit.current_weapon = self.current_weapon

	local weapon1, weapon2 = self:GetActiveWeapons(false, "strict")
	if IsKindOf(weapon1, "Firearm") then
		unit:Attach(weapon1:CreateVisualObj(unit), unit:GetSpotBeginIndex("Weaponr"))
	end
	if IsKindOf(weapon2, "Firearm") then
		unit:Attach(weapon2:CreateVisualObj(unit), unit:GetSpotBeginIndex("Weaponl"))
	end

	self.villain = false
	self.HitPoints = 0
	self:ClearHierarchyEnumFlags(const.efVisible)

	local tidx = g_Teams and table.find(g_Teams, "side", squad.Side)
	if tidx then
		table.insert(g_Teams[tidx].units, unit)
		unit:SetTeam(g_Teams[tidx])
		ObjModified(unit.team)
	end
	
	AddToGlobalUnits(unit)

	-- Check if trying to join a full squad.
	local unitCount, unitCountWithJoining = GetSquadUnitCountWithJoining(squad.UniqueId)
	if unitCountWithJoining >= const.Satellite.MercSquadMaxPeople then
		local oldSector, oldVisualPos = squad.CurrentSector, squad.VisualPos
		local name = SquadName:GetNewSquadName("player1")
		local squadParams = {Side = "player1", CurrentSector = oldSector, VisualPos = oldVisualPos, Name = name}
		local squad_id = CreateNewSatelliteSquad(squadParams, {merc_id})
		squad = gv_Squads[squad_id]
		Msg("UnitJoinedPlayerSquad",squad_id)
	else
		AddUnitsToSquad(squad, {merc_id}, nil, InteractionRand(nil, "Satellite"))
	end
	
	-- Mark unit as spawned, so satellite doesnt respawn.
	local newUd = gv_UnitData[unit.session_id]
	assert(newUd)
	newUd.already_spawned_on_map = true
	unit.already_spawned_on_map = true

	-- Remove old UD from its squad.
	local ud = gv_UnitData[self.session_id]
	if ud then
		RemoveUnitFromSquad(ud, "despawn")
	end

	if g_Combat then
		Msg("UnitEnterCombat", unit)
	end
	Msg("TeamsUpdated")

	DoneObject(self)
	Msg("UnitJoinedAsMerc", unit)
end

function OnMsg.UnitJoinedPlayerSquad()
	if g_Combat then
		ObjModified(g_Combat)
	else
		ForceUpdateCommonUnitControlUI()
	end
end

function GetBehaviorGroups()
	local marker_groups = {}
	for id, group in sorted_pairs(Groups) do
		for _, o in ipairs(group) do
			if IsKindOf(o, "WaypointMarker") or (IsKindOf(o, "GridMarker") and (o.Type == "Position" or o.Type=="Entrance") )then
				marker_groups[#marker_groups + 1] = id
				break
			end
		end
	end
	return marker_groups
end

MapVar("gv_UnitGroups",false)
MapVar("gv_NPCGroups",false)
MapVar("gv_TargetUnitGroups",false)

local groups_separator = "-----------------"

function GetUnitSpawnMarkerGroups()
	local marker_groups = {}
	
	MapForEach("map", "UnitMarker", function(marker, marker_groups)
		table.iappend(marker_groups, marker.Groups or empty_table)
	end, marker_groups)
	
	MapForEachMarker("Defender", false, function(marker, marker_groups)
		table.iappend(marker_groups, marker.Groups or empty_table)
	end, marker_groups)
	
	MapForEachMarker("DefenderPriority", false, function(marker, marker_groups)
		table.iappend(marker_groups, marker.Groups or empty_table)
	end, marker_groups)
	
	table.sort(marker_groups)
	-- remove duplicates
	for i = #marker_groups, 2, -1 do
		if marker_groups[i] == marker_groups[i - 1] then
			table.remove(marker_groups, i)
		end
	end
	return marker_groups
end

function GetUnitGroups()
	if not gv_UnitGroups then
		RecalcGroups()
	end
	return gv_UnitGroups
end

function GetTargetUnitCombo()
	if not gv_TargetUnitGroups then
		RecalcGroups()
	end
	return gv_TargetUnitGroups
end

local custom_unit_groups = {"EnemySquad", "Villains"}
g_AnyUnitGroups = { 
	["any"] = true, 
	["any merc"] = true, 
	["current unit"] = true, 
	["player mercs on map"] = true 
}

function RecalcGroups()
	if GetMap() == "" then return end
	
	local groups = GetUnitSpawnMarkerGroups()
	groups[#groups+1] = groups_separator
	local mercs = {}
	for k,v in pairs(UnitDataDefs) do
		if IsMerc(v) then
			mercs[#mercs+1] = k
		end
	end
	table.sort(mercs)
	table.iappend(groups, mercs)
	groups[#groups+1] = groups_separator
	
	local non_mercs = {}
	for k,v in pairs(UnitDataDefs) do
		if not IsMerc(v) then
			non_mercs[#non_mercs+1] = k
		end
	end
	table.sort(non_mercs)
	table.iappend(groups, non_mercs)
	table.iappend(groups, custom_unit_groups)
	
	gv_UnitGroups = groups
	
	gv_TargetUnitGroups = table.keys2(g_AnyUnitGroups, "sorted")
	table.iappend(gv_TargetUnitGroups, groups)
end

function TFormat.GetNumAliveUnitsInGroup(context, groupName)
	return GetNumAliveUnitsInGroup(groupName)
end

function GetNumAliveUnitsInGroup(group)
	local num = 0
	for _, obj in ipairs(Groups[group]) do
		if IsKindOf(obj, "Unit") and not obj:IsDead() then
			num = num + 1
		end
	end
	return num
end

OnMsg.NewMapLoaded = RecalcGroups
OnMsg.GameExitEditor = RecalcGroups

function OnMsg.UnitDied()
	ObjModified(gv_Quests)
end

GameVar("DeadGroupsInSectors", {})
function UpdateDeadGroups(groups)
	local deadGroups = DeadGroupsInSectors[gv_CurrentSectorId] or {}
	for _, group in ipairs(groups) do
		local allDead = GetNumAliveUnitsInGroup(group) == 0
		if allDead then
			deadGroups[group] = "all"
		else
			deadGroups[group] = "any"
		end
	end
	DeadGroupsInSectors[gv_CurrentSectorId] = deadGroups
end

function OnMsg.UnitDieStart(unit)
	UpdateDeadGroups(unit.Groups)
end

function OnMsg.VillainDefeated(unit)
	UpdateDeadGroups(unit.Groups)
end

function OnMsg.GatherFXActions(list)
	table.insert(list, "StepRun")
	table.insert(list, "StepWalk")
	table.insert(list, "StepRunCrouch")
	table.insert(list, "StepRunProne")

	table.insert(list, "Interact")
	for i,combat_action in ipairs(Presets.CombatAction.Interactions) do
		table.insert(list, combat_action.id)
	end
end

function OnMsg.GatherFXActors(list)
	table.insert(list, "Unit")
end

function Unit:AutoRemoveCombatEffects()
	local effect_ids = table.map(self.StatusEffects or empty_table, "class")
	for _, id in ipairs(effect_ids) do
		local def = CharacterEffectDefs[id]
		if def and def.RemoveOnEndCombat then
			self:RemoveStatusEffect(id, "all")
		end
	end
end

local ExitCombatUninterruptable = {
	["Visit"] = true,
	["EnterMap"] = true,
	["Cower"] = true,
}

function OnMsg.CombatEnd(combat)
	MapForEach("map", "Unit", function(unit)
		unit:AutoRemoveCombatEffects()
		if not unit:IsDead() and g_Overwatch[unit] and (not g_Overwatch[unit].permanent or unit.team.control ~= "UI") then
			unit:InterruptPreparedAttack()
			unit:RemovePreparedAttackVisuals()
		end
		if not unit:IsDead() or unit.immortal then
			local overwatch = g_Overwatch[unit]
			if not ExitCombatUninterruptable[unit.command] then
				if overwatch and overwatch.permanent then
					-- only check for reload
					unit:UpdateNumOverwatchAttacks()
					CreateGameTimeThread(Unit.AutoReload, unit)
				else
					unit:InterruptCommand("ExitCombat")
				end
			end
		end
	end)
end

function Unit:IsAdjacentTo(other, check_pos)
	local x, y, z
	if check_pos then
		x, y, z = PosToGridCoords(check_pos:xyz())
	else
		x, y, z = self:GetGridCoords()
	end
	
	local ox, oy, oz = other:GetGridCoords()

	return abs(x - ox) <= 1 and abs(y - oy) <= 1 and abs(z - oz) <= 1
end

function Unit:CanSurround(other, check_pos)
	-- side
	if not self:IsOnEnemySide(other) or self:IsDead() or self:IsDowned() then
		return false
	end
	
	-- status effects
	if self:HasStatusEffect("Suppressed") then
		return false
	end
	
	-- Not valid gameplay wise, but happens in some rare cases and fires asserts down the line.
	local pos = check_pos or self:GetPos()
	if other:GetPos() == pos then
		return false
	end
	
	-- visibility
	if check_pos then
		-- checking from another position, use CheckLOS
		if not CheckLOS(other, self, self:GetSightRadius()) then
			return false
		end
	else
		-- checking from current position, can use precomputed visibility
		if not HasVisibilityTo(self, other) then
			return false
		end
	end
	
	-- weapon range
	local adjacent = self:IsAdjacentTo(other, check_pos)
	local in_range = false
	local w1, w2, weapons = self:GetActiveWeapons()
	for _, weapon in ipairs(weapons) do
		if IsKindOf(weapon, "Firearm") or (IsKindOf(weapon, "MeleeWeapon") and weapon.CanThrow) then
			-- heavy weapons are Firearms and go here too
			in_range = in_range or other:GetDist(pos) <= weapon.WeaponRange * const.SlabSizeX
		elseif IsKindOf(weapon, "MeleeWeapon") then
			in_range = in_range or adjacent
		end
	end
	
	return in_range
end

function Unit:IsSurrounded(unitReplace)
	if not g_Visibility or not g_Combat or self:IsDead() then
		return
	end
	
	local pos = unitReplace and unitReplace[self] or self:GetPos()
	local enemy_pos = {}
	local angle = 120*60
	local cosa = MulDivRound(cos(angle), guim*guim, 4096)

	for _, team in ipairs(g_Teams) do
		if team.side ~= "neutral" then
			for _, u in ipairs(team.units) do
				if u:CanSurround(self, unitReplace and unitReplace[u]) then
					enemy_pos[#enemy_pos + 1] = unitReplace and unitReplace[u] or u:GetPos()
				end
			end
		end
	end
	if #enemy_pos < 2 then
		return
	end
	local pts = ConvexHull2D(enemy_pos)

	for i = 1, #pts - 1 do
		local v1 = pts[i]:Equal2D(pos) and point30 or SetLen(pts[i] - pos, guim)
		for j = i + 1, #pts do
			local v2 = pts[j]:Equal2D(pos) and point30 or SetLen(pts[j] - pos, guim)
			local dp = Dot2D(v1, v2)
			if dp < cosa then
				return true
			end
		end
	end	
end

function InterpolateCoverEffect(coverage, full_value, exposed_value)
	local threshold = 40
	if coverage >= 80 then
		return full_value
	elseif coverage < threshold then
		return exposed_value
	end
	return exposed_value + MulDivRound(full_value - exposed_value, coverage - threshold, threshold)
end

function Unit:ApplyHitDamageReduction(hit, weapon, hit_body_part, ignore_cover, ignore_armor, record_breakdown)
	local damage = hit.damage or 0
	local dmg = damage
	local armor_decay, armor_pierced = {}, {}
	local weapon_pen_class = weapon:HasMember("PenetrationClass") and weapon.PenetrationClass or 1
	self:ForEachItem("Armor", function(item, slot)
		if dmg > 0 and slot ~= "Inventory" and item.ProtectedBodyParts and item.ProtectedBodyParts[hit_body_part] then
			local dr, degrade = 0, 0
			if not ignore_armor and item.Condition > 0 then
				dr = item.DamageReduction
				degrade = item.Degradation
				if weapon_pen_class < item.PenetrationClass then
					dr = dr + item.AdditionalReduction
					degrade = MulDivRound(degrade, const.Combat.ArmorDegradePercent, 100)
				else
					armor_pierced[item] = true
				end
			else
				armor_pierced[item] = true
			end
			
			-- scale DR down on poor condition
			dr = MulDivRound(dr, Min(100, 50 + item.Condition), 100)
			
			local scaled = dmg * (100 - dr)
			local result = scaled / 100
			if scaled % 100 > 0 and armor_pierced[item] then
				-- round the resulting damage up when pierced only
				result = result + 1
			end

			if record_breakdown then
				if armor_pierced[item] then
					record_breakdown[#record_breakdown + 1] = { name = T{191288543859, "<em><DisplayName></em> (Pierced)", item}, value = -dr }
				else
					record_breakdown[#record_breakdown + 1] = { name = T{516752639882, "<em><DisplayName></em>", item}, value = -dr }
				end
			end

			dmg = Min(dmg, result)
			armor_decay[item] = Min(item.Condition, degrade)
		end
	end)
	
	local armor_prevented = damage - dmg
		
	-- HoldPosition perk damage reduction
	if HasPerk(self, "HoldPosition") and (g_Overwatch[self] or g_Pindown[self]) then
		local statPercent = CharacterEffectDefs.HoldPosition:ResolveValue("percentHealth")
		local percent_reduction = MulDivRound(self.Health, statPercent, 100)
		if record_breakdown then record_breakdown[#record_breakdown + 1] = { name = CharacterEffectDefs.HoldPosition.DisplayName, value = -percent_reduction } end
		dmg = Max(0, MulDivRound(dmg, 100 - percent_reduction, 100))
	end
		
	local armor = next(armor_decay)
	hit.armor = armor and armor.DisplayName
	hit.armor_prevented = armor_prevented
		
	hit.damage = dmg
	hit.armor_decay = armor_decay
	hit.armor_pen = armor_pierced
end

function Unit:IsArmored(target_spot_group)
	if self:IsDead() then return false end
	local armorFound = false
	self:ForEachItem("Armor", function(item, slot)
		if slot ~= "Inventory" and (not target_spot_group or item.ProtectedBodyParts and item.ProtectedBodyParts[target_spot_group]) then 
			armorFound = item
			return "break"
		end
	end)
	
	local iconName = false
	if armorFound and armorFound.PenetrationClass > 1 then
		local classId = PenetrationClassIds[armorFound.PenetrationClass]
		iconName = classId:lower() .. "_armor"
	end
	
	return armorFound, iconName, "UI/Hud/"
end

function Unit:ApplyDamageAndEffects(attacker, damage, hit, armor_decay)
	if self:IsDead() or not IsValid(self) then return end

	if damage and damage > 0 or hit.setpiece then
		self:TakeDamage(damage or 0, attacker, hit)	
	end
	
	local invulnerable = self:IsInvulnerable()
	if not invulnerable then
		local effects = hit.effects
		if type(effects) == "string" and effects ~= "" then
			self:AddStatusEffect(effects)
		else
			for _, effect in ipairs(effects) do
				if effect and effect ~= "" then
					self:AddStatusEffect(effect)
				end
			end
		end
	end
	
	-- blood/soot stains
	local was_wounded = self:HasStatusEffect("Wounded")
	if hit.direct_shot then -- bullet-simulated firearm attacks
		local spot, params = CalcStainParamsFromShot(self, attacker, hit)
		if spot then
			assert(not params or type(params) == "table")
			self:AddStain("Blood", spot, params)
		end
	elseif not was_wounded then
		-- pick a spot and save it as effect value for the Wounded status to use if it gets applied
		local spot
		if hit.melee_attack then
			spot = GetRandomStainSpot(hit.spot_group)
		else
			spot = GetRandomStainSpot()
		end
		if spot then
			self:SetEffectValue("wounded_stain_spot", spot)
		end
	end
	
	-- cleanup wounded_stain_spot
	self:SetEffectValue("wounded_stain_spot", nil)
	
	-- add soot from explosions (if there's no blood)
	if hit.explosion and not self:HasStainType("Blood") then
		local spot = GetRandomStainSpot()
		self:AddStain("Soot", spot)
	end
		
	if not invulnerable then
		local change = false
		for item, degrade in pairs(armor_decay) do
			item.Condition = self:ItemModifyCondition(item, - degrade)
			if IsKindOf(item, "TransmutedItemProperties") and item.RevertCondition=="damage" then
				item.RevertConditionCounter = item.RevertConditionCounter-1
				if item.RevertConditionCounter== 0 then
					local slot_name = self:GetItemSlot(item)
					local new, prev = item:MakeTransmutation("revert")
					armor_decay[new] = degrade
					armor_decay[item] = false
					self:RemoveItem(slot_name, item)
					self:AddItem(slot_name, new)					
					DoneObject(prev)
					change = true
				end
			end	
		end
		if change then
			self:UpdateOutfit()
		end
	end
end

function Unit:SwapActiveWeapon(action_id, cost_ap)
	local igi = GetInGameInterfaceModeDlg()
	if IsKindOf(igi, "IModeCombatBase") and igi.attacker == self then
		InvokeShortcutAction(igi, "ExitAttackMode", igi)
	end

	if self.current_weapon == "Handheld A" then
		self.current_weapon = "Handheld B"
	else
		self.current_weapon = "Handheld A"
	end

	self:OnSetActiveWeapon(action_id, cost_ap)
end

function Unit:OnSetActiveWeapon(action_id, cost_ap)
	if not self.current_weapon then return end
	if HasPerk(self, "Scoundrel") and g_Combat then
		self:ActivatePerk("Scoundrel")
		PlayVoiceResponse(self, "Scoundrel")
	end
	if not GameState.loading then
		local should_interrupt
		local overwatch = g_Overwatch[self]
		if overwatch then
			local weapons = self:GetEquippedWeapons(self.current_weapon, "Firearm")
			should_interrupt = true
			for _, weapon in ipairs(weapons) do
				should_interrupt = should_interrupt and (weapon.id ~= overwatch.weapon_id)
			end
		end
		local pindown = g_Pindown[self]
		if not should_interrupt and pindown then
			local weapons = self:GetEquippedWeapons(self.current_weapon, "Firearm")
			should_interrupt = true
			for _, weapon in ipairs(weapons) do
				should_interrupt = should_interrupt and (weapon.id ~= pindown.weapon_id)
			end
		end
		if not should_interrupt and self.prepared_bombard_zone then
			local weapons = self:GetEquippedWeapons(self.current_weapon, "HeavyWeapon")
			should_interrupt = true
			for _, weapon in ipairs(weapons) do
				should_interrupt = should_interrupt and (weapon.id ~= self.prepared_bombard_zone.weapon_id)
			end
		end
		
		if should_interrupt then
			self:InterruptPreparedAttack()
		end
	end
	self:UpdateOutfit(self.Appearance)
	self:RecalcUIActions()
	--self.lastFiringMode = false
	self:SetAimTarget(false, false)
	if not cost_ap or cost_ap == 0 then
		-- if the action was free we still want the UI to reflect possible differences
		Msg("UnitAPChanged", self, action_id) 
	end
	Msg("UnitSwappedWeapon", self)
	ObjModified(self)
end

function Unit:StartAI(debug_data, forced_behavior)
	if not IsValid(self) or self:IsDead() or self.ai_context or self:HasStatusEffect("Unconscious") then
		return
	end
	AIReloadWeapons(self)
	
	local proto_context = {}
	self:SelectArchetype(proto_context)
	
	--local context = AICreateContext(self, proto_context)
	--local archetype = context.archetype
	local archetype = self:GetArchetype()
	
	local scores, available = {}, {}
	local total = 0

	AIUpdateBiases()
	for i, behavior in ipairs(archetype.Behaviors) do
		local weight_mod, disable, priority
		if behavior:MatchUnit(self) then
			weight_mod, disable, priority = AIGetBias(behavior.BiasId, self)
			priority = priority or behavior.Priority
		else
			weight_mod, disable, priority = 0, true, false
		end

		if debug_data then
			debug_data.behaviors = debug_data.behaviors or {}
			debug_data.behaviors[i] = {
				name = behavior:GetEditorView(),
				priority = priority,
				disable = disable,
				behavior = behavior,
				index = i,
			}
		end

		if not disable then
			local score = MulDivRound(behavior:Score(self, debug_data), weight_mod, 100)
			if debug_data then
				debug_data.behaviors[i].score = score
			end
			if score > 0 then
				if priority and not forced_behavior then
					forced_behavior = behavior
					break
				end
				scores[#scores + 1] = score
				available[#available + 1] = behavior
				total = total + score
			end
		end
	end
	
	if total == 0 and not forced_behavior then 
		printf("unit of %s archetype failed to select a behavior!", archetype.id)
		return
	end
	
	local roll = InteractionRand(total, "AIBehavior", self)
	local selected
	if not forced_behavior then
		for i, behavior in ipairs(available) do
			local score = scores[i]
			if roll <= score then
				selected = behavior
				break
			end
			roll = roll - score
		end
	end
	
	--self.ai_context.behavior = forced_behavior or selected or available[#available]
	proto_context.behavior = forced_behavior or selected or available[#available]
	AICreateContext(self, proto_context)
	if self.ai_context.behavior then
		self.ai_context.behavior:OnStart(self)
	end
	return true
end

function UpdateSurrounded()	
	for _, unit in ipairs(g_Units) do
		if unit:IsSurrounded() then
			unit:AddStatusEffect("Flanked")
		else
			unit:RemoveStatusEffect("Flanked")
		end
	end
end

function RollSkillCheck(unit, skill, modifier, add)
	assert(IsKindOf(unit, "UnitPropertiesStats"))
	
	modifier = modifier or 100
	add = add or 0
	
	local roll = 1 + unit:Random(100)
	--adjust roll based on diff
	local adjustRoll = GameDifficulties[Game.game_difficulty]:ResolveValue("rollSkillCheckBonus") or 0
	roll = roll + adjustRoll
	roll = Min(roll, 95)
	
	local value = MulDivRound(unit[skill], modifier, 100) + add
	local pass = roll < value or CheatEnabled("SkillCheck")
	
	--CombatLog("debug", 
	local t_res = pass and Untranslated("<em>Pass</em>") or Untranslated("<em>Fail</em>")
	local meta = unit:GetPropertyMetadata(skill)
	local t_skill = meta.name
	if modifier ~= 100 then
		if add > 0 then
			t_skill = T{816405633181, "<percent(n1)> <skill>+<n2>", n1 = modifier, n2 = add, skill = meta.name}
		elseif add < 0 then
			t_skill = T{656059859333, "<percent(n1)> <skill><n2>", n1 = modifier, n2 = add, skill = meta.name}
		else
			t_skill = T{570928040607, "<percent(number)> <skill>", number = modifier, skill = meta.name}
		end
	elseif add > 0 then
		t_skill = T{481345361355, "<skill>+<number>", number = add, skill = meta.name}
	elseif add < 0 then
		t_skill = T{945399039468, "<skill><number>", number = add, skill = meta.name}
	end
	
	CombatLog("debug", T{Untranslated("<em><name><em> Skill check (<em><skill></em>) <roll>/<target>: <result>"), 
		name = unit:GetLogName(),
		skill = t_skill,
		roll = roll, 
		target = value,
		result = t_res,
	})
	return pass
end

function SkillCheck(unit, skill, threshold,dont_report_fails)
	if not unit or not IsKindOf(unit, "UnitPropertiesStats") then return "error" end
	local stat = unit[skill]
	if not stat then return "error" end
	if threshold <= stat or CheatEnabled("SkillCheck") then
		CombatLog("debug", "(success) " .. unit.session_id .. " " .. skill.. " check (" .. stat.. " / " ..threshold .. ")")
		PlayFX("SkillCheck", "success", unit, skill)
		return "success", stat - threshold, stat
	end	
	PlayFX("SkillCheck", "fail", unit, skill)
	if not dont_report_fails then
		CombatLog("debug", "(fail) " .. unit.session_id .." " .. skill.. " check (" .. stat.. " / " ..threshold .. ")")
	end
	return "fail", threshold - stat, stat
end

function SpawnUnit(class, session_id, pos, angle, groups, spawner, entrance)
	session_id = session_id or class
	NetUpdateHash("SpawnUnit", class, session_id, pos)
	local unit_data = CreateUnitData(class, session_id, InteractionRand(nil, "Satellite"))

	local unit_group = UnitDataDefs[unit_data.class].group
	local unit = Unit:new{ 
		unitdatadef_id = unit_data.class,
		group = unit_group,
		session_id = session_id,
		spawner = spawner,
		entrance_marker = entrance,
	}

	AddToGlobalUnits(unit)

	for _, group in ipairs(groups) do
		unit:AddToGroup(group)
	end

	if angle then
		unit:SetAngle(angle)
	end
	if pos then
		unit:SetPos(pos)
	end

	if unit:IsNPC() and not unit.dummy then
		if IsKindOf(spawner, "UnitMarker") then
			for _, effect in ipairs(spawner.status_effects) do
				if CharacterEffectDefs[effect] then
					unit:AddStatusEffect(effect)
				end
			end
		end
		if IsKindOf(spawner, "GridMarker") and spawner.Suspicious or IsKindOf(entrance, "GridMarker") and entrance.Suspicious then
			unit:AddStatusEffect("HighAlert")
			if not spawner or spawner.Side ~= "neutral" then
				unit:AddStatusEffect("Unaware")
			end
		else
			local data = gv_UnitData[session_id]
			local squad_idx = data and data.Squad and table.find(g_SquadsArray, "UniqueId", data.Squad)
			local squad = squad_idx and g_SquadsArray[squad_idx]
			if squad and squad.militia then
				unit:AddStatusEffect("HighAlert")
			elseif not spawner or spawner.Side ~= "neutral" then
				unit:AddStatusEffect("Unaware")
			end
		end
	end
	unit:SetTargetDummyFromPos()

	return unit
end

function ValidateUnitGroupForEffectExec(group, effect, trigger_obj)
	local units = Groups[group]
	if Platform.developer and GameState.entered_sector and not units then
		local trigger_obj_idx = 1
		local errs = {}
		local sector_ids, effect_classes = {}, {}
		
		local function addErr(effect, parents, obj)
			if effect:HasMember("Group") and effect.Group == group then
				if obj == trigger_obj then
					trigger_obj_idx = #errs + 1
				end
				if IsKindOf(obj, "QuestsDef") then
					errs[#errs + 1] = {obj, string.format("Effect %s with invalid group %s in quest %s", effect.class, group, obj.id)}
				elseif IsKindOf(obj, "SatelliteSector") then
					sector_ids[#sector_ids + 1] = obj.Id
					effect_classes[#effect_classes + 1] = effect.class
				elseif IsKindOf(obj, "GridMarker") then
					errs[#errs + 1] = {obj, string.format("Effect %s with invalid group %s in marker", effect.class, group)}
				end
			end
		end
		
		-- check quest effects
		for id, quest in sorted_pairs(Quests) do
			if quest.TCEs and next(quest.TCEs) then
				for _, tce in ipairs(quest.TCEs) do
					tce:ForEachSubObject("Effect", addErr, quest)
				end
			end
		end
		
		-- check sector effects
		local campaign_preset = Game.Campaign and CampaignPresets[Game.Campaign]
		for _, sector in ipairs(campaign_preset and campaign_preset.Sectors) do
			for _, event in ipairs(sector.Events) do
				sector:ForEachSubObject("Effect", addErr, sector)
			end
		end
		if next(sector_ids) then
			errs[#errs + 1] = {campaign_preset, string.format("Effects - %s - with invalid group %s in sectors: %s", table.concat(effect_classes, ", "), group, table.concat(sector_ids, ", "))}
		end
		
		--check grid marker effects
		MapForEachMarker("GridMarker", nil, function(marker)
			marker:ForEachSubObject("Effect", addErr, marker)
		end)
		
		errs[1], errs[trigger_obj_idx] = errs[trigger_obj_idx], errs[1]
		for _, err in ipairs(errs) do
			StoreErrorSource(err[1], err[2])
		end
	end
	return units or empty_table
end

OnMsg.VisibilityUpdate = UpdateSurrounded
OnMsg.CombatApplyVisibility = UpdateSurrounded
OnMsg.CombatStart = UpdateSurrounded
OnMsg.CombatEnd = UpdateSurrounded

function OnMsg.CombatStart(dynamic_data)
	local transfer_keys = {
		"hmg_emplacement",
		"spent_ap",
		"PrisonDoor",
		"CellLeaveBanters"
	}

	for _, unit in ipairs(g_Units) do
		if unit.team.side == "neutral" and not unit.behavior then
			unit:SetBehavior("GoBackAfterCombat", {unit:GetPos()})
		end
		if not dynamic_data then
			local values = {}
			for i, key in ipairs(transfer_keys) do
				values[i] = unit:GetEffectValue(key)				
			end
			unit.effect_values = nil -- reset effect data on combat start
			for i, key in ipairs(transfer_keys) do
				if values[i] ~= nil then
					unit:SetEffectValue(key, values[i])
				end					
			end
			if unit.carry_flare then
				unit:RoamDropFlare()
			end
		end
		unit.marked_target_attack_args = nil	-- invalid in combat
		unit.neutral_retal_attacked = nil
	end
end

DefineClass.DummyUnit = {
	__parents = { "AppearanceObject" },
	flags = { gofPermanent = true, gofUnitLighting = false },
	properties = {
		{category = "Dummy Unit", id = "UnitLighting", name = "Unit Lighting", editor = "bool",
			default = false,
		},
		{category = "Dummy Unit", id = "FreezePhase", name = "Freeze Phase", editor = "number",
			default = false, slider = true, min = 0,
			max = function(obj)
				return GetAnimDuration(obj:GetEntity(), obj.anim) - 1
			end,
			help = "The unit will be freezed at this frame.",
		},
	},
	entity = "Male",
	Appearance = "Raider_01",
}

function DummyUnit:GameInit()
	self:UpdateFreezePhase()
end

function DummyUnit:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "FreezePhase" or prop_id == "anim" then
		self:UpdateFreezePhase()
	end
end

function DummyUnit:UpdateFreezePhase()
	local phase = self:GetProperty("FreezePhase")
	if phase then
		self:SetAnimPose(self.anim, phase)
		self:SetAnimSpeedModifier(0)
	else
		self:SetAnimSpeedModifier(1000)
	end
end

-- NOTE: Level Designers are setting the anim through StateText which gets overridden by 'anim' property
function DummyUnit:SetStateText(state)
	AppearanceObject.SetStateText(self, state)
	self:SetProperty("anim", state)
end

function DummyUnit:SetUnitLighting(value)
	if value then
		self:SetHierarchyGameFlags(const.gofUnitLighting)
	else
		self:ClearHierarchyGameFlags(const.gofUnitLighting)
	end
	self:DestroyRenderObj()
end

function DummyUnit:GetUnitLighting(value)
	return self:GetGameFlags(const.gofUnitLighting) ~= 0
end

function ErnyTown_HangUnit(group_id)
	local group = Groups[group_id]
	local units = {}
	for _, o in ipairs(group) do
		if IsKindOf(o, "Unit") then
			table.insert(units, o)
		end
	end	
	if #units ~= 1 then
		StoreErrorSource(point30, "There should be exactly one unit of the group " .. group_id)
		return
	end
	local unit = units[1]
	unit:SetCommand("Hang")
	unit:SetGroups(false)
end

function OnMsg.ValidateMap()
	if Game and not g_IdleAnimActionStances then
		FillIdleAnimActionsAndStances()
	end
end

if FirstLoad then
	g_IdleAnimActionStances = false
end

local function GetAllEntitiesValidAnimations()
	local dummy = PlaceObject("Unit", {
		NetUpdateHash = empty_func,
		IsSyncObject = function(self) return false end,
	})
	dummy:ClearGameFlags(const.gofSyncObject)
	dummy:SetCommand(false)
	dummy:SetPos(point30)
	
	local anims = {}
	for id, app in sorted_pairs(AppearancePresets) do
		if app.Body then
			dummy:ApplyAppearance(AppearancePresets[id])
			if IsValidEntity(dummy:GetEntity()) then
				dummy:SetState("idle")
				local dummy_anims = ValidAnimationsCombo(dummy)
				for _, a in ipairs(dummy_anims) do
					anims[a] = true
				end
			end
		end
	end
	DoneObject(dummy)
	
	return anims
end

function FillIdleAnimActionsAndStances()
	g_IdleAnimActionStances = {
		no_weapon = {g_StanceActionDefault, [g_StanceActionDefault] = {g_StanceActionDefault}},
		weapon = {g_StanceActionDefault, [g_StanceActionDefault] = {g_StanceActionDefault}}
	}
	
	local anims = GetAllEntitiesValidAnimations()
	for a, _ in sorted_pairs(anims) do
		local prefix, stance, action = string.match(a, "(.*)_(.*)_(.*)")
		if prefix and stance and action then
			local key = prefix == "civ" and "no_weapon" or "weapon"
			table.insert_unique(g_IdleAnimActionStances[key], stance)
			g_IdleAnimActionStances[key][stance] = g_IdleAnimActionStances[key][stance] or {g_StanceActionDefault}
			table.insert_unique(g_IdleAnimActionStances[key][stance], action)
		end
	end
end

function GetIdleAnimStances(use_weapons)
	assert(g_IdleAnimActionStances)
	return g_IdleAnimActionStances[use_weapons and "weapon" or "no_weapon"]
end

function GetIdleAnimStanceActions(use_weapons, stance)
	assert(g_IdleAnimActionStances)
	return g_IdleAnimActionStances[use_weapons and "weapon" or "no_weapon"][stance]
end

function Unit:ResolveUIAction(idx)
	local id = self.ui_actions and self.ui_actions[idx]
	return id and self.ui_actions[id] and CombatActions[id]
end

function Unit:IsAware(check_pending)
	if self.team and self.team.side == "neutral" or self.command == "Die" or self:IsDead() then
		return false
	end
	if check_pending then
		if self.pending_aware_state == "aware" or self.pending_aware_state == "surprised" or self:HasStatusEffect("Surprised") then
			return true
		end
	end
	return not self:HasStatusEffect("Unaware") and not self:HasStatusEffect("Suspicious") and not self:HasStatusEffect("Surprised")
end

function Unit:IsSuspicious()
	if self:IsDead() or self.command == "Die" then return false end
	return self:HasStatusEffect("Suspicious")
end

function Unit:AddToInventory(item_id, amount, callback)
	if not item_id then return 0 end
	amount = amount or 1
	local unit_amount = 0	
	self:ForEachItemInSlot("Inventory", "InventoryStack", 
		function(curitm, slot_name, item_left, item_top)
		   if curitm and item_id and curitm.class == item_id and curitm.Amount < curitm.MaxStacks then
				local to_add = Min(curitm.MaxStacks - curitm.Amount, amount)
				curitm.Amount =curitm.Amount + to_add
				Msg("InventoryAddItem", self, curitm, to_add)
				amount = amount - to_add			
				unit_amount = unit_amount + to_add
				if amount <= 0 then
					if callback then
						callback(self, curitm, unit_amount)
					end
					return "break"
				end
			end
		end)
	
	
	local itm
	while amount > 0 do			 
		local item = PlaceInventoryItem(item_id) 
		local is_stack = IsKindOf(item, "InventoryStack")
		
		if self:AddItem("Inventory", item) then 
			local to_add = 1
			if is_stack then
				to_add = Min(item.MaxStacks, amount) 
				item.Amount = to_add 
			end	
			unit_amount = unit_amount + to_add
			amount = amount - to_add
			unit_amount = unit_amount + to_add
			Msg("InventoryAddItem", self, item, to_add)
			itm =  item
		else
			DoneObject(item)
			break
		end				
	end		
	if callback and itm and unit_amount>0 then
		callback(self, itm, unit_amount)
	end
	ObjModified(self)

	return amount
end

-- Drop a container with a new item created from item_id.
function Unit:DropItemContainer(item_id, amount, callback)
	if amount <= 0 then return end
	local item = PlaceInventoryItem(item_id)
	local is_stack = IsKindOf(item, "InventoryStack")
	if is_stack then
		item.Amount = amount
	end

	local container = GetDropContainer(self, false,item )
	if container then
		local pos, res = container:AddItem("Inventory", item)
		if pos and callback then
			callback(self, item, amount)
		end
	end
end

-- Add already generated items (from loot table) into a container and drop it. Stack them if possible.
function Unit:DropItemsInContainer(items, callback)
	local container = GetDropContainer(self)
	if not container then return end
	for i = #items, 1, -1 do
		local item = items[i]
		if not container:CanAddItem("Inventory", item) then
			container = GetDropContainer(self, false, item)
		end
		local pos, reason = container:AddItem("Inventory", item)
		if pos then
			if callback then
				callback(self, item, IsKindOf("InventoryStack") and item.Amount or 1)
			end
			table.remove(items, i)
		end
	end	
end

function Unit:SetHighlightReason(reason, enable)
	self.highlight_reasons = self.highlight_reasons or {}
	self.highlight_reasons[reason] = enable
	
	self:UpdateHighlightMarking()

	if self.session_id then
		ObjModified(self.session_id .. "_combat_badge")
	end
	if reason == "deploy_predict" and self.ui_badge then
		self.ui_badge:SetVisible(not enable, "deploy_predict")
	end
end

function Unit:UpdateHighlightMarking() 
	if WaitRecalcVisibility then return end

	local marking = false

	-- if the unit was set invisible by visibility logic we dont want to mark it, as it would show it
	if not self.visible or IsSetpiecePlaying() or CheatEnabled("IWUIHidden") then
		marking = -1
	end
	
	-- during combat, only show marking of playing
	if not marking then
		local pov_team = GetPoVTeam()
		local enemyTurn = g_Combat and g_Teams[g_CurrentTeam] ~= pov_team
		local playing = IsMerc(self) or (g_AIExecutionController and table.find(g_AIExecutionController.currently_playing, self)) -- if merc skip  this check so we show hard to see mercs
		if enemyTurn and not playing then
			marking = -1
		end
	end
	
	if not marking then
		local reasons = self.highlight_reasons
		if reasons["dark voxel"] then
			marking = 3
		elseif reasons["area target"] then
			marking = 3
		elseif reasons["melee"] then
			marking = 3
		elseif reasons["melee-target"] then
			marking = 3
		elseif reasons["bandage-target"] then
			marking = 0
		elseif reasons["concealed"] then
			if HasThermalVision(Selection) then
				marking = 10
			else
				marking = 9
			end
		elseif reasons["obscured"] then
			marking = 7
		elseif reasons["visibility"] then
			local pov_team = GetPoVTeam()
			if pov_team:IsEnemySide(self.team) then
				local enemyTurn = g_Combat and g_Teams[g_CurrentTeam] ~= pov_team
				local playing = g_AIExecutionController and table.find(g_AIExecutionController.currently_playing, self)
				
				local seen = enemyTurn or playing
				if not seen then
					for _, unit in ipairs(Selection) do
						if HasVisibilityTo(unit, self) then
							seen = true
							break
						end
					end
				end
				marking = seen and 3 or 1
			elseif reasons["faded"] or g_Combat and not g_Combat:ShouldEndCombat() then -- ally and neutral only get marking in conflict unless they're walking in the air
				if pov_team:IsAllySide(self.team) then
					marking = 0
				else -- neutral
					marking = 2
				end
			end
		elseif reasons["darkness"] then
			marking = 8
		elseif reasons["deploy_predict"] then
			marking = 5
		elseif reasons["can_be_interacted"] then
			marking = 11
		end
	end

	marking = marking or -1
	self:SetObjectMarking(marking)
	if marking < 0 then
		self:ClearHierarchyGameFlags(const.gofObjectMarking)
	else
		self:SetHierarchyGameFlags(const.gofObjectMarking)
	end
end

const.utWellRested = -1
const.utNormal = 0
const.utTired = 1
const.utExhausted = 2
const.utUnconscious = 3

UnitTirednessEffect = {
	[const.utWellRested] = "WellRested",
	[const.utNormal] = "Default",
	[const.utTired] = "Tired",
	[const.utExhausted] = "Exhausted",
	[const.utUnconscious] = "Unconscious",
}

function TFormat.tiredness(context_obj, value)
	local effect = UnitTirednessEffect[value]
	if effect and g_Classes[effect] then
		return g_Classes[effect].DisplayName
	elseif effect == "Default" then
		return T(714191851131, "Normal")
	end
	return ""
end

function UnitTirednessComboItems()
	local items = {}
	for k, v in sorted_pairs(UnitTirednessEffect) do
		items[#items + 1] = { name = v, value = k }
	end
	return items
end

function OnMsg.UnitRelationsUpdated()
	for _, unit in ipairs(g_Units) do
		unit:UpdateMeleeTrainingVisual()
	end
end

-- sort units map by pos
function SortUnitsMap(units_map) 
	if not units_map or not next(units_map) then return units_map end
	local first_key = next(units_map)
	if next(units_map, first_key) == nil then 
		return {{id = first_key.session_id, unit = first_key, data = units_map[first_key]}}
	end

	local positions = {}
	for unit, data in pairs(units_map) do
		if IsValid(unit) then
			positions[#positions + 1] = {id = unit.session_id, unit = unit, data = data}		
		end
	end
	table.sortby(positions, "id")
	return positions
end

function Unit:GetBodyParts(attack_weapon)
	local list = Presets.TargetBodyPart.Default
	if self.species == "Human" then
		local head = list.Head
		if IsKindOf(attack_weapon, "MeleeWeapon") then
			head = list.Neck
		end
		return { head, list.Arms, list.Torso, list.Groin, list.Legs } 
	end
	return { list.Head, list.Torso, list.Legs } 
end

function Unit:ShowMishapNotification(action)
	if self.team.player_team then
		local text = action:GetAttackWeapons(self).DisplayName
		HideTacticalNotification("playerAttack")
		ShowTacticalNotification("playerAttack", false, T{989807512852, "<attack> Mishap", attack = text})
	else
		local text = GetTacticalNotificationText("enemyAttack") or action:GetAttackWeapons(self).DisplayName
		HideTacticalNotification("enemyAttack")
		ShowTacticalNotification("enemyAttack", false, T{989807512852, "<attack> Mishap", attack = text})
	end
	CreateFloatingText(self, T(371973388445, "Mishap!"), "FloatingTextMiss")
end

function Unit:GetValidStance(target_stance, pos)
	if target_stance == "Prone" then
		local side = self.team and self.team.side or "player1"
		local pfclass = CalcPFClass(side, "Prone", self.body_type)
		if not GetPassSlab(pos or self, pfclass) then
			return "Crouch"
		end
	end
	return target_stance
end

function Unit:CanSwitchStance(toDoStance, args)
	--no stance switch available for machineguns 
	if self:IsStanceChangeLocked() then
		return false
	end
	--no stance switch for prone - addition checks
	local action
	if toDoStance == "Standing" then
		action = "StanceStanding"
	elseif toDoStance == "Crouch" then
		action = "StanceCrouch"
	elseif toDoStance == "Prone" then
		local unitOrGotoPos = args and args.goto_pos or self
		local in_water = terrain.IsWater(unitOrGotoPos) -- disable when all the units are in water
		if in_water then 
			return false, AttackDisableReasons.Water 
		end		
		local valid_stance = self:GetValidStance("Prone", unitOrGotoPos)
		if valid_stance ~= "Prone" then
			return false, AttackDisableReasons.Stairs
		end
		action = "StanceProne"
	end
	--no stance switch avaible for lack of ap
	local cost = CombatActions[action]:GetAPCost(self, args)
	if cost < 0 then 
		return false, "hidden" 
	end
	if not self:UIHasAP(cost, action) then 
		return false, GetUnitNoApReason(self)
	end
	return true
end

function Unit:IsStanceChangeLocked()
	if IsKindOf(self:GetActiveWeapons(), "MachineGun") and (self.behavior == "OverwatchAction" or self.combat_behavior == "OverwatchAction")then 
		return true
	end
	if self:GetBandageTarget() then -- bandaging other unit
		return true
	end
	
	return false
end

MapVar("g_AttackRevealQueue", false)

function Unit:AttackReveal(action, attack_args, results)
	local attacker = self
	local target = attack_args.target
	local killed = results.killed_units or empty_table
	if not g_Combat then
		g_AttackRevealQueue = {self}
	end
	if IsKindOf(target, "Unit") and not target:IsDead() and not table.find(killed, target) then
		if g_Combat then
			self:RevealTo(target)
		else
			g_AttackRevealQueue[#g_AttackRevealQueue + 1] = target
		end
	end
	for _, hit in ipairs(results) do
		local unit = IsKindOf(hit.obj, "Unit") and not hit.obj:IsIncapacitated() and hit.obj
		if unit and unit.team ~= self.team and not unit:IsDead() and not table.find(killed, unit) then
			if g_Combat then
				self:RevealTo(unit)
			else
				g_AttackRevealQueue[#g_AttackRevealQueue + 1] = unit
			end
		end
	end
end

function Unit:OnEnemySighted(other)
	--printf("%s has seen %s", unit.unitdatadef_id, other.unitdatadef_id)
	if HasPerk(self, "AlwaysReady") and 
		not self:HasStatusEffect("Hidden") and
		g_Combat and not g_Combat:ShouldEndCombat() and
		g_Teams[g_CurrentTeam] ~= self.team and
		not self:HasPreparedAttack() and
		not self:IsThreatened(nil, "overwatch")
	then	
		self:TryActivateAlwaysReady(other)
	end
end

function Unit:GetMoveAPCost(dest)
	if not dest or not (g_Combat or g_StartingCombat) then return 0 end
	
	local move_cost = 0
	local path = GetCombatPath(self)
	move_cost = path and path:GetAP(dest)
	if not move_cost then return -1 end
	
	return Max(0, move_cost - self.free_move_ap)
end

function Unit:HasNightVision()
	if HasPerk(self, "NightOps") then
		return true
	end
	local helm = self:GetItemInSlot("Head")
	return IsKindOf(helm, "NightVisionGoggles") and helm.Condition > 0
end

function NetSyncEvents.SetAutoFace(obj, auto_face)
	if not obj or obj.auto_face == auto_face then
		return
	end
	obj.auto_face = auto_face
	-- reorientation
	if auto_face
		and obj.command == "Idle"
		and obj.stance ~= "Prone"
		and not obj.interrupt_callback
		and not IsValidThread(obj.reorientation_thread)
	then
		obj.reorientation_thread = CreateGameTimeThread(function(obj)
			Sleep(obj:Random(500))
			if obj.auto_face
				and obj.command == "Idle"
				and (obj.stance == "Standing" or obj.stance == "Crouch")
				and not obj.interrupt_callback
			then
				obj:InterruptCommand("Idle")
			end
			obj.reorientation_thread = false
		end, obj)
	end
end

function OnMsg.SelectedObjChange()
	local obj = SelectedObj
	if not obj then
		return
	end
	if not obj.auto_face then
		return
	end
	if not (g_Combat and g_Teams and g_Teams[g_CurrentTeam] == obj.team) then
		return
	end
	if not obj:IsLocalPlayerControlled() then
		return
	end
	NetSyncEvent("SetAutoFace", obj, false)
end

function OnMsg.SelectionRemoved(obj)
	if not (g_Combat and g_Teams and g_Teams[g_CurrentTeam] == obj.team) then
		return
	end
	if not obj:IsLocalPlayerControlled() then
		return
	end
	if obj.stance == "Prone" then
		return
	end
	NetSyncEvent("SetAutoFace", obj, true)
end

function OnMsg:TurnEnded(team)
	for i, unit in ipairs(g_Teams[g_CurrentTeam].units) do
		unit.auto_face = true
	end
end

-- TargetDummy
DefineClass.TargetDummy = {
	__parents = { "Movable", "SyncObject", "AppearanceObject" },
	flags = {
		efUnit = true, efVisible = false, efSelectable = false, efWalkable = false, efCollision = false,
		efPathExecObstacle = false, efResting = false,
		efApplyToGrids = false, efShadow = false, efSunShadow = false, gofOnRoof = false,
	},
	__toluacode = empty_func,
	obj = false,
	stance = false,
	locked = false,
}
DefineClass.TargetDummyLargeAnimal = {
	__parents = { "TargetDummy" },
}

function TargetDummy:Init()
	local obj = self.obj
	if obj then
		self:ApplyAppearance(obj.Appearance)
		pf.SetGroundOrientOffsets(self, table.unpack(obj:GetGroundOrientOffsets()))
	end
	self:SetDestlockRadius(obj and obj:GetDestlockRadius() or 0)
	self:SetCollisionRadius(0)
	self:SetAnimSpeed(1, 0)
	Msg("NewTargetDummy", self) -- for debug visualization
end

-- disable setting efPathExecObstacle
TargetDummy.InitPathfinder = empty_func
TargetDummy.EnterPathfinder = empty_func
TargetDummy.EnterPathfinder = empty_func

function SavegameSectorDataFixups.ClearTargetDummies(sector_data)
	local spawn_data = sector_data.spawn
	while true do
		local idx = table.find(spawn_data, "TargetDummy")
		if not idx then
			break
		end
		table.remove(spawn_data, idx + 1) -- handle
		table.remove(spawn_data, idx)     -- TargetDummy
	end
end

function IsLastUnitInTeam(units)
	local lastStanding = false
	for _, unit in ipairs(units) do
		if not unit:IsDead() and not lastStanding then
			lastStanding = unit
		elseif not unit:IsDead() and lastStanding then
			return false
		end
	end
	return lastStanding
end

function SavegameSessionDataFixups.ExpFixup(data, metadata, lua_ver)
	local ud = data.gvars.gv_UnitData
	for _, data in pairs(ud) do
		if not data.Experience then
			local minXP = XPTable[data.StartingLevel]
			data.Experience = minXP
		end
		data:RemoveModifier("ExperienceBonus", "Experience")
	end
end

UndefineClass('AdditionalGroup')
DefineClass.AdditionalGroup = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Weight", name = "Weight", editor = "number", min = 0, max = 100, default = 100, help = "Integer numbers.(0:never picked / 100:always picked)"},
		{ id = "Exclusive", name = "Mutually Exclusive", editor = "bool", default = false, 
		help = "If marked as exclusive, only one will be chosen from all marked as exclusive. NB: If only one is marked as exclusive and weight > 0, it will be ALWAYS picked." },
		{ id = "Name", name = "Name", editor = "text", default = "", help = "The name of the group." },
	},
}

function AdditionalGroup:EditorView()
	return string.format("AdditionalGroup %s", self.Name and self.Name ~= "" and ("- " .. self.Name) or "")
end

function Unit:IsConcealedFrom(observer)
	return GameState.Fog and not self.indoors and not IsCloser(self, observer, const.EnvEffects.FogUnkownFoeDistance)
end

function Unit:IsObscuredFrom(observer)
	return GameState.DustStorm and not self.indoors and not IsCloser(self, observer, const.EnvEffects.DustStormUnkownFoeDistance)
end

function HasThermalVision(units)
	for _, unit in ipairs(units) do
		local _, _, weapons = unit:GetActiveWeapons()
		for _, weapon in ipairs(weapons) do
			if weapon:HasComponent("IgnoreConcealAndObscure") then
				return true
			end
		end
	end
end

function Unit:UIObscured()
	local side = self.CurrentSide or (self.team and self.team.side)
	if not side or side == "player1" or side == "player2" or side == "ally" then
		return false
	end
	if not GameState.DustStorm then
		return false
	end

	local units = Selection or empty_table
	if #units == 0 then
		local team = GetPoVTeam()
		units = team and team.units
	end
	local obscured = true
	for _, unit in ipairs(units) do
		obscured = obscured and CheckSightCondition(unit, self, const.usObscured)
	end
	return obscured
end

function Unit:UIConcealed(skip_check)
	local side = self.CurrentSide or (self.team and self.team.side)
	if not side or side == "player1" or side == "player2" or side == "ally" then
		return false
	end
	if not GameState.Fog then
		return false
	end
	if not skip_check and HasThermalVision(Selection) then 
		return false 
	end
	
	local concealed = true
	local units = Selection or empty_table
	if #units == 0 then
		local team = GetPoVTeam()
		units = team and team.units
	end
	for _, unit in ipairs(units) do
		concealed = concealed and CheckSightCondition(unit, self, const.usConcealed)
	end
	return concealed
end

function Unit:GetDisplayName()
	if self:UIObscured() or self:UIConcealed() then
		return T(393866533740, "???")
	end
	
	return UnitProperties.GetDisplayName(self)
end

function Unit:HasVisibleEffects()
	if self.team.neutral then return false end
	return StatusEffectObject.HasVisibleEffects(self)
end

function Unit:FastForwardCommand()
	if self.command == "ExitMap" and not self:HasStatusEffect("DontFastForwardExit") then
		self:Despawn()
	end
end

function Unit:SetCommandIfNotDead(...)
	if self:IsDead() or self.command == "Die" then return end
	self:SetCommand(...)
end