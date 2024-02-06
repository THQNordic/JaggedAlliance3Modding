function ResetColorModifier(parentEditor, object, property, ...)
	object:SetProperty(property, const.clrNoModifier)
end

function GetCollectionNames()
	local names = table.keys(CollectionsByName, "sort")
	table.insert(names, 1, "")
	return names
end

local function OnCollisionWithCameraItems(obj)
	local class_become_transparent = GetClassEnumFlags(obj.class, const.efCameraMakeTransparent) ~= 0
	local class_repulse_camera   = GetClassEnumFlags(obj.class, const.efCameraRepulse) ~= 0	
	local items = {
		{ text = "no action", value = "no action"}, 
		{ text = "repulse camera", value = "repulse camera"}, 
		{ text = "become transparent", value = "become transparent"},
		{ text = "repulse camera & become transparent", value = "repulse camera & become transparent"},
	}
	if class_repulse_camera then
		items[2] = { text = "repulse camera (class default)", value = false }
	elseif class_become_transparent then
		items[3] = { text = "become transparent (class default)", value = false }
	else
		items[1] = { text = "no action (class default)", value = false }
	end
	return items
end

OCCtoFlags = {
	["repulse camera"] = { efCameraMakeTransparent = false, efCameraRepulse = true },
	["become transparent"] = { efCameraMakeTransparent = true, efCameraRepulse = false },
}

if FirstLoad then
	FlagsByBits = {
		Game = {},
		Enum = {},
		Class = {},
		Component = {}
	}
	local const_keys = table.keys(const)
	local const_vars = EnumEngineVars("const.")
	for key in pairs(const_vars) do
		const_keys[#const_keys + 1] = key
	end
	for i = 1, #const_keys do
		local key = const_keys[i]
		local flags
		if string.starts_with(key, "gof") then
			flags = FlagsByBits.Game
		elseif string.starts_with(key, "ef") then
			flags = FlagsByBits.Enum
		elseif string.starts_with(key, "cf") then
			flags = FlagsByBits.Class
		elseif string.starts_with(key, "cof") then
			flags = FlagsByBits.Component
		end
		if flags then
			local value = const[key]
			if value ~= 0 then
				flags[LastSetBit(value) + 1] = key
			end
		end
	end
	FlagsByBits.Enum[1] = { name = "efAlive", read_only = true }
end

local efVisible = const.efVisible
local gofWarped = const.gofWarped
local efShadow = const.efShadow
local efSunShadow = const.efSunShadow

local function GetSurfaceByBits()
	local flags = {}
	for name, flag in pairs(EntitySurfaces) do
		if IsPowerOf2(flag) then
			flags[LastSetBit(flag) + 1] = name
		end
	end
	return flags
end

-- MapObject is a base class for all objects that are on the map.
-- Only classes that inherit MapObject can be passed to Map enumeration functions.
DefineClass.MapObject = {
	__parents = { "PropertyObject" },
	GetEntity = empty_func,
	persist_baseclass = "class",
	UnpersistMissingClass = function(self, id, permanents) return self end
}

--[[@@@
@class CObject
CObjects are objects, accessible to Lua, which have a counterpart in the C++ side of the engine.
They do not have allocated memory in the Lua side, and therefore cannot store any information.
Reference: [CObject](LuaCObject.md.html)
--]]
DefineClass.CObject =
{
	__parents = { "MapObject", "ColorizableObject", "FXObject" },
	__hierarchy_cache = true,
	entity = false,
	flags = {
		efSelectable = true, efVisible = true, efWalkable = true, efCollision = true, 
		efApplyToGrids = true, efShadow = true, efSunShadow = true,
		cfConstructible = true, gofScaleSurfaces = true,
		cofComponentCollider = const.maxCollidersPerObject > 0,
	},
	radius = 0,
	texture = "",
	material_type = false,
	template_class = "",
	distortion_scale = 0,
	orient_mode = 0,
	orient_mode_bias = 0,
	max_allowed_radius = const.GameObjectMaxRadius,
	variable_entity = false,

	-- Properties, editable in the editor's property window (Ctrl+O)
	properties = {
		{ id = "ClassFlagsProp", name = "ClassFlags", editor = "flags",
			items = FlagsByBits.Class, default = 0, dont_save = true, read_only = true },
		{ id = "ComponentFlagsProp", name = "ComponentFlags", editor = "flags",
			items = FlagsByBits.Component, default = 0, dont_save = true, read_only = true },
		{ id = "EnumFlagsProp", name = "EnumFlags", editor = "flags",
			items = FlagsByBits.Enum, default = 1, dont_save = true },
		{ id = "GameFlagsProp", name = "GameFlags", editor = "flags",
			items = FlagsByBits.Game, default = 0, dont_save = true, size = 64 },
		{ id = "SurfacesProp", name = "Surfaces", editor = "flags",
			items = GetSurfaceByBits, default = 0, dont_save = true, read_only = true },
		{ id = "DetailClass", name = "Detail class", editor = "dropdownlist",
			items = {"Default", "Essential", "Optional", "Eye Candy"}, default = "Default",
			help = "Controls the graphic details level set from the options that can hide the object. Essential objects are never hidden.",
		},
		
		{ id = "Entity", editor = "text", default = "", read_only = true, dont_save = true },
		-- The default values MUST be the values these properties are initialized with at object creation
		{ id = "Pos", name = "Pos", editor = "point", default = InvalidPos(), scale = "m",
			buttons = {{ name = "View", func = "GedViewPosButton" }}, },
		{ id = "Angle", editor = "number", default = 0, min = 0, max = 360*60 - 1, slider = true, scale = "deg", no_validate = true }, -- GetAngle can return -360..+360, skip validation
		{ id = "Scale", editor = "number", default = 100, slider = true,
			min = function(self) return self:GetMinScale() end,
			max = function(self) return self:GetMaxScale() end,
		},
		{ id = "Axis",  editor = "point", default = axis_z, local_space = true,
			buttons = {{ name = "View", func = "GedViewPosButton" }}, },
		{ id = "Opacity", editor = "number", default = 100, min = 0, max = 100, slider = true },
		{ id = "StateCategory", editor = "choice", items = function() return ArtSpecConfig and ArtSpecConfig.ReturnAnimationCategories end, default = "All", dont_save = true },
		{ id = "StateText", name = "State/Animation", editor = "combo", default = "idle", items = function(obj) return obj:GetStatesTextTable(obj.StateCategory) end, show_recent_items = 7,
			help = "Sets the mesh state or animation of the object.",
		},
		{ id = "TestStateButtons", editor = "buttons", default = false, dont_save = true, buttons = {
			{name = "Play once(c)", func = "BtnTestOnce"},
			{name = "Loop(c)", func = "BtnTestLoop"},
			{name = "Test(c)", func = "BtnTestState"}, 
			{name = "Play once", func = "BtnTestOnce", param = "no_compensate"},
			{name = "Loop", func = "BtnTestLoop", param = "no_compensate"},
			{name = "Test", func = "BtnTestState", param = "no_compensate"},
		}},
		{ id = "ForcedLOD", name = "Visualise LOD", editor = "number", default = 0, min = 0, slider = true, dont_save = true, help = "Forces specific lod to show.",
			max = function(obj)
				return obj:IsKindOf("GedMultiSelectAdapter") and 0 or (Max(obj:GetLODsCount(), 1) - 1)
			end,
			no_edit = function(obj) return not IsValid(obj) or not obj:HasEntity() or obj:GetEntity() == "InvisibleObject" end
		},
		{ id = "ForcedLODState", name = "Forced LOD", editor = "dropdownlist",
			items = function(obj) return obj:GetLODsTextTable() end, default = "Automatic",
		},
		{ id = "Groups", editor = "string_list", default = false, items = function() return table.keys2(Groups or empty_table, "sorted") end, arbitrary_value = true,
			help = "Assigns the object under one or more different names, by which it is referenced from the gameplay logic via markers or Lua code.",
		},
		
		{ id = "ColorModifier", editor = "rgbrm", default = RGB(100, 100, 100) },
		{ id = "Saturation", name = "Saturation(Debug)", editor = "number", slider = true, min = 0, max = 255, default = 128 },
		{ id = "Gamma", name = "Gamma(Debug)", editor = "color", default = RGB(128, 128, 128) },
		
		{ id = "SIModulation", editor = "number", default = 100, min = 0, max = 255, slider = true},
		{ id = "SIModulationManual", editor = "bool", default = false, read_only = true},
		
		{ id = "Occludes", editor = "bool", default = false },
		{ id = "Walkable", editor = "bool", default = true },
		{ id = "ApplyToGrids", editor = "bool", default = true },
		{ id = "IgnoreHeightSurfaces", editor = "bool", default = false, },
		{ id = "Collision", editor = "bool", default = true },
		{ id = "Visible",   editor = "bool", default = true, dont_save = true },
		{ id = "SunShadow", name = "Shadow from Sun", editor = "bool", default = function(obj) return GetClassEnumFlags(obj.class, efSunShadow) ~= 0 end },
		{ id = "CastShadow", name = "Shadow from All", editor = "bool", default = function(obj) return GetClassEnumFlags(obj.class, efShadow) ~= 0 end },
		{ id = "Mirrored", name = "Mirrored", editor = "bool", default = false },
		{ id = "OnRoof", name = "On Roof", editor = "bool", default = false },
		{ id = "DontHideWithRoom", name = "Don't hide with room", editor = "bool", default = false,
			no_edit = not const.SlabSizeX, dont_save = not const.SlabSizeX,
		},
		
		{ id = "SkewX",     name = "Skew X",       editor = "number", default = 0 },
		{ id = "SkewY",     name = "Skew Y",       editor = "number", default = 0 },
		{ id = "ClipPlane", name = "Clip Plane",   editor = "number", default = 0, read_only = true, dont_save = true },
		{ id = "Radius",    name = "Radius (m)",   editor = "number", default = 0, scale = guim, read_only = true, dont_save = true },

		{ id = "AnimSpeedModifier", name = "Anim Speed Modifier", editor = "number", default = 1000, min = 0, max = 65535, slider = true },
		
		{ id = "OnCollisionWithCamera", editor = "choice", default = false, items = OnCollisionWithCameraItems, },
		{ id = "Warped", editor = "bool", default = function (obj) return GetClassGameFlags(obj.class, gofWarped) ~= 0 end },
		
		-- Required for map saving purposes only.
		{ id = "CollectionIndex", name = "Collection Index", editor = "number", default = 0, read_only = true },
		{ id = "CollectionName", name = "Collection Name", editor = "choice",
			items = GetCollectionNames, default = "", dont_save = true,
			buttons = {{ name = "Collection Editor", func = function(self)
				if self:GetRootCollection() then
					OpenCollectionEditorAndSelectCollection(self)
				end
			end }},
		},
	},
	
	SelectionPropagate = empty_func,
	GedTreeCollapsedByDefault = true, -- for Ged object editor (selection properties)
	PropertyTabs = {
		{ TabName = "Object", Categories = { Misc = true, ["Random Map"] = true, Child = true, } },
	},
	IsVirtual = empty_func,
	GetDestlock = empty_func,
}

function CObject:GetScaleLimits()
	if mapdata.ArbitraryScale then
		return 10, const.GameObjectMaxScale
	end
	
	local data = EntityData[self:GetEntity() or false]
	local limits = data and rawget(_G, "ArtSpecConfig") and ArtSpecConfig.ScaleLimits
	if limits then
		local cat, sub = data.editor_category, data.editor_subcategory
		local limits =
			cat and sub and limits[cat][sub] or
			cat and limits[cat]
		if limits then
			return limits[1], limits[2]
		end
	end
	return 10, 250
end

function CObject:GetMinScale() return self:GetScaleLimits() end
function CObject:GetMaxScale() return select(2, self:GetScaleLimits()) end
function CObject:SetScaleClamped(scale)
	self:SetScale(Clamp(scale, self:GetScaleLimits()))
end

function CObject:GetEnumFlagsProp()
	return self:GetEnumFlags()
end

function CObject:SetEnumFlagsProp(val)
	self:SetEnumFlags(val)
	self:ClearEnumFlags(bnot(val))
end

function CObject:GetGameFlagsProp()
	return self:GetGameFlags()
end

local gofDetailClass0, gofDetailClass1 = const.gofDetailClass0, const.gofDetailClass1
local gofDetailClassMask = const.gofDetailClassMask
local s_DetailsValue = {
	["Default"] = const.gofDetailClassDefaultMask,
	["Essential"] = const.gofDetailClassEssential,
	["Optional"] = const.gofDetailClassOptional,
	["Eye Candy"] = const.gofDetailClassEyeCandy,
}
local s_DetailsName = {}
for name, value in pairs(s_DetailsValue) do
	s_DetailsName[value] = name
end

function GetDetailClassMaskName(mask)
	return s_DetailsName[mask]
end

function CObject:SetGameFlagsProp(val)
	self:SetGameFlags(val)
	self:ClearGameFlags(bnot(val))
	self:SetDetailClass(s_DetailsName[val & gofDetailClassMask])
end

function CObject:GetClassFlagsProp()
	return self:GetClassFlags()
end

function CObject:GetComponentFlagsProp()
	return self:GetComponentFlags()
end

function CObject:GetEnumFlagsProp()
	return self:GetEnumFlags()
end

function CObject:GetSurfacesProp()
	return GetSurfacesMask(self)
end

function CObject:GetDetailClass()
	return IsValid(self) and s_DetailsName[self:GetGameFlags(gofDetailClassMask)] or s_DetailsName[0]
end

function CObject:SetDetailClass(details)
	local value = s_DetailsValue[details]
	if band(value, gofDetailClass0) ~= 0 then
		self:SetGameFlags(gofDetailClass0)
	else
		self:ClearGameFlags(gofDetailClass0)
	end
	if band(value, gofDetailClass1) ~= 0 then
		self:SetGameFlags(gofDetailClass1)
	else
		self:ClearGameFlags(gofDetailClass1)
	end
end

function CObject:SetShadowOnly(bSet, time)
	if not time or IsEditorActive() then
		time = 0
	end
	if bSet then
		self:SetHierarchyGameFlags(const.gofSolidShadow)
		self:SetOpacity(0, time)
	else
		self:ClearHierarchyGameFlags(const.gofSolidShadow)
		self:SetOpacity(100, time)
	end
end

function CObject:SetGamma(value)
	local saturation = GetAlpha(self:GetSatGamma())
	self:SetSatGamma(SetA(value, saturation))
end

function CObject:GetGamma()
	return SetA(self:GetSatGamma(), 255)
end

function CObject:SetSaturation(value)
	local old = self:GetSatGamma()
	self:SetSatGamma(SetA(old, value))
end

function CObject:GetSaturation()
	return GetAlpha(self:GetSatGamma())
end

function CObject:OnEditorSetProperty(prop_id, old_value, ged, multi)
	ColorizableObject.OnEditorSetProperty(self, prop_id, old_value, ged, multi)
	
	if (prop_id == "Saturation" or prop_id == "Gamma") and hr.UseSatGammaModifier == 0 then
		hr.UseSatGammaModifier = 1
		RecreateRenderObjects()
	elseif prop_id == "ForcedLODState" then
		if self:IsKindOf("AutoAttachObject") then
			self:SetAutoAttachMode(self:GetAutoAttachMode())
		end
	elseif prop_id == "SIModulation" then
		local prop_meta = self:GetPropertyMetadata(prop_id)
		self.SIModulationManual = self:GetProperty(prop_id) ~= prop_meta.default
	end
end

if FirstLoad then
	ObjectsShownOnPreSave = false
end

function OnMsg.PreSaveMap()
	ObjectsShownOnPreSave = {}
	MapForEach("map", "CObject", function(o)
		if o:GetGameFlags(const.gofSolidShadow) ~= 0 and not IsKindOf(o, "Decal") then
			ObjectsShownOnPreSave[o] = o:GetOpacity()
			o:SetOpacity(100)
		elseif o:GetEnumFlags(const.efVisible) == 0 then
			local skip = IsKindOf(o, "EditorVisibleObject") or (const.SlabSizeX and IsKindOf(o, "Slab"))
			if not skip then
				ObjectsShownOnPreSave[o] = true
				o:SetEnumFlags(const.efVisible)
			end
		end
	end)
end


function OnMsg.PostSaveMap()
	for o, opacity in pairs(ObjectsShownOnPreSave) do
		if IsValid(o) then
			if type(opacity) == "number" then
				o:SetOpacity(opacity)
			else
				o:ClearEnumFlags(const.efVisible)
			end
		end
	end
	ObjectsShownOnPreSave = false
end

function CObject:GetOnCollisionWithCamera()
	local become_transparent_default = GetClassEnumFlags(self.class, const.efCameraMakeTransparent) ~= 0
	local repulse_camera_default     = GetClassEnumFlags(self.class, const.efCameraRepulse) ~= 0
	local become_transparent         = self:GetEnumFlags(const.efCameraMakeTransparent) ~= 0
	local repulse_camera             = self:GetEnumFlags(const.efCameraRepulse) ~= 0
	if become_transparent_default == become_transparent and repulse_camera_default == repulse_camera then
		return false
	end
	if repulse_camera and not become_transparent then
		return "repulse camera"
	end
	if become_transparent and not repulse_camera then
		return "become transparent"
	end
	if become_transparent and repulse_camera then
		return "repulse camera & become transparent"
	end
	return "no action"
end

function CObject:SetOnCollisionWithCamera(value)
	local cmt, cr
	if value then
		local flags = OCCtoFlags[value]
		cmt = flags and flags.efCameraMakeTransparent 
		cr = flags and flags.efCameraRepulse
	end
	if cmt == nil then
		cmt = GetClassEnumFlags(self.class, const.efCameraMakeTransparent) ~= 0 -- class default
	end
	if cmt then
		self:SetEnumFlags(const.efCameraMakeTransparent)
	else
		self:ClearEnumFlags(const.efCameraMakeTransparent)
	end
	if cr == nil then
		cr = GetClassEnumFlags(self.class, const.efCameraRepulse) ~= 0 -- class default
	end
	if cr then
		self:SetEnumFlags(const.efCameraRepulse)
	else
		self:ClearEnumFlags(const.efCameraRepulse)
	end
end

function CObject:GetCollectionName()
	local col = self:GetCollection()
	return col and col.Name or ""
end

function CObject:SetCollectionName(name)
	local col = CollectionsByName[name]
	local prev_col = self:GetCollection()
	if prev_col ~= col then
		self:SetCollection(col)
	end
end

function CObject:GetEditorRelatedObjects()
	-- return objects that are "connected to", or "a part of" this object
	-- these objects "go together" in undo and copy logic; e.g. is it assumed changes to the Room can update/delete/create its child Slabs
end

function CObject:GetEditorParentObject()
	-- return an object that "owns" this object logically, e.g. a Room owns all its Slabs
	-- changes to the "parent" will be tracked by undo when the "child" is updated/deleted/created
	-- it is also assumed that moving the "parent" will auto-move the "childen"
end

-- Used to identify objects on existing maps that don't have a handle, e.g. in map patches.
-- Returns a hash of the basic object properties, but some classes like Container and Slab
-- this is not sufficient, and they have separate implementations.
function CObject:GetObjIdentifier()
	return xxhash(self.class, self.entity, self:GetPos(), self:GetAxis(), self:GetAngle(), self:GetScale())
end

function CObject:GetMaterialType()
	return self.material_type
end

-- copy functions exported from C
for name, value in pairs(g_CObjectFuncs) do
	CObject[name] = value
end

-- table used for keeping references in the C code to Lua objects
MapVar("__cobjectToCObject", {}, weak_keyvalues_meta)

-- table with destroyed objects
MapVar("DeletedCObjects", {}, weak_keyvalues_meta)

function CreateLuaObject(luaobj)
	return luaobj.new(getmetatable(luaobj), luaobj)
end

local __PlaceObject = __PlaceObject
function CObject.new(class, luaobj, components)
	if luaobj and luaobj[true] then -- constructed from C
		return luaobj
	end
	local cobject = __PlaceObject(class.class, components)
	assert(cobject)
	if cobject then
		if luaobj then
			luaobj[true] = cobject
		else
			luaobj = { [true] = cobject }
		end
		__cobjectToCObject[cobject] = luaobj
	end
	setmetatable(luaobj, class)
	return luaobj
end

function CObject:delete(fromC)
	if not self[true] then return end
	self:RemoveLuaReference()
	self:SetCollectionIndex(0)

	DeletedCObjects[self] = true
	if not fromC then
		__DestroyObject(self)
	end
	__cobjectToCObject[self[true]] = nil
	self[true] = false
end

function CObject:GetCollection()
	local idx = self:GetCollectionIndex()
	return idx ~= 0 and Collections[idx] or false
end

function CObject:GetRootCollection()
	local idx = Collection.GetRoot(self:GetCollectionIndex())
	return idx ~= 0 and Collections[idx] or false
end

function CObject:SetCollection(collection)
	return self:SetCollectionIndex(collection and collection.Index or false)
end

function CObject:GetVisible()
	return self:GetEnumFlags( efVisible ) ~= 0
end

function CObject:SetVisible(value)
	if value then
		self:SetEnumFlags( efVisible )
	else
		self:ClearEnumFlags( efVisible )
	end
end

local cached_forced_lods = {}

function CObject:CacheForcedLODState()
	cached_forced_lods[self] = self:GetForcedLOD() or self:GetForcedLODMin()
end

function CObject:RestoreForcedLODState()
	if type(cached_forced_lods[self]) == "number" then
		self:SetForcedLOD(cached_forced_lods[self])
	elseif cached_forced_lods[self] then
		self:SetForcedLODMin(true)
	else
		self:SetForcedLOD(const.InvalidLODIndex)
	end

	cached_forced_lods[self] = nil
end

function CObject:GetLODsTextTable()
	local lods = {}

	lods[1] = "Automatic"

	for i = 1, Max(self:GetLODsCount(), 1) do
		lods[i + 1] = string.format("LOD %s", i - 1)
	end

	lods[#lods + 1] = "Minimum"

	return lods
end

function CObject:GetForcedLODState()
	local lodState = cached_forced_lods[self]
	
	if lodState == nil then
		lodState = self:GetForcedLOD() or self:GetForcedLODMin()
	end

	if type(lodState) == "number" then
		return string.format("LOD %s", lodState)
	elseif lodState then
		return "Minimum"
	else
		return "Automatic"
	end
end

function CObject:SetForcedLODState(value)
	local cache_forced_lod = nil
	if value == "Minimum" then
		self:SetForcedLODMin(true)
		cache_forced_lod = true
	elseif value == "Automatic" then
		self:SetForcedLOD(const.InvalidLODIndex)
		cache_forced_lod = false
	else
		local lodsTable = self:GetLODsTextTable()
		local targetIndex = nil

		for index, tableValue in ipairs(lodsTable) do
			if value == tableValue then
				targetIndex = index
				break
			end
		end

		if targetIndex then
			local lod = Max(targetIndex - 2, 0)
			cache_forced_lod = lod
			self:SetForcedLOD(lod)
		end
	end
	if cached_forced_lods[self] ~= nil then
		cached_forced_lods[self] = cache_forced_lod
	end
end

function CObject:GetWarped()
	return self:GetGameFlags(gofWarped) ~= 0
end

function CObject:SetWarped(value)
	if value then 
		self:SetGameFlags(gofWarped)
	else
		self:ClearGameFlags(gofWarped)
	end
end

--- Returns whether the object is in the process of being destructed
--@cstyle bool IsBeingDestructed(object obj)
--@param obj object
function IsBeingDestructed(obj)
	return DeletedCObjects[obj] or obj:IsBeingDestructed()
end

function CObject:SetRealtimeAnim(bRealtime)
	if bRealtime then
		self:SetHierarchyGameFlags(const.gofRealTimeAnim)
	else
		self:ClearHierarchyGameFlags(const.gofRealTimeAnim)
	end
end

function CObject:GetRealtimeAnim()
	return self:GetGameFlags(const.gofRealTimeAnim) ~= 0
end

-- Support for groups
MapVar("Groups", {})
local find = table.find
local remove_entry = table.remove_entry

function CObject:AddToGroup(group_name)
	local group = Groups[group_name]
	if not group then
		group = {}
		Groups[group_name] = group
	end
	if not find(group, self) then
		group[#group + 1] = self
		self.Groups = self.Groups or {}
		self.Groups[#self.Groups + 1] = group_name
	end
end

function CObject:IsInGroup(group_name)
	return find(self.Groups, group_name)
end

function CObject:RemoveFromGroup(group_name)
	remove_entry(Groups[group_name], self)
	remove_entry(self.Groups, group_name)
end

function CObject:RemoveFromAllGroups()
	local Groups = Groups
	for i, group_name in ipairs(self.Groups) do
		remove_entry(Groups[group_name], self)
	end
	self.Groups = nil
end

--[[@@@
Called when a cobject having a Lua reference is being destroyed. The method isn't overriden by child classes, but instead all implementations are called starting from the topmost parent.
@function void CObject:RemoveLuaReference()
--]]
RecursiveCallMethods.RemoveLuaReference = "procall_parents_last"
CObject.RemoveLuaReference = CObject.RemoveFromAllGroups

function CObject:SetGroups(groups)
	for _, group in ipairs(self.Groups or empty_table) do
		if not find(groups or empty_table, group) then
			self:RemoveFromGroup(group)
		end
	end
	for _, group in ipairs(groups or empty_table) do
		if not find(self.Groups or empty_table, group) then
			self:AddToGroup(group)
		end
	end
end

function CObject:GetRandomSpotAsync(type)
	return self:GetRandomSpot(type)
end

function CObject:GetRandomSpotPosAsync(type)
	return self:GetRandomSpotPos(type)
end

-- returns false, "local" or "remote"
function CObject:NetState()
	return false
end

function CObject:GetWalkable()
	return self:GetEnumFlags(const.efWalkable) ~= 0
end

function CObject:SetWalkable(walkable)
	if walkable then
		self:SetEnumFlags(const.efWalkable)
	else
		self:ClearEnumFlags(const.efWalkable)
	end
end

function CObject:GetCollision()
	return self:GetEnumFlags(const.efCollision) ~= 0
end

function CObject:SetCollision(value)
	if value then
		self:SetEnumFlags(const.efCollision)
	else
		self:ClearEnumFlags(const.efCollision)
	end
end

function CObject:GetApplyToGrids()
	return self:GetEnumFlags(const.efApplyToGrids) ~= 0
end

function CObject:SetApplyToGrids(value)
	if not not value == self:GetApplyToGrids() then
		return
	end
	if value then
		self:SetEnumFlags(const.efApplyToGrids)
	else
		self:ClearEnumFlags(const.efApplyToGrids)
	end
	self:InvalidateSurfaces()
end

function CObject:GetIgnoreHeightSurfaces()
	return self:GetGameFlags(const.gofIgnoreHeightSurfaces) ~= 0
end

function CObject:SetIgnoreHeightSurfaces(value)
	if not not value == self:GetIgnoreHeightSurfaces() then
		return
	end
	if value then
		self:SetGameFlags(const.gofIgnoreHeightSurfaces)
	else
		self:ClearGameFlags(const.gofIgnoreHeightSurfaces)
	end
	self:InvalidateSurfaces()
end

function CObject:IsValidEntity()
	return IsValidEntity(self:GetEntity())
end

function CObject:GetSunShadow()
	return self:GetEnumFlags(const.efSunShadow) ~= 0
end

function CObject:SetSunShadow(sunshadow)
	if sunshadow then
		self:SetEnumFlags(const.efSunShadow)
	else
		self:ClearEnumFlags(const.efSunShadow)
	end
end

function CObject:GetCastShadow()
	return self:GetEnumFlags(const.efShadow) ~= 0
end

function CObject:SetCastShadow(shadow)
	if shadow then
		self:SetEnumFlags(const.efShadow)
	else
		self:ClearEnumFlags(const.efShadow)
	end
end

function CObject:GetOnRoof()
	return self:GetGameFlags(const.gofOnRoof) ~= 0
end

function CObject:SetOnRoof(on_roof)
	if on_roof then
		self:SetGameFlags(const.gofOnRoof)
	else
		self:ClearGameFlags(const.gofOnRoof)
	end
end

if const.SlabSizeX then
	function CObject:GetDontHideWithRoom()
		return self:GetGameFlags(const.gofDontHideWithRoom) ~= 0
	end

	function CObject:SetDontHideWithRoom(val)
		if val then
			self:SetGameFlags(const.gofDontHideWithRoom)
		else
			self:ClearGameFlags(const.gofDontHideWithRoom)
		end
	end
end

function CObject:GetLODsCount()
	local entity = self:GetEntity()
	return entity ~= "" and GetStateLODCount(entity, self:GetState()) or 1
end

function CObject:GetDefaultPropertyValue(prop, prop_meta)
	if prop == "ApplyToGrids" then
		return GetClassEnumFlags(self.class, const.efApplyToGrids) ~= 0
	elseif prop == "Collision" then
		return GetClassEnumFlags(self.class, const.efCollision) ~= 0
	elseif prop == "Walkable" then
		return GetClassEnumFlags(self.class, const.efWalkable) ~= 0
	elseif prop == "DetailClass" then
		local details_mask = GetClassGameFlags(self.class, gofDetailClassMask)
		return GetDetailClassMaskName(details_mask)
	end
	return PropertyObject.GetDefaultPropertyValue(self, prop, prop_meta)
end

-- returns the first valid state for the unit or the last one if none is valid
function CObject:ChooseValidState(state, next_state, ...)
	if next_state == nil then return state end
	if state and self:HasState(state) and not self:IsErrorState(state) then
		return state
	end
	return self:ChooseValidState(next_state, ...)
end

-- State property (implemented as text for saving compatibility)
function CObject:GetStatesTextTable(category)
	local entity = IsValid(self) and self:GetEntity()
	if not IsValidEntity(entity) then return {} end
	local states = category and GetStatesFromCategory(entity, category) or self:GetStates()
	local i = 1
	while i <= #states do
		local state = states[i]
		if string.starts_with(state, "_") then --> ignore states beginning with '_'
			table.remove(states, i)
		else
			if self:IsErrorState(GetStateIdx(state)) then
				states[i] = state.." *"
			end
			i = i + 1
		end
	end
	table.sort(states)
	return states
end

function CObject:SetStateText(value, ...)
	if value:sub(-1, -1) == "*" then
		value = value:sub(1, -3)
	end
	if not self:HasState(value) then
		StoreErrorSource(self, "Missing object state " .. self:GetEntity() .. "." .. value)
	else
		self:SetState(value, ...)
	end
end

function CObject:GetStateText()
	return GetStateName(self)
end

function CObject:OnPropEditorOpen()
	self:SetRealtimeAnim(true)
end

-- Functions for manipulating text attaches

-- Attaches a text at the given spot
-- @param text string Text to be attached
-- @param spot int Id of the spot
function CObject:AttachText( text, spot )
	local obj = PlaceObject ( "Text" )
	obj:SetText(text)
	if spot == nil then
		spot = self:GetSpotBeginIndex("Origin")
	end
	self:Attach(obj, spot)
	return obj
end

-- Attaches a text at the given spot, which is updated trough a function each 900ms + random ( 200ms )
-- @param f function A function that returns the updated text
-- @param spot int Id of the spot
function CObject:AttachUpdatingText( f, spot )
	local obj = PlaceObject ( "Text" )
	CreateRealTimeThread( function ()
		while IsValid(obj) do
			local text, sleep = f(obj)
			obj:SetText(text or "")
			Sleep((sleep or 900) + AsyncRand(200))
		end
	end)
	if spot == nil then
		spot = self:GetSpotBeginIndex("Origin")
	end
	self:Attach(obj, spot)
	return obj
end

-- calls the func or the obj method when the current thread completes (but within the same millisecond);
-- multiple calls with the same arguments result in the function being called only once.
function CObject:Notify(method)
	Notify(self, method)
end

if Platform.editor then
	function EditorCanPlace(class_name)
		local class = g_Classes[class_name]
		return class and class:EditorCanPlace()
	end
	function CObject:EditorCanPlace()
		return IsValidEntity(self:GetEntity())
	end
end

CObject.GetObjectBySpot = empty_func

--- Shows the spots of the object using code renderables.
function CObject:ShowSpots(spot_type, annotation, show_spot_idx)
	if not self:HasEntity() then return end
	local start_id, end_id = self:GetAllSpots(self:GetState())
	local scale = Max(1, DivRound(10000, self:GetScale()))
	for i = start_id, end_id do
		local spot_name = GetSpotNameByType(self:GetSpotsType(i))
		if not spot_type or string.find(spot_name, spot_type) then
			local spot_annotation = self:GetSpotAnnotation(i)
			if not annotation or string.find(spot_annotation, annotation) then
				local text_obj = Text:new{ editor_ignore = true }
				local text_str = self:GetSpotName(i)
				if show_spot_idx then
					text_str = i .. '.' .. text_str
				end
				if spot_annotation then
					text_str = text_str .. ";" .. spot_annotation
				end
				text_obj:SetText(text_str)
				self:Attach(text_obj, i)
				
				local orientation_obj = CreateOrientationMesh()
				orientation_obj.editor_ignore = true
				orientation_obj:SetScale(scale)
				self:Attach(orientation_obj, i)
			end
		end
	end
end

--- Hides the spots of the objects.
function CObject:HideSpots()
	if not self:HasEntity() then return end
	self:DestroyAttaches("Text")
	self:DestroyAttaches("Mesh")
end


ObjectSurfaceColors = {
	ApplyToGrids = red,
	Build = purple,
	ClearRoad = white,
	Collision = green,
	Flat = const.clrGray,
	Height = cyan,
	HexShape = yellow,
	Road = black,
	Selection = blue,
	Terrain = RGBA(255, 0, 0, 128),
	TerrainHole = magenta,
	Walk = const.clrPink,
}

MapVar("ObjToShownSurfaces", {}, weak_keys_meta)
MapVar("TurnedOffObjSurfaces", {})

--- Shows the surfaces of the object using code renderables.
function CObject:ShowSurfaces()
	local entity = self:GetEntity()
	if not IsValidEntity(entity) then return end
	local entry = ObjToShownSurfaces[self]
	for stype, flag in pairs(EntitySurfaces) do
		if HasAnySurfaces(entity, EntitySurfaces[stype])
			and not (stype == "All" or stype == "AllPass" or stype == "AllPassAndWalk")
			and not TurnedOffObjSurfaces[stype]
			and (not entry or not entry[stype]) then
			local color1 = ObjectSurfaceColors[stype] or RandColor(xxhash(stype))
			local color2 = InterpolateRGB(color1, black, 1, 2)
			local mesh = CreateObjSurfaceMesh(self, flag, color1, color2)
			mesh:SetOpacity(75)
			entry = table.create_set(entry, stype, mesh)
		end
	end
	ObjToShownSurfaces[self] = entry or {}
	OpenDialog("ObjSurfacesLegend")
end

--- Hides the surfaces of the object.
function CObject:HideSurfaces()
	for stype, mesh in pairs(ObjToShownSurfaces[self]) do
		DoneObject(mesh)
	end
	ObjToShownSurfaces[self] = nil
	if not next(ObjToShownSurfaces) then
		CloseDialog("ObjSurfacesLegend")
	end
end

function OnMsg.LoadGame()
	if next(ObjToShownSurfaces) then
		OpenDialog("ObjSurfacesLegend")
	end
end


----- Ged

function CObject:GedTreeViewFormat()
	if IsValid(self) then
		local label = self:GetProperty("EditorLabel") or self.class
		local value = self:GetProperty("Name") or self:GetProperty("ParticlesName")
		local tname = value and (IsT(value) and _InternalTranslate(value) or type(value) == "string" and value) or ""
		if #tname > 0 then
			label = label .. " - " .. tname
		end
		return label
	end
end

function CObject:GedTreeChildren()
	local ret = IsValid(self) and self:GetAttaches() or empty_table
	return table.ifilter(ret, function(k, v) return not rawget(v, "editor_ignore") end)
end


------------------------------------------------------------
----------------- Animation Moments ------------------------
------------------------------------------------------------

function GetEntityAnimMoments(entity, anim, moment_type)
	local anim_entity = GetAnimEntity(entity, anim)
	local preset_group = anim_entity and Presets.AnimMetadata[anim_entity]
	local preset_anim = preset_group and preset_group[anim]
	local moments = preset_anim and preset_anim.Moments
	if moments and moment_type then
		moments = table.ifilter(moments, function(_, m, moment_type)
			return m.Type == moment_type
		end, moment_type)
	end
	return moments or empty_table
end
local GetEntityAnimMoments = GetEntityAnimMoments

function CObject:GetAnimMoments(anim, moment_type)
	return GetEntityAnimMoments(self:GetEntity(), anim or self:GetStateText(), moment_type)
end

local AnimSpeedScale = const.AnimSpeedScale
local AnimSpeedScale2 = AnimSpeedScale * AnimSpeedScale

function CObject:IterateMoments(anim, phase, moment_index, moment_type, reversed, looping, moments, duration)	
	moments = moments or self:GetAnimMoments(anim)
	local count = #moments
	if count == 0 or moment_index <= 0 then
		return false, -1
	end
	duration = duration or GetAnimDuration(self:GetEntity(), anim)
	local count_down = moment_index
	local next_loop

	if not reversed then
		local time = -phase		-- current looped beginning time of the animation
		local idx = 1
		while true do
			if idx > count then	-- if we are out of moments for this loop - start over with increased time
				if not looping then
					return false, -1
				end
				idx = 1
				time = time + duration
				if count_down == moment_index and time > duration then
					return false, -1		-- searching for non-existent moment
				end
				next_loop = true
			end
			local moment = moments[idx]
			if (not moment_type or moment_type == moment.Type) and time + moment.Time >= 0 then
				if count_down == 1 then
					return moment.Type, time + Min(duration-1, moment.Time), moment, next_loop
				end
				count_down = count_down - 1
			end
			idx = idx + 1
		end
	else
		local time = phase - duration
		local idx = count
		while true do
			if idx == 0 then
				if not looping then
					return false, -1
				end
				idx = count
				time = time + duration
				if count_down == moment_index and time > duration then
					return false, -1		-- searching for non-existent moment
				end
				next_loop = true
			end
			local moment = moments[idx]
			if (not moment_type or moment_type == moment.Type) and time + duration - moment.Time >= 0 then
				if count_down == 1 then
					return moment.Type, time + duration - moment.Time, moment, next_loop
				end
				count_down = count_down - 1
			end
			idx = idx - 1
		end
	end
end

function CObject:GetChannelData(channel, moment_index)
	local reversed = self:IsAnimReversed(channel)
	if moment_index < 1 then
		reversed = not reversed
		moment_index = -moment_index
	end
	local looping = self:IsAnimLooping(channel)
	local anim = GetStateName(self:GetAnim(channel))
	local phase = self:GetAnimPhase(channel)
	
	return anim, phase, moment_index, reversed, looping
end

local function ComputeTimeTo(anim_time, combined_speed, looping)
	if combined_speed == AnimSpeedScale2 then
		return anim_time
	end
	if combined_speed == 0 then
		return max_int
	end
	local time = anim_time * AnimSpeedScale2 / combined_speed
	if time == 0 and anim_time ~= 0 and looping then
		return 1
	end
	return time
end

function CObject:TimeToMoment(channel, moment_type, moment_index)
	if moment_index == nil and type(channel) == "string" then
		channel, moment_type, moment_index = 1, channel, moment_type
	end
	local anim, phase, index, reversed, looping = self:GetChannelData(channel, moment_index or 1)
	local _, anim_time = self:IterateMoments(anim, phase, index, moment_type, reversed, looping)
	if anim_time == -1 then
		return
	end
	local combined_speed = self:GetAnimSpeed(channel) * self:GetAnimSpeedModifier()
	return ComputeTimeTo(anim_time, combined_speed, looping)
end

function CObject:OnAnimMoment(moment, anim, remaining_duration, moment_counter, loop_counter)
	PlayFX(FXAnimToAction(anim), moment, self)
end

function CObject:PlayTimedMomentTrackedAnim(state, duration)
	return self:WaitMomentTrackedAnim(state, nil, nil, nil, nil, nil, duration)
end

function CObject:PlayAnimWithCallback(state, moment, callback, ...)
	return self:WaitMomentTrackedAnim(state, nil, nil, nil, nil, nil, nil, moment, callback, ...)
end

function CObject:PlayMomentTrackedAnim(state, count, flags, crossfade, duration, moment, callback, ...)
	return self:WaitMomentTrackedAnim(state, nil, nil, count, flags, crossfade, duration, moment, callback, ...)
end

function CObject:WaitMomentTrackedAnim(state, wait_func, wait_param, count, flags, crossfade, duration, moment, callback, ...)
	if not IsValid(self) then return "invalid" end
	if (state or "") ~= "" then
		if not self:HasState(state) then
			GameTestsError("once", "Missing animation:", self:GetEntity() .. '.' .. state)
			duration = duration or 1000
		else
			self:SetState(state, flags or 0, crossfade or -1)
			assert(self:GetAnimPhase() == 0)
			local anim_duration = self:GetAnimDuration()
			if anim_duration == 0 then
				GameTestsError("once", "Zero length animation:", self:GetEntity() .. '.' .. state)
				duration = duration or 1000
			else
				local channel = 1
				duration = duration or (count or 1) * anim_duration
				local moments = self:GetAnimMoments(state)
				local moment_count = table.count(moments, "Type", moment)
				if moment and callback and moment_count ~= 1 then
					StoreErrorSource(self, "The callback is supposed to be called once for animation", state, "but there are", moment_count, "moments with the name", moment)
				end
				local anim, phase, count_down, reversed, looping = self:GetChannelData(channel, 1)
				local moment_counter, loop_counter = 0, 0
				while duration > 0 do
					if not IsValid(self) then return "invalid" end
					local moment_type, time, moment_descr, next_loop = self:TimeToNextMoment(channel, count_down, anim, phase, reversed, looping, moments, anim_duration)
					local sleep_time
					if not time or time == -1 then
						sleep_time = duration
					else
						sleep_time = Min(duration, time)
					end
					if not wait_func then
						Sleep(sleep_time)
					elseif wait_func(wait_param, sleep_time) then
						return "msg"
					end
					
					if not IsValid(self) then return "invalid" end
					duration = duration - sleep_time
					if sleep_time == time and (duration ~= 0 or not next_loop) then
						moment_counter = moment_counter + 1
						-- moment reached
						if next_loop then
							loop_counter = loop_counter + 1
						end
						if self:OnAnimMoment(moment_type, anim, duration, moment_counter, loop_counter) == "break" then
							assert(not callback)
							return "break"
						end
						if callback then
							if not moment then
								if callback(moment_type, ...) == "break" then
									return "break"
								end
							elseif moment == moment_type then
								if callback(...) == "break" then
									return "break"
								end
								callback = nil
							end
						end
					end
					
					phase = nil
					count_down = 2
				end
			end
		end
	end
	if duration and duration > 0 then
		if not wait_func then
			Sleep(duration)
		elseif wait_func(wait_param, duration) then
			return "msg"
		end
	end
	if callback and moment then
		callback(...)
	end
end

function CObject:PlayTransitionAnim(anim, moment, callback, ...)
	return self:ExecuteWeakUninterruptable(self.PlayAnimWithCallback, anim, moment, callback, ...)
end

function CObject:TimeToNextMoment(channel, index, anim, phase, reversed, looping, moments, duration)
	anim = anim or GetStateName(self:GetAnim(channel))
	phase = phase or self:GetAnimPhase(channel)
	if reversed == nil then
		reversed = self:IsAnimReversed(channel)
	end
	if looping == nil then
		looping = self:IsAnimLooping(channel)
	end
	if index < 1 then
		reversed = not reversed
		index = -index
	end
	local moment_type, anim_time, moment_descr, next_loop = self:IterateMoments(anim, phase, index, nil, 
		reversed, looping, moments, duration)
	if anim_time == -1 then
		return
	end
	local combined_speed = self:GetAnimSpeed(channel) * self:GetAnimSpeedModifier()
	local time = ComputeTimeTo(anim_time, combined_speed, looping)
	
	return moment_type, time, moment_descr, next_loop
end

function CObject:TypeOfMoment(channel, moment_index)
	local anim, phase, index, reversed, looping = self:GetChannelData(channel, moment_index or 1)
	return self:IterateMoments(anim, phase, index, false, reversed, looping)
end

function CObject:GetAnimMoment(anim, moment_type, moment_index, raise_error)
	local _, anim_time = self:IterateMoments(anim, 0, moment_index or 1, moment_type, false, self:IsAnimLooping())
	if anim_time ~= -1 then
		return anim_time
	end
	if not raise_error then
		return
	end
	assert(false, string.format("No such anim moment: %s.%s.%s", self:GetEntity(), anim, moment_type), 1)
	return self:GetAnimDuration(anim)
end

function CObject:GetAnimMomentType(anim, moment_index)
	local moment_type = self:IterateMoments(anim, 0, moment_index or 1, false, false, self:IsAnimLooping())
	if not moment_type or moment_type == "" then
		return
	end
	return moment_type
end

function CObject:GetAnimMomentsCount(anim, moment_type)
	return #self:GetAnimMoments(anim, moment_type)
end

-- TODO: maybe return directly the (filtered) table from the Presets.AnimMetadata
function GetStateMoments(entity, anim)
	local moments = {}
	for idx, moment in ipairs(GetEntityAnimMoments(entity, anim)) do
		moments[idx] = {type = moment.Type, time = moment.Time}
	end
	return moments
end

function GetStateMomentsNames(entity, anim)
	if not IsValidEntity(entity) or GetStateIdx(anim) == -1 then return empty_table end
	local moments = {}
	for idx, moment in ipairs(GetEntityAnimMoments(entity, anim)) do
		moments[moment.Type] = true
	end
	return table.keys(moments, true)
end

function GetEntityDefaultAnimMetadata()
	local entityDefaultAnimMetadata = {}
	for name, entity_data in pairs(EntityData) do
		if entity_data.anim_components then
			local anim_components = table.map( entity_data.anim_components, function(t) return AnimComponentWeight:new(t) end )
			local animMetadata = AnimMetadata:new({id = "__default__", group = name, AnimComponents = anim_components})
			entityDefaultAnimMetadata[name] = { __default__ = animMetadata }
		end
	end
	return entityDefaultAnimMetadata
end

local function ReloadAnimData()
	ReloadAnimComponentDefs(AnimComponents)
	
	ClearAnimMetaData()
	LoadAnimMetaData(Presets.AnimMetadata)
	LoadAnimMetaData(GetEntityDefaultAnimMetadata())
	
	local speed_scale = const.AnimSpeedScale
	for _, entity_meta in ipairs(Presets.AnimMetadata) do
		for _, anim_meta in ipairs(entity_meta) do
			local speed_modifier = anim_meta.SpeedModifier * speed_scale / 100
			SetStateSpeedModifier(anim_meta.group, GetStateIdx(anim_meta.id), speed_modifier)
		end
	end
end

OnMsg.DataLoaded = ReloadAnimData
OnMsg.DataReloadDone = ReloadAnimData

function OnMsg.PresetSave(className)
	local class = g_Classes[className]
	if IsKindOf(class, "AnimComponent") or IsKindOf(class, "AnimMetadata") then
		ReloadAnimData()
	end
end

-------------------------------------------------------
---------------------- Testing ------------------------
-------------------------------------------------------

if FirstLoad then
	g_DevTestState = {
		thread = false,
		obj = false,
		start_pos = false,
		start_axis = false,
		start_angle = false,
	}
end

function CObject:BtnTestState(main, prop_id, ged, no_compensate)
	self:TestState(nil, no_compensate)
end

function CObject:BtnTestOnce(main, prop_id, ged, no_compensate)
	self:TestState(1, no_compensate)
end

function CObject:BtnTestLoop(main, prop_id, ged, no_compensate)
	self:TestState(10000000000, no_compensate)
end

function CObject.TestState(self, rep, ignore_compensation)
	if not IsEditorActive() then
		print("Available in editor only")
	end


	if g_DevTestState.thread then
		DeleteThread(g_DevTestState.thread)
	end
	if g_DevTestState.obj ~= self then
		g_DevTestState.start_pos = self:GetVisualPos()
		g_DevTestState.start_angle = self:GetVisualAngle()
		g_DevTestState.start_axis = self:GetVisualAxis()
		g_DevTestState.obj = self
	end
	g_DevTestState.thread = CreateRealTimeThread(function(self, rep, ignore_compensation)
		local start_pos = g_DevTestState.start_pos
		local start_angle = g_DevTestState.start_angle
		local start_axis = g_DevTestState.start_axis
		self:SetAnim(1, self:GetState(), 0, 0)
		local duration = self:GetAnimDuration()
		if duration == 0 then return end
		local state = self:GetState()
		local step_axis, step_angle
		if not ignore_compensation then
			step_axis, step_angle = self:GetStepAxisAngle()
		end

		local rep = rep or 5
		for i = 1, rep do
			if not IsValid(self) or not IsEditorActive() or self:GetState() ~= state then
				break
			end
			self:SetAnim(1, state, const.eDontLoop, 0)

			self:SetPos(start_pos)
			self:SetAxisAngle(start_axis, start_angle)

			if ignore_compensation then
				Sleep(duration)
			else
				local parts = 2
				for i = 1, parts do
					local start_time = MulDivRound(i - 1, duration, parts)
					local end_time = MulDivRound(i, duration, parts)
					local part_duration = end_time - start_time

					local part_step_vector = self:GetStepVector(state, start_angle, start_time, part_duration)
					self:SetPos(self:GetPos() + part_step_vector, part_duration)

					local part_rot_angle = MulDivRound(i, step_angle, parts) - MulDivRound(i - 1, step_angle, parts) 
					self:Rotate(step_axis, part_rot_angle, part_duration)
					Sleep(part_duration)
					if not IsValid(self) or not IsEditorActive() or self:GetState() ~= state then
						break
					end
				end
			end

			Sleep(400)
			if not IsValid(self) or not IsEditorActive() or self:GetState() ~= state then
				break
			end
			self:SetPos(start_pos)
			self:SetAxisAngle(start_axis, start_angle)
			Sleep(400)
		end

		g_DevTestState.obj = false
	end, self, rep, ignore_compensation)
end

function CObject:SetColorFromTextStyle(id)
	assert(TextStyles[id])
	self.textstyle_id = id
	local color = TextStyles[id].TextColor
	local _, _, _, opacity = GetRGBA(color)
	self:SetColorModifier(color)
	self:SetOpacity(opacity)
end

function CObject:SetContourRecursive(visible, id)
	if not IsValid(self) or IsBeingDestructed(self) then
		return
	end
	if visible then
		self:SetContourOuterID(true, id)
		self:ForEachAttach(function(attach)
			attach:SetContourRecursive(true, id)
		end)
	else
		self:SetContourOuterID(false, id)
		self:ForEachAttach(function(attach)
			attach:SetContourRecursive(false, id)
		end)
	end
end

function CallRecursive(self, func, ...)
	if not IsValid(self) or IsBeingDestructed(self) then
		return
	end

	if type(func) == "function" then
		func(self, ...)
	elseif type(func) == "string" then
		table.fget(self, func, "(", ...)
	else
		return "Invalid parameter. Expected function or method name"
	end
	
	self:ForEachAttach(CallRecursive, func, ...)
end

function CObject:SetUnderConstructionRecursive(data)
	if not IsValid(self) or IsBeingDestructed(self) then
		return
	end
	self:SetUnderConstruction(data)
	self:ForEachAttach(function(attach, data)
		attach:SetUnderConstructionRecursive(data)
	end, data)
end

function CObject:SetContourOuterOccludeRecursive(set)
	if not IsValid(self) or IsBeingDestructed(self) then
		return
	end
	self:SetContourOuterOcclude(set)
	self:ForEachAttach(function(attach, set)
		attach:SetContourOuterOccludeRecursive(set)
	end, set)
end

function CObject:GetObjectAttachesBBox(ignore_classes)
	local bbox = self:GetObjectBBox()
	self:ForEachAttach(function(attach)
		if not ignore_classes or not IsKindOfClasses(attach, ignore_classes) then
			bbox = AddRects(bbox, attach:GetObjectBBox())
		end
	end)
	
	return bbox
end

function CObject:GetError()
	if not IsValid(self) then return end

	local parent = self:GetParent()
	-- CheckCollisionObjectsAreEssentials
	if const.maxCollidersPerObject > 0 then
		if not parent and self:GetEnumFlags(const.efCollision) ~= 0 then
			if collision.GetFirstCollisionMask(self) then
				local detail_class = self:GetDetailClass()
				if detail_class == "Default" then
					local entity = self:GetEntity()
					local entity_data = EntityData[entity]
					detail_class = entity and entity_data and entity_data.entity.DetailClass or "Essential"
				end
				if detail_class ~= "Essential" then
					return "Object with colliders is not declared 'Essential'"
				end
			end
		end
	end

	-- Validate collection index
	if not parent then -- obj is not attached
		local col = self:GetCollectionIndex()
		if col > 0 and not Collections[col] then
			self:SetCollectionIndex(0)
			return string.format("Missing collection object for index %s", col)
		end
	end
end

RecursiveCallMethods.OnHoverStart = true
CObject.OnHoverStart = empty_func
RecursiveCallMethods.OnHoverUpdate = true
CObject.OnHoverUpdate = empty_func
RecursiveCallMethods.OnHoverEnd = true
CObject.OnHoverEnd = empty_func

MapVar("ContourReasons", false)
function SetContourReason(obj, contour, reason)
	if not ContourReasons then
		ContourReasons = setmetatable({}, weak_keys_meta)
	end
	local countours = ContourReasons[obj]
	if not countours then
		countours = {}
		ContourReasons[obj] = countours
	end
	local reasons = countours[contour]
	if reasons then
		reasons[reason] = true
		return
	end
	obj:SetContourRecursive(true, contour)
	countours[contour] = {[reason] = true}
end
function ClearContourReason(obj, contour, reason)
	local countours = (ContourReasons or empty_table)[obj]
	local reasons = countours and countours[contour]
	if not reasons or not reasons[reason] then
		return
	end
	reasons[reason] = nil
	if not next(reasons) then
		obj:SetContourRecursive(false, contour)
		countours[contour] = nil
		if not next(countours) then
			ContourReasons[obj] = nil
		end
	end
end

-- Additional functions for working with groups

--- Returns a table, containing all objects from the specified group.
-- @param name string - The name of the group to get all objects from.
function GetGroup(name)
	local list = {}
	local group = Groups[name]
	if not group then
		return list
	end

	for i = 1,#group do
		local obj = group[i]
		if IsValid(obj) then list[#list + 1] = obj end
	end
	return list
end

function GetGroupRef(name)
	return Groups[name]
end

function GroupExists(name)
	return not not Groups[name]
end

function GetGroupNames()
	local group_names = {}
	for group, _ in pairs(Groups) do
		table.insert(group_names, group)
	end
	table.sort(group_names)
	return group_names
end

function GroupNamesWithSpace()
	local group_names = {}
	for group, _ in pairs(Groups) do
		group_names[#group_names + 1] = " " .. group
	end
	table.sort(group_names)
	return group_names
end

--- Spawns the template objects from the specified group, adding the spawned ones to all groups the templates were in.
-- @param name string The name of the group to be spawned.
-- @param pos point Position to center the group on while spawning
-- @param filter is the same function that is passed to MapGet/MapCount queries
-- @return table An object list, containing the spawned units.
function SpawnGroup(name, pos, filter_func)
	local list = {}
	local templates = MapFilter(GetGroup(name, true), "map", "Template", filter_func)
	if #templates > 0 then
		-- Calculate offset to move group (if any)
		local center = AveragePoint(templates)
		if pos then
			center, pos = pos, (pos - center):SetInvalidZ()
		end
		for _, obj in ipairs(templates) do
			local spawned = obj:Spawn()
			if spawned then
				if pos then
					spawned:SetPos(obj:GetPos() + pos)
				end
				list[#list + 1] = spawned
			end
		end
	end
	return list
end


--- Spawns the template objects from the specified group, adding the spawned ones to all groups the templates were in; disperses the times of spawning in the given time interval.
-- @param name string The name of the group to be spawned.
-- @param pos point Position to center the group on while spawning
-- @param filter is the same structure that is passed to MapGet/MapCount queries
-- @param time number The length of the interval in which all units are randomly spawned.
-- @return table An object list, containing the spawned units.
function SpawnGroupOverTime(name, pos, filter, time)
	local list = {}
	local templates = MapFilter(GetGroup(name, true), "map", "Template", filter_func)
	-- Find appropriate times for spawning
	local times, sum = {}, 0
	for i = 1, #templates do
		if templates[i]:ShouldSpawn() then
			local rand = AsyncRand(1000)
			times[i] = rand
			sum = sum + rand
		else
			times[i] = false
		end
	end

	-- Spawn the units using the already known time intervals
	for i,obj in ipairs(templates) do
		if times[i] then
			local spawned_obj = obj:Spawn()
			if spawned_obj then
				list[#list + 1] = spawned_obj:SetPos(pos)
				Sleep(times[i]*time/sum)
			end
		end
	end
	return list
end

__enumflags = false
__classflags = false
__componentflags = false
__gameflags = false

function OnMsg.ClassesPostprocess()
	-- Clear surfaces flags for objects without surfaces or valid entities
	local asWalk = EntitySurfaces.Walk
	local efWalkable = const.efWalkable
	-- Collision flag is also used to enable/disable terrain surface application
	local asCollision = EntitySurfaces.Collision
	local efCollision = const.efCollision
	local asApplyToGrids = EntitySurfaces.ApplyToGrids
	local efApplyToGrids = const.efApplyToGrids
	local cmPassability = const.cmPassability
	local cmDefaultObject = const.cmDefaultObject

	__enumflags = FlagValuesTable("MapObject", "ef", function(name, flags)
		local class = g_Classes[name]
		local entity = class:GetEntity()
		if not class.variable_entity and IsValidEntity(entity) then
			if not HasAnySurfaces(entity, asWalk) then
				flags = FlagClear(flags, efWalkable)
			end
			if not HasAnySurfaces(entity, asCollision) and not HasMeshWithCollisionMask(entity, cmDefaultObject) then
				flags = FlagClear(flags, efCollision)
			end
			if not HasAnySurfaces(entity, asApplyToGrids) and not HasMeshWithCollisionMask(entity, cmPassability) then
				flags = FlagClear(flags, efApplyToGrids)
			end
			return flags
		end
	end)
	__gameflags = FlagValuesTable("MapObject", "gof")
	__classflags = FlagValuesTable("MapObject", "cf")
	__componentflags = FlagValuesTable("MapObject", "cof")
end

function OnMsg.ClassesBuilt()
	-- mirror MapObject class info in the C++ engine for faster access
	ClearStaticClasses()
	ReloadStaticClass("MapObject", g_Classes.MapObject)
	ClassDescendants("MapObject", ReloadStaticClass)
	-- clear flag tables
	__enumflags = nil
	__classflags = nil
	__componentflags = nil
	__gameflags = nil
end

function OnMsg.PostDoneMap()
	-- clear references to cobjects in all lua objects
	for cobject, obj in pairs(__cobjectToCObject or empty_table) do
		if obj then
			obj[true] = false
		end
	end
end

DefineClass.StripCObjectProperties = {
	__parents = { "CObject" },
	properties = {
		{ id = "ColorizationPalette" },
		{ id = "ClassFlagsProp" },
		{ id = "ComponentFlagsProp" },
		{ id = "EnumFlagsProp" },
		{ id = "GameFlagsProp" },
		{ id = "SurfacesProp" },
		{ id = "Axis" },
		{ id = "Opacity" },
		{ id = "StateCategory" },
		{ id = "StateText" },
		{ id = "Mirrored" },
		{ id = "ColorModifier" },
		{ id = "Occludes" },
		{ id = "ApplyToGrids" },
		{ id = "IgnoreHeightSurfaces" },
		{ id = "Walkable" },
		{ id = "Collision" },
		{ id = "OnCollisionWithCamera" },
		{ id = "Scale" },
		{ id = "SIModulation" },
		{ id = "SIModulationManual" },
		{ id = "AnimSpeedModifier" },
		{ id = "Visible" },
		{ id = "SunShadow" },
		{ id = "CastShadow" },
		{ id = "Entity" },
		{ id = "Angle" },
		{ id = "ForcedLOD" },
		{ id = "Groups" },
		{ id = "CollectionIndex" },
		{ id = "CollectionName" },
		{ id = "Warped" },
		{ id = "SkewX", },
		{ id = "SkewY", },
		{ id = "ClipPlane", },
		{ id = "Radius", },
		{ id = "Sound", },
		{ id = "OnRoof", },
		{ id = "DontHideWithRoom", },
		{ id = "Saturation" },
		{ id = "Gamma" },
		{ id = "DetailClass", },
		{ id = "ForcedLODState", },
		{ id = "TestStateButtons", },
	},
}

for i = 1, const.MaxColorizationMaterials do
	table.iappend( StripCObjectProperties.properties, { 
		{ id = string.format("EditableColor%d", i) },
		{ id = string.format("EditableRoughness%d", i) },
		{ id = string.format("EditableMetallic%d", i) },
	})
end

function CObject:AsyncCheatSpots()
	ToggleSpotVisibility{self}
end

function CObject:CheatDelete()
	DoneObject(self)
end

function CObject:AsyncCheatClassHierarchy()
	DbgShowClassHierarchy(self.class)
end

function CObject:__MarkEntities(entities)
	if not IsValid(self) then return end
	
	entities[self:GetEntity()] = true
	for j = 1, self:GetNumAttaches() do
		local attach = self:GetAttach(j)
		attach:__MarkEntities(entities)
	end
end

function CObject:MarkAttachEntities(entities)
	entities = entities or {}
	
	self:__MarkEntities(entities)
	
	return entities
end

function CObject:AsyncCheatScreenshot()
	IsolatedObjectScreenshot(self)
end

-- Dev functionality
CObjectAllowedMembers = {}
CObjectAllowedDeleteMethods = {}
