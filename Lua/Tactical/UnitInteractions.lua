-- general interaction
local pfFinished = const.pfFinished
local pfFailed = const.pfFailed
local pfDestLocked = const.pfDestLocked
local pfTunnel = const.pfTunnel
local objEnumSize = const.SlabSizeX * 1

function OnMsg.ClassesBuilt()
	for name, class in pairs(g_Classes) do
		if IsKindOf(class, "CustomInteractable") then
			objEnumSize = Max(class.range_in_tiles * const.SlabSizeX, objEnumSize)
		end
	end
end

function Unit:GetReachableObjects(class, filter)
	if not IsValid(self) then return {} end
	local unitPos = self:GetOccupiedPos() or self:GetPos()
	local hasAmbient = false
	class = class or "Interactable"
	return MapGet(unitPos, objEnumSize, class, function(obj)
		if obj == self then return false end
		
		local isAmbient = IsKindOf(obj, "Unit") and obj:IsAmbientUnit()
		if isAmbient and hasAmbient then
			return false
		end

		-- Check if close enough to any of the interaction positions.
		local positions = obj:GetInteractionPos(self)
		local closeEnough = self:CloseEnoughToInteract(positions, obj, unitPos)
		if not closeEnough then return false end
		local valid = not filter or filter()
		if valid then
			hasAmbient = isAmbient
		end
		return valid
	end) or {}
end

local skip_conflict_banter_filter = { skipConflictCheck = true }

function Unit:GetInteractionInfo()
	if self.command == "ExitMap" or self.command == "Die" then return end

	if self.interacting_unit then
		return
	end

	if not self.visible or self:GetOpacity() == 0 then return end

	if self:IsDead() and self.command == "Dead" then
		if not self.immortal and self:GetItemInSlot("InventoryDead") then
			return Presets.CombatAction.Interactions.Interact_LootUnit
		end
		return
	end

	if not self:IsNPC() then return end

	local conversationId = FindEnabledConversation(self)
	if conversationId and not g_Combat then
		local conversation = Conversations[conversationId]
		if GetSectorConflict() and conversation.disabledInConflict then
			return Presets.CombatAction.Interactions.Interact_NotNow
		else
			return Presets.CombatAction.Interactions.Interact_Talk
		end
	elseif self.enabled and self.spawner and
		#(self.spawner.InteractionEffects or empty_table) ~= 0 and
		EvalConditionList(self.spawner.InteractionConditions or empty_table) then
		return Presets.CombatAction.Interactions.Interact_UnitCustomInteraction, self.spawner.InteractionVisuals
	end

	if Platform.developer and config.FindInvalidInteractionBanters then
		DeveloperCheckUnitInteractionBanters(self)
	end

	if not self:GetAllBanters("findFirst", skip_conflict_banter_filter) then return end

	if GetSectorConflict() then
		if not self:GetAllBanters("findFirst") then
			return Presets.CombatAction.Interactions.Interact_NotNow
		end
	end
	return Presets.CombatAction.Interactions.Interact_Banter
end

function Unit:GetInteractionCombatAction(unit)
	if self.behavior == "Hang" then return false end
	if unit and self:IsOnEnemySide(unit) and not unit:IsDead() and not self:IsDead() then return false end
	return self:GetInteractionInfo()
end

function Unit:PopulateVisualCache()
	-- nop
end

local face_duration = 200
function Unit:BeginInteraction(other_unit)
	--note: self is the interactable here
	if self:IsDead() then return end
	self.angle_before_interaction = self.angle_before_interaction or self:GetOrientationAngle()
	self:Face(other_unit, face_duration)
	Sleep(face_duration)
end

function Unit:EndInteraction(other_unit)
	--note: self is the interactable here
	if self.angle_before_interaction and self.command ~= "PlayInteractionBanter" and not self:IsPersistentDead() then
		self:SetOrientationAngle(self.angle_before_interaction, face_duration)
		self.angle_before_interaction = false
	end
	Interactable.EndInteraction(self, other_unit)
end

function Unit:GetInteractionPos(unit)
	if not IsValid(self) then return false end
	local x, y, z = SnapToPassSlabXYZ(self)
	if x and (not unit or unit:IsEqualPos(x, y, z)) then
		return point(x, y, z)
	end
	if g_Combat and self:IsDead() then
		return self:GetPos()
	end
	local closestMeleePos = unit and unit:GetClosestMeleeRangePos(self, nil, false, "interaction")
	if closestMeleePos then return closestMeleePos end

	-- Sitting units don't return valid melee pos
	if self.command == "Visit" then
		return GetClosestMeleeRangePos(unit, self)
	end
end

function Unit:GetInteractionPosWith(target, ignore_occupied)
	local positions = target:GetInteractionPos(self)
	if not positions then
		return
	end
	if type(positions) == "table" then
		if #positions == 0 then
			return
		end
		if ignore_occupied == nil then
			ignore_occupied = positions.ignore_occupied
		end
	end
	local pfflags = self:GetPathFlags()
	if ignore_occupied then
		pfflags = pfflags & ~const.pfmDestlock
	end
	local has_path, closest_pos = pf.HasPosPath(self, positions, nil, 0, 0, self, 0, nil, pfflags)
	-- Could path to
	if has_path and closest_pos then
		if closest_pos == positions or type(positions) == "table" and table.find(positions, closest_pos) then
			return closest_pos
		-- Couldnt path, but unit is close enough
		elseif self:CloseEnoughToInteract(positions, target) then
			return closest_pos
		end
	end
end

function Unit:CloseEnoughToInteract(positions, interactable, selfPosOverride)
	if not positions then
		return false
	end
	local my_pos = selfPosOverride or self:GetPos()
	if type(positions) == "table" then
		if table.find(positions, my_pos) then
			return true
		end
	elseif IsPoint(positions) then
		local pos = positions
		local minDist = interactable.range_in_tiles * const.SlabSizeX
		if IsCloser2D(my_pos, pos, minDist) then
			local start_z = my_pos:z() or terrain.GetHeight(my_pos)
			local z = pos:z() or terrain.GetHeight(pos)
			if abs(start_z - z) < const.Combat.InteractionMaxHeightDifference then
				return true
			end
		end
	end
	return false
end

local function lSyncCheck(id, sync, ...)
	if sync then
		NetUpdateHash("CanInteractWith" .. tostring(id), ...)
	end
end

local can_interact_unit_list = {}

function Unit:CanInteractWith(target, action_id, skip_cost, from_ui, sync)
	lSyncCheck(0, sync, target, action_id, skip_cost, from_ui)
	if not IsKindOf(target, "Interactable") then
		lSyncCheck(1, sync, target, action_id, skip_cost, from_ui)
		return false
	end
	
	local prevInteractUnit = g_Units[target.being_interacted_with]
	if IsValid(prevInteractUnit) and prevInteractUnit:IsLocalPlayerControlled() ~= self:IsLocalPlayerControlled() then
		--uninteractable while other player is interacting with it.
		lSyncCheck(11, sync, target, action_id, skip_cost, from_ui)
		return false
	end
	
	if not SpawnedByEnabledMarker(target) or not target.enabled then
		lSyncCheck(2, sync, target, action_id, skip_cost, from_ui, target.enabled, gv_CurrentSectorId, (gv_CurrentSectorId and gv_Sectors[gv_CurrentSectorId].intel_discovered))
		return false
	end

	if IsKindOf(target, "SlabWallWindow") then
		if not target:ShouldShowUnitInteraction() then
			lSyncCheck(3, sync, target, action_id, skip_cost, from_ui)
			return false
		end
	end

	local visual = ResolveInteractableVisualObjects(target, nil, nil, "findFirst")
	if not visual then 
		lSyncCheck(4, sync, target, action_id, skip_cost, from_ui)
		return false 
	end

	if action_id == "Interact_CustomInteractable" and IsKindOf(target, "CustomInteractable") then
		can_interact_unit_list[1] = self
		if from_ui or target:GetUIState(can_interact_unit_list) == "enabled" then
			lSyncCheck(5, sync, target, action_id, skip_cost, from_ui)
			return true
		end
	end

	-- These door interactions are additional actions that do not override Open/Close
	local combat_action
	if action_id and IsKindOf(target, "Lockpickable") and table.find(LockpickableActionIds, action_id) then
		combat_action = CombatActions[action_id]
	else
		combat_action = target:GetInteractionCombatAction(self)
	end
	if not combat_action or action_id and action_id ~= combat_action.id then
		lSyncCheck(6, sync, target, action_id, skip_cost, from_ui)
		return false
	end

	-- special-case Interact_Attack for units using emplacements that prevent their movement
	if combat_action.id == "Interact_Attack" and self:HasStatusEffect("ManningEmplacement") then
		can_interact_unit_list[1] = self
		if not CombatActionTargetFilters.MGBurstFire(target, can_interact_unit_list) then
			return false
		end
	elseif g_Combat and not skip_cost then
		if not target or self:HasStatusEffect("StationedMachineGun") or self:HasStatusEffect("ManningEmplacement") then
			return false
		end
		local has_path
		local combatPath = GetCombatPath(self)
		local paths_ap = combatPath.paths_ap
		local positions = target:GetInteractionPos(self)
		if IsPoint(positions) then
			if paths_ap[point_pack(positions)] then
				has_path = true
			end
		else
			for i, pos in ipairs(positions) do
				if paths_ap[point_pack(pos)] then
					has_path = true
					break
				end
			end
		end
		if not has_path then
			return false
		end
	end

	if not from_ui then
		can_interact_unit_list[1] = self
		local state, reason = combat_action:GetUIState(can_interact_unit_list, {target = target, skip_cost = skip_cost, goto_ap = 0})
		if state ~= "enabled" then
			lSyncCheck(7, sync, target, action_id, skip_cost, from_ui)
			return false, reason
		end
	end

	lSyncCheck(8, sync, target, action_id, skip_cost, from_ui)
	return true, combat_action
end

function Unit:RegisterInteractingUnit(unit)
	assert(self.interacting_unit == false)
	self.interacting_unit = unit
end

function Unit:UnregisterInteractingUnit(unit)
	assert(not unit or self.interacting_unit == unit)
	self.interacting_unit = nil
end

local inventoryCloseIdToMsg = {
	"Player1ClosedInventory",
	"Player2ClosedInventory",
}

function NetSyncEvents.OpenInventory(remoteId)
	NetGossip("Open", "Inventory", GetCurrentPlaytime())
end

function NetSyncEvents.ClosedInventory(remoteId)
	NetGossip("Close", "Inventory", GetCurrentPlaytime())
	Msg(inventoryCloseIdToMsg[remoteId])
end

function OnMsg.OpenInventorySubDialog()
	NetSyncEvent("OpenInventory", netUniqueId)
end

function OnMsg.CloseInventorySubDialog()
	NetSyncEvent("ClosedInventory", netUniqueId)
end

function Unit:BeingInteracted()
	local params = self:GetCommandParamsTbl("Idle")
	self:SetCommandParams(self.command, params)
	local base_anim = self:GetIdleBaseAnim()
	if not IsAnimVariant(self:GetStateText(), base_anim) then
		self:SetRandomAnim(base_anim)
	end
	local target = g_Units[self.being_interacted_with]
	if target then
		self:SetOrientationAngle(CalcOrientation(self, target), 200)
	end
	while self.being_interacted_with or IsUnitPartOfAnyActiveBanter(self) do
		Sleep(500)
	end
	Sleep(2000 + self:Random(1000))
end

local function lInteractionLoadingBar(self, action_id, target)
	local action = CombatActions[action_id]
	if (action and action.InteractionLoadingBar) or IsKindOf(target, "RangeGrantMarker") or (action_id == "Interact_CustomInteractable" and target.InteractionLoadingBar) then
		local time = const.InteractionActionProgressBarTime
		local barUI = SpawnProgressBar(time)
		local spot = self:GetSpotBeginIndex("Headstatic")
		barUI:AddDynamicPosModifier({id = "attached_ui", target = self, spot_idx = spot})
		self:PushDestructor(function(self)
			if barUI.window_state ~= "destroying" then
				barUI:Close()
			end
		end)
		PlayFX("InteractionLoadingBar", "start")
		self:SetRandomAnim(self:GetIdleBaseAnim())
		self:Face(target, 200)
		Sleep(time)
		PlayFX("InteractionLoadingBar", "end")
		self:PopDestructor()
	end
end

function Unit:InteractWith(action_id, cost_ap, pos, goto_ap, target, from_ui)
	local can_interact = not (g_Combat and self:HasPreparedAttack()) and self:CanInteractWith(target, action_id, true, from_ui, "sync check")
	NetUpdateHash("Unit_InteractWith", self, not not g_Combat, (g_Combat and self:HasPreparedAttack()), can_interact)
	if can_interact and target.being_interacted_with then
		local prevInteractUnit = g_Units[target.being_interacted_with]
		if not g_Combat and
			prevInteractUnit and
			self:IsLocalPlayerControlled() == prevInteractUnit:IsLocalPlayerControlled() and
			prevInteractUnit.goto_target then
			prevInteractUnit:InterruptCommand("Idle")
		else
			can_interact = false
			--print("interactable already being interacted with")
		end
	end
	if not can_interact then
		if g_Combat then
			self:GainAP(cost_ap)
			CombatActionInterruped(self)
		end
		PlayFX("IactDisabled", "start")
		return
	end
	self:InterruptPreparedAttack()

	local target_restore_behavior
	local cmd_to_restore
	if action_id == "Interact_Banter" or action_id == "Interact_Talk" or action_id == "Interact_UnitCustomInteraction" then
		target_restore_behavior = IsKindOf(target, "Unit") and (target.behavior == "Visit" or target.behavior == "Cower" or 
		(target:GetCommandParamsTbl("Idle") and target:GetCommandParamsTbl("Idle").idle_stance ~= "Standing"))
		
		self:SetRandomAnim(self:GetIdleBaseAnim())
		local behavior_finished
		if target.behavior == "Patrol" or target.behavior == "GoBackAfterCombat" then
			behavior_finished = true
			cmd_to_restore = {cmd = "Patrol", cmd_params = target.behavior_params}
		elseif target.behavior == "Roam" or target.behavior == "RoamSingle" then
			if IsKindOf(target.traverse_tunnel, "SlabTunnelLadder") then
				target:SetActionInterruptCallback(function()
					target:SetCommand(false)
					Msg("LadderTraversed")
				end)
				while target.traverse_tunnel do
					WaitMsg("LadderTraversed", 300)
				end
			end
			behavior_finished = true
		elseif target.goto_target and target.interruptable then
			behavior_finished = true
		elseif target:IsIdleCommand() and target.interruptable then
			behavior_finished = true
		end

		if behavior_finished then
			target.being_interacted_with = self.session_id
			target:InterruptCommand("BeingInteracted")
		end
	else
		target.being_interacted_with = self.session_id
	end
	
	self:PushDestructor(function()
		if target.being_interacted_with == self.session_id then
			target.being_interacted_with = false
		end
	end)

	-- approach target
	local action_cost = g_Combat and cost_ap - goto_ap or 0
	local can_interact
	
	-- Play VR for selected loot to be opened
	if self:IsMerc() and (action_id == "Interact_LootUnit" or action_id == "Interact_LootContainer") and not IsBlockingLockpickState(target and target.lockpickState or "") then
		PlayVoiceResponse(self, "LootOpened")
	end
	
	if g_Combat then
		self:PushDestructor(function(self)
			self:GainAP(action_cost)
		end)
		PlayFX("InteractGoto", "start", self, target)
		can_interact = self:CombatGoto(action_id, goto_ap, pos)
		self:PopDestructor()
	else
		self:PushDestructor(function(self)
			if cmd_to_restore then
				target:SetCommand(cmd_to_restore.cmd, table.unpack(cmd_to_restore.cmd_params))
			end
		end)
		local positions, angle, preferred = target:GetInteractionPos(self)
		can_interact = self:CloseEnoughToInteract(positions, target)
		if not can_interact and preferred then
			PlayFX("InteractGoto", "start", self, target)
			NetUpdateHash("InteractGotoPreferred", self, target, preferred)
			can_interact = self:GotoSlab(preferred)
		end
		if not can_interact and positions and (IsPoint(positions) or #positions > 0) then
			PlayFX("InteractGoto", "start", self, target)
			NetUpdateHash("InteractGoto", self, target, positions)
			can_interact = self:GotoSlab(positions)
		end
		self:PopDestructor()
	end
	can_interact = can_interact and self:CanInteractWith(target, action_id, true, from_ui, "sync check")
	NetUpdateHash("Unit_InteractWith2", can_interact)
	if not can_interact then
		if g_Combat then
			self:GainAP(action_cost)
			CombatActionInterruped(self)
		end
		self:PopAndCallDestructor()
		return
	end
	local base_idle = self:GetIdleBaseAnim()
	if not IsAnimVariant(self:GetStateText(), base_idle) then
		local anim = self:GetNearbyUniqueRandomAnim(base_idle)
		self:SetState(anim)
	end

	--execute
	lInteractionLoadingBar(self, action_id, target)
	
	local looting = action_id == "Interact_LootUnit" or action_id == "Interact_LootContainer"
	NetUpdateHash("Unit_InteractWith3", looting)
	local containersInArea
	if looting then
		containersInArea = InventoryGetLootContainers(target)
		MultipleRegisterInteractingUnit(containersInArea, self)
	else
		target:RegisterInteractingUnit(self)
	end
	
	local interactionLogSpecifier = false
	self:PushDestructor(function(self)
		NetUpdateHash("Unit_InteractWith_Destro")
		if not IsValid(target) then return end
		if looting then
			MultipleUnregisterInteractingUnit(containersInArea, self)
		else
			target:UnregisterInteractingUnit(self)
		end
		if not target_restore_behavior then
			target:EndInteraction(self)
			if cmd_to_restore and (not target.behavior or target.behavior == "") then
				target:SetCommand(cmd_to_restore.cmd, table.unpack(cmd_to_restore.cmd_params))
			end
		end

		InteractableVisibilityUpdate({self})

		target:LogInteraction(self, action_id, "end", interactionLogSpecifier)
	end)
	local canOpen
	if looting then
		local fxName = action_id
		local fxTarget = target
		if target and target.los_check_obj then
			local containerObj = target.los_check_obj
			if IsKindOf(containerObj, "DummyUnit") then
				fxName = "Interact_LootUnit"
			else
				fxTarget = GetObjMaterial(containerObj:GetPos(), containerObj) or target
			end
		end
		PlayFX(fxName, "start", self, fxTarget)
		canOpen = true
		if action_id == "Interact_LootContainer" then
			NetUpdateHash("Unit_InteractWith_PreOpen")
			if not target:Open(self) then
				canOpen = false
			end
			NetUpdateHash("Unit_InteractWith_PostOpen", canOpen)
		end
		NetUpdateHash("Unit_InteractWith4", canOpen)
		if canOpen then
			self:SetRandomAnim(self:GetIdleBaseAnim())
			self:Face(target, 200)
			Sleep(200)
		end
	end
	if not target_restore_behavior then
		target:BeginInteraction(self)
	end

	target:LogInteraction(self, action_id, "start")
	PlayFX("Interact", "start", IsKindOf(target, "CustomInteractable") and target.Visuals or target, target)
	
	if action_id == "Interact_UnitCustomInteraction" then
		SetCombatActionState(self, "PostAction")
		self:SetRandomAnim(self:GetIdleBaseAnim())
		self:Face(target, 200)
		if not target_restore_behavior then
			target:Face(self, 2000)
		end
		Sleep(200)
		self:PushDestructor(function(self)
			if target.spawner.ExecuteInteractionEffectsSequentially then
				ExecuteSequentialEffects(target.spawner.InteractionEffects, "CustomInteractable", table.imap({self}, "handle"), target.handle)
			else
				ExecuteEffectList(target.spawner.InteractionEffects, self, { target_units = { self, target }, interactable = target })
			end
		end)
		self:PopAndCallDestructor()
	elseif action_id == "Interact_CustomInteractable" then
		--PlayFX is triggered inside CustomInteractable:Execute()
		self:PushDestructor(function(self)
			-- the call below may result in execution various Effects, which are executed in a pcall
			-- when this happens and the actor (self) dies as a result, SetCommand("Die") will attempt to 
			--		delete the current thread and fire an assert as a result
			-- to avoid this, we make the call in a destructor to make sure the pcall finishes before the thread is deleted
			target:Execute({self}, {target = target})
		end)
		self:PopAndCallDestructor()
	else
		if not looting then
			-- looting already PlayFX-ed above
			PlayFX(action_id, "start", self, target)
		end
		if action_id == "Interact_DoorOpen" then
			local err = target:InteractDoor(self, "open")
			
			-- Locked doors (failed to open) will refund ap cost to align
			-- behavior with an edge case in Unit:CombatGoto (ok:Boyan)
			if err == "failed" then
				self:GainAP(action_cost)
			end
		elseif action_id == "Interact_DoorClose" then
			target:InteractDoor(self, "closed")
		elseif action_id == "Interact_WindowBreak" then
			target:InteractWindow(self, "broken")
		elseif action_id == "Interact_Banter" then
			SetCombatActionState(self, "PostAction")
			self:SetRandomAnim(self:GetIdleBaseAnim())
			self:Face(target, 200)
			Sleep(200)
			if target_restore_behavior then
				target:PlayInteractionBanter("no rotation")
			else
				target.dont_clear_queue = true
				target:SetCommand("PlayInteractionBanter")
			end
		elseif action_id == "Interact_Talk" then
			self:SetRandomAnim(self:GetIdleBaseAnim())
			self:Face(target, 200)
			Sleep(200)
			local conversation = FindEnabledConversation(target)
			if conversation then
				OpenConversationDialog(self, conversation, false, "interaction", target)
				WaitMsg("CloseConversationDialog")
			end
			if IsValidTarget(target) then -- target may have been despawned or killed by the conversation (e.g. switching sides)
				if not target_restore_behavior then
					target:SetCommand("Idle")
				end
			end
		elseif action_id == "Interact_Disarm" then
			self:Face(target, 200)
			interactionLogSpecifier = target:AttemptDisarm(self)
			if interactionLogSpecifier and interactionLogSpecifier == "success" then
				PlayVoiceResponse(self, "MineDisarmed")
			end
		elseif looting then
			if canOpen then
				PlayResponseOpenContainer(self, target)
				SetCombatActionState(self, "PostAction")
				
				local inventoryHash = GetInventoryHash(target.Inventory)
				local local_control = self:IsLocalPlayerControlled()
				if local_control then
					OpenInventory(self, target)
				end
				
				SetCombatActionState(self, nil) --end this combat action in order for next actions to go through, such as moving itmems in inv.
				if netInGame then
					WaitMsg(inventoryCloseIdToMsg[self.ControlledBy])
				else
					WaitMsg("CloseInventorySubDialog")
				end
				
				local inventoryHashAfterLoot = GetInventoryHash(target.Inventory)
				if inventoryHash ~= inventoryHashAfterLoot then
					interactionLogSpecifier = "looted"
				end
			end
		elseif action_id == "LockImpossible" or action_id == "NoToolsLocked" or action_id == "NoToolsBlocked" then
			target:PlayCannotOpenFX(self)
		elseif action_id == "Interact_Exit" then
			target:UnitLeaveSector(self)
		end
	end

	self:PopAndCallDestructor()
	self:PopAndCallDestructor()

	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCommonUnitControl") then dlg:UpdateInteractablesHighlight(false, "force") end
end

function Unit:PlayInteractionBanter(no_rotation)
	--unit points to the one doing the interaction
	local unitList = { self }
	local filterContext = self.last_played_banter_id and { filter_if_other = self.last_played_banter_id } or false
	local randomBanterGroup = self:GetRandomBanterGroup(filterContext)
	
	if not next(randomBanterGroup) then 
		CombatLog("debug", T{Untranslated("No available banters for <unit>. Please check the actor name."), unit = self:GetDisplayName()})
		return 
	end
	
	local angle_before_interaction = self.angle_before_interaction
	self.angle_before_interaction = false
	
	EndAllBanter()
	
	if self.sequential_banter then
		for i, bant in ipairs(randomBanterGroup) do
			PlayAndWaitBanter(bant, unitList, self)
		end
	else
		local idx = self:Random(#randomBanterGroup) + 1
		local banter = randomBanterGroup[idx]
		self.last_played_banter_id = banter
		PlayAndWaitBanter(banter, unitList, self)
	end
	
	if not no_rotation and angle_before_interaction then
		self:SetOrientationAngle(angle_before_interaction, face_duration)
		Sleep(face_duration)
	end
end

local get_banters_unit_list = {}

function Unit:GetAllBanters(findFirst, filterContext)
	local unitList = get_banters_unit_list
	unitList[1] = self
	local allBanterGroups, list_unplayed

	local marker = self.zone or self.spawner
	if marker then
		--GET ALL BANTER GROUPS FROM THE UNIT'S MARKER
		for i, group in ipairs(marker.BanterGroups) do
			local availableBanters, _, unplayed = FilterAvailableBanters(Presets.BanterDef[group], filterContext, unitList, false, findFirst)
			if availableBanters then
				if findFirst then return true end
				allBanterGroups = allBanterGroups or {}
				if unplayed and not list_unplayed then
					list_unplayed = true
					table.iclear(allBanterGroups)
				end
				if unplayed or not list_unplayed then
					table.insert(allBanterGroups, {group = group, banters = availableBanters})
				end
			end
		end

		--GET ALL SPECIFIC BANTERS FROM THE UNIT'S MARKER INTO ONE GROUP
		if next(marker.SpecificBanters) then
			local availableBanters, _, unplayed = FilterAvailableBanters(marker.SpecificBanters, filterContext, unitList, false, findFirst)
			if availableBanters then
				if findFirst then return true end
				allBanterGroups = allBanterGroups or {}
				if unplayed and not list_unplayed then
					list_unplayed = true
					table.iclear(allBanterGroups)
				end
				if unplayed or not list_unplayed then
					table.insert(allBanterGroups, {group = "MarkerSpecificBanters", banters = availableBanters})
				end
			end
		end
	end

	--GET ALL BANTERS FROM unit.banters (might come from squads entering sector or other places)
	if next(self.banters) then
		local availableBanters, _, unplayed = FilterAvailableBanters(self.banters, filterContext, unitList, false, findFirst)
		if availableBanters then
			if findFirst then return true end
			allBanterGroups = allBanterGroups or {}
			if unplayed and not list_unplayed then
				list_unplayed = true
				table.iclear(allBanterGroups)
			end
			if unplayed or not list_unplayed then
				table.insert(allBanterGroups, {group = "UnitAdditionalBanters", banters = availableBanters})
			end
		end
	end

	return allBanterGroups
end

function Unit:GetRandomBanterGroup(ctx)
	local allBanterGroups = self:GetAllBanters(false, ctx)
	if allBanterGroups then
		local idx = self:Random(#allBanterGroups) + 1
		local randomBanterGroup = allBanterGroups[idx]
		if randomBanterGroup then
			return randomBanterGroup.banters
		end
	end
	return empty_table
end

function Unit:GetInteractableBadgeSpot()
	if self:IsDead() then
		return "Torso"
	end
	return "Headstatic"
end

local lockpickableFxActions = {
	Lockpick = "Lockpick",
	Break = "BreakLock",
	Cut = "Cut",
}

function Unit:Lockpick(action_id, cost_ap, pos, goto_ap, target)
	local can_interact = self:CanInteractWith(target, action_id, true)
	if not can_interact then
		if g_Combat then
			self:GainAP(cost_ap)
			CombatActionInterruped(self)
		end
		return
	end

	local action = CombatActions[action_id]

	-- approach target
	local action_cost = g_Combat and cost_ap - goto_ap or 0
	local can_interact

	if g_Combat then
		self:PushDestructor(function(self)
			self:GainAP(action_cost)
		end)
		PlayFX("InteractGoto", "start", self, target)
		can_interact = self:CombatGoto(action_id, goto_ap, pos)
		self:PopDestructor()
	else
		local positions, angle, preferred = target:GetInteractionPos(self)
		can_interact = self:CloseEnoughToInteract(positions, target)
		if not can_interact and preferred then
			PlayFX("InteractGoto", "start", self, target)
			NetUpdateHash("LockpickGotoPreferred", target, preferred)
			can_interact = self:GotoSlab(preferred)
		end
		if not can_interact and positions then
			PlayFX("InteractGoto", "start", self, target)
			NetUpdateHash("LockpickGoto", target, positions)
			can_interact = self:GotoSlab(positions)
		end
	end
	can_interact = can_interact and self:CanInteractWith(target, action_id, true)
	if not can_interact then
		if g_Combat then
			self:GainAP(action_cost)
			CombatActionInterruped(self)
		end
		return
	end

	lInteractionLoadingBar(self, action_id, target)

	--execute
	local fx_action = lockpickableFxActions[action_id]
	target:RegisterInteractingUnit(self)
	self:PushDestructor(function(self)
		if fx_action then
			target:PlayLockpickableFX(fx_action, "end")
		end
		if not IsValid(target) then return end
		target:UnregisterInteractingUnit(self)
		target:EndInteraction(self)
	end)
	if fx_action then
		target:PlayLockpickableFX(fx_action, "start")
	end
	target:BeginInteraction(self)

	target:LogInteraction(self, action_id, "start")
	PlayFX("Interact", "start", self, target)
	
	self:Face(target, 200)
	Sleep(200)
	
	local result
	if action_id == "Lockpick" then
		result = target:InteractLockpick(self)
	elseif action_id == "Break" then
		result = target:InteractBreak(self)
	elseif action_id == "Cut" then
		target:InteractCut(self)
	end
	
	target:LogInteraction(self, action_id, "end", result)
	
	if result == "success" and IsKindOf(target, "Door") then
		Msg("DoorUnlocked", target, self)
	end
	
	-- The container is now openable
	if target.lockpickState == "closed" then
		local combat_action = target:GetInteractionCombatAction()
		if combat_action then
			combat_action:Execute({ self }, { target = target })
		end
	end
	
	self:PopAndCallDestructor()
	
	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCommonUnitControl") then dlg:UpdateInteractablesHighlight() end
end

-- overheard conversations

function Unit:OverheardConversationHeadTo(point, face_point, marker)
	self:PushDestructor(function(self)
		if self.command ~= "OverheardConversation" and self.command ~= "OverheardConversationHeadTo" then
			if g_debugOverheardMarker then print("Unit got interrupted en route to marker.", self.command) end
			marker:SetCommand("StopRunning")
		end
	end)
	self:ChangeStance(nil, nil, "Standing")
	if point ~= self:GetPos() and self:GotoSlab(point) ~= pfFinished then
		self:PopAndCallDestructor()
	end
	if self.carry_flare then
		self:RoamDropFlare()
	end

	Msg("OverheardConversationPointReached", self)
	self:SetRandomAnim(self:GetIdleBaseAnim())
	Sleep(1000)
	self:Face(face_point, 300)
	
	-- Wait for the other units to get here.
	self:OverheardConversationWaiting()
end

function Unit:OverheardConversationWaiting()
	while true do
		Sleep(1000)
		if g_Combat then
			self:SetCommand("Idle")
			break
		end
	end
end

function Unit:OverheardConversation(face_point, marker)
	self:PushDestructor(function(self)
		if marker.playing_banter then
			if g_debugOverheardMarker then print("Unit got interrupted during overheard banter.", self.command) end
			marker:SetCommand("StopRunning")
		end
	end)
	
	self:SetRandomAnim(self:GetIdleBaseAnim())
	if face_point then
		self:Face(face_point, 300)
	end

	-- Wait for banter to finish.
	self:OverheardConversationWaiting()
end
