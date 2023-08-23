--[[
	CombatCam_ShowAttack(attacker, target)
		Focus the camera on the attack, attempting to show both the attacker and the target on the screen.
		If another CombatCam_ShowAttack is currently in progress, the call will be queued and wait until all previous calls
		are finished.	
		
	CombatCam_ShowAttackNew()
		Focus the target of the attack. If another CombatCam_ShowAttackNew is currently in progress, this means an interrupt has
		occured and it will be executed before the initial action is finished. This allows for specific behavior of the camera
		during interrupts. 
		
	LockCameraMovement(reason), UnlockCameraMovement(reason)
		Change the LockedMovement state of the tactical camera (reason-based).
		
	CreateAIExecutionController
		Wait until the previous execution controller is destroyed and create a new one.
		The execution controller handles AI activity by selecting groups of units to play simultaneously (when possible),
		positioning the camera accordingly and triggering the actions in question. Covers both the normal AI turn and Reposition phase.
--]]

if FirstLoad then
	g_CombatCamAttackStack = {}			-- [2n-1] = attacker, [2n] = target; n >= 1
	const.CombatCamExplosionDelay = 1500
	const.MaxSimultaneousUnits = 5
end

local MinAPToPlay = 2 * const.Scale.AP

MapVar("s_CameraMoveLockReasons", {})
MapVar("g_AITurnContours", {})
MapVar("g_ShowTargetBadge", {})

function LockCameraMovement(reason)
	if (next(s_CameraMoveLockReasons) == nil) then
		cameraTac.SetLockedMovement(true)
	end
	s_CameraMoveLockReasons[reason] = true
end

function UnlockCameraMovement(reason, unlock_all)
	if unlock_all then
		for reason, _ in pairs(s_CameraMoveLockReasons) do
			s_CameraMoveLockReasons[reason] = nil
		end
	else
		s_CameraMoveLockReasons[reason] = nil
	end
	if (next(s_CameraMoveLockReasons) == nil) then
		cameraTac.SetLockedMovement(false)
	end
end

function AdjustCombatCamera(state, instant, target, floor, sleepTime, noFitCheck)
	if not CanYield() then -- In Co-Op DoPointsFitScreen will yield
		CreateGameTimeThread(AdjustCombatCamera, state, instant, target, floor, sleepTime, noFitCheck)
		return
	end

	if state == "set" then
		if instant then
			cameraTac.SetLookAtAngle(40*60)
			table.change(hr, "Enemy turn TacCamera Angle", { CameraTacLookAtAngle = 40*60 })
			table.change(hr, "Instant Vertical Camera Movement", {CameraTacInterpolatedVerticalMovementTime = 0 })
			table.change(hr, "Enemy turn TacCamera Height", { CameraTacHeight = 1500 })
			cameraTac.SetForceMaxZoom(true, 0, true)
		else
			table.change(hr, "Enemy turn TacCamera Height", { CameraTacHeight = 1500 })
			table.change(hr, "Enemy turn TacCamera Angle", { CameraTacLookAtAngle = 40*60 })
			cameraTac.SetForceMaxZoom(true)
		end
		if target then 
			floor = floor or GetFloorOfPos(SnapToPassSlab(target))
			sleepTime = sleepTime or 1000
			if noFitCheck or not DoPointsFitScreen({IsPoint(target) and target or target:GetVisualPos()}, nil, const.Camera.BufferSizeNoCameraMov) then
				SnapCameraToObj(target, "force", floor, sleepTime)
			end
		end
	elseif state == "reset" then
		hr.CameraTacClampToTerrain = true
		if table.changed(hr, "Instant Vertical Camera Movement") then
			table.restore(hr, "Instant Vertical Camera Movement")
		end
		if cameraTac.GetForceMaxZoom() then
			cameraTac.SetForceMaxZoom(false)
		end
		if table.changed(hr, "Enemy turn TacCamera Angle") then
			table.restore(hr, "Enemy turn TacCamera Angle")
		end
		if table.changed(hr, "Enemy turn TacCamera Height") then
			table.restore(hr, "Enemy turn TacCamera Height")
		end
		if target then 
			floor = floor or GetFloorOfPos(SnapToPassSlab(target))
			sleepTime = sleepTime or 1000
			if noFitCheck or not DoPointsFitScreen({IsPoint(target) and target or target:GetVisualPos()}, nil, const.Camera.BufferSizeNoCameraMov) then
				SnapCameraToObj(target, "force", floor, sleepTime)
			end
		end
	end
end

function OnMsg.NewMapLoaded()
	cameraTac.SetLockedMovement(false)
	g_CombatCamAttackStack = {}
end

local function CombatCam_CheckDeactivate()
	if not cameraTac.IsActive() or #g_CombatCamAttackStack > 0 or CurrentActionCamera or IsSetpiecePlaying() then
		return
	end
	UnlockCameraMovement("CombatCamera")
	cameraTac.SetForceMaxZoom(false)
end

local CombatCam_ScreenBuffer = 20
local CombatCam_DepthScale = 100
local CombatCam_NetZone = false
local CombatCam_ZoneThread = false
function NetSyncEvents.CalcCameraZone(zone)
	CombatCam_NetZone = zone
	if IsValidThread(CombatCam_ZoneThread) then --only exists if both clients are calling the func
		Msg(CombatCam_ZoneThread)
	end
	CombatCam_ZoneThread = false
end

function CalcCombatZone(buffer, depth_scale)
	buffer = buffer or CombatCam_ScreenBuffer
	depth_scale = depth_scale or CombatCam_DepthScale
	
	local w, h = UIL.GetScreenSize():xy()
	local x1, y1 = MulDivRound(w, 100 - buffer, 100), MulDivRound(h, 100 - buffer, 100)
	local x2, y2 = MulDivRound(w, buffer, 100), MulDivRound(h, 100 - buffer, 100)

	local zone = {}
	local wx1, wy1 = GetTerrainCursorXY(x1, y1):xy()
	local wx2, wy2 = GetTerrainCursorXY(x2, y2):xy()
	zone[1] = point(wx1, wy1)
	zone[2] = point(wx2, wy2)
	
	local dx, dy = MulDivRound(wy1 - wy2, depth_scale, 100), MulDivRound(wx2 - wx1, depth_scale, 100) -- subtract, scale and apply rotation
	local rx, ry = GetTerrainCursorXY(w / 2, MulDivRound(h, buffer, 100)):xy()
	local rdx, rdy = rx - wx1, ry - wy1
	if dx*rdx + dy*rdy < 0 then
		dx, dy = -dx, -dy
	end
	zone[3] = point(wx2 + dx, wy2 + dy)
	zone[4] = point(wx1 + dx, wy1 + dy)

	local cx, cy = 0, 0
	for i, pos in ipairs(zone) do
		local x, y = pos:xy()
		cx, cy = cx + x, cy + y
	end
	zone.center = point(cx / 4, cy / 4)
	
	return zone
end

function NetSyncEvents.TestCalcCombatZone()
	local z1, z2
	CreateGameTimeThread(function()
		z1 = CombatCam_CalcZone()
	end)
	CreateGameTimeThread(function()
		z2 = CombatCam_CalcZone()
	end)
	print("TestCalcCombatZone", z1, z2)
end

function CombatCam_CalcZone(buffer, depth)
	NetUpdateHash("CombatCam_CalcZone")
	if not cameraTac.IsActive() and not IsGameReplayRunning() then --gamereplay should get recorded values
		assert(not netInGame) --this can cause desyncs, try n catch it when it happens;
		return
	end
	
	local playingReplay = IsGameReplayRunning()
	local recordingReplay = not not GameRecord
	
	if netInGame or playingReplay then
		assert(CurrentThread() and IsGameTimeThread())
		if not NetIsHost() or playingReplay then
			CombatCam_NetZone = false
			if not IsValidThread(CombatCam_ZoneThread) then
				CombatCam_ZoneThread = CurrentThread()
			end
			local wokeup = WaitMsg(CombatCam_ZoneThread, 11000)
			if CombatCam_NetZone then --if it timeouted something is wrong with the net game, roll with it.
				local ret = CombatCam_NetZone
				return ret
			end
			assert(false, "client failed to get host's cam zone")
		end
	end
	
	local zone = CalcCombatZone(buffer, depth)
	
	if netInGame or recordingReplay then
		if NetIsHost() or recordingReplay then
			if not IsValidThread(CombatCam_ZoneThread) then
				CombatCam_ZoneThread = CurrentThread()
				NetSyncEvent("CalcCameraZone", zone)
			end
			WaitMsg(CombatCam_ZoneThread, 11000)
		end
	end
	
	return zone
end

function CombatCam_DbgZone(zone)
	for i = 1, 4 do
		DbgAddVector(zone[i])
	end
	DbgAddVector(zone.center)
	NetUpdateHash("CombatCam_DbgZone", hashParamTable(zone), zone[1], zone[2], zone[3], zone[4])
end

function CountUnitsInZone(x, y, units, zone, return_units)
	local cx, cy = zone.center:xy()
	local count = 0
	local selected = return_units and {} or nil
	for _, u in ipairs(units) do
		-- offset from current unit -> add to zone center -> check if inside zone
		local ux, uy 
		if IsValid(u) then
			ux, uy = u:GetVisualPosXYZ()
		else
			assert(IsPoint(u))
			ux, uy = u:xy()
		end
		local pos = point(cx + ux - x, cy + uy - y)
		if IsPointInsidePoly2D(pos, zone) then
			count = count + 1
			if selected then
				selected[#selected + 1] = u
			end
		end
	end
	return count, selected
end

local function CombatCam_RemoveAttacker(unit)
	--if unit == g_CombatCamAttackStack[1] then
		table.remove(g_CombatCamAttackStack, 1)
		table.remove(g_CombatCamAttackStack, 1)
		CombatCam_CheckDeactivate()
	--end
	Msg("CombatCamAttackQueueUpdate")
end

--OnMsg.CombatActionEnd = CombatCam_RemoveAttacker
OnMsg.ActionCameraRemoved = CombatCam_CheckDeactivate
OnMsg.SetpieceDialogClosed = CombatCam_CheckDeactivate

--[[function CombatCam_FailSafeUpdate()
	if #g_CombatCamAttackStack > 0 then
		local unit = g_CombatCamAttackStack[1]
		if not HasCombatActionInProgress(unit) then
			CombatCam_RemoveAttacker(unit)
		end
	end
	CombatCam_CheckDeactivate()
end

MapGameTimeRepeat("CombatCam_FailSafe", 100, CombatCam_FailSafeUpdate)]]

local function CombatCam_CalcAttackCamPos(attacker, target)
	local lookat = attacker
	local zone = CombatCam_CalcZone()
	if target and zone then
		local attack_pos = IsValid(attacker) and attacker:GetVisualPos()
		if not attack_pos then
			return
		end
		local target_pos = IsValid(target) and target:GetVisualPos() or target
		if not target_pos:IsValidZ() then
			target_pos = target_pos:SetTerrainZ()
		end
		
		local x, y = zone.center:xy()
		lookat = (attack_pos + target_pos) / 2
		if CountUnitsInZone(x, y, {attack_pos, target_pos}, zone) == 2 then
			return
		end
	end
	local lookat_pos = IsValid(lookat) and lookat:GetVisualPos() or lookat
	if zone and IsCloser(zone.center, lookat_pos, 5*guim) then
		return
	end
	return lookat, zone
end

--[[MapVar("g_CombatCamShowAttackLog", false)

function dbgCombatCamAttack(i)
	if not g_CombatCamShowAttackLog or not i or #g_CombatCamShowAttackLog < i then
		return
	end
	local item = g_CombatCamShowAttackLog[i]
	
	DbgClearVectors()
	DbgAddVector(item.attacker_pos, point(0, 0, 3*guim), const.clrWhite)
	DbgAddVector(item.target_pos, point(0, 0, 3*guim), const.clrRed)
	
	local zone = item.zone
	for i = 1, 4 do
		local ti = 1 + i % 4
		DbgAddVector(zone[i]:SetTerrainZ(10*guic), (zone[ti] - zone[i]):SetZ(0), const.clrGreen)
	end
end--]]

function CombatCam_ShowAttack(attacker, target)
	local zone = CombatCam_CalcZone()
	if IsPointInsidePoly2D(attacker, zone) and (not target or IsPointInsidePoly2D(target, zone)) or CurrentActionCamera then
		return
	end
	
	LockCameraMovement("CombatCamera") -- queued calls will lock multiple times with the same reason (equivalent to single lock) and _Deactivate will only unlock when the queue is empty
	
	-- add in queue
	g_CombatCamAttackStack[#g_CombatCamAttackStack + 1] = attacker
	g_CombatCamAttackStack[#g_CombatCamAttackStack + 1] = target
	
	-- wait until we're the first item in the queue
	while g_CombatCamAttackStack[1] ~= attacker do
		WaitMsg("CombatCamAttackQueueUpdate", 100)
	end
	
	-- wait until action camera is done
	while ActionCameraPlaying do
		WaitMsg("ActionCameraRemoved", 100)
	end
	
	if not HasCombatActionInProgress(attacker) then
		return CombatCam_RemoveAttacker(attacker)
	end	
	local lookat, zone = CombatCam_CalcAttackCamPos(attacker, target)

	--[[g_CombatCamShowAttackLog = g_CombatCamShowAttackLog or {}
	table.insert(g_CombatCamShowAttackLog, {
		zone = zone,
		attacker = attacker,
		attacker_pos = attacker:GetVisualPos(),
		target = target,
		target_pos = IsValid(target) and target:GetVisualPos() or target,
	})--]]

	if not lookat or not zone then -- already in camera
		return
	end
	
	local x, y = lookat:xy()
	if CountUnitsInZone(x, y, {attacker, target}, zone) < 2 then
		cameraTac.SetForceMaxZoom(true)
		-- todo: maybe try to fit target in the zone instead
	end
	
	local floor = GetFloorOfPos(SnapToPassSlab(attacker))
	local pos = SnapToPassSlab(target)
	if pos then
		floor = Max(floor, GetFloorOfPos(pos))
	end
	
	SnapCameraToObj(lookat, "force", floor)
	Sleep(500)
end

MapVar("showAttack", false)

function CombatCam_ShowAttackNew(attacker, target, willBeinterrupted, results, freezeCamPos, changeFloorOnly)
	if CurrentActionCamera then
		return
	end
	
	--queued calls will lock multiple times with the same reason (equivalent to single lock) and _Deactivate will only unlock when the queue is empty
	LockCameraMovement("CombatCamera")
	cameraTac.SetForceMaxZoom(false)
	cameraTac.SetForceMaxZoom(true)
	
	table.insert(g_CombatCamAttackStack, 1, attacker)
	table.insert(g_CombatCamAttackStack, 2, target)
	
	showAttack = showAttack or CreateGameTimeThread(function()
		repeat 
			local attacker = g_CombatCamAttackStack[1]
			local target = not IsPoint(g_CombatCamAttackStack[2]) and g_CombatCamAttackStack[2]:GetVisualPos() or g_CombatCamAttackStack[2]
			local isTargetUnit = IsKindOf(g_CombatCamAttackStack[2], "Unit") and g_CombatCamAttackStack[2] or false
			
			-- wait until action camera is done
			while ActionCameraPlaying do
				WaitMsg("ActionCameraRemoved", 100)
			end
			
			local floor = GetFloorOfPos(SnapToPassSlab(target))
			local pos, look = cameraTac.GetPosLookAt()
			local cameraInZone = DoPointsFitScreen({target}, look, const.Camera.BufferSizeNoCameraMov)
			

			if not willBeinterrupted then 
				-- do not lock to target if interrupt will follow, but go through the other logic
				-- to queue the snap camera later when the attack will be executed
				if not freezeCamPos then 
					SnapCameraToObj(cameraInZone and look or target, "force", floor)
				elseif changeFloorOnly then
					cameraTac.SetFloor(floor, hr.CameraTacInterpolatedMovementTime * 10, hr.CameraTacInterpolatedVerticalMovementTime * 10)
				end
			else
				willBeinterrupted = false
			end
			ShowBadgesOfTargets(isTargetUnit and {isTargetUnit} or results, "show")
			
			local interrupted = false
			local consecutiveAttacks = false
			while not g_CombatCamAttackStack[1]:IsIdleCommand() do
				if g_CombatCamAttackStack[1] ~= attacker then
					interrupted = true
					break
				elseif g_CombatCamAttackStack[1] == g_CombatCamAttackStack[3] then
					table.remove(g_CombatCamAttackStack, 3)
					table.remove(g_CombatCamAttackStack, 3)
					consecutiveAttacks = true
					break
				end
				Sleep(100)
			end
			
			if not interrupted then
				ShowBadgesOfTargets(isTargetUnit and {isTargetUnit} or results, "hide")
				if not consecutiveAttacks then
					CombatCam_RemoveAttacker(attacker)
					ClearAITurnContours()
				end
			end
			
		until #g_CombatCamAttackStack <= 0 
		
		showAttack = false
	end)
end

function ShowBadgesOfTargets(results, show)
	if show == "show" then
		for _, obj in ipairs(results.hit_objs or results) do
			if IsKindOf(obj, "Unit") and obj.ui_badge then
				table.insert(g_ShowTargetBadge, obj)
				obj.ui_badge:SetActive(true, "showTarget")
			end
		end
	elseif show == "hide" then
		for _, obj in ipairs(results.hit_objs or results) do
			if IsKindOf(obj, "Unit") and obj.ui_badge then
				local currentTeam = g_Combat and g_Teams[g_Combat.team_playing]
				if not currentTeam or currentTeam.control ~= "UI" then
					obj.ui_badge:SetActive(false, "showTarget")
				else
					obj.ui_badge.active_reasons.showTarget = false
				end
				table.remove(g_ShowTargetBadge, table.find(g_ShowTargetBadge, obj))
			end
		end
	end
end

---------------------------------------
MapVar("g_AIExecutionController", false)
MapVar("g_AIExecutionControllerCamera", false)

function CreateAIExecutionController(obj, testActions)
	while g_AIExecutionController do
		WaitMsg("ExecutionControllerDeactivate", 500)
	end
	AIExecutionController:new(obj)
	g_AIExecutionController.testAllAttacks = testActions
	return g_AIExecutionController
end

DefineClass.AIExecutionController_Camera = {
	__parents = { "InitDone" }
}

function AIExecutionController_Camera:Done()
	UnlockCameraMovement(self)
end

function AIExecutionController_Camera:SelectObjsInZone(objs, zone)
	if not zone or not objs or #objs == 0 then
		return
	end
	
	local clusters = ClusterUnits(objs)
	-- pick cluster closest to current zone
	local nearest, ndist
	for _, cluster in ipairs(clusters) do
		local dist = zone.center:Dist(point(cluster.x, cluster.y))
		if not nearest or dist < ndist then
			nearest, ndist = cluster, dist
		end
	end
	
	return nearest and nearest.objs
end

function AIExecutionController_Camera:FitObjsInZone(objs, zone, floor, sleep_time)
	if not objs or #objs == 0 then return end
	
	local x, y = zone.center:xy()
	local in_zone = CountUnitsInZone(x, y, objs, zone)
	floor = floor or HighestFloorOfGroup(objs)
	if in_zone < #objs then
		local center = IsValid(objs[1]) and objs[1]:GetVisualPos() or objs[1]
		for i = 2, #objs do
			center = center + (IsValid(objs[i]) and objs[i]:GetVisualPos() or objs[i])
		end
		center = center / #objs
		SnapCameraToObj(center,  "force", floor, sleep_time)
		if sleep_time then
			Sleep(sleep_time)
			return true
		end
	end
	return false
end

-- Not sync
function AIExecutionController_Camera:CombatCamCalcZone()
	return CalcCombatZone()
end

function AIExecutionController_Camera:ShowUnits(units, wait_time)
	assert(CurrentThread())
	local pov_team = GetPoVTeam()
	LockCameraMovement(self)
	
	local w, h = UIL.GetScreenSize():xy()
	local pos, restore_pt = cameraTac.GetPosLookAt()
	local restore_floor = cameraTac.GetFloor()
	local willMoveCam
	
	while #units > 0 and g_Combat do
		local zone = self:CombatCamCalcZone()
		if not zone then 
			break
		end	
		local group = self:SelectObjsInZone(units, zone)
		willMoveCam = self:FitObjsInZone(group, zone, g_Teams[g_CurrentTeam].control == "UI" and restore_floor or false, wait_time) or willMoveCam
		for _, unit in ipairs(group) do
			table.remove_value(units, unit)
			pov_team.seen_units = pov_team.seen_units or {}
			table.insert(pov_team.seen_units, unit:GetHandle())
		end
		if g_AIExecutionController and g_AIExecutionController ~= self then
			return
		end
	end

	if g_Combat and willMoveCam then
		SnapCameraToObj(restore_pt, nil, restore_floor)
		Sleep(500)
	end
end

DefineClass.AIExecutionController = {
	__parents = { "InitDone", "AIExecutionController_Camera" },
	label = false,
	reposition = false,
	restore_camera_obj = false,
	claimed_markers = false,
	tracked_pois = false,
	cinematic_combat_camera = false,
	attacker = false,
	target = false,
	zone = false,
	enable_logging = false,
	override_notification = false,
	override_notification_text = false,
	units_playing = false,
	start_time = 0,
	group_to_follow = false,
	track_group = false,
	currently_playing = false,
	testAllAttacks = false,
	fallbackMoveTracking = false,
}

function AIExecutionController:Init()
	assert(not g_AIExecutionController)
	g_AIExecutionController = self
	self.claimed_markers = {}
	self.units_playing = {}
	Msg("ExecutionControllerActivate")
end

function AIExecutionController:Done()
	NetUpdateHash("AIExecutionController_Done")
	assert(g_AIExecutionController == self)
	UnlockCameraMovement(self, "unlock_all")
	if self.restore_camera_obj then
		AdjustCombatCamera("reset", nil, self.restore_camera_obj, nil, nil, "noFitCheck")
	end
	g_AIExecutionController = false
	Msg("ExecutionControllerDeactivate")
	ObjModified(SelectedObj)
end

function AIExecutionController:IsUnitPlaying(unit)
	return self.units_playing[unit]
end

function AIExecutionController:UpdateControlledUnits(units)
	local new_units = {}
	for _, unit in ipairs(units) do
		local should_play = (not unit:IsAware() and unit.pending_aware_state) or (unit.ActionPoints >= MinAPToPlay)
		local valid_target = IsValidTarget(unit)
		if valid_target and not unit:IsDefeatedVillain() and not unit:IsIncapacitated() and not unit.team.neutral and unit.command ~= "ExitMap" and should_play then
			if not self.units_playing[unit] then
				self.units_playing[unit] = true
				unit:UpdateHighlightMarking()
			end
			if not unit:IsAware() then
				if unit.pending_aware_state == "aware" then
					if unit:HasStatusEffect("Suspicious") or unit:HasStatusEffect("Surprised") then
						unit:AddStatusEffect("OpeningAttackBonus")
					end
					unit:RemoveStatusEffect("Suspicious")
					unit:RemoveStatusEffect("Unaware")
					unit:RemoveStatusEffect("Surprised")
					if unit:HasStatusEffect("Unconscious") then
						unit.pending_aware_state = nil
					else
						new_units[#new_units + 1] = unit
					end
				elseif unit.pending_aware_state == "surprised" then
					unit:AddStatusEffect("Surprised")
					unit.pending_aware_state = nil
				elseif unit.pending_aware_state == "suspicious" then
					unit:AddStatusEffect("Suspicious")
					unit:RemoveStatusEffect("Unaware")
					unit.pending_aware_state = nil
				end
			elseif unit.pending_aware_state == "reposition" then
				new_units[#new_units + 1] = unit
			else
				unit.pending_aware_state = nil
				new_units[#new_units + 1] = unit
			end
		elseif valid_target then
			unit.pending_aware_state = nil
			new_units[#new_units + 1] = unit
		end
	end
	return new_units
end

MapVar("g_LastTurnAILog", {})

function AIExecutionController:Log(...)
	if self.enable_logging then
		local line = string.format(...)
		g_LastTurnAILog[#g_LastTurnAILog + 1] = string.format("[AI][%d] %s", GameTime(), line)
	end
end

function DelayAfterExplosion()
	if g_LastExplosionTime then
		NetUpdateHash("DelayAfterExplosion", g_LastExplosionTime, const.CombatCamExplosionDelay)
		Sleep(Max(0, g_LastExplosionTime + const.CombatCamExplosionDelay - GameTime()))
	end	
end

local function FallbackDespawnExitMapUnits()
	if not g_AIExecutionController or g_AIExecutionController.start_time + 3000 > GameTime() then
		return
	end
	
	for _, unit in ipairs(g_Units) do
		if unit.command == "ExitMap" then
			unit:SetCommand("Despawn")
		end
	end
end

if FirstLoad then
	mp_resolution_results = false
end

function NetSyncEvents.GetResolution(player_id, res)
	mp_resolution_results = mp_resolution_results or {}
	mp_resolution_results[player_id] = res
	Msg("ResUpdated")
end

function Mp_SetUserRes(res)
	CreateRealTimeThread(function() 
		if GameState.sync_loading then
			WaitMsg("SyncLoadingDone") --dont do this while changing maps n such
		end
		mp_resolution_results = mp_resolution_results or {}
		NetSyncEvent("GetResolution", netUniqueId, res)
		local ok = WaitMsg("ResUpdated", 5 * 1000)
		if not ok then
			assert("Failed to update res table for MP.")
		end
	end)
end

function OnMsg.SystemSize(res)
	if netInGame then
		Mp_SetUserRes(res)
	end
end

function OnMsg.NetGameJoined()
	Mp_SetUserRes(UIL.GetScreenSize())
end

function OnMsg.NetGameLeft()
	mp_resolution_results = false
end

function NetSyncEvents.Mp_DoPointsFitScreen(res)
	Msg("DoesFitScreen", res)
end


function Mp_PickSmallerPlayingField(choices)
	--Based on w/h ration choose the bigger one as it often means smaller gameplay area shown
	local player1Ratio = MulDivRound(mp_resolution_results[1]:x(), 10000, mp_resolution_results[1]:y())
	local player2Ratio =MulDivRound(mp_resolution_results[2]:x(), 10000, mp_resolution_results[2]:y())
	
	return player1Ratio > player2Ratio and choices[1] or choices[2]
end

function DoPointsFitScreen(points, screenCenterPos, screenBufferPerc)
	NetUpdateHash("DoPointsFitScreen")
	
	if not cameraTac.IsActive() and not IsGameReplayRunning() then
		assert(not netInGame)
		return
	end
	
	local playingReplay = IsGameReplayRunning()
	local recordingReplay = not not GameRecord
	
	if netInGame and NetIsHost() and table.count(netGamePlayers) == 2 and (not mp_resolution_results or #mp_resolution_results ~= 2) then
		assert(false, "[DoPointsFitScreen] Failed to get both players resolutions.")
		return
	end
	
	if netInGame and not NetIsHost() or playingReplay then
		local ok, res = WaitMsg("DoesFitScreen", 5 * 1000)
		if not ok then
			assert(false, "[DoPointsFitScreen] Failed to receive result from host.")
			return
		end
		return res
	end
	
	local doesFit = true
	local smallerResolution = table.count(netGamePlayers) == 2 and Mp_PickSmallerPlayingField(mp_resolution_results) or UIL.GetScreenSize()
	
	local screenSize = smallerResolution
	local screenBufferW = screenBufferPerc and MulDivRound(screenSize:x(), screenBufferPerc, 100) or 0
	local screenBufferH = screenBufferPerc and MulDivRound(screenSize:y(), screenBufferPerc, 100) or 0
	local bufferedScreenMinPoint = point(screenBufferW, screenBufferH)
	local bufferedScreenMaxPoint = smallerResolution - point(screenBufferW, screenBufferH)
	local safeArea = box(bufferedScreenMinPoint, bufferedScreenMaxPoint)
	local ptCamera, ptCameraLookAt = GetCameraPosLookAtOnPos(screenCenterPos)
	
	local pointsPosOnScreen = { GameToScreenFromView(ptCamera, ptCameraLookAt, screenSize:x(), screenSize:y(), table.unpack(points)) }
	
	for _, scrnPoint in pairs(pointsPosOnScreen) do
		if not safeArea:Point2DInside(scrnPoint) then
			doesFit = false
			break
		end
	end
	
	if not next(pointsPosOnScreen) then
		doesFit = false
	end

	if netInGame and NetIsHost() and table.count(netGamePlayers) == 2 or recordingReplay then
		NetSyncEvent("Mp_DoPointsFitScreen", doesFit)
		local ok, res = WaitMsg("DoesFitScreen", 5 * 1000)
		if not ok then
			assert(false, "[DoPointsFitScreen] Failed to send result to client.")
			return
		end
		return res
	end
	
	return doesFit
end

local MoveAndAttack = { RunAndGun = true, MobileShot = true, Charge = true, HyenaCharge = true }
local AOE_keywords = { "Soldier", "Control", "Explosives", "Ordnance" }
local AOE_archetypes = { "Artillery" }
local function UnitAoeChance(unit)
	local ai_context = unit.ai_context
	local aoe_chance = 0
	for _, keyword in ipairs(unit.AIKeywords) do
		if table.find(AOE_keywords, keyword) then
			 aoe_chance = aoe_chance + 100
		end
	end
	if table.find(AOE_archetypes, ai_context.archetype.id) then
		aoe_chance = aoe_chance + 100
	end
	return Clamp(aoe_chance, 0, 100)
end

local function __AIExecutionControllerExecute(self, units, reposition, played_units)
	assert(CurrentThread())
	if not g_Combat then return end
	
	local pov_team = GetPoVTeam()
	local max_sight_radius = MulDivRound(const.Combat.AwareSightRange, const.SlabSizeX * const.Combat.SightModMaxValue, 100)
	
	self.start_time = GameTime()
	
	DelayAfterExplosion()
	ObjModified(g_Combat) -- update ui

	LockCameraMovement(self)

	g_AIDestEnemyLOSCache = {}
	g_AIDestIndoorsCache = {}

	if self.enable_logging then
		g_LastTurnAILog = {}
	end

	if self.override_notification then
		ShowTacticalNotification(self.override_notification, true, self.override_notification_text)
	end
	
	--repo and turn notifications need to be neutral based on the allyInUnits flag
	local function FindAllyInUnits(units)
		for _, unit in ipairs(units) do
			if unit.team.side == "ally" or unit.team.player_team then
				return true
			end
		end
		return false
	end
	
	local allyInUnits = FindAllyInUnits(units)
	local moveAttackException --flag to keep check if some unit action will stop the cinematic camera trigger for this group
	local hiddenTurnShowMercs --flag to show once mercs during hidden turn (only the first time it happens it is possible the camere to not be showing anything of interest)
	
	-- start of turn
	if not self.reposition then		
		-- StartAI on all aware units in 'units' since it is needed for AIGetNextPhaseUnits; only applies to normal turn
		if not self.override_notification then
			if allyInUnits then 
				ShowTacticalNotification("allyTurnPhase") 
			else
				ShowTacticalNotification("enemyTurnPhase")
			end
		end
		for _, unit in ipairs(units) do
			if not unit:IsIncapacitated() and unit:IsAware() and unit.ActionPoints > 0 then
				unit:StartAI() -- this can indirectly sleep internally in AIUpdateDestLosCache
				table.insert_unique(played_units, unit)
			end
		end
		if not self.override_notification then
			if allyInUnits then 
				HideTacticalNotification("allyTurnPhase")
			else
				HideTacticalNotification("enemyTurnPhase")
			end
		end
	end
	self:Log("Start turn execution (%d units)", #units)
	
	local awareness_anims_played
	local to_play = {}
	local engaged = false
	
	if #units > 0 and g_Combat and netInGame then
		--sync camera for both clients before using it to determine zones
		local closestUnit = false
		local closestDist = max_int
		for _, unit in ipairs(pov_team.units) do
			for i = 1, #units do
				local otherUnit = units[i]
				if otherUnit == unit then
					closestUnit = unit
					goto continue
				elseif not closestUnit or IsCloser(unit, otherUnit, closestUnit) then
					closestUnit = unit
				end
			end
		end
		::continue::
		if closestUnit then
			SnapCameraToObj(closestUnit, nil, nil, 1000)
			NetUpdateHash("SnapCameraToObj", closestUnit)
		end
	end
	
	while #units > 0 and g_Combat do --units contain all the units to be played by the execution controller
		if self.reposition and not g_Combat.enemies_engaged then
			local engage = true
			if self.label == "AlwaysReady" then
				-- check if 'units' contain anyone other than 'activator'
				engage = false
				for _, unit in ipairs(units) do
					engage = engage or (unit ~= self.activator)
				end
			end
			if engage then
				g_Combat.enemies_engaged = true
				engaged = true
				Msg("RepositionStart")
			end
		end
	
		-- preprocess units: remove dead/defeated, update awareness
		units = self:UpdateControlledUnits(units)
		
		-- also check remaining units in to_play
		for i = #to_play, 1, -1 do
			local unit = to_play[i]
			if not IsValidTarget(unit) or unit:IsDefeatedVillain() or unit.command ~= "Die" or unit.command == "ExitMap" or unit.ActionPoints < MinAPToPlay then
				table.remove(to_play, i)
			end
		end
		
		self:Log("Processing %d units...", #units)
		-- select a group of units to play
		local zone = CombatCam_CalcZone()
		--in multiplayer or in replay recording/playing we are going to wait for zone to arrive through netsync ev;
		--sometimes when playing a recording the netsync thread may not execute in the correct order;
		--this sleep shifts it to next game ms for that purpose;
		Sleep(1)
		NetUpdateHash("CombatCam_CalcZone_Done")
		local playing 
		if #to_play > 0 then
			playing = to_play 
		else
			playing = self:SelectPlayingUnits(units, zone) or empty_table --get all units that will move together based on the combat zone picked by nearest unit
		end
		to_play = {}
		--local playing = table.icopy(units)
		self:Log("%d units selected", #playing)
		if #playing == 0 then
			break
		end
		--used for marking only the currently moving/performing actions units
		self.currently_playing = playing
	
		local units_repositioning = self.reposition or not not playing[1].pending_aware_state
		if Platform.developer then
			-- either all units should be repositioning or none of them
			for i = 2, #playing do
				assert((not not playing[i].pending_aware_state) == units_repositioning)
			end
		end
	
		-- preparation & tracking of visible positions/destinations, reveal units ending up on a visible destination
		local pois = {}
		local max_dest_floor = -1
		local cinematicUnits = {}
		for playing_idx, unit in ipairs(playing) do
			local dest
			if not g_Combat then break end
			if units_repositioning then
				if g_Combat and ((self.label == "AlwaysReady" and unit == self.activator) or not g_Combat:IsRepositioned(self)) then
					unit.ActionPoints = MulDivRound(unit:GetMaxActionPoints(), const.Combat.RepositionAPPercent, 100)

					if unit:HasStatusEffect("FreeReposition") then
						unit.free_move_ap = unit.free_move_ap + 999999
						unit.ActionPoints = unit.ActionPoints + 999999
					end

					unit:StartAI()
					if not g_Combat or unit:IsIncapacitated() then break end
					table.insert_unique(played_units, unit)
					if self.label ~= "AlwaysReady" or unit ~= self.activator then
						unit:PickRepositionDest()
					end
				end
				dest = unit.reposition_dest -- can be ai_context.ai_destination or a dest from a reposition marker
				if unit.reposition_marker then
					self.claimed_markers[#self.claimed_markers] = unit.reposition_marker
				end
				if unit.pending_aware_state == "reposition" then
					unit.pending_aware_state = nil
				end
				self:Log("  Unit %s (%d) reposition dest: %d (%s)", unit.unitdatadef_id, unit.handle, dest, unit.reposition_marker and "marker" or "no marker")
				assert(not dest or CanOccupy(unit, stance_pos_unpack(dest)))
			else
				assert(unit.ai_context and unit.ai_context.behavior)
				unit.ai_context.behavior:Think(unit)

				-- debug code: check same destination
				if playing_idx > 1 then
					local dest = unit.ai_context.ai_destination
					local occupied = dest and point(stance_pos_unpack(dest)) or GetPassSlab(unit) or SnapToVoxel(unit)
					for k = 1, playing_idx - 1 do
						local unit2 = playing[k]
						local dest2 = unit2.ai_context.ai_destination
						local occupied2 = dest2 and point(stance_pos_unpack(dest2)) or GetPassSlab(unit2) or SnapToVoxel(unit2)
						if occupied == occupied2 then
							printf('Occupied ai_destination %s. AI behaviors: %s, %s', tostring(occupied), unit.ai_context.behavior.class, unit2.ai_context.behavior.class)
							assert(false, "occupied ai_destination!!!")
							for j = 1, 20 do
								unit.ai_context.behavior:Think(unit)
							end
						end
					end
				end

				if not g_Combat then break end
				unit.ai_context.behavior:TakeStance(unit)
				if not g_Combat then break end
				dest = unit.ai_context.ai_destination
				
				
				local willMove = unit.ai_context.ai_destination and (stance_pos_dist(unit.ai_context.ai_destination, stance_pos_pack(unit)) ~= 0)
				if willMove then
					local currPos = unit:GetVisualPos()
					local destPost = point(stance_pos_unpack(unit.ai_context.ai_destination))
					willMove = currPos:Dist(destPost) > const.Camera.MinTrackDistance
				end
				local isTargetUnit = IsKindOf(unit.ai_context.dest_target[unit.ai_context.ai_destination], "Unit")
				local target = isTargetUnit and unit.ai_context.dest_target[unit.ai_context.ai_destination]
				local middlePoint = target and (point(stance_pos_unpack(unit.ai_context.ai_destination)) + target:GetVisualPos()) / 2
				local hasAp = not unit.ai_context.dest_ap[unit.ai_context.ai_destination] or unit.ai_context.dest_ap[unit.ai_context.ai_destination] >= unit.ai_context.default_attack_cost
				
				local willFit = middlePoint and DoPointsFitScreen({ target:GetVisualPos(), point(stance_pos_unpack(unit.ai_context.ai_destination)) }, 
																					middlePoint,
																					10)
				
				local interrupts = unit:CheckProvokeOpportunityAttacks("attack interrupt", {unit.target_dummy or unit})
			
				moveAttackException = moveAttackException or unit.ai_context and unit.ai_context.movement_action and MoveAndAttack[unit.ai_context.movement_action.action_id] or MoveAndAttack[unit.action_command]
				if not self.testAllAttacks and isTargetUnit and hasAp and willMove and willFit and not interrupts and not g_Combat:GetEmplacementAssignment(unit) and target.visible then
					local aoe_chance = UnitAoeChance(unit)
					if aoe_chance ~= 100 then
						cinematicUnits[unit.handle] = aoe_chance
						table.insert(cinematicUnits, unit)
					end
				end
				
				self:Log("  Unit %s (%d) (archetype: %s, behavior: %s) dest: %s", unit.unitdatadef_id, unit.handle, unit.current_archetype, unit.ai_context.behavior:GetEditorView(), tostring(dest))
				assert(not dest or CanOccupy(unit, stance_pos_unpack(dest)))
			end
			if HasVisibilityTo(pov_team, unit) then
				pois[#pois + 1] = unit
			end
			if dest then
				local rx, ry, rz, rs = stance_pos_unpack(dest)
				unit:ClearEnumFlags(const.efResting)
				PlaceDestlock(unit, rx, ry, rz)
				local step_pos = point(rx, ry, rz)
				local willReveal = RevealUnitBeforeMove(unit, {goto_pos = step_pos, goto_stance = rs})
				if willReveal then
					pois[#pois + 1] = unit
				end
				
				max_dest_floor = Max(max_dest_floor, GetFloorOfPos(step_pos))
				--[[local volume = EnumVolumes(step_pos, "smallest")
				if volume then
					local floor = GetFloorOfPos(step_pos)
					max_dest_floor = Max(max_dest_floor, floor)
				end--]]
			end
			local pos = SnapToPassSlab(unit) or unit:GetPos()
			max_dest_floor = Max(max_dest_floor, GetFloorOfPos(pos))
			--[[local volume = pos and EnumVolumes(pos, "smallest")
			if volume then
				local floor = GetFloorOfPos(pos)
				max_dest_floor = Max(max_dest_floor, floor)
			end--]]
		end

		-- destroy destlocks and apply efResting (before starting movement)
		for i = #playing, 1, -1 do
			playing[i]:ClearPath()
		end

		-- Remove action camera if on.
		assert(netInGame or not not ActionCameraPlaying == not not CurrentActionCamera)
		if ActionCameraPlaying or CurrentActionCamera then
			RemoveActionCamera(true)
			if ActionCameraPlaying then
				WaitMsg("ActionCameraRemoved", 5000)
			end
		end
		
		
		local cinematicUnit
		for _, unit in ipairs(cinematicUnits) do
			local aoe_chance = cinematicUnits[unit.handle]
			if cinematicUnit and cinematicUnits[cinematicUnit.handle] > aoe_chance or not cinematicUnit then
				cinematicUnit = unit
			end
		end
		if cinematicUnit and not moveAttackException then
			StartCinematicCombatCamera(cinematicUnit, cinematicUnit.ai_context.dest_target[cinematicUnit.ai_context.ai_destination])
		end

		-- move camera if needed, update tactical notifications
		local sleep_t = 500
		local did_sleep = false
		if #pois > 0 then
			local floor
			if max_dest_floor > -1 then
				floor = Clamp(max_dest_floor, hr.CameraTacMinFloor, hr.CameraTacMaxFloor)
			end
			--did_sleep = CenterCameraOnObj(pois, floor, sleep_t)
			if not self.override_notification then
				HideTacticalNotification("turn")
				if FindAllyInUnits(pois) then 
					ShowTacticalNotification(units_repositioning and "allyRepositionPhase" or "allyTurnPhase", true)
				else
					ShowTacticalNotification(units_repositioning and "enemyRepositionPhase" or "enemyTurnPhase", true)
				end
			end
		else
			if not self.override_notification then
				HideTacticalNotification("turn")
				if FindAllyInUnits(playing) then 
					ShowTacticalNotification(units_repositioning and "allyHiddenRepoPhase" or "allyHiddenTurnPhase", true)
				else
					ShowTacticalNotification(units_repositioning and "hiddenEnemyRepoPhase" or "hiddenEnemyTurnPhase", true)
				end
			end
		end
		if IsCompetitiveGame() and not did_sleep then
			Sleep(sleep_t) --sync with other client combatcam, who may or may not have slept
		end
		if not IsCompetitiveGame() then
			NetUpdateHash("__AIExecutionControllerExecute_playing", hashParamTable(playing))
		end

		self.zone = CombatCam_CalcZone()
		local attacker, mover
		if (not pois or #pois <= 0) and not hiddenTurnShowMercs then
			local selected = self:SelectObjsInZone(pov_team.units, self.zone)
			local closestMerc = false
			for _, merc in ipairs(selected) do
				if not closestMerc or IsCloser(self.zone.center, merc:GetPos(), closestMerc:GetPos()) then
					closestMerc = merc
					hiddenTurnShowMercs = true
				end
			end
			AdjustCombatCamera("set", nil, closestMerc)
		else
			AdjustCombatCamera("set")
		end
		Sleep(500)
		-- start movement (parallel)
		for i, unit in ipairs(playing) do
			if not g_AITurnContours[unit.handle] then
				local enemy = unit.team.side == "enemy1" or unit.team.side == "enemy2" or unit.team.side == "neutralEnemy"
				g_AITurnContours[unit.handle] = SpawnUnitContour(unit, enemy and "CombatEnemy" or "CombatAlly")
				ShowBadgeOfAttacker(unit, true)
			end
			local result = "continue"
			self:Log("  Unit %s (%d) movement start", unit.unitdatadef_id, unit.handle)
			if units_repositioning then
				if awareness_anims_played then
					unit.pending_awareness_role = nil
				end
				if table.find(pois, unit) and not self.cinematic_combat_camera then
					g_AIExecutionController.tracked_pois = g_AIExecutionController.tracked_pois or {}
					table.insert(g_AIExecutionController.tracked_pois, unit)
				end
				StartCombatAction("Reposition", unit, 0)
			elseif unit:HasStatusEffect("ManningEmplacement") and unit:GetArchetype() ~= Archetypes.EmplacementGunner then
				-- leave emplacement and restart
				AIPlayCombatAction("MGLeave", unit, 0)
				result = "restart"
			elseif unit.ai_context.ai_destination then 
				local unitAIinfo = unit.ai_context
				local lastStanding = IsLastUnitInTeam(unit.team.units)
				local willMove = stance_pos_dist(unitAIinfo.ai_destination, stance_pos_pack(unit)) ~= 0
				local isTargetUnit = IsKindOf(unitAIinfo.dest_target[unitAIinfo.ai_destination], "Unit")
				local hasAp = not unitAIinfo.dest_ap[unitAIinfo.ai_destination] or unitAIinfo.dest_ap[unitAIinfo.ai_destination] >= unitAIinfo.default_attack_cost
				if not attacker and willMove and isTargetUnit and hasAp and not lastStanding then
					attacker = unit
				elseif not mover and willMove and not isTargetUnit and not lastStanding then
					mover = unit
				end
				local trackPos = table.find(pois, unit)
				local trackMove
				if willMove and not self.cinematic_combat_camera and trackPos then
					trackMove = true
				end
				result = unit.ai_context.behavior:BeginMovement(unit, trackMove)
			end
			if result ~= "continue" then
				self:Log("  Execution interrupted: %s", result or "false")
				-- the movement was interrupted, break execution for all remaining units
				local limit = (result == "restart") and i or (i + 1)
				for j = #playing, limit, -1 do
					to_play[#to_play + 1] = playing[j]--store all units that were paused from playing because of an interruption
					playing[j] = nil
				end
				break
			end
		end	
			
		if attacker then
			PlayVoiceResponse(attacker, "AIStartingTurnAttack")
		elseif mover then
			PlayVoiceResponse(mover, "AIStartingTurnMoving")
		end
		
		-- wait movement to resolve
		assert(self.zone)
		WaitAllCombatActionsEnd()
		WaitUnitsInIdle(nil, FallbackDespawnExitMapUnits) -- wait other commands to end (dying, opportunity attacks)
		self.tracked_pois = nil -- stop tracking
		self.group_to_follow = nil
		self.track_group = nil
		self.zone = nil -- seems like it is not used for anything
		awareness_anims_played = true -- only play these one per reposition phase

		self:Log("Movement phase finished (%d units playing)", #playing)
		
		ClearAITurnContours()
		
		WaitActionCamDonePlayingSync()
		-- post-movement update before starting over
		for _, unit in ipairs(playing) do
			-- remove all scouted locations first in case any of the behaviors/actions causes a restart
			unit.ai_context.behavior:EndMovement(unit)
			AIUpdateScoutLocation(unit)
		end
				
		local end_combat
		--for i, unit in ipairs(playing) do
		while #(playing or empty_table) > 0 and g_Combat do
			-- select unit that would cause minimal camera movement (pos + target)
			local unit, min_dist
			if cinematicUnit then
				unit = cinematicUnit
				cinematicUnit = false
			else
				unit, min_dist = PickClosestUnit(playing)
			end
			table.remove_value(playing, unit)
			
			if IsValid(unit) and not unit:IsDead() then
				unit.pending_aware_state = nil
				if units_repositioning then
					StartCombatAction("RepositionOpeningAttack", unit, 0)
					WaitCombatActionsEnd(unit)
					ClearAITurnContours()
					while ActionCameraPlaying do
						WaitMsg("ActionCameraRemoved", 100)
					end
					table.remove_value(units, unit)
				else
					local status = AIExecuteUnitBehavior(unit, self.testAllAttacks)
					if status ~= "restart" then
						table.remove_value(units, unit)
					else
						-- break the execution to restart it starting with current unit
						-- note: if there's more processing of 'playing' below at some time, entries starting with current one need to be
						-- 	removed from it (see above at BeginMovement)
						table.iappend(to_play, playing)
						break
					end
				end
				-- check for early end combat, abort
				if not g_Combat or g_Combat:ShouldEndCombat() then
					end_combat = true
					break
				end
				Sleep(500)
			end
		end
		if end_combat then
			break
		end
		
		-- update 'units' with newly alerted ones (pending_aware_state) from all in g_Units (other teams can reposition during AI turn)
		for _, unit in ipairs(g_Units) do
			if not unit:IsDead() and not unit:IsAware() and unit.pending_aware_state == "aware" then
				if not self.reposition and unit.team == g_Teams[g_CurrentTeam] then
					-- units from the currently playing team do not get a Reposition, they get a normal turn instead
					unit:RemoveStatusEffect("Unaware")
					unit:RemoveStatusEffect("Surprised")
					unit:RemoveStatusEffect("Suspicious")
					unit.pending_aware_state = nil
					unit:StartAI()
					table.insert_unique(played_units, unit)
				end
				table.insert_unique(units, unit)
				--update flag for combat notifications
				allyInUnits = FindAllyInUnits(units)
			end
		end
	end
	
	ObjModified(g_Combat) -- update ui
	
	-- end of turn
	if self.override_notification then
		HideTacticalNotification(self.override_notification)
	else
		HideTacticalNotification("turn")
	end
			
	-- release claimed markers
	for _, marker in ipairs(self.claimed_markers) do
		g_RepositionMarkersClaimed[marker] = nil
	end
	
	if self.reposition and engaged then
		Msg("RepositionEnd")
		if g_Combat and not g_Combat.start_reposition_ended then
			g_Combat.start_reposition_ended = true
			Msg("CombatStartRepositionDone")
		end
	end
	self:Log("Execution finished")
	if g_Combat then 
		g_Combat:EndCombatCheck()
	end
end

-- These changes can sometimes be left over when loading a save during enemy turn and stuff like that
function OnMsg.EnterSector()
	table.restore(hr, "Enemy turn TacCamera Angle", true)
	table.restore(hr, "Enemy turn TacCamera Height", true)
end

MapVar("g_UnawareQueue", {})

function AIExecutionController:Execute(units)
	local played_units = {}
	g_LastUnitToShoot = false
	g_UnawareQueue = {}
	sprocall(__AIExecutionControllerExecute, self, units, nil, played_units)
	for _, unit in ipairs(played_units) do
		unit.ai_context = nil
	end
	local check
	for _, unit in ipairs(g_UnawareQueue) do
		unit:AddStatusEffect("Unaware")
		check = true
	end
	g_LastUnitToShoot = false
	if check and g_Combat then
		g_Combat:EndCombatCheck()
	end
end

function AIExecutionController:SelectPlayingUnits(units, zone)
	local reposition_units = table.ifilter(units, function(idx, unit) return unit.pending_aware_state == "aware" or unit.pending_aware_state == "reposition" or unit == self.activator end)
	if #reposition_units > 0 then 
		-- in reposition phase only care about repositioning units, in ai turn phase prioritize them if there are any
		units = reposition_units
	else -- return to normal turn phase selection logic when in ai turn phase and nobody is repositioning
		units = table.ifilter(units, function(idx, unit) return unit:IsAware() and unit.ActionPoints >= MinAPToPlay and not unit:GetBandageTarget() end)
		units = AIGetNextPhaseUnits(units)
	end
	
	--filter playing units by side
	local side = next(units) and units[1].team.side
	--filter playing units by floor
	local minFloor
	for _, unit in ipairs(units) do
		local unitFloor = GetFloorOfPos(SnapToPassSlab(unit)) or 0
		if not minFloor or minFloor > unitFloor then
			minFloor = unitFloor
		end
	end
	
	local selected = table.copy(units or empty_table)
	selected = table.ifilter(selected, function(idx, unit) 
		local unitFloor = GetFloorOfPos(SnapToPassSlab(unit)) or 0
		return unit.team.side == side and unitFloor == minFloor
	end)
	selected = self:SelectObjsInZone(selected, zone)

	
	--filter by being interrupted
	if #reposition_units <=  0 then
		local interruptedGroup = false
		for idx, unit in ipairs(selected) do
			local pathDummies = unit:GenerateTargetDummiesFromPath(unit.ai_context.dest_combat_path)
			local interrupted = unit:CheckProvokeOpportunityAttacks("move", pathDummies)
			if interrupted and idx == 1 then 
				interruptedGroup = true
			end
			if (not not interruptedGroup) ~= (not not interrupted) then
				table.remove(selected, idx)
			end
		end
	end
	
	while #(selected or empty_table) > const.MaxSimultaneousUnits do
		table.remove(selected)
	end
	return selected
end

function CountUnitsInArea(x, y, objs, r)
	local group = {}
	for _, obj in ipairs(objs) do
		local ox, oy
		if IsValid(obj) then
			ox, oy = obj:GetVisualPosXYZ()
		else
			ox, oy = obj:xy()
		end
		if IsCloser2D(x, y, ox, oy, r) then
			group[#group + 1] = obj
		end
	end
	return #group, group
end

function ClusterUnits(objs)
	objs = objs or g_Units
	
	local r = 0
	r = 10*guim
	
	local clusters = {}
	for _, obj in ipairs(objs) do
		local x, y
		if IsValid(obj) then
			x, y = obj:GetVisualPosXYZ()
		else
			assert(IsPoint(obj))
			x, y = obj:xy()
		end
		local cluster = { x = x, y = y }
		clusters[#clusters + 1] = cluster
		cluster.count, cluster.objs = CountUnitsInArea(cluster.x, cluster.y, objs, r)
	end
		
	for idx, cluster in ipairs(clusters) do
		repeat
			local cx, cy = cluster.x, cluster.y
			local count, next_potential_objs = CountUnitsInArea(cx, cy, objs, 2*r)
			if count > cluster.count then
				-- try moving to the new midpoint and see if we lose some of the existing objects with our normal radius				
				local x, y = midpoint(next_potential_objs)
				local next_count, next_objs = CountUnitsInArea(x, y, objs, r)
				local lost
				for _, obj in ipairs(cluster.objs) do
					lost = lost or not table.find(next_objs, obj)
				end
				if not lost then
					cluster.x, cluster.y = x, y
					cluster.count = next_count
					cluster.objs = next_objs
				end
			end
			
			local change = cx ~= cluster.x or cy ~= cluster.y
		until not change
	end
	
	-- sort by size
	table.sortby_field_descending(clusters, "count")
	
	-- go over objs, find the largest cluster they belong to and remove them from all the others
	for _, obj in ipairs(objs) do
		local cluster_idx
		for i, cluster in ipairs(clusters) do
			if table.find(cluster.objs, obj) then
				cluster_idx = i
				break
			end
		end
		for j = cluster_idx + 1, #clusters do
			table.remove_value(clusters[j].objs, obj)
		end
	end
	for i = #clusters, 1, -1 do
		clusters[i].count = #clusters[i].objs
		if clusters[i].count == 0 then
			table.remove(clusters, i)
		end
	end
		
	return clusters
end

function midpoint(objs)
	local cx, cy, cz = 0, 0, 0
	for _, obj in ipairs(objs) do
		local x, y, z
		if IsValid(obj) then
			x, y, z = obj:GetVisualPosXYZ()
		else
			assert(IsPoint(obj))
			x, y, z = obj:xyz()
		end
		cx, cy, cz = cx + x, cy + y, cz + (z or terrain.GetHeight(x, y))
	end
		
	if #objs > 0 then
		cx, cy, cz = cx / #objs, cy / #objs, cz / #objs
	end
	return cx, cy, cz
end

-- Sync version
function AIExecutionController:CombatCamCalcZone()
	return CombatCam_CalcZone()
end

function AIExecutionController:ShowUnits(units, wait_time)
	WaitActionCamDonePlayingSync()
	return AIExecutionController_Camera.ShowUnits(self, units, wait_time)
end

function CenterCameraOnObj(objs, floor, sleep_time)
	if not objs or #objs == 0 then return end
	
	local center = IsValid(objs[1]) and objs[1]:GetVisualPos() or objs[1]
	for i = 2, #objs do
		center = center + (IsValid(objs[i]) and objs[i]:GetVisualPos() or objs[i])
	end
	center = center / #objs
	AdjustCombatCamera("set", nil, center, floor, sleep_time, "NoFitCheck")
	if sleep_time then
		Sleep(sleep_time)
		return true
	end
	
	return false
end

function StartCinematicCombatCamera(attacker, target)
	local isNear = DoPointsFitScreen({attacker:GetVisualPos()}, nil, const.Camera.BufferSizeNoCameraMov)
	
	
	AdjustCombatCamera("set", nil, not isNear and attacker, GetFloorOfPos(SnapToPassSlab(attacker)), not isNear and 1000 or 0)
	Sleep(not isNear and 1000 or 500)

	AILockTarget(attacker)
	g_AIExecutionController.cinematic_combat_camera = true
	g_AIExecutionController.attacker = attacker
	g_AIExecutionController.target = target
end

function StopCinematicCombatCamera()
	if IsCinematicCCPlaying() then
		Sleep(1000)
		local attacker = g_AIExecutionController.attacker
		g_AIExecutionController.cinematic_combat_camera = false
		g_AIExecutionController.attacker = false
		g_AIExecutionController.target = false
		return true, attacker
	else
		return false
	end
end

function IsCinematicCCPlaying()
	return g_AIExecutionController and g_AIExecutionController.cinematic_combat_camera
end

local function AICinematicCombatCamera()
	if not g_AIExecutionController or g_AIExecutionController.tracked_pois 
	or not g_AIExecutionController.cinematic_combat_camera
	or not g_AIExecutionController.attacker
	or not g_AIExecutionController.target then
		return
	end
	
	local midPointX, midPointY, midPointZ = midpoint({g_AIExecutionController.attacker, g_AIExecutionController.target})
	--maybe use the floor of the closer unit to the camera's current pos
	SnapCameraToObj(point(midPointX, midPointY, midPointZ), "force", GetFloorOfPos(SnapToPassSlab(g_AIExecutionController.target)), 5000, "none")
end

DefineConstInt("Camera", "MinTrackDistance", 3, "voxelSizeX", "The minimum distance (in slabs) required to active the tracking camera, else it will lock to init pos once. Also used for cinematic unit cond.")

local function AIExecutionTrackUnits()
	if not g_AIExecutionController or not g_AIExecutionController.tracked_pois or 
		#g_AIExecutionController.tracked_pois == 0 or #g_CombatCamAttackStack > 1 then
		return
	end
	if ActionCameraPlaying then
		return
	end
		
	g_AIExecutionController.tracked_pois = table.ifilter(g_AIExecutionController.tracked_pois, function(idx, poi) return not IsKindOf(poi, "Unit") or HasCombatActionInProgress(poi) end)
	
	--If the followed group is not determined, run cluster algroithm on destination.
	--This will populate the groupToFollow with units that will have similar final destination.
	if not g_AIExecutionController.group_to_follow or #g_AIExecutionController.group_to_follow == 0 then
		g_AIExecutionController.group_to_follow = {}
		g_AIExecutionController.track_group = false
		local destPoints = {} 
		for _, unit in ipairs(g_AIExecutionController.tracked_pois) do
			local unitFinalDestination = unit.ai_context.ai_destination or unit.reposition_dest --pick the reposition dest if unit is making reposition
			if unitFinalDestination then
				local x, y, z = stance_pos_unpack(unitFinalDestination)
				local pt = point(x, y, z)
				table.insert(destPoints, pt)
				destPoints[pt] = unit
			end
			
		end
		local clusters = ClusterUnits(destPoints)
		table.sortby_field_descending(clusters, "count")
		local bestClusterOfDest = clusters[1]
		local objsInCluster = bestClusterOfDest and bestClusterOfDest.objs or {}
		for _, pt in ipairs(objsInCluster) do
			table.insert(g_AIExecutionController.group_to_follow, destPoints[pt])
		end
		
		--only track group that will move x distance, otherwise just snap once to its center
		if #destPoints > 0 and GetDistGroupInitAndDestPoint(destPoints) >  const.Camera.MinTrackDistance then
			g_AIExecutionController.track_group = true
		end
		
		if not g_AIExecutionController.track_group and next(g_AIExecutionController.group_to_follow) then
			if not DoPointsFitScreen({unpack_params(objsInCluster)}, nil, const.Camera.BufferSizeNoCameraMov) then
				CenterCameraOnObj(g_AIExecutionController.group_to_follow, HighestFloorOfGroup(g_AIExecutionController.group_to_follow), 500)
			end
		end
	end
	
	if not g_AIExecutionController.group_to_follow or not next(g_AIExecutionController.group_to_follow) then
		--for some reason there is no group to follow
		return
	end
	
	--Check if the currently followed group by the camera is too far apart.
	local trackedUnitsClusters = ClusterUnits(g_AIExecutionController.group_to_follow)
	--Pick the group/cluster with more units in it to be the one the camera will track.
	--This might happen very rarely. Most cases will be only one cluster.
	local biggestCluster
	for _, cluster in ipairs(trackedUnitsClusters) do
		if not biggestCluster or biggestCluster.count < cluster.count then
			biggestCluster = cluster
		end
	end
	
	local maxFloor = HighestFloorOfGroup(biggestCluster.objs)
	
	--Track the groupToFollow by moving the camera in the midpoint of the group.
	if biggestCluster and g_AIExecutionController.track_group then
		CenterCameraOnObj(biggestCluster.objs, maxFloor)
	end
end

local function TrackMeleeCharge()			
	if not g_TrackingChargeAttacker or not g_AIExecutionController then 
		return
	end
	
	if IsCinematicCCPlaying() or ActionCameraPlaying then
		return
	end
	
	if gv_DebugMeleeCharge then
		print("tracking melee charge attacker")
	end
	SnapCameraToObj(g_TrackingChargeAttacker:GetVisualPos(), "force", GetFloorOfPos(SnapToPassSlab(g_TrackingChargeAttacker:GetVisualPos())))
end

MapGameTimeRepeat("AIExecutionTracking", 50, AIExecutionTrackUnits)
MapGameTimeRepeat("AICinematicCombat", 50, AICinematicCombatCamera)
MapGameTimeRepeat("AITrackMeleeCharge", 50, TrackMeleeCharge)

MapVar("s_EnemySightedQueue", {})

local function CheckEnemySightedQueue()
	if #s_EnemySightedQueue == 0 then return end
	if (next(CombatActions_RunningState) ~= nil) or MoveAndAttackSyncState == 1 then
		return
	end
	
	if ActionCameraPlaying or g_AIExecutionController then
		s_EnemySightedQueue = {}
		return
	end
	
	local igi = GetInGameInterfaceModeDlg()
	if not IsKindOfClasses(igi, "IModeCombatMovement", "IModeExploration") then
		s_EnemySightedQueue = {}
		return
	end
	
	g_AIExecutionControllerCamera = AIExecutionController_Camera:new()
	CreateGameTimeThread(function()
		local units = s_EnemySightedQueue
		s_EnemySightedQueue = {}
		g_AIExecutionControllerCamera:ShowUnits(units, 1500)
		DoneObject(g_AIExecutionControllerCamera)
	end)
end

function OnMsg.EnemySighted(team, enemy)
	if GameState.sync_loading then return end
	
	if g_Combat and g_AIExecutionController then
		local tacNotState = GetDialog("TacticalNotification") and GetDialog("TacticalNotification").state
		local repoPhase = table.find(tacNotState, "mode", "hiddenEnemyRepoPhase")
		local normalPhase = table.find(tacNotState, "mode", "hiddenEnemyTurnPhase")
		if repoPhase or normalPhase then
			HideTacticalNotification("turn")
			ShowTacticalNotification(repoPhase and "enemyRepositionPhase" or "enemyTurnPhase", true)
		end 
	end
	
	if g_Combat and team == GetPoVTeam() and not enemy.dummy and team == g_Teams[g_CurrentTeam] then
		local handle = enemy:GetHandle()
		if not table.find(team.seen_units or empty_table, handle) then
			-- queue seen enemies until the end of the current combat action, show all seen enemies afterwards		
			s_EnemySightedQueue[#s_EnemySightedQueue + 1] = enemy
			CheckEnemySightedQueue()
--[[			if not HasAnyCombatActionInProgress("all") then
				RestoreDefaultMode(false, false) -- for co-op
			end]]
		end
	end
end

function ClearAITurnContours(specificUnit)
	for unitHandle, contour in pairs(g_AITurnContours) do
		if not specificUnit or specificUnit.handle == unitHandle then 
			DestroyMesh(contour)
			g_AITurnContours[unitHandle] = nil
			ShowBadgeOfAttacker(HandleToObject[unitHandle], false)
		end
	end
end

function OnMsg.UnitDied(unit)
	ClearAITurnContours(unit)
end

function ClearAllCombatBadges()
	for _, unit in ipairs(g_ShowTargetBadge) do
		ShowBadgeOfAttacker(unit, false)
	end
end

OnMsg.CombatActionEnd = CheckEnemySightedQueue
OnMsg.ExecutionControllerDeactivate = CheckEnemySightedQueue

function PickClosestUnit(group)
	-- select unit that would cause minimal camera movement (pos + target)
	local unit, min_dist
	for _, u in ipairs(group) do
		local target = AIGetIntendedTarget(u)
		local lookat, zone = CombatCam_CalcAttackCamPos(u, target)
		if not lookat or not zone then
			unit = u
			break
		end
		local dist = zone.center:Dist(IsValid(lookat) and lookat:GetVisualPos() or lookat)
		if not min_dist or dist < min_dist then
			unit, min_dist = u, dist
		end
	end
	return unit, min_dist
end

function ShowBadgeOfAttacker(attacker, show)
	if show then
		table.insert(g_ShowTargetBadge, attacker)
		if attacker.ui_badge then
			attacker.ui_badge:SetActive(show, "showAttacker")
		end
	elseif attacker then
		local currentTeam = g_Combat and g_Teams[g_Combat.team_playing]
		if not currentTeam or currentTeam.control ~= "UI" then
			if attacker.ui_badge then
				attacker.ui_badge:SetActive(show, "showAttacker")
			end
		elseif attacker.ui_badge then
			attacker.ui_badge.active_reasons.showAttacker = false
		end
		table.remove(g_ShowTargetBadge, table.find(g_ShowTargetBadge, attacker))
	end
end

function HighestFloorOfGroup(group)
	if not next(group) then return cameraTac.IsActive() and cameraTac.GetFloor() end
	local maxFloor
	for _, unit in ipairs(group) do
		if not maxFloor or maxFloor < (GetFloorOfPos(SnapToPassSlab(unit)) or GetFloorOfPos(unit:GetVisualPos())) then
			maxFloor = GetFloorOfPos(SnapToPassSlab(unit))
		end
	end
	return maxFloor
end

function GetDistGroupInitAndDestPoint(destPointsAndUnits)
	local current_center = destPointsAndUnits[destPointsAndUnits[1]]:GetVisualPos()
	local dest_center = destPointsAndUnits[1]
	for i = 2, #destPointsAndUnits do
		current_center = current_center + destPointsAndUnits[destPointsAndUnits[i]]:GetVisualPos()
		dest_center = dest_center + destPointsAndUnits[i]
	end
	current_center = current_center / #destPointsAndUnits
	dest_center = dest_center / #destPointsAndUnits
	
	return current_center:Dist(dest_center)
end

MapVar("g_TrackingChargeAttacker", false)
GameVar("gv_DebugMeleeCharge", false) --set to true to see prints for the melee charge camera behavior

function ShouldTrackMeleeCharge(attacker, target)
	if IsCinematicCCPlaying() or ActionCameraPlaying or not g_AIExecutionController then
		g_TrackingChargeAttacker = false
		if gv_DebugMeleeCharge then
			print("skip melee charge camera logic because of non ai or cinematic camera or action camera")
		end
		return
	end
	
	local attackerPos = attacker:GetVisualPos()
	local targetPos = target:GetVisualPos()
	
	local initFitCheck = DoPointsFitScreen({attackerPos, targetPos}, nil, const.Camera.BufferSizeNoCameraMov)
	if initFitCheck then
		g_TrackingChargeAttacker = false
		if gv_DebugMeleeCharge then
			print("camera will not move as it is in a good spot")
		end
		return
	end
	
	--the second fit check is based on the midpoint of the attacker and target pos
	local midPoint = (attackerPos + targetPos) / 2
	local secondFitCheck = DoPointsFitScreen({attackerPos, targetPos}, midPoint, const.Camera.BufferSizeNoCameraMov)
	if secondFitCheck then
		AdjustCombatCamera("set", nil, targetPos, GetFloorOfPos(SnapToPassSlab(targetPos)), nil, "NoFitCheck")
		g_TrackingChargeAttacker = false
		if gv_DebugMeleeCharge then
			print("snap the camera to the target and don't do anything else (the action would be visible)")
		end
		return
	end
	
	g_TrackingChargeAttacker = attacker
end

function AddToCameraTrackingBehavior(unit, args)
	if g_AIExecutionController and unit then
		if args.fallbackMove then --fallback move, need to calc los to new pos and handle reseting the tracking flag
			local willReveal = RevealUnitBeforeMove(unit, args)
			if willReveal then
				if not g_AITurnContours[unit.handle] then
					local enemy = unit.team.side == "enemy1" or unit.team.side == "enemy2" or unit.team.side == "neutralEnemy"
					g_AITurnContours[unit.handle] = SpawnUnitContour(unit, enemy and "CombatEnemy" or "CombatAlly")
					ShowBadgeOfAttacker(unit, true)
					g_AIExecutionController.fallbackMoveTracking = true
					args.trackMove = true
				end
			end
		end
		if args.trackMove then
			g_AIExecutionController.tracked_pois = g_AIExecutionController.tracked_pois or {}
			table.insert(g_AIExecutionController.tracked_pois, unit)
			return args.fallbackMove, true--means that the unit will be visible and tracked by the camera
		end
	end
end

function OnMsg.UnitMovementDone(unit, action_id)
	if g_AIExecutionController and action_id == "Move" and g_AIExecutionController.fallbackMoveTracking then
		g_AIExecutionController.tracked_pois = nil
		g_AIExecutionController.group_to_follow = nil
		g_AIExecutionController.track_group = nil
		g_AIExecutionController.fallbackMoveTracking = nil
		ClearAITurnContours(unit)
		ShowBadgeOfAttacker(unit, false)
	end
end

function RevealUnitBeforeMove(unit, args)
	local goto_pos = args.goto_pos
	local goto_stance = StancesList.Standing --args.goto_stance --for now, assume the end stance will be standing as there is a bug around that logic
	local step_pos_duplicated_arr = {}
	local pov_team = GetPoVTeam()
	for i = 1, #pov_team.units do
		table.insert(step_pos_duplicated_arr, goto_pos)
	end
	
	local los_any, result = CheckLOS(step_pos_duplicated_arr, pov_team.units) 
	if los_any then
		for pi, pu in ipairs(pov_team.units) do
			if (result[pi] == 2 or result[pi] == 1 and goto_stance == StancesList.Standing) and pu:GetDist(goto_pos) <= pu:GetSightRadius(unit, nil, goto_pos) then
				NetSyncEvent("RevealToTeam", unit, table.find(g_Teams, pov_team))
				return true
			end
		end
	end
end