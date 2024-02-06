
DefineClass.XDef = {
	__parents = { "Preset", "XDefWindow", },
	properties = {
		{ category = "Preset", id = "__class", name = "Class", editor = "choice", default = "XWindow", show_recent_items = 7, items = function(self) return ClassDescendantsCombo("XWindow", true) end, },
		{ category = "Preset", id = "DefUndefineClass", name = "Undefine class", editor = "bool", default = false, },
	},
	GlobalMap = "XDefs",
	
	ContainerClass = "XDefSubItem",
	PresetClass = "XDef",
	HasCompanionFile = true,
	GeneratesClass = true,
	HasSortKey = true,
	SingleFile = false,
	
	EditorMenubarName = "XDef Editor",
	EditorShortcut = "Alt-Shift-F3",
	EditorName = "XDef",
	EditorMenubar = "Editors.UI",
	EditorIcon = "CommonAssets/UI/Icons/backspace.png",
}

function XDef:GenerateCompanionFileCode(code, dlc)
	local class_exists_err = self:CheckIfIdExistsInGlobal()
	if class_exists_err then
		return class_exists_err
	end
	if self.DefUndefineClass then
		code:append("UndefineClass('", self.id, "')\n")
	end
	code:appendf("DefineClass.%s = {\n", self.id, self.id)
	self:GenerateParents(code)
	self:AppendGeneratedByProps(code)
	self:GenerateFlags(code)
	self:GenerateConsts(code, dlc)
	code:append("}\n\n")
	self:GenerateGlobalCode(code)
end

DefineClass.XDefSubItem = {
	__parents = { "Container" },
	properties = {
		{ category = "Def", id = "comment", name = "Comment", editor = "text", default = "", },
	},
	TreeView = T(357198499972, "<class> <color 0 128 0><comment>"),
	EditorView = Untranslated("<TreeView>"),
	EditorName = "Sub Item",
	ContainerClass = "XDefSubItem",
}

DefineClass.XDefGroup = {
	__parents = { "XDefSubItem" },
	properties = {
		{ category = "Def", id = "__context_of_kind", name = "Require context of kind", editor = "text", default = "" },
		{ category = "Def", id = "__context", name = "Context expression", editor = "expression", params = "parent, context" },
		{ category = "Def", id = "__parent", name = "Parent expression", editor = "expression", params = "parent, context" },
		{ category = "Def", id = "__condition", name = "Condition", editor = "expression", params = "parent, context", },
	},
	TreeView = T(551379353577, "Group<ConditionText> <color 0 128 0><comment>"),
	EditorName = "Group",
}

function XDefGroup.__parent(parent, context)
	return parent
end

function XDefGroup.__context(parent, context)
	return context
end

function XDefGroup.__condition(parent, context)
	return true
end

function XDefGroup:ConditionText()
	if self.__condition == g_Classes[self.class].__condition then
		return ""
	end

	-- get condition as a string
	local name, params, body = GetFuncSource(self.__condition)
	if type(body) == "table" then
		body = table.concat(body, "\n")
	end
	if body then
		body = body:match("^%s*return%s*(.*)") or body
		-- Put a space between < and numbers to avoid treating it like a tag
		body = string.gsub(body, "([%w%d])<(%d)", "%1< %2")
	end
	return body and " <color 128 128 220>cond:" .. body or ""
end

-- function XDefGroup:Eval(parent, context)
-- 	local kind = self.__context_of_kind
-- 	if kind == "" 
-- 		or type(context) == kind
-- 		or IsKindOf(context, kind)
-- 		or (IsKindOf(context, "Context") and context:IsKindOf(kind)) 
-- 	then
-- 		context = self.__context(parent, context)
-- 		parent = self.__parent(parent, context)
-- 		if not self.__condition(parent, context) then
-- 			return
-- 		end
-- 		return self:EvalElement(parent, context)
-- 	end
-- end

-- function XDefGroup:EvalElement(parent, context)
-- 	return self:EvalChildren(parent, context)
-- end

DefineClass.XDefWindow = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Def", id = "__class", name = "Class", editor = "choice", default = "XWindow", show_recent_items = 7,
			items = function() return ClassDescendantsCombo("XWindow", true) end, },
	},
}

function XDefWindow:GetPropertyTabs()
	return XWindowPropertyTabs
end

local eval = prop_eval
function XDefWindow:GetProperties()
	--bp()
	local properties = table.icopy(self.properties)
	local class = g_Classes[self.__class]
	for _, prop_meta in ipairs(class and class:GetProperties()) do
		if not eval(prop_meta.dont_save, self, prop_meta) then
			properties[#properties + 1] = prop_meta
		end
	end
	return properties
end

local modified_base_props = {}

function XDefWindow:SetProperty(id, value)
	rawset(self, id, value)
	modified_base_props[self] = nil
end

function XDefWindow:GetProperty(id)
	local prop = PropertyObject.GetProperty(self, id)
	if prop then
		return prop
	else
		local class = g_Classes[self.__class]
		return class and class:GetDefaultPropertyValue(id)
	end
end

function XDefWindow:GetDefaultPropertyValue(id, prop_meta)
	local prop_default = PropertyObject.GetDefaultPropertyValue(self, id, prop_meta)
	if prop_default then
		return prop_default
	end
	local class = g_Classes[self.__class]
	return class and class:GetDefaultPropertyValue(id, prop_meta) or false
end

-- function XDefWindow:EvalElement(parent, context)
-- 	local class = g_Classes[self.__class]
-- 	assert(class, self.class .. " class not found")
-- 	if not class then return end
-- 	local obj = class:new({}, parent, context, self)
	
-- 	local props = modified_base_props[self]
-- 	if not props then
-- 		props = GetPropsToCopy(self, obj:GetProperties())
-- 		modified_base_props[self] = props
-- 	end
	
-- 	for _, entry in ipairs(props) do
-- 		local id, value = entry[1], entry[2]
-- 		if type(value) == "table" and not IsT(value) then
-- 			value = table.copy(value, "deep")
-- 		end
-- 		obj:SetProperty(id, value)
-- 	end
-- 	self:EvalChildren(obj, context)
-- 	return obj
-- end

-- TODO: Check if an OnXDefSetProperty method is necessary 
function XDefWindow:OnEditorSetProperty(prop_id, old_value)
	-- local class = g_Classes[self.__class]
	-- if class and class:HasMember("OnXTemplateSetProperty") then
	-- 	class.OnXTemplateSetProperty(self, prop_id, old_value)
	-- end
end

function XDefWindow:GetError()
	local class = g_Classes[self.__class]
	if IsKindOf(class, "XContentTemplate") then
		if self:GetProperty("RespawnOnContext") and self:GetProperty("ContextUpdateOnOpen") then
			return "'RespawnOnContext' and 'ContextUpdateOnOpen' shouldn't be simultaneously true. This will cause children to be 'Opened' twice."
		end
	end
	if IsKindOf(class, "XEditableText") then
		if self:GetProperty("Translate") and self:GetProperty("UserText") then
			return "'Translated text' and 'User text' properties can't be both set."
		end
	end
end

DefineClass.XDefWindowSubItem = {
	__parents = { "XDefWindow", "XDefGroup", },
	TreeView = T(700510148795, "<IdNodeColor><__class><ConditionText><opt(PlacementText,' <color 128 128 128>','')><opt(comment,' <color 0 128 0>')>"),
	EditorName = "Window",
}

function XDefWindowSubItem:IdNodeColor()
	local idNode = rawget(self, "IdNode")
	if idNode == false or (idNode == nil and not _G[self.__class].IdNode) then
		return ""
	end
	for _,item in ipairs(self) do
		if IsKindOf(item, "XDefGroup") then
			return "<color 75 105 198>"
		end
	end
	return ""
end

function XDefWindowSubItem:PlacementText()
	local class = g_Classes[self.__class]
	if class and class:IsKindOf("XOpenLayer") then
		return Untranslated(self:GetProperty("Layer") .. " " .. self:GetProperty("Mode"))
	else
		local dock = self:GetProperty("Dock")
		dock = dock and (" Dock:" .. tostring(dock)) or ""
		return Untranslated(self:GetProperty("Id") .. dock)
	end
end

-- TODO: XDefProperty for each ClassDefSubItem except code and function, those two will hve their own equivalent here
-- Give them ContainerClass = "" to disallow children disallow children
-- Make them placeable only on the top level

-- function XDef.__parent(parent, context)
-- 	return parent
-- end

-- function XDef.__context(parent, context)
-- 	return context
-- end

-- function XDef.__condition(parent, context)
-- 	return true
-- end

-- function XWindow:Spawn(args, spawn_children, parent, context, ...)
-- 	local win = self:new(args, parent, context, ...)
-- 	if spawn_children then
-- 		self.SpawnChildren = spawn_children
-- 	end
-- 	self:SpawnChildren(parent, context, ...)
-- 	return win
-- end

--XWindow.SpawnChildren = empty_func

DefineClass.XWindowFlattened = {
	__parents = { "XWindow" },
}

function XWindowFlattened:Spawn(args, spawn_children, parent, context, ...)
	if spawn_children then
		self.SpawnChildren = spawn_children
	end
	self:SpawnChildren(parent, context, ...)
end

---- Example XWindowTest XDef code

-- function test()
-- 	PlaceObj('XDef', {
-- 		group = "Common",
-- 		id = "AAATEST",
-- 		PlaceObj('XDefGroup', {
-- 			'comment', "Human",
-- 			'__context_of_kind', '"Human"',
-- 			'__context', function (parent, context) return context[1] end,
-- 			'__parent', function (parent, context) return parent[2] end,
-- 			'__condition', function (parent, context) return #context < #parent end,
-- 		}, {
-- 			PlaceObj('XDefSubItem', {
-- 				'__parent', function (parent, context) return parent[2] end,
-- 				'LayoutMethod', "HWrap",
-- 			}, {
-- 				PlaceObj('XDefSubItem', {
-- 					'__class', "XText",
-- 					'Id', "idText2",
-- 					'Text', "123",
-- 				}),
-- 			}),
-- 		}),
-- 		PlaceObj('XDefSubItem', {
-- 			'__class', "XText",
-- 			'Id', "idText",
-- 			'Text', "abc",
-- 		}),
-- 		PlaceObj('XDefProperty', {
-- 			'id', "test_prop",
-- 			'default', true,
-- 			'name', Untranslated("Test Prop"),
-- 		}),
-- 	})
-- end


-- ---- Example generated code

-- DefineClass.XWindowTest = {
-- 	__parents = { "XWindow" },
-- 	properties = {
-- 		{ category = "Test", id = "test_prop", name = "Test Prop", editor = "bool", default = true, },
-- 	}
-- }

-- function XWindowTest:SpawnChildren(parent, context)
-- 	-- alternatively remove the indentation with goto Humans
-- 	-- well you cant as local context and parent need to be defined 

-- 	-- XDefGroup
-- 	-- Humans -- coment
-- 	if IsKindOf(context, "Human") then -- __context_of_kind
-- 		local context = context[1] -- __context
-- 		local parent = parent[2] -- __parent
-- 		if #context < #parent then -- __condition
-- 			goto condition_failed
-- 		end
-- 		XWindow:Spawn({
-- 			LayoutMethod = "HWrap",
-- 			__parent = function(self, parent, context)
-- 				return parent
-- 			end,
-- 		}, function(self, parent, context)
-- 			-- passing the spawn children function like this saves an indentation level
-- 			XText:Spawn({
-- 				Id = "idText2",
-- 				Text = "123",
-- 			}, self)
-- 		end, parent, context)
-- 		::condition_failed::
-- 	end
-- 	--::Humans::
	
-- 	XText:Spawn({
-- 		Id = "idText",
-- 		Text = "abc",
-- 	}, parent)
-- end
