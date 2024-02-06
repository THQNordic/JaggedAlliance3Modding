DefineClass.StateObject =
{
	__parents = { "CooldownObj" },
	__hierarchy_cache = true,

	so_state = false,
	so_enabled = false,
	so_action = false,
	so_action_param = false,
	so_target = false,
	so_active_zone = false,
	so_anim_control_thread = false,
	so_movement_thread = false,
	so_state_time_start = 0,
	so_target_trigger = false,
	so_tick_enable = false,
	so_tick_thread = false,
	so_aitick_enable = true,
	so_aitick_thread = false,
	so_context = false,
	so_changestateidx = 0,  -- times state has been changed
	so_prev_different_state_id = false, -- TODO: for debug only, remove this member
	so_next_state_id = false,
	so_trigger_object = false,
	so_trigger_action = false,
	so_trigger_target = false,
	so_trigger_target_pos = false,
	so_cooldown = "",
	so_buffered_trigger = false,
	so_buffered_trigger_object = false,
	so_buffered_trigger_action = false,
	so_buffered_trigger_target = false,
	so_buffered_trigger_target_pos = false,
	so_buffered_trigger_time = false,
	so_buffered_times = false,

	so_debug_triggers = config.StateObjectTraceLog or false,
	so_state_start_time = false,
	so_changestateidx_at_start_time = 0, -- so_changestateidx when first change_state in this tick

	so_states = false,

	so_state_debug = false,
	so_compensate_anim_rotation = {},
	so_compensate_angle = false,
	so_context_sync = false,
	so_state_destructors = false,
	so_step_modifier = 100,
	so_speed_modifier = 100,
	so_state_anim_speed_modifier = 100,
	so_action_start_passed = false,
	so_action_hit_passed = false,
	so_wait_phase_threads = false,
	so_repeat = false,
	so_repeat_thread = false,
	so_net_sync_stateidx = false,
	so_net_nav = false,
	so_net_pos = false,
	so_net_pos_time = false,
	so_net_nav_sent_time = false,
	so_net_target = false,
	so_net_target_sent_time = false,
	so_net_target_thread = false,
}

function FindStateSet( class )
	local check_classes = { class }

	while #check_classes > 0 do
		local name = table.remove(check_classes, 1)
		local set = DataInstances.StateSet[name]

		if set then
			return set
		end

		local parents = _G[name].__parents
		for i = 1, #parents do
			table.insert(check_classes, parents[i])
		end
	end
end

function StateObject:Init()
	local set = FindStateSet( self.class )
	if set then
		self.so_states = set.so_states
	end

	--[[
	-- find the state set
	local check_classes = { self.class }
	while #check_classes > 0 do
		local name = table.remove(check_classes, 1)
		local set = DataInstances.StateSet[name]
		if set then
			self.so_states = set.so_states
			break
		end
		local parents = _G[name].__parents
		for i = 1, #parents do
			table.insert(check_classes, parents[i])
		end
	end
	]]
	if Platform.developer then
		if not self.so_tick_enable then
			for state_name, state_data in sorted_pairs(self.so_states) do
				for i_trigger = 1, #state_data do
					local trigger = state_data[i_trigger].trigger
					if trigger == "Tick" then
						assert(false, string.format("\"Tick\" trigger used in state \"%s\" of state object \"%s\" with \"so_tick_enable = false\"", state_name, self.class))
						break
					end
				end
			end
		end
	end
end

function StateObject:Done()
	if self.so_state then
		self:ChangeState(false)
		if self.so_state then
			printf("ERROR: %s entered state %s on destroy!", self.class, self.so_state.name)
		end
	end
end

function StateObject:PushStateDestructor(dtor)
	local destructors = self.so_state_destructors
	if destructors then
		local count = destructors[1] + 1
		destructors[1] = count
		destructors[count + 1] = dtor
	else
		self.so_state_destructors = { 1, dtor }
	end
end

function StateObject:ChangeSet(name)
	local set = DataInstances.StateSet[name]
	if set then
		self.so_states = set.so_states
	end
end

function StateObject:ChangeStateIfDifferent(state_id)
	if not self.so_state or self.so_state.name ~= state_id then
		self:ChangeState(state_id)
	end
end

MaxChangeStates = 10
CriticChangeStates = 15

function StateObject:InternalChangeState(state_id, is_triggered, trigger_object, trigger_action, trigger_target, trigger_target_pos, forced_target, forced_target_state)
	if self.so_debug_triggers then
		self:Trace("[StateObject1]<color 0 255 0>State changed</color> {1} prev {2}\n{3}", state_id, self.so_state, trigger_object, trigger_action, trigger_target, trigger_target_pos, self:GetPos(), self:GetAngle(), GetStack(1))
	end
	self.so_enabled = (state_id or "") ~= ""
	self.so_next_state_id = state_id
	if self.so_state then
		if self.so_cooldown ~= "" then
			self:SetCooldown(self.so_cooldown)
		end
		local destructors = self.so_state_destructors
		local count = destructors and destructors[1] or 0
		while count > 0 do
			local dtor = destructors[count + 1]
			destructors[count + 1] = false
			destructors[1] = count - 1
			dtor(self)
			count = destructors[1]
		end
		if self.so_action_start_passed then
			self.so_action_start_passed = false
			local stateidx = self.so_changestateidx
			self:StateActionMoment("end")
			if stateidx ~= self.so_changestateidx then return end
		end
	end
	if self.so_compensate_angle then
		self:SetAngle(self:GetAngle() + self.so_compensate_angle, 0)
		self.so_compensate_angle = false
	end
	local state = false
	if (state_id or "") ~= "" then
		state = self.so_states[state_id]
		if not state then
			printf('%s invalid state "%s"', self.class, state_id)
			self:InternalChangeState(self.so_states.Error and "Error" or false)
			return
		end
	end
	self.so_changestateidx = self.so_changestateidx + 1
	local stateidx = self.so_changestateidx
	self.so_next_state_id = false
	if is_triggered and self.so_state_start_time == GameTime() then
		local times = self.so_changestateidx - self.so_changestateidx_at_start_time
		if times > MaxChangeStates then
			local error_msg = string.format('%s has too many state changes: "%s" --> "%s" --> "%s"', self.class, tostring(self.so_prev_different_state_id), self.so_state and self.so_state.name or "false", tostring(state_id))
			assert(times ~= MaxChangeStates + 1, error_msg) -- only once
			print(error_msg)
			if self.so_changestateidx - self.so_changestateidx_at_start_time > CriticChangeStates then
				if state_id and state_id ~= "Error" then
					self:InternalChangeState(self.so_states.Error and "Error" or false)
					return
				end
			end
		end
	else
		self.so_state_start_time = GameTime()
		self.so_changestateidx_at_start_time = self.so_changestateidx
	end
	self:WakeupWaitPhaseThreads()

	self:SetMoveSys(false)
	if self.so_anim_control_thread and self.so_anim_control_thread ~= CurrentThread() then
		DeleteThread(self.so_anim_control_thread)
	end
	self.so_anim_control_thread = nil
	self.so_repeat = nil
	self.so_repeat_thread = nil
	self.so_net_target = nil
	self.so_net_target_sent_time = nil
	if self.so_net_target_thread then
		DeleteThread(self.so_net_target_thread)
		self.so_net_target_thread = nil
	end

	Msg(self)

	self.so_target_trigger = false

	if not state then
		-- disable state machine
		self.so_state = nil
		self.so_action = nil
		self.so_action_param = nil
		self.so_target = nil
		self.so_active_zone = nil
		self.so_state_time_start = nil
		self.so_buffered_trigger = nil
		self.so_buffered_trigger_time = nil
		self.so_trigger_object = nil
		self.so_trigger_action = nil
		self.so_trigger_target = nil
		self.so_trigger_target_pos = nil
		self.so_buffered_times = nil
		if CurrentThread() ~= self.so_tick_thread then
			DeleteThread(self.so_tick_thread)
		end
		self.so_tick_thread = nil
		if CurrentThread() ~= self.so_aitick_thread then
			DeleteThread(self.so_aitick_thread)
		end
		self.so_aitick_thread = nil
		self.so_step_modifier = nil
		self.so_state_anim_speed_modifier = nil
		self:SetModifiers("StateAction", nil)
		self:NewStateStarted()
		return
	end
	local same_state = self.so_state == state
	if not same_state then
		self.so_prev_different_state_id = self.so_state and self.so_state.name or false -- TODO: debug, remove this line
		self.so_state = state
	end
	if self.so_state_debug then
		self.so_state_debug:SetText(self.so_state.name)
	end
	self.so_action = self:GetStateAction()
	self.so_action_param = false

	-- Start
	self.so_state_time_start = GameTime()
	self.so_active_zone = "Start"
	self.so_state_time_start = GameTime()
	self.so_action_hit_passed = false

	self:StateChanged()

	-- Target
	local target = forced_target
	if forced_target == nil then
		target = self:FindStateTarget(self.so_state, trigger_object, trigger_action, trigger_target, trigger_target_pos)
		if stateidx ~= self.so_changestateidx then
			return
		end
	end
	self.so_trigger_object = trigger_object
	self.so_trigger_action = trigger_action
	self.so_trigger_target = trigger_target
	self.so_trigger_target_pos = trigger_target_pos
	self:SetStateTarget(target)
	self.so_net_target = self.so_target
	self.so_cooldown = self.so_state:GetInheritProperty(self, "cooldown") or ""

	-- Startup triggers
	self:RaiseTrigger("Start", trigger_object, trigger_action, trigger_target, trigger_target_pos)
	if stateidx ~= self.so_changestateidx then
		return -- this function calls itself recursively and should exit when state is changed
	end
	self:ExecBufferedTriggers()
	if stateidx ~= self.so_changestateidx then
		return -- this function calls itself recursively and should exit when state is changed
	end
	if self.so_tick_enable then
		self:RaiseTrigger("Tick")
		if stateidx ~= self.so_changestateidx then
			return -- this function calls itself recursively and should exit when state is changed
		end
	end
	self:RaiseTrigger("AITick")
	if stateidx ~= self.so_changestateidx then
		return -- this function calls itself recursively and should exit when state is changed
	end

	if forced_target_state then
		target:InternalChangeState(forced_target_state, is_triggered, self, false, false, false, self)
		if stateidx ~= self.so_changestateidx then
			return -- this function calls itself recursively and should exit when state is changed
		end
	else
		local target_trigger = self.so_state:GetInheritProperty(self, "target_trigger")
		if target_trigger and target_trigger ~= "" then
			if self:RaiseTargetTrigger(target_trigger) then
				self.so_target_trigger = target_trigger
			end
			if stateidx ~= self.so_changestateidx then
				return -- this function calls itself recursively and should exit when state is changed
			end
		end
	end
	if self.so_tick_enable and not self.so_tick_thread then
		self.so_tick_thread = CreateGameTimeThread(function(self)
			while self.so_tick_thread == CurrentThread() do
				Sleep(33)
				self:RaiseTrigger("Tick")
			end
		end, self)
		ThreadsSetThreadSource(self.so_tick_thread, "Tick trigger")
	end
	if self.so_aitick_enable and not self.so_aitick_thread then
		self.so_aitick_thread = CreateGameTimeThread(function(self)
			Sleep(BraidRandom(self.handle, 500))
			while self.so_aitick_thread do
				self:RaiseTrigger("AITick")
				Sleep(500)
			end
		end, self)
		ThreadsSetThreadSource(self.so_aitick_thread, "AITick trigger")
	end

	if self.so_state.restore_axis then
		self:SetAxis(axis_z, 100)
	end

	local state_lifetime = self.so_state:GetInheritProperty(self, "state_lifetime")
	if state_lifetime == "" then
		state_lifetime = "animation"
	end
	local anim = self.so_state:GetAnimation(self)
	self.so_compensate_angle = self.so_compensate_anim_rotation[anim] or false
	if anim ~= "" and not self:HasState(anim) then
		printf("Invalid animation %s for %s!", anim, self.class)
		if state_lifetime == "animation" then
			self:NextState()
			return
		end
	end
	if state_lifetime == "animation" and anim == "" then
		state_lifetime = "movement" -- backward compatibility
	end
	self:NewStateStarted()
	self:SetStateAnim(self.so_state, anim)
	local movement = self.so_state:GetInheritProperty(self, "movement")
	self:SetMoveSys(movement, state_lifetime == "movement")
	if stateidx ~= self.so_changestateidx then return end
	if state_lifetime == "animation" then
		self:StartStateAnimControl()
	else
		local state_duration = tonumber(state_lifetime)
		if state_duration then
			self.so_anim_control_thread = CreateGameTimeThread(function(self, stateidx, state_duration)
				Sleep(state_duration)
				if stateidx ~= self.so_changestateidx then return end
				self:NextState()
			end, self, stateidx, state_duration)
		end
	end
	self:SetModifiers("StateAction", self.so_action and self.so_action.modifiers)
	local animation_step = self.so_state:GetInheritProperty(self, "animation_step")
	self.so_step_modifier = tonumber(animation_step)
	local animation_speed = self.so_state:GetInheritProperty(self, "animation_speed")
	if animation_speed == "" then
		animation_speed = 100
	elseif StateAnimationSpeedCorrection[animation_speed] then
		animation_speed = StateAnimationSpeedCorrection[animation_speed](self)
	else
		animation_speed = tonumber(animation_speed)
	end
	self.so_state_anim_speed_modifier = animation_speed
	self:UpdateAnimSpeed()
	self:StateActionMoment("start")
end

function StateObject:StateChanged()
end

function StateObject:NewStateStarted()
	self:ClearPath()
end

function StateObject:StartStateAnimControl(obj)
	local stateidx = self.so_changestateidx
	self.so_anim_control_thread = CreateGameTimeThread(function(self, obj, stateidx)
		obj = obj or self
		-- PreAction
		obj:WaitPhase(obj:GetStateAnimPhase("Start"))
		-- Action
		self:StateActionMoment("action")
		if stateidx ~= self.so_changestateidx then return end
		obj:WaitPhase(obj:GetStateAnimPhase("Hit"))
		-- Hit
		self:StateActionMoment("hit")
		if stateidx ~= self.so_changestateidx then return end
		obj:WaitPhase(obj:GetStateAnimPhase("End"))
		-- PostAction
		self:StateActionMoment("post-action")
		if stateidx ~= self.so_changestateidx then return end
		obj:WaitPhase(obj:GetLastPhase())
		-- End state
		if stateidx ~= self.so_changestateidx then return end
		self:NextState()
	end, self, obj, stateidx)
	ThreadsSetThreadSource(self.so_anim_control_thread, "Animation control")
end

function StateObject:SetStateAnim(state, anim, flags, crossfade, animation_phase)
	anim = anim or state:GetAnimation(self)
	if anim == "" then return end
	animation_phase = animation_phase or state:GetInheritProperty(self, "animation_phase")
	local old_anim = self:GetAnim(1)
	local same_anim = old_anim == EntityStates[anim]
	if same_anim and (animation_phase == "KeepSameAnimPhase" or animation_phase == "KeepSameAnimPhaseBeforeHit" and self:GetAnimPhase(1) < self:GetStateAnimPhase("Hit", anim, state)) then
		return
	end
	if not flags then
		flags = 0
	end
	if not crossfade then
		if same_anim and self:IsAnimLooping(1) then
			crossfade = -1
		else
			local animation_blending = state:GetInheritProperty(self, "animation_blending")
			local dontCrossfade = self.so_compensate_anim_rotation[anim] or animation_blending == "no"
			crossfade = dontCrossfade and 0 or -1
		end
	end
	self:SetAnim(1, anim, flags, crossfade)
	
	if Platform.developer and not same_anim and SelectionEditorShownSpots[self] and self:GetEntity() then
		if GetStateMeshFile(self:GetEntity(), old_anim) ~= GetStateMeshFile(self:GetEntity(), EntityStates[anim]) then
			local window, window_id = PropEditor_GetFirstWindow("SelectionEditor")
			if window then
				local selection_editor = window.main_obj
				if selection_editor:IsKindOf("SelectionEditor") and selection_editor[1] == self then
					selection_editor:ToggleSpots()
					selection_editor:ToggleSpots()
				end
			end
		end
	end
	
	local start_phase
	if animation_phase ~= "" and not (same_anim and animation_phase == "Random") then
		start_phase = self:GetStateAnimPhase(animation_phase, anim, state)
	end
	if start_phase and start_phase > 0 then
		self:SetAnimPhase(1, start_phase)
	end
end

function StateObject:GetLastPhase(channel)
	local duration = GetAnimDuration(self:GetEntity(), self:GetAnim(channel or 1))
	return duration-1
end

function StateObject:WaitPhase(phase)
	local cur_phase = self:GetAnimPhase(1)
	local last_phase = self:GetLastPhase(1)
	phase = Min(phase, last_phase)
	
	local t = self:TimeToPhase(1, phase) or 0
	if t == 0 then
		return true
	end
	self.so_wait_phase_threads = self.so_wait_phase_threads or {}
	table.insert(self.so_wait_phase_threads, CurrentThread())
	local stateidx = self.so_changestateidx
	local interrupted
	while true do
		WaitWakeup(t)
		if not IsValid(self) or stateidx ~= self.so_changestateidx then
			interrupted = true
			break
		end
		t = self:TimeToPhase(1, phase) or 0
		if t == 0 then
			break
		end
		if self:IsAnimLooping(1) then
			local prev_phase = cur_phase
			cur_phase = self:GetAnimPhase(1)
			if cur_phase >= prev_phase then
				if phase >= prev_phase and phase <= cur_phase then
					break
				end
			elseif phase <= cur_phase or phase >= prev_phase then
				break
			end
		end
	end
	table.remove_value(self.so_wait_phase_threads, CurrentThread())
	return not interrupted
end

function StateObject:UpdateAnimSpeed(mod)
	mod = mod or self.so_state_anim_speed_modifier
	self.so_speed_modifier = mod
	self:SetAnimSpeed(1, mod * 10)
	self:SetAnimSpeed(2, mod * 10)
	self:SetAnimSpeed(3, mod * 10)
	self:WakeupWaitPhaseThreads()
	if self:IsKindOf("AnimMomentHook") then
		self:AnimMomentHookUpdate()
	end
end

function StateObject:WakeupWaitPhaseThreads()
	local wait_phase_threads = self.so_wait_phase_threads
	if not wait_phase_threads then return end
	for i = #wait_phase_threads, 1, -1 do
		if not Wakeup(wait_phase_threads[i]) then
			table.remove(wait_phase_threads, i)
		end
	end
end

function StateObject:ChangeState(...)
	return self:InternalChangeState(...)
end

function StateObject:NetSyncState(trigger_id, trigger)
	if not netInGame or not self.so_state or self.so_net_sync_stateidx == self.so_changestateidx then
		return
	end
	local net_nav, trigger_target_pos, channeling_stopped, split_time, torso_angle
	if NetIsLocal(self) then
		if not (trigger and trigger.net_sync) and trigger_id and not State.net_triggers[trigger_id] then
			return
		end
		net_nav = self:GetStateContext("navigation_vector")
		self.so_net_nav_sent_time = GameTime()
		trigger_target_pos = IsPoint(self.so_trigger_target_pos) and self.so_trigger_target_pos
		if self:IsKindOf("Hero") then
			channeling_stopped = self:IsChannelingStopped()
			split_time = self.split_time
			if self.torso_control then
				torso_angle = self.torso_obj:GetAngle()
			end
		end
	elseif IsKindOf(self, "Monster") then
		if not (trigger and trigger.net_sync) then
			if not self.so_action or not self.so_action:IsMonsterNetSyncAction(self) or not NetIsLocal(self.monster_target) then
				return
			end
		end
	else
		return
	end
	self.so_net_sync_stateidx = self.so_changestateidx
	self.so_net_pos = self:IsValidPos() and self:GetVisualPos()
	self.so_net_pos_time = GameTime()
	--printf("Net sync state: %s, %s, pos=%s", self.class, (self.so_state and self.so_state.name or "false"), tostring(self.so_net_pos))
	local step_time = self:TimeToPosInterpolationEnd()
	if step_time == 0 then step_time = nil end
	local step = step_time and self:GetPos() - self:GetVisualPos()
	local angle, attack_angle = self:GetAngle(), self:GetAttackAngle()
	local target = self.so_target and (IsPoint(self.so_target) and self.so_target or NetValidate(self.so_target)) or false
	local state_handle = self.so_state and StateHandles[self.so_state.name]

	NetEventOwner("ChangeState",
		self, state_handle, target, trigger_target_pos,
		self.so_net_pos or nil, step, step_time, angle, attack_angle,
		net_nav, channeling_stopped, split_time, torso_angle
	)
end

function StateObject:RaiseTargetTrigger(trigger_id)
	if trigger_id and trigger_id ~= "" then
		local target = self.so_target
		if IsValid(target) and target:IsKindOf("StateObject") then
			local trigger_processed = target:RaiseTrigger(trigger_id, self)
			if trigger_processed then
				return true
			end
		end
	end
	--printf("Target trigger failed: %s / %s -> %s -> %s / %s / %s", self.class, self.so_state.name, trigger_id, target and target.class or "no target", target and target.so_state and target.so_state.name or "no state", not target and "" or tostring(target.so_active_zone))
end

local cached_empty_table
function StateObject:RaiseTrigger(trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed, level)
	level = level or 0
	assert(level < 128)
	if level >= 130 then
		return
	end
	local state = self.so_state
	if not state or not self.so_enabled then
		return -- state machine disabled
	end
	if not trigger_id or trigger_id == "" then
		return
	end
	time_passed = time_passed or 0
	if self.so_debug_triggers then
		if trigger_id == "AITick" or trigger_id == "Tick" or trigger_id == "Start" or trigger_id == "Action" or trigger_id == "Hit" or trigger_id == "End" or trigger_id == "PostAction" then
			self:Trace("[StateObject2]<color 128 128 255>RaiseTrigger {1} current state {2} trigger object {3}</color>", trigger_id, state, trigger_object, trigger_action, trigger_target, trigger_target_pos)
		else
			self:Trace("[StateObject1]<color 128 128 255>RaiseTrigger {1} current state {2} trigger object {3}</color>", trigger_id, state, trigger_object, trigger_action, trigger_target, trigger_target_pos)
		end
	end

	-- combo buffer could be kept, and various combo length combinations finishing with trigger_id could be tested
	local matched_triggers = cached_empty_table or {}
	cached_empty_table = nil
	local trigger = state:ResolveTrigger(self, trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed, false, matched_triggers)
	if #matched_triggers == 0 then
		cached_empty_table = matched_triggers
	end
	local state_id = trigger and trigger.state
	if trigger_id == "Start" and state.name == state_id then
		return
	end
	local consumed = false
	local buffer_trigger  = State.buffered_triggers[trigger_id]
	if buffer_trigger then
		self.so_buffered_trigger = false
	end

	-- run functions of matched triggers (including "copy_triggers")
	for i = 1, #matched_triggers do
		local trig = matched_triggers[i]
		if trig.cooldown_to_set ~= "" then
			consumed = true
			self:SetCooldown(trig.cooldown_to_set)
		end
		if trig.next_state ~= "" then
			consumed = true
			self.so_next_state_id = trig.next_state
		end
		if trig.func ~= "" then
			if trig.state ~= "continue" then
				consumed = true
			end
			local f = TriggerFunctions[trig.func]
			if f then
				local stateidx = self.so_changestateidx
				local ret = f(trig, self, trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed)
				if stateidx ~= self.so_changestateidx then
					self:NetSyncState(trigger_id, trig)
					return true -- the function could decide to change state
				elseif ret and ret == "break" then
					return true --the function asked us to terminate this trigger chain
				end
			else
				print("Unknown trigger function " .. trig.func)
			end
		end
		if trig.raise_trigger ~= "" then
			local stateidx = self.so_changestateidx
			self:RaiseTrigger(trig.raise_trigger, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed, level + 1)
			if stateidx ~= self.so_changestateidx then
				return true
			end
		end
	end

	if state_id and state_id ~= "" and state_id ~= "break" and state_id ~= "continue" and (state_id ~= state.name or self.so_active_zone ~= "Start" or self.so_target ~= self:FindStateTarget(self.so_state, trigger_object, trigger_action, trigger_target, trigger_target_pos)) then
		if state_id ~= "consume_trigger" then
			self:ChangeState(state_id, true, trigger_object, trigger_action, trigger_target, trigger_target_pos)
			local inherit_trigger_id = trigger and trigger.trigger
			if inherit_trigger_id ~= trigger_id then
				-- recast the original trigger to allow base trigger processing and dispath
				-- the object should be in Start zone to check for dispatch
				if self.so_debug_triggers then
					self:Trace("[StateObject2]Inherited trigger " .. inherit_trigger_id)
				end
				local old_zones = self.so_active_zone
				self.so_active_zone = "Start"
				local trigger_processed = self:RaiseTrigger(trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed, level+1)
				if not trigger_processed then
					self.so_active_zone = old_zones
				end
			end
			self:NetSyncState(trigger_id, trigger)
		end
		return true
	end
	if consumed then
		return true
	end
	if buffer_trigger then
		self:BufferTrigger(trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos)
	end
end

function StateObject:ApplyMatchedTrigger(handle, trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed)
	if not TriggerHandles then
		assert(false, "Trigger handles not defined!")
		return
	end
	local trig = TriggerHandles[handle]
	if not trig then
		assert(false, "Error resolving trigger from handle")
		return
	end
	local function_id = trig.func
	local cooldown_to_set = trig.cooldown_to_set
	if cooldown_to_set ~= "" then
		self:SetCooldown(cooldown_to_set)
	end
	if function_id and function_id ~= "" then
		local f = TriggerFunctions[function_id]
		if f then
			f(trig, self, trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos, time_passed)
		else
			print("Unknown trigger function " .. function_id)
		end
	end
	if trig.next_state ~= "" then
		self.so_next_state_id = trig.next_state
	end
end

function StateObject:IsStateChangeAllowed()
	return true
end

function StateObject:BufferTrigger(trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos)
	self.so_buffered_trigger = trigger_id
	self.so_buffered_trigger_object = trigger_object
	self.so_buffered_trigger_action = trigger_action
	self.so_buffered_trigger_target = trigger_target
	self.so_buffered_trigger_target_pos = trigger_target_pos
	self.so_buffered_trigger_time = GameTime()
	self.so_buffered_times = self.so_buffered_times or {}
	self.so_buffered_times[trigger_id] = self.so_buffered_trigger_time
end

function StateObject:ExecBufferedTriggers()
	local trigger_id = self.so_buffered_trigger
	if not trigger_id then
		return
	end
	self.so_buffered_trigger = false
	local trigger_time = self.so_buffered_trigger_time
	local time_passed = GameTime() - trigger_time
	if time_passed > State.triggers_buffered_time then
		return -- expired
	end
	if self:RaiseTrigger(trigger_id, self.so_buffered_trigger_object, self.so_buffered_trigger_action, self.so_buffered_trigger_target, self.so_buffered_trigger_target_pos, time_passed) then
		-- trigger consumed
	else
		-- restore the buffered trigger when not processed
		self.so_buffered_trigger_time = trigger_time
	end
end

function StateObject:IsTriggerResolved(trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos)
	local state = self.so_state
	local trigger = state and state:ResolveTrigger(self, trigger_id, trigger_object, trigger_action, trigger_target, trigger_target_pos)
	if trigger then
		local state_id, function_id = trigger.state, trigger.func
		if function_id and function_id ~= "" or state_id and state_id ~= "" and state_id ~= "break" and state_id ~= "continue" then
			return true
		end
	end
	return false
end

function StateObject:FindStateTarget(state, trigger_object, trigger_action, trigger_target, trigger_target_pos, debug_level)
	local target
	local target_group = state:GetInheritProperty(self, "target")
	if target_group ~= "" then
		target = StateTargets[target_group](self, state, trigger_object, trigger_action, trigger_target, trigger_target_pos, debug_level)
	end
	return target or false
end

function StateObject:SetStateTarget(target)
	if self.so_debug_triggers then
		self:Trace("[StateObject1]<color 0 255 0>Target {1} for state {2}</color>", target, self.so_state)
	end
	self.so_target = target
end

function StateObject:ChangeStateTarget(target)
	if self.so_target == (target or false) then
		return
	end
	if self.so_target and not IsPoint(self.so_target) then
		self:StateActionMoment("target_lost")
	end
	self:SetStateTarget(target)
	if self.so_target and not IsPoint(self.so_target) then
		self:StateActionMoment("new_target")
	end
end

function StateObject:NextState()
	local next_state_id = self.so_next_state_id or self.so_state:GetInheritProperty(self, "next_state")
	local elapsed_time = GameTime() - self.so_state_time_start
	if elapsed_time == 0 or not self.so_context_sync then
		if next_state_id == self.so_state.name and elapsed_time == 0 then
			printf('%s hangs in state "%s"', self.class, next_state_id)
			Sleep(1000)
		end
		self:InternalChangeState(next_state_id, true)
	else
		self:ChangeState(next_state_id)
	end
end

function StateObject:SetMoveSys(movement, next_state_on_finish)
	if CurrentThread() ~= self.so_movement_thread then
		DeleteThread(self.so_movement_thread)
	end
	local move_sys = movement and (type(movement) == "function" and movement or StateMoveSystems[movement])
	if not move_sys then
		self.so_movement_thread = nil
		if next_state_on_finish then
			self:NextState()
		end
		return
	end
	local stateidx = self.so_changestateidx
	self.so_movement_thread = CreateGameTimeThread(function(self, stateidx, next_state_on_finish, move_sys)
		if stateidx == self.so_changestateidx then
			move_sys(self)
		end
		if next_state_on_finish and stateidx == self.so_changestateidx then
			self:NextState()
		end
	end, self, stateidx, next_state_on_finish, move_sys)
	ThreadsSetThreadSource(self.so_movement_thread, "Movement system")
end

function StateObject:ModifyStateContext(id, value)
	self:SetStateContext(id, (self:GetStateContext(id) or 0) + value)
end

function StateObject:SetStateContext(id, value)
	local so_context = self.so_context
	local old_value
	if not so_context then
		so_context = {}
		self.so_context = so_context
	else
		old_value = so_context[id]
	end
	so_context[id] = value
	return old_value
end

function StateObject:GetStateContext(id)
	local so_context = self.so_context
	if so_context then
		return so_context[id]
	end
end

function StateObject:HasCooldown(cooldown_id)
	if (cooldown_id or "") == "" then
		return false
	end
	if self.so_cooldown == cooldown_id then
		return true
	end
	return CooldownObj.HasCooldown(self, cooldown_id)
end

function StateObject:GetStateAction(state_id)
	local state
	if state_id then
		state = self.so_states[state_id]
	else
		state = self.so_state
	end
	local classname = state and state:GetInheritProperty(self, "action")
	return classname and classname ~= "" and g_Classes[classname]
end

function StateObject:StateActionMoment(moment, ...)
	local stateidx = self.so_changestateidx
	local trigger, buffered_triggers, ai_tick
	if moment == "start" then
		-- the triggers are raised earlier on state change
		self.so_action_start_passed = true
	elseif moment == "action" then
		self.so_active_zone = "Action"
		trigger = "Action"
		ai_tick = true
	elseif moment == "hit" then
		self.so_active_zone = "Action"
		self.so_action_hit_passed = true
		trigger = "Hit"
	elseif moment == "post-action" then
		if not self.so_action_hit_passed then
			self:StateActionMoment("hit")
		end
		self.so_active_zone = "PostAction"
		trigger = "PostAction"
		buffered_triggers = true
		ai_tick = true
	elseif moment == "end" then
		if not self.so_action_hit_passed then
			self:StateActionMoment("interrupted")
		end
		if self.so_target then
			self:StateActionMoment("target_lost")
		end
		trigger = "End"
	end
	local action = self.so_action
	if action then
		action:Moment(moment, self, ...)
		if stateidx ~= self.so_changestateidx then return end
	end
	if buffered_triggers then
		self:ExecBufferedTriggers()
		if stateidx ~= self.so_changestateidx then return end
	end
	if trigger then
		self:RaiseTrigger(trigger)
		if stateidx ~= self.so_changestateidx then return end
	end
	if ai_tick then
		self:RaiseTrigger("AITick")
		if stateidx ~= self.so_changestateidx then return end
	end
	if moment == "start" then
		if IsValid(self.so_target) then
			self:StateActionMoment("new_target")
			if stateidx ~= self.so_changestateidx then return end
		end
		self.so_active_zone = "PreAction"
	end
end

function StateObject:GetStateAnimPhase(id, anim, state)
	if id == "" then return 0 end
	state = state == nil and self.so_state or state
	anim = anim or state and state:GetAnimation(self)
	anim = anim ~= "" and anim or self:GetStateText()
	local phase
	if id == "Hit" then
		if state and state:GetInheritProperty(self, "override_moments") == "yes" then
			local prop = state:GetInheritProperty(self, "animation_hit")
			phase = tonumber(prop)
		end
		if not phase or phase < 0 then
			phase = self:GetAnimMoment(anim, id) or 0
		end
	elseif id == "Start" then
		if state and state:GetInheritProperty(self, "override_moments") == "yes" then
			local prop = state:GetInheritProperty(self, "animation_start")
			phase = tonumber(prop)
		end
		if not phase or phase < 0 then
			phase = self:GetAnimMoment(anim, id) or 0
		end
	elseif id == "End" then
		if state and state:GetInheritProperty(self, "override_moments") == "yes" then
			local prop = state:GetInheritProperty(self, "animation_end")
			phase = tonumber(prop)
		end
		if not phase or phase < 0 then
			phase = self:GetAnimMoment(anim, id) or GetAnimDuration(self:GetEntity(), anim) - 1
		end
	elseif id == "LastPhase" then
		phase = GetAnimDuration(self:GetEntity(), anim) - 1
	elseif id == "Random" then
		phase = self:StateRandom(GetAnimDuration(self:GetEntity(), anim))
	elseif type(id) == "number" then
		phase = id
	elseif id == "TargetHit" then
		if IsValid(self.so_target) then
			phase = self.so_target:GetStateAnimPhase("Hit")
		end
	else
		phase = self:GetAnimMoment(anim, id)
	end
	return phase or 0
end

function StateObject:TimeToStartMoment()
	local phase = self:GetStateAnimPhase("Start")
	local time = self:TimeToPhase(1, phase)
	return time
end

function StateObject:TimeToEndMoment()
	local phase = self:GetStateAnimPhase("End")
	local time = self:TimeToPhase(1, phase)
	return time
end

function StateObject:TimeToHitMoment()
	local phase = self:GetStateAnimPhase("Hit")
	local time = self:TimeToPhase(1, phase)
	return time
end

function StateObject:WaitEndMoment()
	local phase = self:GetStateAnimPhase("End")
	local result = self:WaitPhase(phase)
	return result
end

function StateObject:WaitHitMoment()
	local phase = self:GetStateAnimPhase("Hit")
	local result = self:WaitPhase(phase)
	return result
end

function StateObject:WaitStateChanged()
	WaitMsg(self)
end

function StateObject:WaitStateExit(state)
	while self.so_state and self.so_state.name == state do
		WaitMsg(self)
	end
end

function StateObject:StateDebug(show)
	if self.so_state_debug and not show then
		self.so_state_debug:delete()
		self.so_state_debug = false
	elseif not self.so_state_debug and show then
		self.so_state_debug = Text:new()
		self:Attach(self.so_state_debug)
		self.so_state_debug:SetText(self.so_state.name)
	end
end

function StateObject:StateRandom(range, seed)
	seed = seed or self.so_state and self.so_state.seed or 0
	seed = xxhash(seed, MapLoadRandom, self.handle)
	return (BraidRandom(seed, range))
end

function StateObject:StateRepeat(interval, func, ...)
	self.so_repeat = self.so_repeat or {}
	table.insert(self.so_repeat, { GameTime(), interval, func, ...})
	if IsValidThread(self.so_repeat_thread) then
		Wakeup(self.so_repeat_thread)
		return
	end
	self.so_repeat_thread = CreateGameTimeThread(function(self)
		while self.so_repeat_thread == CurrentThread() do
			local next_update
			local game_time = GameTime()
			local list = self.so_repeat
			local i = 1
			while i <= #list do
				local rep = list[i]
				local dt = rep[1] - game_time
				if dt == 0 then
					dt = rep[3](self.so_action, self, unpack_params(rep, 4))
					if self.so_repeat_thread ~= CurrentThread() then
						return -- the state is finished
					end
					if dt == nil then dt = rep[2] end
					if dt and dt >= 0 then
						rep[1] = game_time + dt
					else
						dt = false
						table.remove(list, i)
						i = i - 1
					end
				end
				if dt and (not next_update or next_update > dt) then
					next_update = dt
				end
				i = i + 1
			end
			if not next_update then
				return
			end
			WaitWakeup(next_update)
		end
	end, self)
end

-- MULTIPLAYER SYNCHRONIZATION:
function StateObject:GetDynamicData(data)
	local state_id = self.so_state and StateHandles[self.so_state.name]
	if state_id then
		data.state_id = state_id
		data.target = self.so_target and (IsPoint(self.so_target) and self.so_target or NetValidate(self.so_target)) or nil
		if self.so_context and next(self.so_context) ~= nil then
			data.context = self.so_context
		end
		data.so_next_state_id = self.so_next_state_id and StateHandles[self.so_next_state_id] or nil
		data.trigger_target_pos = self.so_trigger_target_pos or nil
	end
end

function StateObject:SetDynamicData(data)
	local state_id = data.state_id and StateHandles[data.state_id]
	if state_id then
		self:InternalChangeState(state_id, false,
			false,
			false,
			false,
			data.trigger_target_pos or false,
			data.target or false)
		self.so_next_state_id = data.so_next_state_id and StateHandles[data.so_next_state_id]
	end
end
