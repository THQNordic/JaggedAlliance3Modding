if FirstLoad then
	g_VSDbgVisModeThread = false
	restoreDbgValue = false
	g_VSDbgMode = false
end

function OnMsg.NewMapLoaded()
	g_VSDbgVisModeThread = false
	g_VSDbgMode = false
end

local dbgVectorsOffset = 200
local z_vector = point(0,0,3000)
local vs_dbg_vis_voxel_range = 8
local last_cam, last_lookat, last_cursor_slab

local function PlaceLitVector(pos)
	local v = GetVoxelStealthParams(pos)
	if band(v, const.vsFlagIlluminated) ~= 0 then
		DbgAddVector(pos:SetX(pos:x() - dbgVectorsOffset), z_vector, const.clrWhite)
	end
	if band(v, const.vsFlagTallGrass) ~= 0 then
		DbgAddVector(pos:SetX(pos:x() + dbgVectorsOffset), z_vector, const.clrGreen)
	end
end

local function PlaceCursorLitVectors(pos)
	if not pos then return end
	
	local _, overall_illum, lights, lights_illum = DebugGetVoxelStealthParams(pos)
	for idx, l in ipairs(lights) do
		if IsValid(l) then
			local l_pos = l:GetPos()
			DbgAddVector(l_pos, pos - l_pos, const.clrYellow)
			local text = string.format("%.2f / %.2f", lights_illum[idx], const.vsIlluminationThreshold)
			DbgAddText(text, (l_pos + pos) / 2, const.clrYellow, nil, const.clrBlack)
		end
	end
	local text = string.format("Overall: %.2f/%.2f", overall_illum, const.vsIlluminationThreshold)
	DbgAddText(text, pos, const.clrYellow, nil, const.clrBlack)
end

local function PlaceLitVectorsAround(pos_around)
	if not pos_around then return end
	
	DbgAddVector(pos_around, z_vector * 2, const.clrMagenta)
	local x, y, z = pos_around:xyz()
	local pt = point(x - vs_dbg_vis_voxel_range, y - vs_dbg_vis_voxel_range, z - vs_dbg_vis_voxel_range)
	for i = -vs_dbg_vis_voxel_range, vs_dbg_vis_voxel_range do
		for j = -vs_dbg_vis_voxel_range, vs_dbg_vis_voxel_range do
			for k = -2 * vs_dbg_vis_voxel_range, 2 * vs_dbg_vis_voxel_range do
				local pos = SnapToPassSlab(x + i * const.SlabSizeX, y + j * const.SlabSizeY, z + k * const.SlabSizeZ)
				if pos then
					PlaceLitVector(pos)
				end
			end
		end
	end
end

local function PlaceMapAreaLitVoxels()
	local sizex, sizey = terrain.GetMapSize()
	local bbox =  box(0, 0, sizex, sizey)
	ForEachStealthParamVoxel(bbox, const.vsFlagIlluminated + const.vsFlagTallGrass, function(pos, stealth_mask)
		pos = pos:IsValidZ() and pos or pos:SetTerrainZ()
		if band(stealth_mask, const.vsFlagIlluminated) ~= 0 then
			DbgAddVector(pos:SetX(pos:x() - dbgVectorsOffset), z_vector, const.clrWhite)
		end
		if band(stealth_mask, const.vsFlagTallGrass) ~= 0 then
			DbgAddVector(pos:SetX(pos:x() + dbgVectorsOffset), z_vector, const.clrGreen)
		end
	end)
end

local function GetCursorSlabForLitCheck()
	local cursor_obj = GetPreciseCursorObj()
	local cursor_slab = cursor_obj and cursor_obj:GetPos() or GetCursorPos()
	local z = cursor_slab:z()
	local lit_check = point(VoxelToWorld(WorldToVoxel(cursor_slab)))
	
	return z and lit_check:SetZ(z) or lit_check
end

local function LightAroundCursor(cursor_slab)
	hr.VoxelStealthParamsDebugCacheCleared = false
	PlaceCursorLitVectors(cursor_slab)
end

local function IsLitChanged(cursor_slab)
	return last_cursor_slab ~= cursor_slab or hr.VoxelStealthParamsDebugCacheCleared
end

local function DrawCameraVectors(cursor_slab, cam, lookat)
	DbgClear()
	local box = GetVoxelBox(0, GetCameraLookatTerrainPos())
	PlaceLitVectorsAround(box and box:Center() or GetCameraLookatTerrainPos())
	LightAroundCursor(cursor_slab)
	last_cursor_slab = cursor_slab
	last_cam = cam
	last_lookat = lookat
end

local function DrawMapVectors(cursor_slab)
	DbgClear()
	LightAroundCursor(cursor_slab)
	PlaceMapAreaLitVoxels()
	last_cursor_slab = cursor_slab
end

function CycleVSDbgVisMode()
	g_VSDbgMode = (g_VSDbgMode or 0) + 1
	if g_VSDbgMode == 3 then
		g_VSDbgMode = false
	end
	if g_VSDbgMode == 1 then
		print("Voxel Stealth Dbg Camera Look At is ON")
		ResetVoxelStealthParamsCache()
		ShowLightShadowsStats(1000)
		if g_VSDbgVisModeThread then return end
		if not hr.VoxelStealthParamsDebug then
			restoreDbgValue = true
			hr.VoxelStealthParamsDebug = true
		end
		g_VSDbgVisModeThread = CreateMapRealTimeThread(function()
			repeat
				local cam, lookat = GetCamera()
				local cursor_slab = GetCursorSlabForLitCheck()
				if IsLitChanged(cursor_slab) or cam ~= last_cam or lookat ~= last_lookat then
					DrawCameraVectors(cursor_slab, cam, lookat)
				end
				Sleep(500)
			until false
		end)
	elseif g_VSDbgMode == 2 then
		print("Voxel Stealth Dbg Whole Map ON")
		ResetVoxelStealthParamsCache()
		ShowLightShadowsStats(1000)
		DeleteThread(g_VSDbgVisModeThread)
		g_VSDbgVisModeThread = CreateMapRealTimeThread(function()
			repeat
				local cursor_slab = GetCursorSlabForLitCheck()
				if IsLitChanged(cursor_slab) then
					DrawMapVectors(cursor_slab)
				end
				Sleep(500)
			until false
		end)
	else
		print("Voxel Stealth Dbg OFF")
		DbgClear()
		if restoreDbgValue then
			restoreDbgValue = false
			hr.VoxelStealthParamsDebug = false
		end
		DeleteThread(g_VSDbgVisModeThread)
		HideLightShadowsStats()
		g_VSDbgVisModeThread = false
	end
end

local s_StealthCacheProperty = {
	["DetailClass"] = true,
	["Exterior"] = true,
	["Interior"] = true,
	["AttenuationRadius"] = true,
	["InteriorAndExteriorWhenHasShadowmap"] = true,
	["Intensity"] = true,
	["ConstantIntensity"] = true,
	["ConeInnerAngle"] = true,
	["ConeOuterAngle"] = true,
}

function OnMsg.GedPropertyEdited(_, obj, prop_id, old_value)
	if s_StealthCacheProperty[prop_id] and IsKindOf(obj, "Light") then
		Msg("LightsStateUpdated")
	end
end

local function check_light_objects(objects)
	local function is_light_edited(obj)
		if obj:IsKindOf("Light") then return true end

		local light_edited
		obj:ForEachAttach(function(attach)
			if is_light_edited(attach) then
				light_edited = true
				return "break"
			end
		end)
		
		return light_edited
	end
	
	for _, obj in ipairs(table.validate(objects)) do
		if is_light_edited(obj) then
			Msg("LightsStateUpdated")
			break
		end
	end
end

function OnMsg.EditorCallback(id, objects, ...)
	if id == "EditorCallbackRotate" or id == "EditorCallbackPlace" or id == "EditorCallbackMove" or id == "EditorCallbackDelete" then
		check_light_objects(objects)
	end
end

function OnMsg.EditorResetZ()
	local sel = editor.GetSel()
	if #(sel or empty_table) > 0 then
		check_light_objects(sel)
	end
end

