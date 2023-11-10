function GetSatelliteTravelQuestion(squad)
	if not g_SatelliteUI then return end
	squad = squad or g_SatelliteUI.selected_squad 
	if not squad then return end
	
	local popupHost = GetParentOfKind(g_SatelliteUI, "PDAClass")
	popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
	local questionBox = CreateQuestionBox(
		popupHost,
		T(131922143067, "Cancel Travel"),
		T{616508183961, "Are you sure you want to command <em><u(squadName)></em> to stop traveling?", squadName = squad.Name},
		T(814633909510, "Confirm"),
		T(6879, "Cancel")
	)
	PauseCampaignTime("Popup")
	local resp = questionBox:Wait()
	ResumeCampaignTime("Popup")
	return resp
end

CancelTravelThread = false
function SatelliteCancelTravelSelectedSquad(squad)
	-- Prevent double popups
	if IsValidThread(CancelTravelThread) and CancelTravelThread ~= CurrentThread() then
		return
	end

	if not CanYield() then
		CancelTravelThread = CreateRealTimeThread(SatelliteCancelTravelSelectedSquad, squad)
		return
	else
		CancelTravelThread = CurrentThread()
	end

	local satDiag = GetSatelliteDialog()
	if not satDiag then
		return
	end

	squad = squad or satDiag.selected_squad
	if not squad or CanCancelSatelliteSquadTravel(squad) ~= "enabled" then
		return
	end
	
	local resp = GetSatelliteTravelQuestion(squad)
	if resp ~= "ok" then return end
	
	if g_SatelliteUI and g_SatelliteUI.travel_mode then
		g_SatelliteUI:ExitTravelMode()
	end
	NetSyncEvent("SquadCancelTravel", squad.UniqueId)
end

function HasWaterTravel(route)
	for _, sector_id in ipairs(route) do
		if gv_Sectors[sector_id].Passability == "Water" then
			return true
		end
	end
	return false
end

function SatelliteCanTravelState(squad, sector_id)
	if not squad then
		squad = GetSatelliteContextMenuValidSquad()
	end	
	if not squad then
		return "hidden"
	end
	if type(squad) == "number" then squad = gv_Squads[squad] end

	if not squad.CurrentSector or squad.arrival_squad then
		return "disabled", T(539764240872, "Arriving squad can not travel")
	end
	
	if squad.CurrentSector == sector_id then
		return "disabled", T(496881909491, "Squad already on this sector.")
	end	

	if squad.returning_water_travel then
		return "disabled"
	end

	return "enabled"
end

function SquadTravelCancelled(squad)
	if not squad then return false end
	if not squad.route or not squad.route[1] then return false end
	if squad.route[1]["returning_land_travel"] then return true end
	if squad.returning_water_travel then return true end
	return false
end

function CanCancelSatelliteSquadTravel(squad)
	squad = squad or GetSatelliteContextMenuValidSquad()
	if not squad or not squad.route or not squad.route[1] then
		return "hidden"
	end

	if squad.Retreat then
		return "disabled"
	end
	
	local travelCancelled = SquadTravelCancelled(squad)
	if travelCancelled then
		return "hidden"
	end
	
	if not IsSquadTravelling(squad, "tick_regardless") then
		return "hidden"
	end

	return "enabled"
end

-- Global functions and helpers for satellite squad travel
-- Some UI implementation as well - everything that's mega travel specific

function CabinetInTravelMode()
	return not not (g_SatelliteUI and g_SatelliteUI.travel_mode)
end

function GenerateSquadRoute(route, landRoute, toSectorId, squad)
	route = route or {}
	
	local removedWaypoint = false
	if route.displayedSectionEnd then
		removedWaypoint = table.remove(route, #route)
	end
	
	local lastWp = route[#route]
	if lastWp and toSectorId == lastWp[#lastWp] then
		route.displayedSectionEnd = false
		return route, landRoute
	end
	
	local origin = GetSquadFinalDestination(squad.CurrentSector, route)
	local routePf = GenerateRouteDijkstra(origin, toSectorId, route, squad.units, nil, squad.CurrentSector, squad.Side)
	
	if not routePf then -- No route found (this includes water), retry using "all" pathfinding which will ignore ports.
		routePf = GenerateRouteDijkstra(origin, toSectorId, route, squad.units, "all", squad.CurrentSector, squad.Side)
		if routePf then
			local firstWaterSector = table.findfirst(routePf, function(idx, sectorId) return gv_Sectors[sectorId].Passability == "Water" end)
			route.no_boat = routePf[firstWaterSector] or toSectorId
		end
	else
		route.no_boat = false
	end
	
	if not routePf then
		-- No route found, but restore waypoint as not to have modified the route object.
		if removedWaypoint then route[#route + 1] = removedWaypoint end
		return false
	end
	
	if routePf then
		route[#route + 1] = routePf
		route.displayedSectionEnd = toSectorId
	end
	
	return route, landRoute
end

DefineClass.SquadRouteDecoration = {
	__parents = { "XMapObject", "XImage" },
	HAlign = "center",
	VAlign = "center",
	HandleMouse = false,
	Image = "UI/Icons/SateliteView/move_background",
	ImageFit = "stretch",
	UseClipBox = false,
	MinWidth = 64,
	MinHeight = 64,
	MaxWidth = 64,
	MaxHeight = 64,
	ZOrder = 1,
	
	sector = false,
	sector_two = false,
	mode = false,
	waypoint_idx = false,
}

function SquadRouteDecoration:Open()
	local icon = XTemplateSpawn("XImage", self)
	icon:SetId("idIcon")
	icon:SetUseClipBox(false)
	icon:SetImage("UI/Icons/SateliteView/move_arrow")
	icon:SetDock("box")
	icon:SetMargins(box(5,5,5,5))
	icon:SetImageFit("stretch")
	XImage.Open(self)
end

function SquadRouteDecoration:OnSetRollover(...)
	return XMapObject.OnSetRollover(self, ...)
end

function SquadRouteDecoration:OnMouseButtonDown(pt, button)
	if button == "L" and terminal.IsKeyPressed(const.vkShift) and self.mode == "waypoint" then -- Remove waypoint.
		local travelCtx = g_SatelliteUI.travel_mode
		local route = travelCtx.route
		local squad = g_SatelliteUI.travel_mode.squad
		local startSectorId, endSectorId, waypoints = squad.CurrentSector, route.displayedSectionEnd, {}
		
		-- Get waypoints, except one being removed.
		for i, r in ipairs(route) do
			if i ~= self.waypoint_idx then
				waypoints[#waypoints + 1] = r[#r]
			end
		end
		
		-- Recalculate paths between waypoints left.
		local newRoute = {}
		local previousSector = startSectorId
		for i, w in ipairs(waypoints) do
			newRoute[#newRoute + 1] = GenerateRouteDijkstra(previousSector, w, newRoute, squad.units, nil, squad.CurrentSector, squad.Side)
			previousSector = w
		end
		newRoute.displayedSectionEnd = endSectorId
		
		g_SatelliteUI.travel_mode.route = newRoute
		g_SatelliteUI:TravelDestinationSelect(endSectorId)
	end
end

function SquadRouteDecoration:EnsureSquadIcon(squadMode)
	local shouldHaveSquadMode = not not squadMode
	local hasSquadMode = not not self.idSquadIcon
	if hasSquadMode ~= shouldHaveSquadMode then
		if shouldHaveSquadMode then
			local squadIcon = XTemplateSpawn("SatelliteIconCombined", self,
				SubContext(squadMode, { side = squadMode.Side, squad = squadMode.UniqueId, map = true })
			)
			squadIcon:SetUseClipBox(false)
			squadIcon:SetId("idSquadIcon")
			squadIcon:SetZOrder(-1)
			squadIcon:SetHAlign("center")
			squadIcon:SetVAlign("center")
			self.ScaleWithMap = false
			self.UpdateZoom = XMapWindow.UpdateZoom

			squadIcon.idBase:SetImageColor(RGBA(255, 255, 255, 190))
			squadIcon.idUpperIcon:SetImageColor(RGBA(255, 255, 255, 190))
			if self.window_state == "open" then squadIcon:Open() end
		else
			self.idSquadIcon:Close()
			self.ScaleWithMap = true
			self.UpdateZoom = XMapWindow.UpdateZoom
		end
	end
end

function SquadRouteDecoration:SetRouteEnd(sectorFromId, sectorToId, invalidRoute, squadMode)
	self:EnsureSquadIcon(squadMode)
	self.sector = sectorToId
	self.sector_two = false
	self.mode = "end"
	self.HandleMouse = false
	
	if invalidRoute then
		self.idIcon:SetImage("UI/Icons/SateliteView/move_disable")
		self.idIcon:SetFlipX(false)
		self.idIcon:SetFlipY(false)
	else
		local curY, curX = sector_unpack(sectorToId)
		local preY, preX
		if IsPoint(sectorFromId) then
			preX, preY = sectorFromId:xy()
		else
			preY, preX = sector_unpack(sectorFromId)
		end

		if curX > preX then -- Right
			self.idIcon:SetImage("UI/Icons/SateliteView/move_arrow")
			self.idIcon:SetFlipX(false)
		elseif curX < preX then -- Left
			self.idIcon:SetImage("UI/Icons/SateliteView/move_arrow")
			self.idIcon:SetFlipX(true)
		elseif curY > preY then -- Down
			self.idIcon:SetImage("UI/Icons/SateliteView/move_arrow_vertical")
			self.idIcon:SetFlipY(false)
		elseif curY < preY then -- Up
			self.idIcon:SetImage("UI/Icons/SateliteView/move_arrow_vertical")
			self.idIcon:SetFlipY(true)
		end
	end
	
	if squadMode then
		self:SetImage("")
		self.idIcon:SetImage("")

		self:SetWidth(9999)
		self:SetHeight(9999)
		self:SetZOrder(1)
	else
		self:SetImage("UI/Icons/SateliteView/move_background")
		self:SetWidth(64)
		self:SetHeight(64)
		self:SetZOrder(2)
	end

	self:InvalidateLayout()
	self:InvalidateMeasure()

	local sector = gv_Sectors[sectorToId]
	self.PosX, self.PosY = sector.XMapPosition:xy()
end

function SquadRouteDecoration:SetCorner(sectorId)
	self:EnsureSquadIcon(false)
	self:SetZOrder(1)
	
	self.sector = sectorId
	self.sector_two = false
	self.mode = "corner"
	self.HandleMouse = false
	self:SetImage("UI/Icons/SateliteView/move_background")
	self.idIcon:SetImage("")
	self:SetWidth(40)
	self:SetHeight(40)
	self:InvalidateLayout()
	self:InvalidateMeasure()
	
	local sector = gv_Sectors[sectorId]
	self.PosX, self.PosY = sector.XMapPosition:xy()
end

function SquadRouteDecoration:SetWaypoint(sectorId, waypointIdx)
	self:EnsureSquadIcon(false)
	self:SetZOrder(1)
	
	self.sector = sectorId
	self.sector_two = false
	self.mode = "waypoint"
	self.waypoint_idx = waypointIdx
	self.HandleMouse = true
	self:SetImage("UI/Icons/SateliteView/move_background")
	self.idIcon:SetImage("UI/Icons/SateliteView/move_dot")
	self:SetWidth(64)
	self:SetHeight(64)
	self:InvalidateLayout()
	self:InvalidateMeasure()
	
	local sector = gv_Sectors[sectorId]
	self.PosX, self.PosY = sector.XMapPosition:xy()
end

function SquadRouteDecoration:SetPort(position, routeColor, portData)
	self:EnsureSquadIcon(false)
	self:SetZOrder(1)

	local sectorId = portData.port_sector
	local disabled = gv_Sectors[sectorId].PortLocked

	local sectorOne = portData.sector_one
	local sectorTwo = portData.sector_two

	self.sector = sectorOne
	self.sector_two = sectorTwo
	
	self.mode = "port"
	self.waypoint_idx = false
	self.HandleMouse = true
	self.idIcon:SetImage("UI/Icons/SateliteView/port")
	self.idIcon.Angle = 0
	self.idIcon:SetFlipY(false)
	self:SetWidth(72)
	self:SetHeight(72)
	self:SetImageColor(white)
	self:SetDesaturation(disabled and 255 or 0)
	self:InvalidateLayout()
	self:InvalidateMeasure()
	
	if routeColor == GameColors.Player then
		self:SetImage("UI/Icons/SateliteView/icon_ally_2")
	elseif routeColor == GameColors.Enemy then
		self:SetImage("UI/Icons/SateliteView/icon_enemy_2")
	elseif routeColor == GameColors.Yellow then
		self:SetImage("UI/Icons/SateliteView/squad_path_2")
	end

	self.PosX, self.PosY = position:xy()
end

function SquadRouteDecoration:SetColor(color)
	self:SetImageColor(color)
	self:SetDesaturation(0)
end

function SquadRouteDecoration:DrawWindow(...)
	if self.measure_update then return end
	return XMapObject.DrawWindow(self, ...)
end

DefineClass.SquadRouteSegment = {
	__parents = { "XMapObject" },
	HAlign = "left",
	VAlign = "top",
	HandleMouse = false,
	ZOrder = 0, -- Destroy last and draw below all icons.
	
	sectorFromId = false,
	sectorToId = false,
	direction = false,
	
	pointOne = false,
	pointTwo = false,
}

function SquadRouteSegment:SetDisplayedSection(sectorFromId, sectorToId, squad)
	self.sectorFromId = sectorFromId
	self.sectorToId = sectorToId

	local uimap = self.map

	-- Determine route direction
	local curY, curX = sector_unpack(sectorToId)
	local preY, preX = sector_unpack(sectorFromId)
	if curX > preX then -- Right
		self.direction = "right"
	elseif curX < preX then -- Left
		self.direction = "left"
	elseif curY > preY then -- Down
		self.direction = "down"
	elseif curY < preY then -- Up
		self.direction = "up"
	else
		self.PosX, self.PosY = 0, 0
		self.direction = "none"
	end
	
	local _, __, ___, ____, startWidth, startHeight, startX, startY = self:GetInterpParams()
	self.PosX = startX
	self.PosY = startY
	self:SetSize(startWidth, startHeight)
end

function SquadRouteSegment:SetBox(...)
	XMapObject.SetBox(self, ...)
	self:RecalcLines()
end

function SquadRouteSegment:RecalcLines()
	local height = self.MaxHeight
	local width = self.MaxWidth
	local direction = self.direction
	if direction == "right" then
		self.pointOne = point(self.PosX, self.PosY + height / 2)
		self.pointTwo = point(self.PosX + width, self.PosY + height / 2)
	elseif direction == "left" then
		self.pointTwo = point(self.PosX, self.PosY + height / 2)
		self.pointOne = point(self.PosX + width, self.PosY + height / 2)
	elseif direction == "down" then
		self.pointOne = point(self.PosX + width / 2, self.PosY)
		self.pointTwo = point(self.PosX + width / 2, self.PosY + height)
	elseif direction == "up" then
		self.pointTwo = point(self.PosX + width / 2, self.PosY)
		self.pointOne = point(self.PosX + width / 2, self.PosY + height)
	end
end

function SquadRouteSegment:GetInterpParams()
	local interpWidth, interpHeight, interpOriginX, interpOriginY = 0, 0, "left", "top"
	local startWidth, startHeight = 0, 0
	local startX, startY = 0, 0
	local direction = self.direction
	local uimap = self.map
	if direction == "right" then
	
		-- When travelling right we support typeof(sectorFromId) == point
		-- because of "arriving" travel
		local sectorWindow = uimap.sector_to_wnd[self.sectorFromId]
		if IsPoint(self.sectorFromId) then
			startX, startY = self.sectorFromId:xy()
			
			local endSectorWindow = uimap.sector_to_wnd[self.sectorToId]
			local endSectorX = endSectorWindow:GetSectorCenter()
			
			startWidth = endSectorX - startX
		else
			startX, startY = sectorWindow:GetSectorCenter()
			startWidth = uimap.sector_size:x()
		end
		
		startHeight = 10

		interpHeight = startHeight
		interpOriginX = "right"
		
		startY = startY - startHeight / 2
	elseif direction == "left" then
		local sectorWindow = uimap.sector_to_wnd[self.sectorToId]
		startX, startY = sectorWindow:GetSectorCenter()
	
		startWidth = uimap.sector_size:x()
		startHeight = 10

		interpHeight = startHeight
		interpOriginX = "left"
		
		startY = startY - startHeight / 2
	elseif direction == "down" then
		local sectorWindow = uimap.sector_to_wnd[self.sectorFromId]
		startX, startY = sectorWindow:GetSectorCenter()
	
		startWidth = 10
		startHeight = uimap.sector_size:y()

		interpWidth = startWidth
		interpOriginY = "bottom"
		
		startX = startX - startWidth / 2
	elseif direction == "up" then
		local sectorWindow = uimap.sector_to_wnd[self.sectorToId]
		startX, startY = sectorWindow:GetSectorCenter()
	
		startWidth = 10
		startHeight = uimap.sector_size:y()

		interpWidth = startWidth
		interpOriginY = "top"
		
		startX = startX - startWidth / 2
	end

	return interpWidth, interpHeight, interpOriginX, interpOriginY, startWidth, startHeight, startX, startY
end

function SquadRouteSegment:StartReducing(time, percentOfTotal)
	local interpWidth, interpHeight, interpOriginX, interpOriginY = self:GetInterpParams()
	if percentOfTotal ~= 1000 then
		interpWidth = Lerp(self.MaxWidth, interpWidth, percentOfTotal, 1000)
		interpHeight = Lerp(self.MaxHeight, interpHeight, percentOfTotal, 1000)
	end
	self:SetSize(interpWidth, interpHeight, time, interpOriginX, interpOriginY)
end

function SquadRouteSegment:FastForwardToSquadPos(squadPos, dont_move)
	local sectorTo = gv_Sectors[self.sectorToId]
	local sectorGoingToPos = sectorTo.XMapPosition
	local diffX, diffY = (sectorGoingToPos - squadPos):xy()
	diffX = abs(diffX)
	diffY = abs(diffY)
	
	local direction = self.direction
	if direction == "right" then
		if not dont_move then
			self.PosX = self.PosX + self.MaxWidth - diffX
		end
		self:SetWidth(diffX)
	elseif direction == "left" then
		self:SetWidth(diffX)
	elseif direction == "down" then
		if not dont_move then
			self.PosY = self.PosY + self.MaxHeight - diffY
		end
		self:SetHeight(diffY)
	elseif direction == "up" then
		self:SetHeight(diffY)
	end
	self:InvalidateMeasure()
	self:InvalidateLayout()
end

function SquadRouteSegment:ResumeReduction(squadPos, time, dont_move)
	self:FastForwardToSquadPos(squadPos, dont_move)
	local interpWidth, interpHeight, interpOriginX, interpOriginY, startWidth, startHeight = self:GetInterpParams()
	local x, y, timeLeft = self:GetContinueInterpolationParams(startWidth, startHeight, interpWidth, interpHeight, time, point(self.MaxWidth, self.MaxHeight))
	if x then
		--timeLeft = 0
		--x, y = interpWidth, interpHeight
		self:SetSize(x, y, timeLeft, interpOriginX, interpOriginY)
	end
end

function SquadRouteSegment:DrawBackground()
	if not self.pointOne then return end
	if self.direction == "none" then return end
	
	local scaledWidth = ScaleXY(self.scale, 12)
	local scaledWidthSmaller = ScaleXY(self.scale, 10)
	
	UIL.DrawLineAntialised(scaledWidth, self.pointOne, self.pointTwo, GameColors.D)
	UIL.DrawLineAntialised(scaledWidthSmaller, self.pointOne, self.pointTwo, self.Background)
end

DefineClass.SquadRouteShortcutSegment = {
	__parents = { "SquadRouteSegment" },
	shortcut = false,
	progress = 0,
	reversed = false,
	squadWnd = false
}

function SquadRouteShortcutSegment:SetDisplayShortcut(shortcut, squadWnd, reversed, isCurrent)
	-- Figure out the current progress
	local progress = 0
	local squad = squadWnd.context
	if squad and squad.traversing_shortcut_start and isCurrent then
		local travelTime = shortcut:GetTravelTime()
		local arrivalTime = squad.traversing_shortcut_start + travelTime
		local timeLeft = arrivalTime - Game.CampaignTime
		local percent = MulDivRound(timeLeft, 1000, travelTime)
		if not reversed then percent = 1000 - percent end
		progress = percent
	else
		reversed = false
	end
	
	self.shortcut = shortcut
	self.progress = progress
	self.reversed = reversed
	self.squadWnd = squadWnd
end

function SquadRouteShortcutSegment:SetShortcutProgress(progress, reversed)
	self.progress = progress
	self.reversed = not not reversed
end

function SquadRouteShortcutSegment:DrawBackground()
	if not self.shortcut then return end

	local shortcutPreset = self.shortcut
	local path = shortcutPreset:GetPath()
	local resolution = 100
	local increment = 1000 / resolution
	
	local startVal = self.progress
	local endVal = 1000
	
	if self.reversed then
		startVal = 0
		endVal = self.progress
	end
	
	for i = startVal, endVal, increment do
		local pt1 = GetShortcutCurvePointAt(path, i)
		local pt2 = GetShortcutCurvePointAt(path, i + increment)
		UIL.DrawLineAntialised(12, pt1, pt2, GameColors.D)
	end
	
	for i = startVal, endVal, increment do
		local pt1 = GetShortcutCurvePointAt(path, i)
		local pt2 = GetShortcutCurvePointAt(path, i + increment)
		UIL.DrawLineAntialised(10, pt1, pt2, self.Background)
	end
end

function OnMsg.SquadStartedTravelling(squad)
	if not g_SatelliteUI or not squad then return end
	local squadWnd = g_SatelliteUI.squad_to_wnd[squad.UniqueId]
	SquadUIUpdateMovement(squadWnd)
end

function OnMsg.SquadStoppedTravelling(squad)
	if not g_SatelliteUI or not squad then return end
	local squadWnd = g_SatelliteUI.squad_to_wnd[squad.UniqueId]
	if not squadWnd then return end
	SquadUIUpdateMovement(squadWnd)
end

function NetSyncEvents.RestartMovementThread(squadId)
	local squad = gv_Squads[squadId]
	if not g_SatelliteUI or not squad then return end
	local squadWnd = g_SatelliteUI.squad_to_wnd[squad.UniqueId]
	SquadUIUpdateMovement(squadWnd)
end
	
function OnMsg.ConflictEnd()
	if not g_SatelliteUI then return end
	for _, squad in pairs(gv_Squads) do
		local squadWnd = g_SatelliteUI.squad_to_wnd[squad.UniqueId]
		if squadWnd then
			SquadUIUpdateMovement(squadWnd)
		end
	end
end

function IsSquadWaterTravelling(squad)
	return squad.water_route or squad.traversing_shortcut_water or squad.water_travel
end

local function lUpdateSquadBoatIcon(squad)
	local squadWnd = g_SatelliteUI and g_SatelliteUI.squad_to_wnd[squad.UniqueId]
	if not squadWnd then return end
	squadWnd.idWaterTravel:SetVisible(IsSquadWaterTravelling(squad))
end

function OnMsg.SquadSectorChanged(squad)
	lUpdateSquadBoatIcon(squad)
end

function OnMsg.ReachSectorCenter(squadId)
	local squad = gv_Squads[squadId]
	lUpdateSquadBoatIcon(squad)
end

function OnMsg.SquadStartTraversingShortcut(squad)
	lUpdateSquadBoatIcon(squad)
end

function OnMsg.SquadStartedTravelling(squad)
	lUpdateSquadBoatIcon(squad)
end

function OnMsg.ReachSectorCenter(squadId)
	local squad = gv_Squads[squadId]
	if not squad then return end
	
	-- ReachSectorCenter is also called before spawn when a new squad appears.
	local squadWnd = g_SatelliteUI and g_SatelliteUI.squad_to_wnd[squad.UniqueId]
	if not squadWnd then
		if squad.CurrentSector and not squad.XVisualPos then
			squad.XVisualPos = gv_Sectors[squad.CurrentSector].XMapPosition
		end
		return
	end

	local sectorId = squad.CurrentSector
	local sectorPos = gv_Sectors[sectorId].XMapPosition
	-- this is for teleport (such as from conflict start or a cheat)
	-- and other reach sector center events that aren't raised from within travel logic
	if not IsSquadTravelling(squad) then
		squadWnd:SetPos(sectorPos:x(), sectorPos:y())
		squadWnd:SetAnim(false)

		if squadWnd:GetThread("sat-movement") ~= CurrentThread() then
			squadWnd:DeleteThread("sat-movement")
			
			-- Remove travel destructor since teleporation came from another thread
			-- while this squad was travelling and the sector set could be a different one
			-- from the one captured in the travel destructor's closure.
			rawset(squadWnd, "GetTravelPos", nil)
		end
	end
	
	squadWnd:DisplayRoute("main", sectorId, squad.route)
end

function OnMsg.SquadWaitInSectorChanged(squad)
	if squad.wait_in_sector then return end

	local squadWnd = g_SatelliteUI and g_SatelliteUI.squad_to_wnd[squad.UniqueId]
	if not squadWnd then return end
	SquadUIUpdateMovement(squadWnd)
end

local function lMapObjectWaitForGotoPos(wnd, pos, time, route_line)
	--print("lMapObjectWaitForGotoPos START", GetCampHumanTime(), time, pos, wnd.PosX, wnd.PosY, wnd:GetVisualPos())
	if time == 0 then
		wnd:SetPos(pos:x(), pos:y())
		return
	end
	
	local targetTime = Game.CampaignTime + time
	local startTime = Game.CampaignTime
	local startPos = wnd:GetTravelPos()
	local travel = pos - startPos
	
	local currentThread = CurrentThread()
	local function getPosFromTime()
		local elapsed = Min(Game.CampaignTime, targetTime)- startTime
		local ret = startPos + MulDivRound(travel, elapsed, time)
		-- Destructor of sorts
		if not IsValidThread(currentThread) then
			wnd:SetPos(ret:xy())
			rawset(wnd, "GetTravelPos", nil)
			return wnd:GetTravelPos()
		end
	
		return ret
	end

	rawset(wnd, "GetTravelPos", function(self)
		return getPosFromTime() --this will save proper pos when closing sat view / saving
	end)
	wnd:SetPos(getPosFromTime():xy())
	wnd:SetPos(pos:x(), pos:y(), time)
	
	while true do
		WaitMsg("CampaignTimeAdvanced")
		if targetTime <= Game.CampaignTime then
			break
		end
	end
	wnd:SetPos(getPosFromTime():xy())
	rawset(wnd, "GetTravelPos", nil) --get from meta for non moving objects
	assert(Game.CampaignTime - targetTime == 0) -- oh no
end

function SquadCantMove(squad)
	if squad.wait_in_sector then return true end
	if #squad.units == 0 then return true end
	if IsSquadInConflict(squad) and not squad.Retreat then return true end
	if HasTiredMember(squad, "Exhausted") and not squad.Retreat then return "tired" end
	return false
end

function ArrivingSquadTravelThread(squad)
	local sectorId = squad.CurrentSector
	local sY, sX = sector_unpack(sectorId)
	local sectorPos = gv_Sectors[sectorId].XMapPosition

	local leftMostSectorId = sector_pack(sY, 1)
	local leftMostSector = gv_Sectors[leftMostSectorId]
	local leftMostPos = leftMostSector.XMapPosition
	
	local lmX, lmY = leftMostPos:xy()
	lmX = lmX - 1000
	
	local destX, destY = sectorPos:xy()

	local totalTime = SectorOperations.Arriving:ProgressCompleteThreshold()
	local timeLeft = GetOperationTimeLeft(gv_UnitData[squad.units[1]], "Arriving")

	local percentPassed = MulDivRound(timeLeft, 1000, totalTime)
	local curPosX = Lerp(destX, lmX, timeLeft, totalTime)
	local curPosY = Lerp(destY, lmY, timeLeft, totalTime)
	
	local squadWnd = g_SatelliteUI.squad_to_wnd[squad.UniqueId]
	squadWnd:SetPos(curPosX, curPosY)
	squadWnd:SetPos(destX, destY, timeLeft)
	
	local routeSegment = XTemplateSpawn("SquadRouteSegment", g_SatelliteUI)
	if g_SatelliteUI.window_state == "open" then
		routeSegment:Open()
	end
	
	local routeEndDecoration = XTemplateSpawn("SquadRouteDecoration", g_SatelliteUI)
	if g_SatelliteUI.window_state == "open" then
		routeEndDecoration:Open()
	end
	routeEndDecoration:SetRouteEnd(point(0, sY), sectorId)
	routeEndDecoration:SetColor(GameColors.Player)
	
	if not squadWnd.routes_displayed then squadWnd.routes_displayed = {} end
	squadWnd.routes_displayed["main"] = {
		routeSegment,
		decorations = {
			routeEndDecoration
		}
	}
	
	routeSegment.direction = "right"
	routeSegment.sectorToId = sectorId
	routeSegment.sectorFromId = point(lmX, lmY)
	
	local _, __, ___, ____, startWidth, startHeight, startX, startY = routeSegment:GetInterpParams()
	routeSegment.PosX = startX
	routeSegment.PosY = startY
	routeSegment:SetSize(startWidth, startHeight)
	routeSegment:FastForwardToSquadPos(point(curPosX, curPosY))
	routeSegment:StartReducing(timeLeft, 1000)
	routeSegment:SetBackground(GameColors.Player)
end

function SquadUIUpdateMovement(squadWnd)
	local lateLayoutThread = squadWnd:GetThread("late-layout")
	if lateLayoutThread and CurrentThread() ~= lateLayoutThread then
		squadWnd:DeleteThread(lateLayoutThread)
	end

	squadWnd:DeleteThread("sat-movement")
	squadWnd:CreateThread("sat-movement", SquadUIMovementThread, squadWnd)
end

-- Travel between some sectors is instant, but we don't want squads to look like they're teleporting
-- so this is the minimum time a travel can take visually. Going between sectors in tactical view will
-- still be instant.
lMinVisualTravelTime = const.Scale.min*20

-- Performs a WaitMsg on CampaignTimeAdvanced but the threads are woken up in a determistic order.
-- No need to clear this as the threads are ui and they'll be cleaned up automatically.
if FirstLoad then
g_WaitingMovementThreads = false
end

function OrderedWait_CampaignTimeAdvanced(squadId)
	if not g_WaitingMovementThreads then g_WaitingMovementThreads = {} end
	
	local handle = {}
	local thread = CurrentThread()
	g_WaitingMovementThreads[#g_WaitingMovementThreads + 1] = { thread = thread, sId = squadId, handle = handle }
	WaitMsg(handle)
end

function OnMsg.CampaignTimeAdvanced()
	if not g_WaitingMovementThreads then return end
	table.sortby_field(g_WaitingMovementThreads, "sId")
	for i, entry in ipairs(g_WaitingMovementThreads) do
		local handle = entry.handle
		local thread = entry.thread
		if IsValidThread(thread) then
			Msg(handle)
		end
	end
	g_WaitingMovementThreads = false
end

-- When testing routes there are four cases to consider.
-- 1. Normal A to B
-- 2. Cancel Travel (X while squad is travelling - squad:CancelTravel) [route[1].returning_land_travel]
-- 3. Same as above, but while the squad is on a water sector. [squad.returning_water_travel]
-- 4. Setting a new route for the squad after it has passed the sector boundary, but hasn't reached the center yet. (route.center_old_movement)
-- 5. While a squad is traveling close and open the satellite view. Depending on the side of the sector boundary the squad is on the props will be different.
-- 	5.1. Before the sector boundary you are in a case similiar to (4) but the squad shouldn't move towards the center.
--		5.2. After the sector boundary you are in a case similar to (2).
-- Cases 2 and 3 and 5.1 are the only cases in which the squad's current sector is present in the route array.
-- The route array is an array of waypoints, and each waypoint is an array of sectors.
function SquadUIMovementThread(squadWnd)
	local squad = squadWnd.context
	local playerSquad = squad.Side == "player1" or squad.Side == "player2"
	local currentSectorId = squad.CurrentSector
	if not currentSectorId then -- Secret route, don't animate
		squadWnd:SetVisible(false)
		return
	end

	local currentSector = gv_Sectors[currentSectorId]	
	local visualPos = squadWnd:GetTravelPos()
	
	squadWnd.desktop:RequestLayout()
	Sleep(0) -- Wait for the squad UI to layout (just yield so that satellite time doesnt advance)
	
	-- Special animation from outside the map for arriving units
	if squad.arrival_squad then
		ArrivingSquadTravelThread(squad)
		return
	end
	
	squadWnd:DisplayRoute("main", currentSectorId, squad.route)
	if not squad.route or #squad.route == 0 then return end
	squadWnd.desktop:RequestLayout()
	Sleep(0) -- Wait for the route UI to layout
	
	-- It is possible for a route to be assigned and the campaign to instantly
	-- pause via the "auto-pause: squad movement" option.
	-- It's good to wait for unpause before displaying the exhausted and other popups.
	while IsCampaignPaused() do
		WaitMsg("CampaignSpeedChanged", 100)
	end
	
	-- Check if cant move due to gameplay reasons
	local cantMove = SquadCantMove(squad)
	if cantMove == "tired" and LocalPlayerHasAuthorityOverSquad(squad) then
		-- If cant move due to tired, ask the player to resolve
		-- this will either end in a split or cancel travel.
		-- (Needs to be in a thread as travel thread can be killed)
		CreateRealTimeThread(function()
			local shouldTravel = AskForExhaustedUnits(squad)
			if shouldTravel then
				NetSyncEvent("RestartMovementThread", squad.UniqueId)
			else
				NetSyncEvent("SquadCancelTravel", squad.UniqueId)
			end
		end)
	end
	
	if cantMove then
		return
	end
	
	local routeLocalCopy = {}
	for _, route in ipairs(squad.route) do
		routeLocalCopy[#routeLocalCopy + 1] = table.copy(route)
	end
	
	-- Display route from where squad reached
	local firstWaypoint = routeLocalCopy[1]
	local firstIsntShortcut = not firstWaypoint.shortcuts or not firstWaypoint.shortcuts[1]
	local routeDisplay = squadWnd.routes_displayed["main"]
	local firstSegment = routeDisplay[1]
	if firstSegment and firstIsntShortcut then
		firstSegment:FastForwardToSquadPos(visualPos)
	end
	
	-- Waiting on this sync event msg will cause this thread to sync up
	-- This usually happens when lMapObjectWaitForGotoPos is called but
	-- we want to sync this thread beforehand as we modify the sync state
	--WaitMsg("CampaignTimeAdvanced")
	OrderedWait_CampaignTimeAdvanced(squad.UniqueId)
	
	-- Set the squad as travelling
	NetUpdateHash("SetSquadTravellingActivity", squad.UniqueId)
	SetSquadTravellingActivity(squad)
	
	-- Resuming travel from mid sector position (after middle).
	if routeDisplay.extra_visual_segment then
		local currSectorPos = currentSector.XMapPosition
		local previousSectorId = GetSquadPrevSector(visualPos, currentSectorId, currSectorPos)
		local time = GetSectorTravelTime(previousSectorId, currentSectorId, routeLocalCopy, squad.units, nil, nil, squad.Side)
		local time_orig = time
		time = Max(time, lMinVisualTravelTime) -- if the travel is instant, make a quick transition
		local prevSecX, prevSecY = gv_Sectors[previousSectorId].XMapPosition:xy()
		local x, y, timeLeft = squadWnd:GetContinueInterpolationParams(prevSecX, prevSecY, currSectorPos:x(), currSectorPos:y(), time, visualPos)
		timeLeft = timeLeft and DivCeil(timeLeft, const.Scale.min) * const.Scale.min
		NetUpdateHash("SquadTravelResumeRoute", squad.UniqueId, visualPos, currSectorPos, time_orig, time, timeLeft, Game.CampaignTime)
		-- Resume route display from mid sector position too.
		if routeDisplay and #routeDisplay > 0 then
			local firstSegment = routeDisplay[1]
			firstSegment:ResumeReduction(visualPos, time)
		end
		
		assert(timeLeft)
		if timeLeft then
			lMapObjectWaitForGotoPos(squadWnd, point(x, y), timeLeft)
		else -- Fallback, this will prob never happen, but is theoretically possible
			lMapObjectWaitForGotoPos(squadWnd, currSectorPos, 0)
		end
		
		local dontUpdateRoute = not routeDisplay.extra_in_route
		NetUpdateHash("SatelliteReachSectorCenter", Game.CampaignTime, squad.UniqueId)
		SatelliteReachSectorCenter(squad.UniqueId, currentSectorId, previousSectorId, dontUpdateRoute)
		
		-- Re-copy route now that it has been modified
		if not dontUpdateRoute then
			routeLocalCopy = {}
			for _, route in ipairs(squad.route) do
				routeLocalCopy[#routeLocalCopy + 1] = table.copy(route)
			end
		end
		
		-- Stopped travelling
		if SquadCantMove(squad) then
			return
		end
	end

	local pricePerSector = 0
	for i, section in ipairs(routeLocalCopy) do
		for j, sector in ipairs(section) do
			local prevSectorId = squad.CurrentSector
			local prevSector = gv_Sectors[prevSectorId]
			local prevSectorPos = prevSector.XMapPosition
			
			local nextSectorId = sector
			local nextSector = gv_Sectors[nextSectorId]
			local nextSectorPos = nextSector.XMapPosition
	
			if section.shortcuts and section.shortcuts[j] then -- Shortcut travel
				local shortcut, reversedShortcut = GetShortcutByStartEnd(prevSectorId, nextSectorId)
				
				-- Make sure deleted shortcuts don't break old saves
				if not shortcut then
					assert(false) -- Missing shortcut
					SetSatelliteSquadCurrentSector(squad, nextSectorId, "update-pos")
					SatelliteReachSectorCenter(squad.UniqueId, nextSectorId, prevSectorId)
					return
				end

				squad.traversing_shortcut_water = shortcut.water_shortcut
							
				routeDisplay = squadWnd.routes_displayed["main"]
				local shortcutSegment = routeDisplay.shortcuts[1]
				
				local travelTime = shortcut:GetTravelTime()
				local timeResolution = const.Satellite.Tick
				
				local waterPrevSector = reversedShortcut and shortcut.shortcut_direction_entrance_sector or shortcut.shortcut_direction_exit_sector
				
				-- We can only interpolate in increments of satellite tick, but we
				-- actually dont need to check if the travel time can be divided by it
				-- since the only difference would be a very small jump towards the end,
				-- which is not noticable.
				--assert(travelTime % timeResolution == 0)
				assert(travelTime % const.Scale.min == 0)
				
				if not squad.traversing_shortcut_start then
					NetUpdateHash("SatelliteStartShortcutMovement", Game.CampaignTime, squad.UniqueId)
					SatelliteStartShortcutMovement(squad.UniqueId, Game.CampaignTime, squad.CurrentSector)
				else
					local arrivalTime = squad.traversing_shortcut_start + travelTime
					local timeLeft = arrivalTime - Game.CampaignTime
					if timeLeft < 0 then -- Already passed?
						print("shortcut resume messed up")
					else
						local percent = MulDivRound(timeLeft, 1000, travelTime)
						if not reversedShortcut then percent = 1000 - percent end
						shortcutSegment:SetShortcutProgress(percent, reversedShortcut)
					end
				end
				
				local arrivalTime = squad.traversing_shortcut_start + travelTime				
				local path = shortcut:GetPath()
				
				while Game.CampaignTime < arrivalTime do
					local timeLeft = arrivalTime - Game.CampaignTime
					local interpolateTime = timeResolution
					local leftOverTime = timeLeft % interpolateTime -- When saving/loading it could be out of sync with resolution
					if leftOverTime ~= 0 then
						interpolateTime = leftOverTime
					end
					
					local percent = MulDivRound(timeLeft, 1000, travelTime)
					if not reversedShortcut then percent = 1000 - percent end
					local pt1 = GetShortcutCurvePointAt(path, percent)
					
					local percentNext = MulDivRound(timeLeft - interpolateTime, 1000, travelTime)
					if not reversedShortcut then percentNext = 1000 - percentNext end
					local pt2 = GetShortcutCurvePointAt(path, percentNext)
					
					squadWnd:SetPos(pt1:x(), pt1:y(), false)
					squad.XVisualPos = pt1
					
					lMapObjectWaitForGotoPos(squadWnd, pt2, interpolateTime)
					shortcutSegment:SetShortcutProgress(percentNext, reversedShortcut)
				end
				
				if Game.CampaignTime - arrivalTime ~= 0 then
					print("shortcut ended early/late", Game.CampaignTime - arrivalTime)
				end
				
				NetUpdateHash("SatelliteReachSector", Game.CampaignTime, squad.UniqueId)
				SetSatelliteSquadCurrentSector(squad, nextSectorId, "update-pos", false, waterPrevSector)
			elseif ((prevSectorPos - nextSectorPos):Len() / 2) > 0 then -- Normal travel of dist > 0
				local _, time1, time2 = GetSectorTravelTime(prevSectorId, nextSectorId, squad.route, squad.units, nil, nil, squad.Side)
				time1 = Max(time1, lMinVisualTravelTime);
				time2 = Max(time2, lMinVisualTravelTime)
				local middle = (prevSectorPos + nextSectorPos) / 2
				
				-- Resuming on first part (before middle)
				local originalTime1 = time1
				local squadVisPos = squadWnd:GetTravelPos()
				local prevSecX, prevSecY = gv_Sectors[prevSectorId].XMapPosition:xy()
				if squadVisPos:x() ~= prevSecX or squadVisPos:y() ~= prevSecY then
					local midX, midY = middle:xy()
					local x, y, timeLeft = squadWnd:GetContinueInterpolationParams(prevSecX, prevSecY, midX, midY, time1, squadVisPos)
					timeLeft = timeLeft and DivCeil(timeLeft, const.Scale.min) * const.Scale.min
					time1 = timeLeft or lMinVisualTravelTime
				end

				routeDisplay = squadWnd.routes_displayed["main"]
				firstSegment = table.find_value(routeDisplay, "sectorFromId", prevSectorId)
				if firstSegment then
					assert(firstSegment.sectorFromId == prevSectorId and firstSegment.sectorToId == nextSectorId)
					assert(firstSegment.window_state == "open")
					firstSegment:StartReducing(originalTime1, 500)
				end

				lMapObjectWaitForGotoPos(squadWnd, middle, time1)
				
				-- Remove port icon when going over it.
				local routeDecor = squadWnd.routes_displayed["main"]
				routeDecor = routeDecor and routeDecor.decorations
				local compact = false
				for i, dec in ipairs(routeDecor) do
					if dec.mode == "port" then
						local here = (dec.sector == nextSectorId and dec.sector_two == prevSectorId) or
										(dec.sector_two == nextSectorId and dec.sector == prevSectorId)
						if here then
							dec:Close()
							routeDecor[i] = nil
							compact = true
						end
					end
				end
				if compact then table.compact(routeDecor) end
				
				-- Water cost checks.
				if squad.returning_water_travel then -- Don't charge if cancelled travel.
					squad.water_travel_cost = nil
				else
					-- Get the cost from the port we just left
					if prevSector.Passability == "Land and Water" and prevSector.Port and not prevSector.PortLocked then
						if nextSector.Passability == "Water" then
							squad.water_travel_cost = prevSector:GetTravelPrice(squad)
						end
					end
					if nextSector.Passability == "Water" then
						if squad.water_travel_cost and playerSquad then
							AddMoney(-squad.water_travel_cost, "expense")
						end
					else
						squad.water_travel_cost = nil
					end
				end
				NetUpdateHash("SatelliteReachSector", Game.CampaignTime, squad.UniqueId)
				SetSatelliteSquadCurrentSector(squad, nextSectorId)
				
				-- It is possible for the squad to have been destroyed on reaching the sector
				-- boundary. Such case occurs when a "joining squad" and the squad it is joining both cross over
				-- into a conflict and they get teleported to the sector center.
				if squadWnd.window_state == "destroying" then
					assert(squad.joining_squad)
					return
				end
				
				-- Reget segment as its possible for the route windows to have been refreshed.
				routeDisplay = squadWnd.routes_displayed["main"]
				firstSegment = table.find_value(routeDisplay, "sectorFromId", prevSectorId)
				if firstSegment then
					assert(firstSegment and firstSegment.sectorFromId == prevSectorId and firstSegment.sectorToId == nextSectorId)
					assert(firstSegment.window_state == "open")
					firstSegment:StartReducing(time2, 1000)
				end
				
				lMapObjectWaitForGotoPos(squadWnd, nextSectorPos, time2)
			else -- Not sure when the interpolation time is 0, but it seems the autosave can squeeze in at the very last moment sometimes.
				while IsCampaignPaused() do
					WaitMsg("CampaignSpeedChanged", 100)
				end
			end
			
			NetUpdateHash("SatelliteReachSectorCenter", Game.CampaignTime, squad.UniqueId)
			SatelliteReachSectorCenter(squad.UniqueId, nextSectorId, prevSectorId)

			-- Some stuff triggered by ReachSectorCenter can pause the campaign (popups etc)
			while IsCampaignPaused() do
				WaitMsg("CampaignSpeedChanged", 100)
			end
			
			ObjModified(nextSector)
			ObjModified(prevSector)
			
			-- Despawned squad (joined) or started waiting.
			if SquadCantMove(squad) then
				return
			end
			
			-- Route removed, delete visualization.
			-- Squad is probably removed as well.
			-- Happens when a "joining squad" reaches the squad they're joining (triggered on a movement event).
			if not squad.route then
				if squadWnd.window_state ~= "destroying" then squadWnd:DisplayRoute("main") end
				return
			end
		end
	end
end

function GetSquadPrevSector(vis_pos, next_sector_id, next_sector_pos)
	local dir_vector = vis_pos - next_sector_pos
	local x, y = dir_vector:xy()
	local abs_x = abs(x)
	local abs_y = abs(y)
	local dir
	if x >= 0 and x >= abs_y then
		dir = "East"
	elseif x < 0 and -x >= abs_y then
		dir = "West"
	elseif y >= 0 and y >=	abs_x then
		dir = "South"
	elseif y < 0 and -y >=	abs_x then
		dir = "North"
	end
	assert(dir)
	return GetNeighborSector(next_sector_id, dir)
end

local function lGetSectorTerrainTypeUI(sector, waypoint, routeIdx, prevSector)
	local terrainType = sector and sector.TerrainType
	if sector and sector.Passability == "Water" then terrainType = "Water" end

	if prevSector and AreSectorsSameCity(prevSector, sector) then
		terrainType = "Urban"
	end

	local isShortcut = false
	if waypoint and waypoint.shortcuts and waypoint.shortcuts[routeIdx] then
		local toSector = waypoint[routeIdx]
		local fromSector = prevSector and prevSector.Id or sector and sector.Id
		local shortcutPreset = toSector and fromSector and GetShortcutByStartEnd(toSector, fromSector)

		terrainType = shortcutPreset and shortcutPreset.terrain or "Shortcut"
		isShortcut = true
	end
	return terrainType, isShortcut
end

local function lGetBreakdownHasSpecialTerrainModifier(travelBreakdown)
	local specialTerrainModifier = false
	for i, breakdownEntry in ipairs(travelBreakdown) do
		if breakdownEntry.Category == "sector-special" then
			specialTerrainModifier = breakdownEntry.special
			break
		end
	end
	return specialTerrainModifier
end

local function lAddWaterTravelCostToRouteBreakdown(waterTravelTiles, waterTravelCost, breakdown)
	breakdown[#breakdown + 1] = { Text = T(423059607313, "Cost"), Value = waterTravelTiles * waterTravelCost, Category = "sector", ValueType = "money" } 
end

function GetRouteInfoBreakdown(squad, route)
	route = route or empty_table

	local breakdown = {}
	local forbidden, errs, invalidBecauseOf = IsRouteForbidden(route, squad)
	breakdown.valid = not forbidden
	local invalidSectionMarked = false
	
	-- Get total travel time and modifiers that affect the whole route (such as squad modifiers)
	local total = {}
	local timeTaken, travelBreakdown = GetTotalRouteTravelTime(squad.CurrentSector, route, squad)
	total.travelTime = timeTaken
	total.travelTimeBreakdown = travelBreakdown
	breakdown.total = total
	breakdown.errors = errs
	
	local previousSId = squad.CurrentSector
	local startingSector = gv_Sectors[previousSId]
	local currentSection = {
		start = previousSId,
		dest = previousSId,
		terrain = lGetSectorTerrainTypeUI(startingSector, route[1], 1),
		travelTime = 0,
		travelTimeBreakdown = false,
	}
	breakdown[#breakdown + 1] = currentSection

	-- Add breakdown to first section in case the terrain type changes on the first sector
	local nextSectorId = route[1] and route[1][1]
	local _, __, ___, fillBreakdown = GetSectorTravelTime(currentSection.start, nextSectorId, false, squad.units, nil, nil, squad.Side)
	currentSection.travelTimeBreakdown = fillBreakdown
	local specialMod = lGetBreakdownHasSpecialTerrainModifier(fillBreakdown)
	currentSection.terrainSpecial = specialMod
	
	local waterTravelCost, waterTravelTiles = 0, 0
	for w = 1, #route do
		local waypoint = route[w]
	
		for i = 1, #waypoint do
			local sId = waypoint[i]
			local sector = gv_Sectors[sId]
			local prevSector = gv_Sectors[previousSId]

			local terrainType, isShortcut = lGetSectorTerrainTypeUI(sector, waypoint, i, prevSector)
			local terrainChanged = currentSection.terrain ~= terrainType
			
			if terrainChanged and currentSection.terrain == "Water" and not currentSection.landing_set_to_water then
				terrainChanged = false
				terrainType = "Water"
				currentSection.landing_set_to_water = true
			end
			
			local total, firstHalf, secondHalf, travelBreakdown = GetSectorTravelTime(previousSId, sId, false, squad.units, nil, nil, squad.Side)
			
			if total then
				if not firstHalf or firstHalf == 0 then
					firstHalf = Max(firstHalf or 0, lMinVisualTravelTime)
					secondHalf = Max(secondHalf or 0, lMinVisualTravelTime)
				else
					secondHalf = secondHalf or 0
				end
			else
				firstHalf = 0
				secondHalf = 0
			end
			
			local specialTerrainModifier = lGetBreakdownHasSpecialTerrainModifier(travelBreakdown)
			if currentSection.terrainSpecial ~= specialTerrainModifier then
				terrainChanged = true
			end
			
			if terrainChanged then
				currentSection.travelTime = currentSection.travelTime + firstHalf
				
				-- Stopping water travel, add cost to current section (which is the water section)
				if waterTravelCost > 0 then
					local prevBreakdown = currentSection.travelTimeBreakdown or {}
					lAddWaterTravelCostToRouteBreakdown(waterTravelTiles, waterTravelCost, prevBreakdown)
					waterTravelCost = 0
				end
				
				currentSection.dest = sId
				
				-- We mark the previous section as invalid due to the current sector
				-- rather than the section which led to error, which is more intuitive for the UI 
				if invalidBecauseOf == sId then
					currentSection.invalid = true
					invalidSectionMarked = true
				end
				
				currentSection = {
					start = sId,
					dest = sId,
					terrain = terrainType,
					travelTime = secondHalf,
					travelTimeBreakdown = travelBreakdown,
					terrainSpecial = specialTerrainModifier
				}
				breakdown[#breakdown + 1] = currentSection
			else
				currentSection.travelTime = currentSection.travelTime + (firstHalf + secondHalf)
				currentSection.dest = sId
				
				-- Breakdown should be the same for all sectors of the same terrain type.
				-- Note: except where there are special terrain modifiers (road etc)
				-- which we treat as different terrain
				if travelBreakdown and #travelBreakdown > 0 then
					currentSection.travelTimeBreakdown = travelBreakdown
				end
			end
			
			-- Check if this section is on a boat
			if sector then
				if prevSector.Passability == "Land and Water" and prevSector.Port and not prevSector.PortLocked then
					if sector.Passability == "Water" then
						waterTravelCost = prevSector:GetTravelPrice(squad)
						waterTravelTiles = 0
					end
				end
				-- Continuing water travel
				if sector.Passability == "Water" and waterTravelCost > 0 then
					waterTravelTiles = waterTravelTiles + 1
				end
			end
			
			previousSId = sId
		end
	end
	
	if waterTravelCost > 0 then
		lAddWaterTravelCostToRouteBreakdown(waterTravelTiles, waterTravelCost, currentSection.travelTimeBreakdown or {})
	end
	if not invalidSectionMarked then
		currentSection.invalid = invalidBecauseOf == previousSId
	end
	
	--[[	local verify = 0
	for i, b in ipairs(breakdown) do
		local time = b and b.travelTime
		verify = verify + time
	end
	print("time diff", squad.CurrentSector, prevSectorId, "is", verify - total.travelTime)]]
	
	return breakdown
end

function GetHalfwaySectorPoint(idOne, idTwo)
	local s1 = gv_Sectors[idOne].XMapPosition
	local s2 = gv_Sectors[idTwo].XMapPosition

	local dist = s1:Dist(s2)
	if dist == 0 then
		return point20
	end

	local dir = s2 - s1
	return s1 + SetLen(dir, dist / 2)
end

-- Percent is 0-1000
function GetShortcutCurvePointAt(path, percentOfPath)
	local precision = 1000

	local pathLength = #path - 1
	local indexBetweenPoints = 1 + ((percentOfPath * pathLength) / precision)
	indexBetweenPoints = Min(indexBetweenPoints, pathLength)
	indexBetweenPoints = Max(indexBetweenPoints, 1)

	local p1 = path[indexBetweenPoints]
	local p2 = path[indexBetweenPoints + 1]
	
	local placeBetweenPoints
	if percentOfPath >= precision then
		placeBetweenPoints = precision
	else
		local percentBetween = (percentOfPath * pathLength)
		placeBetweenPoints = percentBetween % precision
	end

	local prevPoint = path[indexBetweenPoints - 1] or path[indexBetweenPoints]
	local nextPoint = path[indexBetweenPoints + 2] or path[indexBetweenPoints + 1]
	return CatmullRomSpline(prevPoint, p1, p2, nextPoint, placeBetweenPoints, precision), indexBetweenPoints
end

function GetShortcutByStartEnd(startSectorId, endSectorId)
	local foundShorcut, foundIsReverse = false, false
	ForEachPreset("SatelliteShortcutPreset", function(shortcut)
		if not shortcut:GetShortcutEnabled() then return end
	
		local rightWay = shortcut.start_sector == startSectorId and shortcut.end_sector == endSectorId
		local reverseWay = shortcut.start_sector == endSectorId and shortcut.end_sector == startSectorId
	
		if rightWay or reverseWay then
			foundShorcut, foundIsReverse = shortcut, reverseWay
			return "break"
		end
	end)
	
	return foundShorcut, foundIsReverse
end

function GetShortcutsAtSector(sectorId, force_twoway)
	local shortcuts = false

	ForEachPreset("SatelliteShortcutPreset", function(shortcut)
		if not shortcut:GetShortcutEnabled() then return end
	
		local here = shortcut.start_sector == sectorId or (shortcut.end_sector == sectorId and (not shortcut.one_way or force_twoway))
		if here then
			if not shortcuts then shortcuts = {} end
			shortcuts[#shortcuts + 1] = shortcut
		end
	end)

	return shortcuts
end

function IsTraversingShortcut(squad, regardlessSatelliteTickPassed)
	if regardlessSatelliteTickPassed then
		local route = squad.route
		return route and route[1] and route[1].shortcuts and route[1].shortcuts[1]
	end

	return not not squad.traversing_shortcut_start
end

function IsRiverSector(sectorId, force_two_way)
	return not not GetShortcutsAtSector(sectorId, force_two_way)
end

DefineConstInt("SatelliteShortcut", "RiverTravelTime", 56, "min", "How many minutes it takes to travel one sector of river")