FadeCategories = {
	["Auto 50%"] = { min = 50, max = 0 },
	["Auto 75%"] = { min = 75, max = 0 },
	["Auto"] = { min = 100, max = 0 },
	["Auto 150%"] = { min = 150, max = 0 },
	["Auto 200%"] = { min = 200, max = 0 },
	["Auto 300%"] = { min = 300, max = 0 },
	["Auto 400%"] = { min = 400, max = 0 },
	["Auto 500%"] = { min = 500, max = 0 },
	["Auto 600%"] = { min = 600, max = 0 },
	["Max"] = { min = 1000000, max = 1000000, },
	["Never"] = { min = -1, max = -1, },
}

local NoCameraCollision = config.NoCameraCollision

if FirstLoad then
	EntityValidCharacters = "[%w#_+]"
	g_AllEntities = false
end

function OnMsg.BinAssetsLoaded()
	g_AllEntities = GetAllEntities()
end

local CommonAssetFirstID = 100000

function GetAllEntitiesComboItems()
	g_AllEntities = g_AllEntities or GetAllEntities()
	return table.keys2(g_AllEntities, true, "")
end

local function GetEntitySpecComboItems(except)
	local items = {""}
	ForEachPreset(EntitySpec, function(spec)
		if not except or spec.id ~= except then
			items[#items + 1] = spec.id
		end
	end)
	return items
end

DefineClass.AssetSpec = {
	__parents = { "InitDone" },
	properties = {
		-- stored in max script
		{ maxScript = true, id = "name", name = "Name", editor = "text", default = "NONE" },
	},
	
	save_in = "",
	TypeColor = false,
	EditorView = Untranslated('<ChooseColor><class></color> "<name>"'),
}

function AssetSpec:ChooseColor()
	return self.TypeColor and string.format("<color %s %s %s>", GetRGB(self.TypeColor)) or ""
end

function AssetSpec:FindUniqueName(old_name)
	local entity_spec = GetParentTableOfKindNoCheck(self, "EntitySpec")
	local specs = entity_spec:GetSpecSubitems(self.class, not "inherit", self) -- exclude self
	local name, j = old_name, 0
	while specs[name] do
		j = j + 1
		name = old_name .. tostring(j)
	end
	return name
end

function AssetSpec:OnAfterEditorNew(parent, ged, is_paste)
	self.name = self:FindUniqueName(self.name)
end

function AssetSpec:OnEditorSetProperty(prop_id, old_value, ged)
	local entity_spec = GetParentTableOfKindNoCheck(self, "EntitySpec")
	if prop_id == "name" then
		-- don't allow a duplicated name among the subobjects
		self.name = self:FindUniqueName(self.name)
		if self:IsKindOf("MeshSpec") then
			-- update references to the old name
			for _, spec in pairs(entity_spec:GetSpecSubitems("StateSpec", not "inherit")) do
				if spec.mesh == old_value then
					spec.mesh = self.name
				end
			end
		end	
	end
	entity_spec:SortSubItems()
	ObjModified(entity_spec)
end

function AssetSpec:GetError()
	if self.name == "" or self.name == "NONE" then
		return "Please specify asset name."
	end
	if not self.name:match("^[_#a-zA-Z0-9]*$") then
		return "The asset name has invalid characters."
	end
end

function AssetSpec:SetSaveIn(save_in)
	self.save_in = save_in ~= "" and save_in or nil
end

function AssetSpec:GetSaveIn()
	return self.save_in
end

DefineClass.MaskSpec = {
	__parents = { "AssetSpec" },
	
	properties = {
		-- stored in max script
		{ maxScript = true, id = "entity", editor = "text", no_edit = true, dont_save = true, default = "" },
	},

	TypeColor = RGB(175, 175, 0),
}

function MaskSpec:Less(other) -- compare to another MaskSpec
	if self.entity == other.entity then
		return self.name < other.name
	end
	return self.entity < other.entity
end

DefineClass.MeshSpec =  {
	__parents = { "AssetSpec" },
	
	properties = {
		-- stored in max script
		{ maxScript = true, id = "lod" , name = "LOD" , editor = "number", min = 0, default = 1 },
		{ maxScript = true, id = "animated" , name = "Animated" , editor = "bool",default = false },
		{ maxScript = true, id = "entity", editor = "text", no_edit = true, dont_save = true, default = "" },
		{ maxScript = true, id = "material" , name = "Material Variations", editor="text", default = "", help = "Specify material variations separated by commas. No spaces allowed in the variation's name!"},
		{ maxScript = true, id = "spots", name = "Required spots", editor = "text", default = "" },
		{ maxScript = true, id = "surfaces", name = "Required surfaces", editor = "text", default = "" },
		{ maxScript = true, toNumber = true, id = "maxTexturesSize", name = "Max textures size" , editor = "choice", default = "2048",
			items = { "2048", "1024", "512" }, 
		},
	},
	
	TypeColor = RGB(143, 0, 0),
}

function MeshSpec:GetMaterialsArray()
	local str_materials = string.gsub(self.material, " ", "")
	return string.tokenize(str_materials, ",")
end

function MeshSpec:Less(other) -- compare to another MeshSpec
	if self.entity == other.entity then
		if self.name == other.name then
			if self.lod == other.lod then
				return self.material < other.material
			end
			return self.lod < other.lod
		end
		return self.name < other.name
	end
	return self.entity < other.entity
end

DefineClass.StateSpec = {
	__parents = { "AssetSpec" },
	
	properties = {
		{ id = "category", name = "Category", editor = "choice", items = function() return ArtSpecConfig.ReturnAnimationCategories end, default = "All" },
		{ id = "SaveIn", name = "Save in", editor = "choice", default = "", items = function(obj) return obj:GetPresetSaveLocations() end, },
		{ maxScript = true, id = "entity", editor = "text", default = "", no_edit = true, dont_save = true },
		{ maxScript = true, id = "mesh", name = "Mesh", editor = "choice", 
			items = function(self)
				local entity_spec = GetParentTableOfKind(self, "EntitySpec")
				local meshes = entity_spec:GetSpecSubitems("MeshSpec", "inherit")
				return table.keys2(meshes, "sorted", "NONE")
			end, 
			default = "NONE"
		},
		{ maxScript = true, id = "animated", name = "Animated", editor = "bool", default = false ,read_only = true, dont_save = true,},
		{ maxScript = true, id = "looping", name = "Looping", editor = "bool", default = false },
		{ maxScript = true, id = "moments", name = "Required moments", editor="text", default = ""},
	},
	
	TypeColor = RGB(0, 143, 0),
}

function StateSpec:Getanimated()
	local entity_spec = GetParentTableOfKind(self, "EntitySpec")
	local mesh = entity_spec:GetMeshSpec(self.mesh)
	return mesh and mesh.animated
end

function StateSpec:Less(other) -- compare to another StateSpec
	if self.entity == other.entity then
		return self.name < other.name
	end
	return self.entity < other.entity
end

function StateSpec:GetError()
	if self.mesh == "" or self.mesh == "NONE" then
		return "Please specify mesh name."
	end
end

function StateSpec:GetPresetSaveLocations()
	return GetDefaultSaveLocations()
end

----- EntitySpec

local editor_artset_no_edit =      function(obj) return obj.editor_exclude end
local editor_category_no_edit =    function(obj) return obj.editor_exclude end
local editor_subcategory_no_edit = function(obj) return obj.editor_exclude or obj.editor_category == "" or not ArtSpecConfig[obj.editor_category.."Categories"] end

local statuses = {
	{ id = "Brief",                help = "The entity is named, and now concept and technical specs for it need to be prepared." },
	{ id = "Ready for production", help = "The brief is done, and work on the entity can start." },
	{ id = "In production",        help = "The entity is currently being produced in-house or via outsourcing, or has been delivered but not yet exported to the game." },
	{ id = "For approval",         help = "The entity is produced and exported to the game." },
	{ id = "Ready",                help = "The entity has been approved and can be used by level designers and programmers." },
}

local _FadeCategoryComboItems = false

function FadeCategoryComboItems() 
	if not _FadeCategoryComboItems then
		local items = {}
		for k,v in pairs(FadeCategories) do
			table.insert(items, { value = k, text = k, sort_key = v.min } )
		end
		table.sortby_field(items, "sort_key")
		_FadeCategoryComboItems = items
	end
	return _FadeCategoryComboItems
end

function GetArtSpecEditor()
	for id, ged in pairs(GedConnections) do
		if ged.app_template == EntitySpec.GedEditor then
			return ged
		end
	end
end

DefineClass.BasicEntitySpecProperties = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "class_parent", name = "Class", editor = "combo", items = PresetsPropCombo("EntitySpec", "class_parent", ""), default = "", category = "Misc", help = "Classes which this entity class should inherit (comma separated).", entitydata = true, }, 
		{ id = "fade_category", name = "Fade category" , editor = "choice", items = FadeCategoryComboItems, default = "Auto", category = "Misc", help = "How the entity should fade away when far from the camera.", entitydata = true,  },
		{ id = "DetailClass", name = "Detail class", editor = "dropdownlist", category = "Misc", items = {"Essential", "Optional", "Eye Candy"}, default = "Essential", entitydata = true, },
	},
}

function BasicEntitySpecProperties:ExportEntityDataForSelf()
	local entity = {}
	for _, prop_meta in ipairs(self:GetProperties()) do
		local prop_id = prop_meta.id
		if prop_meta.entitydata and not self:IsPropertyDefault(prop_id) then
			if type(prop_meta.entitydata) == "function" then
				entity[prop_id] = prop_meta.entitydata(prop_meta, self)
			else
				entity[prop_id] = self[prop_id]
			end
		end
	end
	return next(entity) and { entity = entity } or {}
end

DefineClass.EntitySpecProperties = {
	__parents = { "BasicEntitySpecProperties" },
	properties = {
		{ id = "can_be_inherited", name = "Can be inherited", editor = "bool", default = false, category = "Entity Specification"},
		{ id = "inherit_entity", name = "Inherit entity", editor = "preset_id", default = "", preset_class = "EntitySpec", category = "Entity Specification",
		  help = "Entity to inherit meshes/animations from; only entities with 'Can be inherited' checked are listed.",
		  preset_filter = function(preset, self) return preset.can_be_inherited end,
		},

		{ id = "material_type", name = "Material type", category = "Misc", editor = "preset_id", default = "", preset_class = "ObjMaterial", help = "Physical material of this entity.", entitydata = true, },
		{ id = "on_collision_with_camera", name = "On collision with camera" , editor = "choice", items = { "", "no action", "become transparent", "repulse camera" }, default = "", category = "Misc", help = "Behavior of this entity when colliding with the camera.", entitydata = true, no_edit = NoCameraCollision },
		{ id = "wind_axis", name = "Wind trunk stiffness" , editor = "number", default = 800, category = "Misc", scale = 1000, min = 100, max = 10000, slider = true, help = "Vertex noise needs to be set in the entity material to be affected by wind.", entitydata = true,  },
		{ id = "wind_radial", name = "Wind branch stiffness" , editor = "number", default = 1000, category = "Misc", scale = 1000, min = 500, max = 10000, slider = true, help = "Vertex noise needs to be set in the entity material to be affected by wind.", entitydata = true,  },
		{ id = "wind_modifier_strength", name = "Wind modifier strength" , editor = "number", default = 1000, category = "Misc", scale = 1000, min = 100, max = 10000, slider = true, help = "Vertex noise needs to be set in the entity material to be affected by wind.", entitydata = true, },
		{ id = "wind_modifier_mask", name = "Wind modifier mask" , editor = "choice", default = 0, category = "Misc", items = const.WindModifierMaskComboItems, help = "Vertex noise needs to be set in the entity material to be affected by wind.", entitydata = true, },
		
		{ id = "winds", editor = "buttons", default = false, category = "Misc", buttons = {
			{ name = "Stop wind", func = function() terrain.SetWindStrength(point20, 0) end },
			{ name = "N", func = function() terrain.SetWindStrength(axis_x, 2048) end },
			{ name = "N (strong)", func = function() terrain.SetWindStrength(axis_x, 4096) end },
			{ name = "E", func = function() terrain.SetWindStrength(axis_y, 2048) end },
			{ name = "E (strong)", func = function() terrain.SetWindStrength(axis_y, 4096) end },
			{ name = "S", func = function() terrain.SetWindStrength(-axis_x, 2048) end },
			{ name = "S (strong)", func = function() terrain.SetWindStrength(-axis_x, 4096) end },
			{ name = "W", func = function() terrain.SetWindStrength(-axis_y, 2048) end },
			{ name = "W (strong)", func = function() terrain.SetWindStrength(-axis_y, 4096) end }, },
		},
		{ id = "DisableCanvasWindBlending", name = "Disable canvas wind blending", category = "Misc", 
			default = false, editor = "bool", no_edit = function(self)
				if not rawget(g_Classes, "Canvas") then return true end
				
				local is_canvas = false
				for class in string.gmatch(self.class_parent, '([^,]+)') do
					if IsKindOf(g_Classes[class], "Canvas") then
						is_canvas = true
						break
					end
				end	
				
				return not is_canvas
			end,
			entitydata = true,
		},
		
		{ category = "Defaults", id = "anim_components", name = "Anim components",
			editor = "nested_list", default = false, base_class = "AnimComponentWeight", inclusive = true, auto_expand = true, },
	},
}

function EntitySpecProperties:ExportEntityDataForSelf()
	local data = BasicEntitySpecProperties.ExportEntityDataForSelf(self)
	
	if self.anim_components and next(self.anim_components) then
		data.anim_components = table.map(self.anim_components, function(ac)
			local err, t = LuaCodeToTuple(TableToLuaCode(ac))
			assert(not err)
			return t
		end)
	end
	
	return data
end

DefineClass.EntitySpec = {
	__parents = { "Preset", "EntitySpecProperties" },

	properties = {
		{ id = "produced_by", name = "Produced By" , editor = "combo", default = "HaemimontGames", items = function() return ArtSpecConfig.EntityProducers end, category = "Entity Specification" },
		{ id = "status", name = "Production status", editor = "choice", default = statuses[1].id, items = statuses, category = "Entity Specification" },
		{ id = "placeholder", name = "Allow placeholder use", editor = "bool", default = false, category = "Entity Specification" },
		{ id = "estimate", name = "Estimate (days)", editor = "number", default = 1, category = "Entity Specification" },
		{ id = "LastChange", name = "Last change", editor = "text", default = "", translate = false, read_only = true, category = "Entity Specification" },
		-- { id = "inherit_mesh", name = "Inherit mesh", editor = "text", default = "mesh", category = "Entity Specification" },
		
		-- Tags
		{ id = "editor_exclude", name = "Exclude from Map Editor", editor = "bool", default = false, category = "Map Editor" },
		{ id = "editor_artset", name = "Art set", editor = "text_picker", no_edit = editor_category_no_edit,
		  items = function() return ArtSpecConfig.ArtSets end, horizontal = true, name_on_top = true, default = "", category = "Map Editor",
		},
		{ id = "editor_category", name = "Category", editor = "text_picker", no_edit = editor_category_no_edit,
		  items = function() return ArtSpecConfig.Categories end, horizontal = true, name_on_top = true, default = "", category = "Map Editor",
		},
		{ id = "editor_subcategory", name = "Subcategory", editor = "text_picker", horizontal = true, name_on_top = true, default = "", category = "Map Editor",
		  items = function(obj) return ArtSpecConfig[obj.editor_category.."Categories"] or empty_table end, no_edit = editor_subcategory_no_edit,
		},
		
		-- Misc
		{ id = "HasBillboard", name = "Billboard" , editor = "bool", default = false, category = "Misc", read_only = true, buttons = {{ name = "Rebake", func = "ActionRebake" }} },
		
		-- stored in max script
		{ maxScript = true, id = "name", name = "Name", editor = false, default = "NONE", read_only = true, dont_save = true, },
		{ maxScript = true, id = "unique_id", name = "UniqueID", editor = "number", default = -1, read_only = true, dont_save = true },
		{ maxScript = true, id = "exportableToSVN", name = "Exportable to SVN", editor = "bool", default = true, category = "Entity Specification" },
		
		{ id = "Tools", editor = "buttons", default = false, category = "Entity Specification", buttons = {
			{ name = "List Files",   func = "ListEntityFilesButton"   },
			{ name = "Delete Files", func = "DeleteEntityFilesButton" }, },
		},
	},
	
	last_change_time = false,
	
	ContainerClass = "AssetSpec",
	GlobalMap = "EntitySpecPresets",
	GedEditor = "GedArtSpecEditor",
	EditorMenubarName = "Art Spec",
	EditorShortcut = "Ctrl-Alt-A",
	EditorMenubar = "Editors.Art",
	EditorIcon = "CommonAssets/UI/Icons/colour creativity palette.png",
	FilterClass = "EntitySpecFilter",
	PresetIdRegex = "^" .. EntityValidCharacters .. "*$",
}

function EntitySpec:ExportEntityDataForSelf()
	local data = EntitySpecProperties.ExportEntityDataForSelf(self)
	
	if not self.editor_exclude then
		data.editor_artset = self.editor_artset ~= "" and self.editor_artset or nil
		data.editor_category = self.editor_category ~= "" and self.editor_category or nil
		data.editor_subcategory = self.editor_subcategory ~= "" and self.editor_subcategory or nil
	end
	if self.default_colors then
		data.default_colors = {}
		SetColorizationNoSetter(data.default_colors, self.default_colors)
	end
	
	return data
end

function EntitySpec:GetHasBillboard()
	return table.find(hr.BillboardEntities, self.id)
end

function EntitySpec:ActionRebake()
	if table.find(hr.BillboardEntities, self.id) then
		BakeEntityBillboard(self.id)
	end
end

function EntitySpec:Getunique_id()
	return EntityIDs and EntityIDs[self.id] or -1
end

function EntitySpec:Setunique_id()
	assert(false)
end

function EntitySpec:GetEditorViewPresetPrefix()
	g_AllEntities = g_AllEntities or GetAllEntities()
	return g_AllEntities[self.id] and "<color 0 128 0>" or self.exportableToSVN and "" or "<color 128 0 0>"
end

function EntitySpec:GetSaveFolder(save_in)
	save_in = save_in or self.save_in
	if save_in == "Common" then
		return string.format("CommonAssets/Spec/")
	else
		return string.format("svnAssets/Spec/")
	end
end

function OnMsg.ClassesBuilt()
	if not next(Presets.EntitySpec) and Platform.developer then
		for idx, file in ipairs(io.listfiles("CommonAssets/Spec", "*.lua")) do
			LoadPresets(file)
		end
		for idx, file in ipairs(io.listfiles("svnAssets/Spec", "*.lua")) do
			LoadPresets(file)
		end
	end
end

function EntitySpec:GenerateUniquePresetId(name)
	local id = name or self.id
	if not EntitySpecPresets[id] then
		return id
	end
	
	local new_id
	local n = 0
	local id1, n1 = id:match("(.*)_(%d+)$")
	if id1 and n1 then
		id, n = id1, tonumber(n1)
	end
	repeat
		n = n + 1
		new_id = string.format("%s_%02d", id, n)
	until not EntitySpecPresets[new_id]
	return new_id
end

function EntitySpec:GetSavePath(save_in, group)
	save_in = save_in or self.save_in or ""

	local folder = self:GetSaveFolder(save_in)
	if not folder then return end
	if save_in == "" then save_in = "base" end
	return string.format("%sArtSpec-%s.lua", folder, save_in)
end

function EntitySpec:GetLastChange()
	return self.last_change_time and os.date("%Y-%m-%d %a", self.last_change_time) or ""
end

function EntitySpec:GetCreationTime() -- the time is was marked as Ready in the art spec
	return self.status == "Ready" and self.last_change_time
end

function EntitySpec:GetModificationTime() -- the latest modification time as per the file system
	self:EditorData().entity_files = self:EditorData().entity_files or GetEntityFiles(self.id)
	local max = 0
	for _, file_name in ipairs(self:EditorData().entity_files) do
		max = Max(max, GetAssetFileModificationTime(file_name))
	end
	return max
end

function EntitySpec:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "SaveIn" then
		-- reset IDs when switching between project and common
		if old_value == "Common" or self.save_in == "Common" then
			local old_id = PreviousEntityIDs and PreviousEntityIDs[self.id] or nil
			if old_id and self.save_in == "Common" and old_id < CommonAssetFirstID then old_id = nil end
			if not next(PreviousEntityIDs) then PreviousEntityIDs = {} end
			PreviousEntityIDs[self.id] = EntityIDs[self.id]
			EntityIDs[self.id] = old_id
		end
	elseif prop_id == "status" then
		self.last_change_time = os.time(os.date("!*t"))
	elseif prop_id == "editor_exclude" then
		self.editor_artset = nil
		self.editor_category = nil
		self.editor_subcategory = nil
	elseif prop_id == "editor_category" then
		self.editor_subcategory = nil
	elseif prop_id == "wind_axis" or prop_id == "wind_radial" or prop_id == "wind_modifier_strength" or prop_id == "wind_modifier_mask" then
		local axis, radial, strength, mask = GetEntityWindParams(self.id)
		SetEntityWindParams(self.id, -1, self.wind_axis or axis, self.wind_radial or radial, self.wind_modifier_strength or strength, self.wind_modifier_mask or mask)
		DelayedCall(300, RecreateRenderObjects)
	elseif prop_id == "debris_list" then
		local list_item = Presets.DebrisList.Default[self.debris_list]
		if list_item then
			local classes_weights = list_item.debris_list
			self.debris_classes = {}
			for _, entry in ipairs(classes_weights) do
				local class_weight = DebrisWeight:new{DebrisClass = entry.DebrisClass, Weight = entry.Weight}
				table.insert(self.debris_classes, class_weight)
			end
		else
			self.debris_classes = false
		end
		GedObjectModified(self.debris_classes)
		GedObjectModified(self)
	elseif prop_id == "debris_classes" then
		if not self.debris_classes or #self.debris_classes == 0 then
			self.debris_list = ""
			self.debris_classes = false
		end
	end
	self:EditorData().entity_files = nil
end

function EntitySpec:SortSubItems()
	table.sort(self, function(a, b) if a.class == b.class then return a:Less(b) else return a.class < b.class end end)
end

function EntitySpec:PostLoad()
	SetEntityWindParams(self.id, -1, self.wind_axis, self.wind_radial, self.wind_modifier_strength, self.wind_modifier_mask)
	self:SortSubItems()
	Preset.PostLoad(self)
end

function EntitySpec:GetError()
	local has_mesh, has_state
	for _, asset_spec in ipairs(self) do
		has_mesh = has_mesh or asset_spec.class == "MeshSpec"
		has_state = has_state or asset_spec.class == "StateSpec"
	end
	if not has_mesh then
		return "Entity should have a MeshSpec"
	elseif not has_state then
		return "Entity should have a StateSpec"
	end
	
	if (self.editor_artset == "" or not table.find(ArtSpecConfig.ArtSets, self.editor_artset)) and not editor_artset_no_edit(self) then
		return "Please specify art set."
	elseif (self.editor_category == "" or not table.find(ArtSpecConfig.Categories, self.editor_category)) and not editor_category_no_edit(self) then
		return "Please specify entity category."
	elseif (self.editor_subcategory == "" or ArtSpecConfig[self.editor_category .. "Categories"] and not table.find(ArtSpecConfig[self.editor_category .. "Categories"], self.editor_subcategory)) and not editor_subcategory_no_edit(self) then
		return "Please specify entity subcategory."
	end
	
	if self.editor_category == "Decal" and not string.find(self.class_parent, "Decal", 1, true) then
		return "This entity is in the Decal category, but does not inherit the Decal class."
	end
end

function EntitySpec:Getname()
	return self.id
end

function EntitySpec:GetMeshSpec(meshName)
	for _, spec in ipairs(self) do
		if spec:IsKindOf("MeshSpec") and spec.name == meshName then
			return spec
		end
	end
	return false
end

function EntitySpec:OnEditorSelect(selected, ged)
	OnArtSpecSelectObject(self, selected)
end

function EntitySpec:ReserveEntityIDs()
	ForEachPreset(EntitySpec, function(ent_spec)
		local name = ent_spec.id
		if not EntityIDs[name] then
			if ent_spec.save_in == "Common" then
				ReserveCommonEntityID(name)
			else
				ReserveEntityID(name)
			end
		end
	end)
	if not LastEntityID then
		LastEntityID = GetUnusedEntityID() - 1
	end
end

function EntitySpec:GetSpecSubitems(spec_type, inherit, exclude)
	-- go up the entity spec hierarchy to get inherited states and meshes
	local t, es = {}, self
	while es do
		for _, spec in ipairs(es) do
			if spec.class == spec_type and (not exclude or spec ~= exclude) then
				t[spec.name] = t[spec.name] or spec
			end
		end
		if not inherit then break end
		es = EntitySpecPresets[es.inherit_entity]
	end
	return t
end

function EntitySpec:SaveSpec(specs_class, filter, fn)
	local res = {}
	ForEachPreset(EntitySpec, function(ent_spec)
		if filter and not filter(ent_spec) then return end
		fn(ent_spec.id, ent_spec, res, ent_spec:GetSpecSubitems(specs_class, not "inherit"))
	end)
	table.sort(res)
	return string.format("#(\n\t%s\n)\n", table.concat(res, ",\n\t"))
end

function EntitySpec:SaveEntitySpec(filter)
	return self:SaveSpec(nil, filter, function(name, es, res)
		local id = EntityIDs[name] or -1
		assert(id > 0, "Entities without ids present at ArtSpec save! Please call a developer!")
		res[#res + 1] = string.format('(EntitySpec name:"%s" id:%d exportableToSVN:%s)',
			name,
			id,
			tostring(es.exportableToSVN))
	end)
end

function EntitySpec:SaveMeshSpec(res, filter)
	return self:SaveSpec("MeshSpec", filter, function(name, es, res, meshes)
		for _, mesh in pairs(meshes) do
			local materials = mesh:GetMaterialsArray()
			for lod = 1, mesh.lod do
				for m = 1, Max(#materials, 1) do
					local mat = materials[m] and string.format('material:"%s" ', materials[m]) or ""
					local spots = mesh.spots == "" and "" or string.format('spots:"%s" ', mesh.spots)
					local surfaces = mesh.surfaces == "" and "" or string.format('surfaces:"%s" ', mesh.surfaces)
					res[#res + 1] = string.format('(MeshSpec entity:"%s" name:"%s" lod:%d animated:%s %s%s%smaxTexturesSize:%d)',
						name,
						mesh.name,
						lod,
						tostring(mesh.animated),
						mat,
						spots,
						surfaces,
						mesh.maxTexturesSize)
				end
			end
		end
	end)
end

function EntitySpec:SaveMaskSpec(filter)
	return self:SaveSpec("MaskSpec", filter, function(name, es, res, masks)
		for _, mask in pairs(masks) do
			res[#res + 1] = string.format('(MaskSpec entity:"%s" name:"%s")',
				name,
				mask.name)
		end
	end)
end


function EntitySpec:SaveStateSpec(filter)
	return self:SaveSpec("StateSpec", filter, function(name, es, res, states)
		for _, state in pairs(states) do
			local mesh = es:GetMeshSpec(state.mesh)
			res[#res + 1] = string.format('(StateSpec entity:"%s" name:"%s" mesh:"%s" animated:%s looping:%s)',
				name,
				state.name,
				mesh.name,
				tostring(mesh.animated or false),
				tostring(state.looping))
		end
	end)
end

function EntitySpec:SaveInheritanceSpec(filter)
	return self:SaveSpec(nil, filter, function(name, es, res)
		if es.inherit_entity ~= "" and es.inherit_entity ~= es.name then
			res[#res + 1] = string.format('(InheritSpec entity:"%s" inherit:"%s" mesh:"%s")', 
				name, 
				es.inherit_entity, 
				"mesh") -- was es.inherit_mesh, this property was unused and removed
		end
	end)
end

function EntitySpec:ExportMaxScript(folder, file_suffix, filter)
	local filename
	if file_suffix then
		filename = string.format("%s/Spec/ArtSpec.%s.ms", folder, file_suffix)
	else
		filename = string.format("%s/Spec/ArtSpec.ms", folder)
	end
	local f,error_msg = io.open(filename, "w+")
	
	if f then
		f:write( "struct StateSpec(entity, name, mesh, looping, animated, moments, compensation)\n" )
		f:write( "struct InheritSpec(entity, inherit, mesh)\n" )
		f:write( "struct MeshSpec(entity, name, lod, animated, spots, surfaces, decal, hgShader, dontCompressVerts, maxVerts, maxTris, maxBones, material, sortKey, maxTexturesSize)\n" )
		f:write( "struct EntitySpec(name, id, exportableToSVN)\n" )
		f:write( "struct MaskSpec(entity, name)\n" )
		f:write( "g_maxProjectBoneCount = " .. ArtSpecConfig.maxProjectBoneCount .. "\n" )
		f:write( "g_Platforms = " .. ArtSpecConfig.platforms .. "\n" )
		f:write( "g_EntitySpec = " .. self:SaveEntitySpec(filter) )
		f:write( "g_MeshSpec = " .. self:SaveMeshSpec(nil, filter) )
		f:write( "g_StateSpec = " .. self:SaveStateSpec(filter) )
		f:write( "g_InheritSpec = " .. self:SaveInheritanceSpec(filter) )
		f:write( "g_MaskSpec = " .. self:SaveMaskSpec(filter) )
		f:write("\n")
		f:close()
		
		print( "Wrote " .. filename )
		SVNAddFile(filename)
		return true
	else
		print("ERROR: [Save] Could not save " .. filename .. " - " .. error_msg)
		return false
	end
end

function EntitySpec:ExportDlcLists()
	local old = io.listfiles("svnAssets/Spec/", "*.*list")
	if next(old) then
		local err = AsyncFileDelete(old)
		assert(not err, err)
	end

	local by_dlc = {}
	ForEachPreset(EntitySpec, function(entity_data)
		local states = entity_data:GetSpecSubitems("StateSpec", not "inherit")
		local entity_key = entity_data.save_in
		
		local mesh_names = {}
		for mesh_name, mesh_spec in pairs(entity_data:GetSpecSubitems("MeshSpec")) do
			for i=1,mesh_spec.lod do
				mesh_names[#mesh_names+1] = mesh_name .. (( i == 1 ) and "" or ("." .. tonumber(i-1)))
			end
		end

		for _, state in sorted_pairs(states) do
			local state_key = (state.save_in == "") and entity_key or state.save_in
			if state_key ~= "Common" then
				local file = (state_key == "") and "$(file)" or "Animations/$(file)"
				state_key = state_key .. ".statelist"
				local list = by_dlc[state_key] or { "return {\n" }
				by_dlc[state_key] = list
				list[#list + 1] = string.format("\t['$(assets)/Bin/Common/Animations/%s_%s.hgacl'] = '%s',\n", entity_data:Getname(), state.name, file)
			end
		end

		if entity_key == "Common" then return end
		local file = (entity_key == "") and "$(file)" or "Meshes/$(file)"
		entity_key = entity_key .. ".meshlist"
		local list = by_dlc[entity_key] or { "return {\n" }
		by_dlc[entity_key] = list
		
		local sorted_list = {}
		for _, mesh_name in ipairs(mesh_names) do
			sorted_list[#sorted_list + 1] = string.format("\t['$(assets)/Bin/Common/Meshes/%s_%s.hgm'] = '%s',\n", entity_data:Getname(), mesh_name, file)
		end
		table.sort(sorted_list)
		table.iappend(list, sorted_list)
		
		while entity_data do
			if entity_data.inherit_entity ~= "" then
				local sorted_list =  {}
				for _, mesh_name in ipairs(mesh_names) do
					sorted_list[#sorted_list + 1] = string.format("\t['$(assets)/Bin/Common/Meshes/%s_%s.hgm'] = '%s',\n", entity_data.inherit_entity, mesh_name, file)
				end
				table.sort(sorted_list)
				table.iappend(list, sorted_list)
			end
			entity_data = EntitySpecPresets[entity_data.inherit_entity]
		end
	end)

	local files_to_save = {}
	for save_in, files in pairs(by_dlc) do
		files = table.get_unique(files)
		files[#files + 1] = "}\n"
		local filename = "svnAssets/Spec/" .. save_in
		AsyncStringToFile(filename, files)
		table.insert(files_to_save, filename)
	end
	SVNAddFile(files_to_save)
	return true
end

function EntitySpec:ExportEntityProducers()
	local map = { }
	ForEachPreset("EntitySpec", function(preset, group, filters)
		if preset.save_in == "Common" then return end
		map[preset.id] = preset.produced_by
	end)
	local content = ValueToLuaCode(map, nil, pstr("return ", 256*1024))
	local path = "svnAssets/Spec/EntityProducers.lua"
	AsyncStringToFile(path, content)
	SVNAddFile(path)
	return true
end

function EntitySpec:ExportEntityData()
	local entities_by_dlc = {
		["Common"] = pstr("EntityData = {}\nif Platform.ged then return end\n"),
		[""] = pstr("if Platform.ged then return end\n")
	}
	
	ForEachPreset(EntitySpec, function(es)
		local entity_data = es:ExportEntityDataForSelf()
		if next(entity_data) then
			local save_in = es.save_in or ""
			entities_by_dlc[save_in] = entities_by_dlc[save_in] or pstr("")
			local dlc_pstr = entities_by_dlc[save_in]
			dlc_pstr:append("EntityData[\"", es.id, "\"] = ")
			dlc_pstr:appendt(entity_data)
			dlc_pstr:append("\n")
		end
	end)
	
	for dlc, data in pairs(entities_by_dlc) do
		local path
		if dlc == "Common" then
			path = "CommonLua/_EntityData.generated.lua"
		elseif dlc ~= "" then
			path = string.format("svnProject/Dlc/%s/Code/_EntityData.generated.lua", dlc)
		else
			path = "Lua/_EntityData.generated.lua"
		end
		if #data > 0 then
			local err = SaveSVNFile(path, data)
			if err then return not err end
		else
			SVNDeleteFile(path)
		end
	end
	return true
end

function EntitySpec:SaveAll(...)
	self:SortPresets()
	
	self:ReserveEntityIDs()	
	local SaveFailed = function()
		print("Export failed")
	end
	
	local default_filter = function(es) return es.save_in ~= "Common" end
	if not self:ExportMaxScript("svnAssets", nil, default_filter) then SaveFailed() return end --combined file
	for i,produced_by in ipairs(ArtSpecConfig.EntityProducers) do
		-- separate file per art producer
		local producer_filter = function(es) return es.produced_by == produced_by and es.save_in ~= "Common" end
		if not self:ExportMaxScript("svnAssets", produced_by, producer_filter) then SaveFailed() return end
	end
	if not self:ExportEntityData() then SaveFailed() return end
	if not self:ExportDlcLists() then SaveFailed() return end
	if not self:ExportEntityProducers() then SaveFailed() return end
	
	local common_filter = function(es) return es.save_in == "Common" end
	if not self:ExportMaxScript("CommonAssets", nil, common_filter) then SaveFailed() return end
	
	-- force saving ArtSpec-base.lua every time
	local base_file_path = "svnAssets/Spec/ArtSpec-base.lua"
	local prev_dirty_status = g_PresetDirtySavePaths[base_file_path]
	g_PresetDirtySavePaths[base_file_path] = "EntitySpec"
	
	Preset.SaveAll(self, ...)
	
	g_PresetDirtySavePaths[base_file_path] = prev_dirty_status
end

function EntitySpec:OnEditorNew(parent, ged, is_paste)
	if not is_paste then
		self[1] = MeshSpec:new{ name = "mesh" }
		self[2] = StateSpec:new{ name = "idle", mesh = "mesh" }
	end
	
	local _, _, base_name, suffix = self.id:find("(.*)_(%d%d)$")
	if suffix == "01" and EntitySpecPresets[base_name] then
		self:SetId(self:GenerateUniquePresetId(base_name .. "_02"))
	end
	self.last_change_time = os.time(os.date("!*t"))
end

function EntitySpec:OnEditorDelete(parent, ged)
	EntityIDs[self.id] = nil
	self:DeleteEntityFiles()
end

function EntitySpec:EditorContext()
	local context = Preset.EditorContext(self)
	table.remove_value(context.classes, "AssetSpec")
	return context
end

function EntitySpec:GetAnimRevision(entity, anim)
	if not IsValidEntity(entity) or not HasState(entity, anim) then return 0 end
	return GetAssetFileRevision("Animations/" .. GetEntityAnimName(entity, anim))
end

function EntitySpec:GetEntityFiles(entity)
	entity = entity or self.id
	local ef_list = GetEntityFiles(entity)
	local existing, non_existing = {}, {}
	for _, ef in ipairs(ef_list) do
		table.insert(io.exists(ef) and existing or non_existing, ef)
	end
	return existing, non_existing
end

function EntitySpec:ListEntityFilesButton(root, prop_id, ged)
	local entity = self.id
	local status = not IsValidEntity(entity) and "-> Invalid!" or ""
	local existing, non_existing = self:GetEntityFiles(entity)
	existing = table.map(existing, ConvertToOSPath)
	non_existing = table.map(non_existing, ConvertToOSPath)
	
	local output = {}
	table.sort(existing)
	table.iappend(output, existing)
	if #non_existing > 0 then
		output[#output + 1] = "\nMissing, but referenced and/or mandatory files:"
		table.sort(non_existing)
		table.iappend(output, non_existing)
	end
	output[#output + 1] = string.format("\nTotal files: %d present and %d non-existent", #existing, #non_existing)
	ged:ShowMessage(string.format("Files for entity: '%s' %s", entity, status), table.concat(output, "\n"))
end

function EntitySpec:DeleteEntityFilesButton(root, prop_id, ged)
	local result = ged:WaitQuestion("Confirm Deletion", "Delete all exported files for this entity?", "Yes", "No")
	if result ~= "ok" then
		return
	end
	CreateRealTimeThread(EntitySpec.DeleteEntityFiles, self)
end

function EntitySpec:DeleteEntityFiles(id)
	id = id or self.id
	print(string.format("Deleting '%s' entity files...", id))
	
	local f_existing = self:GetEntityFiles(id)
	SVNDeleteFile(f_existing)
	print("Done")
end

function GedOpCleanupObsoleteAssets(ged, target, type)
	if type == "mappings" then
		CreateRealTimeThread(CleanupObsoleteMappingFiles)
	else
		CreateRealTimeThread(EntitySpec.CleanupObsoleteAssets, EntitySpec, ged)
	end
end

if FirstLoad then
	CheckEntityUsageThread = false
end

function CheckEntityUsage(ged, obj, selection)
	DeleteThread(CheckEntityUsageThread)
	CheckEntityUsageThread = CreateRealTimeThread(function()
		obj = obj or {}
		selection = selection or {}
		local art_specs = obj[selection[1][1]] or {}
		local selected_specs = selection[2] or {}
		local entities = {}
		for i, idx in ipairs(selected_specs) do
			entities[i] = art_specs[idx].id
		end
		if #entities == 0 then
			entities = table.keys(g_AllEntities or GetAllEntities())
		end
		local all_files = {}
		local function AddSourceFiles(path)
			local err, files = AsyncListFiles(path, "*.lua", "recursive")
			if not err then
				table.iappend(all_files, files)
			end
		end
		AddSourceFiles("CommonLua")
		AddSourceFiles("Lua")
		AddSourceFiles("Data")
		AddSourceFiles("Dlc")
		AddSourceFiles("Maps")
		AddSourceFiles("Tools")
		AddSourceFiles("svnAssets/Spec")
		AddSourceFiles("CommonAssets/Spec")
		if #entities == 1 then
			print("Search for entity", entities[1], "in", #all_files, "files...")
		elseif #entities < 4 then
			print("Search for entities", table.concat(entities, ", "), "in", #all_files, "files...")
		else
			print("Search", #entities, "entities in", #all_files, "files...")
		end
		Sleep(1)
		local string_to_files = SearchStringsInFiles(entities, all_files)
		local filename = "AppData/EntityUsage.txt"
		local err = AsyncStringToFile(filename, TableToLuaCode(string_to_files))
		if err then
			print("Failed to save report:", err)
			return
		end
		print("Report saved to:", ConvertToOSPath(filename))
		OpenTextFileWithEditorOfChoice(filename)
	end)
end

function CollectAllReferencedAssets()
	local existing_assets = {}
	local non_ref_entities = {}
	g_AllEntities = g_AllEntities or GetAllEntities()
	-- collecting all used assets 
	for entity_name in pairs(g_AllEntities) do
		local entity_specs = GetEntitySpec(entity_name, "expect_missing") 
		if entity_specs then
			local existing = EntitySpec:GetEntityFiles(entity_name)
			for _, asset in ipairs(existing) do 
				local folder = asset:match("(Materials)/") or asset:match("(Animations)/") or asset:match("(Meshes)/") or asset:match("(Textures.*)/")
				if folder then 
					existing_assets[folder] = existing_assets[folder] or {}
					local asset_name = asset:match(folder.."/(.*)")
					local ref_folder = existing_assets[folder]
					ref_folder[asset_name] = "exists"
				end
			end
		else
			non_ref_entities[#non_ref_entities + 1] = entity_name
		end
	end

	return existing_assets, non_ref_entities
end

function CleanupObsoleteMappingFiles(existing_assets)
	if not CanYield() then
		CreateRealTimeThread(CleanupObsoleteMappingFiles, existing_assets)
		return
	end
	if not existing_assets then
		existing_assets = CollectAllReferencedAssets()
	end
	-- drop extensions
	local referenced_textures = {}
	for asset_name in pairs(existing_assets.Textures) do
		local texture_path = string.match(asset_name, "(.+)%.dds$")
		if texture_path then
			referenced_textures[texture_path] = true
		end
	end

	local err, files = AsyncListFiles("Mapping/", "*.json", "")
	if err then
		printf("Loading of texture remapping files failed: %s", err)
		return
	end
	local files_removed = 0
	local texture_refs_removed = 0
	parallel_foreach(files, function(file)
		file = ConvertToOSPath(file)
		local err, content = AsyncFileToString(file)
		if err then
			printf("Loading of texture mapping file %s failed: %s", file, err)
			return
		end
		local err, obj = JSONToLua(content)
		if err then
			printf("Loading of texture mapipng file %s failed : %s", file, err)
			return
		end

		local path, name, ext = SplitPath(file)
		local entity_id = EntityIDs[name] and tostring(EntityIDs[name])
	
		local ids = table.keys(obj)
		for _, id in ipairs(ids) do
			if not referenced_textures[id] or 
				(entity_id and not string.starts_with(id, entity_id)) then
				obj[id] = nil
				texture_refs_removed = texture_refs_removed + 1
			end
		end

		if not next(obj) then
			local err = AsyncFileDelete(file)
			if err then print("Failed to delete file", file, err) end
			files_removed = files_removed + 1
		else
			local err, json = LuaToJSON(obj, { pretty = true, sort_keys = true, })
			if err then
				printf("Failed to serialize json.")
				return
			end
			local err = AsyncStringToFile(file, json)
			if err then print("Failed to write file", file, err) end
		end
	end)
	print("CleanupObsoleteMappingFiles - removed " .. files_removed .. " mapping files and " .. texture_refs_removed .. " texture references")
end

function EntitySpec:CleanupObsoleteAssets(ged)
	local result = ged:WaitQuestion("Confirm Deletion", "Cleanup all unreferenced art assets from entitites?", "Yes", "No")
	if result ~= "ok" then return end
	
	local existing_assets, non_ref_entities = CollectAllReferencedAssets()

	-- delete all non existent entities
	for _, name in ipairs(non_ref_entities) do
		EntitySpec:DeleteEntityFiles(name)
	end
	-- checking folders and deleting non used assets
	local assets = {
		"Materials", 
		"Animations",
		"Meshes", 
		"Textures",
	}
	
	local to_delete = {}
	for _, asset_type in ipairs(assets) do 
		local assets_list = {}
		local entity_assets = existing_assets[asset_type]
		if asset_type == "Textures" then
			local texture_ids = {}
			for asset,_ in pairs(entity_assets) do
				local id = asset:match("(.*).dds")
				texture_ids[id] = "exists"
			end
			table.iappend(assets_list, io.listfiles("svnAssets/Bin/win32/Textures", "*.dds", "non recursive"))
			table.iappend(assets_list, io.listfiles("svnAssets/Bin/win32/Fallbacks/Textures", "*.dds", "non recursive"))
			table.iappend(assets_list, io.listfiles("svnAssets/Bin/Common/TexturesMeta", "*.lua", "non recursive"))
			
			for _, asset in ipairs(assets_list) do 
				local asset_id = asset:match("Textures.*/(%d*)")
				if not texture_ids[asset_id] then 
					table.insert(to_delete, asset)
				end		
			end		
		else
			assets_list = io.listfiles("svnAssets/Bin/Common/" ..asset_type)
			for _, asset in ipairs(assets_list) do 
				local asset_name = asset:match(asset_type..".*/(.*)$")
				if not entity_assets[asset_name] then 
					table.insert(to_delete, asset)
				end		
			end		
		end
	end
	print(string.format("Deleted assets count: %d", #to_delete))
	SVNDeleteFile(to_delete)
	print("done")
end

function GedOpDeleteEntitySpecs(ged, presets, selection)
	local res = ged:WaitQuestion("Confirm Deletion", "Delete the selected entity specs and all exported files?", "Yes", "No")
	if res ~= "ok" then return end
	return GedOpPresetDelete(ged, presets, selection)
end

function GetEntitySpec(entity, expect_missing)
	g_AllEntities = g_AllEntities or GetAllEntities()
	if not g_AllEntities[entity] then
		assert(expect_missing, string.format("No such entity '%s'!", entity))
		return false
	end
	local spec = EntitySpecPresets[entity]
	assert(spec or expect_missing, string.format("Entity '%s' not found in ArtSpec!", entity))
	return spec
end

function GetStatesFromCategory(entity, category, walked_entities)
	if not category or category == "All" then
		return GetStates(entity)
	end
	walked_entities = walked_entities or {}
	if not walked_entities[entity] then
		walked_entities[entity] = true
	else
		return {}
	end
	if not table.find(ArtSpecConfig.ReturnAnimationCategories, category) then
		assert(false, string.format("No such animation category - '%s'!", category))
		return GetStates(entity)
	end
	local entity_spec = EntitySpecPresets[entity] or GetEntitySpec(entity)
	if not entity_spec then return {} end
	local states = {}
	if entity_spec.inherit_entity ~= "" then
		local inherited_states = GetStatesFromCategory(entity_spec.inherit_entity, category, walked_entities)
		for i = 1, #inherited_states do
			if not table.find(states, inherited_states[i]) then
				states[#states + 1] = inherited_states[i]
			end
		end
	end
	for i = 1, #entity_spec do
		local spec = entity_spec[i]
		if spec.class == "StateSpec" and spec.category == category then
			if not table.find(states, spec.name) then
				states[#states + 1] = spec.name
			end
		end
	end
	return states
end

function GetStatesFromCategoryCombo(entity, category, ignore_underscore, ignore_error_states)
	local IsErrorState, GetStateIdx = IsErrorState, GetStateIdx
	local states = {}
	for _, state in ipairs(GetStatesFromCategory(entity, category)) do
		local is_error_state = IsErrorState(entity, GetStateIdx(state))
		if (not ignore_underscore or not state:starts_with("_")) 
			and (not ignore_error_states or not is_error_state)
		then
			if is_error_state then
				states[#states + 1] = state .. " *"
			else
				states[#states + 1] = state
			end
		end
	end
	table.sort(states)
	return states
end

if FirstLoad then
	EntityIDs = false
	PreviousEntityIDs = false
	LastEntityID = false
	LastCommonEntityID = false
end

function EntitySpec:GetSaveData(file_path, preset_list, ...)
	local code = Preset.GetSaveData(self, file_path, preset_list, ...)
	local save_in = preset_list[1] and preset_list[1].save_in
	local initializedIDsObject = false
	if save_in == "Common" then
		code:appendf("\nLastCommonEntityID = %d\n", LastCommonEntityID)
		for name, id in sorted_pairs(EntityIDs) do
			if id >= CommonAssetFirstID then
				if not initializedIDsObject then
					code:append("if not next(EntityIDs) then EntityIDs = {} end \n")
					initializedIDsObject = true
				end
				code:appendf("EntityIDs[\"%s\"] = %d\n", name, id)
			end
		end
	elseif save_in == "" then
		code:appendf("\nLastEntityID = %d\n\n", LastEntityID)
		for name, id in sorted_pairs(EntityIDs) do
			if id < CommonAssetFirstID then
				if not initializedIDsObject then
					code:append("if not next(EntityIDs) then EntityIDs = {} end \n")
					initializedIDsObject = true
				end
				code:appendf("EntityIDs[\"%s\"] = %d\n", name, id)
			end
		end
	end
	return code
end

function ReserveCommonEntityID(entity)
	if EntityIDs[entity] then
		assert(false, "Entity already has a reserved ID (%d)!", EntityIDs[entity])
		return false
	end
	local id = GetUnusedCommonEntityID()
	if id then
		EntityIDs[entity] = id
		LastCommonEntityID = id
		return id
	end
	assert(false, "Could not reserve a new Entity ID!")
	return false
end

function GetUnusedCommonEntityID()
	if not LastCommonEntityID then
		local max_id = CommonAssetFirstID
		if not next(EntityIDs) then
			max_id = CommonAssetFirstID
		end
		for _, id in pairs(EntityIDs) do
			max_id = Max(max_id, id)
		end
		if max_id >= CommonAssetFirstID then
			LastCommonEntityID = max_id
		else
			assert(false, "GetUnusedCommonEntityID failed!")
			return false
		end
	end	
	return LastCommonEntityID + 1	
end

function ReserveEntityID(entity)
	if EntityIDs[entity] then
		assert(false, "Entity already has a reserved ID (%d)!", EntityIDs[entity])
		return false
	end
	local id = GetUnusedEntityID()
	if id then
		EntityIDs[entity] = id
		LastEntityID = id
		return id
	end
	assert(false, "Could not reserve a new Entity ID!")
	return false
end

function GetUnusedEntityID()
	if not LastEntityID then
		local max_id = -99999
		if not next(EntityIDs) then
			max_id = 0
		end
		local only_common = true
		for _, id in pairs(EntityIDs) do
			if id < CommonAssetFirstID then
				only_common = false
				max_id = Max(max_id, id)
			end
		end
		if only_common then
			max_id = 0
		end
		if max_id >= 0 then
			LastEntityID = max_id
		else
			assert(false, "GetUnusedEntityID failed!")
			return false
		end
	end	
	return LastEntityID + 1	
end

function ValidateEntityIDs()
	local used_ids, errors = {}, false
	for name, id in pairs(EntityIDs) do
		if used_ids[id] then
			StoreErrorSource(EntitySpecPresets[name], string.format("Duplicated entity id found - '%d' for entities '%s' and '%s'!", id, used_ids[id], name))
			errors = true
		else
			used_ids[id] = name
		end
	end
	if errors then
		OpenVMEViewer()
	end
end

function OnMsg.GedOpened(ged_id)
	local gedApp = GedConnections[ged_id]
	if gedApp and gedApp.app_template == EntitySpec.GedEditor then
		ValidateEntityIDs()
	end
end


----- Filtering

DefineClass.EntitySpecFilter = {
	__parents = { "GedFilter" },
	
	properties = {
		{ id = "Class", editor = "combo", default = "", items = PresetsPropCombo("EntitySpec", "class_parent", "") },
		{ id = "NotOfClass", editor = "combo", default = "", items = PresetsPropCombo("EntitySpec", "class_parent", "") },
		{ id = "Category", editor = "choice", default = "", items = function() return table.iappend({""}, ArtSpecConfig.Categories) end },
		{ id = "produced_by", name = "Produced by", editor = "combo", default = "", items = function() return table.iappend({""}, ArtSpecConfig.EntityProducers) end, },
		{ id = "status", name = "Production status", editor = "choice", default = "", items = function() return table.iappend({{id = ""}}, statuses) end },
		{ id = "MaterialType", editor = "preset_id", default = "", preset_class = "ObjMaterial" },
		{ id = "OnCollisionWithCamera", editor = "choice", items = { "", "no action", "become transparent", "repulse camera" }, default = "", no_edit = NoCameraCollision },
		{ id = "fade_category", name = "Fade Category" , editor = "choice", items = FadeCategoryComboItems, default = "", },
		{ id = "HasBillboard", name = "Billboard" , editor = "choice", default = "", items = { "", "yes", "no" } },
		{ id = "HasCollision", name = "Collision" , editor = "choice", default = "any", items = { "any", "has collision", "has no collision" } },
		{ id = "ExportableToSVN", name = "Exportable to SVN", editor = "choice", default = "", items = { "", "true", "false" } },
		{ id = "Exported", name = "Is exported", editor = "choice", default = "", items = { "", "yes", "no" } },
		{ id = "FilterStateSpecDlc", name = "DLC", editor = "choice", default = false, items = DlcCombo{text = "Any", value = false} },
		{ id = "FilterID", name = "ID", editor = "number", default = 0, help = "Find an entity by its unique numeric id." },
	},
	
	billboard_entities = false,
}

function EntitySpecFilter:Init()
	self.ExportableToSVN = "true"
	self.billboard_entities = table.invert(hr.BillboardEntities)
end

function EntitySpecFilter:FilterObject(o)
	if not IsKindOf(o, "EntitySpec") then
		return true
	end
	if self.Class ~= "" and not string.find_lower(o.class_parent, self.Class) then
		return false
	end
	if self.NotOfClass ~= "" and string.find_lower(o.class_parent, self.NotOfClass) then
		return false
	end
	if self.Category ~= "" and o.editor_category ~= self.Category then
		return false
	end
	if self.produced_by ~= "" and o.produced_by ~= self.produced_by then
		return false
	end
	if self.status ~= "" and o.status ~= self.status then
		return false
	end
	if self.MaterialType ~= "" and o.material_type ~= self.MaterialType then
		return false
	end
	if not NoCameraCollision and self.OnCollisionWithCamera ~= "" and o.on_collision_with_camera ~= self.OnCollisionWithCamera then
		return false
	end
	if self.fade_category ~= "" and o.fade_category ~= self.fade_category then
		return false
	end
	if self.ExportableToSVN ~= "" and o.exportableToSVN ~= (self.ExportableToSVN == "true") then
		return false
	end
	g_AllEntities = g_AllEntities or GetAllEntities()
	local exported = g_AllEntities[o.id]
	if self.Exported == "yes" and not exported or self.Exported == "no" and exported then
		return false
	end
	if self.HasBillboard == "yes" and not self.billboard_entities[o.id] or self.HasBillboard == "no" and self.billboard_entities[o.id] then
		return false
	end
	if self.HasCollision ~= "any" then
		local has_collision = (exported and HasCollisions(o.id)) and "has collision" or "has no collision"
		if self.HasCollision ~= has_collision then
			return false
		end
	end
	if self.FilterStateSpecDlc ~= false and 
		((o.class == "EntitySpec" and o.save_in ~= self.FilterStateSpecDlc) or
		(o.class == "StateSpec" and o.save_in ~= self.FilterStateSpecDlc)) then
		return false
	end
	if self.FilterID > 0 and EntityIDs[o.id] ~= self.FilterID then
		return false
	end
	return true
end

function EntitySpecFilter:TryReset(ged, op, to_view)
	return false
end


----- Preview entities from the selected entity specs

if FirstLoad then
	ArtSpecEditorPreviewObjects = {}
end

function OnMsg.GedPropertyEdited(ged_id, obj, prop_id, old_value)
	local gedApp = GedConnections[ged_id]
	if gedApp and gedApp.app_template == EntitySpec.GedEditor then
		if prop_id:find("Editable", 1, true) then -- quick way to see whether a colorization property is edited
			for _, o in ipairs(ArtSpecEditorPreviewObjects) do
				if IsValid(o) then
					o:SetColorsFromTable(obj)
				end
			end
		end
	end	
end

function OnArtSpecSelectObject(entity_spec, selected)
	if GetMap() == "" then return end

	-- delete old objects
	local objs = ArtSpecEditorPreviewObjects
	for _, obj in ipairs(objs) do
		if IsValid(obj) then
			obj:delete()
		end
	end
	table.clear(objs)
	
	if not selected or IsTerrainEntityId(entity_spec.id) then return end

	-- create new objects, assign points starting at (0, 0)
	local all_names = { entity_spec.id }
	local _, _, base_name = entity_spec.id:find("(.*)_%d%d$")
	if base_name then
		local i = 1
		local name = string.format("%s_%02d", base_name, i)
		local names = {}
		while EntitySpecPresets[name] do
			names[#names + 1] = name
			i = i + 1
			name = string.format("%s_%02d", base_name, i)
		end
		if names[1] then
			all_names = names
		end
	end
	
	local positions
	local first_bbox, last_bbox
	local direction = Rotate(camera.GetDirection(), 90 * 60):SetZ(0)
	for _, name in ipairs(all_names) do
		local obj = Shapeshifter:new()
		obj:ChangeEntity(name)
		obj:ClearEnumFlags(const.efApplyToGrids)
		obj:SetColorsByColorizationPaletteName(g_DefaultColorsPalette)
		AutoAttachObjects(obj)
		obj:SetWarped(true)
		
		local bbox = obj:GetEntityBBox("idle")
		if positions then
			positions[#positions + 1] = positions[#positions] + SetLen(direction, last_bbox:sizey() / 2 + bbox:sizey() / 2 + 1 * guim)
		else
			first_bbox = bbox
			positions = { point(0, 0) }
		end
		last_bbox = bbox
		objs[#objs + 1] = obj
		
		local text = Text:new()
		text:SetText(name)
		objs[#objs + 1] = text
	end
	
	-- set positions centered at the center of the screen
	local angle = CalcOrientation(direction) + 90 * 60
	local central_point = GetTerrainGamepadCursor():SetInvalidZ() - positions[#positions] / 2
	local bottom_point, top_point = GetTerrainGamepadCursor(), GetTerrainGamepadCursor()
	for i = 1, #objs / 2 do
		local obj = objs[i * 2 - 1]
		local bbox = obj:GetEntityBBox("idle")
		local pos = positions[i] + central_point
		local objPos = pos:SetTerrainZ() - point(0, 0, bbox:minz() + guic / 10)
		obj:SetPos(objPos)
		obj:SetAngle(angle)
		objs[i * 2]:SetPos(pos:SetTerrainZ())
		if objPos:z() - bbox:sizez() < top_point:z() then
			top_point = objPos - point(0, 0, bbox:sizez())
		end
	end	
	
	-- set camera "look at" position to the central point
	local ptEye, ptLookAt = GetCamera()
	local ptMoveVector = GetTerrainGamepadCursor() - ptLookAt
	ptEye, ptLookAt = ptEye + ptMoveVector, ptLookAt + ptMoveVector
	SetCamera(ptEye, ptLookAt)
	
	-- measure objects total screen width against screen size, and adjust camera to fit all of them
	CreateRealTimeThread(function()
		WaitNextFrame(3)
		if IsValid(objs[1]) and IsValid(objs[#objs - 1]) then
			local _, first_pos  = GameToScreen(objs[1]        :GetPos() - SetLen(direction, first_bbox:sizey() / 2))
			local _, last_pos   = GameToScreen(objs[#objs - 1]:GetPos() + SetLen(direction,  last_bbox:sizey() / 2))
			local _, bottom_pos = GameToScreen(bottom_point)
			local _, top_pos    = GameToScreen(top_point)
			local objectsWidth  = last_pos:x() - first_pos:x()
			local objectsHeight = top_pos:y() - bottom_pos:y()
			local w = MulDivRound(UIL.GetScreenSize():x(), 70, 100)
			local h = MulDivRound(UIL.GetScreenSize():y(), 25, 100)
			if objectsWidth > w or objectsHeight > h then
				local backDirection = ptEye - ptLookAt
				local len = Max(backDirection:Len() * objectsWidth / w, backDirection:Len() * objectsHeight / h)
				SetCamera(ptLookAt + SetLen(backDirection, len), ptLookAt)
			end
		end
	end)
end
