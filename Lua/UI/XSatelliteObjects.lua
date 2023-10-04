-- ZOrder Guide
-- -1: Underground image
-- 0: Route segments
-- 1: Route decorations (corners, end)
-- 2: SectorWindow and children (Buildings etc)
-- 3: Squads
-- 4: Conflict Icon (Squad in disguise)

DefineClass.SectorWindow = {
	__parents = { "XMapWindow", "XContextWindow" },
	HandleMouse = true,
	BorderWidth = 5,
	BorderColor = RGBA(255, 255, 255, 255),
	IdNode = true,
	ZOrder = 2,

	HAlign = "left",
	VAlign = "top",
	
	SectorVisible = true,
	
	--RolloverTemplate = "ZuluContextMenu",
	RolloverAnchor = "right",
	RolloverBackground = RGBA(255, 255, 255, 0),
	PressedBackground = RGBA(255, 255, 255, 0),
	RolloverOffset = box(20, 0, 0, 0),
}

DefineClass.SectorUndergroundImage = {
	__parents = { "XMapWindow", "XImage" },
	
	Clip = false,
	UseClipBox = false,
	HAlign = "left",
	VAlign = "top",
	ZOrder = -1
}

function TFormat.cityLoyaltyConditional(ctx, cityId)
	local loyalty = GetCityLoyalty(cityId)
	if not loyalty or loyalty <= 0 then
		return false
	end
	if not gv_PlayerCityCounts or not gv_PlayerCityCounts.cities or not gv_PlayerCityCounts.cities[cityId] then
		return false
	end
	return Untranslated(" (" .. tostring(loyalty) .. "%)")
end

function SectorWindow:Open()
	local text = false
	local city = self.context.City
	if city ~= "none" and self.context.ShowCity then
		local cityPreset = gv_Cities[city]
		text = cityPreset.DisplayName
	end
	
	if text then
		local txt = XTemplateSpawn("XText", self, gv_Cities[city])
		txt:SetTranslate(true)
		txt:SetText(T{547402413356, "<cityName><cityLoyaltyConditional(city)>", {cityName = text, city = city }})
		txt:SetUseClipBox(false)
		txt:SetTextStyle("CityName")
		txt:SetId("idLoayalty")
		txt:SetHAlign("center")
		txt:SetVAlign("top")
		txt:SetMargins(box(0, 5, 0, 0))
		txt:SetClip(false)
		txt:SetHandleMouse(false)
		txt:SetZOrder(2)
	end
	
	if self.context.Passability == "Blocked" then
		local img = XTemplateSpawn("XImage", self)
		img:SetImage("UI/SatelliteView/sector_empty")
		img:SetDock("box")
		img:SetClip(false)
		img:SetUseClipBox(false)
		img:SetZOrder(-1)
	end
	
	if true then
		local icon = XTemplateSpawn("XMapRollerableContextImage", self)
		icon.Clip = false
		icon.UseClipBox = false
		icon:SetId("idIntelMarker")
		icon:SetImage("UI/Icons/SateliteView/icon_neutral")
		icon:SetHAlign("left")
		icon:SetVAlign("bottom")
		icon:SetVisible(false)
		icon:SetMargins(box(10, 10, 10, 10))
		icon:SetRolloverTemplate("RolloverGeneric")
		icon:SetRolloverText(T(230411316470, "Intel acquired."))
		icon:SetRolloverOffset(box(20, 0, 0, 0))
		icon.HandleMouse = true
		
		local iicon = XTemplateSpawn("XImage", icon)
		iicon.Clip = false
		iicon.UseClipBox = false
		iicon.Margins = box(0, 0, 0, 0)
		iicon.VAlign = "center"
		iicon.HAlign = "center"
		iicon.MinHeight = 25
		iicon.MaxHeight = 25
		iicon:SetImage("UI/Icons/SateliteView/intel_missing")
	end
	
	-- Is an underground sector
	if self.context.GroundSector then
		local img = XTemplateSpawn("SectorUndergroundImage", self.parent)
		img.PosX = self.PosX
		img.PosY = self.PosY
		img.MinWidth = self.MinWidth
		img.MaxWidth = self.MaxWidth
		img.MinHeight = self.MinHeight
		img.MaxHeight = self.MaxHeight
		img:SetVisible(self.visible)
		self.idUndergroundImage = img
	elseif self.context.Passability ~= "Blocked" then
		local sectorId = self.context.Id
		local north = GetNeighborSector(sectorId, "North")
		local east = GetNeighborSector(sectorId, "East")
		local south = GetNeighborSector(sectorId, "South")
		local west = GetNeighborSector(sectorId, "West")
	
		local horizontal = "UI/SatelliteView/sector_borders_accessibility_x"
		local vertical = "UI/SatelliteView/sector_borders_accessibility_y"
		
		local container = XTemplateSpawn("XWindow", self)
		container:SetDock("box")
		container:SetClip(false)
		container:SetUseClipBox(false)
		container:SetId("idTravelBlocked")
		container:SetVisible(false)
		container:SetZOrder(-1)
		
		if north and IsTravelBlocked(sectorId, north) then
			local lineImg = XTemplateSpawn("XImage", container)
			lineImg:SetImage(horizontal)
			lineImg:SetClip(false)
			lineImg:SetUseClipBox(false)
			lineImg:SetVAlign("top")
			lineImg:SetMargins(box(0, -6, 0, 0))
		end
		
		if south and IsTravelBlocked(sectorId, south) then
			local lineImg = XTemplateSpawn("XImage", container)
			lineImg:SetImage(horizontal)
			lineImg:SetClip(false)
			lineImg:SetUseClipBox(false)
			lineImg:SetVAlign("bottom")
			lineImg:SetMargins(box(0, 0, 0, -6))
		end
		
		if east and IsTravelBlocked(sectorId, east) then
			local lineImg = XTemplateSpawn("XImage", container)
			lineImg:SetImage(vertical)
			lineImg:SetClip(false)
			lineImg:SetUseClipBox(false)
			lineImg:SetHAlign("right")
			lineImg:SetMargins(box(0, 0, -6, 0))
		end
		
		if west and IsTravelBlocked(sectorId, west) then
			local lineImg = XTemplateSpawn("XImage", container)
			lineImg:SetImage(vertical)
			lineImg:SetClip(false)
			lineImg:SetUseClipBox(false)
			lineImg:SetHAlign("left")
			lineImg:SetMargins(box(-6, 0, 0, 0))
		end
	elseif self.context.Passability ~= "Blocked" then -- Old travel blocked art
		-- Build mask
		local sectorId = self.context.Id
		local north = GetNeighborSector(sectorId, "North")
		local east = GetNeighborSector(sectorId, "East")
		local south = GetNeighborSector(sectorId, "South")
		local west = GetNeighborSector(sectorId, "West")
		
		local mask = ""
		if not north or IsTravelBlocked(sectorId, north) then mask = "X" else mask = "N" end
		if not east or IsTravelBlocked(sectorId, east) then mask = mask .. "X" else mask = mask .. "E" end
		if not south or IsTravelBlocked(sectorId, south) then mask = mask .. "X" else mask = mask .. "S" end
		if not west or IsTravelBlocked(sectorId, west) then mask = mask .. "X" else mask = mask .. "W" end

		local imageData = BlockTravelMasks[mask]
		if imageData then
			local img = XTemplateSpawn("XFrame", self)
			img:SetDock("box")
			img:SetClip(false)
			img:SetUseClipBox(false)
			img:SetId("idTravelBlocked")
			img:SetVisible(false)
			img:SetZOrder(-1)
			
			-- We need to fake the rotation because
			-- rotated windows are not clipped.
			local image = imageData[1]
			local angle = imageData[2]
			if angle == "flip-x" then
				img:SetFlipX(true)
			elseif angle == "flip-y" then
				img:SetFlipY(true)
			end
			
			img:SetImage(image)
			--img:SetAngle(imageData[2])
		end
	end

	XContextWindow.Open(self)
end

BlockTravelMasks = {
	["NESW"] = false,
	
	["NXSW"] = { "UI/SatelliteView/sector_side_1", 0 },
	["XESW"] = { "UI/SatelliteView/sector_side_1_90", "flip-y" }, --270
	["NEXW"] = { "UI/SatelliteView/sector_side_1_90", 0 }, --90
	["NESX"] = { "UI/SatelliteView/sector_side_1", "flip-x" }, --180

	["XESX"] = { "UI/SatelliteView/sector_side_2", 0 },
	["XXSW"] = { "UI/SatelliteView/sector_side_2_90", 0 }, --90
	["NXXW"] = { "UI/SatelliteView/sector_side_2_90", "flip-y" }, --180
	["NEXX"] = { "UI/SatelliteView/sector_side_2", "flip-y" }, --270
	
	["NXSX"] = { "UI/SatelliteView/sector_side_2B", 0 }, 
	["XEXW"] = { "UI/SatelliteView/sector_side_2B_90", 0 }, --90
	
	["XXXW"] = { "UI/SatelliteView/sector_side_3", 0 },
	["NXXX"] = { "UI/SatelliteView/sector_side_3_90", 90 * 60 }, --90
	["XEXX"] = { "UI/SatelliteView/sector_side_3", "flip-x" }, --180
	["XXSX"] = { "UI/SatelliteView/sector_side_3_90", "flip-y" }, --270
}

function SectorWindow:GetRolloverText()
	return self.context
end

function SectorWindow:OnSetRollover(rollover)
	PlayFX("SectorRollover", rollover and "start" or "end")
	SectorRolloverShowGuardpostRoute(rollover and self.context)
	return self.map:OnSectorRollover(self, self.context, rollover)
end

function SectorWindow:OnMouseButtonDown(pt, button)
	-- Gamepad virtual cursor will right click when X is pressed,
	-- but we have a shortcut bound to LeftTrigger+X :(
	if GetUIStyleGamepad() then
		local activeGamepad, gamepadId = GetActiveGamepadState()
		local ltHeld = XInput.IsCtrlButtonPressed(gamepadId, "LeftTrigger")
		if ltHeld then return end
	end

	return self.map:OnSectorClick(self, self.context, button)
end

function SectorWindow:ShowTravelBlockLines(travelMode)
	if not self.idTravelBlocked then return end
	self.idTravelBlocked:SetVisible(travelMode)
end

-- Map coordinates
function SectorWindow:GetSectorCenter()
	return self.PosX + self.MaxWidth / 2, self.PosY + self.MaxHeight / 2
end

function SectorWindow:SetSectorVisible(visible)
	self.SectorVisible = visible
	--self:SetBackground(visible and RGBA(0,0,0,0) or RGBA(0, 0, 0, 0))
	self:SetBorderWidth(0)
end

function SectorWindow:UpdateZoom(prevZoom, newZoom, time)
	local map = self.map
	local maxZoom = map:GetScaledMaxZoom()
	if self.idUndergroundIconsList then
		self.idUndergroundIconsList:SetVisible(not self.context.HideUnderground and newZoom > maxZoom / 2)
	end
	if self.idPointOfInterest and IsKindOf(self.idPointOfInterest, "SatelliteSectorIconGuardpostClass") then
		self.idPointOfInterest:SetMiniMode(newZoom <= maxZoom / 2)
	end

	XMapWindow.UpdateZoom(self, prevZoom, newZoom, time)
end

function SectorWindow:SetVisible(visible, ...)
	XMapWindow.SetVisible(self, visible, ...)
	if self.idUndergroundImage then self.idUndergroundImage:SetVisible(visible) end
end

function SectorWindow:OnContextUpdate(context,update)
 --"XMapWindow", "XContextWindow"idLoayalty
 XContextWindow.OnContextUpdate(self, context,update)
 
 	local text = false
	local city = context.City
	if city ~= "none" and context.ShowCity then
		local cityPreset = gv_Cities[city]
		text = cityPreset.DisplayName
	end
	
	if text then
		self.idLoayalty:SetText(T{547402413356, "<cityName><cityLoyaltyConditional(city)>", {cityName = text, city = city }})
	end
end

function DbgClearSectorTexts()
	if not g_SatelliteUI then return end
	for i, sectorWnd in pairs(g_SatelliteUI.sector_to_wnd) do
		if sectorWnd.idDebugText then
			sectorWnd.idDebugText:Close()
		end
	end
end

function DbgAddSectorText(sectorId, text)
	if not g_SatelliteUI then return end
	local sectorWnd = g_SatelliteUI.sector_to_wnd[sectorId]
	if not sectorWnd.idDebugText then
		local txt = XTemplateSpawn("XText", sectorWnd)
		txt:SetId("idDebugText")
		txt:SetText(text)
		txt:SetUseClipBox(false)
		txt:SetTextStyle("CityName")
		txt:SetHAlign("center")
		txt:SetVAlign("top")
		txt:SetMargins(box(0, 50, 0, 0))
		txt:SetClip(false)
		txt.HandleMouse = false
		txt:Open()
	else
		sectorWnd.idDebugText:SetText(text)
	end
end

DefineClass.SquadWindow = {
	__parents = { "XMapObject", "XContextWindow" },
	ZOrder = 3,
	IdNode = true,
	ContextUpdateOnOpen = true,
	ScaleWithMap = false,
	FXMouseIn = "SatelliteBadgeRollover",
	FXPress = "SatelliteBadgePress",
	FXPressDisabled = "SatelliteBadgeDisabled",
	RolloverTemplate = "SquadRolloverMap",
	RolloverAnchor = "top-right",
	RolloverOffset = box(20, 24, 0, 0),
	RolloverBackground = RGBA(255, 255, 255, 0),
	PressedBackground = RGBA(255, 255, 255, 0),

	is_player = false,
	routes_displayed = false,
	
	route_visible = true
}

function SquadWindow:SetBox(x, y, width, height)
	XMapObject.SetBox(self, x, y, width, height)
	
	local imagePaddingX, imagePaddingY = ScaleXY(self.scale, 20, 10)
	width = width - imagePaddingX
	height = height - imagePaddingY
	self.interaction_box = sizebox(x + imagePaddingX / 2, y + imagePaddingY / 2, width, height)
end

function SquadWindow:GetTravelPos()
	return self:GetVisualPos()
end

function SquadWindow:Init()	
	local sel_window = XTemplateSpawn("XWindow", self)
	sel_window:SetUseClipBox(false)
	sel_window:SetId("idSquadSelection")
	sel_window:SetIdNode(true)
	sel_window:SetVisible(false)
	sel_window:SetHAlign("center")
	sel_window:SetVAlign("center")
	
	local r,g,b = GetRGB(GameColors.L)
	local sel_window_back = XFrame:new({
		Margins    = box(-6,-6,-6,-6),
		Background = RGBA( r,g,b, 60),
		UseClipBox = false,
		}, sel_window)
	
	local sel_window_top = XImage:new({
		Id         = "idSquadRollover",
		Image      = "UI/Inventory/T_Backpack_Slot_Small_Hover",
		UseClipBox = false,
		Visible    = false,
		ScaleModifier = point(800,800),
		},
	sel_window)

	local sel_window_sel_small = XFrame:new({
		Id         = "idSquadSelSmall",
		Image      = "UI/Inventory/perk_selected_2",
		Margins    = box(-6,-6,-6,-6),
		UseClipBox = false,
		Visible    = false,
	}, sel_window)

	local sel_window_sel_big = XFrame:new({
		Id         = "idSquadSelBig",
		Image      = "UI/Inventory/perk_selected",
		Margins    = box(-13,-13,-13,-13),
		UseClipBox = false,
		Visible    = false,
	}, sel_window)

	local topRightIndicator = XTemplateSpawn("XWindow", self)
	topRightIndicator:SetHAlign("right")
	topRightIndicator:SetVAlign("top")
	topRightIndicator:SetMargins(box(0,2,2,0))
	topRightIndicator:SetUseClipBox(false)

	local moreSquadsContainer = XWindow:new({
		Margins     = box(0, -8, -8, 0),
		Id          = "idMoreSquads",
		IdNode      = true,
		UseClipBox  = false,
		HandleMouse = false,
	}, topRightIndicator)
	moreSquadsContainer:SetVisible(false)
	
	local inner, base = GetSatelliteIconImages({ squad = self.context.UniqueId, side = self.context.Side, map = true })
	local squadImage = XImage:new({
		UseClipBox   = false,
		Desaturation = 255,
		ImageColor   = GameColors.F,
		Image        = inner,		
	}, moreSquadsContainer)
	
	local innerIconImage = XImage:new({
		UseClipBox   = false,
		Desaturation = 255,
		ImageColor   = GameColors.F,
		Image        = base,
		Margins     = box(0, 2, 2, 0),
	}, moreSquadsContainer)
	
	local waterTravelIcon = XTemplateSpawn("XImage", self)
	waterTravelIcon:SetImage("UI/Icons/SateliteView/travel_water")
	waterTravelIcon:SetHAlign("center")
	waterTravelIcon:SetVAlign("top")
	waterTravelIcon:SetId("idWaterTravel")
	waterTravelIcon:SetUseClipBox(false)
	waterTravelIcon:SetMargins(box(0, -27, 0, 0))
	waterTravelIcon:SetVisible(self.context.water_route or self.context.traversing_shortcut_water)
end

function SquadWindow:Open()
	assert(self.context and IsKindOf(self.context, "SatelliteSquad"))

	self:SetWidth(72)
	self:SetHeight(72)

	local side = self.context.Side
	local is_militia = self.context.militia
	local is_player = side == "player1" or side == "player2"
	self.is_player = is_player
	self:SpawnSquadIcon()
	
	local map = self.map
	if self.context.XVisualPos then
		self.PosX, self.PosY = self.context.XVisualPos:xy()
	else
		local sectorWnd = map.sector_to_wnd[self.context.CurrentSector]
		if sectorWnd then
			self.PosX, self.PosY = sectorWnd:GetSectorCenter()
		end
	end

	XContextWindow.Open(self)

	-- Initialization wait for layout.
	self:CreateThread("late-update", function()
		SquadUIUpdateMovement(self)
		Sleep(25) -- Needs to be after the layout of the (potential) route in SquadUIUpdateMovement
		self:SetAnim(self.rollover)
	end)
end

function SquadWindow:OnDelete()
	if self.routes_displayed then
		for id, windows in pairs(self.routes_displayed) do
			for i, w in ipairs(windows) do
				w:Close()
			end

			for i, w in ipairs(windows.decorations) do
				w:Close()
			end
			
			for i, w in ipairs(windows.shortcuts) do
				w:Close()
			end
		end
		self.routes_displayed = false
	end
end

function SquadWindow:UpdateZoom(prevZoom, newZoom, time)
	local map = self.map
	local maxZoom = map:GetScaledMaxZoom()
	local minZoom = Max(1000 * map.box:sizex() / map.map_size:x(), 1000 * map.box:sizey() / map.map_size:y())
	newZoom = Clamp(newZoom, minZoom + 120, maxZoom)

	XMapWindow.UpdateZoom(self, prevZoom, newZoom, time)
end

function SquadWindow:GetRolloverText()
	return self.context
end

function SquadWindow:SelectionAnim()
	local sel_ctrl = self.idSquadSelection
	local big = sel_ctrl.idSquadSelBig
	if self:IsThreadRunning("select_icon") then
		return
	end	
	self:CreateThread("select_icon",function(big, self)
		big:RemoveModifier("zoom")
		big:AddInterpolation{
			id = "zoom",
			type = const.intRect,
			duration = 100,
			OnLayoutComplete = IntRectCenterRelative,
			originalRect = sizebox(0, 0, 1400, 1400),
			targetRect = sizebox(0, 0, 1000, 1000),
			flags = const.intfInverse,
			autoremove = true,
			force_in_interpbox = "end",
			exclude_from_interpbox = true,
			interpolate_clip = false,
		}
		Sleep(100)
		big:AddInterpolation{
			id = "zoom",
			type = const.intRect,
			duration = 100,
			OnLayoutComplete = function(modifier, window)				
				modifier.originalRect = sizebox(self.PosX, self.PosY, big.box:sizex(), big.box:sizey())
				modifier.targetRect = sizebox(self.PosX, self.PosY, MulDivRound(big.box:sizex(),800, 1000), MulDivRound(big.box:sizey(),800, 1000))
			end,	
			flags = const.intfInverse,
			autoremove = true,
			force_in_interpbox = "end",
			exclude_from_interpbox = true,
			interpolate_clip = false,
		}
	end, big, self)
end

function SquadWindow:SetAnim(rollover)
	local side = self.context.Side
	local is_player = side == "player1" or side == "player2"	
	local sel_ctrl = self.idSquadSelection
	if not is_player then 
		sel_ctrl:SetVisible(rollover)
		sel_ctrl.idSquadRollover:SetVisible(rollover)
		sel_ctrl.idSquadSelSmall:SetVisible(false)
		sel_ctrl.idSquadSelBig:SetVisible(false)
		return 
	end
	
	local selected_squad = g_SatelliteUI.selected_squad
	local is_selected = selected_squad and selected_squad.UniqueId == self.context.UniqueId
	local selectedTravelling = selected_squad and (IsSquadTravelling(selected_squad, true) or selected_squad.arrival_squad)
	local imTravelling = IsSquadTravelling(self.context, true) or self.context.arrival_squad
	if not selectedTravelling and not imTravelling and not is_selected then
		is_selected = selected_squad and selected_squad.CurrentSector == self.context.CurrentSector
	end

	local big = sel_ctrl.idSquadSelBig
	if rollover and not is_selected then
		sel_ctrl:SetVisible(true)
		sel_ctrl.idSquadRollover:SetVisible(true)
		sel_ctrl.idSquadSelSmall:SetVisible(false)
		big:SetVisible(false)
	elseif rollover and is_selected then
		sel_ctrl:SetVisible(true)
		sel_ctrl.idSquadRollover:SetVisible(false)
		sel_ctrl.idSquadSelSmall:SetVisible(true)
		big:SetVisible(true)

		big:AddInterpolation{
			id = "rollover",
			type = const.intRect,
			duration = 200,
			OnLayoutComplete = IntRectCenterRelative,
			targetRect = box(0, 0, 1100, 1100),
			originalRect = box(0, 0, 1000, 1000),
			--flags = const.intfInverse,
			autoremove = true,
			force_in_interpbox = "end",
			exclude_from_interpbox = true,
			interpolate_clip = false,
			--flags = const.intfPingPong + const.intfLooping,
		}
	elseif not rollover and is_selected then
		sel_ctrl:SetVisible(true)
		sel_ctrl.idSquadRollover:SetVisible(false)
		sel_ctrl.idSquadSelSmall:SetVisible(true)
		big:SetVisible(true)
	elseif not rollover and not is_selected then
		sel_ctrl:SetVisible(false)
		sel_ctrl.idSquadRollover:SetVisible(false)
		sel_ctrl.idSquadSelSmall:SetVisible(false)
		big:SetVisible(false)
	end

	if is_selected then
		big:RemoveModifier("rollover")
		
		if not imTravelling then
			local flags = const.intfPingPong + const.intfLooping
			if not rollover then
				flags = const.intfInverse
			end
			
			big:AddInterpolation{
				id = "rollover",
				type = const.intRect,
				duration = 600,
				OnLayoutComplete = IntRectCenterRelative,
				OnWindowMove = IntRectCenterRelative,
				targetRect = box(0, 0, 1100, 1100),
				originalRect = box(0, 0, 1000, 1000),
				flags = flags,
				autoremove = not rollover or nil,
				exclude_from_interpbox = not rollover,
				force_in_interpbox = "end",
				interpolate_clip = false,
				easing = "Sin in"
			}
		end
	end
end

function SquadWindow:OnSetRollover(rollover)
	XContextWindow.OnSetRollover(self,rollover)
	self:SetAnim(rollover)
	
	if self.context.Side == "enemy1" then
		local displayedRoute = self.routes_displayed
		displayedRoute = displayedRoute and displayedRoute["main"]
		if not displayedRoute then return end
		
		for i, w in ipairs(displayedRoute) do
			w:SetBackground(rollover and GameColors.C or GameColors.Enemy)
			w:SetDrawOnTop(rollover)
		end

		for i, w in ipairs(displayedRoute.decorations) do
			if w.mode == "port" then
				w:SetColor(rollover and GameColors.C or white)
			else
				w:SetColor(rollover and GameColors.C or GameColors.Enemy)
			end
			w:SetDrawOnTop(rollover)
		end
		
		for i, w in ipairs(displayedRoute.shortcuts) do
			w:SetBackground(rollover and GameColors.C or GameColors.Enemy)
			w:SetDrawOnTop(rollover)
		end
	end
end

function SquadWindow:CreateRolloverWindow(gamepad, context, pos)
	context = SubContext(self.context,{control = self, anchor = self:ResolveRolloverAnchor(context, pos),gamepad = gamepad})
	local tmpl = self:GetRolloverTemplate()
	if tmpl then
		local win = XTemplateSpawn(tmpl, nil, context)
		if not win then return false end
		win:Open()
		return win
	end
end

function SquadWindow:GetSectorWindow()
	local map = self.map
	local sectorWnd = map.sector_to_wnd[self.context.CurrentSector]
	return sectorWnd
end

function SquadWindow:DrawChildren(...)
	if self.context.CurrentSector and gv_Sectors[self.context.CurrentSector] == self.map.selected_sector then
		local top = XPushShaderEffectModifier("SquadWindowSelected")
		XMapObject.DrawChildren(self, ...)
		UIL.ModifiersSetTop(top)
	else
		XMapObject.DrawChildren(self, ...)
	end
	XMapObject.DrawChildren(self, ...)
end

DefineClass.XMapRollerableContextImage = {
	__parents = { "XMapRolloverable", "XContextImage" }
}

DefineClass.XMapRollerableContext = {
	__parents = { "XMapRolloverable", "XContextWindow" }
}

function SquadWindow:SpawnSquadIcon(parent)
	parent =  parent or self
	local side = self.context.Side
	local is_player = side == "player1" or side == "player2"
	self.is_player = is_player
	local img
	if is_player then
		img = XTemplateSpawn("SatelliteIconCombined", parent, SubContext(self.context, {side = side, squad = is_player and self.context.UniqueId, map = true }))
		img:SetUseClipBox(false)
	else	
		img = XTemplateSpawn("XMapRollerableContextImage", parent, self.context)
		local squad_img = GetSatelliteIconImagesSquad(self.context)
		img:SetImage(squad_img or "UI/Icons/SateliteView/enemy_squad")
		img:SetUseClipBox(false)
	end
	if parent == self then
		img:SetId("idSquadIcon")
	end
	return img
end

function CycleSectorSquads(cur_squad_id,sectorId)
	local ally, enemy = GetSquadsInSector(sectorId)
	if not ally or #ally<=1 then
		return
	end
	local squad_idx = table.find(ally,"UniqueId",cur_squad_id)	
	if not squad_idx then
		return 
	end
	squad_idx = squad_idx + 1
	if squad_idx>#ally then
		squad_idx = 1
	end
	g_SatelliteUI:SelectSquad(ally[squad_idx])
end

function SquadWindow:OnMouseButtonDown(pt, button)
	local sectorId = self.context.CurrentSector
	local sector = gv_Sectors[sectorId]
	
	-- In travel mode just propagate to the sector, which will set the route.
	local sectorWin = self:GetSectorWindow()
	if g_SatelliteUI.travel_mode then
		g_SatelliteUI:OnSectorClick(sectorWin, sectorWin.context, button)
		return
	end
	
	if button == "L" and IsSquadInConflict(self.context) then
		if self.is_player then g_SatelliteUI:SelectSquad(self.context) end
		OpenSatelliteConflictDlg(sector)
		return "break"
	end
	
	if button == "R" then
		g_SatelliteUI:OpenContextMenu(self, self.context.CurrentSector, self.context.UniqueId)
		return "break"
	end
	
	if button == "L" and self.is_player then
		g_SatelliteUI:SelectSquad(self.context)
		g_SatelliteUI:SelectSector(false)
		return "break"
	end

	return self.map:OnSectorClick(sectorWin, sectorWin.context, button)
end

local lRouteEffectTable = {
	id = "glow-in-out",
	type = const.intAlpha,
	startValue = 255, -- Multiplied by the 180 alpha of the color
	endValue = 130,
	duration = 2500,
	flags = bor(const.intfRealTime, const.intfPingPong, const.intfLooping),
	modifier_type = const.modInterpolation,

	interpolate_clip = false
}

function SquadWindow:DisplayRoute(id, start, route)
	assert(self.window_state ~= "destroying")
	if not self.routes_displayed then
		self.routes_displayed = {}
	end
	local routeShown = self.routes_displayed[id]

	-- no new
	if not route or #route == 0 then
		for i, w in ipairs(routeShown) do
			w:Close()
		end
		
		for i, w in ipairs(routeShown and routeShown.decorations) do
			w:Close()
		end
		
		for i, w in ipairs(routeShown and routeShown.shortcuts) do
			w:Close()
		end
		
		table.clear(routeShown)
		return
	end
	
	if not routeShown then
		routeShown = {}
		self.routes_displayed[id] = routeShown
	end
	
	-- Reset metadata
	routeShown.extra_in_route = false
	routeShown.extra_visual_segment = false
	
	local squad = self.context
	local enemySquad = squad and (squad.Side == "enemy1" or squad.Side == "enemy2")
	local invalidRoute = IsRouteForbidden(route, squad)
	-- Currently plotting route.
	local plotting = self.map.travel_mode and self.map.travel_mode.squad == self.context
	local routeColor = (enemySquad or (plotting and invalidRoute)) and GameColors.Enemy or GameColors.Player
	if plotting and not invalidRoute then routeColor = GameColors.Yellow end
	local routeColorNoAlpha = routeColor
	--routeColor = GetColorWithAlpha(routeColor, 180)
	
	-- Reuse as many spawned segments as possible, cuz respawning is laggy
	local windowsUsed, shortcutsUsed, prevWasShortcut = 0, 0, false
	local uimap = self.map
	local previousSector, prePreviousSector = start, false
	local lastMove, turns, waypoints, ports = false, {}, {}, {}
	
	local function lAddRouteSegment(to)
		prevWasShortcut = false
	
		windowsUsed = windowsUsed + 1
		local routeWnd = routeShown[windowsUsed]
		if not routeWnd then
			routeWnd = XTemplateSpawn("SquadRouteSegment", uimap)
			routeShown[#routeShown + 1] = routeWnd
		end
		if uimap.window_state == "open" and routeWnd.window_state ~= "open" then routeWnd:Open() end
		
		local sectorPreset = gv_Sectors[previousSector]
		local nextSectorPreset = gv_Sectors[to]
		if (sectorPreset.Port and nextSectorPreset.Passability == "Water") or
			(nextSectorPreset.Port and sectorPreset.Passability == "Water") then
			local halfway = (sectorPreset.XMapPosition + nextSectorPreset.XMapPosition) / 2
			ports[#ports + 1] = halfway
			ports[halfway] = {
				port_sector = sectorPreset.Port and sectorPreset.Id or nextSectorPreset.Port and nextSectorPreset.Id,
				sector_one = sectorPreset.Id,
				sector_two = nextSectorPreset.Id
			}
		end
		
		assert(previousSector ~= to)
		routeWnd:SetDisplayedSection(previousSector, to, squad)
		routeWnd:SetBackground(routeColor)
		routeWnd:SetVisible(self.route_visible or plotting)
		if windowsUsed == 1 and shortcutsUsed == 0 then
			routeWnd:FastForwardToSquadPos(self:GetVisualPos())
		end
		
		local moveDir = point(sector_unpack(previousSector)) - point(sector_unpack(to))
		if not lastMove then
			lastMove = moveDir
		elseif lastMove ~= moveDir then
			turns[#turns + 1] = previousSector
			lastMove = moveDir
		end
		
		prePreviousSector = previousSector
		previousSector = to
	end
	
	local function lAddShortcutSegment(to)
		if not routeShown.shortcuts then routeShown.shortcuts = {} end
		local shortcutsArray = routeShown.shortcuts
	
		shortcutsUsed = shortcutsUsed + 1
		local routeWnd = shortcutsArray[shortcutsUsed]
		if not routeWnd then
			routeWnd = XTemplateSpawn("SquadRouteShortcutSegment", uimap)
			shortcutsArray[#shortcutsArray + 1] = routeWnd
		end
		if uimap.window_state == "open" and routeWnd.window_state ~= "open" then routeWnd:Open() end
		
		local shortcut, reverse = GetShortcutByStartEnd(previousSector, to)
		if not shortcut then
			print("once", "didn't find shortcut in route", previousSector, to)
			return
		end

		routeWnd:SetDisplayShortcut(shortcut, self, reverse, shortcutsUsed == 1)
		routeWnd:SetBackground(routeColor)
		routeWnd:SetVisible(self.route_visible or plotting)

		local moveDir
		
		if not prevWasShortcut then
			moveDir = point(sector_unpack(previousSector)) - point(sector_unpack(to))
			if not lastMove then
				lastMove = moveDir
			elseif lastMove ~= moveDir then
				turns[#turns + 1] = previousSector
				lastMove = moveDir
			end
		end
		
		previousSector = reverse and shortcut.shortcut_direction_entrance_sector or shortcut.shortcut_direction_exit_sector;
		moveDir = point(sector_unpack(previousSector)) - point(sector_unpack(to))
		lastMove = moveDir
		
		prePreviousSector = previousSector
		previousSector = to
		prevWasShortcut = true
	end
	
	-- Squad is in sector, but hasn't reached its center yet.
	-- The segment goes from the middle towards us.
	local startSectorPos = gv_Sectors[start].XMapPosition
	local visualPos = self:GetVisualPos()
	assert(visualPos ~= point20)
	local visuallyPreviousSector = GetSquadPrevSector(visualPos, start, startSectorPos)
	local centerOldMovement = route.center_old_movement -- New route was set while squad was in second half of interpolation.
	local nextWp = route[1] and route[1][1]
	local inShortcut = IsTraversingShortcut(squad)
	if startSectorPos ~= visualPos and visuallyPreviousSector ~= start and (nextWp ~= visuallyPreviousSector or centerOldMovement) and not inShortcut then
		previousSector = visuallyPreviousSector
		lAddRouteSegment(start)
		routeShown.extra_visual_segment = true
	end
	-- The route actually contains the visual position. Disregard it.
	local skipFirst = false
	if nextWp == start and not centerOldMovement then
		skipFirst = true
		routeShown.extra_in_route = true
	end

	for i, section in ipairs(route) do -- each waypoint section
		for is, sector in ipairs(section) do -- array of sector ids
			if i == 1 and is == 1 and skipFirst then goto continue end
			
			if section.shortcuts and section.shortcuts[is] then
				lAddShortcutSegment(sector)
			else
				lAddRouteSegment(sector)
			end

			::continue::
		end

		waypoints[#waypoints + 1] = previousSector
		waypoints[previousSector] = i
	end
	
	-- Delete unused route segments
	if windowsUsed < #routeShown then
		for i = windowsUsed + 1, #routeShown do
			routeShown[i]:Close()
			routeShown[i] = nil
		end
	end

	-- Delete unused shortcut segments
	if routeShown.shortcuts and shortcutsUsed < #routeShown.shortcuts then
		for i = shortcutsUsed + 1, #routeShown.shortcuts do
			routeShown.shortcuts[i]:Close()
			routeShown.shortcuts[i] = nil
		end
	end

	local routeDecorations = routeShown.decorations
	if not routeDecorations then
		routeDecorations = {}
		routeShown.decorations = routeDecorations
	end

	local decorationsUsed = 0
	for i, waypointSector in ipairs(waypoints) do
		if waypointSector == previousSector then goto continue end -- Don't place waypoint at end.
	
		decorationsUsed = decorationsUsed + 1
		local decoration = routeDecorations[decorationsUsed]
		if not decoration then
			decoration = XTemplateSpawn("SquadRouteDecoration", uimap)
			routeDecorations[#routeDecorations + 1] = decoration
		end
		if uimap.window_state == "open" and decoration.window_state ~= "open" then decoration:Open() end
		decoration:SetWaypoint(waypointSector, waypoints[waypointSector])
		decoration:SetColor(routeColorNoAlpha)
		decoration:SetVisible(self.route_visible or plotting)
		::continue::
	end
	
	for i, position in ipairs(ports) do
		decorationsUsed = decorationsUsed + 1
		local decoration = routeDecorations[decorationsUsed]
		if not decoration then
			decoration = XTemplateSpawn("SquadRouteDecoration", uimap)
			routeDecorations[#routeDecorations + 1] = decoration
		end
		
		if uimap.window_state == "open" and decoration.window_state ~= "open" then decoration:Open() end
		
		local portData = ports[position]
		decoration:SetPort(position, routeColorNoAlpha, portData)
		decoration:SetVisible(self.route_visible or plotting)
	end
	
	for i, turnSector in ipairs(turns) do
		if waypoints[turnSector] then goto continue end -- Dont put turns on waypoints.

		decorationsUsed = decorationsUsed + 1
		local decoration = routeDecorations[decorationsUsed]
		if not decoration then
			decoration = XTemplateSpawn("SquadRouteDecoration", uimap)
			routeDecorations[#routeDecorations + 1] = decoration
		end
		if uimap.window_state == "open" and decoration.window_state ~= "open" then decoration:Open() end
		decoration:SetCorner(turnSector)
		decoration:SetColor(routeColorNoAlpha)
		decoration:SetVisible(self.route_visible or plotting)
		::continue::
	end
	
	-- End of path
	if prePreviousSector then
		local squadMode = plotting and squad
		if not squadMode or invalidRoute then
			decorationsUsed = decorationsUsed + 1
			local endDecoration = routeDecorations[decorationsUsed]
			if not endDecoration then
				endDecoration = XTemplateSpawn("SquadRouteDecoration", uimap)
				routeDecorations[#routeDecorations + 1] = endDecoration
			end
			if uimap.window_state == "open" and endDecoration.window_state ~= "open" then endDecoration:Open() end
			
			endDecoration:SetRouteEnd(prePreviousSector, previousSector, plotting and invalidRoute)
			endDecoration:SetColor(routeColorNoAlpha)
			endDecoration:SetVisible(self.route_visible or plotting)
		else
			decorationsUsed = decorationsUsed + 1
			local endDecoration = routeDecorations[decorationsUsed]
			if not endDecoration then
				endDecoration = XTemplateSpawn("SquadRouteDecoration", uimap)
				routeDecorations[#routeDecorations + 1] = endDecoration
			end
			if uimap.window_state == "open" and endDecoration.window_state ~= "open" then endDecoration:Open() end
			
			endDecoration:SetRouteEnd(prePreviousSector, previousSector, plotting and invalidRoute, plotting and squad)
			endDecoration:SetColor(routeColorNoAlpha)
			endDecoration:SetVisible(self.route_visible or plotting)
		end
	end

	-- Delete unused decorations
	if decorationsUsed < #routeDecorations then
		for i = decorationsUsed + 1, #routeDecorations do
			routeDecorations[i]:Close()
			routeDecorations[i] = nil
		end
	end
	
	-- Apply effects to decorations that do not have them, or remove effects.
	local shouldHaveEffect = false--plotting
	for i, w in ipairs(routeShown) do
		if not shouldHaveEffect then
			w:RemoveModifier(lRouteEffectTable)
		elseif not w:FindModifier(lRouteEffectTable) then
			w:AddInterpolation(lRouteEffectTable)
		end
	end
	
	for i, w in ipairs(routeShown.shortcuts) do
		if not shouldHaveEffect then
			w:RemoveModifier(lRouteEffectTable)
		elseif not w:FindModifier(lRouteEffectTable) then
			w:AddInterpolation(lRouteEffectTable)
		end
	end
	
	for i, w in ipairs(routeShown and routeShown.decorations) do
		if not shouldHaveEffect then
			w:RemoveModifier(lRouteEffectTable)
		elseif not w:FindModifier(lRouteEffectTable) then
			w:AddInterpolation(lRouteEffectTable)
		end
	end
end

function SquadWindow:SetConflictMode(conflictMode)
	local conflictIcon = self.idConflict
	if conflictMode and not conflictIcon then
		local icon = XTemplateSpawn("XImage", self)
		icon:SetImage("UI/Icons/SateliteView/sv_conflict")
		icon:SetMaxWidth(40)
		icon:SetMaxHeight(40)
		icon:SetMinWidth(40)
		icon:SetMinHeight(40)
		icon:SetDrawOnTop(true)
		icon:SetUseClipBox(false)
		icon:SetImageFit("stretch")
		icon:SetId("idConflict")
		self:SetZOrder(4)
		if self.window_state == "open" then icon:Open() end
	elseif not conflictMode and conflictIcon and conflictIcon.window_state == "open" then
		conflictIcon:Close()
		self:SetZOrder(3)
	end
	if self.idSquadIcon then self.idSquadIcon:SetVisible(not conflictMode) end
end

function SquadWindow:SetVisible(visible, iconOnly)
	XContextWindow.SetVisible(self, visible)

	if iconOnly then visible = true end
	if visible then CheckAttackSquadCondition(self.context) end --tutorial
	self.route_visible = visible
	for id, route in pairs(self.routes_displayed) do
		for i, wnd in ipairs(route) do
			wnd:SetVisible(visible)
		end
		for i, wnd in ipairs(route.shortcuts) do
			wnd:SetVisible(visible)
		end
		for i, wnd in ipairs(route.decorations) do
			wnd:SetVisible(visible)
		end
	end
end

function SquadWindow:Done()
	local squad = self.context
	squad.XVisualPos = self:GetTravelPos()
	--NetUpdateHash("SquadWindow_Done", squad.UniqueId, squad.XVisualPos) --these windows have become unsorted and sometimes close in different orders; cba to fix;
end

if Platform.developer then
	local function TestPositions()
		for id, squad in ipairs(gv_Squads) do
			NetUpdateHash("OpenSatelliteView_SatSquadPositions", id, squad.XVisualPos)
		end
	end

	function OnMsg.StartSatelliteGameplay()
		TestPositions()
	end

	function OnMsg.OpenSatelliteView()
		TestPositions()
	end
end

function OnMsg.GatherSessionData()
	if g_SatelliteUI then
		for i, s in pairs(g_SatelliteUI.squad_to_wnd) do
			local squad = s.context
			squad.XVisualPos = s:GetTravelPos()
		end
	end
end

function GetSatelliteIconImagesSquad(squad, from_ui)
	local image = false
	if squad.diamond_briefcase then
		local shipmentPresetId = squad.shipment_preset_id
		local shipmentPreset = shipmentPresetId and ShipmentPresets[shipmentPresetId]
		image = shipmentPreset and shipmentPreset.squad_icon or "UI/Icons/SateliteView/enemy_squad_diamonds"
	end

	if squad.militia then
		image = "UI/Icons/SateliteView/militia"
	end
	if squad.Villain then
		image = "UI/Icons/SateliteView/enemy_boss"
	end
	if squad.Side == "player1" or squad.Side == "player2" then
		image = image or (squad.image and squad.image.."_s")
	end
	image = image or squad.image or ""
	
	-- Append _2 to from map.
	if from_ui then
		return image
	end
	
	return image .. "_2"
end

function GetSatelliteIconImages(context)
	local base_img, upper_img = "UI/Icons/SateliteView/icon_neutral", "UI/Icons/SateliteView/hospital"
	local side = context.side
	local is_enemy = side=="enemy1" or side=="enemy2"
	local is_player = side=="player1" or side=="player2"
	local is_ally = is_player or side== "ally"
	local is_neutral = side=="neutral"

	if is_enemy then
		base_img = "UI/Icons/SateliteView/icon_enemy"
	elseif is_ally then
		base_img = "UI/Icons/SateliteView/icon_ally"
	end
	local squad_id = context.squad
	local squad = gv_Squads[squad_id]

	if squad then
		if is_ally then
			base_img = "UI/Icons/SateliteView/merc_squad"
			if is_player then
				upper_img = (squad.image and squad.image.."_s") or "UI/Icons/SquadLogo/squad_logo_01_s"
			else
				upper_img = "UI/Icons/SquadLogo/squad_logo_01_s"
			end
		elseif squad.diamond_briefcase then
			local shipmentPresetId = squad.shipment_preset_id
			local shipmentPreset = shipmentPresetId and ShipmentPresets[shipmentPresetId]
			base_img = shipmentPreset and shipmentPreset.squad_icon or "UI/Icons/SateliteView/enemy_squad_diamonds"
			upper_img = false
		elseif squad.image then
			base_img = squad.image
			upper_img = false
		end
	end

	local building = context.building
	if #(building or "") > 0 then
		local image
		local preset = table.find_value(POIDescriptions, "id", building)
		if preset and preset.icon then
			image = preset and preset.icon
			if building == "Mine" and context.sector and context.sector.mine_depleted then
				image = image .. "_depleted"
			elseif is_neutral and image then
				image = image .. "_neutral"
			end
		end
		upper_img = image and ("UI/Icons/SateliteView/" .. image)
	end
	local intel = context.intel
	if intel~= nil then
		local image = intel and "intel_available" or "intel_missing"
		upper_img = "UI/Icons/SateliteView/"..image
	end
	local suf  = context.map and "_2" or ""
	return base_img..suf, upper_img
end

DefineClass.SatelliteQuestIcon = {
	__parents = { "XContextImage", "XMapRolloverable", "XButton" },
	UseClipBox = false,
	Margins = box(10, 10, 10, 10),
	MinWidth = 64,
	MaxWidth = 64,
	MinHeight = 64,
	MaxHeight = 64,
	ImageFit = "stretch",
	HandleMouse = true,
	
	RolloverTemplate = "RolloverQuests",
	RolloverAnchor = "right",
	Background = RGBA(0, 0, 0, 0),
	RolloverBackground = RGBA(255, 255, 255, 0),
	PressedBackground = RGBA(255, 255, 255, 0),
	RolloverOffset = box(20, 0, 0, 0),
	FXMouseIn = "SatelliteBadgeRollover",
	FXPress = "SatelliteBadgePress",
	FXPressDisabled = "SatelliteBadgeDisabled",
}

function SatelliteQuestIcon:GetRolloverText()
	return self.context
end

function SatelliteQuestIcon:OnPress()
	InvokeShortcutAction(g_SatelliteUI, "actionOpenNotes")
	CreateRealTimeThread(function()
		local dlg = GetDialog("PDADialog")
		local notesUI = dlg and dlg.idContent
		if not IsKindOf(notesUI, "PDANotesClass") then
			print("Where's the quest UI? :(")
			return
		end
		
		local subTab = notesUI.idSubContent
		local questUI = subTab and subTab.idQuestsContent
		if not IsKindOf(questUI, "PDAQuestsClass") then
			print("Where's the quest UI 2? :(")
			return
		end
		
		local quest = self.context.quest
		quest = quest and quest[1]
		quest = quest and quest.preset
		if not quest then return end
		questUI:SetSelectedQuest(quest.id)
		local a = true
	end)
end

DefineClass.SatelliteSectorUndergroundIcon = {
	__parents = { "XTextButton", "XMapRolloverable" },
	
	UseClipBox = false,
	MinWidth = 64,
	MaxWidth = 64,
	MinHeight = 64,
	MaxHeight = 64,
	ImageFit = "stretch",
	HandleMouse = true,
	
	HAlign = "right",
	VAlign = "bottom",
	
	ColumnsUse = "ababa",
	
	ZOrder = 2,
	RolloverTemplate = "RolloverGeneric",
	RolloverTitle = T(848438434046, "Underground sector"),
	RolloverText = T(859822970788, "This sector has an underground section that can be explored"),
	
	FXPress = "SatViewUndergroundlevel",
}

function SatelliteSectorUndergroundIcon:Open()
	XTextButton.Open(self)
end

function SatelliteSectorUndergroundIcon:SwapSector()
	local parentSectorWin = self:ResolveId("node")
	local sectorCtx = parentSectorWin.context
	local groundSectorId = sectorCtx.GroundSector or sectorCtx.Id
	local groundSectorWin = g_SatelliteUI and g_SatelliteUI.sector_to_wnd[groundSectorId]
	if not groundSectorWin then return end
	groundSectorWin:SetVisible(not groundSectorWin.visible)
	
	local undergroundSectorId = groundSectorId .. "_Underground"
	local undergroundSectorWindow = g_SatelliteUI.sector_to_wnd[undergroundSectorId]
	if not undergroundSectorWindow then return end
	undergroundSectorWindow:SetVisible(not groundSectorWin.visible)
	
	g_SatelliteUI:UpdateSectorVisuals(groundSectorId)
	g_SatelliteUI:UpdateSectorVisuals(undergroundSectorId)
	
	local visibleSector = undergroundSectorWindow.visible and undergroundSectorId or groundSectorId
	return visibleSector, visibleSector == undergroundSectorId and groundSectorId or undergroundSectorId
end

function SatelliteSectorUndergroundIcon:OnPress()
	local visibleSector, previouslyVisibleSector = self:SwapSector()
	if GetSectorInfoPanel() and g_SatelliteUI.selected_sector == gv_Sectors[previouslyVisibleSector] then
		g_SatelliteUI:SelectSector(gv_Sectors[visibleSector])
	end
end

DefineClass.SatelliteSectorIconGuardpostClass = {
	__parents = { "XContextWindow", "XMapRolloverable", "SatelliteIconClickThrough" },
	UseClipBox = false,

	Id = "idPointOfInterest",
	ContextUpdateOnOpen = true,
	
	HandleMouse = true
}

function SatelliteSectorIconGuardpostClass:Open()
	self.context.side = self.context.sector.Side
	self.context.building = "Guardpost"
	self.context.poi = "Guardpost"
	self.context.poi_preset = table.find_value(POIDescriptions, "id", "Guardpost")
	self.context.map = true
	self.context.is_main = true
	XContextWindow.Open(self)
end

function SatelliteSectorIconGuardpostClass:Update(mode)
	self.context.is_main = mode == "main"
	self.context.side = self.context.sector.Side
	
	local base, up = GetSatelliteIconImages(self.context)
	self.idIcon:SetImage(base)
	
	local strength = GetGuardpostStrength(self.context.sector.Id)
	local fullStrength = not not strength
	for i, s in ipairs(strength) do
		if s.done then
			fullStrength = false
			break
		end
	end
	if fullStrength then
		up = "UI/Icons/SateliteView/guard_post_2"
	end
	
	self.idInner:SetImage(up)
end

function SatelliteSectorIconGuardpostClass:GetRolloverText()
	local sector = self.context.sector
	return GetGuardpostRollover(sector)
end

function SatelliteSectorIconGuardpostClass:SetMiniMode(on)
	if self.context.sector.Side ~= "enemy1" then
		on = true
	end
	
	self.idShieldContainer:SetVisible(not on)
	self.idTimer:SetVisible(not on)
	self.idIcon:SetScaleModifier(on and point(1000, 1000) or point(1500, 1500))
end

function SectorWindowBlink(sector)
	local satMap = g_SatelliteUI
	local sectorWindow = satMap and satMap.sector_to_wnd[sector.Id]
	if not sectorWindow then return end
	
	sector = sector and gv_Sectors[sector.GroundSector] or sector
	sectorWindow:DeleteThread("blink-thread")
	sectorWindow:CreateThread("blink-thread", function()
		local blinkOn = false
		local blinkCount, maxBlinks = 0, 10
		while sectorWindow.window_state ~= "destroying" do
			blinkOn = not blinkOn
			satMap.blinking_sector_fx = blinkOn and sector
			satMap:Invalidate() -- force redraw
			blinkCount = blinkCount + 1
			
			if sectorWindow.rollover or blinkCount > maxBlinks then break end
			Sleep(250) -- blink interval
		end
		satMap.blinking_sector_fx = false
	end)
end

function SectorRolloverShowGuardpostRoute(sector)
	local satMap = g_SatelliteUI
	local guardpostObj = sector and sector.guardpost_obj
	local showRoute = guardpostObj and guardpostObj.next_spawn_time and (sector.Side == "enemy1" or sector.Side == "enemy2")
	if showRoute then
		local timeRemaining = showRoute and guardpostObj.next_spawn_time - Game.CampaignTime
		showRoute = timeRemaining > 0 and timeRemaining < const.Satellite.GuardPostShowTimer
	end

	local startSectorId = sector and sector.Id
	local targetSectorId = guardpostObj and guardpostObj.target_sector_id
	if not targetSectorId then
		showRoute = false
	end
	
	local calculateRoute = showRoute and GenerateRouteDijkstra(startSectorId, targetSectorId, false, empty_table, nil, startSectorId, sector.Side)
	calculateRoute = calculateRoute and {calculateRoute} -- Waypointify
	if calculateRoute then
		if not satMap.guardpost_route_proxy then
			-- Init dummy map object and props to use the SquadWindow function. Yes, this is a dirty hack.
			local proxyObj = XTemplateSpawn("XMapObject", g_SatelliteUI);
			proxyObj.ScaleWithMap = false
			proxyObj.context = { Side = sector.Side }
			proxyObj.OnDelete = SquadWindow.OnDelete
			local pos = sector.XMapPosition
			proxyObj:SetPos(pos:xy())
			proxyObj.GetVisualPos = function()
				return pos
			end
			if satMap.window_state == "open" then proxyObj:Open() end
			satMap.guardpost_route_proxy = proxyObj
		end
		SquadWindow.DisplayRoute(satMap.guardpost_route_proxy, "guardpost", startSectorId, calculateRoute)
	else
		if satMap.guardpost_route_proxy then
			satMap.guardpost_route_proxy:Close()
			satMap.guardpost_route_proxy = false
		end
	end
end

DefineClass.SatelliteIconClickThrough = {
	__parents = { "XContextWindow", "XMapRolloverable" }
}

function SatelliteIconClickThrough:OnMouseButtonDown(pt, button)
	local sector = self.context.sector
	local map = GetParentOfKind(self, "XMap")
	local sectorWin = map.sector_to_wnd[sector.Id]
	return g_SatelliteUI:OnSectorClick(sectorWin, sectorWin.context, button)
end

DefineClass.SatelliteSectorIconPOI = {
	__parents = { "XMapRolloverable", "XContextWindow" },
	Id = "idPointOfInterest",
	
	mode = false,
	pois = false,
	
	UseClipBox = false,
	IdNode = true
}

function SatelliteSectorIconPOI:Update(mode, allPOIs)
	local oldMode = self.mode
	local oldPOIsHash = self.pois and table.hash(self.pois)
	self.mode = mode
	self.pois = allPOIs
	
	local mainIcon = self.idMainIcon
	local subIcon = self.idSubIcon
	
	local respawnTotally = oldMode ~= mode or oldPOIsHash ~= table.hash(allPOIs)
	if respawnTotally then
		if mainIcon then mainIcon:Close() end
		if subIcon then subIcon:Close() end
	
		local mainIcon = XTemplateSpawn("SatelliteIconPointOfInterest", self, {
			building = allPOIs[1],
			pois = mode == "main" and { allPOIs[1] } or allPOIs,
			sector = self.context.sector
		})
		mainIcon:SetId("idMainIcon")
		mainIcon:SetMain(mode == "main")
		
		local subIcon = false
		if mode == "main" and allPOIs and #allPOIs > 1 then
			table.remove(allPOIs, 1)
			 subIcon = XTemplateSpawn("SatelliteIconPointOfInterest", self, {
				building = allPOIs[1],
				pois = allPOIs,
				sector = self.context.sector
			})
			subIcon:SetId("idSubIcon")
			subIcon:SetMain(false)
		end
		
		if self.window_state == "open" then
			mainIcon:Open()
			if subIcon then subIcon:Open() end
		end
	else
		if mainIcon then
			mainIcon:UpdateStyle()
		end
		if subIcon then
			subIcon:UpdateStyle()
		end
	end
end

function SatelliteSectorIconPOI:OnMouseButtonDown(pt, button)						
	local sector = self.context.sector
	local sectorId = sector.Id
	if button == "L" and sector.conflict then
		OpenSatelliteConflictDlg(sector)
		return "break"
	end
	
	return SatelliteIconClickThrough.OnMouseButtonDown(self, pt, button)
end

DefineClass.PointOfInterestIconClass = {
	__parents = { "XContextWindow", "XMapRolloverable", "SatelliteIconClickThrough" },

	UseClipBox = false,
	Margins = box(10, 10, 10, 10),
	MinWidth = 64,
	MaxWidth = 64,
	MinHeight = 64,
	MaxHeight = 64,
	ImageFit = "stretch",
	HandleMouse = true,
	
	RolloverTemplate = "RolloverGenericPointOfInterest",
	RolloverAnchor = "smart",
	RolloverBackground = RGBA(255, 255, 255, 0),
	PressedBackground = RGBA(255, 255, 255, 0),
	RolloverOffset = box(10, 10, 10, 10),
	FXMouseIn = "SatelliteBadgeRollover",
	FXPress = "SatelliteBadgePress",
	FXPressDisabled = "SatelliteBadgeDisabled",
}

function PointOfInterestIconClass:SetMain(main)
	local context = self.context
	local base, up = GetSatelliteIconImages({
		building = context.building,
		side = context.sector.Side,
		map = true,
		sector = context.sector
	})
	self.idBase:SetImage(base)
	self.idUpperIcon:SetImage(up)

	self:SetScaleModifier(main and point(2000, 2000) or point(1000, 1000))
	self:SetHAlign(main and "center" or "right")
	self:SetVAlign(main and "center" or "top")
	self:UpdateStyle()
end

function PointOfInterestIconClass:UpdateStyle()
	local context = self.context
	local base, up = GetSatelliteIconImages({
		building = context.building,
		side = context.sector.Side,
		map = true,
		sector = context.sector
	})
	self.idBase:SetImage(base)

	local sector = context.sector
	local poi = context.building
	local isLocked = sector[poi .. "Locked"]
	local specialLocked = poi == "Mine" and sector.mine_depleted
	isLocked = isLocked or specialLocked

	self.idBase:SetDesaturation(isLocked and 225 or 0)
	self.idLockedIcon:SetVisible(isLocked)
end

function PointOfInterestIconClass:GetRolloverText()
	return true
end

function PointOfInterestIconClass:GetRolloverTitle()
	return true
end

DefineClass.PointOfInterestRolloverClass = {
	__parents = { "PDARolloverClass" }
}

function PointOfInterestRolloverClass:GetPOITitleForRollover(buildingId, sector)
	if not buildingId or not sector or not g_SatelliteUI then return end
	
	local poiPreset = table.find_value(POIDescriptions, "id", buildingId)
	if not poiPreset then return false end
	
	local rightText = false
	if buildingId == "Port" then
		local selectedSquad = g_SatelliteUI.selected_squad
		local travelCost = sector:GetTravelPrice(selectedSquad)

		if sector.PortLocked then
			rightText = T(319590646964, "Inactive")
		else
			rightText = T{241693398390, "<moneyWithSign(cost)>/sector",
				cost = -travelCost
			}
		end
	elseif buildingId == "Mine" then
		local income  = GetMineIncome(sector.Id, "evenIfUnowned")
		if income then
			rightText = T{374101510295, "<moneyWithSign(income)>/day", income = income}
		elseif sector.mine_depleted then
			rightText = T(670636571444, "Depleted")
		end
	elseif buildingId == "Hospital" then
		if sector.HospitalLocked then
			rightText = T(319590646964, "Inactive")
		end
	end
	
	if rightText then
		rightText = T{985521229804, "<right><style PDASectorInfo_ValueLight><text></style>", text = rightText}
		return poiPreset.display_name .. rightText
	end
	
	return poiPreset.display_name
end

function PointOfInterestRolloverClass:GetPOITextForRollover(buildingId, sector)
	if not buildingId or not sector or not g_SatelliteUI then return end

	local poiPreset = table.find_value(POIDescriptions, "id", buildingId)
	if not poiPreset then return end
	
	local extraText = false
	if buildingId == "Port" then
		local selectedSquad = g_SatelliteUI.selected_squad
		local travelCost, discounts = sector:GetTravelPrice(selectedSquad)
		
		if discounts then
			extraText = T(939967219161, "<newline><newline>Discounted By:")
			for i, d in ipairs(discounts) do
				extraText = extraText .. T{487636023428, "<newline><label><right>-<percent(percent)><left>", label = d.label, percent = d.percent}
			end
		end
	elseif buildingId == "Hospital" then	
		local count = #GetOperationProfessionals(sector.Id, "HospitalTreatment", "Patient")
		extraText = T{498858415486, "<newline><newline>Active patients: <number>", number = count}
	elseif buildingId == "Mine" then
		if sector.mine_depleted then
			extraText = T(997788054289, "Deposit: Fully Depleted")
		elseif not sector.Depletion then
			extraText = T(797228414885, "Deposit: Very Rich")
		else
			local daysUntilDepletion = GetDaysLeftUntilDepletionStarts(sector)
			if daysUntilDepletion < 0 then
				extraText = T(825598030543, "Deposit: Depleting")
			elseif daysUntilDepletion < 30 then
				extraText = T(122719825678, "Deposit: Running Low")
			elseif daysUntilDepletion < 90 then
				extraText = T(266694423591, "Deposit: Moderate")
			elseif daysUntilDepletion < 180 then
				extraText = T(864194248788, "Deposit: Rich")
			else
				extraText = T(797228414885, "Deposit: Very Rich")
			end
		end
		extraText = T(866574791377, "<newline><newline>") .. extraText
	end
		
	if extraText then
		return poiPreset.descr .. extraText
	end
	
	return poiPreset.descr
end