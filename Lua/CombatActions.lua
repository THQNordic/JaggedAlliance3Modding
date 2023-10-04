if FirstLoad then
	CombatActions_Waiting = {} -- packed: action_id, unit, ap, ...
	CombatActions_RunningState = {}
	CombatActions_StartThread = false
	CombatActions_LastStartedAction = {}
	CombatActions_UnitAction = {}
	CombatActionTargetFilters = {}
	LocalPlayer_InterruptSent = false
	CombatSaveGameRequest = false
end

function OnMsg.NewMap()
	CombatActions_Waiting = {}
	CombatActions_RunningState = {}
	CombatActions_LastStartedAction =  {}
	CombatActions_UnitAction = {}
	CombatActions_StartThread = false
	LocalPlayer_InterruptSent = false
	CombatSaveGameRequest = false
end

CustomCombatActions = {}
NetStartCombatActions = {}

function CombatActionCannotBeStarted(action_id, unit)
	if g_Combat then
		for u, state in pairs(CombatActions_RunningState) do
			if state ~= "PostAction" then
				return true
			end
		end
	else
		local state = unit and CombatActions_RunningState[unit]
		if state and state ~= "PostAction" and action_id ~= "MoveItems" then
			local actionPreset = CombatActions[action_id]
			local unitCanBeInterrupted = actionPreset and actionPreset.InterruptInExploration
			if not unitCanBeInterrupted then
				return true
			end
		end
	end
	return false
end

function NetStartActionCanceled(action_id, unit)
	if unit and unit.aim_action_id == action_id then
		NetSyncEvent("Aim", unit)
	end
end

function ActionCanceled(action_id, unit)
	if unit and unit.aim_action_id == action_id then
		unit:SetAimTarget()
	end
end

function NetStartCombatAction(action_id, unit, ap, args, ...)
	local net_cmd = NetStartCombatActions[action_id]
	-- action_id ~= "MoveItems": temporary fix for not being able to execute many MoveItems actions one after another
	if action_id ~= "MoveItems" and net_cmd and net_cmd.unit == unit and net_cmd.ap == ap then
		NetStartActionCanceled(action_id, unit)
		return		-- already registered to travel the network, skip it
	end
	if g_UnitAwarenessPending then
		NetStartActionCanceled(action_id, unit)
		return -- don't start new combat actions while there are units waiting to become aware
	end
	
	if CombatActionCannotBeStarted(action_id, unit) then
		NetStartActionCanceled(action_id, unit)
		return
	end
	
	if g_Combat then
		-- Unit became uncontrollable, it probably died
		-- This can happen when spamming commands and the unit dies
		if unit and not unit:CanBeControlled() then
			NetStartActionCanceled(action_id, unit)
			return
		end
		if not IsNetPlayerTurn() or g_Combat:IsLocalPlayerEndTurn() then
			NetStartActionCanceled(action_id, unit)
			return
		end
		if unit then
			if not ap or ap < 0 or not unit:UIHasAP(ap, action_id, args) then
				NetStartActionCanceled(action_id, unit)
				return false
			end
		end
		ap = ap or 0 -- combat mark
	else
		ap = false -- out of combat mark
	end
	NetSyncEvent("StartCombatAction", netUniqueId, action_id, unit, ap, args, ...)
	return true
end

function NetSyncLocalEffects.StartCombatAction(player_id, action_id, unit, ap, ...)
	NetStartCombatActions[action_id] = {unit = unit, ap = ap}
	if unit then
		unit.actions_nettravel = unit.actions_nettravel + 1
		if (ap or 0) > 0 then
			unit.ui_reserved_ap = unit.ui_reserved_ap + ap
		end
	end
	if action_id == "Interrupt" then
		LocalPlayer_InterruptSent = true
		Msg("NetSentInterrupt")
	else
		LocalPlayer_InterruptSent = false
	end
end

function NetSyncRevertLocalEffects.StartCombatAction(player_id, action_id, unit, ap, ...)
	if player_id ~= netUniqueId then
		return
	end
	NetStartCombatActions[action_id] = nil
	if unit then
		unit.actions_nettravel = Max(0, unit.actions_nettravel - 1)
		if ap and ap > 0 then
			unit.ui_reserved_ap = Max(0, unit.ui_reserved_ap - ap)
		end
	end
	if action_id == "Interrupt" then
		LocalPlayer_InterruptSent = false
	end
end

function NetSyncEvents.StartCombatAction(player_id, action_id, unit, ap, ...)
	if not g_Combat ~= not ap then
		ActionCanceled(action_id, unit)
		return -- combat mode changed
	end
	if g_Combat then
		if not IsNetPlayerTurn(player_id) then
			ActionCanceled(action_id, unit)
			return
		end
	end
	if action_id == "Interrupt" then
		InterruptPlayerActions(player_id)
		return
	end
	StartCombatAction(action_id, unit, ap, ...)
end

function StartCombatAction(action_id, unit, ap, ...)
	if g_Combat then
		if unit then
			unit:ConsumeAP(ap, action_id, ...)
		end
		if g_ItemNetEvents[action_id] then
			CancelUnitWaitingActions(unit)
		end
		table.insert(CombatActions_Waiting, pack_params(action_id, unit, ap, ...))
		RunCombatActions()
	else
		RunCombatAction(action_id, unit, 0, ...)
	end
end

function SetCombatActionState(unit, state)
	assert(not state or not unit:IsDead())
	state = state or nil
	local prev_state = CombatActions_RunningState[unit]
	if prev_state == state then
		return
	end
	unit:NetUpdateHash("CombatActionState", state)
	CombatActions_RunningState[unit] = state
	Msg("CombatActionStateChange", unit, state)
	if not state then
		Msg("CombatPostAction", unit)
		Msg("CombatActionEnd", unit)
	elseif state == "start" then
		Msg("CombatActionStart", unit)
	elseif state == "PostAction" then
		Msg("CombatPostAction", unit)
	end
	ObjModified(unit)
	if g_Combat and #CombatActions_Waiting == 0 and not next(CombatActions_RunningState) then
		g_Combat:CheckEndTurn()
		return
	end
	if CombatSaveGameRequest or not next(CombatActions_RunningState) or prev_state and prev_state ~= "PostAction" and (not state or state == "PostAction") then
		RunCombatActions()
	end
end

function RunCombatAction(action_id, unit, ap, ...)
	local func = CustomCombatActions[action_id]
	if func then
		func(unit, ap, ...)
	else
		local action = CombatActions[action_id]
		if action then
			action:Run(unit, ap, ...)
		end
		if action.ActivePauseBehavior == "queue" then
			if IsActivePaused() then
				unit:SetQueuedAction(action_id)
			end
		elseif action.ActivePauseBehavior == "unpause" then
			if IsActivePaused() then
				ToggleActivePause()
			end
			if not g_Combat then
				ExplorationStartExclusiveAction(unit)
			end
		end
	end
	Msg("RunCombatAction", action_id, unit, ap)
end

function RunCombatActions()
	if not CombatSaveGameRequest and (#CombatActions_Waiting == 0 or IsValidTarget(CombatActions_StartThread)) then
		return
	end
	CombatActions_StartThread = CreateGameTimeThread(function()
		while CombatSaveGameRequest and not next(CombatActions_RunningState) do
			CombatSaveGameRequest = false
			MPSaveGame()
			WaitMsg("MPSaveGameDone")
		end
		local can_start = not CombatSaveGameRequest
		local idx = 1
		while idx <= #CombatActions_Waiting do
			local adata = CombatActions_Waiting[idx]
			local action_id, unit, ap = unpack_params(adata, 1, 3)
			local combat_action = CombatActions[action_id]
			if unit and unit:IsDead() and action_id ~= "Teleport" then
				table.remove(CombatActions_Waiting, idx)
			elseif combat_action and combat_action.LocalChoiceAction then
				-- open loot dialog
				if unit and (CombatActions_RunningState[unit] or table.find(CombatActions_Waiting, 2, unit) < idx) then
					idx = idx + 1
				else
					table.remove(CombatActions_Waiting, idx)
					RunCombatAction(unpack_params(adata))
				end
			else
				local run_action = can_start and not CombatActions_RunningState[unit]
				if run_action and next(CombatActions_RunningState) then
					if not combat_action or not combat_action.SimultaneousPlay then
						run_action = false
					else
						for u, state in pairs(CombatActions_RunningState) do
							if state ~= "PostAction" then
								run_action = false
								break
							end
						end
					end
				end
				if run_action then
					table.remove(CombatActions_Waiting, idx)
					if not combat_action or not combat_action.SimultaneousPlay or not g_Combat:GetActiveUnit(unit) then
						g_Combat:SetActiveUnit(unit)
					end
					CombatActions_LastStartedAction.action_id = action_id
					CombatActions_LastStartedAction.unit = unit
					CombatActions_LastStartedAction.start_time = GameTime()
					CombatActions_UnitAction[unit] = action_id
					if action_id == "Move" and unit:IsMerc() then 
						g_SelectedObjLastActionIsMovement = true
					else
						g_SelectedObjLastActionIsMovement = false
					end
					RunCombatAction(unpack_params(adata))
				else
					idx = idx + 1
					can_start = can_start and combat_action and combat_action.SimultaneousPlay
				end
			end
		end
		if g_Combat then
			g_Combat:CheckEndTurn()
		end
	end)
end

function LocalPlayerCanInterrupt()
	if LocalPlayer_InterruptSent then
		return false
	end
	local units = Selection
	for i, unit in ipairs(units or empty_table) do
		if unit.actions_nettravel > 0 then
			return true
		end
		if g_Combat then
			if HasCombatActionInProgress(unit) then
				return true
			end
		else
			if unit.action_interrupt_callback and not unit.interrupt_callback then
				return true
			end
		end
	end
	return false
end

function InterruptPlayerActions(player_id)
	local mask = NetPlayerControlMask(player_id)
	local side = NetPlayerSide(player_id)
	CancelWaitingActions(mask)
	local team_idx = table.find(g_Teams, "side", side)
	local units = team_idx and g_Teams[team_idx].units
	local interrupted
	for i, unit in ipairs(units or empty_table) do
		if unit:IsControlledBy(mask) then
			unit:Interrupt()
			interrupted = true
		end
	end
	ShowTacticalNotification("actionInterrupted")
	if interrupted and g_Combat and GetInGameInterfaceMode() ~= "IModeCombatMovement" then
		SetInGameInterfaceMode("IModeCombatMovement")
	end
end

function HasCombatActionInProgress(unit)
	return (CombatActions_RunningState[unit] or HasCombatActionWaiting(unit) or unit.move_attack_in_progress) and IsValid(unit) and not unit:IsDead()
end

function HasCombatActionWaiting(unit)
	--this function is sync, it represents the synced state of a unit on all clients
	if table.find(CombatActions_Waiting, 2, unit) then
		return true
	end
	return false
end

function WaitCombatActionsEnd(unit)
	while HasCombatActionInProgress(unit) do
		WaitMsg("CombatActionEnd", 200)
	end
end

function WaitCombatActionsPostAction(unit)
	while HasCombatActionInProgress(unit) and CombatActions_RunningState[unit] ~= "PostAction" do
		WaitMsg("CombatPostAction", 200)
	end
end

function HasAnyCombatActionInProgress(check_all)
	if #CombatActions_Waiting > 0 then
		return true
	end
	if check_all then
		for _, u in ipairs(g_Units) do
			if HasCombatActionInProgress(u) then
				return true
			end
		end
	else
		for u, state in pairs(CombatActions_RunningState) do
			if HasCombatActionInProgress(u) then
				return true
			end
		end
	end
	return false
end

function HasAnyAttackActionInProgress()
	for _, adata in ipairs(CombatActions_Waiting) do
		local action_id, unit, ap = unpack_params(adata, 1, 3)
		local action = CombatActions[action_id]
		if action.ActionType == "Ranged Attack" or action.ActionType == "Melee Attack" then
			return true
		end
	end
	for u, state in pairs(CombatActions_RunningState) do
		local action_id = CombatActions_UnitAction[u]
		if HasCombatActionInProgress(u) and action_id then
			local action = CombatActions[action_id]
			if action and (action.ActionType == "Ranged Attack" or action.ActionType == "Melee Attack") then
				return true
			end
		end
	end
end

function WaitAllCombatActionsEnd()
	while HasAnyCombatActionInProgress() do
		WaitMsg("CombatActionEnd", 200)
	end
end

function WaitOtherCombatActionsEnd(unit)
	while true do
		local wait
		for u, state in pairs(CombatActions_RunningState) do
			if u ~= unit and HasCombatActionInProgress(u) then
				wait = true
				break
			end
		end
		if not wait then
			return
		end
		WaitMsg("CombatActionEnd", 200)
	end
end

function CombatActionInterruped(unit)
	if g_Combat and unit.team and unit.team.control == "UI" then
		-- interrupt the other ordered actions by players that controll this unit
		local mask = 0
		for player_id = 1, Max(1, #netGamePlayers) do
			local pmask = NetPlayerControlMask(player_id)
			if unit:IsControlledBy(pmask) then
				mask = mask | pmask
			end
		end
		CancelWaitingActions(mask)
	end
end

function CancelWaitingActions(mask)
	for i = #CombatActions_Waiting, 1, -1 do
		local adata = CombatActions_Waiting[i]
		local action_id, unit, ap = unpack_params(adata, 1, 3)
		if unit and unit:IsControlledBy(mask) then
			unit:GainAP(ap)
			table.remove(CombatActions_Waiting, i)
			Msg("CombatActionCanceled", unpack_params(adata))
		end
	end
end

function CancelUnitWaitingActions(unit)
	for i = #CombatActions_Waiting, 1, -1 do
		local adata = CombatActions_Waiting[i]
		local action_id, u, ap = unpack_params(adata, 1, 3)
		if u == unit then
			unit:GainAP(ap)
			table.remove(CombatActions_Waiting, i)
			Msg("CombatActionCanceled", unpack_params(adata))
		end
	end
end

function OnMsg:TurnEnded()
	assert(not next(CombatActions_RunningState))
	CombatActions_Waiting = {}
	CombatActions_RunningState = {}
	if CombatSaveGameRequest then
		MPSaveGame()
	end
end

function CustomCombatActions.Teleport(unit, ap, ...)
	unit:SetCommand("Teleport", ...)
end

function CombatActionChangeNeededTryRetainTarget(required_mode, action, unit, target, freeAim)
	local targetParamOrDefault = target or action:GetDefaultTarget(unit)

	local dlg = GetInGameInterfaceModeDlg()
	local iModeMismatch = not IsKindOf(dlg, "IModeCombatAttackBase") or not IsKindOf(dlg, required_mode)
	if iModeMismatch then return "change-mode", dlg, targetParamOrDefault end
	
	-- If the action and target match, no change needed.
	-- "not target" will detect pressing the action key twice.
	local actionCameraSame = action.ActionCamera == dlg.action.ActionCamera
	if dlg.action == action and actionCameraSame and (not target or target == dlg.target) then return false, dlg, target end
	
	-- Changing actions within the same interface mode, with no defined target means
	-- this click came from pressing another action key. Check if the current target can be maintained.
	if not target and dlg.target and IsKindOf(dlg, "IModeCombatAttack") then
		local validTargets = action:GetTargets({unit})
		if table.find(validTargets, dlg.target) then
			if not actionCameraSame then
				return true, dlg, dlg.target
			end

			return "change-action", dlg, dlg.target
		end
	end
	
	if freeAim ~= dlg.context.free_aim then
		return "change-free-aim", dlg
	end

	return true, dlg, targetParamOrDefault
end

ActionsWhichHighlightTargets = {
	"Interact",
	"Lockpick",
	"Cut",
	"Break"
}

function CombatActionInteractablesChoice(self, units, args)
	local mode_dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(mode_dlg, "IModeCommonUnitControl") then
		local targets = self:GetTargets(units)
		local combatChoiceUI = mode_dlg:ShowCombatActionTargetChoice(self, units, targets)
		if combatChoiceUI then
			combatChoiceUI.OnDelete = function(self)
				for i, t in ipairs(targets) do
					t:HighlightIntensely(false, "actionsChoice")
				end
			end
		end
	else
		self:Execute(units[1], args)
	end
end

if FirstLoad then
CombatActionStartThread = false
end

function CombatActionAttackStart(self, units, args, mode, noChangeAction)
	mode = mode or "IModeCombatAttackBase"
	local unit = units[1]
	if IsValidThread(CombatActionStartThread) then
		DeleteThread(CombatActionStartThread)
	end
	CombatActionStartThread = CreateRealTimeThread(function()
		if g_Combat then
			WaitCombatActionsEnd(unit)
		end
		if not IsValid(unit) or unit:IsDead() or not unit:CanBeControlled() then
			return
		end
		if PlayerActionPending(unit) then
			return
		end
		if not g_Combat and not unit:IsIdleCommand() then
			NetSyncEvent("InterruptCommand", unit, "Idle")
		end

		local target = args and args.target
		local freeAim = args and args.free_aim or not UIAnyEnemyAttackGood(self)
		if freeAim and not g_Combat and self.basicAttack and self.ActionType == "Melee Attack" then
			local action = GetMeleeAttackAction(self, unit)
			freeAim = action.id ~= "CancelMark"
		end
		freeAim = freeAim and (self.id ~= "CancelMark")
		if not self.IsTargetableAttack and IsValid(target) and freeAim then
			local ap = self:GetAPCost(unit, args)
			NetStartCombatAction(self.id, unit, ap, args)
			return
		end
		
		local isFreeAimMode = mode == "IModeCombatAttack" or mode == "IModeCombatMelee" 
		if not isFreeAimMode and mode == "IModeCombatAreaAim" then
			local weapon = self:GetAttackWeapons(unit)
			isFreeAimMode = not IsOverwatchAction(self.id) and IsKindOf(weapon, "Firearm") and not IsKindOfClasses(weapon, "HeavyWeapon", "FlareGun")
		end
		isFreeAimMode = isFreeAimMode and self.id ~= "Bandage"
		
		if isFreeAimMode and not self.RequireTargets and (not target) and freeAim then
			CreateRealTimeThread(function()
				local prompt = "ok"
				if (not args or not args.free_aim) and g_Combat then
					local modeDlg = GetInGameInterfaceModeDlg()
					local text = T(871884306956, "There are no valid enemy targets in range. You can target the attack freely instead. <em>Free Aim</em> ranged attacks consume AP normally and can target anything, even empty spaces.")
					if mode == "IModeCombatMelee" then
						text = T(306912792200, "There are no valid enemy targets in range. If you wish to attack a non-hostile target, you can target the attack freely instead. <em>Free Aim</em> melee attacks consume AP normally and can target any adjacent unit.")
					end
					local choiceUI = CreateQuestionBox(
						modeDlg,
						T(333335408841, "Free Aim"),
						text,
						T(333335408841, "Free Aim"),
						T(1000246, "Cancel"))
					prompt = choiceUI:Wait()
				end
				if prompt == "ok" then
					args = args or {}
					args.free_aim = true
					CombatActionAttackStart(self, units, args, "IModeCombatFreeAim", noChangeAction)
				end
			end)
			return
		elseif mode == "IModeCombatMelee" and target then
			local weapon = self:GetAttackWeapons(unit)
			local ok, reason = unit:CanAttack(target, weapon, self)
			if not ok then
				ReportAttackError(args.target, reason)
				return
			end
			--if not IsMeleeRangeTarget(unit, nil, nil, target) then			
				--ReportAttackError(args.target, AttackDisableReasons.CantReach)
				--return
			--end
		end
		
		-- Check what actually needs switching
		local changeNeeded, dlg, targetGiven = CombatActionChangeNeededTryRetainTarget(mode, self, unit, target, freeAim)
		if mode == "IModeCombatAttack" and changeNeeded then
			target = targetGiven
		end

		-- Clicking a single target skill twice will cause the attack to proceed
		if not changeNeeded then
			if dlg.crosshair then
				dlg.crosshair:Attack()
			else
				dlg:Confirm()
			end
			return
		end
		
		-- This should prob have something to do with action.RequireTarget
		-- but that isn't a reliable indicator.
		if mode == "IModeCombatAttack" and not target then return end
		
		-- Changing actions requires notifying the dialog to exit quietly.
		if changeNeeded == "change-action" then
			dlg.context.changing_action = true
		end
		
		-- It is possible for the unit to have been deselected in all our waiting.
		-- Of for the action to have been disabled.
		local state = self:GetUIState(units)
		if not SelectedObj or state ~= "enabled" then
			return
		end

		if mode == "IModeCombatAttack" and self.id ~= "MarkTarget" then
			-- The unit might step out of cover, changing their position. We want to calculate the action camera from
			-- the position where the unit will be rather than where it is, as it could show an angle we dont want (ex. crosshair on unit)
			assert(IsValid(unit))
			
			local action = self
			if self.group == "FiringModeMetaAction" then
				action = GetUnitDefaultFiringModeActionFromMetaAction(unit, self)
			end
			
			NetSyncEvent("Aim", unit, action.id, target)
			WaitMsg("AimIdleLoop", 800)
		end
		
		-- Patch selection outside of combat to remove multiselection
		-- We're not doing this through SelectObj as the selection changed msg
		-- will cancel the action.
		if not g_Combat then
			Selection = { unit }
		end

		local modeDlg = GetInGameInterfaceModeDlg()
		modeDlg.dont_return_camera_on_close = true
		SetInGameInterfaceMode(mode, {
			action = self,
			attacker = unit,
			target = target,
			aim = args and args.aim,
			free_aim = freeAim,
			changing_action = changeNeeded == "change-action"
		})
	end)
end

function MeleeCombatActionGetValidTiles(attacker, target)
	local tiles
	if g_Combat then
		local attacker_stance = attacker.species == "Human" and "Standing" or nil
		local combatPath = GetCombatPath(attacker, attacker_stance)
		tiles = combatPath:GetReachableMeleeRangePositions(target, true)
	else
		tiles = GetMeleeRangePositions(attacker, target, nil, true)
	end
	return tiles
end

-- Used to get the cost of moving to a target in melee abilities.
function CombatActionMeleeActionCost(unit, args, target, ap)
	-- ignore move part when pos == false
	-- this happens when validating the cost in multiplayer
	local stance = args and args.stance
	local goto_pos = args and args.goto_pos
	if goto_pos == false or (goto_pos == nil and target == unit) then
		return ap, ap, stance
	end

	if not IsValid(target) then return -1, ap end

	if goto_pos == nil then
		goto_pos = unit:GetClosestMeleeRangePos(target, stance)
		if not goto_pos then
			return -1, ap
		end
	end
	local goto_ap = 0
	local stance_ap = 0
	if stance and stance ~= unit.stance then
		stance_ap = unit:GetStanceToStanceAP(args.stance)
	end
	
	if goto_pos ~= SnapToVoxel(unit:GetPos()) then
		goto_ap = CombatActions.Move:GetAPCost(unit, { goto_pos = goto_pos, stance = args and args.stance })
		if not goto_ap or goto_ap < 0 then
			return -1, ap
		end
		goto_ap = Max(0, goto_ap - Max(0, unit.free_move_ap))
	end
	return ap + goto_ap + stance_ap, ap, stance
end

function CombatActionInteractionGetCost(self, unit, args)
	if not g_Combat or args and args.skip_cost then
		return 0, 0
	end

	local target = args and args.target
	local goto_ap = 0
	if args and args.goto_pos ~= false then
		local pos = args.goto_pos or target and unit:GetInteractionPosWith(target)
		goto_ap = pos and CombatActions.Move:GetAPCost(unit, { goto_pos = pos })
		args.ap_cost_breakdown = { move_cost = goto_ap }
		if not goto_ap or goto_ap < 0 then
			return -1, 0
		end
		--goto_ap = Max(0, goto_ap - Max(0, unit.free_move_ap))
	end
	
	local ap
	if args and args.override_ap_cost then
		ap = args.override_ap_cost
	elseif IsKindOf(target, "CustomInteractable") then
		ap = target.ActionPoints
	else
		ap = self.ActionPoints
	end

	return goto_ap + ap, ap
end

function CombatActionExecuteWithMove(self, unit, args)
	if not args or not args.target then return end
	if #unit > 0 then
		unit = ChooseClosestObject(unit, args.target)
	end
	if not args.goto_pos then
		args.goto_pos = unit:GetInteractionPosWith(args.target)
	end
	args.goto_ap = args.goto_pos ~= SnapToVoxel(unit:GetPos()) and CombatActions.Move:GetAPCost(unit, args) or 0
	local ap, action_ap = self:GetAPCost(unit, args)
	NetStartCombatAction(self.id, unit, ap, args)
end

function CombatActionIsBusy(action, unit)
	--this func is not sync, it checks local not yet synced actions as well
	return HasCombatActionWaiting(unit) or not unit:IsIdleCommand() or unit.actions_nettravel > 0 
end

function CombatActionGetAttackableEnemies(self, attacker, weapon, filter, ...)
	local attackable = {}
	if not attacker or (self.ActionType ~= "Melee Attack" and self.ActionType ~= "Ranged Attack") then 
		return attackable 
	end
	local visibleTargets = attacker:GetVisibleEnemies()
	local weps = weapon or self:GetAttackWeapons(attacker)
	for i, t in ipairs(visibleTargets) do
		if IsValid(t) and (not filter or filter(t, ...)) then
			local canAttack, err = attacker:CanAttack(t, weps, self, 0)
			if canAttack then
				attackable[#attackable + 1] = t
			end
		end
	end
	return attackable
end

function CombatActionGetOneAttackableEnemy(action, attacker, weapon, filter, ...)
	if not IsValid(attacker) or (action.ActionType ~= "Melee Attack" and action.ActionType ~= "Ranged Attack") then 
		return 
	end
	local visibleTargets = attacker:GetVisibleEnemies()
	weapon = weapon or action:GetAttackWeapons(attacker)
	for i, t in ipairs(visibleTargets) do
		if IsValid(t) and (not filter or filter(t, ...)) then
			local canAttack, err = attacker:CanAttack(t, weapon, action, 0)
			if canAttack then
				return t
			end
		end
	end
end

function CombatActionGenericAttackGetUIState(self, units, args)
	if netInGame and (IsPaused() and not IsActivePaused()) then
		return "disabled", AttackDisableReasons.InvalidTarget
	end
	local unit = units[1]
	
	local recharge = unit:GetSignatureRecharge(self.id)
	if recharge then
		if recharge.on_kill then
			return "disabled", AttackDisableReasons.SignatureRechargeOnKill
		end
		return "disabled", AttackDisableReasons.SignatureRecharge
	end
	
	local cost = self:GetAPCost(unit, args)
	if cost < 0 then return "hidden" end
	if not unit:UIHasAP(cost) then return "disabled", GetUnitNoApReason(unit) end

	local wep = args and args.weapon or self:GetAttackWeapons(unit)
	if args and args.target then
		local canAttack, err = unit:CanAttack(
			args.target,
			wep,
			self,
			args and args.aim or 0,
			args and args.goto_pos,
			not "skip_cost",
			args and args.free_aim
		)
		if not canAttack then return "disabled", err end
		return "enabled"
	end
	
	if not self.RequireTargets then
		local canAttack, err = unit:CanAttack(false, wep, self, args and args.aim or 0)
		if not canAttack then return "disabled", err end
		return "enabled"
	end

	local target = self:GetAnyTarget(units)
	if not target then
		return "disabled", AttackDisableReasons.NoTarget
	end
	return "enabled"
end

function CombatActionsAOEGenericDamageCalculation(self, unit, base_damage_mod)
	local weapon = self:GetAttackWeapons(unit)
	if not weapon then return 0 end

	local params = weapon:GetAreaAttackParams(self.id, unit)
	local base = unit:GetBaseDamage(weapon)
	base = MulDivRound(base, 100 + (base_damage_mod or 0), 100)
	local mod = params.damage_mod + params.attribute_bonus
	local damage = MulDivRound(base, mod, 100)
	local bonus = MulDivRound(base, params.attribute_bonus, 100)
	base = damage - bonus

	return damage, base, bonus, params
end

function CombatActionsAttackGenericDamageCalculation(self, unit, args)
	local weapon = args and args.weapon or self:GetAttackWeapons(unit)
	if not weapon then 
		return 0, 0, 0, { critChance = 0, min = 0, max = 0 }
	end
	if not IsKindOf(unit, "Unit") then
		local base = unit:GetBaseDamage(weapon)
		return base, base
	end
	local aim = args and args.aim
	if not aim then
		local dlg = GetInGameInterfaceModeDlg() 
		if IsKindOf(dlg, "IModeCombatAttackBase") and dlg.crosshair then
			aim = dlg.crosshair.aim
		end
	end
	local critChance = unit:CalcCritChance(weapon, GetCurrentUITarget(), aim, args and args.goto_pos, args and args.target_spot_group, self)
	local base = unit:GetBaseDamage(weapon)
	local hit = {
		weapon = weapon,
		critical = critChance,
		actionType = self.ActionType,
		ignore_obj_damage_mod = true,
	}
	weapon:PrecalcDamageAndStatusEffects(unit, false, unit:GetPos(), base, hit)
	base = hit.damage or base
	
	return base, base, 0, { critChance = critChance, min = base, max = base }
end

function CombatActionAttackResultsDisperseWarning(hits, weapon, attacker, target)
	local attacker_pos = attacker:GetPos()
	local target_pos = IsPoint(target) and target or target:GetPos()
	local distance = attacker_pos:Dist(target_pos)
	local dispersion = weapon:GetMaxDispersion(distance)
	local minz = terrain.GetHeight(attacker_pos) + const.SlabSizeZ / 2
	if not attacker_pos:IsValidZ() or attacker_pos:z() < minz then
		attacker_pos = attacker_pos:SetZ(minz)
	end
	
	local base_shape = {}
	local vAT = attacker_pos - target_pos
	local perpendicular = point(vAT:y(), -vAT:x())
	local side_a = target_pos + SetLen(perpendicular, dispersion)
	local side_b = target_pos - SetLen(perpendicular, dispersion)
	base_shape[#base_shape + 1] = attacker_pos
	base_shape[#base_shape + 1] = side_a
	base_shape[#base_shape + 1] = side_b
	perpendicular = point(perpendicular:y(), -perpendicular:x())
	base_shape[#base_shape + 1] = side_a + SetLen(perpendicular, distance * 2)
	base_shape[#base_shape + 1] = side_b + SetLen(perpendicular, distance * 2)
	
	local vertices = {
		point(-const.SlabSizeX / 2, -const.SlabSizeY / 2),
		point( const.SlabSizeX / 2, -const.SlabSizeY / 2),
		point( const.SlabSizeX / 2,  const.SlabSizeY / 2),
		point(-const.SlabSizeX / 2,  const.SlabSizeY / 2),
	}
	local ms_points = {}
	for _, pt in ipairs(base_shape) do
		for _, vert in ipairs(vertices) do
			ms_points[#ms_points + 1] = pt + vert
		end
	end
	
	local ms_shape = ConvexHull2D(ms_points)
	local attacker_team = attacker.team
	for i, u in ipairs(g_Units) do
		if u == attacker or not u.team or u.team:IsEnemySide(attacker_team) then goto continue end
		if IsPointInsidePoly2D(u:GetPos(), ms_shape) then
			hits[#hits + 1] = {
				obj = u,
				damage = 0,
				conditional_damage = 0,
				ignore_armor = true
			}
		end
		::continue::
	end
	return hits
end

function CombatActionsAppendFreeAimActionName(action, unit, name)
	if not unit:CanBeControlled() then
		return name
	end

	if not UIAnyEnemyAttackGood() then
		name = name .. T(587521561381, " (Free Aim)")
	end
	return name
end

function CombatActionsAppendFreeAimDescription(action, unit, descr, ignore_check)
	if ignore_check or UIAnyEnemyAttackGood() then
		if GetUIStyleGamepad() then
			local image_path, scale = GetPlatformSpecificImagePath("LeftThumbClick")
			local image_path2, scale2 = GetPlatformSpecificImagePath("RightTrigger")
			local imageCombined = Untranslated("<image " .. image_path2 .. ">+<image " .. image_path .. ">")
			descr = descr .. T{714791806470, "<newline><newline><flavor><shortcut> Free Aim Mode</flavor>", shortcut = imageCombined}
		else
			local text = GetShortcutButtonT("actionFreeAim")
			descr = descr .. T{434227846947, "<newline><newline><flavor>[<shortcut>] Free Aim Mode</flavor>", shortcut = text}
		end
	else
		descr = descr .. T(636120454494, "<newline><newline><flavor>Free Aim - no visible enemies in range</flavor>")
	end
	return descr
end

function EnterFreeAimWithDefaultCombatAction(unit)
	-- If the mouse is over an action button, take its action instead.
	local defaultAction
	local combatActions = GetInGameInterfaceModeDlg()
	combatActions = combatActions and combatActions:ResolveId("idCombatActionsContainer")
	if combatActions then
		for i, b in ipairs(combatActions) do
			if b.rollover then
				defaultAction = b.context.action
				break
			end
		end
	end

	if not defaultAction then
		defaultAction = unit:GetDefaultAttackAction()--("ranged")
	end
	
	if defaultAction:GetUIState({unit}) ~= "enabled" then return end
	defaultAction:UIBegin({unit}, {free_aim = true})
end

function CombatActionPlayCustomError(action, unit)
	--local _, err = action:GetUIState({unit})
	--nop ph
end

function CombatActionGrenadeDescription(action, units)
	local baseDescription = T(519947740930, "Affects a designated area.")
	
	local unit = units[1]
	local weapon = action:GetAttackWeapons(unit)
	if not weapon then return baseDescription end
	
	if weapon:HasMember("GetCustomActionDescription") then
		local descr = weapon:GetCustomActionDescription(action, units)
		if descr and descr ~= "" then
			return descr
		end
	end

	local base = unit:GetBaseDamage(weapon)
	local bonus = GetGrenadeDamageBonus(unit)
	local damage = MulDivRound(base, 100 + bonus, 100)
	local text = T{baseDescription, damage = damage, basedamage = base, bonusdamage = damage - base}
	if (weapon.AdditionalHint or "") ~= "" then
		text = text  .. "<newline>" .. weapon.AdditionalHint
	end
	return text
end


function GetUnitDefaultFiringModeActionFromMetaAction(unit, metaAction, nonUnitDefault)
	local def_id, actions = unit:ResolveDefaultFiringModeAction(metaAction, true)
	if nonUnitDefault then
		return actions and actions[1], actions
	end
	return CombatActions[def_id], actions
end

local dev_shortcuts

function StripDeveloperShortcuts(action)
	if Platform.developer then
		if not dev_shortcuts then
			dev_shortcuts = {}
			for _, action in ipairs(XShortcutsTarget:GetActions()) do
				if not action.ActionId:starts_with("combatAction") and action.ActionMode ~= "Editor" then
					dev_shortcuts[action.ActionShortcut] = true
					dev_shortcuts[action.ActionShortcut2] = true
				end
			end
		end
		
		local s1, s2, sg = action.ActionShortcut, action.ActionShortcut2, action.ActionGamepad
		if s1 and s1 ~= "" and dev_shortcuts[s1] then s1 = nil end
		if s2 and s2 ~= "" and dev_shortcuts[s2] then s2 = nil end
		action:SetActionShortcuts(s1, s2, sg)
	end
end

function GetOtherWeaponSet(currentSet)
	if currentSet == "Handheld A" then return "Handheld B" end
	if currentSet == "Handheld B" then return "Handheld A" end
	-- ???
	return "Handheld A"
end

function GetWeaponChangeActionDisplayName(unit)
	local otherSet = "Handheld A"
	if unit and unit.current_weapon == "Handheld A" then
		otherSet = "Handheld B"
	end
	local weapons = unit and unit:GetEquippedWeapons(otherSet)
	if not weapons or #weapons == 0 then
		weapons = {unit:GetActiveWeapons("UnarmedWeapon")}
	end
	
	local itemTypes = {}
	for i, w in ipairs(weapons) do
		itemTypes[#itemTypes + 1] = w.DisplayName
	end
	local weaponsTxt = table.concat(itemTypes, "/")
	return T{887065293634, "Switch to <weaponsTxt>", weaponsTxt = weaponsTxt}
end

function GetUnitWeapons(unit, otherSet)
	if not unit then return empty_table end
	
	local weps = otherSet and GetOtherWeaponSet(unit.current_weapon) or unit.current_weapon
	local items = unit:GetItemsInWeaponSlot(weps)
	if not otherSet then
		-- Things such as manning an emplacement change the active weapon without
		-- being equipped through the inventory. If the active weapon returned is
		-- not present in the inventory, show it instead
		local wep1, wep2 = unit:GetActiveWeapons()
		if (wep1 and not table.find(items, wep1)) or (wep2 and not table.find(items, wep2)) then
			items = { wep1, wep2 }
		end
	end
	
	local anyWeapon = false
	for i, item in ipairs(items) do
		if item:IsWeapon() then
			anyWeapon = true
			break
		end
	end
	if not anyWeapon and #items ~= 2 then
		local unarmed = unit:GetActiveWeapons("UnarmedWeapon")
		table.insert(items, 1, unarmed)
	end
	return items
end

function IsCombatActionForAlly(action) 
	if not action then return false end
	
	local isActionEnabled = SelectedObj and SelectedObj.ui_actions and SelectedObj.ui_actions
	isActionEnabled = isActionEnabled and isActionEnabled[action.id] == "enabled"
	if not isActionEnabled then return false end

	local targets = action:GetTargets({SelectedObj})
	local allyTargers = GetAllAlliedUnits(SelectedObj)
	for _, target in ipairs(targets) do
		if table.find(allyTargers, target) or target == SelectedObj then
			return true
		end
	end
	
	return false
end

function CombatActionTargetFilters.MGBurstFire(target, units)
	local attacker = units[1]
	if #units > 1 then
		units = {attacker}
	end
	local overwatch = g_Overwatch[attacker]
	if overwatch and overwatch.permanent then
		-- only fire in the cone when set
		local angle = overwatch.orient or CalcOrientation(attacker, overwatch.target_pos)
		local los_any = CheckLOSRange(target, attacker, overwatch.dist, attacker.stance, overwatch.cone_angle, angle)
		return los_any
	end	
	return true
end

function CombatActionTargetFilters.Charge(target, attacker, move_ap, action_id)
	local goto_pos, _, dist_error, line_error = GetChargeAttackPosition(attacker, target, move_ap, action_id)
	return not dist_error and not line_error and not not goto_pos
end

function CombatActionTargetFilters.HyenaCharge(target, attacker, move_ap, jump_dist, action_id)
	local goto_pos, _, _, dist_error, line_error = GetHyenaChargeAttackPosition(attacker, target, move_ap, jump_dist, action_id)
	return not dist_error and not line_error and not not goto_pos
end

function CombatActionTargetFilters.KnifeThrow(target, attacker, range)
	return IsCloser(attacker, target, range + 1)
end

function CombatActionTargetFilters.MeleeAttack(target, attacker)
	--return attacker ~= target and IsMeleeRangeTarget(attacker, nil, nil, target)
	return attacker ~= target
end

function CombatActionTargetFilters.Pindown(target, attacker, weapon)
	if not weapon then
		return false
	end
	if not VisibilityCheckAll(attacker, target, nil, const.uvVisible) then
		return false
	end
	local body_parts = target:GetBodyParts(weapon)
	for _, def in ipairs(body_parts) do
		if attacker:HasPindownLineCached(target, def.id, attacker:GetOccupiedPos()) then
			return true
		end
	end
end

function GetBandageTargets(unit, mode, range_mode)
	local targets = (mode ~= "any") and {}
	if unit:HasStatusEffect("Bleeding") or (unit.HitPoints < unit.MaxHitPoints) then
		if mode == "any" then 
			return unit
		end
		targets[1] = unit
	end
	local allies = GetAllAlliedUnits(unit)
	if unit.team and unit.team.player_team then
		-- enable player to bandage neutral units as well
		allies = table.icopy(allies)
		for _, u in ipairs(g_Units) do
			if u.team.neutral then
				allies[#allies + 1] = u
			end
		end
	end
	local base_cost = CombatActions.Bandage:GetAPCost(unit)
	for _, ally in ipairs(allies) do
		if not ally:IsDead() and ((ally.HitPoints < ally.MaxHitPoints) or ally:IsDowned() or ally:HasStatusEffect("Bleeding") or ally:HasStatusEffect("Unconscious")) then
			local range_ok = range_mode == "ignore" or IsMeleeRangeTarget(unit, nil, nil, ally)
			if range_mode == "reachable" and base_cost > 0 then
				if g_Combat then
					local pos = unit:GetClosestMeleeRangePos(ally)
					if pos then
						local path = GetCombatPath(unit)
						local ap = path:GetAP(pos)
						if ap then 
							local cost = base_cost + Max(0, ap - unit.free_move_ap)
							range_ok = unit:HasAP(cost)
						end
					end
				else
					range_ok = true
				end
			end
			
			if range_ok then
				if mode == "any" then
					return ally
				end
				targets[#targets +1] = ally
			end
		end
	end
	return targets
end

function GetMeleeAttackTargets(attacker, mode)
	local targets
	for _, target in ipairs(g_Units) do
		if target ~= attacker and not target:IsDead() and IsMeleeRangeTarget(attacker, nil, nil, target) then
			if mode == "any" then
				return target
			end
			targets = targets or {}
			targets[#targets + 1] = target
		end
	end
	return targets
end

function GetMeleeAttackAPCost(action, unit, args)
	local cost
	if action.CostBasedOnWeapon then
		local weapon = action:GetAttackWeapons(unit, args)	
		cost = weapon and unit:GetAttackAPCost(action, weapon, nil, args and args.aim or 0, action.ActionPointDelta) or -1
	else
		cost = action.ActionPoints
	end
	if args and args.action_cost_only then
		return cost
	end
	local goto_pos = args and args.goto_pos
	if not goto_pos and args and args.target then
		goto_pos = GetClosestMeleeRangePos(unit, args.target)
	end
	local attack_cost = cost
	local move_cost = 0
	if cost >= 0 and goto_pos then
		local path = GetCombatPath(unit)
		move_cost = path:GetAP(goto_pos)
		cost = cost + Max(0, move_cost or 0)
	end
	if args and type(args.ap_cost_breakdown) == "table" then
		args.ap_cost_breakdown.attack_cost = attack_cost
		args.ap_cost_breakdown.move_cost = move_cost
		args.ap_cost_breakdown.total_cost = cost
	end
	return cost
end

function CombatActionCreateMeleeRangeArea(unit, vstate, mode)
	local voxels = GetMeleeRangePositions(unit)
	voxels = voxels or {}
	local pos = unit:GetPos()
	table.insert(voxels, point_pack(pos))
	return MeleeAOEVisuals:new({vstate = vstate or "Cast"}, nil, {voxels = voxels, pos = pos, mode =  mode or "Ally"})
end

function XActionRedirectToCombatAction(xactionName, obj)
	local actions = obj.ui_actions
	for i, actionId in ipairs(actions) do
		local combatAction = CombatActions[actionId]
		local redirectAction = combatAction and combatAction.KeybindingFromAction
		if redirectAction and redirectAction == xactionName then
			return combatAction, actions[actionId]
		end
	end
end

function GetSignatureActionDescription(action)
	local perk = CharacterEffectDefs[action.id]
	local description = perk and T{perk.Description, perk} or action.Description
	if (description or "") == "" then
		description = action:GetActionDisplayName()
	end
	return description
end

function GetSignatureActionDisplayName(action)
	local perk = CharacterEffectDefs[action.id]
	local name = perk and perk.DisplayName or action.DisplayName
	if (name or "") == "" then
		name = Untranslated(action.id)
	end
	return name
end

function IsOverwatchAction(actionId)
	return actionId == "Overwatch" or actionId == "DanceForMe" or actionId == "EyesOnTheBack" or actionId == "MGSetup" or actionId == "MGRotate"
end

function GetThrowItemIcon(self, unit)
	local weapon = self:GetAttackWeapons(unit)
	local icon = IsKindOf(weapon, "GrenadeProperties") and weapon.ActionIcon or ""
	return (icon ~= "") and icon or self.Icon
end

function GetMeleeAttackAction(action, unit)
	if not g_Combat and action.basicAttack and action.ActionType == "Melee Attack" then
		return (unit and unit.marked_target_attack_args) and CombatActions.CancelMark or CombatActions.MarkTarget
	end
	return action
end