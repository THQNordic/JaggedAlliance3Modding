DefineClass.StatsMarker = {
	__parents = { "GridMarker" },
	properties =
	{
		{ category = "Grid Marker", id = "Type", name = "Type", editor = "dropdownlist", items = PresetGroupCombo("GridMarkerType", "Default"), default = "Stats", no_edit = true },
		{ category = "Marker", id = "AreaHeight", name = "Area Height", editor = "number", default = 10, help = "Defining a voxel-aligned rectangle with North-South and East-West axes" },
		{ category = "Marker", id = "AreaWidth",  name = "Area Width", editor = "number", default = 10, help = "Defining a voxel-aligned rectangle with North-South and East-West axes" },
		{ category = "Marker", id = "Color",      name = "Color", editor = "color", default = const.clrYellow},
		{ category = "Marker", id = "Reachable",  name = "Reachable only", editor = "bool", default = false, no_edit = true},
	},
	stats_text = false,
	vertex_weight = false,
	moved = false,
}

local stats_marker_z_offset = 5000
function StatsMarker:UpdateTextStats(obj_cnt, obj_vcnt,  obj_tcnt, shadow_cnt, shadow_vcnt, shadow_tcnt, pt_cnt, pt_vcnt, pt_tcnt, sp_cnt, sp_vcnt, sp_tcnt)
	if not IsValid(self.stats_text) then
		self:DestroyAttaches("Text")
		local text = PlaceObject("Text")
		text:SetTextStyle("InfoText")
		text:SetShadowOffset(2)
		self.stats_text = text
		self:Attach(text)
		text:SetAttachOffset(0, 0, stats_marker_z_offset)
	end
	local text = ""
	if obj_cnt > 0 or shadow_cnt > 0 then
		text = string.format("Main + Shadow: %d/v%dK/t%dK\n", obj_cnt + shadow_cnt, (obj_vcnt + shadow_vcnt)/1000, (obj_tcnt + shadow_tcnt)/1000)
	end
	if pt_cnt > 0 or pt_vcnt > 0 or pt_tcnt > 0 then
		text = string.format("%sPoint light shadow: %d/v%dK/t%dK\n", text, pt_cnt, pt_vcnt/1000, pt_tcnt/1000)
	end
	if sp_cnt > 0 then
		text = string.format("%sSpot light shadow: %d/v%dK/t%dK\n", text, sp_cnt, sp_vcnt/1000, sp_tcnt/1000)
	end
	self.stats_text:SetText(text)
	self.stats_text:SetColor(self.Color)
end

function StatsMarker:GetBox()
	local pos = self:GetPos()
	local width = self.AreaWidth*const.SlabSizeX
	local height = self.AreaHeight*const.SlabSizeY
	local area_left = pos:x() - width/2 - const.SlabSizeX / 2
	local area_top = pos:y() - height/2 - const.SlabSizeY / 2
	return box(area_left, area_top, area_left + width, area_top + height)
end

local excl_classes = {"EditorMarker", "Unit", "AppearanceObject", "Light", "InvisibleObjectHelper"}
function StatsMarker:VisualizeStats()
	if not IsEditorActive() then return end
	local obj_cnt, obj_vcnt,  obj_tcnt, shadow_cnt, shadow_vcnt,
			shadow_tcnt, pt_cnt, pt_vcnt, pt_tcnt, sp_cnt, sp_vcnt, sp_tcnt = GetBoxRenderingStats(self:GetBox(), excl_classes)
	local vertices = (obj_vcnt + shadow_vcnt + pt_vcnt + sp_vcnt)/1000
	local color
	if vertices < 600 then
		color = RGB(0, 255, 0)
	elseif vertices < 1000 then
		color = RGB(224, 224, 0)
	else 
		color = RGB(255, 0, 0)
	end
	self:SetColor(color)
	self:UpdateTextStats(obj_cnt, obj_vcnt, obj_tcnt, shadow_cnt, shadow_vcnt, shadow_tcnt, pt_cnt, pt_vcnt, pt_tcnt, sp_cnt, sp_vcnt, sp_tcnt)
	if self.moved or not self.area_ground_mesh then
		self.moved = false
		self:ShowArea()
	end
end

function StatsMarker:RecalcAreaPositions()
end

function StatsMarker:ShowArea()
	local _ = self.area_ground_mesh and self.area_ground_mesh:delete()
	self.area_ground_mesh = PlaceTerrainBox(self:GetBox():grow(-500, -500), self.Color)
end

function StatsMarker:EditorCallbackMove()
	VoxelSnappingObj.EditorCallbackMove(self)
	self.moved = true
	self:VisualizeStats()
end

function StatsMarker:EditorCallbackPlace()
	GridMarker.EditorCallbackPlace(self)
	g_StatsMarkers = g_StatsMarkers or {}
	table.insert(g_StatsMarkers, self)
	self.moved = true
	CreateRealTimeThread(function(self)
		self:VisualizeStats()
	end, self)
end

function StatsMarker:EditorCallbackDelete()
	GridMarker.EditorCallbackDelete(self)
	if not g_StatsMarkers then return end
	table.remove_entry(g_StatsMarkers, self)
end

MapVar("g_StatsMarkers", false)
if FirstLoad then
	g_StatsMarkersThread = false
end

function OnMsg.GameEnterEditor()
	if not g_StatsMarkers then
		g_StatsMarkers = MapGetMarkers("Stats") or false
	end
	if not g_StatsMarkersThread then
		g_StatsMarkersThread = CreateRealTimeThread(function()
			while true do
				Sleep(5000)
				if IsEditorActive() then
					for _, m in ipairs(g_StatsMarkers or empty_table) do
						m:VisualizeStats()
					end
				end
			end
		end)
	end
end

if FirstLoad then
	g_DbgStatsMarkersVertexSorted = false
	StatsMarkerDbgActionIdx = false
end

local half_box_size_outdoor = 8
local half_box_size_underground = 5
function PopulateMapWithStatsMarkers()
	g_StatsMarkers = g_StatsMarkers or {}
	local half_area_size = IsCurrentMapUnderground() and half_box_size_underground or half_box_size_outdoor
	local first_x = half_area_size*const.SlabSizeX + const.SlabSizeX/2
	local max_x = terrain.GetMapWidth()
	local step_x = 2*half_area_size*const.SlabSizeX
	local first_y = half_area_size*const.SlabSizeY + const.SlabSizeY/2
	local max_y = terrain.GetMapHeight()
	local step_y = 2*half_area_size*const.SlabSizeY
	g_DbgStatsMarkersVertexSorted = {}
	
	for x = first_x, max_x, step_x do
		for y = first_y, max_y, step_y do
			local sm = PlaceObject("StatsMarker")
			if not IsCurrentMapUnderground() then
				sm.AreaWidth = 2*half_box_size_outdoor
				sm.AreaHeight = 2*half_box_size_outdoor
			end
			sm:SetPos(x, y, const.InvalidZ)
			if IsEditorActive() then
				sm:SetHierarchyEnumFlags(const.efVisible)
			end
			table.insert(g_StatsMarkers, sm)
			
			local _, obj_vcnt,  _, _, shadow_vcnt, _, _, pt_vcnt, _, _, sp_vcnt = GetBoxRenderingStats(sm:GetBox())
			sm.vertex_weight = obj_vcnt + shadow_vcnt + pt_vcnt + sp_vcnt
			table.insert(g_DbgStatsMarkersVertexSorted, sm)
			if IsEditorActive() then
				sm:VisualizeStats()
			end
		end
	end
	table.sortby_field(g_DbgStatsMarkersVertexSorted, "vertex_weight")
	PrintLightsTotalStats()
end

function PrintLightsTotalStats()
	local _, _, _, _, _, _, pt_lights, _, _, sp_lights = GetBoxRenderingStats(GetMapBox())
	print(string.format("Point Lights: %d, Spot Lights: %d, Total Lights: %d", pt_lights, sp_lights, pt_lights + sp_lights))
end

function DeleteAllStatsMarkers()
	for _, m in ipairs(g_StatsMarkers or empty_table) do
		DoneObject(m)
	end
	g_StatsMarkers = false
	g_DbgStatsMarkersVertexSorted = false
end

local view_stats_marker_dist = 30000
function ViewHeaviestStatsMarker(rank)
	if not g_DbgStatsMarkersVertexSorted then return end
	ViewObject(g_DbgStatsMarkersVertexSorted[#g_DbgStatsMarkersVertexSorted - rank + 1], view_stats_marker_dist)
end

function StatsMarkerDebugNext()
	if not StatsMarkerDbgActionIdx then
		PopulateMapWithStatsMarkers()
		StatsMarkerDbgActionIdx = 1
	elseif StatsMarkerDbgActionIdx == 5 then
		DeleteAllStatsMarkers()
		StatsMarkerDbgActionIdx = false
	else
		ViewHeaviestStatsMarker(StatsMarkerDbgActionIdx)
		StatsMarkerDbgActionIdx = StatsMarkerDbgActionIdx + 1
	end
end

function OnMsg.NewMapLoaded()
	StatsMarkerDbgActionIdx = false
end

local underground_maps = {
	"H-3 - Bunker FB45-68",
	"L-6U - Underground Prison",
}
function IsCurrentMapUnderground()
	return table.find(underground_maps, mapdata.id)
end