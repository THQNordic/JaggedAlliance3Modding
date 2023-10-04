InteractableCollectionMaxRange = 10 * guim
InteractableMaxRangeInTiles = 4
InteractableMaxSurfacesRadius = 12000

DefineClass.ContouredInteractable = { 
	contourWhenInvisible = true
}

--[[@@@
@class Interactable
Interactable is a base class for things like item containers, items lying on the ground, doors, NPCs - objects in tactical view that mercs in exploration/combat can interact with when commanded by the player.
They provide abstract "is interaction enabled" and "interact" methods, implemented in the child classes.
--]]
DefineClass.Interactable = {
	__parents = { "CObject", "PropertyObject", "GameDynamicDataObject", "EditorObject" },
	properties = {
		{ category = "Interactable", id = "BadgePosition", name = "Badge Position", editor = "choice", items = { "self", "average" }, default = "average" },
		{ category = "Interactable", id = "range_in_tiles", name = "Interaction Distance (Voxels)", editor = "number", default = 2 },
		{ category = "Interactable", id = "enabled", name = "CanBeEnabled", editor = "bool", default = true, help = "used by the DisableInteractionMarkerEffect to enable/disable interactables" },
	},
	
	highlight = true,
	interactable_badge = false,
	intensely_highlit = false,
	until_interacted_with_highlight = false,
	until_interacted_with_highlight_suspended = false,
	highlit = false,

	interaction_last_highlight = false,
	interaction_spot = "Interaction",
	interaction_log = false,

	highlight_reasons = false,
	highlight_cooldown_time = false,
	highlight_thread = false,
	highlight_collection = true,
	
	marker_selectable = true,
	
	volume_badge_hiding = true,
	volume = false,
	volume_checking_thread = false,
	volume_hidden = false,

	discovered = false,
	
	spawner = false, -- If the interactable is to be spawned by a ShowHideCollectionMarker
	visuals_spawners = false, -- List of spawners that can potentially spawn visual objects for the interactable
	visuals_cache = false, -- All interactable visuals, cached at GameInit
	visuals_just_decals = false,
	los_check_obj = false, -- The interactable visual or marker to perform los checks against

	interact_positions = false,
	being_interacted_with = false,
}

function Interactable:Init()
	self.highlight_reasons = {}
end

function Interactable:GameInit()
	self:PopulateVisualCache()

	if not self.volume_badge_hiding then return end
	local badgeSpot = self:GetInteractableBadgeSpot() or "Origin"
	self.volume = EnumVolumes(IsPoint(badgeSpot) and badgeSpot or self, "smallest")

	-- Doors are between two rooms, if they only used the volume hiding logic
	-- they would hide when the room "they belong to" is hidden.
	-- So instead they are hidden when the camera floor is different than their, unless
	-- the room of their volume(if any) is hidden.
	if IsKindOf(self, "SlabWallDoor") then
		self.volume_checking_thread = CreateGameTimeThread(function(self)
			local myFloor = WallInvisibilityGetCamFloor(self:GetPos())
			while IsValid(self) do
				Sleep(500)
				if IsEditorActive() or not self.interactable_badge then goto continue end
				local visible = self:FloorCheckingThreadProc(myFloor, volume)
				--if not visible then DbgAddVector(self:GetPos(), point(0, 0, guim * 15), const.clrGreen) end
				self.interactable_badge:SetVisible(self.volume)
				self.volume_hidden = not visible
				::continue::
			end
		end, self)
	elseif self.volume then
		self.volume_checking_thread = CreateGameTimeThread(function(self)
			while IsValid(self) do
				Sleep(500)
				if IsEditorActive() or not self.interactable_badge then goto continue end
				local visible = self:VolumeCheckingThreadProc(self.volume)
				--if not visible then DbgAddVector(self:GetPos(), point(0, 0, guim * 15), const.clrRed) end
				self.interactable_badge:SetVisible(visible)
				self.volume_hidden = not visible
				::continue::
			end
		end, self)
	end
end

if FirstLoad then
	g_AdditionalContourObjects = {}
end

function Interactable:PopulateVisualCache()
	self.visuals_cache = false
	self.spawner = false

	-- Mark all visual objects as selectable. Even those who are invisible as they might get shown by a script.
	local visuals = ResolveInteractableVisualObjects(self, 0, "no_cache") or empty_table
	for i, v in ipairs(visuals) do
		v:SetEnumFlags(const.efSelectable)
		if v.contourWhenInvisible then -- Add contour outer to specific interactables
			g_AdditionalContourObjects[v] = true
		end
	end
	local imTheVisual = #visuals == 1 and visuals[1] == self
	if #visuals > 0 and self.BadgePosition ~= "self" and not imTheVisual then
		self:ClearEnumFlags(const.efSelectable)
		self.marker_selectable = false
	end
	
	if not imTheVisual then
		local justDecals = true
		local hasAtLeastOneDecal = false
		for i, v in ipairs(visuals) do
			local isDecal = IsKindOf(v, "Decal")
			if not isDecal and v ~= self then
				justDecals = false
			end
			hasAtLeastOneDecal = hasAtLeastOneDecal or isDecal
		end
		self.visuals_just_decals = justDecals
	end

	for i, obj in ipairs(visuals) do
		if IsKindOf(obj, "UnitMarker") then
			if not self.visuals_spawners then self.visuals_spawners = {} end
			table.insert(self.visuals_spawners, obj)
		elseif IsKindOf(obj, "ShowHideCollectionMarker") then
			if self.spawner then
				StoreErrorSource(self, "Multiple spawners (ContainerMarker/ShowHideCollection) in interactable collection")
			end
			self.spawner = obj
		end
	end
	
	local excludedClasses = {"Room", "Interactable", "GridMarker", "InvisibleObject"}
	if not self.visuals_just_decals then
		excludedClasses[#excludedClasses + 1] = "Decal"
	end
	
	local largest, largestSize = false, 0
	for i, vis in ipairs(visuals) do
		if not IsKindOfClasses(vis, excludedClasses) then
			local _, size = vis:GetBSphere()
			if size > largestSize then
				largest = vis
				largestSize = size
			end
		end
	end
	self.los_check_obj = largest
	self.visuals_cache = visuals
end

function Interactable:EditorExit()
	self:PopulateVisualCache()
end

function Interactable:VolumeCheckingThreadProc(volume)
	if table.find(self.highlight_reasons, "hotkey") then return true end
	if table.find(self.highlight_reasons, "cursor") then return true end

	local hiddenWalls = VT2CollapsedWalls and VT2CollapsedWalls[volume]
	if not hiddenWalls then
		return false
	end
	return true
end

function Interactable:FloorCheckingThreadProc(myFloor, volume)
	if table.find(self.highlight_reasons, "hotkey") then return true end
	if table.find(self.highlight_reasons, "cursor") then return true end
	
	local cameraFloor = cameraTac.GetFloor()
	if cameraFloor ~= myFloor then
		local hiddenWalls = VT2CollapsedWalls and VT2CollapsedWalls[volume]
		if not hiddenWalls or not hiddenWalls.Roof then
			return false
		end
	end
	return true
end

function Interactable:Done()
	DeleteThread(self.highlight_thread)
end

--[[@@@
@function CombatAction Interactable@GetInteractionCombatAction(Unit unit)
@param Unit unit - The unit who wants to interact with the object.
@result CombatAction - The CombatAction which defines the interaction.
]]
function Interactable:GetInteractionCombatAction(unit)
	--see Presets.CombatAction.Interactions
end

--[[@@@
Returns a position, where the unit must stand in order to interact with this object.
The return values can either be:
 - position - specific position (usually a spot)
 - array of points - array of positions where to stand (angle is still an integer, and not an array)
 - map of points, angle, preferred points - array of all points, (angle is still an integer, and not an array), array of prefered points

In the last case, where the interactable has "preferred" and "normal" interaction points,
 the unit will first try to go to the prefferd points. If that fails it will go to the normal points.
But before any movement begins, if it's already standing on any of the points, then no movement will occur.
@function point Interactable@GetInteractionPos(Unit unit)
@param Unit unit - the unit who wants to interact with the object.
@result Point, angle - Where the unit must stand to interact with the object. The angle is always optional.
]]
function Interactable:GetInteractionPos(unit)
	local interact_positions = self.interact_positions
	if not interact_positions then
		-- newly created objects could have no cached points
		interact_positions = GetInteractablePos(self) or empty_table
		self.interact_positions = interact_positions
		if #interact_positions > 0 then
			local farther_pos
			for i, pos in ipairs(interact_positions) do
				if i == 1 or IsCloser2D(self, farther_pos, pos) then
					farther_pos = pos
				end
			end
			if not IsCloser2D(self, farther_pos, InteractableMaxSurfacesRadius) then
				local message = string.format("InteractableMaxSurfacesRadius(%d) is not enough. %s(%s, handle=%d) farther interact position distance is %d", InteractableMaxSurfacesRadius, self.class, self:GetEntity(), self.handle, self:GetDist2D(farther_pos))
				GameTestsError("once", message)
			end
		end
	end
	-- return a table with not occupied positions (return interact_positions if possible and skip creating a new table)
	if not unit or #interact_positions == 0 then
		return
	end

	-- return the closest position when there is a interaction spot
	if self:HasSpot(self.interaction_spot) then
		local closest_spot_pos = interact_positions[1]
		if unit then
			for i = 2, #interact_positions do
				if IsCloser(unit, interact_positions[i], closest_spot_pos) then
					closest_spot_pos = interact_positions[i]
				end
			end
		end
		return closest_spot_pos
	end

	local result
	local count = 0
	for i, pt in ipairs(interact_positions) do
		if CanOccupy(unit, pt) then
			count = count + 1
			if count < i then
				if not result then
					result = {}
					for j = 1, count - 1 do
						result[j] = interact_positions[j]
					end
				end
				result[count] = pt
			end
		end
	end
	if count == 0 then
		return
	elseif count == #interact_positions then
		return interact_positions
	else
		if not result then
			result = {}
			for j = 1, count do
				result[j] = interact_positions[j]
			end
		end
		return result
	end
end

local interactable_range = const.SlabSizeX + const.PassTileSize / 2
local interactable_range_box = box(-interactable_range, -interactable_range, -const.SlabSizeZ, interactable_range + 1, interactable_range + 1, const.SlabSizeZ + 1)
local interactable_collision_offset = const.passSpheroidCollisionOffsetZ

function Interactable:GetInteractionPosOld(unit)
	--try to find the passable spot closest to the unit
	local first, last = self:GetSpotRange(self.interaction_spot)
	if first < last then
		local closest_spot, closest_spot_pos
		for i = first, last do
			local p = SnapToPassSlab(self:GetSpotLocPosXYZ(i))
			if p then
				if not closest_spot or unit and IsCloser(unit, p, closest_spot_pos) then
					closest_spot = i
					closest_spot_pos = p
				end
			end
		end
		if closest_spot then
			local closest_spot_angle = self:GetSpotAngle2D(closest_spot)
			return closest_spot_pos, closest_spot_angle
		end
	end

	-- collect positions that the unit must be able to reach
	local pos_to_reach = { }

	-- Starting with the position of the interactable itself
	local myPos = self:GetPos()
	pos_to_reach[1] = myPos

	local objs = ResolveInteractableVisualObjects(self)
	for i, visual_obj in ipairs(objs) do
		local center, radius = visual_obj:GetBSphere()
		table.insert(pos_to_reach, center)
	end
	
	-- note: could we potentially only return on the first found valid position?

	-- create "reachability segments" for each voxel and each position
	-- batch by 10 voxels until at least one interaction position is found
	local stance_idx = StancesList["Standing"]
	local positionsProcessed = 1
	local head_offset = const.passSpheroidCollisionOffsetZ
	while positionsProcessed < #pos_to_reach do
		-- process positions until we run out of them or reach 10 voxels
		local voxels = { }
		local segments = { }
		for i = positionsProcessed, #pos_to_reach do
			if #voxels >= 10 then break end
			
			local pos = pos_to_reach[i]
			local pos3D = pos
			if not pos3D:IsValidZ() then 
				pos3D = pos:SetTerrainZ()
			end

			local center_x, center_y, center_z = pos3D:xyz()
			center_x, center_y, center_z = SnapToVoxel(center_x, center_y, SnapToVoxelZ(center_x, center_y, center_z))
			pos3D = pos3D:SetZ(pos3D:z() + head_offset)

			local voxel_enum_box = Offset(interactable_range_box, center_x, center_y, center_z)
			ForEachPassSlab(voxel_enum_box, function(x, y, z, center_x, center_y, center_z, unit, voxels, segments, stance_idx, pos3D)
				--TODO this check doesn't always work
				if x == center_x and y == center_y then
					local voxelz = SnapToVoxelZ(x, y, z) --fix invalid z
					if voxelz == center_z then
						return
					end
				end
				if unit and not CanOccupy(unit, x, y, z) then
					return
				end
				table.insert(voxels, point(x, y, z))
				table.insert(segments, stance_head_pos(stance_pos_pack(x, y, z, stance_idx)))
				table.insert(segments, pos3D)
			end, center_x, center_y, center_z, unit, voxels, segments, stance_idx, pos3D)

			positionsProcessed = positionsProcessed + 1
		end
		if not next(voxels) then
			local selfPassSlab = SnapToPassSlab(self)
			if not selfPassSlab then -- The interactable is in an impassable location
				return terrain.FindPassable(myPos, unit)
			end
			return empty_table
		end
		
		-- check collected segments
		local any_hit, hit_points, hit_objs = CollideSegmentsObjs(segments)
		if not any_hit then return voxels end
		
		local result = false
		for i, pt in ipairs(voxels) do
			local noHit = not hit_points[i]
			local terrainHit = not hit_objs[i]
			
			-- hit a shared visual object of this interactable
			local sharedObjectHit = false
			if not noHit and not terrainHit then
				local int, allInteractables = ResolveInteractableObject(hit_objs[i])
				sharedObjectHit = int == self or allInteractables and table.find(allInteractables, self)
			end
			
			if noHit or terrainHit or sharedObjectHit	then
				if not result then result = {} end -- lazy allocate
				table.insert(result, pt)
			end
		end
		
		if result then
			-- Don't allow "close enough to interact" checks if there were collisions in the way.
			result.mustMove = not unit or not table.find(result, unit:GetPos())
			return result
		end
	end

	return empty_table
end

InteractionLogEvents = { "start", "end" }
InteractionLogResults = {
	["Lockpick"] = { false, "success", "fail" },
	["Break"] = { false, "success", "fail" },
	["Interact_Disarm"] = { false, "success", "fail" },
	["Interact_LootUnit"] = { false, "looted" },
	["Interact_LootContainer"] = { false, "looted" },
}

function Interactable:LogInteraction(unit, combatActionId, event, resultSpecifier)
	if not self.interaction_log then
		self.interaction_log = { }
	end
	
	local interaction = {
		unit_template_id = unit.unitdatadef_id,
		action = combatActionId,
		event = event
	}
	if resultSpecifier then interaction.result = resultSpecifier end
	table.insert(self.interaction_log, interaction)
	
	self:InteractableHighlightUntilInteractedWith(false)
end

function Interactable:RegisterInteractingUnit(unit)
end

function Interactable:UnregisterInteractingUnit(unit)
end

--[[@@@
Called by the unit just before the interaction begins.
@function void Interactable@BeginInteraction(Unit unit)
@param Unit unit - the unit which interacts with this object.
]]
function Interactable:BeginInteraction(unit)
end

--[[@@@
Called by the unit just after the interaction ends.
@function void Interactable@EndInteraction(Unit unit)
@param Unit unit - the unit which interacts with this object.
]]
function Interactable:EndInteraction(unit)
	local canInteractWith = UICanInteractWith(unit, self)
	if not canInteractWith then
		table.clear(self.highlight_reasons)
		self:HighlightIntensely(false)
	end
end

--[[@@@
Returns the icon path which is spawned above the interactable when highlighted (if any).
@function striing Interactable@GetInteractionVisuals(Unit unit)
@Param Unit unit - the unit which interacts with this object
]]
function Interactable:GetInteractionVisuals(unit)
	local action, iconOverride = self:GetInteractionCombatAction(unit or UIFindInteractWith(self))
	if action then
		return iconOverride or action.Icon
	end
end

function Interactable:UpdateInteractableBadge(visible, image)
	local badge = self.interactable_badge
	if badge and visible and badge.target == self and IsKindOf(badge.ui, "XImage") and badge.ui.Image == image then return end
	if not not badge == not not visible then return end

	if badge and not visible then
		badge:delete()
		self.interactable_badge = false
		return
	end

	if not IsValid(self) then return end

	if not badge and visible then
		badge = CreateBadgeFromPreset("InteractableBadge", { target = self, spot = self:GetInteractableBadgeSpot() or "Origin" }, self)
		if not badge then return end
		
		-- Start off hidden, the volume checking will show it
		if self.volume_hidden then
			badge:SetVisible(false)
		end
	end
	badge.ui.idImage:SetImage(image)
	assert(not self.interactable_badge)
	self.interactable_badge = badge
end

function Interactable:BadgeTextUpdate()
	local badgeInstance = self.interactable_badge
	if not badgeInstance or badgeInstance.ui.window_state == "destroying" then
		return
	end
	if IsUnitPartOfAnyActiveBanter(self) then
		badgeInstance.ui.idText:SetVisible(false)
		return
	end
	local unit = UIFindInteractWith(self)
	if unit then
		local action = self:GetInteractionCombatAction(unit)
		badgeInstance.ui.idText:SetContext(unit)
		if action == CombatActions.Interact_Talk or action == CombatActions.Interact_Banter then
			badgeInstance.ui.idText:SetText(T{418007709502, "<ActionName> <style UIHeaderLabelsAccent>(<Nick>)</style>", ActionName = T{action:GetActionDisplayName({unit, self}), target = self, unit = unit}, Nick = unit.Nick})
		elseif #Selection > 1 and not action.DontShowWith then
			badgeInstance.ui.idText:SetText(T{562471619295, "<ActionName> with <Nick>", ActionName = T{action:GetActionDisplayName({unit, self}), target = self, unit = unit}, Nick = unit.Nick})
		else
			badgeInstance.ui.idText:SetText(T{501564765631, "<ActionName>", ActionName = T{action:GetActionDisplayName({unit, self}), target = self, unit = unit}})
		end
	end
	local withCursor = table.find(self.highlight_reasons, "cursor")
	badgeInstance.ui.idText:SetVisible(withCursor)
end

function Interactable:GetHighlightColor()
	return 3
end

function Interactable:SetHighlightColorModifier(visible)
	local color_modifier = visible and const.clrWhite or const.clrNoModifier
	self:SetColorModifier(color_modifier)
end

MapVar("InteractableColorModifierStorage", {})

--will apply interaction highlighting to obj, obj's attaches and everything in the collection (optionally)
function SetInteractionHighlightRecursive(obj, visible, highlight, highlight_col, clr_contour, force_passed_color)
	clr_contour = clr_contour or 3

	assert(not not highlight) -- if always true, rename to highlightType and remove if below

	if highlight then
		if IsKindOf(obj, "Interactable") then
			if obj:SetHighlightColorModifier(visible) == "break" then return end
			clr_contour = not force_passed_color and obj:GetHighlightColor() or clr_contour
		else
			if not InteractableColorModifierStorage[obj] then
				local current_mod = obj:GetColorModifier()
				if current_mod ~= const.clrNoModifier and current_mod ~= const.clrWhite then
					InteractableColorModifierStorage[obj] = current_mod
				end
			end
			local color_modifier
			if visible then
				if InteractableColorModifierStorage[obj] then
					color_modifier = InterpolateRGB(InteractableColorModifierStorage[obj], const.clrWhite, 20, 255)
				else
					color_modifier = const.clrWhite
				end
			else
				color_modifier = InteractableColorModifierStorage[obj] or const.clrNoModifier
			end
			obj:SetColorModifier(color_modifier)
		end

		if visible then
			obj:SetContourOuterID(true, clr_contour)
			obj:ForEachAttach(function(att, clr)
				att:SetContourOuterID(true, clr)
			end, clr_contour)
		else
			obj:ClearHierarchyGameFlags(const.gofContourOuter)
			obj:SetContourOuterID(false, clr_contour)
			obj:ForEachAttach(function(att, clr)
				att:SetContourOuterID(false, clr)
			end, clr_contour)
		end
	end

	if IsValid(obj) then
		C_CCMT_SetObjOpacityOneMode(obj, visible and highlight == "hidden-too")
	end

	if highlight_col then
		local visual_objs = ResolveInteractableVisualObjects(obj)
		for i, o in ipairs(visual_objs) do
			if o ~= obj then
				SetInteractionHighlightRecursive(o, visible, highlight, false, clr_contour)
			end
		end
	end

	obj:ForEachAttach(function(att, ...)
		SetInteractionHighlightRecursive(att, ...)
	end, visible, highlight, false, clr_contour)
end

-- Interactables are highlit when rollovered and in other cases.
function Interactable:HighlightIntensely(visible, reason)
	local noChangeNeeded = false
	local highlight_reasons = self.highlight_reasons
	if reason then
		if visible then
			if not table.find_value(highlight_reasons, reason) then
				highlight_reasons[#highlight_reasons + 1] = reason
				if #highlight_reasons > 1 then noChangeNeeded = true end
			end
		elseif #highlight_reasons == 0 then
			noChangeNeeded = true
		else
			table.remove_value(highlight_reasons, reason)
			if #highlight_reasons > 0 then
				noChangeNeeded = true
				visible = true
			end
		end
	end
	noChangeNeeded = noChangeNeeded and self.intensely_highlit == visible 
	
	-- If the cursor is on the interactable the badge must behave as if rollovered.
	if reason == "cursor" and self.interactable_badge and self.interactable_badge.ui then
		self.interactable_badge.ui.RolloverOnFocus = true
		if not GetUIStyleGamepad() then
			self.interactable_badge.ui:SetFocus(visible)
		end
	end
	local hotkeyHighlight = visible and reason == "hotkey"
	local badgeOnly = #highlight_reasons == 1 and highlight_reasons[1] == "badge-only"
	
	if not hotkeyHighlight and not badgeOnly and noChangeNeeded then
		self:BadgeTextUpdate()
		return
	end

	self.intensely_highlit = visible
	local visuals = visible and self:GetInteractionVisuals() or self.interaction_last_highlight
	self.interaction_last_highlight = visuals
	self:UpdateInteractableBadge(visible, visuals)
	local highlightOn = visible and not badgeOnly
	SetInteractionHighlightRecursive(self, highlightOn, hotkeyHighlight and "hidden-too" or true, self.highlight_collection)
	self:BadgeTextUpdate()
end

function Interactable:InteractableHighlightUntilInteractedWith(apply)
	if apply and self:HasMember("IsMarkerEnabled") and not self:IsMarkerEnabled({}) then
		return
	end
	if IsKindOf(self, "Unit") then
		self:SetHighlightReason("can_be_interacted", apply)
	end
	
	local visuals = self.visuals_cache
	
	for i, v in ipairs(visuals) do
		local dead = v:HasMember("IsDead") and v:IsDead()
		local marking = (apply and not dead) and 11 or -1
		v:SetObjectMarking(marking)
		if marking < 0 then
			v:ClearHierarchyGameFlags(const.gofObjectMarking)
		else
			v:SetHierarchyGameFlags(const.gofObjectMarking)
		end
	end
	
	self.until_interacted_with_highlight = apply
end

function Interactable:UnitNearbyHighlight(time, cooldown, force)
	if not force and self.highlight_cooldown_time and GameTime() - self.highlight_cooldown_time < 0 then
		return false
	end
	local clr_contour =  5
	local period = Presets.ContourOuterParameters.Default.DefaultParameters["period_5"] or 3000
	if period == 0 then period = 1000 end 

	self.highlight_cooldown_time = GameTime() + cooldown
	time = RoundUp(time, period)

	local visuals = self.visuals_cache
	
	self:InteractableHighlightUntilInteractedWith(true)

	DeleteThread(self.highlight_thread)
	self.highlight_thread = CreateGameTimeThread(function(self)
		local interactionLogCount = #(self.interaction_log or "")
		local start = GameTime()
		local tick = 0

		local proper_start = RoundUp(start, period)
		Sleep(proper_start - start)
		start = proper_start

		for i, v in ipairs(visuals) do
			v:SetContourRecursive(true, clr_contour)
		end
		while GameTime() - start < time do
			-- Observe changes in the length of the interaction log, which
			-- tell us that someone has interacted with the interactable in question.
			if #(self.interaction_log or "") > interactionLogCount then
				break
			end
			if not self:GetInteractionCombatAction() then
				break
			end
			Sleep(200)
		end
		
		self.highlight_thread = nil
		for i, v in ipairs(visuals) do
			v:SetContourRecursive(false, clr_contour)
		end
	end, self)
	return true
end

function Interactable:SetDynamicData(data)
	self.interaction_log = data.interaction_log
	if data.enabled ~= nil then self.enabled = data.enabled end
	if data.discovered then self.discovered = data.discovered end
	
	if data.until_interacted_with_highlight then
		self:InteractableHighlightUntilInteractedWith(true)
	end
end

function Interactable:GetDynamicData(data)
	if #(self.interaction_log or "") > 0 then
		data.interaction_log = self.interaction_log
	end
	data.enabled = self.enabled
	if self.discovered then data.discovered = self.discovered end
	
	if self.until_interacted_with_highlight then
		data.until_interacted_with_highlight = self.until_interacted_with_highlight
	end
end

function Interactable:GetInteractableBadgeSpot()
	if self.BadgePosition ~= "average" then return "Origin" end
	local sumX = 0
	local sumY = 0
	local sumZ = 0
	local collection = ResolveInteractableVisualObjects(self)
	local count = 0
	for i, s in ipairs(collection) do
		-- Exclude invisible objects
		if s:GetEnumFlags(const.efVisible) ~= 0 then
			local badgeSpot = s:GetSpotBeginIndex("Interactablebadge")
			if badgeSpot and badgeSpot ~= -1 then
				return s:GetSpotPos(badgeSpot)
			end
			badgeSpot = s:GetSpotBeginIndex("Badge")
			if badgeSpot and badgeSpot ~= -1 then
				return s:GetSpotPos(badgeSpot)
			end

			local x, y, z = s:GetPosXYZ()
			sumX = sumX + x
			sumY = sumY + y
			sumZ = sumZ + (z or terrain.GetHeight(x, y))
			count = count + 1
		end
	end
	if count == 0 then return "Origin" end
	
	local averagePosition = point(sumX, sumY, sumZ) / count
	return averagePosition
end

local SkipRebuildInteractables = {
	"Unit",
	"Door",
	"MachineGunEmplacement",
	"Landmine",
	"ExplosiveContainer",
}

function RebuildInteractablesList(interactables)
	local positions = GetInteractablePos(interactables)
	for i, obj in ipairs(interactables) do
		obj.interact_positions = positions[i] or empty_table
	end

	--[[ debug code
	for i, obj in ipairs(interactables) do
		local pos1 = obj:GetInteractionPosOld()
		local pos2 = GetInteractablePos(obj) or empty_table
		local same = IsPoint(pos1) and #pos2 == 1 and pos1 == pos2[1]
		local diff
		if not same and type(pos1) == "table" then
			for k = #pos1, 1, -1 do
				for m = k-1, 1, -1 do
					if pos1[m] == pos1[k] then
						table.remove(pos1, m)
					end
				end
			end
			same = type(pos1) == "table" and #pos1 == #pos2
			for i = 1, #pos1 do
				if not table.find(pos2, pos1[i]) then
					same = false
				end
			end
		end
		if not same then
			printf("Interactable difference: %s, %d", obj.class, obj.handle)
			printf("      pos1 = %s", type(pos1) == "table" and TableToLuaCode(pos1) or tostring(pos1))
			printf("      pos2 = %s", TableToLuaCode(pos2))
			ViewObject(obj)
			for i = 1, 10 do
				local p1 = obj:GetInteractionPosOld()
				local p2 = GetInteractablePos(obj)
			end
		end
	end
	--]]
end

function RebuildAreaInteractables(clip)
	local area
	if clip then
		local obj_max_radius = InteractableMaxSurfacesRadius or GetEntityMaxSurfacesRadius()
		area = clip:grow(obj_max_radius + (InteractableMaxRangeInTiles + 1) * const.SlabSizeX)
	end
	MapForEach(area or "map", "Interactable", function(o)
		if o:IsKindOfClasses(SkipRebuildInteractables) then
			return -- handled somewhere else
		end
		o.interact_positions = false
	end)
end

--[[@@@
Resolves the interactable in a collection.
An interactable can be in a collection with other objects.
One is the interactable and the rest are considered visuals.
@function object ResolveInteractableObject(obj)
@param obj - An object in the collection.
]]
function ResolveInteractableObject(obj)
	if not IsKindOf(obj, "CObject") then return end

	local spawner = rawget(obj, "spawner")
	if spawner and spawner ~= obj and
		(obj.highlight_collection or not IsKindOf(obj, "Interactable")) then
		local markerInteractable, mrkGroup = ResolveInteractableObject(spawner)
		if markerInteractable then
			return markerInteractable, mrkGroup
		end
	end

	-- This interactable is acting as the visual of another interactable.
	-- Case: doors in exit zone interactables
	local int1 = obj.visual_of_interactable
	local int2 = obj ~= int1 and IsKindOf(obj, "Interactable") and obj

	local originalObject = obj
	obj = SelectionPropagate(obj)
	local int3 = obj ~= originalObject and obj ~= int1 and IsKindOf(obj, "Interactable") and obj

	local interactables
	local root_collection = obj:GetRootCollection()
	local collection_idx = root_collection and root_collection.Index or 0
	if collection_idx ~= 0 then
		interactables = MapGet(obj, InteractableCollectionMaxRange, "collection", collection_idx, true, "Interactable")
	end

	local interactable1 = int1 or int2 or int3 or interactables and interactables[1]
	if not interactable1 then
		return
	end

	local highlight_collection =
		int1 and int1.highlight_collection or
		int2 and int2.highlight_collection or
		int3 and int3.highlight_collection
	if not highlight_collection and interactables then
		for i, int in ipairs(interactables) do
			if int.highlight_collection then
				highlight_collection = true
				break
			end
		end
	end

	if highlight_collection then
		-- If the interactable we're about to return has highlight_collection off, then we shouldn't return it
		-- if we got to it through propagating an object in its collection
		if int1 and not int1.highlight_collection then int1 = nil end
		if int2 and not int2.highlight_collection then int2 = nil end
		if int3 and not int3.highlight_collection then int3 = nil end
		interactable1 = int1 or int2 or int3
		local count
		if interactables then
			for i = #interactables, 1, -1 do
				if not interactables[i].highlight_collection then
					table.remove(interactables, i)
				end
			end
			if int3 then
				interactables[table.find(interactables, int3) or #interactables + 1] = interactables[1]
				interactables[1] = int3
			end
			if int2 then
				interactables[table.find(interactables, int2) or #interactables + 1] = interactables[1]
				interactables[1] = int2
			end
			if int1 then
				interactables[table.find(interactables, int1) or #interactables + 1] = interactables[1]
				interactables[1] = int1
			end
			interactable1 = interactable1 or interactables[1]
			count = #interactables
		else
			count = (int1 and 1 or 0) + (int2 and 1 or 0) + (int3 and 1 or 0)
			if count > 1 then
				interactables = {}
				if int1 then table.insert(int1) end
				if int2 then table.insert_unique(int2) end
				if int3 then table.insert_unique(int3) end
			end
		end
		if count > 1 then
			return interactable1, interactables
		end
		return interactable1
	end

	if interactable1 ~= originalObject then
		-- check if the interactable1 is the only interactable
		if (not int2 or int2 == interactable1) and
			(not int3 or int3 == interactable1) and
			(not interactables or #interactables == 0 or #interactables == 1 and interactables[1] == interactable1)
		then
			return
		end
	end

	return interactable1
end

--[[@@
Resolves the list of visuals objects in a collection.
An interactable can be in a collection with other objects.
One is the interactable and the rest are considered visuals.
@function array ResolveInteractableVisualObjects(obj)
@param obj - An object in the collection.
]]

function ResolveInteractableVisualObjects(obj, flag, skipCache, findFirst)
	if not obj.highlight_collection then
		return findFirst and obj or { obj }
	end
	local collection_objs = not skipCache and obj.visuals_cache
	if collection_objs then
		local count = #collection_objs
		if count == 1 and IsKindOf(collection_objs[1], "Interactable") then
			return findFirst and collection_objs[1] or collection_objs
		end
		-- Cleanup destroyed objects
		if count > 0 then
			local anyDestroyed, anyNonDecal
			for i = count, 1, -1 do
				local o = collection_objs[i]
				if IsObjectDestroyed(o) then
					SetInteractionHighlightRecursive(o, false, true)
					anyDestroyed = true
					table.remove(collection_objs, i)
					count = count - 1
				elseif not anyNonDecal and not IsKindOf(o, "Decal") and o ~= obj then
					anyNonDecal = true
				end
			end
			if anyDestroyed then
				local allLeftoverAreNonSelectableMarkers = true
				for i, collectionObj in ipairs(collection_objs) do
					if not IsKindOf(collectionObj, "Interactable") or collectionObj.marker_selectable then
						allLeftoverAreNonSelectableMarkers = false
					end
				end
				if allLeftoverAreNonSelectableMarkers then
					collection_objs = empty_table
				end
				obj.los_check_obj = collection_objs[1] or obj
				obj.visuals_cache = collection_objs
			end
			-- If all objects but the decals are destroyed, consider all destroyed.
			-- Unless! All interactable visuals are decals.
			if not anyNonDecal and not obj.visuals_just_decals then
				obj.los_check_obj = false
				obj.visuals_cache = empty_table
			end
		end
	else
		-- This case is usually ran once to populate the visuals_cache
		local root_collection = obj:GetRootCollection()
		local collection_idx = root_collection and root_collection.Index or 0
		if collection_idx == 0 then
			return findFirst and obj or { obj }
		end

		collection_objs = MapGet(obj, InteractableCollectionMaxRange, "collection", collection_idx, true, flag or const.efVisible)

		-- If the interactable is its own visual, return it. This basically equalizes the above "no collection" case
		-- with the "accidentally made a collection of one object" case.
		if collection_objs and #collection_objs == 1 and IsKindOf(collection_objs[1], "Interactable") then
			return findFirst and collection_objs[1] or collection_objs
		end
	end

	if findFirst and collection_objs and collection_objs[1] then
		return collection_objs[1]
	end

	-- Add any objects spawned by associated visual spawners.
	if obj.visuals_spawners then
		local t = collection_objs ~= obj.visuals_cache and collection_objs
		for i, sp in ipairs(obj.visuals_spawners) do
			for i, o in ipairs(sp.objects) do
				if findFirst then
					return o
				end
				if not t then
					t = table.copy{collection_objs}
				end
				table.insert(t, o)
			end
		end
		collection_objs = t or collection_objs
	end

	return (not findFirst) and collection_objs or collection_objs[1]
end

function OnMsg.GatherFXActions(list)
	table.insert(list, "InteractableIntenseHighlight")
	table.insert(list, "InteractableHighlight")
end

function OnMsg.GameTimeStart()
	MapForEach("map", "Interactable", function(interactable)
		--some more exceptions
		if IsKindOfClasses(interactable, InteractableClassesThatAreDestroyable) then return end
		-- Containers can be destroyed.
		if IsKindOf(interactable, "ContainerMarker") then return end
		-- Booby trapped objects should be able to blow up themselves.
		if IsKindOf(interactable, "Trap") and interactable.boobyTrapType ~= BoobyTrapTypeNone then
			return
		end

		local visuals = ResolveInteractableVisualObjects(interactable)
		for _, obj in ipairs(visuals) do
			if not IsKindOfClasses(obj, InteractableClassesThatAreDestroyable) then
				TemporarilyInvulnerableObjs[obj] = true
			end
		end
	end)
end

function SpawnedByEnabledMarker(obj)
	if obj:HasMember("spawner") and obj.spawner and obj.spawner:IsKindOf("GridMarker") then
		if obj.spawner == obj and not obj:IsMarkerEnabled() then
			return false
		end
	
		return obj.spawner:IsKindOf("ShowHideCollectionMarker") and obj.spawner.last_spawned_objects
	end
	if IsKindOf(obj, "ShowHideCollectionMarker") then
		return obj:IsMarkerEnabled() and obj:IsKindOf("ShowHideCollectionMarker") and obj.last_spawned_objects
	end

	return true
end

function OnMsg.UnitSideChanged(unit)
	if unit and unit.highlight_reasons and #unit.highlight_reasons > 0 then
		table.clear(unit.highlight_reasons)
		unit:HighlightIntensely(false)
	end
end

if Platform.developer then

local function GetObjCollectionIdx(obj)
	if not obj.highlight_collection then return end

	local root_collection = obj:GetRootCollection()
	local collection_idx = root_collection and root_collection.Index or 0
	if collection_idx == 0 then return end
	
	return collection_idx
end

function InteractableCollectionsTooBigVME()
	MapForEach("map", "Interactable", function(obj)
		local collection_idx = GetObjCollectionIdx(obj)
		if not collection_idx then
			return
		end
		local collection_objs = MapForEach("map", "collection", collection_idx, true, function(colObj, obj)
			if IsKindOf(colObj, "Interactable") then
				return
			elseif IsCloser(colObj, obj, InteractableCollectionMaxRange + 1) then
				return
			end
			StoreErrorSource(colObj, "Object in interactable collection is further from than interactable than what is allowed. " .. colObj:GetDist(obj) .. " > " .. InteractableCollectionMaxRange)
		end, obj)
	end)
end

OnMsg.PostSaveMap = InteractableCollectionsTooBigVME
OnMsg.NewMapLoaded = InteractableCollectionsTooBigVME

function MakeInteractableCollectionsEssentialsOnly()
	MapForEach("map", "Interactable", function(obj)
		local collection_idx = GetObjCollectionIdx(obj)
		if not collection_idx then
			return
		end
		local collection_objs = MapForEach("map", "collection", collection_idx, true, function(colObj, obj)
			if IsKindOf(colObj, "Interactable") then
				return
			elseif colObj:GetDetailClass() == "Essential" then
				return
			end
			StoreErrorSource(colObj, "Object in collection with interactable is not 'Essential' - forcing it to save as such!", obj)
			colObj:SetDetailClass("Essential")
		end, obj)
	end)
end

OnMsg.PreSaveMap = MakeInteractableCollectionsEssentialsOnly

end

local lInteractableVisibilityRange = 10 * guim

function OnMsg.ExplorationTick()
	local units = GetAllPlayerUnitsOnMap()
	InteractableVisibilityUpdate(units)
end

function OnMsg.CombatGotoStep(unit)
	if g_Combat and not g_Combat.combat_started then return end -- Everyone repositions while combat is starting.
	if unit and unit.team and unit.team.side == "player1" then
		InteractableVisibilityUpdate({ unit })
	end
end

function OnMsg.ClassesGenerate(classdefs)
	local class = classdefs["ContourOuterParameters"]
	table.insert(class.properties, {
		id = "default_time", editor = "number", scale = 1000, default = 5001, category = "ID: 5",
	})
	table.insert(class.properties, {
		id = "default_cooldown", editor = "number", scale = 1000, default = 60 * 1000, category = "ID: 5",
	})
end

local __InteractableVisibility_Units = {}
local __InteractableVisibility_Targets = {}
local __InteractableVisibility_TargetsLOSCheck = {}
local __InteractableVisibility_CanNoLongerInteractWith = {}

function InteractableVisibilityUpdate(units)
	if IsSetpiecePlaying() then
		return
	end
	table.iclear(__InteractableVisibility_Units)
	table.iclear(__InteractableVisibility_Targets)
	table.iclear(__InteractableVisibility_TargetsLOSCheck)
	table.iclear(__InteractableVisibility_CanNoLongerInteractWith)
	for i, unit in ipairs(units) do
		if IsValid(unit) and unit:CanBeControlled(-1) then
			MapForEach(unit, lInteractableVisibilityRange, "Interactable", function(o, unit)
				local checkLos = true
				local checkCanStillInteract = o.until_interacted_with_highlight
				
				if o.discovered then
					checkCanStillInteract = true
				end
				
				if IsKindOf(i, "Unit") then
					checkLos = not not o:IsDead()
				elseif IsKindOf(o, "ExitZoneInteractable") then
					checkLos = false
				end
				
				local canInteractWith = false
				if checkLos or checkCanStillInteract then
					canInteractWith = unit:CanInteractWith(o)
				end
			
				if checkLos and canInteractWith then
					table.insert(__InteractableVisibility_Units, unit)
					table.insert(__InteractableVisibility_Targets, o)
					table.insert(__InteractableVisibility_TargetsLOSCheck, o.los_check_obj or o)
				elseif checkCanStillInteract and not canInteractWith then
					table.insert_unique(__InteractableVisibility_CanNoLongerInteractWith, o)
				end
			end, unit)
		end
	end

	-- Clear "until interacted with" highlight from interactables that are no longer interactable.
	if #__InteractableVisibility_CanNoLongerInteractWith > 0 then
		for i, o in ipairs(__InteractableVisibility_CanNoLongerInteractWith) do
			if not table.find_value(__InteractableVisibility_Targets, o) then
				o:InteractableHighlightUntilInteractedWith(false)
			end
		end
		table.iclear(__InteractableVisibility_CanNoLongerInteractWith)
	end

	if #__InteractableVisibility_Targets > 0 then
		local any_los, losData = CheckLOS(__InteractableVisibility_TargetsLOSCheck, __InteractableVisibility_Units, lInteractableVisibilityRange)
		if any_los then
			local preset = Presets.ContourOuterParameters.Default.DefaultParameters
			local voice_response_idx, voice_response_type
			for i, los_value in ipairs(losData) do
				if los_value then
					local o = __InteractableVisibility_Targets[i]
					if not o.discovered then
						o.discovered = true
						if not g_Combat and voice_response_type ~= "LootFound" then
							if IsKindOfClasses(o, "Unit", "ItemContainer") then
								voice_response_idx = i
								voice_response_type = "LootFound"
							elseif not voice_response_type and not IsKindOf(o, "CuttableFence") and not IsKindOf(o, "Landmine") then
								voice_response_idx = i
								voice_response_type = "InteractableFound"
							end
						end
					end
					o:UnitNearbyHighlight(preset.default_time, preset.default_cooldown)
				end
			end
			if voice_response_type then
				local pickedUnit = RandomSelectNearUnit(__InteractableVisibility_Units[voice_response_idx], const.SlabSizeX * 5)
				PlayVoiceResponse(pickedUnit, voice_response_type)
			end
		end
		table.iclear(__InteractableVisibility_Units)
		table.iclear(__InteractableVisibility_Targets)
		table.iclear(__InteractableVisibility_TargetsLOSCheck)
	end
end

function OnMsg.UnitDied(unit)
	-- Discover units killed in combat, but dont run the normal discovery logic with los etc.
	if unit then
		unit.discovered = true
		if unit:IsDead() and unit:GetItemInSlot("InventoryDead") then
			unit:InteractableHighlightUntilInteractedWith(true)
		end
	end
end

--return random unit from unit's team in a given distance
function RandomSelectNearUnit(unit, distance)
	local units = {}
	for _, u in ipairs(unit.team.units) do
		if u:GetDist(unit) <= distance then
			table.insert(units, u)
		end
	end
	return table.rand(units, InteractionRand(1000000, "InteractableVR"))
end

function GetAllInteractablesOnFloors()
	if not CanYield() then
		CreateRealTimeThread(GiveMeAllInteractablesOnFloors)
		return
	end
	
	local interactables = {}
	ForEachMap(ListMaps(), function()
		MapForEach("map", "Interactable", function(o)
			if IsKindOf(o, "CuttableFence") and not o:GetInteractionPos() then
				return
			end
		
			if o:IsValidZ() and not IsKindOf(o, "Door") then
				if not interactables[CurrentMap] then
					interactables[CurrentMap] = {}
				end
				
				local tbl = interactables[CurrentMap]
				tbl[#tbl + 1] = tostring(o.class) .. "@" .. tostring(o:GetPos())
			end
		end)
	end)
	
	local err = AsyncStringToFile("AppData/Interactables.txt", TableToLuaCode(interactables))
end

function CalcInteractableMaxSurfacesRadius()
	local max_radius = 0
	for name, class in pairs(g_Classes) do
		if IsKindOf(class, "Interactable") and IsValidEntity(class:GetEntity()) then
			local r = GetEntityMaxSurfacesRadius(class:GetEntity())
			if max_radius < r then
				max_radius = r
			end
		end
	end
	return max_radius
end

-- used while in a setpiece
function SuspendInteractableHighlights()
	MapForEach("map", "Interactable", function(m)
		if m.until_interacted_with_highlight then
			m:InteractableHighlightUntilInteractedWith(false)
			m.until_interacted_with_highlight_suspended = true
		end
	end)
end

function ResumeInteractableHightlights()
	MapForEach("map", "Interactable", function(m)
		if m.until_interacted_with_highlight_suspended then
			m:InteractableHighlightUntilInteractedWith(true)
			m.until_interacted_with_highlight_suspended = false
		end
	end)
end
