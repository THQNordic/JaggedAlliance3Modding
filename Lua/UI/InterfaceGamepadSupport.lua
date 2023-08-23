MapVar("g_GamepadTarget", false)

-- Works alongside the current IModeCommonUnitControl to provide gamepad support
DefineClass.GamepadUnitControl = {
	__parents = { "InterfaceModeDialog" },
	gamepad_thread = false,
	world_cursor = false,
	world_cursor_visible = false,

	move_button_down_time = false,
	last_potential_target = false,
	potential_interactable_gamepad_resolved = false
}

DefineClass.GamepadWorldCursor = {
	__parents = { "SpawnFXObject" },
	flags = { gofAlwaysRenderable = true },
}

function GamepadWorldCursor:Attach(obj)
	CObject.Attach(self, obj)
	obj:AddComponentFlags(const.cofComponentExtraTransform)
	obj:SetSpecialOrientation(const.soGamepadCursor)
	obj:SetGameFlags(const.gofAlwaysRenderable)
end

function GamepadUnitControl:InitializeWorldCursor()
	assert(not self.world_cursor)
	if self.world_cursor then return end

	local wObj = PlaceObject("GamepadWorldCursor")--PlaceSingleTileStaticContourMesh(RGB(255, 255,255), nil, true)
	wObj:SetPos(GetCursorPos())
	self.world_cursor = wObj
	
	local cursorImageContainer = self.idGamepadCenterAnchor
	if not cursorImageContainer then
		cursorImageContainer = XTemplateSpawn("XWindow", self)
		cursorImageContainer:SetId("idGamepadCenterAnchor")
		cursorImageContainer:SetZOrder(-100)
		cursorImageContainer:SetHAlign("center")
		cursorImageContainer:SetVAlign("center")
		cursorImageContainer:SetLayoutMethod("VList")
		cursorImageContainer:SetMinWidth(80)
		cursorImageContainer:SetMaxWidth(80)
		if self.window_state == "open" then cursorImageContainer:Open() end
	end

	local cursorAttachedUI = XTemplateSpawn("XPopup", self)
	cursorAttachedUI:SetId("idGamepadAttached")
	cursorAttachedUI:SetMargins(box(10, 0, 0, 0))
	cursorAttachedUI:SetAnchorType("right")
	cursorImageContainer.OnLayoutComplete = function()
		cursorAttachedUI:SetAnchor(cursorImageContainer.box)
	end
	cursorImageContainer:InvalidateLayout()
	cursorAttachedUI:SetBackground(RGBA(0, 0, 0, 0))
	cursorAttachedUI:SetBorderWidth(0)
	--cursorAttachedUI:AddDynamicPosModifier({id = "attached_ui", target = wObj})
	if self.window_state == "open" then cursorAttachedUI:Open() end
end

function GamepadUnitControl:ClearWorldCursor()
	if not self.world_cursor then return end

	DoneObject(self.world_cursor)
	self.world_cursor = false
	
	if self.idGamepadAttached then
		self.idGamepadAttached:Close()
	end
end

function OnMsg.GamepadUIStyleChanged()
	local igi = GetInGameInterfaceModeDlg()
	if not IsKindOf(igi, "GamepadUnitControl") then return end
	if GetUIStyleGamepad() then
		igi:ResumeGamepadThread()
	else
		igi:StopGamepadThread()
	end
end

function GamepadUnitControl:StopGamepadThread()
	if IsValidThread(self.gamepad_thread) then DeleteThread(self.gamepad_thread) end
	
	self:ClearWorldCursor()
	
	g_GamepadTarget = false
	self:SpawnHelperTexts()
	hr.CameraTacMoveSpeed = CameraTacMoveSpeed
	UnlockCamera("ActionBarGamepad")
	self:GamepadSelectionSetTarget(false)
	self:FocusActionBar(false)
	
	ObjModified("combat_bar")
	ObjModified("combat_bar_enemies")
	UnforceHideMouseCursor("GamepadActive")
	ObjModified(APIndicator)
	table.restore(hr, "gamepad-ui", true)
end

function GamepadUnitControl:ResumeGamepadThread(start)
	if IsValidThread(self.gamepad_thread) then return end
	self.gamepad_thread = CreateRealTimeThread(function()
		while self.window_state ~= "destroying" do
			self:ThreadProc()
			WaitNextFrame()
		end
	end)
	
	self:InitializeWorldCursor()

	ObjModified("combat_bar")
	if not Platform.trailer and not start and not gv_SatelliteView then OpenCombatLog() end
	ForceHideMouseCursor("GamepadActive")
	ObjModified(APIndicator)
	table.change(hr, "gamepad-ui", {CameraTacMouseEdgeScrolling = false, GamepadPreciseSelectionPos = 1})
	self.show_world_ui = true
	g_RolloverShowMoreInfo = true
end

function GamepadUnitControl:Open()
	self:GamepadSelectionSetTarget(false)

	-- Move camera to the selected unit.
	local unit = Selection and Selection[1]
	local pos, lookat, t, zoom, props
	if unit then
		pos = unit:GetPos()
	else
		pos = point30
	end
	
	InterfaceModeDialog.Open(self)
	if not GetUIStyleGamepad() then return end
	self:ResumeGamepadThread("start")
end

local easingCubic = GetEasingIndex("Cubic out")
function GamepadUnitControl:ThreadProc()
	local combatAttackMode = IsKindOf(self, "IModeCombatAttackBase")
	local hideGamePadCursor = IsSetpiecePlaying() or
									gv_SatelliteView or
									#Selection == 0 or
									(SelectedObj and not SelectedObj:CanBeControlled()) or
									CurrentActionCamera or
									(combatAttackMode and self.crosshair) or
									(GetDialog("PhotoMode") and GetDialog("PhotoMode").isWorldUIHidden)

	self.world_cursor:SetVisible(not hideGamePadCursor)
	self.world_cursor_visible = not hideGamePadCursor
	if not self.visible then return end
	
	local cursorPos = GetCursorPos(self.movement_mode and "walkable")
	local passPos = GetPassSlab(cursorPos)
	
	--self.world_cursor:SetPos(cursorPos) --done via special orientation
	
	if self.UpdateTarget then
		self:UpdateTarget(cursorPos)
	end

	local combatMovementMode = false
	local combatMovementIgi = IsKindOf(self, "IModeCombatMovement")
	if combatMovementIgi then
		self:UpdateLinesOfFire()
		combatMovementMode = g_Combat and self.movement_mode
	end

	-- Show/Hide tip
	local target = self.potential_target
	local interactable = self.potential_interactable
	local lastPotentialTarget = self.last_potential_target
	local lastPotentialInteractable = self.last_potential_interactable
	local potentialTargetIsSelectedUnit = false
	if lastPotentialTarget then
		potentialTargetIsSelectedUnit = table.find(Selection, lastPotentialTarget)
	end
	
	if not not lastPotentialTarget ~= not not target then
		if target then
			PlayFX("GamepadCursorOverUnit", "start", self.world_cursor)
		else
			PlayFX("GamepadCursorOverUnit", "end", self.world_cursor)
		end
	end
	
	if not target and not not lastPotentialInteractable ~= not not interactable then
		if interactable then
			PlayFX("GamepadCursorOverInteractable", "start", self.world_cursor)
		else
			PlayFX("GamepadCursorOverInteractable", "end", self.world_cursor)
		end
	end
	
	self.last_potential_target = target
	self.last_potential_interactable = interactable
								
	local hintShown = false

	-- Attack detection
	if not hintShown and combatAttackMode and self.action and self.action.id == "Bandage" then
		self:SpawnHelperTexts("ButtonASmall", T(648304184409, "Bandage"))
		hintShown = true
	elseif not hintShown and combatAttackMode then
		self:SpawnHelperTexts("ButtonASmall", T(516305772518, "Attack"))
		hintShown = true
	end
	
	local cameraSpeed = GamepadCameraTacMoveSpeed
	local snapMaxDist = const.SlabSizeX
	local speedCap = 150
	local interactableAroundCursor = self.potential_interactable or self.potential_target
	if self.potential_interactable_gamepad_resolved then
		local obj = self.potential_interactable_gamepad_resolved[interactableAroundCursor]
		if obj then
			interactableAroundCursor = obj
		end
	end
	
	if interactableAroundCursor then
		local distToIt = cursorPos:Dist(interactableAroundCursor)
		distToIt = Min(distToIt, snapMaxDist)
		cameraSpeed = Lerp(speedCap, 500, EaseCoeff(easingCubic, distToIt, snapMaxDist), snapMaxDist)
	end
	
	if Selection[1] and not hintShown then	
		local attackable = IsKindOf(target, "Unit") and target.team:IsEnemySide(Selection[1].team) and not target:IsDead()
		if attackable then
			self:SpawnHelperTexts("ButtonASmall", T(516305772518, "Attack"), target)
			hintShown = true
		end
	end
	
	-- Select/Interact/Move
	if not hintShown then
		if lastPotentialTarget and lastPotentialTarget:CanBeControlled() and not potentialTargetIsSelectedUnit then
			self:SpawnHelperTexts("ButtonASmall", T(775961618506, "Select"), lastPotentialTarget)
			if not g_CursorContour then
				--HandleMovementTileContour(false, lastPotentialTarget:GetPos(), "CombatAttack")
			end
			ContourPolylineSetColor(lastPotentialTarget, "GamepadCursor")
			hintShown = true
		elseif interactable then
			local action = interactable:GetInteractionCombatAction()
			if action then
				local closest_unit = ChooseClosestObject(Selection, interactable)
				self:SpawnHelperTexts("ButtonASmall", T{action:GetActionDisplayName(closest_unit), target = interactable, unit = closest_unit})
				hintShown = true
			end
		elseif gv_Deployment then
			self:SpawnHelperTexts({"ButtonASmall"},{T(602300303403, "Deploy merc")})
			hintShown = true
		elseif passPos and #Selection > 0 and not combatAttackMode then
			if combatMovementIgi and not combatMovementMode then
				local combatPath = Selection[1] and GetCombatPath(Selection[1])
				if combatPath and table.count(combatPath.destinations) > 1 then
					self:SpawnHelperTexts("ButtonASmall", T(928032104770, "Movement Mode"))
					hintShown = true
				end
			elseif combatMovementIgi and combatMovementMode then
				self:SpawnHelperTexts({"ButtonASmall"}, {T(463014525696, "Move")})				
				hintShown = true
			else
				if Selection and #Selection > 1 then
					self:SpawnHelperTexts({"ButtonASmall"}, {T(463014525696, "Move")})				
				else
					self:SpawnHelperTexts({"ButtonASmall", "ButtonASmallHold"}, {T(463014525696, "Move"),T(657923169702, "Move squad")})				
				end					
				hintShown = true
			end
		end
	end
	
	if not cameraTac.IsActive() then
		hintShown = false
		cameraSpeed = GamepadCameraTacMoveSpeed
	end
	
	-- Hide if focus is in another ui like the action bar
	if terminal.desktop.keyboard_focus ~= self then
		hintShown = false
	end
	
	if hideGamePadCursor then
		hintShown = false
	end

	if not hintShown then
		self:SpawnHelperTexts()
	end
	hr.CameraTacMoveSpeed = cameraSpeed
end

function CalculateGamepadCursorSize(pos, lookat, img)
	local dz = abs(pos:z() - lookat:z())
	local d = pos:Dist(lookat)
	local aspect = MulDivRound(dz, 1000, d)	-- aspect is cos function of camera tilt angle
	
	return MulDivRound(img.parent.box:sizex(), aspect*100, 100*GetUIScale())
end

function GamepadUnitControl:SpawnHelperTexts(buttons, texts, target)
	local helpText = self.idGamepadAttached and self.idGamepadAttached.idHelpText

	if not buttons then
		if helpText then
			helpText:Close()
		end
		return
	end

	if not helpText then
		helpText = XTemplateSpawn("XText", self.idGamepadAttached)
		helpText:SetId("idHelpText")
		helpText:Open()
		helpText.Clip = false
		helpText.UseClip = false
		helpText.Translate = true
		helpText.HAlign = "left"
		helpText.VAlign = "top"
		helpText:SetTextVAlign("center")
	end

	if type(buttons) ~= "table" then buttons = { buttons } end
	if IsT(texts) then texts = { texts } end 

	local textConstruct = T{""}
	for i, button in ipairs(buttons) do		
		if i ~= 1 then
			textConstruct = textConstruct .. T(420993559859, "<newline>")
		end
		textConstruct = textConstruct .. TLookupTag("<"..button..">") .. " " .. texts[i]
	end

	local apIndicator = self:ResolveId("idApIndicator")
	local apText = false
	if apIndicator and apIndicator.text_wnd then
		apText = apIndicator.text_wnd.Text
		textConstruct = textConstruct .. "\n" .. apText
		
		local dangerIcon = apIndicator.danger_icon
		if dangerIcon and dangerIcon.danger then
			textConstruct = T(684252334678, "<image UI/Hud/attack_of_opportunity 2000><newline>") .. textConstruct
		end
	end

	helpText:SetText(textConstruct)
	helpText:SetTextStyle("GamepadHint")
end

function GamepadUnitControl:Done()
	HandleMovementTileContour()
	if IsValidThread(self.gamepad_thread) then
		DeleteThread(self.gamepad_thread)
	end
	self:ClearWorldCursor()
	SetAPIndicator(false, "unreachable")
	UpdateAllBadges()
end

function GamepadUnitControl:OnShortcut(button, source, controller_id)
	Msg("UserInputMade")
	return InterfaceModeDialog.OnShortcut(self, button, source, controller_id)
end

-- Check manually due to SelectFirstValidItem/SelectLastValidItem
-- checking enabled in addition to CanBeSelected
function SelectFirstSelectableItemInList(list, direction)
	local itemToSelect = direction == "right" and 1 or #list
	if itemToSelect and list[itemToSelect] then
		local idx = list:NextSelectableItem(itemToSelect, 0, direction == "right" and 1 or -1)
		if idx then
			list:SetSelection(idx)
		end
	end
end

function GamepadUnitControl:FocusActionBar(direction)
	if g_GamepadTarget then return end
	
	local bottomBar = self:ResolveId("idBottomBar")
	local combatActionsBar = self:ResolveId("idCombatActionsContainer")
	
	if not direction then
		ApplyCombatBarHidingAnimation(bottomBar, false)
		--UnlockCamera("ActionBarGamepad")

		if combatActionsBar then
			combatActionsBar:SetSelection(false)
		end
		if self.window_state ~= "destroying" then self:SetFocus() end
		return
	end

	if combatActionsBar then
		combatActionsBar:SetFocus()
		
		local currentAction = self.action
		if currentAction then
			local buttonIdx = table.find(combatActionsBar, "Id", currentAction.id)
			combatActionsBar:SetSelection(buttonIdx)
			direction = false -- If already selected then dont move selection on initial focus
		end
		
		if direction then
			SelectFirstSelectableItemInList(combatActionsBar, direction)
		end

		if Selection then SnapCameraToObj(Selection[1], true) end
		
		ApplyCombatBarHidingAnimation(bottomBar, true)
		--LockCamera("ActionBarGamepad")
	end
end

function GamepadUnitControl:ActionBarUnfocusCheck()
	-- Delayed call
	CreateRealTimeThread(function()
		local focus = self.desktop.keyboard_focus
		if not focus then return end
	
		local stanceButton = self:ResolveId("idStanceButton")
		local actionButtonsBar = self:ResolveId("idActionButtonsBar") 
		if not focus:IsWithin(actionButtonsBar) and not focus:IsWithin(stanceButton) then
			self:GamepadSelectionSetTarget(false)
		end
	end)
end

function GamepadUnitControl:GamepadSelectionSetTarget(target)
	local bottomBar = self:ResolveId("idBottomBar")
	local combatActionsBar = self:ResolveId("idCombatActionsContainer")
	local signatureBar = self:ResolveId("idSignatureAbilitiesContainer")
	local hideButton = self:ResolveId("idHideButton")
	local stanceButton = self:ResolveId("idStanceButton")
	stanceButton = stanceButton and stanceButton:ResolveId("idStanceButtons")

	if not GetUIStyleGamepad() then
		target = false
	end

	if not target then
		g_GamepadTarget = false
		ObjModified("combat_bar_enemies")
		
		ApplyCombatBarHidingAnimation(bottomBar, false)
		UnlockCamera("ActionBarGamepad")

		if combatActionsBar then
			combatActionsBar:SetSelection(false)
			combatActionsBar:ShowSelected()
		end
		
		if signatureBar then
			signatureBar:SetSelection(false)
			signatureBar:ShowSelected()
		end
		
		if hideButton then
			hideButton:SetSelected(false)
		end
		
		if stanceButton then
			stanceButton:SetSelection(false)
		end
		
		if self.window_state ~= "destroying" then
			if self.desktop.keyboard_focus and self.desktop.keyboard_focus:IsWithin(bottomBar) then
				self:SetFocus()
			end
		end
		
		if cameraTac.GetIsInOverview() then
			local deployMenu = self:ResolveId("idDeployMenu")
			if deployMenu then
				deployMenu.idList:SetFocus(true)
			end
		end
		
		return
	end

	local selUnit = Selection[1]
	local allTargets = GetTargetsToShowAboveActionBarSorted(selUnit, self)
	if #allTargets == 0 then
		self:GamepadSelectionSetTarget(false)
		return
	end
	
	if not g_GamepadTarget then
		target = "first"
	end
	
	if target == "first" then
		target = allTargets[1]
	elseif target == "prev" then
		local tIdx = table.find(allTargets, g_GamepadTarget)
		if not tIdx then
			target = allTargets[#allTargets]
		else
			tIdx = tIdx - 1
			if tIdx == 0 then
				tIdx = #allTargets
			end
			target = allTargets[tIdx]
		end
	elseif target == "next" then
		local tIdx = table.find(allTargets, g_GamepadTarget)
		if not tIdx then
			target = allTargets[#allTargets]
		else
			tIdx = tIdx + 1
			if tIdx == #allTargets + 1 then
				tIdx = 1
			end
			target = allTargets[tIdx]
		end
	end
	
	if bottomBar then
		ApplyCombatBarHidingAnimation(bottomBar, true)
		LockCamera("ActionBarGamepad")
	end
	
	if not g_GamepadTarget and target and combatActionsBar then
		combatActionsBar:SetFocus()
		local firstSel = combatActionsBar:GetFirstValidItemIdx()
		combatActionsBar:SetSelection(firstSel)
	end
	
	if target then
		SnapCameraToObj(target, true)
	end
	
	g_GamepadTarget = target or false
	ObjModified("combat_bar_enemies")
end

function DetermineUnitCombatActionButtonX()
	local priorityList = {
		CombatActions.Hide,
		CombatActions.Reveal,
	}
	for i, c in ipairs(priorityList) do
		if c:GetVisibility(Selection) == "enabled" then
			return c
		end
	end
end

function GetActiveGamepadState()
	for i = 0, XInput.MaxControllers() - 1 do
		if XInput.IsControllerConnected(i) then
			return XInput.CurrentState[i], i
		end
	end
end

-- Overriden from common to allow checking ButtonPressTime in the XEvent call
-- and support suppressing
function XEvent(action, nCtrlId, button, ...)
	if action == "OnXButtonDown" then
		local repeat_time = XInput.InitialRepeatButtonTimeSpecific[button] or XInput.InitialRepeatButtonTime
		local real_time = RealTime()
		XInput.LastPressTime = real_time
		XInput.ButtonPressTime[nCtrlId][button] = real_time + repeat_time
		XInput.InitialButtonPressTime[nCtrlId][button] = real_time
	end

	if not terminal.desktop.inactive then 
		if action == "OnXNewPacket" then
			procall(terminal.XEvent, action, nil, nCtrlId, ...)
		else
			procall(terminal.XEvent, action, button, nCtrlId, ...)
		end
	end

	-- repeat support
	if action == "OnXButtonUp" then
		XInput.ButtonPressTime[nCtrlId][button] = nil
		XInput.InitialButtonPressTime[nCtrlId][button] = nil
	end
end

DefineConstInt("Default", "GamePadButtonHoldTime", 200)

function IsXInputHeld(button, time)
	local time = time or const.GamePadButtonHoldTime
	local _, gamepadId = GetActiveGamepadState()
	local pressTime = XInput.InitialButtonPressTime[gamepadId]
	pressTime = pressTime and pressTime[button]
	local timeWasPressed = pressTime and RealTime() - pressTime

	return timeWasPressed and timeWasPressed >= time
end

function XInputSuppressButtonUpHoldCheck(button)
	local _, gamepadId = GetActiveGamepadState()
	local pressTime = XInput.InitialButtonPressTime[gamepadId]
	if pressTime and pressTime[button] then
		pressTime[button] = nil
	end
	
	pressTime = XInput.ButtonPressTime[gamepadId]
	if pressTime and pressTime[button] then
		pressTime[button] = nil
	end
end

MapVar("GamepadStaggeredFloorChangeThread", false)

GamepadFloorChangeStaggerTime = 500

function GamepadStaggeredFloorUp()
	if IsValidThread(GamepadStaggeredFloorChangeThread) then return end
	
	GamepadStaggeredFloorChangeThread = CreateRealTimeThread(function()
		while true do
			if camera.IsLocked() then return end
			cameraTac.SetFloor(
				cameraTac:GetFloor() + 1,
				hr.CameraTacInterpolatedMovementTime * 10,
				hr.CameraTacInterpolatedVerticalMovementTime * 10
			)
			Sleep(GamepadFloorChangeStaggerTime)
		end
	end)
end

function GamepadStaggeredFloorDown()
	if IsValidThread(GamepadStaggeredFloorChangeThread) then return end
	
	GamepadStaggeredFloorChangeThread = CreateRealTimeThread(function()
		while true do
			if camera.IsLocked() then return end
			cameraTac.SetFloor(
				cameraTac:GetFloor() - 1,
				hr.CameraTacInterpolatedMovementTime * 10,
				hr.CameraTacInterpolatedVerticalMovementTime * 10
			)
			Sleep(GamepadFloorChangeStaggerTime)
		end
	end)
end

function GamepadStaggerFloorChangeEnd()
	if IsValidThread(GamepadStaggeredFloorChangeThread) then DeleteThread(GamepadStaggeredFloorChangeThread) end
end

function GamepadUnitControl:ShowFloorDisplay()
	local dlg
	if IsValidThread(self.gamepad_thread) then
		local floorDisplayDlg = self.idGamepadAttached.idFloorHintCursor
		if floorDisplayDlg then
			floorDisplayDlg:ResetHiding()
			return
		end

		dlg = XTemplateSpawn("FloorDisplay", self.idGamepadAttached)
		dlg:Open()
	else
		local floorDisplayDlg = self.idFloorHintCursor
		if floorDisplayDlg then
			floorDisplayDlg:ResetHiding()
			return
		end

		dlg = XTemplateSpawn("FloorDisplay", self)
		dlg:AddDynamicPosModifier({id = "attached_ui", target = "mouse"})
		dlg:Open()
	end
	dlg:ResetHiding()
	dlg:SetMargins(box(20, 0, 0, 0))
end

function GamepadFocusStanceList()
	local igi = GetInGameInterfaceModeDlg()
	local stanceButton = igi and igi.idStanceButton
	local stanceList = stanceButton and stanceButton.idStanceButtons
	if not stanceList then return end
	
	local unit = Selection and Selection[1]
	if not unit then return end

	local currentStanceId = "Stance" .. unit.stance
	local currentStanceAction = CombatActions[currentStanceId]
	if not currentStanceAction then return end
	
	local currentStanceId = -1
	for i, stanceButton in ipairs(stanceList) do
		if stanceButton.context and stanceButton.context.action == currentStanceAction then
			currentStanceId = i
			break
		end
	end
	if currentStanceId == -1 then return end
	
	stanceList:SetFocus()
	stanceList:SetSelection(currentStanceId)
	
	local bottomBar = igi:ResolveId("idBottomBar")
	ApplyCombatBarHidingAnimation(bottomBar, true)
	--LockCamera("ActionBarGamepad")
end

local lPingCooldownMax = 5 -- No more than this many pings in the last this many seconds.

if FirstLoad then
g_RecentPings = false
PingCooldownThread = false
end

function NetSyncEvents.PlayerPing(pos, playerId)
	PlayFX(playerId == netUniqueId and "PlayerPing" or "Player2Ping", "start", "Unit", false, pos)

	local badgeObject = PlaceObject("Object")
	badgeObject:SetPos(pos)
	CreateBadgeFromPreset("PingBadge", badgeObject)
	CreateMapRealTimeThread(function()
		Sleep(1500)
		if IsValid(badgeObject) then
			DoneObject(badgeObject)
		end
	end)
end

function PlayerPing()
	if g_RecentPings and g_RecentPings > lPingCooldownMax then return end
	if not netInGame then return end
	NetSyncEvent("PlayerPing", GetCursorPos(), netUniqueId)
	
	g_RecentPings = (g_RecentPings or 0) + 1
	if not IsValidThread(PingCooldownThread) then
		PingCooldownThread = CreateRealTimeThread(function()
			while g_RecentPings > 0 do
				Sleep(1000)
				g_RecentPings = g_RecentPings - 1
			end
		end)
	end
end