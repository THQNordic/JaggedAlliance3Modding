config.ParticlesMaxBaseColorMapSize = 2048
config.ParticlesMaxNormalMapSize = 512

local function folder_fn(obj)
	return obj:GetTextureFolders()
end

local function filter_fn_texture(obj)
	return obj:GetTextureFilter()
end

local function filter_fn_normalmap(obj)
	return obj:GetNormalmapFilter()
end

DefineClass.ParticleEmitter =
{
	__parents = { "ParticleBehavior" },
	PropEditorCopy = true,
	EditorName = "Emitter",
	
	properties = {
		-- Base
		{ id = "emit_detail_level", name = "Detail level category", category = "Base", default = ActionFXDetailLevelCombo()[1].value, editor = "combo", items = ActionFXDetailLevelCombo, help = "Determines the options detail levels at which the emitter is active. Essential will make it always active, Optional at high/medium setting, and EyeCandy at high setting only.", },
		-- Emission
		{ id = "enabled", name = "Enabled", category = "Emission Attributes", editor = "bool", dynamic = true, },
		{ id = "emit_fade", name = "Emit fading range (m)", category = "Emission Attributes", editor = "range", slider = true, min = 0, max = 15000, default = range( 0, 2000 ), help = "Camera distance interval in which particles will be emitted." },
		{ id = "max_live_count", name = "Max live count", category = "Emission Attributes", editor = "number", min = 1, dynamic = true, max = 5000 },
		{ id = "parts_per_sec", name = "Particles/sec", category = "Emission Attributes", editor = "number", scale = 100, dynamic = true, max = 12000000 },
		{ id = "parts_per_meter", name = "Particles/meter", category = "Emission Attributes", editor = "number", scale = 100, dynamic = true },
		{ id = "parts_per_meter_min_velocity", name = "Particles/meter treshold", category = "Emission Attributes", editor = "number", scale = 1000, default = 0, },
		{ id = "lifetime_min", name = "Lifetime min", category = "Emission Attributes", editor = "number", min = 0, scale = "sec", dynamic = true },
		{ id = "lifetime_max", name = "Lifetime max", category = "Emission Attributes", editor = "number", min = 0, scale = "sec", dynamic = true },
		{ id = "position", name = "Position", category = "Emission Attributes", editor = "point", scale = guim, dynamic = true },
		{ id = "angle", name = "Angle (degrees)", category = "Emission Attributes", editor = "range", slider = true, min = -360, max = 360 },
		{ id = "size_min", name = "Size min (m)", category = "Emission Attributes", editor = "number", min = 1, scale = 1000, dynamic = true },
		{ id = "size_max", name = "Size max (m)", category = "Emission Attributes", editor = "number", min = 1, scale = 1000, dynamic = true },
		{ id = "part_emit_modifier", name = "Emit Modifier", category = "Emission Attributes", editor = "number", min = 1, scale = 1000, dynamic = true },
		-- Material
		{ id = "geometry_building", name = "Geometry", category = "Material Attributes", editor = "combo", items = { "Particle", "Ribbon", "Decal" }, help = "What type of geometry is being emitted." },
		{ id = "decal_depth", name = "Decal Depth", category = "Material Attributes", editor = "number", scale = 1000, no_edit = function(self) return self.geometry_building ~= "Decal" end, dynamic = true },
		{ id = "decal_group", name = "Decal Group", category = "Material Attributes", editor = "choice", items = const.DecalGroups, no_edit = function(self) return self.geometry_building ~= "Decal" end, dynamic = true },
		{ id = "shader", name = "Shader", category = "Material Attributes", editor = "combo", items = { "Solid", "Blend", "Add", "Premultiplied", "Overlay", "Add Light", "Distortion", "Blend Exposed" } },
		{ id = "SourceTexture", name = "Texture", category = "Material Attributes", default = false, editor = "browse", folder = folder_fn, filter = filter_fn_texture, dont_save = true, },
		{ id = "texture", editor = "text", no_edit = true, },
		{ id = "TexturePreview", name = "Texture Preview", category = "Material Attributes", editor = "image", default = "", dont_save = true,
										img_size = 128, img_box = 1, img_comp = "rgba", img_back = RGB(0, 0, 0),
										img_polyline_color = RGB(128, 128, 128), img_polyline = function(self) return self.outlines end, img_polyline_closed = true },
		{ id = "filtering_bilinear", name = "Texture filtering: smooth", category = "Material Attributes", editor = "bool" },
		{ id = "normal_as_flow_map", name = "Normal map as Flow map", category = "Material Attributes", editor = "bool", default = false, no_edit = function(self) return self.shader == "Distortion" end, dynamic = true },
		{ id = "SourceNormalmap", name = "Normalmap", category = "Material Attributes", editor = "browse", folder = folder_fn, filter = filter_fn_normalmap, image_preview_size = 128, dont_save = true, default = false },
		{ id = "normalmap", editor = "text", no_edit = true, },
		{ id = "frames", name = "UV Frames", category = "Material Attributes", editor = "point2d", max = 8*8, help = "X * Y should be limited to 6x6" },
		{ id = "self_illum", name = "Self-Illumination", category = "Material Attributes", editor = "number", slider = true, min = 0, max = 200, no_edit = function(self) return self.shader == "Distortion" end, dynamic = true, help = "Shaded particles receive additional light based on the material color." },
		{ id = "light_softness", name = "NM Light Softness", category = "Material Attributes", editor = "number", slider = true, min = 0, max = 1000, no_edit = function(self) return self.shader == "Distortion" end, dynamic = true, help = "How soft should the light affecting this particle be" },
		{ id = "mat_roughness", name = "Material Roughness", category = "Material Attributes", editor = "number", min = 0, max = 100, slider = true, no_edit = function(self) return self.shader == "Distortion" end, dynamic = true, help = "Controls the roughness of the material surface. Value of 1 results in no specular reflection and an optimized shading path." },
		{ id = "mat_metallic", name = "Material Metallic", category = "Material Attributes", editor = "number", min = 0, max = 100, slider = true, no_edit = function(self) return self.shader == "Distortion" end, dynamic = true, help = "Controls the metallicness of the material surface." },
		{ id = "receive_shadow", name = "Receive Shadow", category = "Material Attributes", editor = "bool", default = false },
		-- Flow map
		{ id = "flow_speed", name = "Flow Speed", category = "Material Attributes", editor = "number", slider = true, min = 0, max = 1000, default = 0, help = "Speed of texture distortion", no_edit = function(self) return not self.normal_as_flow_map end, dynamic = true },
		{ id = "flow_scale", name = "Flow Scale", category = "Material Attributes", editor = "number", slider = true, min = 0, max = 1000, default = 0, help = "Scale of texture distortion", no_edit = function(self) return not self.normal_as_flow_map end, dynamic = true },
		-- Transparency
		{ id = "softness", name = "Softness (m)", no_edit = true, category = "Transparency Attributes", editor = "number", scale = 100, read_only = function(obj, prop_meta) return obj.ui end },	
		{ id = "far_softness", name = "Terrain Distance Fade (m)", category = "Transparency Attributes", editor = "number", scale = 100, min = -1, read_only = function(obj, prop_meta) return obj.ui end },	
		{ id = "near_softness", name = "Camera Distance Fade (m)", category = "Transparency Attributes", editor = "number", scale = 100, min = -1, read_only = function(obj, prop_meta) return obj.ui end },	
		{ id = "far_softness_curve", name = "Far Softness %", category = "Transparency Attributes", editor = "curve4", fixedx = true, scale = 1000, min = 0, max = 1000, default = MakeLine(0, 1000), },
		{ id = "near_softness_curve", name = "Near Softness %", category = "Transparency Attributes", editor = "curve4", fixedx = true, scale = 1000, min = 0, max = 1000, default = MakeLine(0, 1000), },
		{ id = "viewangle_softness_curve", name = "View Angle Softness %", category = "Transparency Attributes", editor = "curve4", fixedx = true, scale = 1000, min = 0, max = 1000, default = MakeLine(1000, 1000), },
		
		{ id = "view_dependent_opacity", name = "View dependent opacity", category = "Transparency Attributes", editor = "number", slider = true, min = 0, max = 1000, default = 0, help = "Lowers particle opacity when viewed perpendicular to normal." },
		{ id = "alpha_test", name = "Alpha test (0-255)", category = "Transparency Attributes", editor = "number", slider = true, min = 0, max = 255, help = "Cut texture pixels with lesser alpha" },
		{ id = "alpha", name = "Alpha (0-255)", category = "Transparency Attributes", editor = "range", slider = true, min = 0, max = 255 },
		{ id = "interior", category = "Transparency Attributes", editor = "bool", default = true, help = "Render if inside buildings" },
		{ id = "exterior", category = "Transparency Attributes", editor = "bool", default = true, help = "Render if outside buildings"},
		-- Distortion
		{ id = "normal_to_distortion", name = "Normal map as Distortion map", category = "Material Attributes", editor = "bool", no_edit = function(self) return self.shader ~= "Distortion" end, dynamic = true },
		{ id = "distortion_mode", name = "Distortion mode", category = "Material Attributes", editor = "combo", items = { "Fixed", "Ramp", "Ping-Pong" }, help = "How does distortion change overt time", no_edit = function(self) return self.shader ~= "Distortion" end, dynamic = true }, 
		{ id = "distortion_start", name = "Distortion start", category = "Material Attributes", editor = "number", scale = "sec", help = "When does the animated distortion effect start", no_edit = function(self) return self.shader ~= "Distortion" end, dynamic = true },
		{ id = "distortion_end", name = "Distortion end", category = "Material Attributes", editor = "number", scale = "sec", help = "When does the animated distortion effect end", no_edit = function(self) return self.shader ~= "Distortion" end, dynamic = true },
		{ id = "distortion_scale", name = "Distortion scale (min)", category = "Material Attributes", editor = "number", min = -1000, max = 1000, slider = true, help = "The strength of the distortion effect", no_edit = function(self) return self.shader ~= "Distortion" end, dynamic = true },
		{ id = "distortion_scale_max", name = "Distortion scale (max)", category = "Material Attributes", editor = "number", min = -1000, max = 1000, slider = true, help = "The strength of the distortion effect", no_edit = function(self) return self.shader ~= "Distortion" end, dynamic = true },
		-- Depth
		{ id = "no_depth_test", name = "No depth test", category = "Depth Settings", editor = "bool", default = false, read_only = function(obj, prop_meta) return obj.ui end },
		{ id = "drawing_order", name = "Drawing order", category = "Depth Settings", editor = "number" },
		{ id = "depth_offset", name = "Depth offset", category = "Depth Settings", editor = "number", min = -10000, max = 10000, scale = "m", slider = true, help = "Camera relative offset of particles along the view direction" },
		{ id = "sort", name = "Sort particles", category = "Depth Settings", editor = "bool", help = "Should we sort the particles front to back to the camera or not (Blend mode only)!" },
		-- no_edit
		{ id = "probability", no_edit = true },
		{ id = "outlines", default = false, editor = "prop_table", no_edit = true },
		{ id = "texture_hash", default = false, editor = "number", no_edit = true },
		{ id = "ui", default = false, editor = "bool", no_edit = false },
		{ id = "mat_ice", name = "Material Ice", category = "Material Attributes", editor = "number", min = 0, max = 100, slider = true, no_edit = true, help = "Controls how much the material is affected by the Ice special effect." },
	},
	
	bins = set( "A" ),
	geometry_building = "Particle",
	time_start = 0,
	time_stop = -1000,
	time_period = 0,
	randomize_period = 0,
	enabled = true,
	max_live_count = 200,
	parts_per_sec = 5000,
	parts_per_meter = 0,
	lifetime_min = 1000,
	lifetime_max = 3000,
	texture = "",
	normalmap = "",
	self_illum = 0,
	light_softness = 800,
	decal_depth = 1000,
	decal_group = "Default",
	part_emit_modifier = 1000,
	
	frames = point(1, 1),
	drawing_order = 0,
	softness = 0,
	far_softness = -1,
	near_softness = -1,
	alpha_test = 0,
	shader = "Blend",
	position = point30,
	size_min = 1000,
	size_max = 2000,
	alpha = range( 255, 255 ),
	angle = range( 0, 0 ),
	filtering_bilinear = true,
	sort = true,
	normal_to_distortion = false,
	distortion_mode = "Fixed",
	distortion_scale = 0,
	distortion_scale_max = 0,
	distortion_start = 0,
	distortion_end = 0,
	velocity_min = 0,
	velocity_max = 0,
	mat_roughness = 100,
	mat_metallic = 0,
	mat_ice = 100,
	depth_offset = 0,
}

function ParticleEmitter:GetTextureFolders()
	return GetParentTable(self):GetTextureFolders()
end

function ParticleEmitter:GetTextureFilter()
	 return "Texture (*.tga)|*.tga"
end

function ParticleEmitter:GetNormalmapFilter()
	return "Texture (*.norm.tga)|*.norm.tga"
end

function ParticleEmitter:Setframes(value)
	local x, y = value:xy()
	local max = table.find_value(self.properties, "id", "frames").max
	local frames = x * y
	if frames > max then
		x = max * x / frames
		y = max * y / frames
		assert(x * y <= max, "Frames not properly limit-scaled down")
	end
	self.frames = point(x, y)
end

function ParticleEmitter:GetColorForGed()
	return self.enabled and "32 128 32" or "169 18 23"
end

function ParticleEmitter:ShouldNormalizeTexturePath()
	return true
end

local function ConvertSlashes(path)
	--convert all '\' into '/'
	return string.gsub(path, "\\", "/")
end

local function EscapeMagicSymbols(path)
	--convert all gsub 'magic symbols' into escaped symbols
	return string.gsub(ConvertSlashes(path), "[%(%)%.%%%+%-%*%?%[%^%$]", "%%%1")
end

function ParticleEmitter:NormalizeTexturePath(texture_path)
	if not self:ShouldNormalizeTexturePath() then return texture_path end
	
	return texture_path
end

function ParticleEmitter:Settexture(texture)
	self.texture = self:NormalizeTexturePath(texture)
end

function ParticleEmitter:Setnormalmap(texture)
	self.normalmap = self:NormalizeTexturePath(texture)
end

function ParticleEmitter:GetAlphaPreview()
	return self.texture
end

function ParticleEmitter:GetTexturePreview()
	return self.texture
end

local function GetSegments(path)
	path = path:gsub("[\\/]+", '/')
	local segments = {}
	for segment in string.gmatch(path, '[^/]+') do
		table.insert(segments, segment)
	end
	return segments
end

local function GetRelativePath(path, base, game_path)
	if not path then return path end
	path = GetSegments(path)
	base = GetSegments(base)
	game_path = GetSegments(game_path)

	for key, value in ipairs(base) do
		if value ~= path[key] then
			return false
		end
	end

	local moved = table.move(path, #base + 1, #path, #game_path + 1, game_path)
	return table.concat(moved, '/')
end

function ParticleEmitter:GetTextureBasePath()
	return GetParentTable(self):GetTextureBasePath()
end

function ParticleEmitter:GetTextureTargetPath()
	return GetParentTable(self):GetTextureTargetPath()
end

function ParticleEmitter:GetTextureTargetGamePath()
	return GetParentTable(self):GetTextureTargetGamePath()
end

function ParticleEmitter:GetSourceTexture()
	if self.texture == "" or not self.texture then
		return ""
	end
	return self:GetTextureBasePath() .. self.texture
end

function ParticleEmitter:SetSourceTexture(value)
	self.texture = GetRelativePath(value, self:GetTextureBasePath() .. self:GetTextureTargetPath(), self:GetTextureTargetGamePath()) or ""
end

function ParticleEmitter:GetSourceNormalmap()
	if self.normalmap == "" or not self.normalmap then
		return ""
	end
	return self:GetTextureBasePath() .. self.normalmap
end

function ParticleEmitter:SetSourceNormalmap(value)
	self.normalmap = GetRelativePath(value, self:GetTextureBasePath() .. self:GetTextureTargetPath(), self:GetTextureTargetGamePath()) or ""
end


function ParticleEmitter:ScheduleGenerateOutlines()
	self.outlines = false
	CreateRealTimeThread(self.GenerateOutlines, self)
end

function ParticleEmitter:Setui(ui)
	self.ui = ui
	if ui then
		self.no_depth_test = true
		self.softness = 0
	end
end

local outlines_cache = false
local texture_to_hash = false
function ClearOutlinesCache()
	outlines_cache = false
	texture_to_hash = false
end

function ParticleEmitter:GenerateOutlines(update_mode)
	if self.outlines and not update_mode then
		return
	end
	local texture = self.texture
	texture_to_hash = texture_to_hash or {}
	local texture_hash = texture_to_hash[texture]
	if texture_hash == nil then
		local err
		if texture ~= "" then
			err, texture_hash = AsyncFileToString(self:GetSourceTexture(), nil, nil, "hash")
			if err then
				print("Error", err, "while computing hash of", texture)
			end
		end
		texture_hash = texture_hash or false
		texture_to_hash[texture] = texture_hash
	end
	if update_mode == "update" and texture_hash == self.texture_hash then
		return
	end
	local outlines, generated
	if self.normal_to_distortion then
		outlines = {}
	else
		local param_hash = xxhash(texture, self.alpha_test, self.frames)
		outlines_cache = outlines_cache or {}
		outlines = outlines_cache[param_hash]
		if not outlines then
			generated = true
			local err
			err, outlines = TrimParticleTexture( texture, self.alpha_test, self.frames:x(), self.frames:y() )
			outlines = outlines or {}
			if err then
				print("Outlines:", err)
			end
			outlines_cache[param_hash] = outlines
			local count = 0
			for i=1,#outlines do
				count = count + #outlines[i]
			end
			if count > 256 then
				print("Too many outlines", count, "in", texture)
			end
		end
	end
	self.texture_hash = texture_hash
	self.outlines = outlines
	ObjModified(self)
	return true, generated
end

function ParticleEmitter:IsOutlineProp(prop_id)
	local outline_props = {
		normal_to_distortion = true,
		texture = true,
		SourceTexture = true,
		frames = true,
		alpha_test = true,
	}
	return outline_props[prop_id]
end


function ParticleEmitter:OnEditorSetProperty(prop_id, old_value, ged)
	local value = self:GetProperty(prop_id)
	if prop_id == "texture" then
		local w, h = UIL.MeasureImage(value)
		if (Max(w, h) > config.ParticlesMaxBaseColorMapSize) then
			ged:ShowMessage("Warning", "Diffuse texture is over the size limit " .. config.ParticlesMaxBaseColorMapSize .. "px. Please resize!")
		end
	elseif prop_id == "normalmap" then
		local w, h = UIL.MeasureImage(value)
		if (Max(w, h) > config.ParticlesMaxNormalMapSize) then
			ged:ShowMessage("Warning", "Normalmap texture is over the size limit " .. config.ParticlesMaxNormalMapSize .. "px. Please resize!")
		end
	elseif prop_id == "emit_detail_level" then
		if type(value) == "string" and tonumber(value) then
			self.emit_detail_level = tonumber(value)
		end
	end
	
	if self:IsOutlineProp(prop_id) then
		self:ScheduleGenerateOutlines()
	end
end

function ParticleEmitter:GetError()
	if self.emit_detail_level == ActionFXDetailLevelCombo()[1].value then
		return "Please set the 'Detail level category' property to specify at which detail levels this emitter should be active."
	end
end

function ParticleEmitter:OnEditorNew(preset, ged, is_paste)
	self:Setui(preset.ui)
	preset:OverrideEmitterFuncs(self)
end

function SaveParticleSystem(parsys)
	parsys:EnableDynamicToggles()
	parsys:Save()
end

function ReloadParticleTexture(filename)
	local parsyslist = GetParticleSystemList()
	for i=1,#parsyslist do
		local parsys = parsyslist[i]
		for j=1,#parsys do
			local behavior = parsys[j]
			if behavior:IsKindOf("ParticleEmitter") and behavior.texture == filename then
				DelayedCall( 500, SaveParticleSystem, parsys )
			end
		end
	end
end

DefineClass.Rename =
{
	__parents = { "ParticleBehavior" },
	
	properties =
	{
		{ id = "life_time", name = "Lifetime (sec)", editor = "number", min = 100, scale = 1000, dynamic = true },
		{ id = "remove_bins", name = "Remove Bins", editor = "set", items = { "A", "B", "C", "D", "E", "F", "G", "H" } },
		{ id = "add_bins", name = "Add Bins", editor = "set", items = { "A", "B", "C", "D", "E", "F", "G", "H" } },
		{ id = "reset_new_flag", name = "Reset New Flag", editor = "number" },
	},
	
	EditorName = "Rename",
	
	life_time = 1000,
	remove_bins = set(),
	add_bins = set(),
	reset_new_flag = 0,
}

if Platform.developer then

function FindParticleMaxProperty(part_class, prop)
	local particles = GetParticleSystemList()
	local max
	for i = 1, #particles do
		local par_sys = particles[i]
		for k = 1, #par_sys do
			local par_beh = par_sys[k]
			if par_beh:IsKindOf(part_class) then
				--local dynamic = table.find_value(g_Classes[part_class].properties, "id", prop).dynamic
				--local value = dynamic and par_beh:GetParam(prop) or par_beh:GetProperty(prop)
				local value = par_beh:GetProperty(prop)
				value = type(value) == "number" and value or 0
				if not max or value > max then
					max = value
				end
			end
		end
	end
	
	return max
end

function DumpPartStats()
	print("Max ParticleEmitter stats:")
	print("Frames: ", FindParticleMaxProperty("ParticleEmitter", "frames"))
	print("Max Live Count: ", FindParticleMaxProperty("ParticleEmitter", "max_live_count"))
	print("Particles/Sec: ", FindParticleMaxProperty("ParticleEmitter", "parts_per_sec"))
end

end