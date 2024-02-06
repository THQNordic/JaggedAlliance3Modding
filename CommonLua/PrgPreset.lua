const.TagLookupTable["keyword"] = "<color 75 105 198>"
const.TagLookupTable["/keyword"] = "</color>"

if Platform.developer then
	function prgdbg(li, level, idx)
		li[level] = idx
		Msg("OnPrgLine", li)
	end
else
	prgdbg = empty_func
end

g_PrgPresetPropsCache = {}

DefineClass.PrgPreset = {
	__parents = { "Preset" },
	
	properties = {
		{ id = "Params", editor = "string_list", default = {} },
	},
	
	SingleFile = false,
	ContainerClass = "PrgStatement",
	EditorMenubarName = false,
	HasCompanionFile = true,
	
	StatementTags = { "Basics" }, -- list the PrgStatement tags usable in this Prg class
	FuncTable = "Prgs", -- override in child classes
}

function PrgPreset:GenerateFuncName()
	return self.id
end

function PrgPreset:GetParamString()
	return table.concat(self.Params, ", ")
end

function PrgPreset:GenerateCodeAtFunctionStart(code)
	code:append("\tlocal rand = BraidRandomCreate(seed or AsyncRand())\n")
end

function PrgPreset:GenerateCompanionFileCode(code)
	-- generate static code
	local has_statements = false
	for _, statement in ipairs(self) do
		if not statement.Disable then
			local len = code:size()
			statement:GenerateStaticCode(code)
			if len ~= code:size() then
				code:append("\n")
				has_statements = true
			end
		end
	end
	if has_statements then
		code:append("\n")
	end
	
	-- generate function code
	code:appendf("rawset(_G, '%s', rawget(_G, '%s') or {})\n", self.FuncTable, self.FuncTable)
	code:appendf("%s.%s = function(seed, %s)\n", self.FuncTable, self:GenerateFuncName(), self:GetParamString())
	code:appendf("\tlocal li = { id = \"%s\" }\n", self.id)
	self:GenerateCodeAtFunctionStart(code)
	for idx, statement in ipairs(self) do
		if not statement.Disable then
			statement:GenerateCode(code, "\t", idx)
			code:append("\n")
		end
	end
	code:append("end")
end

function PrgPreset:EditorContext()
	local context = Preset.EditorContext(self)
	context.ContainerTree = true
	return context
end

function PrgPreset:FilterSubItemClass(class)
	return not class.StatementTag or table.find(self.StatementTags, class.StatementTag)
end

function OnMsg.ClassesBuilt()
	local undefined = ClassLeafDescendantsList("PrgStatement", function(name, class) return not class.StatementTag end)
	assert(#undefined == 0, string.format("Prg statement %s has no StatementTag defined.", undefined[1]))
	
	-- add a validate function to enforce variables names to be identifiers
	ClassLeafDescendantsList("PrgStatement", function(name, class)
		for _, prop_meta in ipairs(class:GetProperties()) do
			if prop_meta.items == PrgVarsCombo or prop_meta.variable then
				prop_meta.validate = function(self, value) 
					return ValidateIdentifier(self, value)
				end
			end
		end
	end)
end


----- Statement & Block

function PrgVarsCombo()
	return function(obj)
		local vars = table.keys(obj:VarsInScope())
		table.insert(vars, "")
		table.sort(vars)
		return vars
	end
end

function PrgLocalVarsCombo()
	return function(obj)
		local vars = {}
		for k, v in pairs(obj:VarsInScope()) do
			if v ~= "static" then
				vars[#vars + 1] = k
			end
		end
		table.insert(vars, "")
		table.sort(vars)
		return vars
	end
end

DefineClass.PrgStatement = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Disable", editor = "bool", default = false, },
	},
	DisabledPrefix = Untranslated("<if(Disable)><style GedError>[Disabled] </style></if>"),
	EditorName = "Command",
	StoreAsTable = true,
	StatementTag = false, -- each PrgStatement must have a tag; each PrgPreset defines the list of tags that can be used in it
}

function PrgStatement:VarsInScope()
	local vars = {}
	local current = self
	local block = GetParentTableOfKindNoCheck(self, "PrgBlock", "PrgPreset")
	while block do
		for _, statement in ipairs(block) do
			if statement ~= self then
				statement:GatherVars(vars)
			end
			if statement == current then break end
		end
		current = block
		block = GetParentTableOfKindNoCheck(block, "PrgBlock", "PrgPreset")
	end
	-- 'current' is now the PrgPreset
	for _, var in ipairs(current.Params) do
		vars[var] = true
	end
	vars[""] = nil -- skip "" vars due to unset properties
	return vars
end

function PrgStatement:LinePrefix(indent, idx)
	return string.format("%sprgdbg(li, %d, %d) ", indent, #indent, idx)
end

function PrgStatement:GatherVars(vars)
	-- add variables declared by this statement as keys in the 'vars' table, with value "local" or "static"
end

function PrgStatement:GenerateStaticCode(code)
	-- generate code to be inserted before the Prg function body, generates the code that declares the static vars
end

function PrgStatement:GenerateCode(code, indent, idx)
	-- generate code for the Prg function body
end

function PrgStatement:GetEditorView()
	return _InternalTranslate(Untranslated("<DisabledPrefix>"), self, false) .. _InternalTranslate(self.EditorView, self, false)
end

DefineClass.PrgBlock = {
	__parents = { "PrgStatement", "Container" },
	ContainerClass = "PrgStatement",
}

function PrgBlock:GenerateStaticCode(code)
	if #self == 0 then return end
	for i = 1, #self - 1 do
		self[i]:GenerateStaticCode(code)
	end
	self[#self]:GenerateStaticCode(code)
end

function PrgBlock:GenerateCode(code, indent, idx)
	if #self == 0 then return end
	indent = indent .. "\t"
	for i = 1, #self - 1 do
		if not self[i].Disable then
			self[i]:GenerateCode(code, indent, i)
			code:append("\n")
		end
	end
	if not self[#self].Disable then
		self[#self]:GenerateCode(code, indent, #self)
		code:appendf(" li[%d] = nil", #indent)
	end
end


----- Variables

local function get_expr_string(expr)
	if not expr or expr == empty_func then return "nil" end
	
	local name, parameters, body = GetFuncSource(expr)
	body = type(body) == "table" and table.concat(body, "\n") or body
	return body:match("^%s*return%s*(.*)") or body
end

DefineClass.PrgAssign = {
	__parents = { "PrgStatement" },
	properties = {
		{ id = "Variable", editor = "combo", default = "", items = PrgLocalVarsCombo, },
	},
	EditorView = Untranslated("<Variable> = <ValueDescription>"),
}

function PrgAssign:GatherVars(vars)
	vars[self.Variable] = "local"
end

function PrgAssign:GenerateCode(code, indent, idx)
	local var_exists = self:VarsInScope()[self.Variable]
	code:appendf("%s%s%s = %s", self:LinePrefix(indent, idx), var_exists and "" or "local ", self.Variable, self:GetValueCode())
end

function PrgAssign:GetValueCode()
	-- define in child classes
end

function PrgAssign:GetValueDescription()
	-- define in child classes
end

DefineClass.PrgAssignExpr = {
	__parents = { "PrgAssign" },
	properties = {
		{ id = "Value", editor = "expression", default = empty_func },
	},
	EditorName = "Set variable",
	EditorSubmenu = "Basics",
	StatementTag = "Basics",
}

function PrgAssignExpr:GetValueCode()
	return get_expr_string(self.Value)
end

function PrgAssignExpr:GetValueDescription()
	return get_expr_string(self.Value)
end


----- Flow control - if / else, while, loops

DefineClass.PrgIf = {
	__parents = { "PrgBlock" },
	properties = {
		{ id = "Repeat", name = "Repeat while satisfied", editor = "bool", default = false, },
		{ id = "Condition", editor = "expression", default = empty_func, },
	},
	EditorName = "Condition check (if/while)",
	EditorSubmenu = "Code flow",
	StatementTag = "Basics",
}

function PrgIf:GetExprCode(for_preview)
	return get_expr_string(self.Condition)
end

function PrgIf:GenerateCode(code, indent, idx)
	code:appendf(self.Repeat and "%swhile %s do\n" or "%sif %s then\n", self:LinePrefix(indent, idx), self:GetExprCode(false))
	PrgBlock.GenerateCode(self, code, indent)
	
	local parent = GetParentTableOfKind(self, "PrgBlock") or GetParentTableOfKind(self, "PrgPreset")
	local next_statement = parent[table.find(parent, self) + 1]
	if not IsKindOf(next_statement, "PrgElse") then
		code:appendf("\n%send", indent)
	end
end

function PrgIf:GetEditorView()
	return Untranslated("<DisabledPrefix>" .. (self.Repeat and "<keyword>while</keyword> " or "<keyword>if</keyword> ") .. self:GetExprCode(true))
end

DefineClass.PrgElse = {
	__parents = { "PrgBlock" },
	EditorName = "Condition else",
	EditorView = Untranslated("<keyword>else</keyword>"),
	EditorSubmenu = "Code flow",
	StatementTag = "Basics",
}

function PrgElse:GenerateCode(code, indent, idx)
	if self:CheckPrgError() then return end
	code:appendf("%selse\n\t%s\n", indent, self:LinePrefix(indent, idx))
	PrgBlock.GenerateCode(self, code, indent, idx)
	code:appendf("\n%send", indent)
end

function PrgElse:CheckPrgError()
	local parent = GetParentTableOfKind(self, "PrgBlock") or GetParentTableOfKind(self, "PrgPreset")
	local prev_statement = parent[table.find(parent, self) - 1]
	return not IsKindOf(prev_statement, "PrgIf") or prev_statement.Repeat
end

DefineClass.PrgForEach = {
	__parents = { "PrgBlock" },
	properties = {
		{ id = "List", name = "List variable", editor = "choice", default = "", items = PrgVarsCombo, },
		{ id = "Value", name = "Value variable", editor = "text", default = "value" },
		{ id = "Index", name = "Index variable", editor = "text", default = "i", },
	},
	EditorName = "For each",
	EditorView = Untranslated("<keyword>for each</keyword> '<Value>' <keyword>in</keyword> '<List>'"),
	EditorSubmenu = "Code flow",
	StatementTag = "Basics",
}

function PrgForEach:GatherVars(vars)
	vars[self.List] = "local"
	vars[self.Value] = "local"
	vars[self.Index] = "local"
end

function PrgForEach:GenerateCode(code, indent, idx)
	if self.List == "" then return end
	code:appendf("%sfor %s, %s in ipairs(%s) do\n", self:LinePrefix(indent, idx), self.Index, self.Value, self.List)
	PrgBlock.GenerateCode(self, code, indent)	
	code:appendf("\n%send", indent)
end


----- Calls (function and Prg)

-- calls self:Exec with sprocall, passing all property values in order as parameters
DefineClass.PrgExec = {
	__parents = { "PrgStatement" },
	ExtraParams = {}, -- extra params to pass before the properties, e.g. { "rand" } to use the random generator for the Prg
	AssignTo = "", -- variable name to assign function result to; create a property with the same name to allow the user specify it
	PassClassAsSelf = true,
}

function PrgExec:GetParamProps()
	return self:GetProperties()
end

function PrgExec:GetParamString()
	local params = self.PassClassAsSelf and { self.class } or {}
	table.iappend(params, self.ExtraParams)
	for _, prop in ipairs(self:GetParamProps()) do
		if prop.editor ~= "help" and prop.editor ~= "buttons" and prop.id ~= "Disable" then
			local value = self:GetProperty(prop.id)
			params[#params + 1] =
				type(value) == "function"     and get_expr_string(value) or
				prop.variable and value == "" and "nil"                  or
				prop.variable and value ~= "" and value                  or ValueToLuaCode(value):gsub("[\t\r\n]", "")
		end
	end
	return table.concat(params, ", ")
end

function PrgExec:GatherVars(vars)
	vars[self.AssignTo] = "local"
end

function PrgExec:GenerateCode(code, indent, idx)
	if self.AssignTo and self.AssignTo ~= "" then
		local var_exists = self:VarsInScope()[self.AssignTo]
		code:appendf("%slocal _%s\n", indent, var_exists and "" or ", " .. self.AssignTo)
		code:appendf("%s_, %s = sprocall(%s.Exec, %s)", self:LinePrefix(indent, idx), self.AssignTo, self.class, self:GetParamString())
	else
		code:appendf("%ssprocall(%s.Exec, %s)", self:LinePrefix(indent, idx), self.class, self:GetParamString())
	end
end

function PrgExec:Exec(...)
	-- IMPORTANT: 'self' will be the class and not the instance
	-- implement the function to execute here; all properties of your class are passed AS PARAMETERS in the order of their declaration
end

-- override to "export" an existing Lua function as a Prg statement
DefineClass.PrgFunction = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "VarArgs", name = "Add extra parameters", editor = "string_list", default = false, no_edit = function(self) return not self.HasExtraParams end },
	},
	
	PassClassAsSelf = false,
	
	Params = "", -- specify comma-separated parameters here
	HasExtraParams = false, -- has variable arguments?
	Exec = empty_func, -- function to execute
}

function PrgFunction:GetParamProps()
	local props = {}
	for param in string.gmatch(self.Params, "[^, ]+") do
		props[#props + 1] = { id = param, editor = "expression", default = empty_func, }
	end
	return props
end

function PrgFunction:GetProperties()
	local props = g_PrgPresetPropsCache[self]
	if not props then
		props = self:GetParamProps()
		local class_props = table.copy(PropertyObject.GetProperties(self), "deep")
		local idx = table.find(class_props, "id", "VarArgs")
		if idx then
			table.insert(props, class_props[idx])
			table.remove(class_props, idx)
		end
		table.iappend(class_props, props)
		g_PrgPresetPropsCache[self] = class_props
	end
	return props
end

function PrgFunction:GetParamString()
	local ret = PrgExec.GetParamString(self)
	if self.HasExtraParams and self.VarArgs then
		local extra = table.concat(self.VarArgs, ", ")
		ret = ret == "" and extra or (ret .. ", " .. extra)
	end
	return ret
end

-- call any Lua function by name
DefineClass.PrgCallLuaFunction = {
	__parents = { "PrgFunction" },
	properties = {
		{ id = "FunctionName", name = "Function name", editor = "text", default = "",
			validate = function(self, value)
				return value ~= "" and not self:FindFunction(value) and "Can't find function with the specified name"
			end,
			help = "Lua function to call - use Object:MethodName if you'd like to call a class method."
		},
	},
	StoreAsTable = false, -- so SetFunctionName gets called upon loading
	
	EditorName = "Call function",
	EditorView = Untranslated("Call <FunctionName>(<ParamString>)"),
	EditorSubmenu = "Code flow",
	StatementTag = "Basics",
}

function PrgCallLuaFunction:FindFunction(fn_name)
	local ret = _G
	for field in string.gmatch(fn_name, "[^:. ]+") do
		ret = rawget(ret, field)
		if not ret then return end
	end
	return fn_name ~= "" and ret
end

function PrgCallLuaFunction:SetFunctionName(fn_name)
	if self.FunctionName == fn_name then return end
	
	local fn = self:FindFunction(fn_name)
	local name, parameters, body = GetFuncSource(fn)
	if name then
		local extra = parameters:ends_with(", ...")
		self.Params = extra and parameters:sub(1, -6) or parameters
		self.HasExtraParams = extra
	else
		self.Params = nil
		self.HasExtraParams = nil
	end
	if string.find(fn_name, ":") then
		self.Params = self.Params == "" and "self" or ("self, " .. self.Params)
	end
	self.FunctionName = fn_name
	g_PrgPresetPropsCache[self] = nil
end

function PrgCallLuaFunction:GenerateCode(code, indent, idx)
	code:appendf("%ssprocall(%s, %s)",  self:LinePrefix(indent, idx), self.FunctionName:gsub(":", "."), self:GetParamString())
end

DefineClass.PrgCallPrgBase = {
	__parents = { "PrgStatement" },
	properties = {
	   { id = "PrgClass", name = "Prg class", editor = "choice", default = "", items = ClassDescendantsCombo("PrgPreset") },
	   { id = "PrgGroup", name = "Prg preset group", editor = "choice", default = "",
	     items = function(self) return PresetGroupsCombo(self.PrgClass) end, 
	     no_edit = function(self) return self.PrgClass == "" or g_Classes[self.PrgClass].GlobalMap end, },
		{ id = "Prg", editor = "preset_id", default = "",
		  preset_group = function(self) return self.PrgGroup ~= "" and self.PrgGroup end,
		  preset_class = function(self) return self.PrgClass ~= "" and self.PrgClass or "PrgPreset" end },
	},
	
	EditorName = "Call Prg",
	EditorView = Untranslated("Call Prg '<Prg>'"),
	EditorSubmenu = "Code flow",
	StatementTag = "Basics",
}

function PrgCallPrgBase:GetProperties()
	local prg = self.Prg ~= "" and PresetIdPropFindInstance(self, table.find_value(self.properties, "id", "Prg"), self.Prg)
	if not prg then return self.properties end
	
	local props = g_PrgPresetPropsCache[self]
	if not props then
		props = table.copy(PropertyObject.GetProperties(self), "deep")
		for _, param in ipairs(prg.Params or empty_table) do
			props[#props + 1] = { id = param, editor = "expression", default = empty_func, }
		end
		g_PrgPresetPropsCache[self] = props
	end
	return props
end

function PrgCallPrgBase:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "PrgClass" then
		self.PrgGroup = self.PrgClass ~= "" and not g_Classes[self.PrgClass].GlobalMap and PresetGroupsCombo(self.PrgClass)()[2] or ""
	end
	if prop_id == "PrgClass" or prop_id == "PrgGroup" then
		self.Prg = nil
	end
	if prop_id == "PrgClass" or prop_id == "PrgGroup" or prop_id == "Prg" then
		local prop_cache = g_PrgPresetPropsCache[self]
		for _, prop in ipairs(prop_cache) do
			if not table.find(self.properties, "id", prop.id) then
				self[prop.id] = nil
			end
		end
		g_PrgPresetPropsCache[self] = nil
	end
end

function PrgCallPrgBase:OnAfterEditorNew()
	local parent_prg = GetParentTableOfKind(self, "PrgPreset")
	self.PrgClass = parent_prg.class
	self.PrgGroup = self.PrgClass ~= "" and not g_Classes[self.PrgClass].GlobalMap and PresetGroupsCombo(self.PrgClass)()[2] or ""
end

DefineClass("PrgCallPrg", "PrgCallPrgBase")

function PrgCallPrg:GetParamString()
	local prg = PresetIdPropFindInstance(self, table.find_value(self.properties, "id", "Prg"), self.Prg)
	local params = {}
	for _, param in ipairs(prg.Params or empty_table) do
		params[#params + 1] = get_expr_string(rawget(self, param))
	end
	return table.concat(params, ", ")
end

function PrgCallPrg:GenerateCode(code, indent, idx)
	if self.PrgClass == "" or self.Prg == "" then return end
	
	local prg = PresetIdPropFindInstance(self, table.find_value(self.properties, "id", "Prg"), self.Prg)
	if prg then
		code:appendf("%ssprocall(%s.%s, rand(), %s)", self:LinePrefix(indent, idx), prg.FuncTable, prg:GenerateFuncName(), self:GetParamString())
	end
end

DefineClass.PrgPrint = {
	__parents = { "PrgFunction" },
	Params = "",
	HasExtraParams = true,
	Exec = print,
	EditorName = "Print on console",
	EditorView = Untranslated("Print <ParamString>"),
	EditorSubmenu = "Basics",
	StatementTag = "Basics",
}

DefineClass.PrgExecuteEffects = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "Effects", editor = "nested_list", default = false, base_class = "Effect", all_descendants = true },
	},
	EditorName = "Execute effects",
	EditorSubmenu = "Basics",
	StatementTag = "Effects",
}

function PrgExecuteEffects:GetEditorView()
	local items = { _InternalTranslate("<DisabledPrefix>Execute effects:", self, false) }
	for _, effect in ipairs(self.Effects or empty_table) do
		items[#items + 1] = "--> " .. _InternalTranslate(Untranslated("<EditorView>"), effect, false)
	end
	return table.concat(items, "\n")
end

function PrgExecuteEffects:Exec(effects)
	return ExecuteEffectList(effects)
end


----- Get objects (add/remove/assign a list of objects to a variable)

DefineClass.PrgGetObjs = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "Action", editor = "choice", default = "Assign", items = { "Assign", "Add to", "Remove from" }, },
		{ id = "AssignTo", name = "Objects variable", editor = "combo", default = "", items = PrgVarsCombo, variable = true, },
	},
	EditorSubmenu = "Objects",
	StatementTag = "Objects",
}

function PrgGetObjs:GetEditorView()
	local prefix = _InternalTranslate("<DisabledPrefix>", self, false)
	if self.Action == "Assign" then
		return string.format("'%s' = %s", self.AssignTo, self:GetObjectsDescription())
	elseif self.Action == "Add to" then
		return string.format("'%s' += %s", self.AssignTo, self:GetObjectsDescription())
	else -- if self.Action == "Remove from" then
		return string.format("'%s' -= %s", self.AssignTo, self:GetObjectsDescription())
	end
end

function PrgGetObjs:Exec(Action, AssignTo, ...)
	if self.Action == "Assign" then
		return self:GetObjects(...)
	elseif self.Action == "Add to" then
		local objs = IsKindOf(AssignTo, "Object") and { AssignTo } or AssignTo or {}
		return table.iappend(objs, self:GetObjects(...))
	else -- if self.Action == "Remove from" then
		local objs = IsKindOf(AssignTo, "Object") and { AssignTo } or AssignTo or {}
		return table.subtraction(objs, self:GetObjects(...))
	end
	return AssignTo
end

function PrgGetObjs:GetObjectsDescription()
	-- return a text that describes the objects here, e.g. "enemy units of the unit in 'Variable'"
end

function PrgGetObjs:GetObjects(...)
	-- the properties after Action and Variable are passed to this function; return the list of objects here
end

DefineClass.GetObjectsInGroup = {
__parents = { "PrgGetObjs" },
	properties = {
		{ id = "Group", editor = "choice", default = "", items = function() return table.keys2(Groups, true, "") end, },
	},
	EditorName = "Get objects from group",
}

function GetObjectsInGroup:GetObjectsDescription()
	return string.format("objects from group '%s'", self.Group)
end

function GetObjectsInGroup:GetObjects(Group)
	return table.copy(Groups[Group] or empty_table)
end


----- Object list filtering

DefineClass.PrgFilterObjs = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "AssignTo", name = "Objects variable", editor = "combo", default = "", items = PrgVarsCombo, variable = true, },
	},
	EditorSubmenu = "Objects",
	StatementTag = "Objects",
}

DefineClass.FilterByClass = {
	__parents = { "PrgFilterObjs" },
	properties = {
		{ id = "Classes", editor = "string_list", default = false, items = ClassDescendantsCombo("Object"), arbitrary_value = true, },
		{ id = "Negate", editor = "bool", default = false, },
	},
	EditorName = "Filter by class",
}

function FilterByClass:GetEditorView()
	return self.Negate and
		string.format("Leave only objects of classes %s in '%s'", table.concat(self.Classes, ", "), self.AssignTo) or
		string.format("Remove objects of classes %s in '%s'", table.concat(self.Classes, ", "), self.AssignTo)
end

function FilterByClass:Exec(objs, Negate, Classes)
	return table.ifilter(objs, function(i, obj) return Negate == not IsKindOfClasses(obj, table.unpack(Classes)) end)
end

DefineClass.SelectObjectsAtRandom = {
	__parents = { "PrgFilterObjs" },
	properties = {
		{ id = "Percentage", editor = "number", default = 100, min = 1, max = 100, slider = true },
		{ id = "MaxCount", editor = "number", default = 0, },
	},
	ExtraParams = { "rand" },
	EditorName = "Filter at random",
}

function SelectObjectsAtRandom:GetEditorView()
	if self.MaxCount <= 0 then
		return string.format("Leave %d%% of the objects in '%s'", self.Percentage, self.AssignTo)
	elseif self.Percentage == 100 then
		return string.format("Leave no more than %d objects in '%s'", self.MaxCount, self.AssignTo)
	else
		return string.format("Leave %d%% of the objects in '%s', but no more than %d", self.Percentage, self.AssignTo, self.MaxCount)
	end
end

function SelectObjectsAtRandom:Exec(rand, objs, Percentage, MaxCount)
	local count = MulDivRound(#objs, Percentage, 100)
	if MaxCount > 0 then
		count = Min(count, MaxCount)
	end
	
	local ret, taken, len = {}, {}, #objs
	--local added = {}
	while count > 0 do
		local idx = rand(len) + 1
		ret[count] = objs[taken[idx] or idx]
		--assert(not added[ret[count]])
		--added[ret[count]] = true
		count, len = count - 1, len - 1
		taken[idx] = taken[len] or len
	end
	return ret
end


----- Others

DefineClass.DeleteObjects = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "ObjectsVar", name = "Objects variable", editor = "choice", default = "", items = PrgLocalVarsCombo, variable = true, },
	},
	EditorName = "Delete objects",
	EditorView = Untranslated("Delete the objects in '<ObjectsVar>'"),
	EditorSubmenu = "Objects",
	StatementTag = "Objects",
}

function DeleteObjects:Exec(ObjectsVar)
	ObjectsVar = ObjectsVar or empty_table
	XEditorUndo:BeginOp{ objects = ObjectsVar } -- does nothing if outside of editor
	if IsEditorActive() then
		Msg("EditorCallback", "EditorCallbackDelete", ObjectsVar)
	end
	for _, obj in ipairs(ObjectsVar) do obj:delete() end
	XEditorUndo:EndOp()
end
