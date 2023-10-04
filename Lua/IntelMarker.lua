function GetTextStyleForColorIDs()
	local styles = table.filter(TextStyles, function(_, s) return s.group == "Zulu Ingame" end)
	return table.keys(styles, "sorted")
end

DefineClass.IntelMarker = {
	__parents = { "GridMarker" },
	properties = {
		{ category = "Grid Marker", id = "Type", name = "Type", editor = "dropdownlist", items = PresetGroupCombo("GridMarkerType", "Default"), default = "Intel", no_edit = true },
		{ category = "Intel Marker", id = "IntelAreaRadius",  name = "Intel Area Radius", editor = "number", default = 6, help = "Visual radius in voxels" },
		{ category = "Intel Marker", id = "IntelAreaText", name = "Intel Area Text", editor = "text", translate = true, default = false },
		{ category = "Intel Marker", id = "Description", editor = "text", translate = true, default = false },
		{ category = "Intel Marker", id = "TextStyleForColor", name = "Text Style For Color", editor = "choice", items = GetTextStyleForColorIDs, default = "IntelDefault", },
		{ category = "Intel Marker", id = "IntelTextStyle", name = "TextStyle for Text", editor = "preset_id", preset_class = "TextStyle", editor_preview = true, default = "IntelDefaultText", },
		{ category = "Marker", id = "Reachable",  no_edit = true, default = false, },
		{ category = "Intel Marker", id = "Conditions", name = "Conditions For Dynamic Text Update",
			editor = "nested_list", default = false, base_class = "Condition", no_edit = function(self) return not self.dynamicText end,},
		{ category = "Intel Marker", id = "dynamicText", editor = "bool", default = false, no_edit = true},
		{ category = "Intel Marker", id = "enemyColoring", editor = "bool", default = true, no_edit = true},
	},
	area_obj = false,
	text_attach_obj = false,
	area_text = false,
	area_text_second_line = false,
	recalc_area_on_pass_rebuild = false,
}

local dec_radius_in_voxels = 3

function IntelMarker:IsMarkerEnabled(ctx)
	if gv_CurrentSectorId and not gv_Sectors[gv_CurrentSectorId].intel_discovered then return false end
	return GridMarker.IsMarkerEnabled(self, ctx)
end

function IntelMarker:GetIntelText()
	return self.IntelAreaText
end

function IntelMarker:IsVisualized()
	return self.area_obj
end



DefineClass.CRM_IntelArea = {
	__parents = { "CRMaterial" },

	--group = "RangeContourPreset",
	properties = {
		{ uniform = true, id = "depth_softness", editor = "number", default = 0, scale = 1000, min = -2000, max = 2000, slider = true, },
		{ uniform = true, id = "scale", editor = "number", default = 1000, scale = 1000, },
		{ uniform = true, id = "fill_percent", editor = "number", default = 1000, scale = 1000, },

		{ uniform = true, id = "fill_color", editor = "color", default = RGB(255, 255, 255), },
		{ uniform = true, id = "empty_color", editor = "color", default = RGB(255, 255, 255), },
		
	},

	shader_id = "ground_strokes",
}


function IntelMarker:Visualize(show)
	if gv_CurrentSectorId and not gv_Sectors[gv_CurrentSectorId].intel_discovered then return end
	if not self.text_attach_obj then
		local attObj = PlaceObject("Object")
		local pos = self:GetPos()
		if not pos:IsValidZ() then
			pos = pos:SetZ(terrain.GetHeight(pos))
		end
		pos = pos:SetZ(pos:z() + 100)
		attObj:SetPos(pos)
		attObj:SetAngle(0)
		self.text_attach_obj = attObj
	end

	if show then
		if self.area_text then
			self.area_text:delete()
			self.area_text = false
		end
		if self.area_text_second_line then
			self.area_text_second_line:delete()
			self.area_text_second_line = false
		end
		
		local pos = self:GetPos()
		if not pos:IsValidZ() then
			pos = pos:SetZ(terrain.GetHeight(pos))
		end

		local enemyColoring = false
		if self.enemyColoring then
			--enemyColoring = self:CheckEnemyPresence()
		end
		
		local text = self:GetIntelText()
		if text then
			if enemyColoring then
				local secondLine = FlatTextMesh:new({
					text_style_id = "IntelEnemyText",
					text = _InternalTranslate(T(927586584232, "(Enemies)")),
				})
				secondLine:FetchEffectsFromTextStyle()
				secondLine:CalculateSizes(self.IntelAreaRadius * 500, Min(self.IntelAreaRadius * 500, 1250))
				secondLine:Recreate()
				local pt = point(0, secondLine.height + 250, 0)
				secondLine:ClearGameFlags(const.gofOnTerrain)
				secondLine:SetDepthTest(false)
				secondLine:SetMeshFlags(secondLine:GetMeshFlags() | const.mfSortByPosZ)
				
				secondLine:SetAttachOffset(pt)
				self.text_attach_obj:Attach(secondLine)
				self.area_text_second_line = secondLine
			end
			
			local intelText = FlatTextMesh:new({
				text_style_id = self.IntelTextStyle,
				text = "[" .. _InternalTranslate(text) .. "]",
			})
			intelText:FetchEffectsFromTextStyle()
			intelText:CalculateSizes(self.IntelAreaRadius * 1000, Min(self.IntelAreaRadius * 1000, 2500))
			intelText:Recreate()
			intelText:ClearGameFlags(const.gofOnTerrain)
			intelText:SetDepthTest(false)
			intelText:SetMeshFlags(intelText:GetMeshFlags() | const.mfSortByPosZ)

			intelText:SetAttachOffset(point30)
			self.text_attach_obj:Attach(intelText)
			self.area_text = intelText
		end
		if self.area_obj then
			DoneObject(self.area_obj)
		end
		self.area_obj = PlaceObject("Mesh")
		local mesh_str = pstr("", 1024)
		local radius = self.IntelAreaRadius * const.SlabSizeX
		local angles = 64
		local center = point30
		local color = const.clrWhite
		local r = RotateRadius(radius, 0, center)
		for i=1,angles do
			mesh_str:AppendVertex(center, color, 100)
			mesh_str:AppendVertex(r, color, 0)
			r = RotateRadius(radius, i*60*360/angles, center)
			mesh_str:AppendVertex(r, color, 0)
		end
		--self.area_obj:SetMeshFlags(const.mfWorldSpace)
		self.area_obj:SetMeshFlags(self.area_obj:GetMeshFlags() | const.mfSortByPosZ)
		self.area_obj:SetCRMaterial(CRM_IntelArea:GetById(enemyColoring and "IntelArea_Enemy" or "IntelArea_Default"))
		self.area_obj:SetMesh(mesh_str)
		self.area_obj:ClearGameFlags(const.gofOnTerrain)
		self.area_obj:SetPos(pos)
	else
		if self.area_obj then
			DoneObject(self.area_obj)
			self.area_obj = false
		end
		if self.area_text then
			self.area_text:delete()
			self.area_text = false
		end
		if self.area_text_second_line then
			self.area_text_second_line:delete()
			self.area_text_second_line = false
		end
	end
end

function IntelMarker:CheckEnemyPresence()
	local positions = self:GetAreaPositions("ignore_occupied")
	local values = positions.values or empty_table
	for _, team in ipairs(g_Teams) do
		if team.side == "enemy1" then
			for _, u in ipairs(team.units) do
				if not u:IsDead() and values[point_pack(SnapToVoxel(u:GetPosXYZ()))] then
					return true
				end
			end
		end
	end
end

function IntelMarker:GameInit()
	if EvalConditionList(self.Conditions, self) and self.dynamicText then
		CreateRealTimeThread(function(self)
			while IsValid(self) do
				Sleep(1000)
				if self:IsValidPos() and self:IsVisualized() then
					self:Visualize(true, "refresh")
				end
			end
		end, self)
	end
end

function GetEnabledIntelMarkers(all)
	local empty_ctx = {}
	return MapGetMarkers("GridMarker", nil, function(m, all)
		return IsKindOfClasses(m, "IntelMarker", "ImplicitIntelMarker") and (all or m:IsMarkerEnabled(empty_ctx))
	end, all)
end

function VisualizeIntelMarkers(show)
	local intel_markers = GetEnabledIntelMarkers(not show and "all")
	for i, m in ipairs(intel_markers) do
		m:Visualize(show)
	end
end

MapVar("g_NorthObject", false)

function GetMapPositionAlongOrientation(angle)
	angle = (angle + 90) % 360
	
	local sizex, sizey = terrain.GetMapSize()
	if angle == 0 or angle == 360 then
		return point(sizex * 2, sizey / 2, 0)
	elseif angle == 90 then
		return point(sizex / 2, -sizey, 0)
	elseif angle == 180 then
		return point(-sizex, sizey / 2, 0)
	elseif angle == 270 then
		return point(sizex / 2, sizey * 2, 0)
	end
	assert(false, "Non-cardinal orientation. Maths needed")
	return point30
end

function VisualizeNorth(show)
	if not GetInGameInterface() then return end

	if not g_NorthObject then
		local northStar = PlaceObject("Object")
		northStar:SetPos(GetMapPositionAlongOrientation(mapdata.MapOrientation))
		CreateBadgeFromPreset("NorthBadge", northStar)
		g_NorthObject = northStar
	end
	g_Badges[g_NorthObject][1]:SetVisible(show)
end

function OnMsg.ExplorationStart()
	if GetAccountStorageOptionValue("ShowNorth") then VisualizeNorth(true) end
end

function OnMsg.ApplyAccountOptions()
	if GetInGameInterfaceMode() == "IModeExploration" then
		VisualizeNorth(GetAccountStorageOptionValue("ShowNorth"))
	end
end

function OnMsg.CombatStart()
	VisualizeNorth(false)
end

MapVar("g_Overview", false)

function OnSetOverview(set)
	set = set == 1
	g_Overview = set
	VisualizeIntelMarkers(set)
	if not set then
		VisualizeNorth(GetInGameInterfaceMode() == "IModeExploration" and GetAccountStorageOptionValue("ShowNorth"))
	else
		VisualizeNorth(set)
	end
	Msg("CameraTacOverview", set)
end

DefineClass.EnemyIntelMarker = {
	__parents = { "IntelMarker" },
	properties = {
		{ category = "Intel Marker", id = "IntelSide",  name = "Intel Side", editor = "dropdownlist", items = function() return table.map(GetCurrentCampaignPreset().Sides, "Id") end, default = "enemy1" },
		{ category = "Intel Marker", id = "IntelAreaText", name = "Intel Area Text", editor = "text", translate = true, default = T(815679600520, "Enemies") },
		{ category = "Intel Marker", id = "IntelAreaRadius",  name = "Intel Area Radius", editor = "number", default = false, help = "Radius in voxels", no_edit = true },
		{ category = "Intel Marker", id = "TextStyleForColor", name = "Text Style For Color", editor = "choice", items = GetTextStyleForColorIDs, default = "IntelEnemy", }
	},
	IntelTextStyle = "IntelEnemyText",
	number_of_units = false,
	dynamicText = true,
}

function EnemyIntelMarker:GameInit()
	local max_area_dim = Max(self.AreaWidth, self.AreaHeight)
	self.IntelAreaRadius = max_area_dim / 2 + 1
end

function EnemyIntelMarker:GetNumberOfUnits()
	local positions = self:GetAreaPositions("ignore_occupied")
	local values = positions.values or empty_table
	local side = self.IntelSide
	local count = 0
	for _, team in ipairs(g_Teams) do
		if team.side == side then
			for _, u in ipairs(team.units) do
				if not u:IsDead() and values[point_pack(SnapToVoxel(u:GetPosXYZ()))] then
					count = count + 1
				end
			end
		end
	end
	return count
end

function EnemyIntelMarker:RefreshNumberOfUnits()
	local old_number = self.number_of_units
	self.number_of_units = self:GetNumberOfUnits()
	return old_number ~= self.number_of_units
end

function EnemyIntelMarker:GetIntelText()
	if not self.number_of_units then
		self:RefreshNumberOfUnits()
	end
	return T{130187357600, "<number> <text>", number = self.number_of_units, text = self.IntelAreaText}
end

function EnemyIntelMarker:Visualize(show, refresh)
	if gv_CurrentSectorId and not gv_Sectors[gv_CurrentSectorId].intel_discovered then return end
	local ch = self:RefreshNumberOfUnits()
	if not ch and refresh then return end
	if self.number_of_units == 0 then
		if refresh then
			show = false
		else
			return
		end
	end
	IntelMarker.Visualize(self, show)
end

DefineClass.ContainerIntelMarker = {
	__parents = { "ContainerMarker", "IntelMarker" },
	properties = {
		{ id = "Type", name = "Type", editor = "text", default = "IntelInventoryItemSpawn", read_only = true, no_edit = true, },
	},
	empty = false,
	dynamicText = true,
}

function ContainerIntelMarker:GetIntelText()
	local intel_text = IntelMarker.GetIntelText(self)
	if not intel_text then
		local namePreset = Presets.ContainerNames.Default[self.Name]
		if namePreset then
			intel_text = namePreset.DisplayName
		end
	end
	
	if self.empty then
		intel_text = T{638798180397, "<text> (Empty)", text = intel_text}
	end
	return intel_text
end

function ContainerIntelMarker:Visualize(show, refresh)
	if gv_CurrentSectorId and not gv_Sectors[gv_CurrentSectorId].intel_discovered then return end
	local empty = not self:GetItemInSlot("Inventory")
	if refresh and self.empty == empty then
		return
	end
	self.empty = empty
	IntelMarker.Visualize(self, show)
end

function LocalCheatRevealIntelForCurrentSector()
	DiscoverIntelForSector(gv_CurrentSectorId)
	if g_Overview then
		VisualizeIntelMarkers(true)
	end
end

function NetSyncEvents.CheatRevealIntelForCurrentSector()
	LocalCheatRevealIntelForCurrentSector()
end

function OnMsg.ValidateMap()
	local campaign = Game and Game.Campaign or rawget(_G, "DefaultCampaign") or "HotDiamonds"
	local campaign_presets = rawget(_G, "CampaignPresets") or empty_table
	local campaign_preset = campaign_presets[campaign]
	local sectors = campaign_preset and campaign_preset.Sectors or empty_table
	local sector = false
	for i, s in ipairs(sectors) do
		if s.Map == CurrentMap then
			sector = s
			break
		end
	end
	if not sector or sector.GroundSector then return end
	
	local markers = MapGet("map", "IntelMarker")
	if not markers or #markers == 0 then
		--StoreErrorSource(false, "Sector", sector.Id, "has no intel markers!")
	end
end

function OnMsg.EnterSector()
	local defenderMarkers = MapGetMarkers("Defender", false, function(m) return m:IsMarkerEnabled() end)
	for i, defMarker in ipairs(defenderMarkers) do
		local defenderIntel = PlaceObject("ImplicitEnemyDefenderIntelMarker")
		defenderIntel:ClearGameFlags(const.gofPermanent) -- place object spawns non-perma, but this is to clarify intention
		defenderIntel:SetPos(defMarker:GetPos())
		defenderIntel:SetAreaWidth(defMarker.AreaWidth)
		defenderIntel:SetAreaHeight(defMarker.AreaHeight)
		defenderIntel:RefreshEnemyCount()
	end
	
	local emplacements = MapGet("map", "MachineGunEmplacement")
	for i, emplacement in ipairs(emplacements) do
		local emplacementIntel = PlaceObject("ImplicitIntelMarker")
		emplacementIntel:ClearGameFlags(const.gofPermanent) -- place object spawns non-perma, but this is to clarify intention
		emplacementIntel:SetPos(emplacement:GetPos())
		emplacementIntel:SetAreaWidth(1)
		emplacementIntel:SetAreaHeight(1)
		emplacementIntel.GetIntelText = function()
			return emplacement:GetTitle()
		end
		emplacementIntel.GetDescription = function(self)
			if emplacement:GetEnumFlags(const.efVisible) == 0 then return end
			
			return ImplicitIntelMarker.GetDescription(self)
		end
		emplacementIntel:SetPOIPreset("Emplacement")
		emplacementIntel.DontShowInList = true
	end
	
	local barrelBadgeDedupe = {}
	local explodingBarrels = MapGet("map", "ExplosiveContainer")
	for i, barrel in ipairs(explodingBarrels) do
		local barrelPos = barrel:GetPos()
		
		for i, dedupePos in ipairs(barrelBadgeDedupe) do
			if IsCloser(barrelPos, dedupePos, 5000) then
				goto continue
			end
		end
		barrelBadgeDedupe[#barrelBadgeDedupe + 1] = barrelPos
		
		local barrelIntel = PlaceObject("ImplicitIntelMarker")
		barrelIntel:ClearGameFlags(const.gofPermanent) -- place object spawns non-perma, but this is to clarify intention
		barrelIntel:SetPos(barrelPos)
		barrelIntel:SetAreaWidth(1)
		barrelIntel:SetAreaHeight(1)
		barrelIntel.GetIntelText = function()
			return barrel.DisplayName
		end
		barrelIntel:SetPOIPreset("ExplodingBarrel")
		barrelIntel.DontShowInList = true
	
		::continue::
	end
	
	if GameState.Night or GameState.Underground then
		local sneakProjector = MapGet("map", "SneakProjector")
		for i, projector in ipairs(sneakProjector) do
			if projector:GetEnumFlags(const.efVisible) == 0 then goto continue end
			
			local projectorIntel = PlaceObject("ImplicitIntelMarker")
			projectorIntel:ClearGameFlags(const.gofPermanent) -- place object spawns non-perma, but this is to clarify intention
			projectorIntel:SetPos(projector:GetPos())
			projectorIntel:SetAreaWidth(1)
			projectorIntel:SetAreaHeight(1)
			projectorIntel.GetIntelText = function()
				return T(641707402624, "Searchlight")
			end
			projectorIntel:SetPOIPreset("Searchlight")
			projectorIntel.DontShowInList = true
			
			::continue::
		end
	end
end

DefineClass.ImplicitEnemyDefenderIntelMarker = {
	__parents = { "ImplicitIntelMarker" },
	
	enemy_count = 0
}

function ImplicitEnemyDefenderIntelMarker:GetEnemyCount()
	--local positions = self:GetAreaPositions("ignore_occupied")
	
	local bbox = self:GetBBox()
	bbox = box(
		bbox:minx(),
		bbox:miny(),
		bbox:minz(),
		bbox:maxx(),
		bbox:maxy(),
		bbox:maxz() + hr.CameraTacFloorHeight * (hr.CameraTacMaxFloor + 1)
	)
	
	-- optimization
	local hasAny = MapGetFirst(bbox, "Unit", function(u)
		return u.team.side == "enemy1" and not u:IsDead()
	end)
	return hasAny and 1 or 0
end

function ImplicitEnemyDefenderIntelMarker:RefreshEnemyCount()
	self.enemy_count = self:GetEnemyCount()
end

function ImplicitEnemyDefenderIntelMarker:GetIntelText()
	local enemyCount = self.enemy_count
	if enemyCount == 0 then return false end
	return T(815679600520, "Enemies"), true
end

function ImplicitEnemyDefenderIntelMarker:IsMarkerEnabled()
	if gv_CurrentSectorId and not gv_Sectors[gv_CurrentSectorId].intel_discovered then return false end
	local enemyCount = self.enemy_count
	return enemyCount > 0
end

local function lRefreshEnemyIntelCounts()
	MapForEach("map", "ImplicitEnemyDefenderIntelMarker", function(m)
		m:RefreshEnemyCount()
	end)
end

function OnMsg.UnitDied()
	DelayedCall(0, lRefreshEnemyIntelCounts)
end

DefineClass.ImplicitIntelMarker = {
	__parents = { "GridMarker" },

	DontShowInList = false,
	area_obj = false,
	text_attach_obj = false,
	area_text = false,
	
	preset_id = false
}

function ImplicitIntelMarker:IsMarkerEnabled()
	if gv_CurrentSectorId and not gv_Sectors[gv_CurrentSectorId].intel_discovered then return false end
	return true
end

-- Override this
function ImplicitIntelMarker:GetIntelText()
	return false
end

function ImplicitIntelMarker:GetDescription()
	if not self.preset_id then return false end
	local preset = IntelPOIPresets[self.preset_id]
	return preset and preset.Text
end

function ImplicitIntelMarker:GetIcon()
	if not self.preset_id then return false end
	local preset = IntelPOIPresets[self.preset_id]
	return preset and preset.Icon
end

function ImplicitIntelMarker:SetPOIPreset(id)
	self.preset_id = id
	assert(IntelPOIPresets[id])
end

function ImplicitIntelMarker:Visualize(show)
	-- Clear old
	if self.area_text then
		self.area_text:delete()
		self.area_text = false
	end

	if self.area_obj then
		DoneObject(self.area_obj)
		self.area_obj = false
	end

	-- Nothing left to do if not recreating
	if not show then
		return
	end
	
	if gv_CurrentSectorId and not gv_Sectors[gv_CurrentSectorId].intel_discovered then return end
	
	local pos = self:GetPos()
	if not pos:IsValidZ() then
		pos = pos:SetZ(terrain.GetHeight(pos))
	end
	
	-- Object to which text will attach.
	if not self.text_attach_obj then
		local attObj = PlaceObject("Object")
		attObj:SetPos(pos:SetZ(pos:z() + 100))
		attObj:SetAngle(0)
		self.text_attach_obj = attObj
	end

	local text, isRed = self:GetIntelText()
	if not text or self.DontShowInList then
		return
	end

	-- Intel text
	local intelText = FlatTextMesh:new({
		text_style_id = isRed and "IntelEnemyText" or "IntelDefaultText",
		text = "[" .. _InternalTranslate(text) .. "]",
	})
	intelText:FetchEffectsFromTextStyle()
	intelText:CalculateSizes(6000, 2500)
	intelText:Recreate()
	intelText:ClearGameFlags(const.gofOnTerrain)
	intelText:SetDepthTest(false)
	intelText:SetMeshFlags(intelText:GetMeshFlags() | const.mfSortByPosZ)

	intelText:SetAttachOffset(point30)
	self.text_attach_obj:Attach(intelText)
	self.area_text = intelText

	-- Create text background
	self.area_obj = PlaceObject("Mesh")
	local mesh_str = pstr("", 1024)
	local radius = Max(self.AreaWidth, self.AreaHeight) * guim / 2
	local angles = 64
	local center = point30
	local color = const.clrWhite
	local r = RotateRadius(radius, 0, center)
	for i=1,angles do
		mesh_str:AppendVertex(center, color, 100)
		mesh_str:AppendVertex(r, color, 0)
		r = RotateRadius(radius, i*60*360/angles, center)
		mesh_str:AppendVertex(r, color, 0)
	end
	--self.area_obj:SetMeshFlags(const.mfWorldSpace)
	self.area_obj:SetMeshFlags(self.area_obj:GetMeshFlags() | const.mfSortByPosZ)
	self.area_obj:SetCRMaterial(CRM_IntelArea:GetById(isRed and "IntelArea_Enemy" or "IntelArea_Default"))
	self.area_obj:SetMesh(mesh_str)
	self.area_obj:ClearGameFlags(const.gofOnTerrain)
	self.area_obj:SetPos(pos)
end

function GetDeploymentUIPOIs()
	local markers = {}
	local intel_markers = GetEnabledIntelMarkers()
	
	for i, im in ipairs(intel_markers) do
		if not IsKindOf(im, "EnemyIntelMarker") then
			markers[#markers + 1] = im
		end
	end
	
	for i, u in ipairs(g_Units) do
		local hasBriefcase = not not HasAnyShipmentItem(u)
		hasBriefcase = hasBriefcase and (u.team.side == "enemy1" or u.team.side == "enemy2" or u:IsDead())
		if hasBriefcase and gv_Sectors[gv_CurrentSectorId].intel_discovered then
			markers[#markers + 1] = u
		end
	end
	
	return markers
end

function GetDeploymentPOIName(poi)
	if IsKindOf(poi, "ContainerIntelMarker") then
		return poi:GetIntelText() or T(899428826682, "Loot")
	elseif IsKindOfClasses(poi, "IntelMarker", "ImplicitIntelMarker") then
		return poi:GetIntelText() or T(304425875136, "Intel")
	elseif IsKindOf(poi, "Unit") then -- Assuming
		local _, shipmentPresetId = HasAnyShipmentItem(poi)
		shipmentPresetId = shipmentPresetId or "DiamondShipment"
		local preset = ShipmentPresets[shipmentPresetId]
		return preset and preset.IntelTitle or T(304425875136, "Intel")
	else
		return GetDeploymentAreaRollover(poi)
	end
end

GameVar("gv_DeploymentShowIntelUI", false)

function OnMsg.CameraTacOverview(set)
	UpdateDeploymentUIIntelBadges(not set and "delete")
	
	if set then
		for target, badges in pairs(g_Badges) do
			for i, b in ipairs(badges) do
				if b.preset == "DiamondBadge" then
					b:SetHandleMouse(true)
					b.ui.idImageIntel:SetVisible(true)
					b.ui.idImage:SetVisible(false)
				end
			end
		end
	else
		for target, badges in pairs(g_Badges) do
			for i, b in ipairs(badges) do
				if b.preset == "DiamondBadge" then
					b:SetHandleMouse(false)
					b.ui.idImageIntel:SetVisible(false)
					b.ui.idImage:SetVisible(true)
				end
			end
		end
	end
	
	ObjModified("CameraTacOverviewModeChanged")
end

function UpdateDeploymentUIIntelBadges(forceDelete)
	if not gv_DeploymentShowIntelUI or forceDelete then
		local removeBadges = {}
		for target, badges in pairs(g_Badges) do
			for i, badge in ipairs(badges) do
				if badge.preset == "DeploymentPOIBadge" then
					removeBadges[#removeBadges + 1] = badge
				end
			end
		end
		for i, b in ipairs(removeBadges) do
			b:Done()
		end
	else
		local pois = GetDeploymentUIPOIs()
		for i, poi in ipairs(pois) do
			local description = (poi.GetDescription and poi:GetDescription() or poi.Description or "")
			if description and description ~= "" then
				local badge = CreateBadgeFromPreset("DeploymentPOIBadge", poi)
				if badge.ui then
					badge.ui:SetRolloverTitle(GetDeploymentPOIName(poi))
					badge.ui:SetRolloverText(description)
					badge.ui.idImage:SetImage(poi:GetIcon())
				end
			end
		end
	end
	ObjModified("gv_DeploymentShowIntelUI")
end

function OnMsg.IntelDiscovered(sectorId)
	if sectorId == gv_CurrentSectorId then
		ObjModified("CornerIntelRespawn")
	end
end