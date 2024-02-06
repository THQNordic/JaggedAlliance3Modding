-- TODO Move file - HGL must not do this file.
if Platform.cmdline then return end

DefineClass.EV_DummyTextItem =
{
	__parents = { "PropertyObject" },
	properties = {},
	itemtext = "None",
	parent = false,
}

DefineClass.EV_Spot =
{
	__parents = { "PropertyObject" },
	properties = {
		{ id = "bone", editor = "text" },
		{ id = "name", editor = "text" },
	},
	bone = "", 
	name = "",
	itemtext = "",
	parent_state = false,
}

function EV_Spot:OnEditorSelect(selected, ged)
	local root = ged:ResolveObj("root")
	if selected then
		root.obj:Attach( root.spotObj, root.obj:GetSpotBeginIndex( EntitySpots[self.name] ))
		root.spotText:SetText(self.name)
		root.obj:Attach( root.spotText, root.obj:GetSpotBeginIndex( EntitySpots[self.name] ))
		root.spotText:SetEnumFlags(const.efVisible)
		root.spotObj:SetEnumFlags(const.efVisible)
	else
		root.spotText:Detach()
		root.spotObj:Detach()
		root.spotText:ClearEnumFlags(const.efVisible)
		root.spotObj:ClearEnumFlags(const.efVisible)
	end
end

DefineClass.EV_Surfaces =
{
	__parents = { "PropertyObject" },
	properties = {
		{ id = "surfacetype", editor = "text" },
	},
	surfacetype = "",
	es_index = -1,
	itemtext = "",
	parent_state = false,
}

function EV_Surfaces:OnEditorSelect(selected, ged)
	if selected then
		hr.ShowSurfaces = 1
		hr.ShowSurfacesType = self.surfacetype
	else
		hr.ShowSurfaces = 0
	end
end

DefineClass.EV_Moment =
{
	__parents = { "PropertyObject" },
	properties = {
		{ id = "type", editor = "text", default = ""},
		{ id = "time", editor = "number", default = 0},
	},
	itemtext = "", 
	parent_state = false, 
	
	Getitemtext = function(self)
		return self.time .. " | " .. self.type
	end
}

function EV_Moment:OnEditorSelect(selected, ged)
	local root = ged:ResolveObj("root")
	root.obj:SetAnimSpeed(1,0)
	root.obj:SetAnimPhase(1, self.time)
end


local function FileNameFromPath(path)
	path = string.gsub( path, "\\","/")
	path = string.gsub(path, "([^/]+)/", "")
	if path == "" then
		return false
	else
		return path
	end
end

function EV_LocateFile(parent_editor, obj, property)
	local filepath = obj[property]
	if filepath then
		OS_LocateFile(filepath)
	end
end

function EV_OpenFile(parent_editor, obj, property)
	local filepath = obj[property]
	if filepath then
		OS_OpenFile(filepath)
	end
end


local function FindXMLTag(xml, tag, close_tag)
	local tag_start, _ = string.find(xml, tag)
	if not tag_start then return end
	xml = xml:sub(tag_start)
	if not close_tag then
		return xml:sub(1, string.find(xml, "/>") + 2)
	else
		local tag_end = string.find(xml, close_tag)
		if not tag_end then return xml end
		return xml:sub(1, tag_end + close_tag:len())
	end
end

function EV_LoadEntityXML(entity)
	local file_path = "Entities/".. entity .. ".ent"
	local err, xml = AsyncFileToString( file_path )
	return err and "" or xml
end

function EV_GetMeshSourceFile(entity_xml, mesh)	
	local mesh_desc = FindXMLTag(entity_xml, '<mesh_description id="'.. tostring(mesh) .. '">', '</mesh_description>')
	if not mesh_desc then return "" end
	local src_file = FindXMLTag(mesh_desc, '<src file=')
	if not src_file then return "" end
	return string.match(src_file, '<src file="([^"]+)"')
end

function EV_GetAnimSourceFile(entity_xml, anim)	
	local state_desc = FindXMLTag(entity_xml, '<state id="'.. anim .. '">', '</state>')
	if not state_desc then return "" end
	local src_file = FindXMLTag(state_desc, '<src file=')
	if not src_file then return "" end
	return string.match(src_file, '<src file="([^"]+)"')
end

local maps_buttons = {
	{name = "View", func = "OpenTextureViewer"},
	{name = "Alpha", func = "OpenTextureViewerAlpha"},
	{name = "Locate", func = "EV_LocateFile"},
	{name = "InGame", func = "OpenTextureViewerIngame"},
}

local if_not_set = function(obj, prop_id)
	return not obj[prop_id.id] or obj[prop_id.id] == ""
end

DefineClass.EV_Material =
{
	__parents = { "PropertyObject" },
	properties = {
		{ name = "Filename", id = "filename", editor = "text", default = "", buttons = {{name = "Open", func = "EV_OpenFile"}, { name = "Locate", func = "EV_LocateFile"}} },
		{ name = "Dust map", id = "Dust", editor = "text", default = "", no_edit = if_not_set, buttons = maps_buttons },
	},
	parent = false,
	itemtext = "",
	index = false,

	Create = function(self, name, index, sub_material, parent)
		self.parent = parent
		self.filename = "Materials/".. string.gsub(name, ".mtl.", ".hmtl.")
		self.index = index
		if not sub_material then
			self.itemtext = FileNameFromPath(name)
		else
			self.itemtext = "SubMaterial "..tostring(sub_material)
		end
	end
}

function EV_Material.new(class, obj)
	obj = obj or {}
	for i,prop_meta in ipairs(class.properties) do
		local value = obj[prop_meta.id]
		if value and prop_meta.editor == "bool" then
			obj[prop_meta.id] = (value ~= 0)
		elseif prop_meta.editor == "image" then
			obj[prop_meta.id] = obj[prop_meta.org_id] or false
		end
	end
	return setmetatable(obj, class)
end

local all_properties = GetMaterialProperties()
for i,prop in ipairs(all_properties) do
	if not string.find(prop.field, "MapChannel") then
		local prop_meta = { }
		prop_meta.id = prop.field
		prop_meta.name = prop.field
		prop_meta.editor =
		    (prop.type == "std::string" and "text") or
		    (prop.type == "int" and "number") or
		    (prop.type == "float" and "number")
		prop_meta.default = prop.value
		prop_meta.read_only = true
		table.insert(EV_Material.properties, prop_meta)
		
		if string.find(prop.field, "Map") then
			prop_meta.buttons = table.iappend(prop_meta.buttons or {}, maps_buttons)

			local preview_prop_meta = { }
			preview_prop_meta.org_id = prop.field
			preview_prop_meta.id = prop.field .. "Preview"
			preview_prop_meta.name = prop.field .. "Preview"
			preview_prop_meta.editor = "image"
			preview_prop_meta.default = false
			preview_prop_meta.read_only = true
			preview_prop_meta.img_size = 128
			preview_prop_meta.img_box = 1
			preview_prop_meta.base_color_map = true
			preview_prop_meta.no_edit = function(obj, meta)
				local value = obj[meta.id]
				return not (type(value) == "string" and value ~= "")
			end
			table.insert(EV_Material.properties, preview_prop_meta)
		end
	end
end

DefineClass.EV_MeshInfo = {
	__parents = { "PropertyObject" },
	properties = {
		-- General
		{ id = "MeshName", editor = "text", read_only = true, default = "", category = "General" },
		{ id = "NumSub", editor = "number", read_only = true, default = 0, category = "General" },
		{ id = "NumTriangles", editor = "number", read_only = true, default = 0, category = "General" },
		{ id = "NumVerts", editor = "number", read_only = true, default = 0, category = "General" },
		{ id = "NumIndices", editor = "number", read_only = true, default = 0, category = "General" },
		{ id = "Size", editor = "number", read_only = true, default = 0, category = "General" },
		{ id = "Volume", editor = "number", read_only = true, default = 0, category = "General" },
		-- BoundingSphere
		{ id = "BSCenter", name = "Center", editor = "point", read_only = true, default = point(-1, -1), category = "Bounding Sphere" },
		{ id = "BSRadius", name = "Radius", editor = "number", read_only = true, default = 0, category = "Bounding Sphere" },
		{ id = "BSHelperVis", name = "Helper Visbility", editor = "bool", default = false, category = "Bounding Sphere" },
	},	
	itemtext = "",
	bs_helper_obj = false,
	bs_update_thread = false,
	obj = false,
	parent = false,
}

function EV_MeshInfo:Create(info, obj)
	for p, v in pairs(info) do
		if table.find(self.properties, "id", p) then
			self[p] = v
		else
			assert(false, "Trying to show an unknown mesh property in the EV!")
		end
	end
	self.obj = obj
	self.bs_helper_obj = CreateSphereMesh(self.BSRadius)
	
	self:CreateBSUpdateThread()
	self:ShowBSphere(false)
end

function EV_MeshInfo:CreateBSUpdateThread()
	DeleteThread(self.bs_update_thread)
	self.bs_update_thread = CreateRealTimeThread(function()
		Sleep(1000) -- EV init wait
		while IsValid(self.obj) and IsValid(self.bs_helper_obj) and self.obj:IsValidPos() do
			local center, radius = self.obj:GetBSphere()
			if center ~= self.BSCenter or radius ~= self.BSRadius then 
				self.BSCenter, self.BSRadius = center, radius
				ObjModified(self)
			end
			self.bs_helper_obj:SetPos(center)
			self.bs_helper_obj:SetMesh(CreateSphereVertices(radius))
			if self.BSHelperVis then
				self.bs_helper_obj:SetEnumFlags(const.efVisible)
			else
				self.bs_helper_obj:ClearEnumFlags(const.efVisible)
			end
			Sleep(50)
		end
	end)
end

function EV_MeshInfo:ShowBSphere(visible)
	self.BSHelperVis = visible
end

function EV_MeshInfo:DestroyBSphere()
	if IsValid(self.bs_helper_obj) then
		DeleteThread(self.bs_update_thread)
		DoneObject(self.bs_helper_obj)
	end
end

DefineClass.EV_State =
{
	__parents = { "PropertyObject" },
	properties = {
		-- Misc
		{ id = "name", editor = "text", default = "" },
		{ id = "duration", editor = "number", default = 0, read_only = true},
		{ id = "errorstate", editor = "bool", default = false, no_edit = true },
		
		-- Files
		{ id = "mesh_file", name = "Mesh File", editor = "text", default = "", category = "Files", buttons = {{name = "Open", func = "EV_OpenFile"}, {name = "Locate", func = "EV_LocateFile"}}},
		{ id = "mesh_src_file", name = "Mesh Source", editor = "text", default = "", category = "Files", buttons = {{name = "Open", func = "EV_OpenFile"}, {name = "Locate", func = "EV_LocateFile"}}},
		{ id = "anim_file", name = "Anim File", editor = "text", default = "", category = "Files", buttons = {{name = "Open", func = "EV_OpenFile"}, {name = "Locate", func = "EV_LocateFile"}}},
		{ id = "anim_src_file", name = "Anim Source", editor = "text", default = "", category = "Files", buttons = {{name = "Open", func = "EV_OpenFile"}, {name = "Locate", func = "EV_LocateFile"}}},
		{ id = "material_file", name = "Material", editor = "text", default = "", category = "Files", buttons = {{name = "Open", func = "EV_OpenFile"}, {name = "Locate", func = "EV_LocateFile"}}},
		{ id = "ent_file", name = "Ent File", editor = "text", default = "", category = "Files", buttons = {{name = "Open", func = "EV_OpenFile"}, {name = "Locate", func = "EV_LocateFile"}}},
	},	
	entity = "",
	obj = false,
	itemtext = "",
	parent = false,
	parent_mesh = false,

	MarkErrorState = function (self) return self.errorstate and " *" or "" end,
}

function EV_State:Create(entity, obj, state, parent_item, parent_mesh)
	assert(HasState(entity, state))
	self.entity = entity
	self.parent = parent_item
	self.parent_mesh = parent_mesh
	self.name = state
	self.obj = obj
	local modifier = GetStateSpeedModifier(self.entity, GetStateIdx(self.name))
	self.duration = MulDivRound(GetAnimDuration(entity, EntityStates[state]), modifier, 1000)

	self.ent_file = GetEntityFile(entity)

	local anim_entity = GetAnimEntity(entity, EntityStates[state])
	local entity_xml = EV_LoadEntityXML(anim_entity)
	local mesh_file =  GetStateMeshFile(entity, EntityStates[state], parent_mesh.lod)
	self.mesh_file = "Meshes/" .. mesh_file;
	self.mesh_src_file = EV_GetMeshSourceFile(entity_xml, "mesh")
	
	self.material_file = "Materials/"..GetStateMaterial(entity, EntityStates[state])
	
	local anim_file = GetStateAnimFile(entity,  EntityStates[state])
	if anim_file ~= "" then
		self.anim_file = "Animations/"..anim_file
		self.anim_src_file = EV_GetAnimSourceFile(entity_xml, self.name)
	else
		self.anim_file = "no anim (static mesh)"
		self.anim_src_file = "no src available"
	end
	
	self.errorstate = obj:IsErrorState(GetStateIdx(state))
	self.itemtext = self.name .. self:MarkErrorState()
	self.SMTime = 0
	self.SMSound = false
	
	local spots_root_item = EV_DummyTextItem:new{itemtext = "Spots", parent = false}
	self[#self+1] = spots_root_item
	local spbeg, spend = GetAllSpots(entity, state)
	for i = spbeg, spend do
		local sp = EV_Spot:new()
		sp.name = GetSpotName(entity, i)
		sp.bone = ""
		sp.itemtext = sp.name .. " | " .. " \""..sp.bone.."\""
		sp.parent_state = self
		table.insert(spots_root_item, sp)
	end

	local surfaces_root_item = EV_DummyTextItem:new{itemtext = "Surfaces", parent = false}
	self[#self+1] = surfaces_root_item
	for stype in pairs(EntitySurfaces) do
		if HasAnySurfaces(entity,EntitySurfaces[stype]) and not (stype == "All" or stype == "AllPass" or stype == "AllPassAndWalk") then
			local surfaces = EV_Surfaces:new()
			surfaces.surfacetype = stype
			surfaces.itemtext = stype
			surfaces.parent = surfaces_root_item
			table.insert(surfaces_root_item, surfaces)
		end
	end

	local moments_root_item = EV_DummyTextItem:new{itemtext = "Moments", parent = false}
	self[#self+1] = moments_root_item
	local state_moments = GetStateMoments(entity,state)
	table.sortby_field(state_moments, "time")
	for i=1, #state_moments do
		local moment = EV_Moment:new()
		moment.type = state_moments[i]["type"]
		moment.time = state_moments[i]["time"]
		moment.ev_state = self
		moment.parent_state = self
		table.insert(moments_root_item, moment)
	end
end
	
function EV_State:PlayAnim(root, prop_id, ged)
	if not self.errorstate then
		root:PlayAnim(ged:ResolveObj("SelectedMesh"))
	end
end
	
function EV_State:OnEditorSelect(selected, ged)
	self.obj:SetRealtimeAnim(true)
	self.obj:SetState(self.name)
	self.anim_speed = self.obj:GetAnimSpeed(1)
	self.obj:TestState(1)
	ged:ResolveObj("root"):PlayAnim(nil, nil, ged)
	self.obj:SetForcedLOD(self.parent_mesh.lod)
end

DefineClass.HexShapePlaceholder = {
	__parents = { "PosMarkerObj" },
	entity = "Hex1_Placeholder",
	editor_text_offset = point(0, 0, 11*guim),
}

local HexColorsByType = {
	outline = RGBA(150, 0, 0, 0),
	interior = RGBA(150, 150, 0, 0),
	buildable = RGBA(150, 220, 0, 0),
}
local function CreateHex(object, hex_offset, hex_type)
	local obj = PlaceObject("HexShapePlaceholder")
	obj:SetCollision(false)
	obj:SetApplyToGrids(false)
	
	local objectPos = object:GetPos()
	local x, y = HexToWorld(hex_offset:xy())
	x = x + objectPos:x()
	y = y + objectPos:y()
	obj:SetPos(point(x, y))
	obj:SetColorModifier(HexColorsByType[hex_type] or red)
	return obj
end

DefineClass.EV_Mesh =
{
	__parents = { "PropertyObject" },

	properties = {
		-- General
		{ id = "MeshName", editor = "text", read_only = true, default = "", category = "General" },
		{ id = "NumBones", editor = "number", read_only = true, default = 0, category = "General"},
		{ id = "NumSub", editor = "number", read_only = true, default = 0, category = "General" },
		{ id = "NumTriangles", editor = "number", read_only = true, default = 0, category = "General" },
		{ id = "NumVerts", editor = "number", read_only = true, default = 0, category = "General" },
		{ id = "NumIndices", editor = "number", read_only = true, default = 0, category = "General" },
		{ id = "Size", editor = "number", read_only = true, default = 0, category = "General" },
		{ id = "Volume", editor = "number", read_only = true, default = 0, category = "General" },
		-- BoundingSphere
		{ id = "BSCenter", name = "Center", editor = "point", read_only = true, default = point(-1, -1), category = "Bounding Sphere" },
		{ id = "BSRadius", name = "Radius", editor = "number", read_only = true, default = 0, category = "Bounding Sphere" },
		{ id = "BSHelperVis", name = "Helper Visbility", editor = "bool", default = false, category = "Bounding Sphere" },
	},	

	lod = 0,
	itemtext = "",
	bs_update_thread = false,
	bs_helper_obj = false,
}

function EV_Mesh:name()
	return string.format("(%s) %s", self.lod, self.itemtext)
end

function EV_Mesh:MeshInfoCreate( mesh_name, obj)
	local mesh_info = GetMeshProperties(mesh_name)
	mesh_info.BSCenter, mesh_info.BSRadius = obj:GetBSphere()
	local mesh_info_item = EV_MeshInfo:new{itemtext = "Mesh Info"}
	for p, v in pairs(mesh_info) do
		if table.find(self.properties, "id", p) then
			self[p] = v
		else
			assert(false, "Trying to show an unknown mesh property in the EV!")
		end
	end
	self.obj = obj
	
	self.bs_helper_obj = CreateSphereMesh(self.BSRadius)
	self:CreateBSUpdateThread()
	self:ShowBSphere(false)
end
	
function EV_Mesh:Create(parent, entity, obj, mesh_name, mesh_states, mesh_lod)
	self.itemtext = FileNameFromPath(mesh_name)
	self.lod = mesh_lod
	local states = GetStates(entity)

	local states_root_item = { itemtext = "States" }

	local state_item
	for i=1, #ArtSpecConfig.ReturnAnimationCategories do
		local cat = ArtSpecConfig.ReturnAnimationCategories[i]
		local cat_states = GetStatesFromCategory(entity, cat)
		local cat_item
		local cat_items_count = 0
		for j=1, #cat_states do
			local cat_state = cat_states[j]
			if table.find(mesh_states, EntityStates[cat_state]) then
				state_item = EV_State:new({	GedTreeCollapsedByDefault = true })
				state_item:Create(entity, obj, cat_state, cat_item, self)

				states_root_item[#states_root_item + 1] = state_item
				cat_items_count = cat_items_count + 1
			end
		end
	end
	local material_name = state_item and GetStateMaterial(entity, state_item.name, self.lod)
	
	table.sort(self, function(a, b) return CmpLower(a.itemtext, b.itemtext) end)
	table.insert(self, 1, states_root_item)

	local materials_root = EV_DummyTextItem:new{itemtext = "Materials", parent = self}
	self[#self+1] = materials_root
	local mat = GetMaterialProperties(material_name)
	local em = EV_Material:new(mat)
	em:Create(material_name, false, materials_root)
	materials_root[#materials_root+1] = em
	if IsMultiMaterial(material_name) then
		local num_sub_mtls = GetNumSubMaterials(material_name)
		for i=1, num_sub_mtls do
			local mat = GetMaterialProperties(material_name, i-1)
			local submat = EV_Material:new(mat)
			submat:Create(material_name, i-1, em)
			em[#em+1] = submat
		end
	end
	self:MeshInfoCreate(mesh_name, obj)
end

function EV_Mesh:CreateBSUpdateThread()
	DeleteThread(self.bs_update_thread)
	self.bs_update_thread = CreateRealTimeThread(function()
		Sleep(1000) -- EV init wait
		while IsValid(self.obj) and IsValid(self.bs_helper_obj) and self.obj:IsValidPos() do
			local center, radius = self.obj:GetBSphere()
			if center ~= self.BSCenter or radius ~= self.BSRadius then 
				self.BSCenter, self.BSRadius = center, radius
				ObjModified(self)
			end
			self.bs_helper_obj:SetPos(center)
			self.bs_helper_obj:SetMesh(CreateSphereVertices(radius))
			if self.BSHelperVis then
				self.bs_helper_obj:SetEnumFlags(const.efVisible)
			else
				self.bs_helper_obj:ClearEnumFlags(const.efVisible)
			end
			Sleep(50)
		end
	end)
end

function EV_Mesh:ShowBSphere(visible)
	self.BSHelperVis = visible
end

function EV_Mesh:DestroyBSphere()
	if IsValid(self.bs_helper_obj) then
		DeleteThread(self.bs_update_thread)
		DoneObject(self.bs_helper_obj)
	end
end

function EV_Mesh:OnEditorSelect(selected, ged)
	local root = ged:ResolveObj("root")
	if IsValid(root.obj) then
		if selected then
			root.obj:SetForcedLOD(self.lod)
		else
			root.obj:SetForcedLOD(const.InvalidLODIndex)
		end
	end
end

function GetEntityMaterialsMap(entity)
	local states = (entity == "") and {} or GetStates(entity)
	local mesh_states_map, mesh_lod_map = {}, {}
	for i=1, #states do
		local state_name = states[i]
		local state_idx = EntityStates[state_name]
		local lod_count = GetStateLODCount(entity, state_idx)
		for lod=1, lod_count do
			local mesh_name = GetStateMeshFile(entity, state_idx, lod - 1)
			if not mesh_states_map[mesh_name] then
				mesh_states_map[mesh_name] = {}
				mesh_lod_map[mesh_name] = lod - 1
			end
			table.insert(mesh_states_map[mesh_name], state_idx)
		end
	end
	
	return mesh_states_map, mesh_lod_map
end

DefineClass.EntityViewerRoot = {
	__parents = {"InitDone" },
	
	spotObj = false,
	spotText = false,
	obj = false,
	entity = false,
	spotAttach = false,

	anim_speed = 1,
}

function EntityViewerRoot:Init(obj)
	self.spotObj = CreateOrientationMesh()
	self.spotText = PlaceObject("Text")
	self.obj = obj
	self.entity = obj:GetEntity()
	
	CreateRealTimeThread(function ()
		WaitNextFrame(2) -- wait camera switch to obtain proper cursor pos
		if not obj:IsValidPos() then
			local sizex, sizey = terrain.GetMapSize()
			local posx, posy = GetTerrainCursor():xy()
			local border = 100 * guim
			posx = Clamp(posx, border, sizex - border)
			posy = Clamp(posy, border, sizey - border)
			obj:SetPos(point(posx, posy, GetWalkableZ(point(posx, posy)) + guim/10))
		end
		editor.ClearSel()
		editor.AddToSel({obj})
		local obj_center = obj:GetVisualPos() + point (0,0, obj:GetHeight()/2)
		cameraMax.SetCamera(obj_center - (camera.GetDirection()* obj:GetRadius()*2/1000), obj_center)
	end)

	local mesh_states_map, mesh_lod_map = GetEntityMaterialsMap(self.entity)
	for m_name, m_map in pairs(mesh_states_map) do
		local emesh = EV_Mesh:new()
		emesh:Create(self, self.entity, self.obj, m_name, m_map, mesh_lod_map[m_name])
		table.insert(self, emesh)
	end
end
	
function EntityViewerRoot:PlayAnim(mesh)
	if self.anim_speed then
		if IsValid(self.obj) then
			if self.obj:TimeToAnimEnd() == 1 or self.obj:GetAnimSpeed() == 0 then
				self.obj:SetAnimSpeed(1, self.anim_speed)
				self.obj:SetState(self.obj:GetState(), 0, 0)
				self.obj:SetForcedLOD(mesh and mesh.lod or const.InvalidLODIndex)
			end
		end
	end
end
	
function EntityViewerRoot:AttachDetachAtSpot(ged)
	if self.spotAttach then
		self.spotAttach:Detach()
		DoneObject(self.spotAttach)
		self.spotAttach = false
		return
	end

	local state, spot
	local selected_object = ged:ResolveObj("SelectedObject")
	if selected_object:IsKindOf("EV_Spot") then
		spot = selected_object
		state = spot.parent_state
	else
		print("Please select a spot.")
		return
	end

	local classes = ClassDescendantsList("CObject")
	local class = ged:WaitUserInput("Choose object to attach", "", classes)
	if not class then
		return
	end

	self.spotAttach = PlaceObject(class)
	self.obj:Attach( self.spotAttach, self.obj:GetSpotBeginIndex(spot.name))
	self.attach_class = class
end

function CreateEntityViewer(obj)
	local root = EntityViewerRoot:new({}, obj)
	local ged = OpenGedApp("GedEntityViewer", root)
	return ged
end