DefineClass.Template =
{
	-- It currently inherits CObject because that's all the editor will currently show in default brush mode
	__parents = { "Shapeshifter", "EditorVisibleObject", "EditorTextObject", "EditorCallbackObject" },
	entity = "WayPoint",
	flags = { efWalkable = false, efCollision = false, efApplyToGrids = false },

	properties = {
		{ id = "TemplateOf", category = "Template", editor = "combo", default = "", important = true, items = function(self) return self:GetTemplatesList() end },
		{ id = "autospawn", category = "Template", name = "Autospawn", editor = "bool", default = true },
		{ id = "EditorLabel", category = "Template", editor = "text", default = "", no_edit = true },
		{ id = "Opacity" },
		{ id = "LastSpawnedObject", category = "Template", name = "Last Spawned Object", editor = "object", default = false, read_only = true, dont_save = true },
		{ id = "RemainingHandles", category = "Template", name = "Remaining Handles", editor = "number", default = 0, read_only = true, dont_save = true },
		{ id = "SpawnCount", category = "Template", name = "Spawned Objects", editor = "number", default = 0, read_only = true, dont_save = true },
		{ id = "template_root", category = "Template", name = "Root Class", editor = "text", read_only = true, dont_save = true },
	},

	template_root = "CObject", -- must be set by descendants

	Walkable = false,
	Collision = false,
	ApplyToGrids = false,

	reserved_handles = 10,
	
	editor_text_color = RGB(128,192,128),
	editor_text_member = "TemplateOf",
}

-- template functions
function Template:Init()
	self:SetOpacity(65)
end

function Template:GetLastSpawnedObject()
	return TemplateSpawn[self]
end

function Template:GetRemainingHandles()
	local count = 0
	for i=self.handle+1, self.handle+self.reserved_handles do	
		if not HandleToObject[i] then
			count = count + 1
		end
	end
	return count
end

function Template:GetSpawnCount()
	return self.reserved_handles - self:GetRemainingHandles()
end

local TemplatesListCache = {}
function OnMsg.ClassesBuilt()
	 TemplatesListCache = {}
end
function Template:GetTemplatesList()
	if TemplatesListCache[self.template_root] then
		return TemplatesListCache[self.template_root]
	end
	-- Get all classes that inherit from template_root
	-- WARNING: It will get non-instantiatable classes as well!
	local cache = ClassDescendantsList(self.template_root, function(name, class)
		return class:GetEntity() ~= "" and IsValidEntity(class:GetEntity()) and not name:ends_with("impl", true)
	end)
	TemplatesListCache[self.template_root] = cache
	return cache
end

local template_props = {}
function Template:IsTemplateProperty(id)
	local props = template_props[self.class]
	if not props then
		props = {}
		template_props[self.class] = props
		for i = 1, #self.properties do
			props[self.properties[i].id] = true
		end
	end
	return props[id]
end

function Template:SetProperties(values)
	local template = values.TemplateOf
	if template then
		assert(g_Classes[template], "Invalid template class")
		self:SetProperty("TemplateOf", template)
	end
	
	local props = self:GetProperties()
	for i = 1, #props do
		local id = props[i].id
		local value = values[id]
		if value ~= nil and id ~= "TemplateOf" then
			self:SetProperty(id, value)
		end
	end
end

function Template:GetProperties()
	local template_class = g_Classes[(self.TemplateOf or "") ~= "" and self.TemplateOf or self.template_root]
	local properties = table.copy(self.properties)

	-- move TemplateOf first (it should be at least before StateText property)
	local idx = table.find(properties, "id", "TemplateOf")
	local prop = properties[idx]
	table.remove(properties, idx)
	table.insert(properties, 1, prop)

	local properties2 = template_class:GetProperties()
	for i = 1, #properties2 do
		local p = properties2[i]
		local id = p.id
		if id == "Opacity" then
			-- ignore it
		else
			local template_prop_idx = table.find(properties, "id", id)
			if template_prop_idx then
				if id == "ColorModifier" then
					properties[template_prop_idx] = p
				end
			else
				if (p.editor == "combo" or p.editor == "dropdownlist" or p.editor == "set") and type(p.items) == "function" then
					p = table.copy(p)
					local func = p.items
					p.items = function(o, editor)
						return func(o, editor)
					end
				end
				properties[#properties + 1] = p
			end
		end
	end
	return properties
end

function Template:GetDefaultPropertyValue(prop, prop_meta)
	if not self:IsTemplateProperty(prop) then
		local class = g_Classes[self.TemplateOf]
		if class then
			return class:GetDefaultPropertyValue(prop, prop_meta)
		end
	end
	if prop == "ApplyToGrids" then
		return GetClassEnumFlags(self.TemplateOf or self.class, const.efApplyToGrids)
	elseif prop == "Collision" then
		return GetClassEnumFlags(self.TemplateOf or self.class, const.efCollision)
	elseif prop == "Walkable" then
		return GetClassEnumFlags(self.TemplateOf or self.class, const.efWalkable)
	end
	return CObject.GetDefaultPropertyValue(self, prop, prop_meta)
end

local function TransferValue(class, prop_meta, prev_class, prev_value)
	local prev_prop_meta = prev_class:GetPropertyMetadata(prop_meta.id)
	if prev_prop_meta and prev_prop_meta.editor == prop_meta.editor then
		if not prop_meta.items then return prev_value end

		local items = prop_meta.items
		if type(items) == "function" then items = items(class) end
		if type(items) == "table" then
			for i = 1, #items do
				local item = items[i]
				if item == prev_value or type(item) == "table" and item.value == prev_value then
					return prev_value
				end
			end
		end
	end
end

-- invoked from the editor; transfers as much info as possible
function Template:SetTemplateOf(classname)
	local prev_class = g_Classes[self.TemplateOf]
	local class = g_Classes[classname]
	assert(class and class:IsKindOf(self.template_root) or classname == "WayPoint", "Invalid template class: " .. classname)
	if not class then
		return
	end

	if prev_class then
		-- remove default property values so they're not transfered to the new template class
		local props = prev_class.properties
		for i = 1, #props do
			local prop_meta = props[i]
			local prop = prop_meta.id
			if not self:IsTemplateProperty(prop) then
				local value = rawget(self, prop)
				if value ~= nil and prev_class:IsDefaultPropertyValue(prop, prop_meta, value) then
					self[prop] = nil
				end
			end
		end
	end

	self.TemplateOf = classname
	self:DestroyAttaches()

	local entity = class:GetEntity()
	if entity == "" then entity = Template.entity end
	self:ChangeEntity(entity)
	-- reset collision flags to their defaults for the new class
	self.ApplyToGrids = GetClassEnumFlags(classname, const.efApplyToGrids)
	self.Collision = GetClassEnumFlags(classname, const.efCollision)
	self.Walkable = GetClassEnumFlags(classname, const.efWalkable)

	if prev_class then
		local props = class.properties
		for i = 1, #props do
			local prop_meta = props[i]
			local prop = prop_meta.id

			if not self:IsTemplateProperty(prop) then
				local value = rawget(self, prop)
			
				if value ~= nil then
					self[prop] = TransferValue(class, prop_meta, prev_class, value)
				end
			end
		end
	end
end

function Template:EditorCallbackPlace()
	if not self.TemplateOf then
		if self.template_root == "CObject" then
			self:SetTemplateOf("WayPoint")
		else
			local list = self:GetTemplatesList()
			if list and #list > 0 then
				self:SetTemplateOf(list[1])
			else
				self:SetTemplateOf("WayPoint")
			end
		end
	end
	self:RandomizeProperties()
	self:TemplateApplyProperties()
end

function Template:EditorCallbackClone()
	assert(g_Classes[self.TemplateOf])
	self:RandomizeProperties()
	self:TemplateApplyProperties()
end

function Template:OnEditorSetProperty(prop_id)
	assert(g_Classes[self.TemplateOf])
	self:TemplateClearProperties()
	self:TemplateApplyProperties()
	if prop_id == "TemplateOf" then
		ObjModified(self)
	end
end

function Template.TurnTemplatesIntoObjects(list)
	local listOfObjsToDestroy = {}
	for i = 1, #list do
		local t = list[i]
		if t:IsKindOf("Template") then
			local obj = t:Spawn()
			if obj then
				obj:SetGameFlags(const.gofPermanent)
				list[i] = obj
				table.insert(listOfObjsToDestroy,t)
			end
		end
	end
	DoneObjects(listOfObjsToDestroy)
	return list
end

g_convert_template_order = { "Template" }
function Template.TurnObjectsIntoTemplates(list)
	local listOfObjsToDestroy = {}
	for i = 1, #list do
		local o = list[i]
		local template_class
		if not o:IsKindOf("Template") and o:GetGameFlags(const.gofPermanent) ~= 0 then
			for j = 1, #g_convert_template_order do
				local template_class = g_convert_template_order[j]
				if o:IsKindOf(g_Classes[template_class].template_root) then
					local template = PlaceObject(template_class)
					template:SetTemplateOf(o.class)
					template:CopyProperties(o)
					-- Boilerplate Stuff
					template:SetEnumFlags(const.efVisible)
					template:SetGameFlags(const.gofPermanent)
					template.SpawnCheckpoint = "Start"
					template:TemplateApplyProperties()
					list[i] = template
					table.insert(listOfObjsToDestroy,o)
					break
				end
			end
		end
	end
	DoneObjects(listOfObjsToDestroy)
	return list
end

function Template:GetProperty(property)
	if self:IsTemplateProperty(property) then
		return PropertyObject.GetProperty(self, property)
	end
	local value = rawget(self, property)
	if value ~= nil then
		return value
	end
	local class = g_Classes[self.TemplateOf]
	if class then
		return class:GetDefaultPropertyValue(property)
	end
end

function Template:SetProperty(property, value)
	if self:IsTemplateProperty(property) then
		return PropertyObject.SetProperty(self, property, value)
	end
	self[property] = value
	return true
end

function Template:TemplateClearProperties()
	local template_class = g_Classes[self.TemplateOf]
	if template_class and template_class:HasMember("TemplateClearProperties") then
		local old_meta = getmetatable(self)
		setmetatable(self, template_class) -- pretend to be an instance of template_class, instead of template
		self:TemplateClearProperties(template_class)
		setmetatable(self, old_meta) -- return to being a template again
	end
end

function Template:TemplateApplyProperties()
	local template_class = g_Classes[self.TemplateOf]
	if template_class and template_class:HasMember("TemplateApplyProperties") then
		local old_meta = getmetatable(self)
		setmetatable(self, template_class) -- pretend to be an instance of template_class, instead of template
		self.GetProperty = old_meta.GetProperty
		rawset(self, "IsTemplateProperty", old_meta.IsTemplateProperty)
		self:TemplateApplyProperties(template_class)
		self.GetProperty = nil
		self.IsTemplateProperty = nil
		setmetatable(self, old_meta) -- return to being a template again
	end
end

function Template:RandomizeProperties(seed)
	local template_class = g_Classes[self.TemplateOf]
	if template_class then
		local old_meta = getmetatable(self)
		setmetatable(self, template_class) -- pretend to be an instance of template_class, instead of template
		self:RandomizeProperties(seed)
		setmetatable(self, old_meta) -- return to being a template again
	end
end

function Template:CopyProperties(source, properties)
	if IsKindOf(source, "Template") then
		self:SetTemplateOf(source.TemplateOf)
	else
		self:SetTemplateOf(source.class)
	end
	Object.CopyProperties(self, source, properties)
end

MapVar("TemplateSpawn", {}) -- todo: handle the case of multiplayer

function Template:Spawn()
	-- Some templates can only be spawned on e.g. "easy"
	local handle
	for i=self.handle+1, self.handle+self.reserved_handles do	
		if not HandleToObject[i] then
			handle = i
			break
		end
	end
	if not handle then return end
	local object = PlaceObject(self.TemplateOf, { handle = handle } )
	if not object then return end
	object:CopyProperties(self, object:GetProperties())
	
	if object:IsKindOf("Hero") and not (object.groups and table.find(object.groups, object.class)) then
		object:AddToGroup(object.class)
	end
	TemplateSpawn[self] = object
	if object:HasMember("spawned_by_template") then
		object.spawned_by_template = self
	end
	Msg(self)
	return object
end

function Template:EditorEnter()
	self:TemplateApplyProperties()
end

function Template:EditorExit()
	self:TemplateClearProperties()
end

function Template:GetApplyToGrids()
	return self.ApplyToGrids
end

function Template:SetApplyToGrids(value)
	self.ApplyToGrids = value
end

function Template:GetCollision()
	return self.Collision
end

function Template:SetCollision(value)
	self.Collision = value
end

function Template:GetWalkable()
	return self.Walkable
end

function Template:SetWalkable(value)
	self.Walkable = value
end

function Template:__enum()
	if self.TemplateOf and _G[self.TemplateOf] then
		return _G[self.TemplateOf]:__enum()
	end
	return PropertyObject.__enum(self)
end

function ResolveObjectRef(obj)
	if IsValid(obj) and obj:IsKindOf("Template") then
		return TemplateSpawn[obj]
	end
	return obj
end

function WaitResolveObjectRef(obj)
	if IsValid(obj) and obj:IsKindOf("Template") then
		if not TemplateSpawn[obj] then
			WaitMsg(obj)
		end
		return TemplateSpawn[obj]
	end
	return obj
end

function IsTemplateOrClass(obj, class)
	if obj:IsKindOf(class) then return true end
	return obj:IsKindOf("Template") and rawget(_G, obj.TemplateOf) and _G[obj.TemplateOf]:IsKindOf(class)
end

function IsTemplateOrClasses(obj, classes)
	if obj:IsKindOfClasses(classes) then return true end
	return obj:IsKindOf("Template") and rawget(_G, obj.TemplateOf) and _G[obj.TemplateOf]:IsKindOfClasses(classes)
end

function GetTemplateGroupsComboList()
	local list = { "Disabled","Default Spawn"}
	for k,group in pairs(groups) do
		for j=1, #group do
			if IsValid(group[j]) and group[j]:IsKindOf("TemplateOpponent") then
				list[#list + 1] = k
				break
			end
		end
	end
	table.sort(list)
	return list
end

function CreateClassShapeshifter(classname)
	local o = PlaceObject("ShapeshifterClass")
	o:ChangeClass(classname)
	o:SetGameFlags(const.gofSyncState)

	local t = PlaceObject("Template")
	t:SetTemplateOf(classname)
	t:RandomizeProperties()
	t:TemplateApplyProperties()

	o:SetColorModifier(t:GetColorModifier())
	for i = t:GetNumAttaches(), 1, -1 do
		local attach = t:GetAttach(i)
		local attach_spot = attach:GetAttachSpot()
		o:Attach(attach, attach_spot)
	end
	DoneObject(t)
	return o
end

function Template:GetEditorLabel()
	local template_class = g_Classes[self.TemplateOf]
	local template_label = template_class and template_class:GetProperty("EditorLabel")
	return "Template of " .. (template_label or self.TemplateOf)
end