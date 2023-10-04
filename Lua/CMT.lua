if FirstLoad then
	CCMT = true
	C_CCMT = true
	C_CMT_Async = false
end
MapVar("CMT_trigger_target_pairs", false)

function SetCCMT(val)
	if CCMT == val then
		return
	end
	
	if val then
		CMT_trigger_target_pairs = false
	end
	
	SetC_CCMT(val)
	CCMT = val
	ReloadTriggerTargetPairs()
end

function OnMsg.GameEnterEditor()
	StopAllHiding("Editor")
end

function OnMsg.GameExitEditor()
	ResumeAllHiding("Editor")
end

function CObject:SetShadowOnly(bSet)
	if g_CMTPaused then return end
	CMT(self, bSet)
end

function CObject:SetShadowOnlyImmediate(bSet)
	if bSet then
		self:SetHierarchyGameFlags(const.gofSolidShadow)
	else
		self:ClearHierarchyGameFlags(const.gofSolidShadow)
	end
	self:SetOpacity(bSet and 0 or 100)
end

function Decal:SetShadowOnlyImmediate(bSet)
	if bSet then
		self:SetHierarchyGameFlags(const.gofSolidShadow)
	else
		self:ClearHierarchyGameFlags(const.gofSolidShadow)
	end
end

function OnMsg.ChangeMap()
	CMT_SetPause(true, "ChangeMap")
	C_CMT_Reset()
end

function OnMsg.ChangeMapDone()
	ReloadTriggerTargetPairs()
	CMT_SetPause(false, "ChangeMap")
end

function OnMsg.GameExitEditor()
	ReloadTriggerTargetPairs()
end

function ReloadTriggerTargetPairs()
	if GetMap() == "" then
		return
	end
	if CCMT then
		--CCMTMode
		--0 dist check (UseDistCheckForNonTops)
		--1 collision check (UseCollisionForNonTops)
		ReloadCMTTargets((EngineOptions.ObjectDetail == "Low") and 0 or 1)
	else
		local border = GetBorderAreaLimits()
		CMT_trigger_target_pairs = {}
		for _, col in pairs(CollectionsByName) do
			if not IsCollectionLinkedToRooms(col) then
				local objs = MapGet("map", "collection", col.Index, true)
				if col.HideFromCamera then
					CMT_trigger_target_pairs[col] = objs
				elseif not col.DontHideFromCamera then
					local ht
					for _, o in ipairs(objs) do
						if IsKindOf(o, "HideTop") and o:GetGameFlags(const.gofOnRoof) == 0 and (not border or border:Point2DInside(o)) then
							ht = ht or {}
							table.insert(ht, o)
						end
					end
					if ht then
						CMT_trigger_target_pairs[col] = ht
					end
				end
			elseif col.HideFromCamera then
				print("<color 255 0 0> Collection " .. col.Name .. " with index " .. tostring(col.Index) .. " is marked as HideFromCamera but is also linked to rooms, HideFromCamera is ignored!</color>")
			end
		end
		MapForEach("map", "HideTop", function(o)
			local col = o:GetCollection()
			if col or o:GetGameFlags(const.gofOnRoof) ~= 0 then
				return
			end
			if not o.Top then return end
			CMT_trigger_target_pairs[o] = true
		end)
	end
end

local sleep_time = CMT_OpacitySleep*4
MapRealTimeRepeat("CMT_Trigger_Thread", 0, function()
	assert(sleep_time % CMT_OpacitySleep == 0)
	Sleep(sleep_time)
	local startTs = GetPreciseTicks(1000)
	if g_CMTPaused then 
		return 
	end
	local camera_pos, lookAt = cameraTac.GetZoomedPosLookAt()
	local hiding_pt = camera_pos + (lookAt - camera_pos)/2

	if CCMT then
		if C_CMT_Async then
			AsyncC_CMT_Thread_Func(SelectedObj)
		else
			async.AsyncC_CMT_Thread_Func(nil, SelectedObj)
		end
	else
		local hide_collections = CMT_GetCollectionsToHide()
		for trigger, objs in next, CMT_trigger_target_pairs do
			trigger:HandleCMTTrigger(camera_pos, lookAt, hiding_pt, objs, hide_collections)
		end
	end
	local endTs = GetPreciseTicks(1000)
	--print("CCMT", CCMT, "CMT_Trigger_Thread time", endTs - startTs)
end)

local col_mask_any = 2^32-1
local col_mask_all = 0
local cam_pos, lookat
function CMT_GetCollectionsToHide()
	local collided = CMTCollisionDbg and {}
	if CMTCollisionDbg then
		local c, l = GetCamera()
		cam_pos = cam_pos or c
		lookat = lookat or l
		if c ~= cam_pos or l ~= lookat then
			cam_pos = c
			lookat = l
		end
	end
	
	local collections = {}
	local ptCamera, ptCameraLookAt = GetCamera()
	local bbox = box(-2000, -2000, -2000, 2000, 2000, 2000)
	collision.Collide(bbox + ptCamera, ptCameraLookAt - ptCamera, 0, col_mask_all, col_mask_any,
	function(o)
		if not IsValid(o) then return end --happens when editing rooms in editor
		if IsKindOf(o, "HideTop") then return end
		local col = o:GetRootCollection()
		if not col or not col.HideFromCamera or collections[col.Index] then
			return
		end
		
		if CMTCollisionDbg then
			o:SetHierarchyGameFlags(const.gofEditorSelection)
			CMTCollisionDbgShown[o] = true
			collided[o] = true
		end
		
		collections[col.Index] = true
	end)
	
	if CMTCollisionDbg then
		for o, _ in pairs(CMTCollisionDbgShown) do
			if not collided[o] then
				o:ClearHierarchyGameFlags(const.gofEditorSelection)
				CMTCollisionDbgShown[o] = nil
			end
		end
	end
	return collections
end

function Collection:HandleCMTTrigger(camera_pos, lookAt, hiding_pt, objs_to_hide, hide_collections)
	local hide
	if hide_collections[self.Index] then
		hide = true
	else
		for _, obj in ipairs(objs_to_hide) do
			if IsKindOf(obj, "HideTop") and obj:TopHidingCondition(camera_pos, lookAt, hiding_pt) then
				hide = true
				break
			end
		end
	end
	for _, obj in ipairs(objs_to_hide) do
		obj:SetShadowOnly(hide)
	end
end

if FirstLoad then
	CMTCollisionDbg = false
end

MapVar("CMTCollisionDbgShown", {})

function ToggleCMTCollisionDbg()
	for o, _ in pairs(CMTCollisionDbgShown) do
		o:ClearHierarchyGameFlags(const.gofEditorSelection)
		CMTCollisionDbgShown[o] = nil
	end
	CMTCollisionDbg = not CMTCollisionDbg
end

local visualized_cube_count = 3
function VisualizeCMTCube()
	local ptCamera, ptCameraLookAt = GetCamera()
	local bbox = box(-2000, -2000, -2000, 2000, 2000, 2000)
	for i = 1, visualized_cube_count do
		DbgAddBox(bbox + (ptCamera + (ptCameraLookAt - ptCamera)*i/visualized_cube_count), const.clrRed)
	end
end

function IsContourObjectClassAndEntityCheck(obj)
	--used by CCMT
	if IsKindOf(obj, "Slab") then
		if obj.room then
			if obj.room:IsRoofOnly() then 
				return false 
			end
		end
		
		if IsKindOf(obj, "SlabWallObject") then
			if next(obj.decorations) then
				for _, plank in ipairs(obj.decorations) do
					plank:SetHierarchyGameFlags(const.gofContourInner)
				end
			end
			local s = obj.main_wall
			if IsKindOf(s, "RoofWallSlab") then
				return false --no contours for windows on roofs
			end
		end
		
		local entity = obj:GetEntity()
		return (not IsKindOfClasses(obj, "RoofSlab", "RoofWallSlab", "FloorSlab", "CeilingSlab", "RoofCornerWallSlab") and not entity:find("ence"))
	end
	
	return false
end

function IsContourObject(obj)
	if IsContourObjectClassAndEntityCheck(obj) then
		local flr = cameraTac.GetFloor() + 1
		if obj.floor > flr then return false end
		
		return true
	end
	if g_AdditionalContourObjects[obj] then 
		return true
	end
	
	return false
end

------------------------------------------------------------------------------------
--CMTPlane
------------------------------------------------------------------------------------
local mask = const.CMTPlaneFlags
DefineClass.CMTPlane = {
	__parents = { "CObject", "EditorVisibleObject" },
	entity = "CMTPlane",
}

function SetupCMTPlaneCollections(map)
	if map == "" then return end
	local cols = {}
	local collectionlessPlanes = {}
	local allPlanes = {}
	MapForEach("map", "CMTPlane", function(o, cols, allPlanes, collectionlessPlanes)
		allPlanes[o] = true
		local id = o:GetCollectionIndex()
		if id and id ~= 0 then
			cols[id] = true
		else
			table.insert(collectionlessPlanes, o)
		end
	end, cols, allPlanes, collectionlessPlanes)
	
	if next(cols) then
		MapForEach("map", "CObject", function(o, cols, allPlanes)
			if allPlanes[o] then
				collision.SetAllowedMask(o, const.cmSeenByCMT)
				return 
			end
			
			local id = o:GetCollectionIndex()
			if cols[id] then
				local m = collision.GetAllowedMask(o)
				m = m & ~mask
				collision.SetAllowedMask(o, m)
			end
		end, cols, allPlanes)
	end
	
	if #collectionlessPlanes > 0 then
		print("Found " .. #collectionlessPlanes .. " CMTPlane(s) without collections!")
		--should probably kill those?
	end
end

OnMsg.GameExitEditor = SetupCMTPlaneCollections
OnMsg.ChangeMapDone = SetupCMTPlaneCollections

function ToggleVisibilitySystems(reason)
	local turnOn = g_CMTPaused
	if not turnOn then
		StopWallInvisibilityThread()
	end
	CMT_SetPause(not turnOn, reason or "BecauseReasons")
	C_CCMT_ShowAllAndReset()
	if turnOn then
		StartWallInvisibilityThreadWithChecks()
	end
end