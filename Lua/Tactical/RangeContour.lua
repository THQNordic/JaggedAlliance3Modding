 -- offset against voxel border
const.ContoursOffset = -80
const.ContoursOffset_Merc = -85
const.ContoursOffset_BorderlineAttack = const.ContoursOffset -90
const.ContoursOffset_BorderlineTurn = const.ContoursOffset
-- z offset
const.ContoursOffsetZ = 15*guic
const.ContoursOffsetZ_Merc = const.ContoursOffsetZ +30
const.ContoursOffsetZ_BorderlineAttack = const.ContoursOffsetZ 
const.ContoursOffsetZ_BorderlineTurn = const.ContoursOffsetZ 
-- width
const.ContoursWidth = 480 / 5
const.ContoursWidth_Merc = const.ContoursWidth
const.ContoursWidth_BorderlineAttack = const.ContoursWidth
const.ContoursWidth_BorderlineTurn = const.ContoursWidth
-- turn radius
const.ContoursRadius2D = 180
const.ContoursRadius2D_Merc = 180
const.ContoursRadius2D_Merc_Exploration = 500
const.ContoursRadiusVertical = 80
const.ContoursRadiusSteps = 8
-- voxel connectivity
const.ContoursPassConnection = false
const.ContoursTunnelMask =
	const.TunnelMaskWalk
	| const.TunnelMaskClimbDrop
	| const.TunnelTypeLadder
	| const.TunnelTypeJumpOver1
	| const.TunnelTypeDoor
	| const.TunnelTypeWindow


function GetRangeContour(voxels, contour_width, radius2D, offset, offsetz, voxel_pass_connection, tunnels_mask, exclude_voxels)
	if not voxels or #voxels == 0 then
		return
	end
	contour_width = contour_width or const.ContoursWidth
	radius2D = radius2D or const.ContoursRadius2D
	local radius_vertical = const.ContoursRadiusVertical
	offset = offset or const.ContoursOffset
	offsetz = offsetz or const.ContoursOffsetZ
	voxel_pass_connection = voxel_pass_connection or const.ContoursPassConnection
	tunnels_mask = tunnels_mask or const.ContoursTunnelMask
	local contours = GetContoursPStr(voxels, voxel_pass_connection, tunnels_mask, contour_width, radius2D, radius_vertical, offset, offsetz)
	return contours
end


local function RGBToModifier(r, g, b)
	local r = MulDivRound(r, 100, 255)
	local g = MulDivRound(g, 100, 255)
	local b = MulDivRound(b, 100, 255)
	return RGB(r, g, b)
end
function PlaceContourPolyline(contour, color, shader)
	local meshes = {
		SetVisible = function(self, value)
			for _, m in ipairs(self) do
				m:SetVisible(value)
			end
		end
	}
	shader = shader or "range_contour"
	if type(color) == "string" then
		color = Mesh.ColorFromTextStyle(color)
	else
		local r, g, b, opacity = GetRGBA(color)
		color = RGBToModifier(r, g, b)
	end
	for _, v_pstr in ipairs(contour) do
		local mesh = PlaceObject("Mesh")
		mesh:SetColorModifier(color)
		mesh:SetMesh(v_pstr)
		if not ProceduralMeshShaders[shader] then
			mesh:SetCRMaterial(shader)
		else
			mesh:SetShader(ProceduralMeshShaders[shader])
		end
		mesh:SetPos(0, 0, 0)
		table.insert(meshes, mesh)
	end
	return meshes
end

function PlaceSingleTileStaticContourMesh(color_textstyle_id, pos, exploration)
	local r = const.SlabSizeX / 2 + const.ContoursOffset_Merc
	local z = const.ContoursOffsetZ_Merc
	local contour = GetRectContourPStr(box(-r, -r, z, r, r, z), const.ContoursWidth_Merc, exploration and const.ContoursRadius2D_Merc_Exploration or const.ContoursRadius2D_Merc)
	local polyline = PlaceContourPolyline({contour}, color_textstyle_id)
	if pos then
		polyline[1]:SetPos(pos)
	end
	return polyline[1]
end

function DestroyMesh(mesh)
	if IsValid(mesh) then
		mesh:delete()
	end
end

function DestroyContourPolyline(meshes)
	if not meshes then return end
	for _, mesh in ipairs(meshes) do
		DestroyMesh(mesh)
	end
	table.iclear(meshes)
end

function ContourPolylineSetVisible(meshes, visible)
	for _, mesh in ipairs(meshes) do
		if IsValid(mesh) then
			if visible then
				mesh:SetEnumFlags(const.efVisible)
			else
				mesh:ClearEnumFlags(const.efVisible)
			end
		end
	end
end

function ContourPolylineSetColor(meshes, color_textstyle_id)
	for _, mesh in ipairs(meshes) do
		mesh:SetColorFromTextStyle(color_textstyle_id)
	end
end

function ContourPolylineSetShader(meshes, shader)
	shader = ProceduralMeshShaders[shader]
	for _, mesh in ipairs(meshes) do
		if mesh.shader ~= shader then
			mesh:SetShader(shader)
		end
	end
end

function PlaceGroundRectMesh(v_pstr, color_textstyle_id, shader)
	shader = shader or "ground_strokes"
	local mesh = PlaceObject("Mesh")
	if color_textstyle_id then
		mesh:SetColorFromTextStyle(color_textstyle_id)
	end
	mesh:SetMesh(v_pstr)
	mesh:SetPos(0, 0, 0)
	if IsKindOf(shader, "CRMaterial") then
		mesh:SetCRMaterial(shader)
	else
		mesh:SetShader(ProceduralMeshShaders[shader])
	end
	mesh:SetDepthTest(true)
	return mesh
end

local reload_prop_ids = {TextColor = true, ShadowColor = true, ShadowSize = true, }
function TextStyle:OnEditorSetProperty(prop_id, old_value, ged)
	if self.group == "Zulu Ingame" and reload_prop_ids[prop_id] then
		DelayedCall(300, MapForEach, "map", "Mesh", function(mesh)
			if mesh.textstyle_id == self.id then
				mesh:SetColorFromTextStyle(self.id)
			end
		end)
	end
end

DefineClass.CRM_RangeContourPreset = {
	__parents = { "CRMaterial" },
	group = "RangeContourPreset",
	properties = {
		{ uniform = true, id = "depth_softness", editor = "number", default = 0, scale = 1000, min = -2000, max = 2000, slider = true, },
		{ uniform = true, id = "fill_color", editor = "color", default = RGB(0, 255, 0) },
		{ uniform = true, id = "border_color", editor = "color", default = RGB(255, 255, 255) },
		{ uniform = true, id = "dash_color", editor = "color", default = RGB(255, 255, 255) },

		{ uniform = true, id = "fill_width", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, slider = true, },
		{ uniform = true, id = "border_width", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, slider = true, },
		{ uniform = true, id = "border_softness", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, slider = true, },

		{ uniform = true, id = "dash_density", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 1000},
		{ uniform = true, id = "dash_segment", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 100000},

		{ uniform = true, id = "anim_speed", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 10000},
		{ uniform = true, id = "grain_strength", editor = "number", scale = 1000, default = 200, slider = true, min = 0, max = 1000},
		{ uniform = true, id = "interlacing_strength", editor = "number", scale = 1000, default = 200, slider = true, min = 0, max = 1000},
	},

	shader_id = "range_contour_default",
}

DefineClass.CRM_RangeContourControllerPreset = {
	__parents = { "CRMaterial" },
	group = "RangeContourControllerPreset",

	shader_id = "combat_border",
	properties = {
		{ id = "contour_base_inside", editor = "preset_id", preset_class = "CRM_RangeContourPreset", default = false, },
		{ id = "contour_base_outside", editor = "preset_id", preset_class = "CRM_RangeContourPreset", default = false, },
		{ id = "contour_fx_inside", editor = "preset_id", preset_class = "CRM_RangeContourPreset", default = false, },
		{ id = "contour_fx_outside", editor = "preset_id", preset_class = "CRM_RangeContourPreset", default = false, },

		{ uniform = "integer", id = "fade_inout_start", editor = "number", scale = 1, default = 0, no_edit = true, dont_save = true, },
		{ uniform = true, id = "fade_in", editor = "number", scale = 1000, default = 200, min = 0, max = 2000, slider = true, },
		{ uniform = true, id = "cursor_alpha_distance", editor = "number", scale = 1000, default = 1000, min = 0, max = 3000, slider = true, },
		{ uniform = true, id = "cursor_alpha_falloff", editor = "number", scale = 1000, default = 1000, min = 0, max = 25000, slider = true, },
		
		{ uniform = "integer", id = "pop_in_start", editor = "number", scale = 1, default = 0, no_edit = true, dont_save = true,  },
		{ id = "pop_delay", editor = "number", scale = 1, default = 0, },
		{ uniform = true, id = "pop_in_time", editor = "number", scale = 1000, default = 500, slider = true, min = 0, max = 1200, },
		{ uniform = true, id = "pop_in_freq", editor = "number", scale = 1000, default = 200, slider = true, min = 0, max = 1200, },

		{ id = "is_inside", editor = "bool", default = false, no_edit = true, dont_save = true,  },

		{ uniform = true, id = "ZOffset", editor = "number", default = false, scale = 1000, no_edit = true, default = 0, }
	},
}

function CRM_RangeContourControllerPreset:Recreate()
	self.dirty = false

	local pstr_buffer = self.pstr_buffer

	local preset = CRM_RangeContourPreset:GetById(self.is_inside and self.contour_base_inside or self.contour_base_outside)
	pstr_buffer = preset:WriteBuffer(pstr_buffer)

	local preset2 = CRM_RangeContourPreset:GetById(self.is_inside and self.contour_fx_inside or self.contour_fx_outside)
	pstr_buffer = preset2:WriteBuffer(pstr_buffer, 4 * 12)

	self:WriteBuffer(pstr_buffer, 4 * 12 * 2 )
	self.pstr_buffer = pstr_buffer
end

function CRM_RangeContourControllerPreset:SetIsInside(value, notimereset)
	value = value and true or false
	if self.is_inside ~= value then
		self.is_inside = value
		if not notimereset then
			self.fade_inout_start =  RealTime()
		end
		self.dirty = true
	end
end


DefineClass.RangeContourMesh = {
	__parents = {"Mesh"},

	preset_id = false,

	polyline = false,
	exclude_polyline = false,
	use_exclude_polyline = true,

	meshes = false,
	dirty_geometry = false,
}

function RangeContourMesh:SetPolyline(polyline, exclude_polyline)
	self.polyline = polyline
	self.exclude_polyline = exclude_polyline
end

function RangeContourMesh:SetPreset(preset)
	if type(preset) == "string" then
		preset = CRM_RangeContourControllerPreset:GetById(preset)
	end
	if self.CRMaterial and preset.id == self.CRMaterial.id  then
		return
	end
	self:SetCRMaterial(preset:Clone())
end

function RangeContourMesh:SetVisible(value)
	for _, mesh in ipairs(self.meshes or empty_table) do
		mesh:SetVisible(value)
	end
	if self.visible ~= value then
		self.CRMaterial.pop_in_start = RealTime() + self.CRMaterial.pop_delay
		self.visible = value
		self.CRMaterial.dirty = true
	end
end

function RangeContourMesh:SetIsInside(value)
	self.CRMaterial:SetIsInside(value)
end

function RangeContourMesh:SetUseExcludePolyline(value)
	if self.use_exclude_polyline ~= value then
		self.use_exclude_polyline = value
		self.dirty_geometry = true
	end
end

function RangeContourMesh:Recreate(force_geometry)
	if #(self.meshes or empty_table) == 0 then
		force_geometry = true
	end
	if force_geometry or self.dirty_geometry then
		self.dirty_geometry = false
		for _, mesh in ipairs(self.meshes) do
			mesh:delete()
		end
		--self.polyline.side_len = 200
		self.meshes = PlaceContourPolyline(self.polyline, RGB(255, 255, 255), self.CRMaterial, self.use_exclude_polyline and self.exclude_polyline)
	else
		for _, mesh in ipairs(self.meshes) do
			mesh:SetCRMaterial(self.CRMaterial)
		end
	end
end

function RangeContourMesh:delete()
	for _, mesh in ipairs(self.meshes or empty_table) do
		mesh:delete()
	end
	self.meshes = false
	Mesh.delete(self)
end

function CRM_RangeContourPreset:Apply()
	CRMaterial.Apply(self)
	self.cached_uniform_buf = self:GetDataPstr()
	if CurrentMap ~= "" then
		MapGet("map", "RangeContourMesh", function(o)
			if o.preset_id == self.id then
				o:Recreate()
			end
		end)
	end
end

RegisterSceneParam({
	id = "CursorPos", type = "float", elements = 3, default = { 0, 0, 0 }, scale = 1000, prop_id = false,
})
local cursor_pos_table = {0,0,0}
MapRealTimeRepeat("RangeContourSceneParam", 33, function()
	local pos = GetCursorPos()
	if pos then
		cursor_pos_table[1], cursor_pos_table[2], cursor_pos_table[3] = pos:xyz()
		local interp_time = next(PauseReasons) and 0 or 33
		SetSceneParamEx(1, "CursorPos", cursor_pos_table, interp_time)
	end
end)
