MapVar("g_UnitAlertThread", false)
MapVar("g_RepositionMarkersClaimed", {})
MapVar("g_NoiseSources", {})
MapVar("g_SuspicionThreads", {})
MapVar("g_UnitAwarenessPending", false)

GameVar("g_AwarenessLog", {})

--[[ 
	Awareness:
		Events that can raise unit Awareness or Suspicion use PushUnitAlert which determines the units who should 
			change their state	and marks them. Different types of events/triggers can behave differently, but whenever
			a unit becomes Aware they will propagate this awareness to nearby allies. Unit awareness state does NOT change.
			
		Actual state change is triggered by calling AlertPendingUnits. The function is safe to be called at any time and is
			called automatically on a number of occasons. It does not, however, guarantee the change would happen immediately.
			The change itself is handled differently, depending if the unit becomes Aware or Suspicious - Suspicious is applied
			directly as it does not involve any actions, whereas Aware involves Reposition phase (and possibly a StartCombat setpiece)
			and is handled by a dedicated AI execution phase ran in an own thread.
						
		TriggerUnitAlert is a convenience function which will call PushUnitAlert and AlertPendingUnits immediately when
			the caller only needs a single alert raised.
--]]

DefineClass.AwareReasons = {
	__parents = { "ListPreset", },
	properties = {
		{ id = "display_name", name = "Display Name", 
			editor = "text", default = false, translate = true, },
	},
}

DefineClass.NoiseTypes = {
	__parents = { "Preset", },
	properties = {
		{ id = "display_name", name = "Display Name", 
			editor = "text", default = false, translate = true, },
	},
}

if Platform.developer then
	local AwarenessLogMaxLines = 100
	function dbg_awareness_log(...)
		local msg = string.format("[%d] ", GameTime())
		for i = 1, select("#", ...) do
			local obj = select(i, ...)
			local item_str
			if IsValid(obj) then
				if IsKindOf(obj, "Unit") then
					item_str = string.format("%s (%d)", obj.unitdatadef_id, obj.handle)
				else
					item_str = obj.class
				end
			else
				item_str = tostring(obj)
			end
			msg = msg .. item_str
		end
		g_AwarenessLog = g_AwarenessLog or {}
		while #g_AwarenessLog >= AwarenessLogMaxLines do
			table.remove(g_AwarenessLog, 1)
		end
		table.insert(g_AwarenessLog, msg)
	end
else
	dbg_awareness_log = empty_func
end

function PushUnitAlert(trigger_type, ...)
	if trigger_type == "discovered" and CheatEnabled("DisableDiscoveryAlert") then
		return
	end
	local param1, param2 = ...
	NetUpdateHash("PushUnitAlert", trigger_type, param1 and param1.class or "", param2 or 0)

	local pov_team = GetPoVTeam()
	local enemies = pov_team and pov_team.units and GetAllEnemyUnits(pov_team.units[1] or false)
	local enemies_alive
	for _, unit in ipairs(enemies) do
		if IsValidTarget(unit) then
			enemies_alive = true
			break
		end
	end
	if not enemies_alive then
		return 0, 0
	end

	local alerted
	local suspicious = 0
	local surprised = 0

	if trigger_type == "attack" then -- make target and damaged units aware
		local attacker, alerted_obj, from_stealth, hit_objs = ...
		local aware_state = (from_stealth or HasPerk(attacker, "FoxPerk")) and "surprised" or "aware"
		dbg_awareness_log(attacker, " alerts: attack")
		local units = IsValid(alerted_obj) and {alerted_obj} or alerted_obj
		for _, unit in ipairs(units) do
			local state = (g_Combat and unit:HasStatusEffect("Surprised")) and "aware" or aware_state
			local is_aware = unit:IsAware() or unit.pending_aware_state == "aware"
			local reason_id
			if state == "surprised" and not is_aware or (hit_objs and not table.find(hit_objs, unit)) then
				reason_id = "arSurprised"
			else
				reason_id = "arAttack"
			end
			local reason = T{Presets.AwareReasons.Default[reason_id].display_name, enemy = unit.Name, merc = attacker.Nick or attacker.Name}
			if unit:SetPendingAwareState(state, reason, attacker) then
				if state ~= "aware" then
					surprised = surprised + 1
				else
					if not alerted then alerted = {} end
					alerted[#alerted + 1] = unit
				end
				dbg_awareness_log("  ", unit, " alerted")
			end
			if unit.pending_aware_state == "aware" then
				local action = g_CurrentAttackActions[1]
				if action and action.attack_args and action.attack_args.target == unit then
					unit.pending_awareness_role = state == "surprised" and "surprised" or "attacked"
				end
			end
		end
	elseif trigger_type == "death" then
		local actor = ...
		dbg_awareness_log(actor, " alerts: dead")
		-- check units based on their sight/los toward actor
		local units
		for _, team in ipairs(g_Teams) do
			if not team.neutral then
				for _, u in ipairs(team.units) do
					if not u.dummy and not u:IsIncapacitated() and not u:IsAware() then
						local sight = u:GetSightRadius(actor)
						if IsCloser(u, actor, sight + 1) then
							if not units then units = {} end
							units[#units + 1] = u
						end
					end
				end
			end
		end
		if units then
			local los_any, los_targets = CheckLOS(units, actor)
			if los_any then
				for i, los_value in ipairs(los_targets) do
					if los_value then
						local unit = units[i]
						local reason = T{Presets.AwareReasons.Default.arSawDying.display_name, enemy = unit.Name}
						if unit:SetPendingAwareState("surprised", reason) then
							dbg_awareness_log("  ", unit, " is surprised")
							surprised = surprised + 1
						end
					end
				end
			end
		end
	elseif trigger_type == "dead body" then
		local actor, _units = ...
		local units
		for _, unit in ipairs(_units) do
			if not unit.seen_bodies[actor]
				and not (unit.dummy or unit.team.neutral or unit:IsDead() or unit:IsAware()) -- SetPendingAwareState ignores these units
				and IsCloser(unit, actor, unit:GetSightRadius(actor) + 1)
			then
				if not units then units = {} end
				units[#units + 1] = unit
			end
		end
		if units then
			local los_any, los_targets = CheckLOS(units, actor)
			if los_any then
				local aware_state = g_Combat and "surprised" or "suspicious"
				for i, los_value in ipairs(los_targets) do
					if los_value then
						local unit = units[i]
						if unit:SetPendingAwareState(aware_state) then
							unit.suspicious_body_seen = actor:GetHandle()
							unit.seen_bodies[actor] = true
							dbg_awareness_log("  ", unit, " is suspicious")
							suspicious = suspicious + 1
						end
					end
				end
			end
		end
	elseif trigger_type == "noise" then -- aware/suspicious based on range, current awareness
		local actor, radius, soundName, attacker = ... -- actor can be unit or another object (grenade, mine, etc.)
		-- log noise sources (will reset on new turn)
		if GameState.RainLight or GameState.RainHeavy then
			radius = MulDivRound(radius, Max(0, 100 + const.EnvEffects.RainNoiseMod), 100)
		end
		dbg_awareness_log(actor, " alerts: noise ", radius)
		g_NoiseSources[#g_NoiseSources + 1] = {
			actor = actor,
			pos = actor and actor:GetPos(),
			noise = radius,
		}
		radius = radius * const.SlabSizeX
		local alerter = IsKindOf(actor, "Unit") and actor or nil
		if IsKindOf(attacker, "Unit") then
			alerter = attacker
		end
		local state = alerter and HasPerk(alerter, "FoxPerk") and "surprised" or "aware"
		for _, team in ipairs(g_Teams) do
			local side = team.side
			if side ~= "neutral" and (g_Combat or side == "enemy1" or side == "enemy2") then
				for _, unit in ipairs(team.units) do
					if unit ~= actor
						and IsCloser(unit, actor, radius + 1)
						and (not unit:HasStatusEffect("Distracted") or IsCloser(unit, actor, MulDivRound(radius, 66, 100) + 1))
					then
						local reason = T{Presets.AwareReasons.Default.arNoise.display_name, enemy = unit.Name, noise = soundName}
						if unit:SetPendingAwareState(state, reason, alerter) then
							if actor then
								unit.last_known_enemy_pos = actor:GetPos()
							end
							if state == "aware" then
								if not alerted then alerted = {} end
								alerted[#alerted + 1] = unit
							else
								surprised = surprised + 1
							end
							dbg_awareness_log("  ", unit, " alerted")
						end
					end
				end
			end
		end
	elseif trigger_type == "projector" then
		local actor, units, projector = ...
		for i, unit in ipairs(units) do
			if IsCloser(unit, projector, ProjectorSuspiciousApplyRange) then
				local reason = T{Presets.AwareReasons.Default.arProjector.display_name, enemy = unit.Name}
				if unit:SetPendingAwareState("aware", reason, actor) then
					surprised = surprised + 1
				end
			end
		end
	elseif trigger_type == "sight" then -- sight: make unaware units suspicious
		local actor, seen = ... -- actor is unaware unit who saw an enemy. seen is enemy unit seen by actor
		local aware = actor:IsAware() or actor.pending_aware_state == "aware"
		local surprised = actor:HasStatusEffect("Surprised") or actor.pending_aware_state == "surprised"
		if actor:IsOnEnemySide(seen) and not aware and not surprised and actor:SetPendingAwareState("surprised") then
			suspicious = suspicious + 1
			dbg_awareness_log(actor, " is alerted (sight)")
		end
	elseif trigger_type == "thrown" then
		local obj, attacker = ...  --  obj is thrown object
		local units
		for _, team in ipairs(g_Teams) do
			if not team.neutral and (not attacker or attacker.team and team:IsEnemySide(attacker.team)) then
				for _, unit in ipairs(team.units) do
					if not unit:IsDead() and not unit:IsAware("pending") then
						local sight = unit:GetSightRadius(obj)
						if IsCloser(unit, obj, sight + 1) then
							if not units then units = {} end
							units[#units + 1] = unit
						end
					end
				end
			end
		end
		if units then
			local los_any, los_targets = CheckLOS(units, obj)
			if los_any then
				for i, los_value in ipairs(los_targets) do
					if los_value then
						local unit = units[i]
						local reason = T{Presets.AwareReasons.Default.arThrownObject.display_name, enemy = unit.Name}
						if unit:SetPendingAwareState("surprised", reason) then
							dbg_awareness_log("  ", unit, " is surprised")
							surprised = surprised + 1
						end
					end
				end
			end
		end
	elseif trigger_type == "script" then --should this be included in the aware_reason
		local _units, state = ...  -- units to become suspicious/aware
		local units = table.ifilter(_units, function(idx, unit)
			return unit.team and not unit.team.neutral
		end)
		for _, unit in ipairs(units) do	
			unit.pending_aware_state = state
			dbg_awareness_log(unit, " is alerted (script): ", state)
		end
		if state == "aware" then
			alerted = units
		end
	elseif trigger_type == "surprise" then
		local unit, from_suspicious = ...
		local reason
		if from_suspicious then
			reason = T{Presets.AwareReasons.Default.arDeadBody.display_name, enemy = unit.Name}
		end
		if unit:SetPendingAwareState("aware", reason) then
			dbg_awareness_log(unit, " is alerted (surprise)")
			if not alerted then alerted = {} end
			alerted[#alerted + 1] = unit
		end
	elseif trigger_type == "discovered" then -- Alert all enemies who have sight of unit.
		local unit = ...
		local enemyUnits = GetAllEnemyUnits(unit)
		local alertedPeople = 0
		for i, enemyUnit in ipairs(enemyUnits) do
			if not enemyUnit:IsAware() and HasVisibilityTo(enemyUnit, unit) then
				alertedPeople = alertedPeople + 1
				CombatStarDetectedtVR(unit)
				if enemyUnit.pending_aware_state ~= "aware" then
					if not enemyUnit:HasStatusEffect("Surprised") then -- unit has already spotted someone and is now surprised, dont try to make it aware again
						local reason = T{Presets.AwareReasons.Default.arNotice.display_name, enemy = enemyUnit.Name, merc = unit.Nick or unit.Name}
						if enemyUnit:SetPendingAwareState("aware", reason, unit) then
							if not alerted then alerted = {} end
							alerted[#alerted + 1] = enemyUnit
							dbg_awareness_log(enemyUnit, " is alerted (combat-walk)")
						end
					end
				end
			end
		end
		if alertedPeople > 0 then
			unit:RemoveStatusEffect("Hidden")
		end
	else
		assert(false, string.format("unknown alert trigger '%s' used", tostring(trigger_type)))
	end

	if alerted then
		alerted = table.ifilter(alerted, function(idx, unit)
			return not unit.dummy and unit.pending_aware_state == "aware"
		end)
	end
	local alerted_count = alerted and #alerted or 0

	if alerted_count > 0 then
		local roles = {}
		PropagateAwareness(alerted, roles)
		for _, unit in ipairs(alerted) do
			if unit.pending_aware_state ~= "aware" and unit:SetPendingAwareState("aware") or roles[unit] == "alerter" then
				unit.pending_awareness_role = roles[unit] or "alerted"
			end
		end
	end
	
	if alerted_count + surprised > 0 then
		local pendingType = alerted_count > 0 and "alert" or "sus"
		if not g_UnitAwarenessPending or pendingType == "alert" then
			g_UnitAwarenessPending = pendingType
		end
	end

	return alerted_count + surprised, suspicious
end

function TriggerUnitAlert(trigger_type, ...)
	local alerted, suspicious = PushUnitAlert(trigger_type, ...)
	AlertPendingUnits()
	
	return alerted, suspicious
end

function PropagateAwareness(alerted_units, roles, killed_units)
	local i = 1	
	while i <= #alerted_units do
		local unit = alerted_units[i]
		local killed = killed_units and table.find(killed_units, unit)
		if not unit:IsDead() or killed then
			local upos = GetPackedPosAndStance(unit, killed and unit.killed_stance)
			local allies = GetAllAlliedUnits(unit)
			for _, ally in ipairs(allies) do
				if IsValidTarget(ally) and (ally.team.side == "neutral" or (not ally:IsAware() and ally.pending_aware_state ~= "aware")) then
					local apos = GetPackedPosAndStance(ally)
					local sight = ally:GetSightRadius(unit)
					if apos and upos and (stance_pos_dist(upos, apos) <= sight) and stance_pos_visibility(upos, apos) then
						table.insert_unique(alerted_units, ally)
						if roles then
							if not roles[unit] then
								roles[unit] = "alerter"
							end
							roles[ally] = "alerted"
						end
					end
				end
			end
		end
		i = i + 1
	end
end

local function ExecUnitAlert(reposition_units, alerted_by_enemy, first_unit)
	local sector = gv_Sectors[gv_CurrentSectorId]

	local unitList
	if next(alerted_by_enemy) then
		unitList = alerted_by_enemy
		alerted_by_enemy = table.ifilter(alerted_by_enemy, function(idx, unit) return IsValidTarget(unit) and IsValid(unit.alerted_by_enemy) and not unit:HasStatusEffect("Unconscious") end)
	else
		unitList = reposition_units
	end

	for _, unit in ipairs(unitList) do
		if sector.awareness_sequence == "Standard" then
			unit.pending_awareness_role = unit.pending_awareness_role or "alerted"
		else
			unit.pending_awareness_role = nil
		end
	end
	
	PlayBestCombatNotification(unitList)

	if not g_Combat then
		if not g_StartingCombat and g_Units and next(g_Units) then
			NetSyncEvent("ExplorationStartCombat", nil, first_unit and first_unit.session_id)
			WaitMsg("CombatStart")
		end
	elseif g_StartingCombat then
		WaitMsg("CombatStart")
	end
	
	-- Remove action camera if on.
	if ActionCameraPlaying then
		RemoveActionCamera(true)
		WaitMsg("ActionCameraRemoved", 5000)
	end
	
	-- start of combat setpiece (if needed)
	local cam_actor, restore_cam_obj
	if g_Combat and not g_Combat.unit_reposition_shown and alerted_by_enemy and #alerted_by_enemy > 0 and sector.awareness_sequence == "Standard" then		
		local unit 
		for _, u in ipairs(alerted_by_enemy) do
			if u.pending_awareness_role == "attacked" then
				unit = u
				break
			end
		end
		unit = unit or table.interaction_rand(alerted_by_enemy, "StartCombat")
		g_Combat.unit_reposition_shown = true
		cam_actor, restore_cam_obj = unit, unit.alerted_by_enemy
		if unit and not IsCompetitiveGame() then
			cameraTac.SetZoom(0,50)
			LockCamera(unit)
			Sleep(50)
			-- add all units to AlertedUnits group so the setpiece can access them
			for _, unit in ipairs(reposition_units) do
				if IsValid(unit) and not unit:IsDead() then
					unit:AddToGroup("AlertedUnits")
				end
			end
		
			-- go over setpieces and try to find the ones which can use their action camera
			local valid, all = {}, {}
			ForEachPresetInGroup("SetpiecePrg", "Combat", function(prg) -- todo: move to separate StartCombat group maybe?
				for _, cmd in ipairs(prg) do
					if IsKindOfClasses(cmd, "SetpieceActionCameraSingle", "SetpieceActionCamera") then
						local target
						if IsKindOf(cmd, "SetpieceActionCameraSingle") then
							target = SetpieceActionCameraSingle.CalcTarget({unit}, cmd.TargetOffset, cmd.TargetHeight, cmd.TargetAngleOffset)
						else
							target = unit.alerted_by_enemy
						end
						local pos, lookat, preset = SetpieceActionCamera.CalcCamera(unit, target, cmd.Preset, cmd.Position)
						if cmd.Preset == "Any" or preset == cmd.Preset then
							valid[#valid + 1] = prg.id
						end
						all[#all + 1] = prg.id		
					elseif IsKindOfClasses(cmd, "SetStartCombatAnim") then
						valid[#valid + 1] = prg.id			
					end
				end
			end)
			
			-- fall back to picking randomly if none of the available setpieces matched the current situation and rely on action cam fallback mechanism
			valid = (#valid > 0) and valid or all
			assert(#valid > 0)
			local setpiece = table.interaction_rand(valid, "StartCombat")
			
			-- pass the single unit in triggerUnits as it defines the camera for the setpiece
			local dlg = OpenDialog("XSetpieceDlg", false, {setpiece = setpiece, triggerUnits = {unit} })
			if dlg then
				while true do
					local ok, sp = WaitMsg("SetpieceEnded", 20 * 1000)
					if not ok or sp.id == dlg.setpiece then
						break
					end
				end
			end
			-- remove units from AlertedUnits group
			for _, unit in ipairs(reposition_units) do
				unit:RemoveFromGroup("AlertedUnits")
				unit.pending_awareness_role = nil
			end
			UnlockCamera(unit)
		end
	end
	
	CancelWaitingActions(-1)
	assert(#reposition_units > 0)
	assert(g_AIExecutionController and g_AIExecutionController.label == "AlertUnits")
	if not g_StartingCombat then 
		g_AIExecutionController.restore_camera_obj = restore_cam_obj or SelectedObj
	end
	g_AIExecutionController:Execute(reposition_units)
	
	-- special-case: if there are allied units who did not yet reposition in this combat, let them do it now - they're all aware anyway
	local team = table.find(g_Teams, "side", "ally")
	team = g_Teams[team or false]
	if g_Combat and team then
		local units = table.ifilter(team.units, function(idx, u) return not g_Combat:IsRepositioned(u) end)
		if #units > 0 then
			for _, unit in ipairs(units) do
				unit.pending_aware_state = "reposition"
			end
			g_AIExecutionController:Execute(units)
		end
	end

	g_UnitAlertThread = false
	g_UnitAwarenessPending = false
	DoneObject(g_AIExecutionController)
end

function AlertPendingUnits(sync_code)
	-- check buffering conditions
	--NetUpdateHash("AlertPendingUnits")
	if g_Combat then
		if g_Combat.start_of_turn or next(CombatActions_RunningState) ~= nil then
			return
		end
	end
	--[[
	NetUpdateHash("AlertPendingUnits_EarlyOuts", "GameState.entering_sector", GameState.entering_sector,
										"IsValidThread(g_UnitAlertThread)", IsValidThread(g_UnitAlertThread),
										"IsSetpiecePlaying()", IsSetpiecePlaying(),
										"GameState.setpiece_playing", GameState.setpiece_playing,
										"IsRadioBanterPlaying()", IsRadioBanterPlaying(),
										"g_AIExecutionController", not not g_AIExecutionController,
										"GameState.sync_loading", GameState.sync_loading,
										"not gv_Sectors", not gv_Sectors,
										"GameState.entering_sector", GameState.entering_sector)
	]]
	if IsSetpiecePlaying() or GameState.sync_loading or g_AIExecutionController or IsValidThread(g_UnitAlertThread) or gv_SatelliteView or not gv_Sectors then
		return
	end
	if GameState.entering_sector then
		return
	end
	
	--NetUpdateHash("AlertPendingUnits_doing_work")
	-- check for unit reactions to damage:
		-- pain: the alert will happen after it ends (triggered by the pain thread)
		-- dying: the alert will happen after it ends (triggered by UnitDied msg)
		-- thrown off by explosion: the alert will happen after it ends (triggered by Idle or UnitDied msg)
	for _, unit in ipairs(g_Units) do
		--if IsValidThread(unit.pain_thread) or (unit:IsDead() and not unit:IsIdleCommand()) or unit.command == "ExplosionFly" then
		if IsValidThread(unit.pain_thread) or unit.command == "ExplosionFly" or HasCombatActionInProgress(unit) then
			return
		end
	end
	
	local sector = gv_Sectors[gv_CurrentSectorId]
	-- only enum the units with pending awareness, the execution controller will process them
	local reposition_units, alerted_by_enemy, surprised_units
	local start_combat, first_unit
	local current_team = g_Combat and g_Teams[g_CurrentTeam]
	local end_combat = g_Combat and g_Combat:ShouldEndCombat()
	local skip_all = sector and sector.awareness_sequence == "Skip All"

	for _, team in ipairs(g_Teams) do
		if end_combat or team.side == "neutral" then
			for _, unit in ipairs(team.units) do
				unit.pending_aware_state = nil
			end
		else
			for _, unit in ipairs(team.units) do
				local state = unit.pending_aware_state
				if state then
					if not IsValidTarget(unit) then
						unit.pending_aware_state = nil
					elseif unit:IsAware() then
						unit.pending_aware_state = nil
					elseif state == "aware" then
						start_combat = true
						if skip_all or team == current_team then
							unit:RemoveStatusEffect("Unaware")
							unit:RemoveStatusEffect("Surprised")
							unit:RemoveStatusEffect("Suspicious")
							unit.pending_aware_state = nil
						else
							if not reposition_units then reposition_units = {} end
							reposition_units[#reposition_units + 1] = unit
							first_unit = first_unit or unit.alerted_by_enemy
							if IsValidTarget(unit.alerted_by_enemy) then
								if not alerted_by_enemy then alerted_by_enemy = {} end
								alerted_by_enemy[#alerted_by_enemy + 1] = unit
							end
						end
					elseif state == "surprised" then
						start_combat = true
						if g_Combat then
							unit:AddStatusEffect("Surprised")
							unit:RemoveStatusEffect("Suspicious")
							unit.pending_aware_state = nil
						else
							if not surprised_units then surprised_units = {} end
							surprised_units[#surprised_units + 1] = unit
						end
					elseif state == "suspicious" then -- becoming suspicious is instant (no action involved),	 so do it directly
						unit:AddStatusEffect("Suspicious")
						unit:RemoveStatusEffect("Unaware")
						unit.pending_aware_state = nil
					else
						unit.pending_aware_state = nil
					end
				end
			end
		end
	end
	if start_combat and not g_Combat or reposition_units then
		if reposition_units then
			CreateAIExecutionController{label = "AlertUnits", reposition = true} -- create controller first so nobody else does before the thread starts
		end

		g_UnitAlertThread = CreateGameTimeThread(function(sync_code, first_unit, reposition_units, alerted_by_enemy)
			if not g_Combat then
				if not g_StartingCombat and g_Units and next(g_Units) then
					if sync_code then
						CreateGameTimeThread(NetSyncEvents.ExplorationStartCombat, nil, first_unit and first_unit.session_id)
					else
						NetSyncEvent("ExplorationStartCombat", nil, first_unit and first_unit.session_id)
					end
				end
				while not g_Combat do
					WaitMsg("CombatStarting", 10)
				end
				-- now that we're in combat recheck the units for pending Surprised status
				for _, team in ipairs(g_Teams) do
					if team.side ~= "neutral" then
						for _, unit in ipairs(team.units) do
							if unit.pending_aware_state == "surprised" and IsValidTarget(unit) and not unit:IsAware() then
								unit:AddStatusEffect("Surprised")
								unit.pending_aware_state = nil
							end
						end
					end
				end
			end
			if reposition_units then
				ExecUnitAlert(reposition_units, alerted_by_enemy, first_unit)
			end
		end, sync_code, first_unit, reposition_units, alerted_by_enemy)
	end

	if not reposition_units then
		if surprised_units then
			PlayBestCombatNotification(surprised_units)
		end
		g_UnitAwarenessPending = false
	end
end

MapGameTimeRepeat("AlertPendingUnits", 100, AlertPendingUnits)

function OnMsg.VisibilityUpdate()
	if not g_Combat then return end -- out of combat this is handled by UpdateSuspicion
	
	local aware = {}
	for _, unit in ipairs(g_Units) do	
		if not unit:IsDead() then
			local is_aware = unit:IsAware()
			if is_aware and not unit.team.player_team and unit.team.side ~= "neutral" then
				aware[#aware + 1] = unit
			end
			for _, seen in ipairs(g_Visibility[unit]) do
				if IsValid(seen) and unit:IsOnEnemySide(seen) then
					unit.last_known_enemy_pos = seen:GetPos()
					if not is_aware then
						PushUnitAlert("sight", unit, seen)
					end
				end
			end
		end
	end
	
	-- PropagateAwareness from the already aware units to reflect sight/visuals changes
	PropagateAwareness(aware)
	for _, unit in ipairs(aware) do
		if unit:SetPendingAwareState("aware") then
			unit.pending_awareness_role = "alerted"
		end
	end
	
	AlertPendingUnits()
end

function DeadUnitsPulse()
	if IsSetpiecePlaying() then return end

	local alert_team_units
	for _, team in ipairs(g_Teams) do
		local neutral = team.neutral
		local alert_side = neutral and "enemy1" or team.side
		local alert_units = alert_team_units and alert_team_units[alert_side]
		for _, unit in ipairs(team.units) do
			if (not neutral or unit.neutral_retaliate) and unit:IsDead() then
				if not alert_units then
					for _, team in ipairs(g_Teams) do
						if team.side == alert_side then
							for _, u in ipairs(team.units) do
								if not u:IsDead()
									and not u:IsAware("pending")
									and not u:HasStatusEffect("HighAlert")
									and not u:HasStatusEffect("IgnoreBodies")
								then
									if not alert_units then alert_units = {} end
									alert_units[#alert_units + 1] = u
								end
							end
						end
					end
					if not alert_team_units then alert_team_units = {} end
					alert_team_units[alert_side] = alert_units or empty_table
				end
				if not alert_units or #alert_units == 0 then
					break
				end
				PushUnitAlert("dead body", unit, alert_units)
			end
		end
	end
	AlertPendingUnits()
end

OnMsg.TurnStart = DeadUnitsPulse
OnMsg.UnitDied = DeadUnitsPulse
OnMsg.Idle = AlertPendingUnits

function OnMsg.CombatActionEnd()
	CreateGameTimeThread(AlertPendingUnits)
end

function OnMsg.CombatEnd()
	MapForEach("map", "Unit", function(unit) 
		unit.pending_aware_state = nil
		unit.alerted_by_enemy = nil
		unit.aware_reason = nil
	end)
	dbg_awareness_log("Combat ended")
end

function OnMsg.CombatStart()
	dbg_awareness_log("Combat started")
end

function OnMsg.EnterSector()
	g_AwarenessLog = {}
end

MapGameTimeRepeat("DeadAwarenessPulseTick", 500, function()
	if not g_Combat then
		DeadUnitsPulse()
	end
end)

function Unit:SetPendingAwareState(state, reason, alerter)
	NetUpdateHash("SetPendingAwareState", state, alerter, self.pending_aware_state, self:IsAware())
	if self.dummy or self.team.side == "neutral" or self:IsDead() or self:IsAware() then return end
	
	if reason and (not self.aware_reason or table.find(Presets.AwareReasons.Default, "display_name", reason[1]) > table.find(Presets.AwareReasons.Default, "display_name", self.aware_reason[1])) then
		self.aware_reason = reason or self.aware_reason
	end
	if not self.pending_aware_state or (state == "aware" or state == "surprised") and self.pending_aware_state ~= "aware" then
		self.pending_aware_state = state
		self.alerted_by_enemy = alerter or self.alerted_by_enemy
		return true
	elseif self.pending_aware_state == state then
		self.alerted_by_enemy = self.alerted_by_enemy or alerter
		return true
	end
end

-- Suspicious

function Unit:SuspiciousRoutine()
	local def = CharacterEffectDefs.Suspicious
	
	-- wait to finish the previouse job
	Sleep(self:TimeToAngleInterpolationEnd())

	local body = self.suspicious_body_seen and HandleToObject[self.suspicious_body_seen]
	if IsValid(body) then
		self:Face(body, not GameTimeAdvanced and 0 or 500)
	end

	local anim = self:TryGetActionAnim("Suspicious", "Standing")
	if anim and self:GetStateText() ~= anim then
		self:SetState(anim)
	end
	
	local last_update = GameTime()
	local effect = self:GetStatusEffect("Suspicious")
	local time = effect:ResolveValue("suspicious_time") or 0
	effect:SetParameter("suspicious_time", time)
	
	local grow_time = effect:ResolveValue("sight_grow_time")
	local sight_mod_max = effect:ResolveValue("sight_modifier_max")
	local delay_time = effect:ResolveValue("max_sight_delay")
	local shrink_time = effect:ResolveValue("sight_shrink_time")
	
	repeat		
		WaitMsg("CombatStarting", 100) -- so it breaks when on combat start
		effect = self:GetStatusEffect("Suspicious") -- recheck in case it was lost meanwhile
		if g_Combat or not effect then break end
		
		-- accumulate time spent looking around
		local time_now = GameTime()
		time = time + time_now - last_update
		last_update = time_now
		effect:ResolveValue("suspicious_time", time)
		
		-- update sight radius mod in effect value
		local mod
		if time < grow_time then
			mod = MulDivRound(sight_mod_max, time, grow_time)
		elseif time < grow_time + delay_time then
			mod = sight_mod_max
		elseif time < grow_time + delay_time + shrink_time then
			local t = time - grow_time - delay_time
			mod = MulDivRound(sight_mod_max, shrink_time - t, shrink_time)
		else
			mod = nil
		end
		if effect:ResolveValue("suspicious_sight_mod") ~= mod then
			effect:SetParameter("suspicious_sight_mod", mod)
			InvalidateUnitLOS(self)
		end
	until not mod
	self.suspicious_body_seen = nil
	if not g_Combat and not g_StartingCombat and self:HasStatusEffect("Suspicious") then 
		local enemies = GetAllEnemyUnits(self)
		local mindist
		for _, enemy in ipairs(enemies) do
			if enemy.team and enemy.team.player_team then
				local dist = self:GetDist(enemy)
				mindist = Min(mindist or dist, dist)
			end
		end
		-- become aware or revert to unaware based on min distance to enemy
		if mindist and mindist < Suspicious:ResolveValue("remain_unaware_min_dist")*guim then
			TriggerUnitAlert("surprise", self, "suspicious")
		else
			self:AddStatusEffect("Unaware")
		end
	end
end

-- Reposition

local function PathFromContextDest(unit, context, dest)
	for _, stance in ipairs(StancesList) do
		local cpath = context.combat_paths[stance]
		local path = cpath and cpath:GetCombatPathFromPos(dest)
		if path then
			return path
		end
	end
end

function Unit:ClaimRepositionMarker()
	local rep_markers = MapGetMarkers("Reposition", nil, function(marker, unit)
		if g_RepositionMarkersClaimed[marker] then
			return false
		end
		if (marker.TargetUnits or "") ~= "" and marker.TargetUnits ~= unit.unitdatadef_id then
			return false
		end
		local x, y, z = GetPassSlabXYZ(marker)
		if not x then
			return false
		end
		local has_path
		local dest = point_pack(x, y, z)
		for _, stance in ipairs(StancesList) do
			local cpath = unit.ai_context.combat_paths[stance]
			if cpath and cpath:GetAP(dest) then
				has_path = true
				break
			end
		end
		return 
			has_path and 
			CanOccupy(unit, x, y, z) and 
			marker:IsMarkerEnabled()
	end, self)
	if not rep_markers or #rep_markers == 0 then
		return
	end
	local idx = 1 + self:Random(#rep_markers)
	return rep_markers[idx]
end

function Unit:PickRepositionDest()
	local context = self.ai_context
	local behavior = context and context.behavior
	context.reposition = true
	context.forced_run = true
	context.ai_destination = false
	self.reposition_dest = false
	self.reposition_marker = false

	if not behavior then return end

	local marker = self:ClaimRepositionMarker()

	if marker then
		g_RepositionMarkersClaimed[marker] = true
		local x, y, z = GetPassSlabXYZ(marker)
		self.reposition_path = PathFromContextDest(self, context, point_pack(x, y, z))
		-- there could be no path when the unit is on the destination
		if self.reposition_path then
			self.reposition_dest = stance_pos_pack(x, y, z, self.stance)
			self.reposition_marker = marker
		end
	else
		behavior:Think(self)
		if context.ai_destination then
			local x, y, z = stance_pos_unpack(context.ai_destination)
			assert(CanOccupy(self, x, y, z))
			self.reposition_path = PathFromContextDest(self, context, point_pack(x, y, z))
			-- there could be no path when the unit is on the destination
			if self.reposition_path then
				self.reposition_dest = context.ai_destination
			end
		end
	end
end

function Unit:GetProvokePos(path, visible_only)
	local goto_dummies = self:GenerateTargetDummiesFromPath(path)
	local interrupts, provoke_idx = self:CheckProvokeOpportunityAttacks(CombatActions.Move, "move", goto_dummies, visible_only)
	local provoke_pos = provoke_idx and goto_dummies[provoke_idx].pos
	return provoke_pos
end

function Unit:Reposition()
	assert(g_Combat and self:IsAware())
	local always_ready = g_AIExecutionController and g_AIExecutionController.label == "AlwaysReady" and g_AIExecutionController.activator == self
	if not g_Combat or (not always_ready and g_Combat:IsRepositioned(self)) or self:HasStatusEffect("Unconscious") then
		return
	end

	-- initialization/startup
	g_Combat:SetRepositioned(self, true)
	self:PushDestructor(function()
		self.reposition_dest = nil
		self.reposition_path = nil
		self.reposition_marker = nil
	end)

	if not g_Combat or (self.team == g_Teams[g_CurrentTeam] and not always_ready) or (self.team.side == "neutral") or self.dummy then
		self:PopAndCallDestructor()
		return
	end

	local context = self.ai_context
	local path = self.reposition_path

	if path then
		-- set target dummy to free the current position (random waits could chnage the move order)
		local destination = point(point_unpack(path[1]))
		self:SetTargetDummyFromPos(destination, nil, true)

		-- debug code
		local x, y, z = point_unpack(path[1])
		local o = GetOccupiedBy(x, y, z, self)
		if o and o ~= self then
			printf("Unit %d reposition to %s is occupied by another unit %d (%s)", self.handle, tostring(point(point_unpack(path[1]))), o.handle, o.command)
			printf("Unit current pos      %s, efResting = %d", tostring(self:GetPos()), self:GetEnumFlags(const.efResting))
			if self.target_dummy then
				printf("Unit target dummy pos %s, efResting = %d, locked = %s", tostring(self.target_dummy:GetPos()), self.target_dummy:GetEnumFlags(const.efResting), tostring(self.target_dummy.locked))
			end
			printf("Unit reposition_dest  %s", self.reposition_dest and tostring(point(stance_pos_unpack(self.reposition_dest))) or "")
			if self.ai_context and self.ai_context.ai_destination then
				printf("Unit ai_destination   %s", tostring(point(stance_pos_unpack(self.ai_context.ai_destination))))
			end
			printf("Other command: %s", o.command)
			printf("Other current pos      %s, efResting = %d", tostring(o:GetPos()), o:GetEnumFlags(const.efResting))
			if o.target_dummy then
				printf("Other target dummy pos %s, efResting = %d, locked = %s", tostring(o.target_dummy:GetPos()), o.target_dummy:GetEnumFlags(const.efResting), tostring(o.target_dummy.locked))
			end
			if o.reposition_dest then
				printf("Other reposition_dest  %s", tostring(point(stance_pos_unpack(o.reposition_dest))))
			end
			if o.ai_context and o.ai_context.ai_destination then
				printf("Other ai_destination   %s", tostring(point(stance_pos_unpack(o.ai_context.ai_destination))))
			end
			assert(false, "Unit reposition")
		end

		-- check for interrupts first and move to PostAction early if there are none to enable all units to play their Awareness anims simultaneously
		if not self:GetProvokePos(path) then
			SetCombatActionState(self, "PostAction")
		end

		if self.pending_awareness_role then
			self:PlayAwarenessAnim() -- PlayAwarenessAnim has built-in randomized starting time when applicable
		else
			-- randomize starting time to avoid total sync when multiple units reposition
			Sleep(self:Random(500))
		end

		self:CombatGoto("Move", self.ActionPoints, nil, path, true)
	else
		-- no movement, just move to PostAction
		SetCombatActionState(self, "PostAction")
		if self.pending_awareness_role then
			self:PlayAwarenessAnim() -- PlayAwarenessAnim has built-in randomized starting time when applicable
		end
	end
	self:SetTargetDummyFromPos(nil, nil, true)
	if string.match(self:GetStateText(), ".*_Combat%a+Stop.*") then
		Sleep(self:TimeToAnimEnd())
	end
	local base_idle = self:GetIdleBaseAnim(self.target_dummy.stance)
	if not IsAnimVariant(self:GetStateText(), base_idle) then
		self:PlayTransitionAnims(base_idle, self.target_dummy:GetAngle())
	end
	self:AnimatedRotation(self.target_dummy:GetAngle(), base_idle)
	self:SetRandomAnim(base_idle)

	-- end/cleanup
	self:PopAndCallDestructor()
end

function Unit:RepositionOpeningAttack()
	local context = self.ai_context
	if not context then return end

	local dest = GetPackedPosAndStance(self)
	local target
	if dest then
		-- recalc target to make sure we're firing at a valid target, giving enough AP for one basic attack
		self.ActionPoints = context.default_attack_cost
		context.dest_ap[dest] = self.ActionPoints
		context.reposition = false -- re-enable damage score
		AIPrecalcDamageScore(context, {dest})
		target = (context.dest_target or empty_table)[dest]
	end
	
	if IsKindOf(target, "Unit") and IsValidTarget(target) then
		local chance 
		if self.AlwaysUseOpeningAttack then
			chance = 100
		else
			chance = Max(0, 30 + self.Dexterity - target.Dexterity)
			chance = self:CallReactions_Modify("OnCalcOpeningAttackChance", chance, self, target)
			chance = target:CallReactions_Modify("OnCalcOpeningAttackChance", chance, self, target)
			chance = Clamp(chance, 0, 100)
		end
		
		if self:Random(100) < chance then
			local weapon = context.default_attack:GetAttackWeapons(self)
			if IsKindOf(weapon, "Firearm") and not IsKindOfClasses(weapon, "HeavyWeapon", "FlareGun") then
				local attacked
				local opening_attack = self.OpeningAttackType
				if opening_attack ~= "Default" then
					if CombatActions[opening_attack]:GetUIState({self}) == "hidden" then
						opening_attack = false -- revert to basic attack
					end
				end
				
				if opening_attack == "Overwatch" then
					local args, has_ap = AIGetAttackArgs(context, CombatActions.Overwatch, nil, "None")
					if has_ap then 	
						local zones = AIPrecalcConeTargetZones(context, "Overwatch")
						local zone = AIEvalZones(context, zones, 1, 1)
						if zone then
							-- We're already running a Combat Action so we can't use AIPlayCombatAction.
							-- We also shouldn't call OverwatchAction() directly as it will break the execution of the current command in the end.
							-- Instead, we exploit OverwatchAction being a combat behavior and set it directly as one, relying on the code to be
							--		executed once the current command concludes and the we go into Idle.
							local args = { target = zone.target_pos }
							self:SetCombatBehavior("OverwatchAction", {"Overwatch", 0, args})
							attacked = true
						end
					end
				elseif opening_attack == "PinDown" then
					local args, has_ap, target = AIGetAttackArgs(context, CombatActions.PinDown, nil, "None")
					if has_ap and IsValidTarget(target) then
						if self:HasPindownLine(target, "Torso") then
							-- Same as above, set the behavior directly.
							local arg = { target = target, target_spot_group = "Torso" },
							self:SetCombatBehavior("PinDown", {"PinDown", 0, args})
							attacked = true
						end
					end
				end
				if not attacked then
					self:FirearmAttack(context.default_attack.id, 0, {target = target, opportunity_attack = true, opening_attack = true})
				end
			elseif IsKindOf(weapon, "MeleeWeapon") then
				self:MeleeAttack(context.default_attack.id, 0, { target = target, opportunity_attack = true})
			end
		end
	end
	
	-- take cover chance
	local archetype = self:GetCurrentArchetype()
	local chance = 0
	for _, behavior in ipairs(archetype.Behaviors) do
		if behavior:MatchUnit(self) then
			chance = Max(chance, behavior.TakeCoverChance)
		end
	end
	if self:Random(100) < chance then
		self:TakeCover()
	end

	self:RemoveStatusEffect("OpeningAttackBonus")	
end

function IsRepositionPhase()
	return g_AIExecutionController and g_AIExecutionController.reposition
end

-- noise sources debug
if Platform.developer then
	function ToggleNoiseSources()
		if not g_NoiseSources then return end
		
		if g_NoiseSources.shown then
			for _, obj in ipairs(g_NoiseSources.shown) do
				DoneObject(obj)
			end
			g_NoiseSources.shown = nil
			printf("displayed noise sources removed")
		else
			local list, centers, ranges = {}, {}, {}
			local avg_pos = point30
			
			for i, descr in ipairs(g_NoiseSources) do
				local obj = PlaceObject("Object")
				obj:ChangeEntity("MarkerMusic")
				obj:SetScale(20)
				obj:SetPos(descr.pos)
				
				local text = Text:new()
				text:SetText(string.format("%s (%d)", descr.actor.unitdatadef_id, descr.noise))
				obj:Attach(text)
				
--[[				local mesh = Mesh:new()		
				local mesh_str = pstr("", 1024)
				AppendVerticesUnionCircles({descr.pos}, {descr.noise * const.SlabSizeX}, mesh_str)
				mesh:SetMeshFlags(const.mfWorldSpace)
				mesh:SetMesh(mesh_str)
				mesh:SetShader(ProceduralMeshShaders.enemy_aware_range)
				obj:Attach(mesh)--]]
				
				centers[i] = descr.pos
				ranges[i] = descr.noise * const.SlabSizeX
				list[i] = obj				
			end
			
			if #list > 0 then
---[[				
				local mesh = Mesh:new()		
				local mesh_str = pstr("", 1024)
				AppendVerticesUnionCircles(centers, ranges, mesh_str)
				mesh:SetMeshFlags(const.mfWorldSpace)
				mesh:SetMesh(mesh_str)
				mesh:SetShader(ProceduralMeshShaders.enemy_aware_range)
				mesh:SetColorFromTextStyle("EnemyAwareRange")
				mesh:SetPos(avg_pos:SetInvalidZ() / #list)
				list[#list + 1] = mesh--]]
				g_NoiseSources.shown = list
			end
			printf("%d logged noise sources displayed", #g_NoiseSources)
		end
	end
	
	function ResetNoiseSources()
		if not g_NoiseSources then return end
		if g_NoiseSources.shown then
			ToggleNoiseSources()
		end
		g_NoiseSources = {}
	end
	
	--OnMsg.NewCombatTurn = ResetNoiseSources
	OnMsg.CombatStart = ResetNoiseSources
end

-- Suspicion

SuspicionThreshold = 160 -- Above this much the unit will become alerted
local lSuspicionTickRate = 100 -- How often to add the tick amount
local lSuspicionTickAmount = 10 -- The amount to add when hidden
local lSuspicionTickAmountProjector = 6 -- The amount to add when hidden
ProjectorSuspiciousApplyRange = 10 * const.SlabSizeX -- Enemies within this distance of the projector will be alerted
local lSuspicionTickAmountProne = 5 -- The amount to add when hidden and in prone
local lSuspicionTickAmountNotHidden = 16 -- The amount to add when not hidden
local lSuspicionTickDownAmount = 2 -- The amount to remove when no unit is in range
local lSuspicionTickMinDist = const.SlabSizeX * 2 -- If this close to an enemy then frontness doesn't matter (unless hidden or in the dark)
local lSuspicionTickDistanceModOuter = const.SlabSizeX * 4 -- Past this distance in the sight radius the distance modifier is 100%
local lCubicInIndex = GetEasingIndex("Cubic in")

MapVar("lastSusUpdate", 0)

function OnMsg.CombatEnd()
	for i, u in ipairs(g_Units) do
		u.suspicion = 0
	end
	Msg("CombatEndAfterAwarenessReset")
end

function UpdateSuspicion(alliedUnits, enemyUnits, intermediate_update)
	if GameTime() - lastSusUpdate < lSuspicionTickRate then return end
	--NetUpdateHash("UpdateSuspicion", alliedUnits, enemyUnits, intermediate_update)

	local sneakLights
	if intermediate_update then
		sneakLights = GetSneakProjectorLights()
	end

	local sector = gv_Sectors[gv_CurrentSectorId]
	local anySusUpdated = false
	local susIncreasedBy = {}
	for i, ally in ipairs(alliedUnits) do
		ally.suspicion = ally.suspicion or 0
		
		-- Performing an attack or something
		if not ally:IsIdleCommand() and not ally:IsInterruptable() then
			goto continue
		end
		if not IsValid(ally) or ally:IsDead() then goto continue end
		
		local allyDetectionModifier = 100
		if HasPerk(ally, "Untraceable") then
			allyDetectionModifier = allyDetectionModifier - Untraceable:ResolveValue("enemy_detection_reduction")
		end
		if ally:HasStatusEffect("Darkness") then
			allyDetectionModifier = allyDetectionModifier + const.EnvEffects.DarknessDetectionRate
		end
		allyDetectionModifier = Max(0, allyDetectionModifier)

		local raiseSusLargest = 0
		local raiseSusEnemy = false
		local max_sight_radius = MulDivRound(GetMaxSightRadius(), 1200, 1000)
		for i, enemy in ipairs(enemyUnits) do
			if enemy.retreating then goto continue end
			if enemy.command == "ExitCombat" then goto continue end
			if enemy:IsDead() then goto continue end
			if not IsCloser(enemy, ally, max_sight_radius) then
				goto continue
			end
			local seesAlly = HasVisibilityTo(enemy, ally)
			-- try to skip GetSightRadius calculations
			if not seesAlly then
				if raiseSusEnemy or not HasVisibilityTo(ally, enemy) then
					goto continue
				end
			end
			local sightRad, hidden, darkness = enemy:GetSightRadius(ally)
			local dist = enemy:GetDist(ally)
			local inRad = dist <= sightRad
			if inRad then
				if seesAlly then
					-- If in front of any enemy, add a bonus detection %
					-- If in the behind plane then have a smaller cut off.
					local angle_to_object = AngleDiff(CalcOrientation(enemy, ally), enemy:GetOrientationAngle())
					if abs(angle_to_object) < 90*60 then
						local radiusLess = MulDivRound(sightRad, 80, 100)
						if dist > radiusLess then
							goto continue
						end
					end
					
					-- The larger this is, the closer the ally is to the enemy
					local distFromSightRad = sightRad - dist 
					
					-- Decrease sus the further away you are
					local distanceModifier = false
					if distFromSightRad < lSuspicionTickDistanceModOuter then
						distanceModifier = Lerp(10, 100, distFromSightRad, sightRad)
					else
						distanceModifier = 100
					end
					
					-- Modify the value based on how in front you are
					local frontnessModifier = false
					local maxDot = (4096 * 4096) * 2
					local dot = cos(angle_to_object) * 4096
					dot = EaseCoeff(lCubicInIndex, dot + 4096 * 4096, maxDot)
					frontnessModifier = Lerp(hidden and 30 or 40, 100, dot, maxDot)
					
					local closeInTheLight = false
					if hidden and not darkness and dist < lSuspicionTickMinDist and frontnessModifier > 60 then
						closeInTheLight = true
					end
					
					-- Get the base value based on a variety of factors
					local value = 0
					if hidden and not closeInTheLight then
						if ally.stance == "Prone" then
							value = lSuspicionTickAmountProne
						else
							value = lSuspicionTickAmount
						end
					else
						value = lSuspicionTickAmountNotHidden
					end
					
					value = MulDivRound(value, distanceModifier, 100)
					value = MulDivRound(value, frontnessModifier, 100)
					
					if value > raiseSusLargest then
						raiseSusEnemy = enemy
						raiseSusLargest = value
					end
				end
			elseif not raiseSusEnemy and HasVisibilityTo(ally, enemy) then
				local extraRad = MulDivRound(sightRad, 1200, 1000)
				if dist <= extraRad then
					raiseSusEnemy = enemy
				end
			end

			::continue::
		end
		
		if sneakLights and IsMerc(ally) then
			local lightIndex = IsVoxelIlluminatedByObjects(ally:GetPos(), sneakLights)
			local val = lightIndex ~= 0 and lSuspicionTickAmountProjector or 0
			if val > raiseSusLargest then
				raiseSusLargest = val
				
				local light = sneakLights[lightIndex]
				local originalLight = light and light.original_light
				local projector = originalLight and originalLight:GetParent()
				if projector then
					raiseSusEnemy = projector
				end
				
				if ally.suspicion + raiseSusLargest >= SuspicionThreshold and ally:HasStatusEffect("Hidden") then
					ally:RemoveStatusEffect("Hidden")
					-- In this specific case we want this status effect to have a removal message.
					-- Copied from AddStatusEffect's floating text.
					CreateMapRealTimeThread(function()
						WaitPlayerControl()
						CreateFloatingText(ally, T{488962074575, "- <DisplayName>", Hidden}, nil, nil, true)
					end)

					PushUnitAlert("projector", ally, enemyUnits, projector)
				end
			end
		end
		
		local oldSus = ally.suspicion
		if raiseSusLargest > 0 then
			ally.suspicion = ally.suspicion + raiseSusLargest
			susIncreasedBy[#susIncreasedBy + 1] = { unit = raiseSusEnemy, amount = raiseSusLargest, sees = ally }
		else
			ally.suspicion = ally.suspicion - lSuspicionTickDownAmount
			if raiseSusEnemy then
				susIncreasedBy[#susIncreasedBy + 1] = { unit = raiseSusEnemy, amount = -1, sees = ally }
			end
		end
		ally.suspicion = Clamp(ally.suspicion, 0, SuspicionThreshold)
		
		if ally.suspicion ~= oldSus and ally.ui_badge then
			local wasZeroNowIsnt = oldSus == 0 and ally.suspicion > 0
			local wasntZeroNowIs = oldSus > 0 and ally.suspicion == 0
			if wasZeroNowIsnt or wasntZeroNowIs then
				ally.ui_badge:UpdateActive()
				anySusUpdated = true
			end
		end
		
		if ally.suspicion >= SuspicionThreshold then
			if sector.warningStateEnabled and not sector.warningReceived then
				EnterWarningState(enemyUnits, alliedUnits, ally)
				anySusUpdated = true
				break
			else
				TriggerUnitAlert("discovered", ally)
				return
			end
		end
		
		::continue::
	end
	
	if anySusUpdated then
		local igi = GetInGameInterfaceModeDlg()
		if igi.crosshair then
			igi.crosshair:UpdateBadgeHiding()
		end
	end
	
	if not intermediate_update then
		lastSusUpdate = GameTime()
	end
	
	return susIncreasedBy
end

MapVar("g_CombatStartDetectedVR", false)
function CombatStarDetectedtVR(unit)
	if (not g_Combat or g_Combat:ShouldEndCombat()) and unit:IsMerc() then
		if unit:HasStatusEffect("Hidden") then
			g_CombatStartDetectedVR = true
			PlayVoiceResponse(unit, "CombatStartDetected")
		end
	end
end

function OnMsg.CombatStart()
	if not g_CombatStartDetectedVR and g_Combat.starting_unit then
		if g_LastAttackStealth then
			PlayVoiceResponse(g_Combat.starting_unit, "CombatStartDetected")
		else
			PlayVoiceResponse(g_Combat.starting_unit, "CombatStartPlayer")
		end
	end
end

function OnMsg.CombatEnd()
	g_CombatStartDetectedVR = false
end

function OnMsg.UnitMovementDone(self, action_id)
	if not g_Combat or not self.team.player_team or self.command == "EnterCombat" then return end
	if action_id ~= "Move" then -- Attacks which include movement will push the "attack" alert.
		return
	end

	PushUnitAlert("discovered", self)
end

-- Warning State
MapVar("WarningStateEnemies", {})

function EnterWarningState(enemyUnits, alliedUnits, triggeringUnit)
	local sector = gv_Sectors[gv_CurrentSectorId]
	if sector.inWarningState then return end -- already in Warning State

	WarningStateEnemies = enemyUnits
	
	-- Try to play a Banter from the nearest enemy to the unit that triggered the Warning
	local warningBanters = sector.warningBanters or {}
	if #warningBanters > 0 then 
		local nearestEnemy = GetNearestEnemy(triggeringUnit)
		local banters, actors = FilterAvailableBanters(warningBanters, nil, {nearestEnemy})
		if banters then
			local idx = InteractionRand(#banters, "PlayBanterEffect") + 1
			
			-- Stop and look at triggering unit
			local lookAt = CalcOrientation(nearestEnemy, triggeringUnit) or nearestEnemy:GetAngle()
			nearestEnemy:SetBehavior()
			nearestEnemy:SetCommand("Idle")
			nearestEnemy:SetAngle(lookAt)
			
			PlayBanter(banters[idx], actors[idx])
		end
	end
	
	for _, enemy in ipairs(WarningStateEnemies) do
		enemy:SetSide("neutral")
	end

	local timerId = "warningTimer_" .. sector.Id
	local timerText = sector.warningTimerText or T(243197217972, "Exit the Area")
	TimerCreate(timerId, timerText, sector.warningStateTimer)
	
	-- Reset Suspicion
	for _, unit in ipairs(alliedUnits) do
		unit.suspicion = 0
	end
	
	sector.warningReceived = true
	sector.inWarningState = true
	
	Msg("OnEnterWarningState")
	ExecuteSectorEvents("SE_OnEnterWarningState", sector.Id)
end

function EndWarningState()
	local sector = gv_Sectors[gv_CurrentSectorId]
	if not sector or not sector.inWarningState then return end -- not in Warning State
		
	for _, enemy in ipairs(WarningStateEnemies) do
		enemy:SetSide("enemy1")
	end
	
	local timerId = "warningTimer_" .. sector.Id
	TimerDelete(timerId) -- might be better to move this after
	
	sector.inWarningState = false
end

function OnMsg.OnAttack(attacker)
	if IsMerc(attacker) then
		local sector = gv_Sectors[gv_CurrentSectorId]
		if sector.inWarningState then
			EndWarningState()
			attacker.suspicion = SuspicionThreshold
		end
	end
end

function OnMsg.TimerFinished(timerId)
	if string.starts_with(timerId, "warningTimer_") then
		EndWarningState()
	end
end

function OnMsg.AllSquadsLeftSector() -- this might not be the ideal place to do the clean up
	EndWarningState()
end

function OnMsg.CampaignTimeAdvanced()
	EndWarningState()
end

function PlayBestCombatNotification(units)
	local bestReason = false
	local bestUnitIdx = 0
	for idx, unit in ipairs(units or empty_table) do
		if not bestReason then
			bestReason = unit.aware_reason
			bestUnitIdx = idx
		elseif unit.aware_reason and table.find(Presets.AwareReasons.Default, "display_name", unit.aware_reason[1]) > table.find(Presets.AwareReasons.Default, "display_name", bestReason[1]) then
			bestReason = unit.aware_reason
			bestUnitIdx = idx
		end
	end
	if bestReason then
		local unit = units[bestUnitIdx]
		local isAlly = unit and unit:IsPlayerAlly()
		ShowTacticalNotification(isAlly and "allyAwareReason" or "awareReason", false, bestReason)
	end
end