local AppendVertex = pstr().AppendVertex
local GetHeight = terrain.GetHeight
local height_tile = const.HeightTileSize
local InvalidZ = const.InvalidZ
local KeepRefOneFrame = KeepRefOneFrame

local SetCustomData
local GetCustomData
function OnMsg.Autorun()
	SetCustomData = ComponentCustomData.SetCustomData
	GetCustomData = ComponentCustomData.GetCustomData
end

DefineClass.CodeRenderableObject = 
{
	__parents = { "Object", "ComponentAttach", "ComponentCustomData" },
	entity = "",
	flags = { 
		gofAlwaysRenderable = true, cfCodeRenderable = true, cofComponentInterpolation = true, cfConstructible = false,
		efWalkable = false, efCollision = false, efApplyToGrids = false, efSelectable = false, efShadow = false, efSunShadow = false
	},
	depth_test = false,
	zwrite = true,
}

DefineClass.Text =
{
	--[[
		Custom data layout:
		const.CRTextCCDIndexColorMain    - base color, RGBA
		const.CRTextCCDIndexColorShadow  - shadow color, RGBA
		const.CRTextCCDIndexFlags        - flags: 0: depth test, 1, center
		const.CRTextCCDIndexText         - text, as string - you must keep this string from being GCed while the Text object is alive
		const.CRTextCCDIndexFont         - font_id, integer as returned by UIL.GetFontID
		const.CRTextCCDIndexShadowOffset - shadow offset
		const.CRTextCCDIndexOpacity      - opacity interpolation parameters
		const.CRTextCCDIndexScale        - scale interpolation parameters
		const.CRTextCCDIndexZOffset      - z offset interpolation parameters
	]]
	__parents = { "CodeRenderableObject" },
	text = false,
	text_style = false,
	hide_in_editor = true, -- hide using the T button in the editor statusbar (or Alt-Shift-T shortcut)
}

local TextFlag_DepthTest = 1
local TextFlag_Center = 2

function Text:SetColor1(c) SetCustomData(self, const.CRTextCCDIndexColorMain, c) end
function Text:SetColor2(c) SetCustomData(self, const.CRTextCCDIndexColorShadow, c) end
function Text:GetColor1(c) return GetCustomData(self, const.CRTextCCDIndexColorMain) end
function Text:GetColor2(c) return GetCustomData(self, const.CRTextCCDIndexColorShadow) end

function Text:SetColor(c)
	self:SetColor1(c)
	self:SetColor2(RGB(0,0,0))
end

function Text:GetColor(c)
	return self:GetColor1()
end

function Text:SetDepthTest(depth_test) 
	local flags = GetCustomData(self, const.CRTextCCDIndexFlags)
	if depth_test then
		SetCustomData(self, const.CRTextCCDIndexFlags, FlagSet(flags, TextFlag_DepthTest))
	else
		SetCustomData(self, const.CRTextCCDIndexFlags, FlagClear(flags, TextFlag_DepthTest))
	end
end
function Text:GetDepthTest()   
	return IsFlagSet(GetCustomData(self, const.CRTextCCDIndexFlags), TextFlag_DepthTest)
end

function Text:SetCenter(c) 
	local flags = GetCustomData(self, const.CRTextCCDIndexFlags)
	if c then
		SetCustomData(self, const.CRTextCCDIndexFlags, FlagSet(flags, TextFlag_Center)) 
	else
		SetCustomData(self, const.CRTextCCDIndexFlags, FlagClear(flags, TextFlag_Center)) 
	end
end
function Text:GetCenter()   
	return IsFlagSet(GetCustomData(self, const.CRTextCCDIndexFlags), TextFlag_Center)
end

function Text:SetText(txt) 
	KeepRefOneFrame(self.text)
	self.text = txt  
	SetCustomData(self, const.CRTextCCDIndexText, self.text) 
end
function Text:GetText()
	return self.text
end

function Text:SetFontId(id)       SetCustomData(self, const.CRTextCCDIndexFont, id)    end
function Text:GetFontId()         return GetCustomData(self, const.CRTextCCDIndexFont) end
function Text:SetShadowOffset(so) SetCustomData(self, const.CRTextCCDIndexShadowOffset, so)    end
function Text:GetShadowOffset()   return GetCustomData(self, const.CRTextCCDIndexShadowOffset) end

function Text:SetTextStyle(style, scale)
	local style = TextStyles[style]
	if not style then
		assert(false, string.format("Invalid text style '%s'", style))
		return
	end
	scale = scale or terminal.desktop.scale:y()
	local font, height, base_height = style:GetFontIdHeightBaseline(scale)
	self:SetFontId(font, height, base_height)
	self:SetColor(style.TextColor)
	self:SetShadowOffset(style.ShadowSize)
	self.text_style = style
end

function Text:SetOpacityInterpolation(v0, t0, v1, t1)
	-- opacities are 0..100, 7 bits
	-- times are encoded as ms/10, 8 bits each
	v0 = v0 or 100
	v1 = v1 or v0
	t0 = t0 or 0
	t1 = t1 or 0
	SetCustomData(self, const.CRTextCCDIndexOpacity, EncodeBits(v0, 7, v1, 7, t0/10, 8, t1/10, 8))
end

function Text:SetScaleInterpolation(v0, t0, v1, t1)
	-- scales are encoded 0..127, scale in percent/4 - so range 0..500%
	-- times are encoded as ms/10, 8 bits each
	v0 = v0 or 100
	v1 = v1 or v0
	t0 = t0 or 0
	t1 = t1 or 0
	SetCustomData(self, const.CRTextCCDIndexScale, EncodeBits(v0/4, 7, v1/4, 7, t0/10, 8, t1/10, 8))
end

function Text:SetZOffsetInterpolation(v0, t0, v1, t1)
	-- Z offsets are encoded 0..127, in guim/50 - so range 0..6.35 m
	-- times are encoded as ms/10, 8 bits each
	v0 = v0 or 0
	v1 = v1 or v0
	t0 = t0 or 0
	t1 = t1 or 0
	SetCustomData(self, const.CRTextCCDIndexZOffset, EncodeBits(v0/50, 7, v1/50, 7, t0/10, 8, t1/10, 8))
end

function Text:Init()	
	self:SetTextStyle(self.text_style or "EditorText")
end

function Text:Done()
	KeepRefOneFrame(self.text)
	self.text = nil
end

function Text:SetCustomData(idx, data)
    assert(idx ~= const.CRTextCCDIndexText, "Use SetText instead")
    return SetCustomData(self, idx, data)
end

DefineClass.TextEditor = {
	__parents = {"Text", "EditorVisibleObject"},
}

function PlaceText(text, pos, color, editor_visibile_only)
	local obj = PlaceObject(editor_visibile_only and "TextEditor" or "Text")
	if pos then
		obj:SetPos(pos)
	end
	obj:SetText(text)
	if color then
		obj:SetColor(color)
	end
	return obj
end

function RemoveAllTexts()
	MapDelete("map", "Text")
end

local function GetMeshFlags()
	local flags = {}
	for name, value in pairs(const) do
		if string.starts_with(name, "mf") then
			flags[value] = name
		end
	end
	return flags
end

DefineClass.MeshParamSet = {
	__parents = { "PropertyObject" },
	properties = {
		
	},
	uniforms = false,
	uniforms_size = 0,
}

local uniform_sizes = {
	integer = 4,
	float = 4,
	color = 4,
	point2 = 8,
	point3 = 12,
}

function GetUniformMeta(properties)
	local uniforms = {}
	local offset = 0
	for _, prop in ipairs(properties) do
		local uniform_type = prop.uniform
		if uniform_type then
			if type(uniform_type) ~= "string" then
				if prop.editor == "number" then
					uniform_type = prop.scale and prop.scale ~= 1 and "float" or "integer"
				elseif prop.editor == "point" then
					uniform_type = "point3"
				else
					uniform_type = prop.editor
				end
			end
			local size = uniform_sizes[uniform_type]
			if not size then
				assert(false, "Unknown uniform type.")
			end
			local space = 16 - (offset % 16)
			if space < size then
				table.insert(uniforms, {id = false, type = "padding", offset = offset, size = space})
				offset = offset + space
			end
			table.insert(uniforms, {id = prop.id, type = uniform_type, offset = offset, size = size, scale = prop.scale})
			offset = offset + size
		end
	end
	return uniforms, offset
end

function OnMsg.ClassesPostprocess()
	ClassDescendantsList("MeshParamSet", function(name, def)
		def.uniforms, def.uniforms_size = GetUniformMeta(def:GetProperties())
	end)
end

function MeshParamSet:WriteBuffer(param_pstr, offset, getter)
	if not offset then
		offset = 0
	end
	if not getter then 
		getter = self.GetProperty
	end
	param_pstr = param_pstr or pstr("", self.uniforms_size)
	param_pstr:resize(offset)
	for _, prop in ipairs(self.uniforms) do
		local value
		if prop.type == "padding" then
			value = prop.size
		else
			value = getter(self, prop.id)
		end
		
		param_pstr:AppendUniform(prop.type, value, prop.scale)
	end
	return param_pstr
end

function MeshParamSet:ComposeBuffer(param_pstr, getter)
	return self:WriteBuffer(param_pstr, 0, getter)
end

DefineClass.Mesh = {
	__parents = { "CodeRenderableObject" },
	
	properties = {
		{ id = "vertices_len", read_only = true, dont_save = true, editor = "number", default = 0,},
		{ id = "CRMaterial", editor = "nested_obj", base_class = "CRMaterial", default = false, },
		{ id = "MeshFlags", editor = "flags", default = 0, items = GetMeshFlags },
		{ id = "DepthTest", editor = "bool", default = false, read_only = function(s) return not s.shader or s.shader.depth_test ~= "runtime" end, },
		{ id = "ShaderName", editor = "choice", default = "default_mesh", items = function() return table.keys2(ProceduralMeshShaders, "sorted") end},
	},
	--[[
		Custom data layout:
		const.CRMeshCCDIndexGeometry  - vertices, packed in a pstr
		const.CRMeshCCDIndexPipeline  - shader; depth_test >> 31, 0 for off, 1 for on
		const.CRMeshCCDIndexMeshFlags - mesh flags
		const.CRMeshCCDIndexUniforms  - uniforms, packed in a pstr
		const.CRMeshCCDIndexTexture0, const.CRMeshCCDIndexTexture1 - textures
	]]

	vertices_pstr = false,
	uniforms_pstr = false,
	shader = false,
	textstyle_id = false,
}

function Mesh:GedTreeViewFormat()
	return string.format("%s (%s)", self.class, self.CRMaterial and self.CRMaterial.id or self:GetShaderName())
end

function Mesh:Getvertices_len()
	return self.vertices_pstr and #self.vertices_pstr or 0
end

function Mesh:GetShaderName()
	return self.shader and self.shader.name or ""
end

function Mesh:SetShaderName(value)
	self:SetShader(ProceduralMeshShaders[value])
end

function Mesh:Init()
	self:SetShader(ProceduralMeshShaders.default_mesh)
end

function Mesh:SetMesh(vpstr)
	KeepRefOneFrame(self.vertices_pstr)
	local vertices_pstr = #(vpstr or "") > 0 and vpstr or nil -- an empty string would result in a crash :|
	self.vertices_pstr = vertices_pstr
	SetCustomData(self, const.CRMeshCCDIndexGeometry, vertices_pstr)
end

function Mesh:SetUniformSet(uniform_set)
	self:SetUniformsPstr(uniform_set:ComposeBuffer())
end

function Mesh:SetUniformsPstr(uniforms_pstr)
	KeepRefOneFrame(self.uniforms_pstr)
	self.uniforms_pstr = uniforms_pstr
	SetCustomData(self, const.CRMeshCCDIndexUniforms, uniforms_pstr)
end

function Mesh:SetUniformsList(uniforms, isDouble)
	KeepRefOneFrame(self.uniforms_pstr)
	local count = Max(8, #uniforms)
	local uniforms_pstr = pstr("", count * 4)
	self.uniforms_pstr = uniforms_pstr
	for i = 1, count do
		if isDouble then
			uniforms_pstr:AppendUniform("double", uniforms[i] or 0)
		else
			uniforms_pstr:AppendUniform("float", uniforms[i] or 0, 1000)
		end
	end
	SetCustomData(self, const.CRMeshCCDIndexUniforms, uniforms_pstr)
end

function Mesh:SetUniforms(...)
	return self:SetUniformsList{...}
end

function Mesh:SetDoubleUniforms(...)
	return self:SetUniformsList({...}, true)
end

function Mesh:SetShader(shader, depth_test)
	assert(shader.shaderid)
	assert(shader.defines)
	assert(shader.ref_id > 0)
	if depth_test == nil then
		if shader.depth_test == "always" then
			depth_test = true
		elseif shader.depth_test == "never" then
			depth_test = false
		else
			depth_test = self:GetDepthTest()
		end
	end
	local depth_test_int = 0
	if depth_test then
		depth_test_int = 1
		assert(shader.depth_test == "runtime" or shader.depth_test == "always", "Tried to enable depth test for shader with depth_test = never")
	else
		depth_test_int = 0
		assert(shader.depth_test == "runtime" or shader.depth_test == "never", "Tried to disable depth test for shader with depth_test = always")
	end
	SetCustomData(self, const.CRMeshCCDIndexPipeline, shader.ref_id | (depth_test_int << 31))
	self.shader = shader
end

function Mesh:SetDepthTest(depth_test)
	assert(self.shader)
	self:SetShader(self.shader, depth_test)
end

function Mesh:SetCRMaterial(material)
	if type(material) == "string" then
		local new_material = CRMaterial:GetById(material, true)
		assert(new_material, "CRMaterial not found.")
		material = new_material
	end
	self.CRMaterial = material
	local depth_test = material.depth_test
	if depth_test == "default" then depth_test = nil end

	CodeRenderableLockCCD(self)
	self:SetShader(material:GetShader(), depth_test)
	self:SetUniformsPstr(material:GetDataPstr())
	CodeRenderableUnlockCCD(self)
end

function Mesh:GetCRMaterial()
	return self.CRMaterial
end

if FirstLoad then
	MeshTextureRefCount = {}
end

local function ModifyMeshTextureRefCount(id, change)
	if id == 0 then return end
	local old = MeshTextureRefCount[id] or 0
	local new = old + change
	if new == 0 then
		MeshTextureRefCount[id] = nil
		ProceduralMeshReleaseResource(id)
	else
		MeshTextureRefCount[id] = new
	end
end

function Mesh:SetTexture(idx, resource_id)
	assert(idx >= 0 and idx <= 1)
	if self:GetTexture(idx) == resource_id then return end
	ModifyMeshTextureRefCount(self:GetTexture(idx), -1)
	SetCustomData(self, const.CRMeshCCDIndexTexture0 + idx, resource_id or 0)
	ModifyMeshTextureRefCount(resource_id, 1) 
end

function Mesh:GetTexture(idx)
	assert(idx >= 0 and idx <= 1)
	return GetCustomData(self, const.CRMeshCCDIndexTexture0 + idx) or 0
end

function Mesh:Done()
	KeepRefOneFrame(self.vertices_pstr)
	KeepRefOneFrame(self.uniforms_pstr)
	self.vertices_pstr = nil
	self.uniforms_pstr = nil
	self:SetTexture(0, 0)
	self:SetTexture(1, 0)
end

function OnMsg.DoneMap()
	for key, value in pairs(MeshTextureRefCount) do
		ProceduralMeshReleaseResource(key)
	end
	MeshTextureRefCount = {}
end

function Mesh:SetCustomData(idx, data)
	assert(idx > const.CRMeshCCDIndexGeometry, "Use SetMesh instead!")
	return SetCustomData(self, idx, data)
end
function Mesh:GetDepthTest() return (GetCustomData(self, const.CRMeshCCDIndexPipeline) >> 31) == 1 end
function Mesh:SetMeshFlags(flags) SetCustomData(self, const.CRMeshCCDIndexMeshFlags, flags) end
function Mesh:GetMeshFlags() return GetCustomData(self, const.CRMeshCCDIndexMeshFlags) end
function Mesh:AddMeshFlags(flags) self:SetMeshFlags(flags | self:GetMeshFlags()) end
function Mesh:ClearMeshFlags(flags) self:SetMeshFlags(~flags & self:GetMeshFlags()) end

function Mesh.ColorFromTextStyle(id)
	assert(TextStyles[id])
	return TextStyles[id].TextColor
end

function AppendCircleVertices(vpstr, center, radius, color, strip)
	local HSeg = 32
	vpstr = vpstr or pstr("", 1024)
	color = color or RGB(254, 127, 156)
	center = center or point30
	local x0, y0, z0
	for i = 0, HSeg do
		local x, y, z = RotateRadius(radius, MulDivRound(360 * 60, i, HSeg), center, true)
		AppendVertex(vpstr, x, y, z, color)
		if not strip then
			if i ~= 0 then
				AppendVertex(vpstr, x, y, z, color)
				if i == HSeg then
					AppendVertex(vpstr, x0, y0, z0)
				end
			else
				x0, y0, z0 = x, y, z
			end
		end
	end

	return vpstr
end

function AppendTileVertices(vstr, x, y, z, tile_size, color, offset_z, get_height)
	offset_z = offset_z or 0
	z = z or InvalidZ
	local d = tile_size / 2
	local x1, y1, z1 = x - d, y - d
	local x2, y2, z2 = x + d, y - d
	local x3, y3, z3 = x - d, y + d
	local x4, y4, z4 = x + d, y + d
	get_height = get_height or GetHeight
	if z ~= InvalidZ and z ~= get_height(x, y) then
		z = z + offset_z
		z1, z2, z3, z4 = z, z, z, z
	else
		z1 = get_height(x1, y1) + offset_z
		z2 = get_height(x2, y2) + offset_z
		z3 = get_height(x3, y3) + offset_z
		z4 = get_height(x4, y4) + offset_z
	end
	AppendVertex(vstr, x1, y1, z1, color)
	AppendVertex(vstr, x2, y2, z2, color)
	AppendVertex(vstr, x3, y3, z3, color)
	AppendVertex(vstr, x4, y4, z4, color)
	AppendVertex(vstr, x2, y2, z2, color)
	AppendVertex(vstr, x3, y3, z3, color)
end

function GetSizePstrTile()
	return 6 * const.pstrVertexSize
end

function AppendTorusVertices(vpstr, radius1, radius2, axis, color, normal)
	local HSeg = 32
	local VSeg = 10
	vpstr = vpstr or pstr("", 1024)
	local rad1 = Rotate(axis, 90 * 60)
	rad1 = Cross(axis, rad1)
	rad1 = Normalize(rad1)
	rad1 = MulDivRound(rad1, radius1, 4096)
	for i = 1, HSeg do
		local localCenter1 = RotateAxis(rad1, axis, MulDivRound(360 * 60, i, HSeg))
		local localCenter2 = RotateAxis(rad1, axis, MulDivRound(360 * 60, i - 1, HSeg))
		local lastUpperPt, lastPt
		if not normal or not IsPointInFrontOfPlane(point(0, 0, 0), normal, (localCenter1 + localCenter2) / 2) then
			for j = 0, VSeg do
				local rad2 = MulDivRound(localCenter1, radius2, radius1)
				local localAxis = Cross(rad2, axis)
				local pt = RotateAxis(rad2, localAxis, MulDivRound(360 * 60, j, VSeg))
				pt = localCenter1 + pt
				rad2 = MulDivRound(localCenter2, radius2, radius1)
				localAxis = Cross(rad2, axis)
				local upperPt = RotateAxis(rad2, localAxis, MulDivRound(360 * 60, j, VSeg))
				upperPt = localCenter2 + upperPt
				if j ~= 0 then
					AppendVertex(vpstr, pt, color)
					AppendVertex(vpstr, lastPt)
					AppendVertex(vpstr, upperPt)
					AppendVertex(vpstr, upperPt, color)
					AppendVertex(vpstr, lastUpperPt)
					AppendVertex(vpstr, lastPt)
				end
				lastPt = pt
				lastUpperPt = upperPt
			end
		end
	end
	
	return vpstr
end

function AppendConeVertices(vpstr, center, displacement, radius1, radius2, axis, angle, color, offset)
	local HSeg = 10
	vpstr = vpstr or pstr("", 1024)
	center = center or point(0, 0, 0)
	displacement = displacement or point(0, 0, 30 * guim)
	axis = axis or axis_z
	angle = angle or 0
	offset = offset or point(0, 0, 0)
	color = color or RGB(254, 127, 156)
	local lastPt, lastUpperPt
	for i = 0, HSeg do
		local rad = point(radius1, 0, 0)
		local pt = center + Rotate(rad, MulDivRound(360 * 60, i, HSeg))
		local upperRad = point(radius2, 0, 0)
		local upperPt = center + displacement + Rotate(upperRad, MulDivRound(360 * 60, i, HSeg))
		pt = RotateAxis(pt, axis, angle * 60) + offset
		upperPt = RotateAxis(upperPt, axis, angle * 60) + offset
		if i ~= 0 then
			AppendVertex(vpstr, pt, color)
			AppendVertex(vpstr, lastPt)
			AppendVertex(vpstr, upperPt)
			if radius2 ~= 0 then
				AppendVertex(vpstr, upperPt, color)
				AppendVertex(vpstr, lastUpperPt)
				AppendVertex(vpstr, lastPt)
			end
		end
		lastPt = pt
		lastUpperPt = upperPt
	end
	
	return vpstr
end

DefineClass.Polyline =
{
	__parents = { "Mesh" },
}

function Polyline:Init()
	self:SetMeshFlags(const.mfWorldSpace)
	self:SetShader(ProceduralMeshShaders.default_polyline)
end

DefineClass.Vector = {
	__parents = {"Polyline"},
}

function Vector:Set (a, b, col)
	col = col or RGB(255, 255, 255)
	a = ValidateZ(a)
	b = ValidateZ(b)
	self:SetPos(a)
	
	local vpstr = pstr("", 1024)
	
	AppendVertex(vpstr, a, col)
	AppendVertex(vpstr, b)

	local ab = b - a
	local cb = (ab * 5) / 100
	local f = cb:Len() / 4
	local c = b - cb

	local n = 4
	local ps = GetRadialPoints (n, c, cb, f)
	for i = 1 , n/2 do
		AppendVertex(vpstr, ps[i])
		AppendVertex(vpstr, ps[i + n/2])
		AppendVertex(vpstr, b)
	end
	self:SetMesh(vpstr)
end

function Vector:GetA()
	return self:GetPos() 
end

function ShowVector(vector, origin, color, time)
	local v = PlaceObject("Vector")
	origin = origin:z() and origin or point(origin:x(), origin:y(), GetWalkableZ(origin))
	vector = vector:z() and vector or point(vector:x(), vector:y(), 0)
	v:Set(origin, origin + vector, color)
	if time then
		CreateGameTimeThread(function()
			Sleep(time)
			DoneObject(v)
		end)
	end
	
	return v
end

DefineClass.Segment = {
	__parents = {"Polyline"},
}

function Segment:Init()
	self:SetDepthTest(false)
end

function Segment:Set (a, b, col)
	col = col or RGB(255, 255, 255)
	a = ValidateZ(a)
	b = ValidateZ(b)
	self:SetPos(a)
	local vpstr = pstr("", 1024)
	AppendVertex(vpstr, a, col)
	AppendVertex(vpstr, b)
	self:SetMesh(vpstr)
end

-- After loading the code renderables from C, fix their string custom data in the Lua
function OnMsg.PersistLoad(_dummy_)
	MapForEach(true, "Text", function(obj)
		SetCustomData(obj, const.CRTextCCDIndexText, obj.text or 0)
	end)
	MapForEach(true, "Mesh", function(obj)
		CodeRenderableLockCCD(obj)
		SetCustomData(obj, const.CRMeshCCDIndexGeometry, obj.vertices_pstr or 0)
		SetCustomData(obj, const.CRMeshCCDIndexUniforms, obj.uniforms_pstr or 0)
		CodeRenderableUnlockCCD(obj)
	end)
end

----

function PlaceTerrainCircle(center, radius, color, step, offset, max_steps)
	step = step or guim
	offset = offset or guim
	local steps = Min(Max(12, (44 * radius) / (7 * step)), max_steps or 360)
	local last_pt
	local mapw, maph = terrain.GetMapSize()
	local vpstr = pstr("", 1024)
	for i = 0,steps do
		local x, y = RotateRadius(radius, MulDivRound(360*60, i, steps), center, true)
		x = Clamp(x, 0, mapw - height_tile)
		y = Clamp(y, 0, maph - height_tile)
		AppendVertex(vpstr, x, y, offset, color)
	end

	local line = PlaceObject("Polyline")
	line:SetMesh(vpstr)
	line:SetPos(center)
	line:AddMeshFlags(const.mfTerrainDistorted)
	return line
end

local function GetTerrainPointsPStr(vpstr, pt1, pt2, step, offset, color)
	step = step or guim
	offset = offset or guim
	local diff = pt2 - pt1
	local steps = Max(2, 1 + diff:Len2D() / step)
	local mapw, maph = terrain.GetMapSize()
	vpstr = vpstr or pstr("", 1024)
	for i=1,steps do
		local pos = pt1 + MulDivRound(diff, i - 1, steps - 1)
		local x, y = pos:xy()
		x = Clamp(x, 0, mapw - height_tile)
		y = Clamp(y, 0, maph - height_tile)
		AppendVertex(vpstr, x, y, offset, color)
	end
	return vpstr
end

function PlaceTerrainLine(pt1, pt2, color, step, offset)
	local vpstr = GetTerrainPointsPStr(false, pt1, pt2, step, offset, color)
	local line = PlaceObject("Polyline")
	line:SetMesh(vpstr)
	line:SetPos((pt1 + pt2) / 2)
	line:AddMeshFlags(const.mfTerrainDistorted)
	return line
end

function PlaceTerrainBox(box, color, step, offset, mesh_obj, depth_test)
	local p = {box:ToPoints2D()}
	local m
	for i = 1, #p do
		m = GetTerrainPointsPStr(m, p[i], p[i + 1] or p[1], step, offset, color)
	end
	mesh_obj = mesh_obj or PlaceObject("Polyline")
	if depth_test ~= nil then
		mesh_obj:SetDepthTest(depth_test)
	end
	mesh_obj:SetMesh(m)
	mesh_obj:SetPos(box:Center())
	mesh_obj:AddMeshFlags(const.mfTerrainDistorted)
	return mesh_obj
end

function PlaceTerrainPoly(p, color, step, offset, mesh_obj)
	local m
	local center = p[1] + ((p[1] - p[3]) / 2)
	for i = 1, #p do
		m = GetTerrainPointsPStr(m, p[i], p[i + 1] or p[1], step, offset, color)
	end
	mesh_obj = mesh_obj or PlaceObject("Polyline")
	mesh_obj:SetMesh(m)
	mesh_obj:SetPos(center)
	return mesh_obj
end

function PlacePolyLine(pts, clrs, depth_test)
	local line = PlaceObject("Polyline")
	line:SetEnumFlags(const.efVisible)
	if depth_test ~= nil then
		line:SetDepthTest(depth_test)
	end
	local vpstr = pstr("", 1024)
	local clr
	local pt0
	for i, pt in ipairs(pts) do
		if IsValidPos(pt) then
			pt0 = pt0 or pt
			clr = type(clrs) == "table" and clrs[i] or clrs or clr
			AppendVertex(vpstr, pt, clr)
		end
	end
	line:SetMesh(vpstr)
	if pt0 then
		line:SetPos(pt0)
	end
	return line
end

function AppendSplineVertices(spline, color, step, min_steps, max_steps, vpstr)
	step = step or guim
	min_steps = min_steps or 7
	max_steps = max_steps or 1024
	local len = BS3_GetSplineLength3D(spline)
	local steps = Clamp(len / step, min_steps, max_steps)
	vpstr = vpstr or pstr("", (steps + 2) * const.pstrVertexSize)
	local x, y, z
	local x0, y0, z0 = BS3_GetSplinePos(spline, 0)
	AppendVertex(vpstr, x0, y0, z0, color)
	for i = 1,steps-1 do
		local x, y, z = BS3_GetSplinePos(spline, i, steps)
		AppendVertex(vpstr, x, y, z, color)
	end
	local x1, y1, z1 = BS3_GetSplinePos(spline, steps, steps)
	AppendVertex(vpstr, x1, y1, z1, color)
	return vpstr, point((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
end

function PlaceSpline(spline, color, depth_test, step, min_steps, max_steps)
	local line = PlaceObject("Polyline")
	line:SetEnumFlags(const.efVisible)
	if depth_test ~= nil then
		line:SetDepthTest(depth_test)
	end
	local vpstr, pos = AppendSplineVertices(spline, color, step, min_steps, max_steps)
	line:SetMesh(vpstr)
	line:SetPos(pos)
	return line
end

function PlaceSplines(splines, color, depth_test, start_idx, step, min_steps, max_steps)
	local line = PlaceObject("Polyline")
	line:SetEnumFlags(const.efVisible)
	if depth_test ~= nil then
		line:SetDepthTest(depth_test)
	end
	local count = #(splines or "")
	local pos = point30
	local vpstr = pstr("", count * 128 * const.pstrVertexSize)
	for i = (start_idx or 1), count do
		local _, posi = AppendSplineVertices(splines[i], color, step, min_steps, max_steps, vpstr)
		pos = pos + posi
	end
	if count > 0 then
		pos = pos / count
	end
	line:SetMesh(vpstr)
	line:SetPos(pos)
	return line
end

function PlaceBox(box, color, mesh_obj, depth_test)
	local p1, p2, p3, p4 = box:ToPoints2D()
	local minz, maxz = box:minz(), box:maxz()
	local vpstr = pstr("", 1024)
	if minz and maxz then
		if minz >= maxz - 1 then
			for _, p in ipairs{p1, p2, p3, p4, p1} do
				local x, y = p:xy()
				AppendVertex(vpstr, x, y, minz, color)
			end
		else
			for _, z in ipairs{minz, maxz} do
				for _, p in ipairs{p1, p2, p3, p4, p1} do
					local x, y = p:xy()
					AppendVertex(vpstr, x, y, z, color)
				end
			end
			AppendVertex(vpstr, p2:SetZ(maxz), color)
			AppendVertex(vpstr, p2:SetZ(minz), color)
			AppendVertex(vpstr, p3:SetZ(minz), color)
			AppendVertex(vpstr, p3:SetZ(maxz), color)
			AppendVertex(vpstr, p4:SetZ(maxz), color)
			AppendVertex(vpstr, p4:SetZ(minz), color)
		end
	else
		local z = terrain.GetHeight(p1)
		for _, p in ipairs{p2, p3, p4} do
			z = Max(z, terrain.GetHeight(p))
		end
		for _, p in ipairs{p1, p2, p3, p4, p1} do
			local x, y = p:xy()
			AppendVertex(vpstr, x, y, z, color)
		end
	end
	mesh_obj = mesh_obj or PlaceObject("Polyline")
	if depth_test ~= nil then
		mesh_obj:SetDepthTest(depth_test)
	end
	mesh_obj:SetMesh(vpstr)
	mesh_obj:SetPos(box:Center())
	return mesh_obj
end

function PlaceVector(pos, vec, color, depth_test)
	vec = vec or 10*guim
	vec = type(vec) == "number" and point(0, 0, vec) or vec
	return PlacePolyLine({pos, pos + vec}, color, depth_test)
end

function CreateTerrainCursorCircle(radius, color)
	color = color or RGB(23, 34, 122)
	radius = radius or 30 * guim
	
	local line = CreateCircleMesh(radius, color)
	line:SetPos(GetTerrainCursor())
	line:SetMeshFlags(const.mfOffsetByTerrainCursor + const.mfTerrainDistorted + const.mfWorldSpace)
	return line
end

function CreateTerrainCursorSphere(radius, color)
	color = color or RGB(23, 34, 122)
	radius = radius or 30 * guim
	
	local line = PlaceObject("Mesh")
	line:SetMesh(CreateSphereVertices(radius, color))
	line:SetShader(ProceduralMeshShaders.mesh_linelist)
	line:SetPos(GetTerrainCursor())
	line:SetMeshFlags(const.mfOffsetByTerrainCursor + const.mfTerrainDistorted + const.mfWorldSpace)
	return line
end

function CreateOrientationMesh(pos)
	local o_mesh = Mesh:new()
	pos = pos or point(0, 0, 0) 
	o_mesh:SetShader(ProceduralMeshShaders.mesh_linelist)
	local r = guim/4
	local vpstr = pstr("", 1024)
	AppendVertex(vpstr, point(0, 0, 0), RGB(255, 0, 0))
	AppendVertex(vpstr, point(r, 0, 0))
	AppendVertex(vpstr, point(0, 0, 0), RGB(0, 255, 0))
	AppendVertex(vpstr, point(0, r, 0))
	AppendVertex(vpstr, point(0, 0, 0), RGB(0, 0, 255))
	AppendVertex(vpstr, point(0, 0, r))
	o_mesh:SetMesh(vpstr)
	o_mesh:SetPos(pos)
	return o_mesh
end

function CreateSphereMesh(radius, color, precision)
	local sphere_mesh = Mesh:new()
	sphere_mesh:SetMesh(CreateSphereVertices(radius, color))
	sphere_mesh:SetShader(ProceduralMeshShaders.mesh_linelist)
	return sphere_mesh
end

function PlaceSphere(center, radius, color, depth_test)
	local sphere = CreateSphereMesh(radius, color)
	if depth_test ~= nil then
		sphere:SetDepthTest(depth_test)
	end
	sphere:SetPos(center)
	return sphere
end

function ShowMesh(time, func, ...)
	local ok, meshes = procall(func, ...)
	if not ok or not meshes then
		return
	end
	return CreateRealTimeThread(function(meshes, time)
		Msg("ShowMesh")
		WaitMsg("ShowMesh", time)
		if IsValid(meshes) then
			DoneObject(meshes)
		else
			DoneObjects(meshes)
		end
	end, meshes, time)
end

function CreateCircleMesh(radius, color, center)
	local circle_mesh = Mesh:new()
	circle_mesh:SetMesh(AppendCircleVertices(nil, center, radius, color, true))
	circle_mesh:SetShader(ProceduralMeshShaders.default_polyline)
	return circle_mesh
end	

function PlaceCircle(center, radius, color, depth_test)
	local circle = CreateCircleMesh(radius, color)
	if depth_test ~= nil then
		circle:SetDepthTest(depth_test)
	end
	circle:SetPos(center)
	return circle
end

function CreateConeMesh(center, displacement, radius1, radius2, axis, angle, color)
	local circle_mesh = Mesh:new()
	circle_mesh:SetMesh(AppendConeVertices(nil, center, displacement, radius1, radius2, axis, angle, color))
	circle_mesh:SetShader(ProceduralMeshShaders.mesh_linelist)
	return circle_mesh
end	

function CreateCylinderMesh(center, displacement, radius, axis, angle, color)
	local circle_mesh = Mesh:new()
	circle_mesh:SetMesh(AppendConeVertices(nil, center, displacement, radius, radius, axis, angle, color))
	circle_mesh:SetShader(ProceduralMeshShaders.default_mesh)
	return circle_mesh
end	

function CreateMoveGizmo()
	local g_MoveGizmo = MoveGizmo:new()
	CreateRealTimeThread(function()
		while true do
			g_MoveGizmo:OnMousePos(GetTerrainCursor())
			Sleep(100)
		end
	end)
end

function CreateTerrainCursorTorus(radius1, radius2, axis, angle, color)
	color = color or RGB(255, 0, 0)
	radius1 = radius1 or 2.3 * guim
	radius2 = radius2 or 0.15 * guim
	axis = axis or axis_y
	angle = angle or 90
	
	local line = PlaceObject("Mesh")
	local vpstr = pstr("", 1024)
	local normal = selo():GetPos() - camera.GetEye()
	local b = selo():GetPos()
	local bigTorusAxis, bigTorusAngle = GetAxisAngle(normal, axis_z)
	bigTorusAxis = Normalize(bigTorusAxis)
	bigTorusAngle = 180 - bigTorusAngle / 60
	vpstr = AppendTorusVertices(vpstr, point(0, 0, 0), 2.3 * guim, 0.15 * guim, bigTorusAxis, bigTorusAngle, RGB(128, 128, 128))
	vpstr = AppendTorusVertices(vpstr, point(0, 0, 0), 2.3 * guim, 0.15 * guim, axis_y, 90, RGB(255, 0, 0), normal, b)
	vpstr = AppendTorusVertices(vpstr, point(0, 0, 0), 2.3 * guim, 0.15 * guim, axis_x, 90, RGB(0, 255, 0), normal, b)
	vpstr = AppendTorusVertices(vpstr, point(0, 0, 0), 2.3 * guim, 0.15 * guim, axis_z, 0, RGB(0, 0, 255), normal, b)
	vpstr = AppendTorusVertices(vpstr, point(0, 0, 0), 3.5 * guim, 0.15 * guim, bigTorusAxis, bigTorusAngle, RGB(0, 192, 192))
	line:SetMesh(vpstr)
	line:SetPos(selo():GetPos())
	return line
end

function CreateObjSurfaceMesh(obj, surface_flag, color1, color2)
	if not IsValidPos(obj) then
		return
	end
	local v_pstr = pstr("", 1024)
	ForEachSurface(obj, surface_flag, function(pt1, pt2, pt3, v_pstr, color1, color2)
		local color
		if color1 and color2 then
			local rand = xxhash(pt1, pt2, pt3) % 1024
			color = InterpolateRGB(color1, color2, rand, 1024)
		end
		v_pstr:AppendVertex(pt1, color)
		v_pstr:AppendVertex(pt2, color)
		v_pstr:AppendVertex(pt3, color)
	end, v_pstr, color1, color2)
	local mesh = PlaceObject("Mesh")
	mesh:SetMesh(v_pstr)
	mesh:SetPos(obj:GetPos())
	mesh:SetMeshFlags(const.mfWorldSpace)
	mesh:SetDepthTest(true)
	if color1 and not color2 then
		mesh:SetColorModifier(color1)
	end
	return mesh
end

function FlatImageMesh(texture, width, height, glow_size, glow_period, glow_color)
	local text = PlaceObject("Mesh")
	local vpstr = pstr("", 1024)
	local color = RGB(255,255,255)
	local half_size_x = width or 1000
	local half_size_y = height or 1000
	glow_size = glow_size or 0
	glow_period = glow_period or 0
	glow_color = glow_color or RGB(255,255,255)

	AppendVertex(vpstr, point(-half_size_x, -half_size_y, 0), color, 0, 0)
	AppendVertex(vpstr, point(half_size_x, -half_size_y, 0), color, 1, 0)
	AppendVertex(vpstr, point(-half_size_x, half_size_y, 0), color, 0, 1)

	AppendVertex(vpstr, point(half_size_x, -half_size_y, 0), color, 1, 0)
	AppendVertex(vpstr, point(half_size_x, half_size_y, 0), color, 1, 1)
	AppendVertex(vpstr, point(-half_size_x, half_size_y, 0), color, 0, 1)

	text:SetMesh(vpstr)

	if texture then
		local use_sdf = false
		local padding = 0
		local low_edge = 0
		local high_edge = 0
		if glow_size > 0 then
			use_sdf = true
			padding = 16
			low_edge = 490
			high_edge = 510
		end
		text:SetTexture(0, ProceduralMeshBindResource("texture", texture, false, 0))
		if glow_size > 0 then
			text:SetTexture(1, ProceduralMeshBindResource("texture", texture, true, 0, const.fmt_unorm16_c1))
			text:SetShader(ProceduralMeshShaders.default_ui_sdf)
		else
			text:SetShader(ProceduralMeshShaders.default_ui)
		end
		local r, g, b = GetRGB(glow_color)
		text:SetUniforms(low_edge, high_edge, glow_size, glow_period, r, g, b)
	end
	
	return text
end

DefineClass.FlatTextMesh = {
	__parents = { "Mesh" },
	properties = {
		{id = "font_id", editor = "number", read_only = true, default = 0, category = "Rasterize" },
		{id = "text_style_id", editor = "preset_id", preset_class = "TextStyle", editor_preview = true, default = false, category = "Rasterize" },
		{id = "text_scale", editor = "number", default = 1000, category = "Rasterize" },
		{id = "text", editor = "text", default = "", category = "Rasterize" },
		{id = "padding", editor = "number", default = 0, category = "Rasterize", help = "How much pixels to leave around the text(for effects)"},

		{id = "width", editor = "number", default = 0, category = "Present", help = "In meters. Leave 0 to calculate automatically"},
		{id = "height", editor = "number", default = 0, category = "Present", help = "In meters. Leave 0 to calculate automatically"},
		{id = "text_color", editor = "color", default = RGB(255,255,255), category = "Present"},
		{id = "effect_type", editor = "choice", items = {"none", "glow"}, default = "glow", category = "Present" },
		{id = "effect_color", editor = "color", default = RGB(255,255,255), category = "Present"},
		{id = "effect_size", editor = "number", default = 0, help = "In pixels from the rasterized image.", category = "Present" },
		{id = "effect_period", editor = "number", default = 0, help = "1 pulse per each period seconds. ", category = "Present"},
	}
}

function FlatTextMesh:Init()
	self:Recreate()
end

function FlatTextMesh:FetchEffectsFromTextStyle()
	local text_style = TextStyles[self.text_style_id]
	if not text_style then return end
	self.text_color = text_style.TextColor
	self.effect_type = text_style.ShadowType == "glow" and "glow" or "none"
	self.effect_color = text_style.ShadowColor
	self.effect_size = text_style.ShadowSize
	self.textstyle_id = self.text_style_id
end

function FlatTextMesh:SetColorFromTextStyle(text_style_id)
	self.text_style_id = text_style_id
	self.textstyle_id = text_style_id
	self:FetchEffectsFromTextStyle()
	self:Recreate()
end

function FlatTextMesh:CalculateSizes(max_width, max_height, default_scale)
	local width_pixels, height_pixels = UIL.MeasureText(self.text, self.font_id)
	local scale = 0
	if max_width == 0 and max_height == 0 then
		scale = default_scale or 10000
	elseif max_width == 0 then
		max_width = 1000000
	elseif max_height == 0 then
		max_height = 1000000
	end

	if scale == 0 then
		local scale1 = MulDivRound(max_width, 1000, width_pixels)
		local scale2 = MulDivRound(max_height, 1000, height_pixels)
		scale = Min(scale1, scale2)
	end

	self.width = MulDivRound(width_pixels, scale, 1000)
	self.height = MulDivRound(height_pixels, scale, 1000)
end

function FlatTextMesh:Recreate()
	local text_style = TextStyles[self.text_style_id]
	if not text_style then return end
	local font_id = text_style:GetFontIdHeightBaseline(self.text_scale)
	self.font_id = font_id

	local effect_type = self.effect_type
	local use_sdf = false
	local padding = 0
	if effect_type == "glow" then
		use_sdf = true
		padding = 16
	end

	local width_pixels, height_pixels = UIL.MeasureText(self.text, font_id)
	local width = self.width
	local height = self.height
	if width == 0 and height == 0 then
		local default_scale = 10000
		width = MulDivRound(width_pixels, default_scale, 1000)
		height = MulDivRound(height_pixels, default_scale, 1000)
	end
	if width == 0 then
		width = MulDivRound(width_pixels, height, height_pixels)
	end
	if height == 0 then
		height = MulDivRound(height_pixels, width, width_pixels)
	end
	
	--add for padding
	width = width + MulDivRound(width, padding * 2 * 1000, width_pixels * 1000)
	height = height + MulDivRound(height, padding * 2 * 1000, height_pixels * 1000)


	local vpstr = pstr("", 1024)
	local half_size_x = (width or 1000) / 2
	local half_size_y = (height or 1000) / 2
	local color = self.text_color
	AppendVertex(vpstr, point(-half_size_x, -half_size_y, 0), color, 0, 0)
	AppendVertex(vpstr, point(half_size_x, -half_size_y, 0), color, 1, 0)
	AppendVertex(vpstr, point(-half_size_x, half_size_y, 0), color, 0, 1)

	AppendVertex(vpstr, point(half_size_x, -half_size_y, 0), color, 1, 0)
	AppendVertex(vpstr, point(half_size_x, half_size_y, 0), color, 1, 1)
	AppendVertex(vpstr, point(-half_size_x, half_size_y, 0), color, 0, 1)

	self:SetMesh(vpstr)

	self:SetTexture(0, ProceduralMeshBindResource("text", self.text, font_id, use_sdf, padding))
	local r, g, b = GetRGB(self.effect_color)
	self:SetUniforms(use_sdf and 1000 or 0, 0, self.effect_size * 1000, self.effect_period, r, g, b)
	self:SetShader(ProceduralMeshShaders.default_ui)
end

function TestUIRenderables()
	local pt = GetTerrainCursor() + point(0, 0, 100)
	for i = 0, 4 do
		local height = 700
		local space = 5000

		local text = FlatTextMesh:new({
			text_style_id = "ProcMeshDefault",
			text_scale = 500 + 400 * i,
			text = "Hello world",
			height = height,
		})
		text:SetPos(pt + point(i * space, 0, 0))

		text = FlatTextMesh:new({
			text_style_id = "ProcMeshDefaultFX",
			text_scale = 500 + 400 * i,
			text = "Hello world",
			height = height,
			effect_type = "glow",
			effect_size = 8,
			effect_period = 200,
			effect_color = RGB(255, 0, 0),
		})
		text:SetPos(pt + point(i * space, 3000, 0))
		text:SetGameFlags(const.gofRealTimeAnim)

		local mesh = FlatImageMesh("UI/MercsPortraits/Buns", 1000, 1000, 200 * i, 1000, RGB(255, 255, 255))
		mesh:SetPos(pt + point(i * space, 6000, 0))

		mesh = FlatImageMesh("UI/MercsPortraits/Buns", 1000, 1000)
		mesh:SetPos(pt + point(i * space, 9000, 0))
	end
end

function DebugShowMeshes()
	local meshes = MapGet("map", "Mesh")
	OpenGedGameObjectEditor(meshes, true)
end

-- Represents combination of shader & the data the shader accepts. Provides "properties" interface for the underlying raw bits sent to the shader.
-- Inherits from PersistedRenderVars(is a preset) and provides minimalistic default logic for updating meshes on the fly.
local function depth_test_values(obj)
	local tbl = {{value = "default", text = "default"}}
	local shader_id = obj.shader_id
	local shader_data = ProceduralMeshShaders[shader_id]
	if shader_data then
		if shader_data.depth_test == "runtime" or shader_data.depth_test == "never" then
			table.insert(tbl, {value = false, text = "never"})
		end
		if shader_data.depth_test == "runtime" or shader_data.depth_test == "always" then
			table.insert(tbl, {value = true, text = "always"})
		end
	end
	return tbl
end
DefineClass.CRMaterial = {
	__parents = {"PersistedRenderVars", "MeshParamSet"},

	properties = { 
		{ id = "ShaderName", editor = "choice", default = "default_mesh", items = function() return table.keys2(ProceduralMeshShaders, "sorted") end, read_only = true,},
		{ id = "depth_test", editor = "choice", items = depth_test_values },
	},
	group = "CRMaterial",
	depth_test = "default",
	cloned_from = false,
	shader_id = "default_mesh",
	shader = false,
	pstr_buffer = false,
	dirty = false,
}

function CRMaterial:GetError()
	if not self.shader_id then
		return "CRMaterial without a shader_id."
	end
	if not ProceduralMeshShaders[self.shader_id] then
		return "ShaderID " .. self.shader_id .. " is not valid."
	end
end

function CRMaterial:GetShader()
	if self.shader then
		return self.shader
	end
	if self.shader_id then
		return ProceduralMeshShaders[self.shader_id]
	end
	return false
end

------- Prevent triggering Preset logic on cloned materials. Probably should be implemented smarter, maybe by __index table reference, so even clones are live updated by editor
function CRMaterial:SetId(value)
	if self.cloned_from then
		self.id = value
	else
		PersistedRenderVars.SetId(self, value)
	end
end

function CRMaterial:SetGroup(value)
	if self.cloned_from then
		self.group = value
	else
		PersistedRenderVars.SetGroup(self, value)
	end
end

function CRMaterial:Register(...)
	if self.cloned_from then
		return
	end
	return PersistedRenderVars.Register(self, ...)
end

function CRMaterial:Clone()
	local obj = _G[self.class]:new({cloned_from = self.id})
	obj:CopyProperties(self)
	return obj
end

function CRMaterial:GetDataPstr()
	if self.dirty or not self.pstr_buffer then
		self:Recreate()
	end
	return self.pstr_buffer
end

function CRMaterial:GetShaderName()
	return self.shader and self.shader.id or self.shader_id
end

function CRMaterial:Recreate()
	self.dirty = false
	self.pstr_buffer = self:WriteBuffer()
end

function CRMaterial:OnPreSave()
	self.pstr_buffer = nil
end

function CRMaterial:Apply()
	self:Recreate()
	if CurrentMap ~= "" then
		MapGet("map", "Mesh", function(o)
			local omtrl = o.CRMaterial
			if omtrl == self then
				o:SetCRMaterial(self)
			elseif (omtrl and omtrl.id == self.id) then
				for _, prop in ipairs(omtrl:GetProperties()) do
					local value = rawget(omtrl, prop.id)
					if value == nil or (not prop.read_only and not prop.no_edit) then
						omtrl:SetProperty(prop.id, self:GetProperty(prop.id))
					end
				end
				omtrl:Recreate()
				o:SetCRMaterial(omtrl)
			end
		end)
	end
end



DefineClass.CRM_DebugMeshMaterial = {
	__parents = {"CRMaterial"},

	shader_id = "debug_mesh",
	properties = {
	},
}

