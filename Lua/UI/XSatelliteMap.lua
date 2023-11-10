if FirstLoad then
g_SatelliteUI = false
end

DefineClass.XSatelliteDialog = { -- Parent of map and all UI in PDASatellite
	__parents = { "XDialog" },
}

local function lKeyboardFocusedFuzzy(self)
	if self.desktop.inactive then return false end

	local focus = self.desktop.keyboard_focus
	if not focus then return false end
	return focus == self or self:IsWithin(focus)
end

function TFormat.dayNightIcon()
	local timeOfDay = CalculateTimeOfDay(Game.CampaignTime)
	if timeOfDay == "Night" then
		return "<image UI/PDA/moon 2000>"
	else
		return "<image UI/PDA/sun 2000>"
	end
end

function XSatelliteDialog:Open()
	XDialog.Open(self)
	
	-- Initial squad selection. Needs to be ran after everything in PDA has initialized.
	local selSquad = g_SatelliteUI:SelectSquad(false)
	Msg("SatelliteNewSquadSelected", selSquad, false, true)
end

DefineClass.XSatelliteViewMap = {
	__parents = { "XImage", "XMap" },
	HandleMouse = true,
	ChildrenHandleMouse = true,
	ZOrder = 0,
	
	-- satellite settings
	MouseWheelStep = 70,
	max_zoom = 550,
	
	-- read from the current campaign preset
	Image = false,
	map_size = false,
	grid_start = false,
	sector_size = false,
	sector_max_x = 0,
	sector_max_y = 0,
	
	-- sector selection
	last_mouse_down = false,
	click_time = 200,
	
	-- runtime state
	sector_to_wnd = false,
	squad_to_wnd = false,
	shipment_to_wnd = false,
	travel_mode = false,
	selected_squad = false,
	selected_sector = false,
	rollover_sector = false,
	filter_info_mode = false,--toggled from the button on theleft ot the minimap (i), shows all secotrs id
	playable_area = false,
	clamp_box = false,
	translation_change_notWASD = false,
	
	layer_mode = "satellite",
	
	-- UI stuff
	context_menu = false,
	expand_icons_window = false,
	cursor_hint = false,
	mouse_cursor = false,
	
	suppress_visual_updates = false,
	
	-- Effects stuff
	sector_visible_map = false,
	sector_player = false,
	sector_enemy = false,
	sector_neutral = false,
	rollover_sector_fx = false,
	selected_sector_fx = false,
	blinking_sector_fx = false,
	
	-- Caches
	squads_in_shorcuts = false
}

function XSatelliteViewMap:Init()
	local campaign = GetCurrentCampaignPreset()
	self:ValidateAndInitSizes(campaign)
	self:SetImage(campaign.map_file)
	
	self.playable_area = point(campaign.sector_columns * self.sector_size:x(), (campaign.sector_rows - campaign.sector_rowsstart + 1) * self.sector_size:y())
	self.clamp_box = sizebox(self.grid_start, self.playable_area)
end

function XSatelliteViewMap:ValidateAndInitSizes(campaign)
	local gx, gy = campaign.sectors_offset:xy()
	self.grid_start = point(Max(gx, 0), Max(gy, 0))
	
	local sx, sy = campaign.sector_size:xy()
	self.sector_size = point(Max(sx, 50), Max(sy, 50))
	
	local minx, miny =
		campaign.sector_columns * self.sector_size:x() + self.grid_start:x(),
		(campaign.sector_rows - campaign.sector_rowsstart + 1) * self.sector_size:y() + self.grid_start:y()
	local mx, my = campaign.map_size:xy()
	self.map_size = point(Max(mx, minx), Max(my, miny))
end

SatelliteViewMoveTimeInterval = 25
SatelliteViewMoveTimeAmount = 30

function XSatelliteViewMap:Open()
	g_SatelliteUI = self
	Msg("InitSatelliteView")
	gv_SatelliteView = true
	
	assert(IsGameTimeThread() or GetDialog("PDADialogSatelliteEditor")) -- Assure satellite open is sync
	
	XShortcutsSetMode("Satellite")
	SetRenderMode("ui")
	
	self:SetTimeFactor(GetCampaignSpeedXMapFactor())
	self:InitCacheOfShortcutSquads()
	self:GenerateSectorGrid()
	self:GenerateSquadWindows()
	self:GenerateShipmentWindows()
	self:UpdateAllSectorVisuals()
	NetUpdateHash("OpenSatelliteView")
	Msg("OpenSatelliteView")
	
	self.cursor_hint = GetDialog(self).idCursorHintText
	self.cursor_hint:SetVisible(false)
	self.cursor_hint:AddDynamicPosModifier({
		id = "cursor_hint",
		target = "mouse",
		interpolate_clip = false
	})

	-- Camera restore needs to wait for the window to layout.
	self:CreateThread("restore-camera", function()
		--TODO: this causes flicker, maybe show black screen until this is done?
		Sleep(1)

		local selectedSquad = self.selected_squad
		local sectorToShow = selectedSquad and selectedSquad.CurrentSector
		sectorToShow = sectorToShow or gv_CurrentSectorId or GetCurrentCampaignPreset().InitialSector
		SatelliteSetCameraDest(sectorToShow, 0)
	end)
	XMap.Open(self)
	UpdateSatelliteDesaturation()
	
	RecalcRevealedSectors()
	Msg("StartSatelliteGameplay")
	ObjModified("gv_SatelliteView")
	ObjModified("satellite-overlay")
	ObjModified(Game)
	if not GetDialog("Intro") then
		PlayFX("SatelliteOpen")
	end
	
	local dlg = GetDialog(self)
	self:CreateThread("WASD-SatelliteMap", function()
		local interval = SatelliteViewMoveTimeInterval
		local moveAmount = SatelliteViewMoveTimeAmount
		while self.window_state == "open" do
			
			-- Prevent the zooming interpolation and the
			-- WASD interpolation from overlapping
			local movingAlready = false
			if self.translation_change_notWASD then
				local transPos = UIL.GetParam(0)
				local transAtEnd = UIL.GetParam(0, "end")
				movingAlready = transPos ~= transAtEnd
			end
			
			local gamepadState = GetUIStyleGamepad() and GetActiveGamepadState()
			
			if lKeyboardFocusedFuzzy(dlg) and not movingAlready then
				if terminal.IsKeyPressed(const.vkW) or terminal.IsKeyPressed(const.vkUp) then
					self:ScrollMap(0, moveAmount, interval)
				elseif terminal.IsKeyPressed(const.vkS) or terminal.IsKeyPressed(const.vkDown) then
					self:ScrollMap(0, -moveAmount, interval)
				elseif terminal.IsKeyPressed(const.vkA) or terminal.IsKeyPressed(const.vkLeft) then
					self:ScrollMap(moveAmount, 0, interval)
				elseif terminal.IsKeyPressed(const.vkD) or terminal.IsKeyPressed(const.vkRight) then
					self:ScrollMap(-moveAmount, 0, interval)
				end
				self.translation_change_notWASD = false
				
				if gamepadState then
					local stick = GetAccountStorageOptionValue("InvertPDAThumbs") and
									gamepadState.LeftThumb or gamepadState.RightThumb
					if stick ~= point20 and stick:Len2D() > XInput.ThumbsAsButtonsLevel / 2 then
						local moveRts = MulDivRound(stick, moveAmount, XInput.ThumbsAsButtonsLevel * 2)
						self:ScrollMap(-moveRts:x(), moveRts:y(), interval)
					end
				
					local gamepadState, currentGamepadId = GetActiveGamepadState()
					if gamepadState then
						local dPadDown = XInput.IsCtrlButtonPressed(currentGamepadId, "DPadDown")
						local dPadUp = XInput.IsCtrlButtonPressed(currentGamepadId, "DPadUp")
						local ltHeld = XInput.IsCtrlButtonPressed(currentGamepadId, "LeftTrigger")
						if ltHeld and (dPadDown or dPadUp) then
							local center = self.box:Center()
							self:ZoomMap(moveAmount * (dPadDown and -1 or 1), interval, center)
						end
					end
				end
			end
			Sleep(interval)
		end
	end)
end

function XSatelliteViewMap:OnDelete()
	self:RemoveContextMenu()
	if self.travel_mode then self:ExitTravelMode() end
	
	DeleteThread(g_SatelliteThread)
	g_SatelliteUI = false
	
	FireNetSyncEventOnHost("SatelliteViewClosed")
	XShortcutsSetMode("Game")
	SetRenderMode("scene")
	ObjModified("satellite-overlay")
	
	PlayFX("SatelliteClose")
end

function XSatelliteViewMap:ScrollStart()
	XMap.ScrollStart(self)
	self:SetMouseCursor("UI/Cursors/Pda_Inspect.tga")
	local cornerMenu = GetDialog(self).idMenu
	if cornerMenu then
		cornerMenu:SetChildrenHandleMouse(false)
		cornerMenu:DeleteThread("delayed-fade")
		cornerMenu:CreateThread("delayed-fade", function()
			Sleep(200)
			cornerMenu:SetTransparency(150, 125)
		end)
	end
end

function XSatelliteViewMap:ScrollStop()
	XMap.ScrollStop(self)
	self:SetMouseCursor()
	
	local cornerMenu = GetDialog(self).idMenu
	if cornerMenu then
		cornerMenu:SetChildrenHandleMouse(true)
		cornerMenu:DeleteThread("delayed-fade")
		cornerMenu:CreateThread("delayed-fade", function()
			Sleep(200)
			cornerMenu:SetTransparency(0, 125)
		end)
	end
end

function XSatelliteViewMap:SetMapScroll(transX, transY, time, int)
	local win_box = self.box

	local scaleX, scaleY = UIL.GetParam(1, "end")
	local clampMinX, clampMinY = MulDivRound(self.clamp_box:minx(), scaleX, 1000), MulDivRound(self.clamp_box:miny(), scaleY, 1000)
	local clampMaxX, clampMaxY = MulDivRound(self.clamp_box:maxx(), scaleX, 1000), MulDivRound(self.clamp_box:maxy(), scaleY, 1000)
	local winSizeX, winSizeY = win_box:sizex(), win_box:sizey()
	local winMinX, winMinY = win_box:minx(), win_box:miny()

	-- Clamp to map bounds.
	transX = Clamp(transX, winMinX - clampMaxX + winSizeX / 2, (winMinX + winSizeX / 2) - clampMinX)
	transY = Clamp(transY, winMinY - clampMaxY + winSizeY / 2, (winMinY + winSizeY / 2) - clampMinY)
	UIL.SetParam(0, transX, transY, time or 100, int)
	self.translation_change_notWASD = true
end

SatelliteLayers = { "satellite", "underground" }

function IsSectorLayerDefaultVisible(layerName)
	return false
end

function XSatelliteViewMap:GenerateSectorGrid()
	local size_x, size_y = 0, 0
	for id, s in pairs(gv_Sectors) do
		local y, x = sector_unpack(id)
		size_x = Max(size_x, x)
		size_y = Max(size_y, y)
	end
	self.sector_max_x = size_x
	self.sector_max_y = size_y
	
	-- Fx visibility map
	self.sector_visible_map = {}
	self.sector_player = {}
	self.sector_enemy = {}
	self.sector_neutral = {}
	for i, layerName in ipairs(SatelliteLayers) do
		local defaultVisible = IsSectorLayerDefaultVisible(layerName)
		local visibleMap = {}
		local player = {}
		local enemy = {}
		local neutral = {}
	
		for i = 1, size_x * size_y do
			assert(type(self.sector_visible_map[i]) == "nil")
			visibleMap[i] = defaultVisible
			player[i] = false
			enemy[i] = false
			neutral[i] = false
		end
		
		self.sector_visible_map[layerName] = visibleMap
		self.sector_player[layerName] = player
		self.sector_enemy[layerName] = enemy
		self.sector_neutral[layerName] = neutral
	end

	-- Sector window objects.
	local sector_to_wnd = {}
	self.sector_to_wnd = sector_to_wnd
	local start_x = self.grid_start:x()
	local start_y = self.grid_start:y()
	local sector_size_x = self.sector_size:x()
	local sector_size_y = self.sector_size:y()
	
	for id, sector in pairs(gv_Sectors) do
		local sectorId = sector.Id
		if not sectorId then
			assert(false, "Sector with no Id property: " .. id)
			goto continue
		end
		
		local y, x = sector_unpack(sectorId)
		x = start_x + (x-1) * sector_size_x
		y = start_y + (y-1) * sector_size_y
		local sectorWin = XTemplateSpawn("SectorWindow", self, gv_Sectors[sectorId])
		sectorWin.PosX, sectorWin.PosY = x, y
		sectorWin:SetWidth(sector_size_x)
		sectorWin:SetHeight(sector_size_y)
		
		sector_to_wnd[sectorId] = sectorWin
		
		-- Update position in global map.
		sector.XMapPosition = point(sectorWin:GetSectorCenter())
		
		-- Put underground sectors behind overground sectors.
		local isUnderground = sector.GroundSector
		if isUnderground then
			sectorWin:SetVisible(false)
		end
		
		-- Add underground/overground switch button.
		if gv_Sectors[sectorId .. "_Underground"] or isUnderground then
			local undergroundIconsList = XTemplateSpawn("XWindow", sectorWin)
			undergroundIconsList:SetLayoutMethod("HList")
			undergroundIconsList:SetUseClipBox(false)
			undergroundIconsList:SetMargins(box(10, 10, 10, 10))
			undergroundIconsList:SetHAlign("right")
			undergroundIconsList:SetVAlign("bottom")
			undergroundIconsList:SetId("idUndergroundIconsList")
		
			local udMarker = XTemplateSpawn("SatelliteSectorUndergroundIcon", undergroundIconsList)
			udMarker:SetId("idUnderground")
		end
		
		::continue::
	end
end

-- slow, to be used from Satellite Sector editor onlyfunction XSatelliteViewMap:RebuildSectorGrid()
	for _, win in pairs(self.sector_to_wnd) do
		win:delete()
	end
	self:GenerateSectorGrid()
	for id, win in pairs(self.sector_to_wnd) do
		win:Open()
		self:UpdateSectorVisuals(id)
	end	
end

-- Visualizations
------

function XSatelliteViewMap:GenerateSquadWindows()
	local squad_to_wnd = {}
	self.squad_to_wnd = squad_to_wnd

	for _, squad in ipairs(g_SquadsArray) do
		local squad_id = squad.UniqueId
		if squad.CurrentSector then
			local win = XTemplateSpawn("SquadWindow", self, squad)
			squad_to_wnd[squad_id] = win
		end
	end
end

function XSatelliteViewMap:GenerateShipmentWindows()
	local shipment_to_wnd = {}
	self.shipment_to_wnd = shipment_to_wnd
	
	for _, shipment_details in pairs(g_BobbyRay_CurrentShipments) do
		shipment_to_wnd[shipment_details] = CreateBobbyRayShipmentSquad(shipment_details)
	end
end

function OnMsg.BobbyRayShopShipmentSent(shipment_details)
	if not (g_SatelliteUI and g_SatelliteUI.shipment_to_wnd) then return end
	g_SatelliteUI.shipment_to_wnd[shipment_details] = CreateBobbyRayShipmentSquad(shipment_details)
	if g_SatelliteUI.window_state == "open" then g_SatelliteUI.shipment_to_wnd[shipment_details]:Open() end
end

function OnMsg.BobbyRayShopShipmentArrived(shipment_details)
	if not (g_SatelliteUI and g_SatelliteUI.shipment_to_wnd) then return end
	
	local shipment_window = g_SatelliteUI.shipment_to_wnd[shipment_details]
	if not shipment_window then return end
	
	g_SatelliteUI.shipment_to_wnd[shipment_details] = nil
	shipment_window:Close()
end

function OnMsg.ActiveQuestChanged()
	if g_SatelliteUI then
		g_SatelliteUI:UpdateAllSectorVisuals()
	end
end

function OnMsg.UnitAssignedToSquad(squad_id)
	if not g_SatelliteUI then return end
	local squad = gv_Squads[squad_id]
	if not squad or not squad.CurrentSector then return end
	g_SatelliteUI:UpdateSectorVisuals(squad.CurrentSector)
end

function OnMsg.ConflictEnd(sector)
	if not g_SatelliteUI then return end
	g_SatelliteUI:UpdateSectorVisuals(sector.Id)
end

function OnMsg.BuildingLockChanged(sector_id)
	if not g_SatelliteUI then return end
	g_SatelliteUI:UpdateSectorVisuals(sector_id)
end

function OnMsg.SquadTravellingTickPassed(squad)
	if not g_SatelliteUI or not squad or not squad.CurrentSector then return end
	g_SatelliteUI:UpdateSectorVisuals(squad.CurrentSector)
end

function XSatelliteViewMap:SetSuppressSectorVisualUpdates(val)
	self.suppress_visual_updates = val
	if not val then
		self:UpdateAllSectorVisuals()
	end
end

function XSatelliteViewMap:DelayedUpdateAllSectorVisuals()
	if self:GetThread("queue-update-all-sectors") then
		return
	end
	self:CreateThread("queue-update-all-sectors", function()
		if self.window_state == "destroying" then return end
		self:UpdateAllSectorVisuals()
	end)
end

function XSatelliteViewMap:UpdateAllSectorVisuals()
	for id, _ in pairs(self.sector_to_wnd) do
		self:UpdateSectorVisuals(id)
	end
	self:UpdateShipmentsVisibility()
end

function TFormat.SatelliteFilterMode()
	if not g_SatelliteUI then return end
	local mode = g_SatelliteUI.filter_info_mode
	if not mode then
		return T(366064427094, "Default")
	end
	if mode == "quests" then
		return T(210514527844, "Tasks")
	elseif mode == "buildings" then
		return T(491601259257, "Buildings")
	end
end

function XSatelliteViewMap:UpdateShipmentsVisibility()
	for _, shipment_details in pairs(g_BobbyRay_CurrentShipments) do
		local window = self.sector_to_wnd[shipment_details.sector_id]
		local shipWin = self.shipment_to_wnd[shipment_details]
		if shipWin then
			local visible = window.visible and (not self.filter_info_mode or self.filter_info_mode == "stash")
			shipWin:SetVisible(visible)
		end
	end
end

function XSatelliteViewMap:ToggleFilterMode(mode)
	if	mode == "default" or
		mode and mode == self.filter_info_mode
	then
		mode = false
	end
	self.filter_info_mode = mode

	local questFilter = self.filter_info_mode == "quests"
	local squadFilter = self.filter_info_mode == "squads"
	
	local placeLabelOnSquad = squadFilter or questFilter
	local sectorsPlacedOn = placeLabelOnSquad and {} or false
	for i, squadWnd in pairs(self.squad_to_wnd) do
		local squad = squadWnd.context
		if squad.Side ~= "player1" then goto continue end
		
		local label = squadWnd.idLabel
		local hasLabel = not not label		
		if hasLabel ~= placeLabelOnSquad then
			if hasLabel then
				label:Close()
			elseif not sectorsPlacedOn[squad.CurrentSector] or IsSquadTravelling(squad) then
				local lbl = XTemplateSpawn("SatelliteSquadLabel", squadWnd, squad)
				lbl:SetId("idLabel")
				if squadWnd.window_state == "open" then lbl:Open() end
				
				if sectorsPlacedOn then sectorsPlacedOn[squad.CurrentSector] = true end
			end
		end
		
		::continue::
	end
	XUpdateRolloverWindow(RolloverControl)
	g_SatelliteUI:UpdateAllSectorVisuals()
	ObjModified("satellite_filters")
end

function OnMsg.OperationChanged(ud)
	if not g_SatelliteUI then return end
	local squad = ud.Squad
	ObjModified("SquadLabel" .. squad)
end

function XSatelliteViewMap:ShowSectorIdUI(sector, show)
	local window = self.sector_to_wnd[sector.Id]
	if not window then return end
	
	local sectorId = window.context.Id
	if not window.idSectorIcon then
		local sectorIcon = XTemplateSpawn("SectorWindowId", g_SatelliteUI)
		sectorIcon:SetHAlign("left")
		sectorIcon:SetVAlign("top")
		sectorIcon:SetScaleModifier(point(550, 550))
		sectorIcon.ScaleWithMap = false
		sectorIcon.UpdateZoom = function(self, prevZoom, newZoom, time)
			local map = self.map
			local maxZoom = map:GetScaledMaxZoom()
			local minZoom = Max(1000 * map.box:sizex() / map.map_size:x(), 1000 * map.box:sizey() / map.map_size:y())
			local scaleAddition = MulDivRound(100, self.scale:x(), 1000)
			newZoom = Clamp(newZoom, minZoom + scaleAddition, maxZoom)
			XMapWindow.UpdateZoom(self, prevZoom, newZoom, time)
		end
		rawset(window, "idSectorIcon", sectorIcon)
		sectorIcon:SetPos(window.PosX, window.PosY)
		sectorIcon.idSectorId:SetText(T{764093693143, "<SectorIdColored(id)>", id = sectorId})
		if window.window_state == "open" then sectorIcon:Open() end
	end
	
	if show and window.idSectorIcon then
		local sectorIcon = window.idSectorIcon
		local color = GetSectorControlColor(sector.Side)
		sectorIcon.idSectorIdBg:SetBackground(color)
	end
	
	window.idSectorIcon:SetVisible(show)
end

function XSatelliteViewMap:ShowCursorHint(show, reason)
	if show and not g_ZuluMessagePopup and not RolloverWin then
		local text = false
		local style = false
		if IsSquadTravelling(self.selected_squad, "skip_satellite_tick")
			and CanCancelSatelliteSquadTravel(self.selected_squad) == "enabled"
			and (reason == "travel" or reason == "none") then
			text = GetUIStyleGamepad() and
					T(614351336268, "<ButtonBSmall> Cancel Travel") or
					T(392145576074, "<left_click> Cancel Travel")
		elseif reason == "travel" then
			text = GetUIStyleGamepad() and
					T(109122385021, "<ButtonASmall> Travel<newline><ButtonXSmall> Sector menu") or
					T(828415810044, "<left_click> Travel")
		elseif reason == "travel_mode" then
			
			if self.travel_mode then
				local travelMode = self.travel_mode
				local invalidRoute, errs = IsRouteForbidden(travelMode.route, travelMode.squad)
				if invalidRoute and #(errs or "") > 0 then
					style = "error"
					text = errs[1]
				end
			end
			
			if not text then
				text = GetUIStyleGamepad() and
						T(938773041595, "<ButtonASmall> Set <newline><ButtonBSmall> Cancel") or
						T(103054576698, "<left_click> Set<newline><right_click> Cancel")
			end
				
		elseif GetUIStyleGamepad() then 
			text = T(427350777180, "<ButtonXSmall> Sector menu")
		end
		
		if style == "error" then
			self.cursor_hint:SetBackground(GetColorWithAlpha(GameColors.B, 220))
			self.cursor_hint:SetBorderWidth(2)
			self.cursor_hint:SetBorderColor(GameColors.I)
			self.cursor_hint:SetMaxWidth(250)
			self.cursor_hint:SetPadding(box(3, 3, 3, 3))
			text = T{772176985382, "<error><txt></error>", txt = text}
		else
			self.cursor_hint:SetBackground(0)
			self.cursor_hint:SetBorderWidth(0)
			self.cursor_hint:SetBorderColor(GameColors.I)
			self.cursor_hint:SetMaxWidth(999)
			self.cursor_hint:SetPadding(empty_box)
		end
		
		self.cursor_hint.idText:SetText(text)	
		self.cursor_hint:SetVisible(not not text)
	else
		self.cursor_hint:SetVisible(false)
	end
end

function OnMsg.ZuluMessagePopup()
	if not g_SatelliteUI then return end
	g_SatelliteUI:RemoveContextMenu()
	g_SatelliteUI:ShowCursorHint(false)
end

function OnMsg.CreateRolloverWindow()
	if not g_SatelliteUI then return end
	g_SatelliteUI:ShowCursorHint(false)
end

function OnMsg.DestroyRolloverWindow()
	if not g_SatelliteUI then return end
	g_SatelliteUI:ShowCursorHint(true)
end

function XSatelliteViewMap:UpdateSectorVisuals(sector_id)
	if self.suppress_visual_updates then return end

	local sector = gv_Sectors[sector_id]
	local sectorVisible = IsSectorRevealed(sector)
	local window = self.sector_to_wnd[sector_id]
	local windowIsVisible = window.visible
	local inConflict = IsConflictMode(sector_id)
	
	window:SetSectorVisible(sectorVisible)
	
	-- Drawing data
	local windowLayer = window.layer
	local visibleMap = self.sector_visible_map[windowLayer]
	local playerMask = self.sector_player[windowLayer]
	local enemyMask = self.sector_enemy[windowLayer]
	local neutralMask = self.sector_neutral[windowLayer]
	
	local pos_y, pos_x = sector_unpack(sector_id)
	local mapIdx = 1 + pos_x - 1 + (pos_y - 1) * self.sector_max_x
	local visibleFx = sectorVisible or IsSectorLayerDefaultVisible(windowLayer)
	visibleMap[mapIdx] = not not visibleFx -- the C++ side needs strictly true/false here
	
	local side = sector.Side
	if (side == "player1" or side == "player2") and not sector.ForceConflict and sector.Passability ~= "Water" then
		playerMask[mapIdx] = true
		enemyMask[mapIdx] = false
		neutralMask[mapIdx] = false
	elseif side == "enemy1" and sector.Passability ~= "Water" then
		enemyMask[mapIdx] = true
		playerMask[mapIdx] = false
		neutralMask[mapIdx] = false
	elseif side == "neutral" and sector.Passability ~= "Water" and sector.Passability ~= "Blocked" then
		neutralMask[mapIdx] = true
		enemyMask[mapIdx] = false
		playerMask[mapIdx] = false
	else
		neutralMask[mapIdx] = false
		enemyMask[mapIdx] = false
		playerMask[mapIdx] = false
	end
	
	if windowLayer == "underground" then
		local groundSectorId = sector.GroundSector
		local groundSector = gv_Sectors[groundSectorId]
		if groundSector and groundSector.HideUnderground then
			neutralMask[mapIdx] = false
			enemyMask[mapIdx] = false
			playerMask[mapIdx] = false
		end
	end

	local questMode = self.filter_info_mode == "quests"
	local buildingMode = self.filter_info_mode == "buildings"
	local stashMode = self.filter_info_mode == "stash"
	local filterShowSquads = not questMode and not buildingMode and not stashMode

	-- sector indicator
	local sectorIndicatorVisible = self.selected_sector == sector or self.rollover_sector == sector
	self:ShowSectorIdUI(sector, sectorIndicatorVisible)

	-- If the window is toggled to show the underground/overground sector act as if the other one is invisible.
	sectorVisible = sectorVisible and windowIsVisible

	-- Objects on sector visibility
	local playerSquads, enemySquads = GetSquadsInSector(sector.Id, nil, "includeMilitia")
	local enemySquadsInShortcuts = UIGetSquadsInShortcutsHere(window)
	local playerSquadCount, enemySquadCount = #playerSquads, #enemySquads
	local top_priority_shown = false -- set top priority visible and delete all the others
	local sel_id = false
	
	-- Count non travelling squads to display multi-squad image.
	local nonTravellingSquadCount = 0
	for i = 1, playerSquadCount + enemySquadCount do
		local squad = i > playerSquadCount and enemySquads[i - playerSquadCount] or playerSquads[i]
		if not IsSquadTravelling(squad, not IsSquadInSectorVisually(squad)) then
			nonTravellingSquadCount = nonTravellingSquadCount + 1
		end
	end

	-- Sector switch (underground/overground)
	local otherSectorId = GetUnderOrOvergroundId(sector_id)
	if window.idUnderground then
		window.idUnderground:SetImage(GetUndergroundButtonIcon(otherSectorId))
	end
	
	if window.idUndergroundImage then
		window.idUndergroundImage:SetImage(inConflict and "UI/SatelliteView/sector_underground_conflict" or "UI/SatelliteView/sector_underground")
	end

	-- 1. selected_squad
	if self.selected_squad and table.find(playerSquads, "UniqueId", self.selected_squad.UniqueId) then
		local squadInConflict = IsSquadInConflict(self.selected_squad)
		local travelling = IsSquadTravelling(self.selected_squad, not IsSquadInSectorVisually(self.selected_squad))

		if squadInConflict then
			travelling = false
		end

		top_priority_shown = not travelling and filterShowSquads
		sel_id = self.selected_squad.UniqueId
		
		local squadWin = self.squad_to_wnd[self.selected_squad.UniqueId]			
		if squadWin then
			squadWin:SetVisible(sectorVisible and filterShowSquads)
			local visConflict = sectorVisible and squadInConflict
			squadWin:SetConflictMode(visConflict)
			squadWin:SetAnim(squadWin.rollover)
			squadWin.idMoreSquads:SetVisible(top_priority_shown and nonTravellingSquadCount > 1 and not visConflict)
			squadWin.idSquadSelection.idSquadRollover:SetVisible(false)
			squadWin.idSquadSelection.idSquadSelSmall:SetVisible(true)
			squadWin.idSquadSelection.idSquadSelBig:SetVisible(true)
		end
	end
	
	-- 1.5 Shortcut Travelling Enemy Squads
	for i, s in ipairs(enemySquadsInShortcuts) do
		local squadWin = self.squad_to_wnd[s.UniqueId]
		if squadWin then
			squadWin:SetVisible(windowIsVisible and filterShowSquads)
			squadWin:SetAnim(squadWin.rollover)
			squadWin.idMoreSquads:SetVisible(false)
		end
	end
	
	-- 2. player squad 3. enemy squad
	for i = 1, playerSquadCount + enemySquadCount do
		local squad = i > playerSquadCount and enemySquads[i - playerSquadCount] or playerSquads[i]
		if sel_id == squad.UniqueId then goto continue end
		
		local squadWin = self.squad_to_wnd[squad.UniqueId]
		if not squadWin then goto continue end

		local nonPlayer = squad.Side ~= "player1"
		if nonPlayer and IsTraversingShortcut(squad) then goto continue end
	
		local squadInConflict = IsSquadInConflict(squad)
		local travelling = IsSquadTravelling(squad, not IsSquadInSectorVisually(squad))
		local nonPlayerTravelling = nonPlayer and travelling
		
		-- Dont show the patrol squad for the crocodile guardpost objective.
		-- Dirty hack to test
		if squad.enemy_squad_def == "CampCrocodile_CirclingPatrol" then
			nonPlayerTravelling = false
		end
		
		local vis = (sectorVisible or squad.always_visible or squad.arrival_squad or nonPlayerTravelling) and
						(not top_priority_shown or travelling) and
						filterShowSquads
		vis = vis and windowIsVisible
						
		local showRouteEvenIfInvisible = sectorVisible and not vis and filterShowSquads
		squadWin:SetVisible(vis, showRouteEvenIfInvisible and "iconOnly")
		local visConflict = sectorVisible and not top_priority_shown and squadInConflict
		squadWin:SetConflictMode(visConflict)
		squadWin:SetAnim(squadWin.rollover)
		
		local iAmTop = top_priority_shown
		top_priority_shown = top_priority_shown or (vis and not travelling)
		iAmTop = not iAmTop and top_priority_shown
		squadWin.idMoreSquads:SetVisible(iAmTop and nonTravellingSquadCount > 1 and not visConflict)

		::continue::
	end
	
	-- 4. quests
	local underground = gv_Sectors[sector_id .. "_Underground"]
	local quests = GetQuestsAssociatedWithSector(sector_id)
	local activeQuest = false
	local questSectorId = sector_id
	-- If no quests on this sector, check above/below ground, since they're shown on the same square.
	if #quests == 0 and otherSectorId then
		quests = GetQuestsAssociatedWithSector(otherSectorId)
	end
	local hasQuests = #quests > 0
	local activeQuest = GetQuestsAssociatedWithSector(questSectorId, "active_only")
	local hasActiveQuest = #activeQuest > 0

	local hasMarker = not not window.idQuestMarker	
	local showMarker = (hasActiveQuest or questMode) and hasQuests
	local contextQuest = questMode and quests or activeQuest
	if hasMarker and window.idQuestMarker.context.quest ~= contextQuest then -- Check if displaying the same quest data.
		window.idQuestMarker:Close()
		hasMarker = false
	end
	
	if questMode and showMarker then
		if windowIsVisible then self:ShowSectorIdUI(sector, true) end
		window.quest_shows_sectorId = true
	else
		window.quest_shows_sectorId = false
	end
	if questMode then
		top_priority_shown = true
	end
	
	if hasMarker ~= showMarker then
		if hasMarker and not showMarker then
			window.idQuestMarker:Close()
		elseif not hasMarker and showMarker then
			local questMarker = XTemplateSpawn("SatelliteQuestIcon", window, { sector = gv_Sectors[questSectorId], quest = contextQuest })
			questMarker:SetId("idQuestMarker")
			questMarker:SetHAlign("left")
			questMarker:SetVAlign("bottom")
			questMarker:SetImage("UI/Icons/SateliteView/main_quest")
			if window.window_state == "open" then questMarker:Open() end		
		end
	end
	if window.idIntelMarker then
		window.idIntelMarker:SetVisible(sector.Intel and sector.intel_discovered and questMode)
	end
	
	-- In the quest filter the quest icon looks bigger
	if window.idQuestMarker then
		local marker = window.idQuestMarker
		if rawget(marker, "questMode") ~= questMode then
			if questMode then
				marker:SetHAlign("center")
				marker:SetVAlign("center")
				marker:SetScaleModifier(point(2000, 2000))
				rawset(marker, "questMode", true)
			else
				marker:SetHAlign("left")
				marker:SetVAlign("bottom")
				marker:SetScaleModifier(point(1000, 1000))
				rawset(marker, "questMode", false)
			end
		end
	end
	
	-- 5. POIs (buildings)	
	local sectorSide = sector.Side
	local sectorPOIs = false
	for _, poi in ipairs(POIDescriptions) do
		if sector[poi.id] then
			if not sectorPOIs then sectorPOIs = {} end
			sectorPOIs[#sectorPOIs + 1] = poi.id
		end
	end
	
	local firstPOIId = sectorPOIs and sectorPOIs[1]

	local templateName = "SatelliteSectorIconPOI"
	if firstPOIId == "Guardpost" and not buildingMode then
		templateName = "SatelliteSectorIconGuardpost"
	end

	local shouldHavePOI = not not firstPOIId and sector.reveal_allowed
	local hasPOIIcon = not not window.idPointOfInterest
	
	-- Despawn if changing to a different template
	if hasPOIIcon and shouldHavePOI then
		if window.idPointOfInterest.context.template ~= templateName then
			window.idPointOfInterest:Close()
			hasPOIIcon = false
		end
	end
	
	local canSpawnAsMainIcon = not top_priority_shown and not stashMode
	top_priority_shown = true
	if hasPOIIcon ~= shouldHavePOI then
		if not shouldHavePOI and hasPOIIcon then
			window.idPointOfInterest:Close()
			hasPOIIcon = false
		else
			local poiIcon = XTemplateSpawn(templateName, window, { sector = sector, template = templateName })
			if window.window_state == "open" then poiIcon:Open() end
			hasPOIIcon = true
		end
	end
	
	if hasPOIIcon then
		local wnd = window.idPointOfInterest
		wnd:Update(canSpawnAsMainIcon and "main" or "side", sectorPOIs)
	end
	
	-- Place underground POI
	local undegroundIconList = window.idUndergroundIconsList
	if underground and undegroundIconList then
		local node = undegroundIconList:ResolveId("node")
		for _, poi in ipairs(POIDescriptions) do
			local uPOI = poi.id
			local hasPOI = shouldHavePOI and underground[uPOI]
			local hasPOIUI = node["idUndergroundPOI" .. uPOI]
			
			if (not not hasPOI) ~= (not not hasPOIUI) then
			
				if hasPOI then
					local undergroundPOI = XTemplateSpawn("SatelliteIconPointOfInterest", undegroundIconList, {
						building = uPOI,
						pois = { uPOI },
						sector = underground
					})
					
					undergroundPOI:SetMain(false)
					undergroundPOI:SetScaleModifier(point(800, 800))
					undergroundPOI:SetId("idUndergroundPOI" .. uPOI)
					
					if window.window_state == "open" then undergroundPOI:Open() end		
				else
					hasPOIUI:Close()
				end
			
			end
			
			if hasPOIUI then
				hasPOIUI:UpdateStyle();
			end
		end
	end
	
	-- 6. Stash
	local hasStashIcon = not not window.idStashIcon
	local shouldHaveStashIcon = stashMode
	local stashObject = false
	if stashMode then
		if hasStashIcon then
			stashObject = window.idStashIcon.context
		else
			stashObject = PlaceObject("SectorStash")
			stashObject:SetSectorId(sector_id)
		end

		shouldHaveStashIcon = playerSquadCount > 0 or stashObject:CountItemsInSlot("Inventory") >= 1
	end
	if shouldHaveStashIcon ~= hasStashIcon then
		if hasStashIcon and not shouldHaveStashIcon then
			window.idStashIcon:Close()
			if window.idStashIconMercs then
				window.idStashIconMercs:Close()
			end
		elseif not hasStashIcon and shouldHaveStashIcon then
			local stashIcon = XTemplateSpawn("SatelliteStashIcon", window, stashObject)
			stashIcon:SetId("idStashIcon")
			if window.window_state == "open" then stashIcon:Open() end		
		end
	end
end

function OnMsg.RevealedSectorsUpdate()
	if not g_SatelliteUI then return end
	g_SatelliteUI:UpdateAllSectorVisuals()
end

function OnMsg.ConflictStart(sector_id)
	if not g_SatelliteUI then return end
	g_SatelliteUI:UpdateSectorVisuals(sector_id)
end

function OnMsg.SquadSpawned(squadId)
	assert(squadId)
	if not g_SatelliteUI or not squadId then return end
	local squad = gv_Squads[squadId]
	local window = g_SatelliteUI.squad_to_wnd[squadId]
	assert(not window)
	if not window then
		window = XTemplateSpawn("SquadWindow", g_SatelliteUI, squad)
		if g_SatelliteUI.window_state == "open" then window:Open() end
		g_SatelliteUI.squad_to_wnd[squadId] = window
	end
	RecalcRevealedSectors()
	local playerSquad = squad.Side == "player1"
	if playerSquad then ObjModified("ui_player_squads") end
end

function OnMsg.SquadDespawned(squadId, sector, side)
	assert(squadId)
	if not g_SatelliteUI or not squadId then return end
	local window = g_SatelliteUI.squad_to_wnd[squadId]
	if window then
		window:Close()
		g_SatelliteUI.squad_to_wnd[squadId] = nil
	end
	RecalcRevealedSectors()
	local playerSquad = side == "player1"
	if playerSquad then ObjModified("ui_player_squads") end
end

-- Note: Removed ObjModified(squad) from these msgs and associated logic.
-- These should only matter when the squad is the selected squad.
-- OperationChanged
-- SquadStartedTravelling
-- ReachSectorCenter

function OnMsg.MercReleased(squadId, mercUd)
	ObjModified("ui_player_squads")
end

function OnMsg.SquadStartedTravelling(squad)
	if not g_SatelliteUI or not squad then return end
	local sectorId = squad.CurrentSector
	if sectorId then
		g_SatelliteUI:UpdateSectorVisuals(sectorId)
		local squadWin = g_SatelliteUI.squad_to_wnd[squad.UniqueId]
		squadWin:SetAnim(true)
	end
	
	local travelMode = g_SatelliteUI.travel_mode
	if travelMode and travelMode.squad == squad then
		g_SatelliteUI:ExitTravelMode()
	end
end

function OnMsg.SquadFinishedTraveling(squad)
	print(OnMsg.SquadFinishedTraveling)
	local squadWin = g_SatelliteUI.squad_to_wnd[squad.UniqueId]
	squadWin:SetAnim(false)
end

function GetCampaignSpeedXMapFactor()
	if IsCampaignPaused() then return 0 end
	return 1000
end

function OnMsg.CampaignSpeedChanged()
	if not g_SatelliteUI then return end
	g_SatelliteUI:SetTimeFactor(GetCampaignSpeedXMapFactor())
	UpdateSatelliteDesaturation()
end

function UpdateSatelliteDesaturation()
	local factor = GetCampaignSpeedXMapFactor()
	
	local mod = {
		id = "desat",
		type = const.intDesaturation,
		startValue = factor == 0 and 0 or 100,
		endValue = factor == 0 and 100 or 0,
		duration = 500,
		interpolate_clip = false
	}
	g_SatelliteUI:AddInterpolation(mod)
	g_SatelliteUI:SetDesaturation(factor == 0 and 150 or 0)
end

DefineClass.XSatelliteViewMapBaseParams = {
	__parents = { "MeshParamSet", "UIFxModifierPreset" },
	properties = {
		{ uniform = true, id = "OriginalImgAlpha", editor = "number", default = 0, scale = 1000, },
		{ uniform = true, id = "BorderWidth", editor = "number", default = 0, scale = 1000, },
		{ uniform = true, id = "BorderColor", editor = "color", default = RGB(255,255,255) },
		{ uniform = true, id = "BorderOffset", editor = "number", default = 0, min = -500, max = 500, slider = true, scale = 1000, },

		{ uniform = true, id = "InsideColor", editor = "color", default = RGB(255, 255, 255) },
		{ uniform = true, id = "InsideGlowMin", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1500},
		{ uniform = true, id = "InsideGlowMax", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1500},
		{ uniform = true, id = "InsideGlowPow", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 4000},
		{ uniform = true, id = "InsideInterlace", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1000},
		{ uniform = true, id = "InsideGroundLoopColor", editor = "color", default = RGB(255,255,255),  },
		{ uniform = true, id = "InsideGroundLoopGlow", editor = "number", default = 0, min = 0, max = 500, slider = true, scale = 1000, },
		{ uniform = true, id = "InsideGroundLoopSpeed", editor = "number", default = 0, min = 0, max = 1000, scale = 1000, },
		{ uniform = true, id = "InsideGroundLoopLength", editor = "number", default = 0, min = 0, max = 20000, scale = 1000, },
		{ uniform = true, id = "InsideGroundLoopPauseLen", editor = "number", default = 0, min = 0, max = 20000, scale = 1000, },
		{ uniform = true, id = "InsideGroundLoopStrength1", editor = "number", default = 0, min = 0, max = 1000, scale = 1000, },
		{ uniform = true, id = "InsideGroundLoopStrength2", editor = "number", default = 0, min = 0, max = 1000, scale = 1000, },

		{ uniform = true, id = "OutsideColor", editor = "color", default = RGB(255, 255, 255) },
		{ uniform = true, id = "OutsideGlowMin", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1500},
		{ uniform = true, id = "OutsideGlowMax", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1500},
		{ uniform = true, id = "OutsideGlowPow", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 4000},
		{ uniform = true, id = "OutsideInterlace", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1000},
		{ uniform = true, id = "OutsideGroundLoopColor", editor = "color", default = RGB(255,255,255),  },
		{ uniform = true, id = "OutsideGroundLoopGlow", editor = "number", default = 0, min = 0, max = 500, slider = true, scale = 1000, },
		{ uniform = true, id = "OutsideGroundLoopSpeed", editor = "number", default = 1000, min = 0, max = 3000, scale = 1000, },
		{ uniform = true, id = "OutsideGroundLoopLength", editor = "number", default = 6000, min = 0, max = 20000, scale = 1000, },
		{ uniform = true, id = "OutsideGroundLoopPauseLen", editor = "number", default = 0, min = 0, max = 20000, scale = 1000, },
		{ uniform = true, id = "OutsideGroundLoopStrength1", editor = "number", default = 0, min = 0, max = 1000, scale = 1000, },
		{ uniform = true, id = "OutsideGroundLoopStrength2", editor = "number", default = 0, min = 0, max = 1000, scale = 1000, },

		{ uniform = true, id = "LodBias", name = "LodBias (Blur)", editor = "number", default = 0, min = -10000, max = 10000, scale = 1000, slider = true, },
	},
	StoreAsTable = false,
}
DefineClass.XSatelliteViewParams = {
	__parents = { "PersistedRenderVars" },
	group = "XSatelliteViewParams",

	properties = {
		{id = "visible_grid_color", editor = "color", default = RGBA(110, 110, 110, 170)},
		{id = "invisible_grid_color", editor = "color", default =  RGBA(110, 110, 110, 170),},
		{id = "grid_width", editor = "number", min = 1, max = 20, default = 6, },

		{id = "vision_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "vision_blur_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "neutral_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "player_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "enemy_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "selected_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "rollover_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "neutral_sector_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
	},
}

local ModifiersSetTop = UIL.ModifiersSetTop
local ModifiersGetTop = UIL.ModifiersGetTop
local PushModifier = UIL.PushModifier

function XSatelliteViewMap:DrawContent()
	if not self.Image or self.Image == "" or not self.sector_visible_map then return end

	local image_src = self:CalcSrcRect()
	local satview_image_size = image_src:size()

	local src = box(0, 0, self.map_size:x(), self.map_size:y())
	local width, height = self.map_size:xyz()
	local color = self.ImageColor

	local start_x = self.grid_start:x()
	local start_y = self.grid_start:y()
	local sector_size_x = self.sector_size:x()
	local sector_size_y = self.sector_size:y()

	local satviewSpaceToSrcrc = function(value)
		if IsPoint(value) then
			return MulDivRoundPoint(value, satview_image_size, self.map_size)
		else
			return box(MulDivRoundPoint(value:min(), satview_image_size, self.map_size),
				MulDivRoundPoint(value:max(), satview_image_size, self.map_size))
		end
	end

	local dst_rect = sizebox(start_x, start_y, sector_size_x * self.sector_max_x, sector_size_y * self.sector_max_y)
	local src_rect = satviewSpaceToSrcrc(dst_rect)

	local draw_as_paused = IsCampaignPaused()
	--- DrawBackground
	local top = XPushShaderEffectModifier(draw_as_paused and "SatelliteViewFog_Blur" or "SatelliteViewFog")
	UIL.DrawXImage(self.Image,
		box(0, 0, width, height), width, height, satviewSpaceToSrcrc(src),
		color, color, color, color,
		self:CalcDesaturation(), self.Angle, self.FlipX, self.FlipY,
		self.EffectType, self.EffectPixels, self.EffectColor, true,
		RGBA(255,255,255,0), src_rect:minx(), src_rect:miny(), satview_image_size:x() - src_rect:maxx(), satview_image_size:y() - src_rect:maxy())
	ModifiersSetTop(top)
	--- EndDrawBackground

	local white = RGB(255,255,255)
	
	local shader_params = XSatelliteViewParams:GetActiveInstance() or XSatelliteViewParams
	local shader_buf = pstr()

	local currentLayer = self.layer_mode
	local visible_sectors = table.copy(self.sector_visible_map[currentLayer])
	local player_sectors = table.copy(self.sector_player[currentLayer])
	local enemy_sectors = table.copy(self.sector_enemy[currentLayer])
	local neutral_sectors = table.copy(self.sector_neutral[currentLayer])
	
	local width, height = 	self.sector_max_x, self.sector_max_y
	local selected_sectors, rollover_sectors = {}, {}
	for i = 1, width * height do
		selected_sectors[i] = false
		rollover_sectors[i] = false
	end
	
	if self.selected_sector_fx then
		local id = self.selected_sector_fx.Id
		local y, x = sector_unpack(id)
		local idx = 1 + (x - 1) + (y - 1) * self.sector_max_x
		selected_sectors[idx] = true
	end
	
	if self.rollover_sector_fx then
		local id = self.rollover_sector_fx.Id
		local y, x = sector_unpack(id)
		local idx = 1 + (x - 1) + (y - 1) * self.sector_max_x
		rollover_sectors[idx] = true
	end
	
	if self.blinking_sector_fx then
		local id = self.blinking_sector_fx.Id
		local y, x = sector_unpack(id)
		local idx = 1 + (x - 1) + (y - 1) * self.sector_max_x
		rollover_sectors[idx] = true
	end

	local vision_mask_id = draw_as_paused and shader_params.vision_blur_id or shader_params.vision_id
	shader_buf = (UIFxModifierPresets[vision_mask_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, point(self.sector_max_x, self.sector_max_y), visible_sectors, shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, point(self.sector_max_x, self.sector_max_y), selected_sectors, shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, point(self.sector_max_x, self.sector_max_y), rollover_sectors, shader_buf)

	UILDrawSatelliteViewLines( dst_rect, point(self.sector_max_x, self.sector_max_y), self.sector_visible_map[currentLayer],
		shader_params.visible_grid_color, shader_params.invisible_grid_color, shader_params.grid_width)

	shader_buf = (UIFxModifierPresets[shader_params.neutral_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, point(self.sector_max_x, self.sector_max_y), visible_sectors, shader_buf)
	
	shader_buf = (UIFxModifierPresets[shader_params.neutral_sector_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, point(self.sector_max_x, self.sector_max_y), neutral_sectors, shader_buf)

	shader_buf = (UIFxModifierPresets[shader_params.enemy_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, point(self.sector_max_x, self.sector_max_y), enemy_sectors, shader_buf)

	shader_buf = (UIFxModifierPresets[shader_params.player_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, point(self.sector_max_x, self.sector_max_y), player_sectors, shader_buf)

	shader_buf = (UIFxModifierPresets[shader_params.selected_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, point(self.sector_max_x, self.sector_max_y), selected_sectors, shader_buf)

	shader_buf = (UIFxModifierPresets[shader_params.rollover_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, point(self.sector_max_x, self.sector_max_y), rollover_sectors, shader_buf)

	-- Debug visualize satellite shortcut path
--[[	local shortcutPreset = SatelliteShortcuts[1]
	local path = shortcutPreset:GetPath()
	local resolution = 200
	local increment = 1000 / resolution
	for i = 0, 1000 - increment, increment do
		local pt1 = GetShortcutCurvePointAt(path, i)
		local pt2 = GetShortcutCurvePointAt(path, i + increment)
		UIL.DrawLineAntialised(10, pt1, pt2, green)
	end]]
end

function XSatelliteViewMap:GetMouseCursor()
	return self.mouse_cursor
end

function XSatelliteViewMap:GetMouseTargetOfType(pt, class)
	local target, mouse_cursor
	for i = #self, 1, -1 do
		local win = self[i]
		if (not target or win.DrawOnTop) and win:MouseInWindow(pt) then
			if IsKindOf(win, class) then
				return win, win:GetMouseCursor()
			end
			local newTarget, newMouse_cursor = win:GetMouseTarget(pt)
			if IsKindOf(newTarget, class) then
				return newTarget, newMouse_cursor
			end
		end
	end
end

function XSatelliteViewMap:GetSectorOnPos(pos, mapSpace)
	if pos == "mouse" then pos = terminal.GetMousePos() end

	if not mapSpace then pos = self:ScreenToMapPt(pos) end
	return self:GetMouseTargetOfType(pos, "SectorWindow")
end

--- UI Functionality
------

function SatelliteSetCameraDest(sector, time)
	local sector = gv_Sectors[sector]
	if not sector or not g_SatelliteUI then return end
	local pos = sector.XMapPosition
	g_SatelliteUI:CenterScrollOn(pos:x(), pos:y(), time)
	
	if time and time > 0 then
		SectorWindowBlink(sector)
	end
end

function XSatelliteViewMap:SelectSquad(squad)
	local partyCont = self:ResolveId("idPartyContainer")
	partyCont:SelectSquad(squad)
	return partyCont.selected_squad
end

function XSatelliteViewMap:SelectSector(sector)
	if true then return end

	if sector and sector.Passability == "Water" then
		sector = false
	end
	if sector == self.selected_sector then 
		--sector = false
		return
	end

	if self.selected_sector then self:ShowSectorIdUI(self.selected_sector, false) end
	if sector then self:ShowSectorIdUI(sector, true) end

	self.selected_sector = sector
	self.selected_sector_fx = sector and sector.GroundSector and gv_Sectors[sector.GroundSector] or sector
	ObjModified("sector_selection_changed")
	ObjModified("sector_selection_changed_actions")
	-- If switching underground/overground selection reflect the change on the
	-- in-map sector as well.
	local wnd = sector and self.sector_to_wnd[sector.Id]
	if wnd and not wnd.visible and wnd.idUnderground then
		wnd.idUnderground:SwapSector()
	end
end

function GetSectorInfoPanel()
	return g_SatelliteUI and g_SatelliteUI.parent.idSectorInfoPanel
end

function GetTravelPanel()
	return g_SatelliteUI and g_SatelliteUI.parent.idTravelPanel
end

function OnMsg.SatelliteTick()
	if GetSectorInfoPanel() and g_SatelliteUI.selected_sector then		
		ObjModified("sector_selection_changed")
	end
end

-- All squad selection happens here!
function OnMsg.SatelliteNewSquadSelected(selected_squad, old_squad, force)
	if not gv_SatelliteView and not force then return end
	
	local satDiag = g_SatelliteUI	
	satDiag.selected_squad = selected_squad
	ObjModified("PDAButtons")
	UpdatePDAPowerButtonState()
	
	if satDiag.travel_mode then
		--satDiag:SetTravelPreviewSquad(selected_squad)
		satDiag:ExitTravelMode()
	end
	
	if old_squad then
		satDiag:UpdateSectorVisuals(old_squad.CurrentSector)
	end
	
	if selected_squad then
		local sectorId = selected_squad.CurrentSector
		satDiag:UpdateSectorVisuals(sectorId)		
		local squadWin = satDiag.squad_to_wnd[selected_squad.UniqueId]	
		if squadWin then
			squadWin:SelectionAnim()
		end
		
		local sectorUnderground = IsSectorUnderground(sectorId)
		local sectorWin = satDiag.sector_to_wnd[sectorId]
		if sectorWin and sectorWin.idUnderground and not sectorWin.visible then
			sectorWin.idUnderground:SwapSector()
		end
	end

	ObjModified(satDiag)
	ObjModified("gv_SatelliteView")
end

function XSatelliteViewMap:OpenContextMenu(ctrl, sector_id, squad_id, unit_id)
	if self.travel_mode then
		self:ExitTravelMode()
	end

	local actions = {}
	local squad = gv_Squads[squad_id]
	local squadName = squad and Untranslated(squad.Name)
	
	if unit_id then
		table.insert(actions, "idInventory")
		table.insert(actions, "idPerks")
	else
		local squadsOnSector = GetSquadsInSector(sector_id)

		-- If the currently selected squad is on this sector and can enter the map, then we dont need to change
		-- the selected squad for satisfy the context menu.
		local canEnterWithAny = false
		local currentSelectedSquad = self.selected_squad
		if currentSelectedSquad and
			table.find(squadsOnSector, currentSelectedSquad) and
			GetSquadEnterSectorState(currentSelectedSquad.UniqueId) then
			canEnterWithAny = currentSelectedSquad
		end
		
		if not canEnterWithAny then
			for i, s in ipairs(squadsOnSector) do
				if GetSquadEnterSectorState(s.UniqueId) then
					canEnterWithAny = s
					break
				end
			end
		end
		
		local selSquad = canEnterWithAny or squad
		if selSquad and selSquad.Side == "player1" and self.selected_squad ~= selSquad then
			self:SelectSquad(selSquad)
		end
		
		if SatelliteToggleActionState() == "enabled" and canEnterWithAny then
			table.insert(actions, "actionToggleSatellite")
		end
		if #squadsOnSector > 0 then
			table.insert(actions, "idOperations")
		end
		if squad_id and CanCancelSatelliteSquadTravel() == "enabled" then
			table.insert(actions, "idCancelTravel")
		end
		table.insert(actions, "actionContextMenuViewSectorStash")
	end
	if #actions == 0 then return end
	
	if IsKindOf(ctrl, "XMapObject") then
		SetCampaignSpeed(0, GetUICampaignPauseReason("UIContextMenu"))
	end

	local overrideRollover = false
	if RolloverWin and IsKindOf(RolloverWin, "ZuluContextMenu") then
		overrideRollover = RolloverWin
		RolloverWin = false
		RolloverControl = false
		assert(false) -- This is used?
	else
		XDestroyRolloverWindow()
	end
	
	local context = {sector_id = sector_id, squad_id = squad_id, actions = actions, unit_id = unit_id}
	local popupHost = GetParentOfKind(self, "PDAClass")
	popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
	local menu = overrideRollover or XTemplateSpawn("SatelliteViewMapContextMenu", popupHost, context)
	self.context_menu = menu

	menu:SetAnchor(ctrl:ResolveRolloverAnchor())
	if IsKindOf(ctrl, "XMapRolloverable") then
		ctrl:SetupMapSafeArea(menu)
	else
		-- Margins from PDAMercRollover
		menu:SetMargins(box(30, 2, 0, 0))
	end
	if menu.window_state ~= "open" then menu:Open() end
	menu.idContent:SetContext(context, true)
	menu:SetModal(true)
	
	return menu
end		

function XSatelliteViewMap:RemoveContextMenu()
	if self.context_menu then
		if self.context_menu.window_state ~= "destroying" then self.context_menu:Close() end
		self.context_menu = false
		return true		
	end
	return false
end

function GetSatelliteSquadsForContextMenu(sectorId)
	if not sectorId then return empty_table end
	local squads = GetSquadsInSector(sectorId, "excludeTravelling", not "includeMilitia", "excludeArriving")
	if #squads <= 1 then return empty_table end
	return squads
end

-- Travel
-----

function OnMsg.TravelModeChanged()
	ObjModified("travel_mode_changed")
end

function XSatelliteViewMap:IsRolloverSectorImpassable()
	return self.rollover_sector and (self.rollover_sector.Passability == "Blocked" or self.rollover_sector.Passability == "Water")
end

function XSatelliteViewMap:OnSectorRollover(wnd, sector, rollover)
	-- Update shown route with rollovered sector
	if self.travel_mode then
		if self.travel_mode.destination_choice and rollover then
			self:TravelDestinationSelect(sector.Id)
		end
		self:ShowCursorHint(true, "travel_mode")
	else
		local selSquadSector = self.selected_squad and self.selected_squad.CurrentSector
		selSquadSector = selSquadSector and selSquadSector == sector.Id
		local show_hint = rollover and sector and sector.Passability ~= "Water" and not selSquadSector
		self:ShowCursorHint(show_hint, show_hint and "travel" or "none")
	end
	self.mouse_cursor = self:IsRolloverSectorImpassable() and "UI/Cursors/Pda_Impassable.tga"

	self.rollover_sector = rollover and sector
	self.rollover_sector_fx = rollover and sector
	if self.rollover_sector ~= sector then
		self:Invalidate()
	end
	
	local questFilter = self.filter_info_mode == "quests"
	local window = self.sector_to_wnd[sector.Id]
	local show = rollover or self.selected_sector == sector or (window.visible and window.quest_shows_sectorId)
	self:ShowSectorIdUI(sector, show)
end

function XSatelliteViewMap:SetTravelWaypoint()
	local travelCtx = self.travel_mode
	assert(travelCtx)
	if not travelCtx then return end
	local route = travelCtx.route
	if not route then return end -- No valid route to that sector (shift-click on impassable adjacent sector)

	local forbidden, _, _, canPlaceWaypoint = IsRouteForbidden(route)
	if forbidden and not canPlaceWaypoint then
		PlayFX("UnreachableSatellite")
		return
	end
	
	-- This will turn the currently temporary waypoint in the display route to a permanent one.	
	route.displayedSectionEnd = false
	ObjModified(travelCtx)
end

function AskForExhaustedUnits(squad)
	local willTravel = true
	if HasTiredMember(squad, "Exhausted") then
		local exhausted_ids = ShowExhaustedUnitsQuestion(squad)
		if exhausted_ids then
			if #exhausted_ids ~= #squad.units then
				NetSyncEvent("SplitSquad", squad.UniqueId, exhausted_ids)
			else
				willTravel = false
			end
		else
			willTravel = false
		end
	end
	return willTravel
end

function XSatelliteViewMap:TravelModeMove()
	-- Sanity checks
	local travelCtx = self.travel_mode
	if not travelCtx then return end
	local route = travelCtx.route
	if not route then return end
	local squad = travelCtx.squad
	if not squad then return end
	
	if IsRouteForbidden(route, squad) then return end

	-- Thread the function so popups can wait
	local existingThread = self:GetThread("TravelModeMove")
	if IsValidThread(existingThread) and existingThread ~= CurrentThread() then
		return
	end

	if not CanYield() then
		self:CreateThread("TravelModeMove", XSatelliteViewMap.TravelModeMove, self)
		return
	end
	
	-- Stop destination choice during popups as it might change the dest.
	self.travel_mode.destination_choice = false
	Msg("TravelModeChanged")
	ObjModified(g_SatelliteUI.travel_mode)
	PlayFX("SatViewMoveCommand", "start")
	
	-- Ask if we want to split tired units
	local willTravel = AskForExhaustedUnits(squad)
	if not willTravel then
		self.travel_mode.destination_choice = true
		return
	end

	-- Ask if we want to split busy mercs etc.
	local res = TryAssignSatelliteSquadRoute(squad.UniqueId, route)
	if res == "cancel" then
		self.travel_mode.destination_choice = true
		return
	end
	
	local vr_type = #squad.units>1 and "GroupOrder" or "Order"
	PlayVoiceResponse(squad.units and squad.units[1], vr_type)
end

function XSatelliteViewMap:OnSectorClick(wnd, sector, button)
	if self:RemoveContextMenu() then return "break" end

	self.last_mouse_down = false

	local shiftPressed = terminal.IsKeyPressed(const.vkShift)
	if self.travel_mode and self.travel_mode.destination_choice and button == "L" then
		self.last_mouse_down = { time = RealTime(), sector = sector, map_scroll = point(UIL.GetParam(0)) }
		return
	elseif not self.travel_mode and button == "L" and self.selected_squad then
		if shiftPressed then
			local selSquadSector = self.selected_squad.CurrentSector
			if selSquadSector ~= sector.Id then
				InvokeShortcutAction(self, "idTravel")
				if not self.travel_mode then return end -- It's possible for travel to be disabled
				self:SetTravelWaypoint()
			end
		else
			self.last_mouse_down = { time = RealTime(), sector = sector, map_scroll = point(UIL.GetParam(0)) }
			return
		end
		
		return "break"
	elseif not self.travel_mode and button == "R" then
		--self.last_mouse_down = { time = RealTime(), sector = sector, map_scroll = point(UIL.GetParam(0)) }
		g_SatelliteUI:OpenContextMenu(wnd, sector.Id)
		return "break"
	end
end

function XSatelliteViewMap:OnMouseButtonUp(pt, button, ...)
	XMap.OnMouseButtonUp(self, pt, button, ...)
	if button ~= "L" or not self.last_mouse_down then return end

	local soon = (RealTime() - self.last_mouse_down.time < self.click_time)
	local didntMove = (self.last_mouse_down.map_scroll:Dist(point(UIL.GetParam(0))) < 20)
	if not soon or not didntMove then return end

	local shiftPressed = terminal.IsKeyPressed(const.vkShift)
	local sector = self.last_mouse_down.sector 
	if self.travel_mode and self.travel_mode.destination_choice and button == "L" then
		local travelCtx = self.travel_mode
		local route = travelCtx.route

		if not route then
			PlayFX("UnreachableSatellite")
			return "break"
		end
	
		if shiftPressed then
			self:SetTravelWaypoint()
			return "break"
		end
		
		if IsRouteForbidden(route) then
			PlayFX("UnreachableSatellite")
			return "break"
		end
		
		if sector.GroundSector then sector = gv_Squads[sector.GroundSector] end -- Prevent waypoints on underground sectors
		self:SetTravelWaypoint(sector)
	
		-- Route wasn't recalculated after placing of waypoint.
		local r = self.travel_mode.route
		if #r > 0 and not r.displayedSectionEnd then 
			local lastWp = r[#r]
			r.displayedSectionEnd = lastWp[#lastWp]
		end
		-- Remove waypoint at end, if any was placed
		if #r > 1 then
			local lastWp = r[#r]
			local penultimate = r[#r - 1]
			if #lastWp == 1 and lastWp[1] == penultimate[#penultimate] then -- Overlapping waypoint
				table.remove(r, #r)
			end
		end
		
		self:TravelModeMove()
		return "break"
	else
		if IsSquadTravelling(self.selected_squad, "skip_satellite_tick") then
			InvokeShortcutAction(self, "idCancelTravel", nil, "check_enabled")
			return
		end
		
		--[[if GetUIStyleGamepad() then
			self:SelectSector(self.last_mouse_down.sector)
			return "break"
		end]]
		
		local selSquadSector = self.selected_squad.CurrentSector
		local sector = self.last_mouse_down.sector
		if selSquadSector ~= sector.Id then
			PlayFX("SectorSelected", "start")
			InvokeShortcutAction(self, "idTravel")
		end
		
		return "break"
	end
end

function XSatelliteViewMap:OnMouseButtonDown(pt, button, ...)
	if self:RemoveContextMenu() then return "break" end
	if button == "R" and self.travel_mode then
		self:ExitTravelMode()
		return "break"
	end
	
	if GetUIStyleGamepad() then return end -- No dragging with gamepad mouse
	XMap.OnMouseButtonDown(self, pt, button, ...)
end

function XSatelliteViewMap:TravelWithSquad(squadId)
	if self.travel_mode or SatelliteCanTravelState(squadId) ~= "enabled" then return end
	self:RemoveContextMenu()
	self.travel_mode = { squad = gv_Squads[squadId], route = false }
	self.parent.idSpeedControls:SetTransparency(125)
	SetCampaignSpeed(0, GetUICampaignPauseReason("SatelliteTravel"))
	self.desktop:SetMouseCursor("UI/Cursors/Pda_Travel.tga")

	self:SelectSector(false)

	-- Decide which sector the initial selected destination will be when travel mode is
	-- opened while the mouse is on top of the squad's sector.
	local squadSector = gv_Squads[squadId].CurrentSector
	local squadSectorX, squadSectorY = sector_unpack(squadSector)
	local bestSector, firstAvail = squadSector
	ForEachSectorAround(squadSector, 1,
		function(s_id)
			-- Skip diagonal sectors and we can't check travel blocked for them trivially.
			local sX, sY = sector_unpack(s_id)
			if abs(sX - squadSectorX) == 1 and abs(sY - squadSectorY) == 1 then return end
		
			firstAvail = firstAvail or s_id
			local sectorObj = gv_Sectors[s_id]
			if (sectorObj.Passability == "Land" or sectorObj.Passability == "Land and Water")
				and not IsTravelBlocked(squadSector, s_id)
				and s_id ~= squadSector then
				bestSector = s_id
				return "break"
			end
		end
	)
		
--[[	for i, wnd in pairs(self.sector_to_wnd) do
		wnd:ShowTravelBlockLines(true)
	end]]
	
	-- Show the underground/overground sector if the squad traveling is on it.
	local squadSectorWnd = self.sector_to_wnd[squadSector]
	if squadSectorWnd and squadSectorWnd.idUnderground and not squadSectorWnd.visible then
		squadSectorWnd.idUnderground:SwapSector()
	end
		
	local travelDest = bestSector or firstAvail
	local squadSectPreset = gv_Sectors[squadSector]
	assert(squadSectPreset.Passability ~= "Land" or squadSectPreset.Passability ~= "Land and Water" or travelDest ~= squadSector)
	self:TravelDestinationSelect(travelDest)
	Msg("TravelModeChanged", true)
end

function XSatelliteViewMap:ExitTravelMode()
	if not self.travel_mode then return end
	local travellingSquad = self.travel_mode.squad
	self.travel_mode = false
	
	if self.window_state ~= "destroying" then
		self.parent.idSpeedControls:SetTransparency(0)
		if travellingSquad then
			local squadWnd = self.squad_to_wnd[travellingSquad.UniqueId]
			if squadWnd then
				squadWnd:DisplayRoute("main", travellingSquad.CurrentSector, travellingSquad.route)
				squadWnd:DisplayRoute("land") -- delete
			end
		end
	end
	
	for i, wnd in pairs(self.sector_to_wnd) do
		wnd:ShowTravelBlockLines(false)
	end

	SetCampaignSpeed(nil, GetUICampaignPauseReason("SatelliteTravel"))
	self.desktop:SetMouseCursor()
	Msg("TravelModeChanged", false)
end

function OnMsg.TravelModeChanged()
	if not g_SatelliteUI or g_SatelliteUI.window_state == "destroying" then return end
	
	local sectorWndOnMouse = g_SatelliteUI:GetSectorOnPos("mouse")
	if sectorWndOnMouse then
		g_SatelliteUI:OnSectorRollover(sectorWndOnMouse, sectorWndOnMouse.context, true)
	end
end

function XSatelliteViewMap:SetTravelPreviewSquad(squad)
	if not self.travel_mode then return end
	if not squad then squad = self.selected_squad end -- Default to selected

	if SatelliteCanTravelState(squad) ~= "enabled" then
		self:ExitTravelMode()
		return
	end
	
	local oldSquad = self.travel_mode.squad
	local oldSquadWnd = self.squad_to_wnd[oldSquad.UniqueId]
	oldSquadWnd:DisplayRoute("main", oldSquad.CurrentSector, oldSquad.route)
	self.travel_mode.squad = squad
	ObjModified(self.travel_mode)
	
	-- Redraw to current destination
	if self.travel_mode.dest then
		self:TravelDestinationSelect(self.travel_mode.dest)
	end
end

function XSatelliteViewMap:TravelDestinationSelect(sectorId)
	if not self.travel_mode then return end
	if sectorId then
		local travelCtx = self.travel_mode
		local squad = travelCtx.squad
		if sectorId == squad.CurrentSector then return end

		if travelCtx.route_valid then
			travelCtx.route = travelCtx.route_valid
			travelCtx.route_valid = false
		end
	
		local newCalculatedRoute = GenerateSquadRoute(travelCtx.route, false, sectorId, squad)
		if travelCtx.route and not newCalculatedRoute then
			travelCtx.route_valid = travelCtx.route
		end
		travelCtx.route = newCalculatedRoute
		
		local squadWin = self.squad_to_wnd[squad.UniqueId]; assert(squadWin)
		local oldRoute = squad.route
		local newRoute = travelCtx.route
		if newRoute then -- When plotting a route from a halfway position the squad needs to recenter as diagonal movements are not allowed.
			local nextStepIsSame = oldRoute and not oldRoute.center_old_movement and newRoute and table.get(oldRoute, 1, 1) == table.get(newRoute, 1, 1)
			local nextStepIsSameDirection = oldRoute and not oldRoute.center_old_movement and newRoute and table.get(oldRoute, 1, 1) == table.get(newRoute, 1, 1)
			local needToRecenter = not nextStepIsSame and not IsSquadInSectorVisually(squad, squad.CurrentSector)
			
			-- Dont recenter if going to move in the same direction we were already moving
			if needToRecenter then
				-- Get direction we're going to move in
				local nextSector = table.get(newRoute, 1, 1)
				local nextSectorY, nextSectorX = sector_unpack(nextSector)
				local currentSector = squad.CurrentSector
				local curSectorY, curSectorX = sector_unpack(currentSector)
				local dX, dY = (nextSectorX - curSectorX), (nextSectorY - curSectorY)
				
				-- Direction squad has moved in
				local squadVisualPos = GetSquadVisualPos(squad)
				local currentSectorVisPos = gv_Sectors[squad.CurrentSector].XMapPosition
				local visualDiff = Normalize(squadVisualPos - currentSectorVisPos)
				local normX = visualDiff:x()
				local normY = visualDiff:y()
				
				-- Convert to [-1,1]
				local visualDiff01X, visualDiff01Y = 0, 0
				if normX > 0 then
					visualDiff01X = 1
				elseif normX < 0 then
					visualDiff01X = -1
				end
				if normY > 0 then
					visualDiff01Y = 1
				elseif normY < 0 then
					visualDiff01Y = -1
				end

				if dX == visualDiff01X and dY == visualDiff01Y then
					needToRecenter = false
				end
			end
			
			newRoute.center_old_movement = needToRecenter
		end
		
		travelCtx.dest = sectorId
		squadWin:DisplayRoute("main", squad.CurrentSector, newRoute)
		
		-- If invalid route show a fake route end decoration
		if not newRoute then
			local fakeEndingShownRoute = {}
			squadWin.routes_displayed["main"] = fakeEndingShownRoute

			local uimap = squadWin.map
			local endDecoration = XTemplateSpawn("SquadRouteDecoration", uimap)
			if uimap.window_state == "open" and endDecoration.window_state ~= "open" then endDecoration:Open() end
			endDecoration:SetRouteEnd(sectorId, sectorId, true)
			endDecoration:SetColor(GameColors.Enemy)
			endDecoration:SetVisible(true)
			
			fakeEndingShownRoute.decorations = { endDecoration }
		end
		
		local routeHashMap = {}
		for i, wp in ipairs(newRoute) do
			for _, sId in ipairs(wp) do
				routeHashMap[sId] = true
			end
		end
		for sId, wnd in pairs(self.sector_to_wnd) do
			wnd:ShowTravelBlockLines(routeHashMap[sId])
		end
	else
		self.travel_mode.destination_choice = true
		Msg("TravelModeChanged")
	end
	ObjModified(self.travel_mode)
end

local function lCloseSatelliteContextMenu()
	if g_SatelliteUI then
		g_SatelliteUI:RemoveContextMenu()
	end
end

OnMsg.SquadStartedTravelling = lCloseSatelliteContextMenu
OnMsg.SquadStoppedTravelling = lCloseSatelliteContextMenu

-- If starting travel from an underground sector the squad will automatically go on the upper sector.
-- In this case we want to switch the ui to the upper sector.
function OnMsg.SquadStartedTravelling(s)
	if g_SatelliteUI and s and s.Side == "player1" then
		local sectorId = s.CurrentSector
		local win = g_SatelliteUI.sector_to_wnd[sectorId]
		if win and not win.visible then
			local undergroundSectorId = sectorId .. "_Underground"
			local undergroundSectorWindow = g_SatelliteUI.sector_to_wnd[undergroundSectorId]
			if undergroundSectorWindow and undergroundSectorWindow.visible then
				local button = undergroundSectorWindow.idUnderground
				if button then
					button:SwapSector()
				end
			end
		end
	end
end

----

DefineClass.GuardpostSpawnTimer = {
	__parents = { "XContextWindow" },
	IdNode = true
}

function GuardpostSpawnTimer:Open()
	XContextWindow.Open(self)
	self:CreateThread("guardpost", function()
		while not self.context do
			Sleep(100)
		end
		local sector =  gv_Sectors[self.context.SectorId]
		while self.window_state ~= "destroying" do
			local hasSpawn = self.context.next_spawn_time and self.context.next_spawn_time_duration
			hasSpawn = hasSpawn and sector.Side == "enemy1" or sector.Side == "enemy2"
			hasSpawn = hasSpawn and not not self.context.target_sector_id
			local timeRemaining = hasSpawn and self.context.next_spawn_time - Game.CampaignTime
			hasSpawn = hasSpawn and timeRemaining > 0 and timeRemaining < const.Satellite.GuardPostShowTimer
			self:SetVisible(not not hasSpawn)
			if hasSpawn then
				local percent = 1000 - MulDivRound(timeRemaining, 1000, const.Satellite.GuardPostShowTimer)
				self:SetBar(percent)
			end

			Sleep(1000)
		end
	end)
end

function GuardpostSpawnTimer:SetBar(percent)
	local bar = self.idBar
	if not bar then return end
	local totalTicks = #bar
	local currentTick = MulDivRound(percent, totalTicks, 1000)
	bar:Update(currentTick)
end

table.insert(GridMarker.properties,
	{
		id = "EasySetupButtons",
		category = "Enabled Logic",
		editor = "buttons",
		buttons = { { name = "Disable on WorldFlip", func = "SetDefenderMarkerWorldFlipFilter" } },
   }
)

table.insert(GridMarker.properties,
	{
		id = "DespawnEasySetupButtons",
		sort_order = 10,
		category = "Spawn Object",
		editor = "buttons",
		buttons = { { name = "Despawn on WorldFlip", func = "SetMarkerDespawnWorldFlipFilter" } },
   }
)


function SetDefenderMarkerWorldFlipFilter(_, marker)
	if not marker.EnabledConditions then marker.EnabledConditions = {} end
	table.insert(marker.EnabledConditions,
		QuestIsVariableBool:new({
			QuestId = "04_Betrayal",
			Vars = set({
				TriggerWorldFlip = false
			}),
		})
	)
	ObjModified(marker)
end

function SetMarkerDespawnWorldFlipFilter(_, marker)
	if not marker.Despawn_Conditions then marker.Despawn_Conditions = {} end
	table.insert(marker.Despawn_Conditions,
		QuestIsVariableBool:new({
			QuestId = "04_Betrayal",
			Vars = set({
				TriggerWorldFlip = true
			}),
		})
	)
	ObjModified(marker)
end

DefineClass.PostWorldFlipDefenderMarker = {
	__parents = { "GridMarker" },
	Type = "Defender"
}

function PostWorldFlipDefenderMarker:Init()
	self:SetColor(RGBA(0, 105, 205, 255))
	self.Groups = { "PostWorldFlip" }
	self.EnabledConditions = {
		QuestIsVariableBool:new({
			QuestId = "04_Betrayal",
			Vars = set( "TriggerWorldFlip" ),
		})
	}
end

function PostWorldFlipDefenderMarker:UpdateVisuals()
	self:UpdateText(false)
end

DefineClass.PostWorldFlipDefenderPriorityMarker = {
	__parents = { "PostWorldFlipDefenderMarker" },
	Type = "DefenderPriority"
}

function XSatelliteViewMap:InitCacheOfShortcutSquads()
	local cache = {}
	for i, s in ipairs(g_SquadsArray) do
		if IsTraversingShortcut(s) and s.Side ~= "player1" then
			cache[#cache + 1] = s
		end
	end
	self.squads_in_shorcuts = cache
end

function OnMsg.SquadStartTraversingShortcut(squad)
	if g_SatelliteUI and g_SatelliteUI.squads_in_shorcuts and squad and squad.Side ~= "player1" then
		table.insert(g_SatelliteUI.squads_in_shorcuts, squad)
	end
end

function OnMsg.SquadSectorChanged(squad)
	if g_SatelliteUI and g_SatelliteUI.squads_in_shorcuts and squad and squad.Side ~= "player1" then
		table.remove_value(g_SatelliteUI.squads_in_shorcuts, squad)
	end
end

function UIGetSquadsInShortcutsHere(sectorWin)
	local result = false
	if g_SatelliteUI and g_SatelliteUI.squads_in_shorcuts then
		for i, s in ipairs(g_SatelliteUI.squads_in_shorcuts) do
			local win = g_SatelliteUI.squad_to_wnd[s.UniqueId]
			local pos = win and win:GetVisualPos()
			if pos and pos:InBox(sectorWin.box) then
				if not result then result = {} end
				result[#result + 1] = s
			end
		end
	end
	return result
end

function OpenSectorStashUIForSector(sectorId)
	local selSquad = g_SatelliteUI.selected_squad
	if not selSquad then return end

	local actualInventory = GetSectorInventory(sectorId)
	local _, squadHere = AnyPlayerSquadsInSector(sectorId)
	if not squadHere then
		squadHere = selSquad
	end
	local firstUnit = squadHere.units and squadHere.units[1]
	OpenInventory(gv_UnitData[firstUnit], actualInventory)
end

function GenerateEmptySector(sector_id)
	return SatelliteSector:new{
		Id = sector_id,
		Label1 = "Blocked",
		Side = "neutral",
		StickySide = true,
		TerrainType = "Highlands",
		Passability = "Blocked",
		Intel = false,
		MusicCombat = "Battle_Normal",
		MusicConflict = "Cursed_Conflict",
		MusicExploration = "Cursed_Exploration",
		
		name = sector_id,
		generated = true, -- generated sectors won't be saved in the campaign, and are re-generated automatically upon load
	}
end
