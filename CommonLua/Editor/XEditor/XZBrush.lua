local supported_fmt = {[".tga"] = true, [".raw"] = true}
local thumb_fmt = {[".tga"] = true, [".png"] = true }
local textures_folders = {"svnAssets/Source/Editor/ZBrush"}
local thumbs_folders = {"svnAssets/Source/Editor/ZBrushThumbs"}

local function store_as_by_category(self, prop_meta) return prop_meta.id .. "_for_" .. self:GetCategory() end

DefineClass.XZBrush = {
	__parents = { "XEditorTool" },
	properties = {
		persisted_setting = true,
		store_as = function(self, prop_meta) -- store settings per texture
			if prop_meta.id == "BrushPattern" then
				return prop_meta.id
			else
				return prop_meta.id .. "_for_" .. self:GetBrushPattern()
			end
		end,
		{ id = "BrushHeightChange", name = "Height change",      editor = "number", default = 500*guim, min = -1000*guim, max = 1000*guim, scale = "m", slider = true, help = "Height change corresponding to the texture levels", buttons = {{name = "Invert", func = "ActionHeightChangeInvert"}} },
		{ id = "BrushZeroLevel",    name = "Texture zero level", editor = "number", default = -1,  min = -1, max = 255, slider = true, help = "The grayscale level corresponding to zero height. If negative, the top-left corner value would be used." },
		{ id = "BrushDistortAmp",   name = "Distort amplitude",  editor = "number", default = 10, min = 1, max = 30, slider = true },
		{ id = "BrushDistortFreq",  name = "Distort frequency",  editor = "number", default = 1,  min = 1, max = 10, slider = true },
		{ id = "BrushMode",         name = "Mode",               editor = "text_picker", default = "Add", items = { "Add", "Max", "Min" }, horizontal = true, store_as = false, },
		{ id = "ClampMin", name = "Min <style GedHighlight>(Ctrl-click)</style>", editor = "number", scale = "m", default = 0 },
		{ id = "ClampMax", name = "Max <style GedHighlight>(Shift-click)</style>", editor = "number", scale = "m", default = 0 },
		{ id = "BrushPattern",      name = "Pattern",            editor = "texture_picker", default = "", thumb_size = 100, items = function(self) return self:GetZBrushTexturesList() end, small_font = true },
		
		{ id = "TerrainR", name = "Terrain red",   editor = "choice", default = "", items = GetTerrainNamesCombo, no_edit = function(self) return not self.pattern_terrains_file end, },
		{ id = "TerrainG", name = "Terrain green", editor = "choice", default = "", items = GetTerrainNamesCombo, no_edit = function(self) return not self.pattern_terrains_file end, },
		{ id = "TerrainB", name = "Terrain blue",  editor = "choice", default = "", items = GetTerrainNamesCombo, no_edit = function(self) return not self.pattern_terrains_file end, },
		
		{ id = "_", editor = "buttons", buttons = {{name = "See Texture Locations", func = "OpenTextureLocationHelp"}}, default = false },
	},
	
	ToolSection = "Height",
	ToolTitle = "Z Brush",
	Description = {
		"Select pattern and drag to place and size it.",
		"<style GedHighlight>hold Ctrl</style> - Move   <style GedHighlight>hold Shift</style> - Rotate  \n<style GedHighlight>hold Alt</style> - Height   <style GedHighlight>hold Space</style> - Distort"
	},
	ActionSortKey = "15",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Zbrush.tga", 
	ActionShortcut = "Ctrl-H",
	
	pattern_grid = false,
	pattern_raw = false,
	pattern_terrains_file = false,
	
	height_change = false,
	
	-- bools
	distorting = false,
	
	-- resizing
	z_resize_start = false,
	
	resize_start = false,
	last_resize_delta = false,
	
	-- angle of brush rotation in minutes
	last_rotation_delta = false,
	angle_start = false,
	angle = false, 
	
	distort_grid_x = false,
	distort_grid_y = false,
	distorting_start = false,
	
	distort_amp_xy = false,
	distort_distance = 0,
	
	initial_point_z = false,
	center_point = false,
	current_point = false,
	
	box_radius = 0,
	box_size = 0,
	old_box = false,
	
	cursor_start_pos = false, -- used with rotation (Shift)
	is_editing = false,
}

function XZBrush:Init()
	self:InitDistort()
	self:InitBrushPattern()
	XShortcutsTarget:SetStatusTextRight("ZBrush Editor")
end

function XZBrush:Done()
	self:CancelOperation()
	
	if self.pattern_grid   then self.pattern_grid:free()   end
	if self.distort_grid_x then self.distort_grid_x:free() end
	if self.distort_grid_y then self.distort_grid_y:free() end
	
	editor.ClearOriginalHeightGrid()
end

function XZBrush:InitBrushPattern()
	local brush_pattern = self:GetBrushPattern()
	local had_terrains = not not self.pattern_terrains_file
	if brush_pattern then
		local dir, name, ext = SplitPath(brush_pattern)
		XShortcutsTarget:SetStatusTextRight(name)
		
		if self.pattern_grid then
			self.pattern_grid:free()
		end
		self.pattern_raw = string.find(brush_pattern, ".raw") and true or false
		self.pattern_grid = ImageToGrids(brush_pattern, self.pattern_raw)
		self.pattern_terrains_file = dir .. name .. "_Mask.png"
		self.pattern_terrains_file = io.exists(self.pattern_terrains_file) and self.pattern_terrains_file
	end
	if had_terrains ~= not not self.pattern_terrains_file then
		ObjModified(self)
	end
end

function XZBrush:InitDistort()
	if self.distort_grid_x then self.distort_grid_x:free() end
	if self.distort_grid_y then self.distort_grid_y:free() end
	
	local dist_size = editor.ZBrushDistortSize
	self.distort_grid_x = NewComputeGrid(dist_size, dist_size, "F")
	self.distort_grid_y = NewComputeGrid(dist_size, dist_size, "F")
	
	local seed = AsyncRand()
	local noise = PerlinNoise:new()
	noise:SetMainOctave(1 + MulDivRound( editor.ZBrushParamsCount - 1, self:GetBrushDistortFreq()* 100 , 1024))
	
	noise:GetNoise(seed, self.distort_grid_x, self.distort_grid_y)
	GridNormalize(self.distort_grid_x, 0, 1)
	GridNormalize(self.distort_grid_y, 0, 1)
	
	self.distort_amp_xy = point(0, 0)
	self.distort_distance = 0
end

function XZBrush:OnEditorSetProperty(prop_id, old_value, ged)
	local brush_pattern = false
	if prop_id == "BrushPattern" then
		self:InitBrushPattern()
	elseif prop_id == "BrushDistortFreq" then 
		self:InitDistort()
	end
end

function XZBrush:ActionHeightChangeInvert()
	self:SetBrushHeightChange(-self:GetBrushHeightChange())
	self:OnEditorSetProperty("SetBrushHeightChange")
	ObjModified(self)
end

function XZBrush:CalculateResizeDelta()
	if not self.resize_start then 
		return self.last_resize_delta
	end 
	if self.last_resize_delta ~= point(0, 0, 0) then 
		local dCCP = self.current_point:Dist2D(self.center_point)
		local dCLP = self.resize_start:Dist2D(self.center_point)
		return MulDivRound(self.last_resize_delta, dCCP, dCLP)
	else
		return self.current_point - self.resize_start
	end
end

function XZBrush:UpdateParameters(screen_point)
	local isRotating = false
	local isScalingZ = false
	local isMoving = false
	if terminal.IsKeyPressed(const.vkAlt) then
		isScalingZ = true
		SetMouseDeltaMode(true)
		self.height_change = self.height_change - MulDivRound(GetMouseDelta():y(), self:GetBrushHeightChange(), 100)
	else
		SetMouseDeltaMode(false)
	end
	
	local isDistorting = false
	if terminal.IsKeyPressed(const.vkSpace) then 
		isDistorting = true
		if not self.distorting then
			self.distorting_start = screen_point
		end
		self.distort_distance = self.distorting_start:Dist2D(screen_point)
		self.distort_amp_xy = self:GetBrushDistortAmp() * (self.distorting_start - screen_point)
	end
	self.distorting = isDistorting
	
	local ptDelta = screen_point - self.cursor_start_pos
	if terminal.IsKeyPressed(const.vkShift) then
		local absDiff = Max(abs(ptDelta:x()), abs(ptDelta:y()))
		if absDiff > 0 then
			self.angle = atan(ptDelta:y(), ptDelta:x())
			if not self.angle_start then 
				self.angle_start = self.angle
			end
		end
		isRotating = true
	else
		if self.angle_start then
			self.last_rotation_delta = self.last_rotation_delta + (self.angle - self.angle_start)
			self.angle_start = false
		end
	end
	
	local mouse_world_pos = GetTerrainCursor()
	if terminal.IsKeyPressed(const.vkControl) then 
		self.center_point = self.center_point + mouse_world_pos - self.current_point
		isMoving = true
	end
	self.current_point = mouse_world_pos
	if not isScalingZ and not isDistorting and not isRotating and not isMoving then
		-- if not all that, then we do default action - resize
		if not self.resize_start then
			self.resize_start = self.current_point
		end
	else
		if self.resize_start then
			self.last_resize_delta = self:CalculateResizeDelta()
			self.resize_start = false
		end	
	end
end

function XZBrush:OnMouseButtonDown(screen_point, button)
	if button == "R" and self.is_editing then
		self:CancelOperation()
		return "break"
	end
	if button == "L" then
		if terminal.IsKeyPressed(const.vkControl) then
			self:SetClampMin(GetTerrainCursor():z())
			ObjModified(self)
			return "break"
		end
		if terminal.IsKeyPressed(const.vkShift) then
			self:SetClampMax(GetTerrainCursor():z())
			ObjModified(self)
			return "break"
		end
	
		XEditorUndo:BeginOp{ height = true, terrain_type = not not self.pattern_terrains_file, name = "Z Brush" }
		editor.StoreOriginalHeightGrid(true)
		
		self.is_editing = true
		self.cursor_start_pos = screen_point
		
		local game_pt = GetTerrainCursor()
		self.center_point = game_pt
		self.current_point = game_pt
		self.resize_start = game_pt
		self.last_resize_delta = point30
		self.initial_point_z = game_pt:z()
		
		local w, h = terrain.HeightMapSize()
		self.height_change = self:GetBrushHeightChange() / const.TerrainHeightScale
		self.last_rotation_delta = 0
		
		self.desktop:SetMouseCapture(self)
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, screen_point, button)
end

function XZBrush:OnMouseButtonUp(screen_point, button)
	if self.is_editing then
		self:UpdateParameters(screen_point)
		local bbox = editor.GetSegmentBoundingBox(self.center_point, self.center_point, self.box_radius, true)
		Msg("EditorHeightChanged", true, bbox)
		if self.pattern_terrains_file then
			self:ApplyTerrainTextures(self.pattern_terrains_file)
			Msg("EditorTerrainTypeChanged", bbox)
		end
		XEditorUndo:EndOp()
		
		self.is_editing = false
		self.center_point = false
		self.current_point = false
		self.scalingZ = false 
		self.distorting = false
		self.angle_start = false
		self.last_rotation_delta = 0
		self.distort_amp_xy = point(0, 0)
		self.distort_distance = 0
		
		local dir, name, ext = SplitPath(self:GetBrushPattern())
		XShortcutsTarget:SetStatusTextRight(name or "ZBrush Editor")
		
		SetMouseDeltaMode(false)
		self.desktop:SetMouseCapture()
		UnforceHideMouseCursor("XEditorBrushTool")
		return "break"
	end
	return XEditorTool.OnMouseButtonUp(self, screen_point, button)
end

function XZBrush:OnMousePos(screen_point, button)
	if self.is_editing and self.pattern_grid then
		if terminal.IsKeyPressed(const.vkEsc) then 
			self:CancelOperation()
			return "break"
		end 
		
		self:UpdateParameters(screen_point)	
		local angleDelta = self.last_rotation_delta + (self.angle_start and (self.angle - self.angle_start) or 0)
		local sin, cos = sincos(angleDelta)
		local ptDelta = self:CalculateResizeDelta()
		local box_size = Max(abs(ptDelta:x()), abs(ptDelta:y()))
		self.box_radius = box_size > 0 and MulDivRound(box_size, abs(sin) + abs(cos), 4096) or const.HeightTileSize / 2
		
		local bBox = editor.GetSegmentBoundingBox(self.center_point, self.center_point, self.box_radius, true)
		local extended_box = AddRects(self.old_box or bBox, bBox)
		local min, max = editor.ApplyZBrushToGrid(self.pattern_grid, self.distort_grid_x, self.distort_grid_y, extended_box, self.center_point:SetZ(self.initial_point_z),
			self.distort_amp_xy, self.distort_distance, angleDelta, box_size, self.height_change, self:GetBrushZeroLevel(), self.pattern_raw,
			self:GetBrushMode(), self:GetClampMin(), self:GetClampMax())
		if max and min then
			XShortcutsTarget:SetStatusTextRight(string.format("Size %d, Min height %dm, Max height %dm", (2 * box_size) / guim, min * const.TerrainHeightScale / guim, max * const.TerrainHeightScale / guim))
		end
		self.old_box = bBox
		self.box_size = box_size
		
		Msg("EditorHeightChanged", false, extended_box)
		return "break"
	end
	XEditorTool.OnMousePos(self, screen_point, button)
end

function XZBrush:OnKbdKeyDown(key, ...)
	if self.is_editing and key == const.vkEsc then
		self:CancelOperation()
		return "break"
	end
	XEditorTool.OnKbdKeyDown(self, key, ...)
end

function XZBrush:CancelOperation()
	if self.editing then
		local w, h = terrain.HeightMapSize()
		local mask = NewComputeGrid(w, h, "F")
		local box = editor.DrawMaskSegment(mask, self.center_point, self.center_point, self.box_radius, self.box_radius, "min")
		editor.SetHeightWithMask(0, mask, box)
		mask:clear()
		
		self:OnMouseButtonUp(self.center_point, 'L')
	end
end

function XZBrush:ApplyTerrainTextures(filename)
	local r, g, b = ImageToGrids(filename)
	local bbox = editor.GetSegmentBoundingBox(self.center_point, self.center_point, self.box_radius, true)
	local angle = self.last_rotation_delta + (self.angle_start and (self.angle - self.angle_start) or 0)
	-- places terrain based on the texture in filename (different terrain for R, G, B channels); pattern_grid, pattern_raw are ignored
	editor.ApplyZBrushToGrid(self.pattern_grid, self.distort_grid_x, self.distort_grid_y, bbox, self.center_point:SetZ(self.initial_point_z),
		self.distort_amp_xy, self.distort_distance, angle, self.box_size, self.height_change, self:GetBrushZeroLevel(), self.pattern_raw,
		self:GetBrushMode(), self:GetClampMin(), self:GetClampMax(),
		r, g, b, self:GetTerrainR(), self:GetTerrainG(), self:GetTerrainB())
end

function XZBrush:OpenTextureLocationHelp()
	local paths = { "Texture folders:" }
	for i = 1, #textures_folders do
		paths[#paths + 1] = ConvertToOSPath(textures_folders[i])
	end
	paths[#paths + 1] = "Thumb folders:"
	for i = 1, #thumbs_folders do
		paths[#paths + 1] = ConvertToOSPath(thumbs_folders[i])
	end
	CreateMessageBox(self, Untranslated("Texture Location"), Untranslated(table.concat(paths, "\n")))
end

function XZBrush:GetZBrushTexturesList()
	local texture_list = {}
	for i = 1, #textures_folders do
		local textures_folder = textures_folders[i] or ""
		local thumbs_folder = thumbs_folders[i] or ""
		local err, thumbs, textures
		if thumbs_folder ~= "" then
			err, thumbs = AsyncListFiles(thumbs_folder, "*.png")
		end
		if textures_folder ~= "" then
			err, textures = AsyncListFiles(textures_folder)
		end
		
		for _, texture in ipairs(textures or empty_table) do
			local dir, name, ext = SplitPath(texture)
			if supported_fmt[ext] then
				local thumb = thumbs_folder .. "/" .. name .. ".png"
				if not table.find(thumbs or empty_table, thumb) and thumb_fmt[ext] then
					thumb = texture
				end
				texture_list[#texture_list + 1] = { text = name, value = texture, image = thumb }
			end
		end
	end
	table.sort(texture_list, function(a, b) return a.text < b.text or a.text == b.text and a.value < b.value end )
	return texture_list
end