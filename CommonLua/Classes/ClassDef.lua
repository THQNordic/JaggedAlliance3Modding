DefineClass.PropertyTabDef = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "TabName", editor = "text", default = "" },
		{ id = "Categories", editor = "set", default = {}, items = function(self)
				local class_def = GetParentTableOfKind(self, "ClassDef")
				local categories = {}
				for _, classname in ipairs(class_def.DefParentClassList) do
					local base = g_Classes[classname]
					for _, prop_meta in ipairs(base and base:GetProperties()) do
						categories[prop_meta.category or "Misc"] = true
					end
				end
				for _, subitem in ipairs(class_def) do
					if IsKindOf(subitem, "PropertyDef") then
						categories[subitem.category or "Misc"] = true
					end
				end
				return table.keys2(categories, "sorted")
			end
		}
	},
	GetEditorView = function(self)
		return string.format("%s - %s", self.TabName, table.concat(table.keys2(self.Categories or empty_table), ", "))
	end,
}

DefineClass.ClassDef = {
	__parents = { "Preset" },
	properties = {
		{ id = "DefParentClassList", name = "Parent classes", editor = "string_list", items = function(obj, prop_meta, validate_fn)
				if validate_fn == "validate_fn" then
					-- function for preset validation, checks whether the property value is from "items"
					return "validate_fn", function(value, obj, prop_meta)
						return value == "" or g_Classes[value]
					end
				end
				return table.keys2(g_Classes, true, "")
			end
		},
		{ id = "DefPropertyTranslation", name = "Translate property names", editor = "bool", default = false, },
		{ id = "DefStoreAsTable", name = "Store as table", editor = "choice", default = "inherit", items = { "inherit", "true", "false" } },
		{ id = "DefPropertyTabs", name = "Property tabs", editor = "nested_list", base_class = "PropertyTabDef", inclusive = true, default = false, },
		{ id = "DefUndefineClass", name = "Undefine class", editor = "bool", default = false, },
	},
	DefParentClassList = { "PropertyObject" },
	
	ContainerClass = "ClassDefSubItem",
	PresetClass = "ClassDef",
	FilePerGroup = true,
	HasCompanionFile = true,
	GeneratesClass = true,
	DefineKeyword = "DefineClass",
	
	GedEditor = "ClassDefEditor",
	EditorMenubarName = "Class definitions",
	EditorIcon = "CommonAssets/UI/Icons/cpu.png",
	EditorMenubar = "Editors.Engine",
	EditorShortcut = "Ctrl-Alt-F3",
	EditorViewPresetPrefix = "<color 75 105 198>[Class]</color> ",
}

function ClassDef:FindSubitem(name)
	for _, subitem in ipairs(self) do
		if subitem:HasMember("name") and subitem.name == name or subitem:IsKindOf("PropertyDef") and subitem.id == name then
			return subitem
		end
	end
end

function ClassDef:GetDefaultPropertyValue(prop_id, prop_meta)
	if prop_id:starts_with("Def") then
		local class_prop_id = prop_id:sub(4)
		-- try to find the default property value from the parent list
		-- this is not correct if there are multiple parent classes that have different default values for the property
		for i, class_name in ipairs(self.DefParentClassList) do
			local class = g_Classes[class_name]
			if class then
				local default = class:GetDefaultPropertyValue(class_prop_id)
				if default ~= nil then
					return default
				end
			end
		end
	end
	return Preset.GetDefaultPropertyValue(self, prop_id, prop_meta)
end

function ClassDef:PostLoad()
	for key, prop_def in ipairs(self) do
		prop_def.translate_in_ged = self.DefPropertyTranslation
	end
	Preset.PostLoad(self)
end

function ClassDef:OnPreSave()
	-- convert texts to/from Ts if the 'translated' value changed
	local translate = self.DefPropertyTranslation
	for key, prop_def in ipairs(self) do
		if IsKindOf(prop_def, "PropertyDef") then
			local convert_text = function(value)
				local prop_translated = not value or IsT(value)
				if prop_translated and not translate then
					return value and TDevModeGetEnglishText(value) or false
				elseif not prop_translated and translate then
					return value and value ~= "" and T(value) or false 
				end
				return value
			end
			prop_def.name = convert_text(prop_def.name)
			prop_def.help = convert_text(prop_def.help)
			prop_def.translate_in_ged = translate
		end
	end
end

function ClassDef:GenerateCompanionFileCode(code)
	if self.DefUndefineClass then
		code:append("UndefineClass('", self.id, "')\n")
	end
	code:append(self.DefineKeyword, ".", self.id, " = {\n")
	self:GenerateParents(code)
	self:AppendGeneratedByProps(code)
	self:GenerateProps(code)
	self:GenerateConsts(code)
	code:append("}\n\n")
	self:GenerateMethods(code)
	self:GenerateGlobalCode(code)
end

function ClassDef:GenerateParents(code)
	local parents = self.DefParentClassList
	if #(parents or "") > 0 then
		code:append("\t__parents = { \"", table.concat(parents, "\", \""), "\", },\n")
	end
end

function ClassDef:GenerateProps(code)
	local extra_code_fn = self.GeneratePropExtraCode ~= ClassDef.GeneratePropExtraCode and
		function(prop_def) return self:GeneratePropExtraCode(prop_def) end
	self:GenerateSubItemsCode(code, "PropertyDef", "\tproperties = {\n", "\t},\n", self.DefPropertyTranslation, extra_code_fn )
end

function ClassDef:GeneratePropExtraCode(prop_def)
end

function ClassDef:AppendConst(code, prop_id, alternative_default, def_prop_id)
	def_prop_id = def_prop_id or "Def" .. prop_id
	local value = rawget(self, def_prop_id)
	if value == nil then return end
	local def_value = self:GetDefaultPropertyValue(def_prop_id)
	if value ~= alternative_default and value ~= def_value then
		code:append("\t", prop_id, " = ")
		code:appendv(value)
		code:append(",\n")
	end
end

function ClassDef:GenerateConsts(code)
	if self.DefStoreAsTable ~= "inherit" then
		code:append("\tStoreAsTable = ", self.DefStoreAsTable, ",\n")
	end
	if self.DefPropertyTabs then
		code:append("\tPropertyTabs = ")
		code:appendv(self.DefPropertyTabs, "\t")
		code:append(",\n")
	end
	self:GenerateSubItemsCode(code, "ClassConstDef")
end

function ClassDef:GenerateMethods(code)
	self:GenerateSubItemsCode(code, "ClassMethodDef", "", "", self.id)
end

function ClassDef:GenerateGlobalCode(code)
	self:GenerateSubItemsCode(code, "ClassGlobalCodeDef", "", "", self.id)
end

function ClassDef:GenerateSubItemsCode(code, subitem_class, prefix, suffix, ...)
	local has_subitems
	for i, prop in ipairs(self) do
		if prop:IsKindOf(subitem_class) then
			has_subitems = true
			break
		end
	end
	
	if has_subitems then 
		if prefix then code:append(prefix) end
		for i, prop in ipairs(self) do
			if prop:IsKindOf(subitem_class) then
				prop:GenerateCode(code, ...)
			end
		end
		if suffix then code:append(suffix) end
	end
end

function ClassDef:GetCompanionFileSavePath(path)
	if path:starts_with("Data") then
		path = path:gsub("^Data", "Lua/ClassDefs") -- save in the game folder
	elseif path:starts_with("CommonLua/Data") then
		path = path:gsub("^CommonLua/Data", "CommonLua/Classes/ClassDefs") -- save in common lua
	elseif path:starts_with("CommonLua/Libs/") then -- lib
		path = path:gsub("/Data/", "/ClassDefs/")
	else
		path = path:gsub("^(svnProject/Dlc/[^/]*)/Presets", "%1/Code/ClassDefs") -- save in a DLC
	end
	return path:gsub(".lua$", ".generated.lua")
end


function ClassDef:GetError()
	local names = {}
	for _, element in ipairs(self or empty_table) do
		local id = rawget(element, "id") or rawget(element, "id")
		if id then
			if names[id] then
				return "Some class members have matching ids - '"..element.id.."'"
			else
				names[id] = true
			end
		end
	end
end

function GetTextFilePreview(path, lines_count, filter_func)
	if lines_count and lines_count > 0 then
		local file, err = io.open(path, "r")
		if not err then
			local count = 1
			local lines = {}
			local line
			while count <= lines_count do
				line = file:read()
				if line == nil then break end
				for subline in line:gmatch("[^%\r?~%\n?]+") do
					if count == lines_count + 1 or (filter_func and filter_func(subline)) then
						break
					end
					lines[#lines + 1] = subline
					count = count + 1
				end
			end
			lines[#lines + 1] = ""
			lines[#lines + 1] = "..."
			file:close()
			return table.concat(lines, "\n")
		end
	end
end

local function CleanUpHTMLTags(text)
	text = text:gsub("<br>", "\n")
	text = text:gsub("<br/>", "\n")
	text = text:gsub("<script(.+)/script>", "")
	text = text:gsub("<style(.+)/style>", "")
	text = text:gsub("<!--(.+)-->", "")
	text = text:gsub("<link(.+)/>", "")
	return text
end

function GetDocumentation(obj)
	if type(obj) == "table" and PropObjHasMember(obj, "Documentation") and obj.Documentation and obj.Documentation ~= "" then
		return obj.Documentation
	end
end

function GetDocumentationLink(obj)
	if type(obj) == "table" and PropObjHasMember(obj, "DocumentationLink") and obj.DocumentationLink and obj.DocumentationLink ~= "" then
		local link = obj.DocumentationLink
		assert(link:starts_with("Docs/"))
		if not link:starts_with("http") then
			link = ConvertToOSPath(link)
		end
		link = string.gsub(link, "[\n\r]", "")
		link = string.gsub(link, " ", "%%20")
		return link
	end
end

function GedOpenDocumentationLink(root, obj, prop_id, ged, btn_param, idx)
	OpenUrl(GetDocumentationLink(obj), "force external browser")
end


----- AppendClassDef

DefineClass.AppendClassDef = {
	__parents = { "ClassDef" },
	properties = {
		{ id = "DefUndefineClass", editor = false, },
		
	},
	GeneratesClass = false,
	DefParentClassList = false,
	DefineKeyword = "AppendClass",
}


----- ListPreset

DefineClass.ListPreset = {
	__parents = { "Preset", },
	HasGroups = false,
	HasSortKey = true,
	EditorMenubar = "Editors.Lists",
}

-- deprecated and left for compatibility reasons, to be removed
DefineClass.ListItem = {
	__parents = { "Preset", },
	properties = {
		{ id = "Group", no_edit = false, },
	},
	HasSortKey = true,
	PresetClass = "ListItem",
}


-----

if Platform.developer and not Platform.ged then
	function RemoveUnversionedClassdefs()
		local err, files = AsyncListFiles("svnProject/../", "*.lua", "recursive")
		local removed = 0
		for _, file in ipairs(files) do
			if string.match(file, "ClassDef%-.*%.lua$") and not SVNLocalInfo(file) then
				print("removing", file)
				os.remove(file)
				removed = removed + 1
			end
		end
		print(removed, "files removed")
	end
end