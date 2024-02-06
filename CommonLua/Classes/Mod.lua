if FirstLoad then
	Mods = {}
	ModsList = false -- in list form sorted by title, used for editing in Ged
	ModsLoaded = false -- an array of the loaded mods in the order of loading
	ModsPackFileName = "ModContent.hpk"
	ModContentPath = "Mod/"
	ModMountNextLabelIdx = 0
	--screenshots are copied to another folder and renamed
	--this way we can distinguish them from shots uploaded from outside the mod editor
	ModsScreenshotPrefix = "ModScreenshot_"
	ModMessageLog = {}
	
	--Bumped whenever a major change to mods has been made.
	--One that breaks backward compatibility.
	ModMinLuaRevision = 233360
	
	--Min game version required to load mods created using the current game version.
	--Bumped whenever forward compatibility is broken for older game versions.
	ModRequiredLuaRevision = 233360
	
	--Mod blacklist support
	--These mods will not show in the UI and will not be loaded
	--Two types of blacklisting:
	--deprecate -> mod is present in the base game and no longer needed, saves will work without it, no warnings for missing in saves, warning in ui that is deprecated, can be loaded again
	--ban -> mod is banned from the game, saves with this mod missing are not guaranteed to work, doesn't show in the ui at all
	ModIdBlacklist = {} -- { [id] = "deprecate", [id] = "ban" }
	AutoDisabledModsAlertText = {}

	if Platform.goldmaster and io.exists("ModTools") then
		function OnMsg.Autorun()
			CreateRealTimeThread(function()
				local out_path = ConvertToOSPath("ModTools/Src/ModTools.code-workspace")
				if io.exists(out_path) then return end
				local template_path = ConvertToOSPath("ModTools/Src/ModTools.code-workspace.template")
				local err, contents = AsyncFileToString(template_path)
				if err then return end
				local mods_path = ConvertToOSPath("AppData/Mods/")
				contents = string.gsub(contents, "Mods", string.gsub(mods_path, "\\", "\\\\"))
				local err = AsyncStringToFile(out_path, contents)
			end)
		end
	end
end

function IsUserCreatedContentAllowed()
	return true
end

mod_print = CreatePrint{
	"mod",
	format = "printf",
	output = DebugPrint,
}

-- Usage:
-- ModLog(T(...)) to print to Mod Manager dialog
-- ModLog(true, T(...)) to print to Mod Manager and store in log file
function ModLog(log_or_msg, msg)
	local log
	if IsT(log_or_msg) then
		msg = log_or_msg
	else
		log = log_or_msg
	end
	msg = _InternalTranslate(msg)
	ModMessageLog[#ModMessageLog + 1] = msg
	if log then
		mod_print(msg)
	end
	ObjModifiedDelayed(ModMessageLog)
end

-- Usage:
-- ModLogF("asd", ...) to print to Mod Manager dialog
-- ModLogF(true, "asd", ...) to print to Mod Manager and store in log file
function ModLogF(log_or_fmt, fmt, ...)
	local log, msg
	if type(log_or_fmt) == "string" then
		local arg1 = fmt
		fmt = log_or_fmt
		msg = string.format(fmt, arg1, ...)
	else
		log = log_or_fmt
		msg = string.format(fmt, ...)
	end
	return ModLog(log, Untranslated(msg))
end

function OnMsg.Autorun()
	ObjModified(ModMessageLog)
end

if not config.Mods then 
	AreModdingToolsActive = empty_func
	DefineClass("ModLinkDef", "PropertyObject")
	return
end

function AreModdingToolsActive()
	return IsModEditorOpened() or IsModManagerOpened() or IsModEditorMap() or (Game and Game.testModGame)
end

DocsRoot = "ModTools/Docs/"
if Platform.developer then
	DocsRoot = "svnProject/Docs/ModTools/"
end


----- ModElement

DefineClass.ModElement = { 
}

function ModElement:OnLoad(mod)
	self:AddPathPrefix()
end

function ModElement:OnUnload(mod)
end

function ModElement:IsMounted()
end

function ModElement:IsPacked()
end

--root path is where the mod exists on the OS
function ModElement:GetModRootPath()
end

--content path is the path where content can be accessed
function ModElement:GetModContentPath()
end

function ModConvertSlashes(path)
	--convert all '\' into '/'
	return string.gsub(path, "\\", "/")
end

local function EscapeMagicSymbols(path)
	--convert all gsub 'magic symbols' into escaped symbols
	return string.gsub(ModConvertSlashes(path), "[%(%)%.%%%+%-%*%?%[%^%$]", "%%%1")
end

local function GetChildren(item)
	if IsKindOf(item, "ModDef") then
		return item.items
	else
		return item
	end
end

function ModElement:PostSave()
	self:AddPathPrefix()
end

local function ModResourceExists(path, item)
	if io.exists(path) then
		return true
	end
	
	if item and IsKindOf(item, "SoundFile") then
		local parent = GetParentTable(item)
		local files = parent and parent:GetSoundFiles()
		if files and files[path .. "." .. item:GetFileExt()] then
			return true
		end
	end

	local res_id = ResourceManager.GetResourceID(path)
	return res_id ~= const.InvalidResourceID
end

local function RecursiveAddPathPrefix(item, mod_path, mod_os_path, mod_content_path, is_packed)
	for i, prop in ipairs(item:GetProperties()) do
		if (prop.editor == "browse" or prop.editor == "ui_image") and not prop.os_path then
			local prop_id = prop.id
			local path = item:GetProperty(prop_id)
			if (path or "") ~= "" and not path:starts_with(ModContentPath) and not ModResourceExists(path, item) then
				if is_packed then
					item:SetProperty(prop_id, mod_content_path .. path)
				else
					if not string.find(path, EscapeMagicSymbols(mod_os_path)) then
						item:SetProperty(prop_id, ModConvertSlashes(mod_os_path .. path))
					end
				end
			end
		end
	end
	
	for _, child in ipairs(GetChildren(item)) do
		RecursiveAddPathPrefix(child, mod_path, mod_os_path, mod_content_path, is_packed)
	end
end

function ModElement:AddPathPrefix()
	local mod_path = ModConvertSlashes(self:GetModRootPath())
	local mod_os_path = ConvertToOSPath(mod_path)
	local mod_content_path = self:GetModContentPath()
	local is_packed = self:IsPacked()
	RecursiveAddPathPrefix(self, mod_path, mod_os_path, mod_content_path, is_packed)
end

function ModElement:PreSave()
	self:RemovePathPrefix()
end

local function RecursiveRemovePathPrefix(item, mod_path, mod_os_path, mod_content_path, is_packed)
	for i, prop in ipairs(item:GetProperties()) do
		if (prop.editor == "browse" or prop.editor == "ui_image") and not prop.os_path then
			local prop_id = prop.id
			local path = item:GetProperty(prop_id)
			if (path or "") ~= "" and not path:starts_with(ModContentPath) then
				path = ModConvertSlashes(path)
				local prefix = is_packed and mod_content_path or mod_os_path
				local new_path = string.gsub(path, EscapeMagicSymbols(prefix), "")
				item:SetProperty(prop_id, new_path)
			end
		end
	end

	for _, child in ipairs(GetChildren(item)) do
		RecursiveRemovePathPrefix(child, mod_path, mod_os_path, mod_content_path, is_packed)
	end
end

function ModElement:RemovePathPrefix()
	local mod_path = ModConvertSlashes(self:GetModRootPath())
	local mod_os_path = ModConvertSlashes(ConvertToOSPath(mod_path))
	local mod_content_path = self:GetModContentPath()
	local is_packed = self:IsPacked()
	RecursiveRemovePathPrefix(self, mod_path, mod_os_path, mod_content_path, is_packed)
end

function ModElement:NeedsResave()
end


----- ModLinkDef

DefineClass.ModLinkDef = {
	__parents = { "DisplayPreset", },
	__generated_by_class = "PresetDef",

	properties = {
		{ id = "Patterns", 
			editor = "string_list", default = {}, item_default = "", items = false, arbitrary_value = true, help = "A link should match any of these patterns. The pattern capture (in brackets) defines how the link will be displayed. Add a capture to remove the typical 'https://www.' at the start." },
		{ id = "Icon", 
			editor = "ui_image", default = false, },
	},
	GlobalMap = "ModLinkDefs",
	EditorMenubarName = "Mod links",
	EditorMenubar = "Editors.Engine",
	StoreAsTable = true,
}

function NormalizeLink(link)
	if not link or link == "" then return "" end
	return link:starts_with("https://") and link or "https://" .. link
end

function GetLinkDef(link)
	link = NormalizeLink(link)
	local link_def, link_short
	ForEachPreset("ModLinkDef", function(def)
		for _, pattern in ipairs(def.Patterns) do
			link_short = link:match(pattern)
			if link_short then
				link_def = def
				return "break"
			end
		end
	end)
	return link_def, link_short
end

function GetLinkShort(link)
	local def, short = GetLinkDef(link)
	return short
end


----- ModDef

DefineClass.ModDef = {
	__parents = { "GedEditedObject", "ModElement", "Container", "InitDone" },
	properties =
	{
		{ category = "Mod",  id = "title",         name = "Title",        editor = "text",   default = "" },
		{ category = "Mod",  id = "description",   name = "Description",  editor = "text",   default = "", lines = 5, max_lines = 15, max_len = 8000, },
		{ category = "Mod",  id = "tags",          name = "Tags",         editor = false,    default = "" },
		{ category = "Mod",  id = "image",         name = "Preview image",editor = "ui_image", default = "", filter = "Image files|*.png;*.jpg" },
		{ category = "Mod",  id = "external_links",name = "Links",        editor = "string_list", default = {}, arbitrary_value = true, help = function(obj, prop_meta)
			local sites = {}
			ForEachPreset("ModLinkDef", function(def)
				sites[#sites + 1] = " • " .. (def.display_name == "" and def.id or TTranslate(def.display_name, def))
			end)
			return "Allows including links in the mod description to the following sites:\n\n" .. table.concat(sites, "\n")
		end },
		{ category = "Mod",  id = "last_changes",  name = "Last changes",  editor = "text",   default = "", lines = 3, },
		{ category = "Mod",  id = "ignore_files",  name = "Ignore files",  editor = "string_list", default = { "*.git/*", "*.svn/*" },
			help = "Files in the mod folder that must not be included in the packaged mod."
		},
		{ category = "Mod",  id = "dependencies",  name = "Dependencies",  editor = "nested_list", default = false, base_class = "ModDependency", inclusive = true,
			help = "Allows specifying a list of mods required for this mod to work,\nor mods that must be loaded before it, if present."
		},
		{ category = "Mod",  id = "id",            name = "ID",            editor = "text",   default = "", read_only = true },
		{ category = "Mod",  id = "content_path",  name = "Content path",  editor = "text",   default = false, read_only = true, help = "Folder to access the mod files.", buttons = {{name = "Copy", func = "CopyContentPath"}}, dont_save = true },
		{ category = "Mod",  id = "author",        name = "Author",        editor = "text",   default = "", read_only = true }, -- platform specific author name
		{ category = "Mod",  id = "version_major", name = "Major version", editor = "number", default =  0 },
		{ category = "Mod",  id = "version_minor", name = "Minor version", editor = "number", default =  0 },
		{ category = "Mod",  id = "version",       name = "Revision",      editor = "number", default =  0, read_only = true },
		{ category = "Mod",  id = "lua_revision",      name = "Required game version", editor = "number", default =  0, read_only = true },
		{ category = "Mod",  id = "saved_with_revision", name = "Saved with game version",      editor = "number", default =  0, read_only = true },
		
		-- not displayed, used for saving only
		{ category = "Mod",  id = "entities",      editor = "prop_table",  default = false, no_edit = true },
		{ category = "Mod",  id = "code",          editor = "prop_table",  default = false, no_edit = true },
		{ category = "Mod",  id = "loctables",     editor = "prop_table",  default = false, no_edit = true },
		{ category = "Mod",  id = "default_options",   editor = "prop_table",        default = false, no_edit = true },
		{ category = "Mod",  id = "has_data",      editor = "bool",        default = false, no_edit = true },
		{ category = "Mod",  id = "saved",         editor = "number", default = false, no_edit = true },
		{ category = "Mod",  id = "code_hash",     editor = "number", default = false, no_edit = true },
		
		{ category = "Screenshot", id = "screenshot1", name = "Screenshot", editor = "ui_image", default = "", filter = "Image files|*.png;*.jpg" },
		{ category = "Screenshot", id = "screenshot2", name = "Screenshot", editor = "ui_image", default = "", filter = "Image files|*.png;*.jpg" },
		{ category = "Screenshot", id = "screenshot3", name = "Screenshot", editor = "ui_image", default = "", filter = "Image files|*.png;*.jpg" },
		{ category = "Screenshot", id = "screenshot4", name = "Screenshot", editor = "ui_image", default = "", filter = "Image files|*.png;*.jpg" },
		{ category = "Screenshot", id = "screenshot5", name = "Screenshot", editor = "ui_image", default = "", filter = "Image files|*.png;*.jpg" },
		
		{ category = "Conflict Detection",  id = "affected_resources", name = "Affected resources", editor = "nested_list", default = false, base_class = "ModResourceDescriptor", inclusive = true, read_only = true,
			help = "Lists the game content affects by the mod, used to detect potential conflicts as mods are loaded.",
			sort_order = 1000000,
		},
	},
	path = "", -- source folder, this is where the metadata and ModContent.hpk is located
	source = "appdata",
	env = false,
	packed = false,
	mounted = false,
	mount_label = false,
	status = "alive",
	items = false,
	items_file_timestamp = 0,
	options = false,
	dev_message = "",
	ContainerClass = "ModItem",
	force_reload = false,
	mod_opening = false,
	mod_ged_id = false,
	-- Mods Editor
	GedTreeChildren = function (self) return self.items end,
}

function ModDef:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "title" then
		local new_title = "Mod Editor - " .. self[prop_id]
		ged:Send("rfnApp", "SetTitle", new_title)
	end
end

function ModDef:CopyContentPath()
	CopyToClipboard(self.content_path)
end

function ModDef:Init()
	self.options = ModOptionsObject:new({ __mod = self })
end

function ModDef:delete()
	if self.status == "deleted" then
		return
	end

	self:UnloadItems()
	self:UnmountContent()
	self.status = "deleted"
end

function ModDef:IsOpenInGed()
	return not not GedObjects[ParentTableCache[self]]
end

function ModDef:CalculatePersistHash()
	local hash = PropertyObject.CalculatePersistHash(self)
	self:ForEachModItem(function(mod_item)
		mod_item:TrackDirty() -- calculate the current hash, if not already calculated
		hash = xxhash(hash, mod_item:EditorData().current_hash) -- consider the mod changed if any mod item is changed
	end)
	return hash
end

function ModDef:__eq(rhs)
	return
		self.id == rhs.id and
		self.source == rhs.source and
		self.version == rhs.version
end

function ModDef:GetTags()
	assert(false, "override this method in game-specific code")
	return { }
end

function ModDef:GetEditorView()
	if self:ItemsLoaded() then
		return Untranslated("<u(literal(title))> (loaded)\nid <u(id)>, version <VersionString>")
	else
		return Untranslated("<color 128 128 128><u(literal(title))>\nid <u(id)>, version <VersionString></color>")
	end
end

local ModIdCharacters = "ACDEFGHJKLMNPQRSTUVWXYabcdefghijkmnopqrstuvwxyz345679"
function ModDef:GenerateId()
	local id = ""
	for i = 1, 7 do
		local rand = AsyncRand(i > 1 and #ModIdCharacters or #ModIdCharacters - 10)
		id = id .. ModIdCharacters:sub(rand, rand)
	end
	return id
end

function ModDef:GetExternalLinkError()
	local seen = {}
	for i, link in ipairs(self.external_links) do
		if link ~= "" then
			local def = GetLinkDef(link)
			if not def then return "Unrecognized link: " .. link, i end
			if seen[def] then
				return "Duplicate link to: " .. def.id
			end
			seen[def] = true
		end
	end
end

function ModDef:GetError()
	return self:GetExternalLinkError()
end

function ModDef:GetValidatedExternalLinks()
	local seen, validated = {}, {}
	for _, link in ipairs(self.external_links) do
		local def = GetLinkDef(link)
		if def and not seen[def] then
			validated[#validated + 1] = link
			seen[def] = true
		end
	end
	return validated
end

function ModDef:GenerateMountLabel()
	ModMountNextLabelIdx = ModMountNextLabelIdx + 1
	return "mod_" .. ModMountNextLabelIdx
end

function ModDef:ChangePaths(mod_path)
	self:RemovePathPrefix()
	self.path = mod_path
	self:AddPathPrefix()
end

function ModDef:NeedsResave()
	return self:ForEachModItem(function(item)
		if item:NeedsResave() then
			return true
		end
	end)
end

function ModDef:GetWarning()
	if self:NeedsResave() then
		return "Please resave this mod for optimization reasons."
	end
end

function ModDef:SortItems()
	table.stable_sort(self.items, function(a, b)
		if a.class == b.class then
			return a.name < b.name
		end
		return a.class < b.class
	end)
end

function ModDef:ItemsLoaded()
	return not not self.items
end

function ModDef:GenerateModItemId(mod_item)
	return string.format("autoid_%s_%s", self.id, self:GenerateId())
end

function ModDef:GetDefaultOptions()
	local options_items = { }
	if not self.items then return options_items end
	
	self:ForEachModItem("ModItemOption", function(item)
		if item.name and item.name ~= "" then
			options_items[item.name] = item.DefaultValue
		end
	end)
	return options_items
end

function ModDef:HasOptions()
	return self.has_options or next(self.default_options) -- has_options is used for backwards comp
end

function ModDef:GetOptionItems(test)
	local options_items = not test and { }
	if not self.items then return options_items end
	self:ForEachModItem("ModItemOption", function(item)
		if item.name and item.name ~= "" then
			if test then return true end
			table.insert(options_items, item)
		end
	end)
	
	return options_items
end

function ModDef:LoadCode()
	if not LuaLoadedForMods[self.id] then
		rawset(self.env, "FirstLoad", true)
		LuaLoadedForMods[self.id] = true
	end
	
	-- load classes generated from Presets (e.g. composite classes) first
	local errs = {}
	for _, filename in ipairs(self.code) do
		if not filename:starts_with("Code/") then
			local ok, err = pdofile(self.content_path .. filename, self.env, "t")
			if not ok then
				err = err and err:gsub(self.content_path, ""):gsub("cannot read ", ""):gsub(": ", " - ")
				table.insert(errs, err or string.format("%s: Unknown error", filename))
			end
		end
	end
	
	-- load Code mod items last, to allow them define methods of classes loaded above, etc.
	for _, filename in ipairs(self.code) do
		if filename:starts_with("Code/") then
			local ok, err = pdofile(self.content_path .. filename, self.env, "t")
			if not ok then
				err = err and err:gsub(self.content_path, ""):gsub("cannot read ", ""):gsub(": ", " - ")
				table.insert(errs, err or string.format("%s: Unknown error", filename))
			end
		end
	end
	
	rawset(self.env, "FirstLoad", false)
	return next(errs) and errs
end

function ModDef:StoreItemsFileModifiedTime()
	self.items_file_timestamp = io.getmetadata(self.content_path .. "items.lua", "modification_time")
end

function ModDef:IsItemsFileModified()
	return self.items_file_timestamp ~= io.getmetadata(self.content_path .. "items.lua", "modification_time")
end

function ModDef:LoadItems()
	if self:ItemsLoaded() then return end
	
	assert(self.content_path)
	local path = self.content_path .. "items.lua"
	local ok, items = pdofile(path, self.env)
	self.items = ok and items or { }
	if not ok then
		local err = items
		ModLogF(true, "Failed to load mod items for %s. Error: %s", self:GetModLabel("plainText"), err)
		return
	end
	
	-- cache the source file to make sure it matches with the debug info of loaded functions
	-- (and we can get their source code even if items.lua is edited externally)
	local err, source = AsyncFileToString(path, nil, nil, "lines")
	if not err then CacheLuaSourceFile(path, source) end
	
	PopulateParentTableCache(self)
	self:StoreItemsFileModifiedTime()
	
	local has_data
	self:ForEachModItem(function(item)
		item.mod = self
		sprocall(item.OnModLoad, item, self)
		has_data = has_data or item.is_data
	end)
	self.has_data = has_data
end

function ModDef:LoadOptions()
	if not self:HasOptions() then
		self:UnloadOptions()
		return
	end
	
	if AccountStorage then
		local options_in_storage = AccountStorage.ModOptions and AccountStorage.ModOptions[self.id]
		self:UnloadOptions()
		table.overwrite(self.options, options_in_storage)
		-- initialize option defaults
		-- so mod code can use it without GetProperty
		for id, default_value in pairs(self.default_options) do
			if rawget(self.options, id) == nil then
				rawset(self.options, id, default_value)
			end
		end
		Msg("ApplyModOptions", self.id)
	end
end

function ModDef:UnloadOptions()
	local options_obj = self.options
	options_obj.properties = nil
	options_obj.__defaults = nil
	table.clear(options_obj)
	options_obj.__mod = self
end

function ModDef:UnloadItems()
	if not self:ItemsLoaded() then
		return
	end
	
	self:ForEachModItem(function(item)
		item:OnModUnload(self)
		item:delete()
	end)
	
	self.items = false
	self.has_data = false
end

function ModDef:ForEachModItem(classname, fn)
	if not self.items then return end
	for _, item in ipairs(self.items) do
		local ret = item:ForEachModItem(classname, fn)
		if ret == "break" then
			break
		elseif ret ~= nil then
			return ret
		end
	end
end

function ModDef:FindModItem(mod_item)
	return table.find(self.items, mod_item)
end

function ApplyModOptions(host)
	CreateRealTimeThread(function(host)
		local mod = GetDialogModeParam(host)
		local options = mod.options
		if not options then return end
		--@@@msg ApplyModOptions,mod_id- fired when loading the mod options and when the user applies changes to their mod options.
		Msg("ApplyModOptions", mod.id)
		
		AccountStorage.ModOptions = AccountStorage.ModOptions or { }
		local storage_table = AccountStorage.ModOptions[mod.id] or { }
		for _, prop in ipairs(options:GetProperties()) do
			local value = options:GetProperty(prop.id)
			value = type(value) == "table" and table.copy(value) or value
			storage_table[prop.id] = value
		end
		AccountStorage.ModOptions[mod.id] = storage_table
		SaveAccountStorage(1000)
		
		SetBackDialogMode(host)
	end, host)
end

function CancelModOptions(host)
	CreateRealTimeThread(function(host)
		local mod = GetDialogModeParam(host)
		local original_obj = ResolvePropObj(host:ResolveId("idOriginalModOptions").context)
		if not mod or not original_obj then return end
		local properties = mod.options:GetProperties()
		for i = 1, #properties do
			local prop = properties[i]
			local original_value = original_obj:GetProperty(prop.id)
			mod.options:SetProperty(prop.id, original_value)
		end
		SetBackDialogMode(host)
	end, host)
end

function ResetModOptions(host)
	CreateRealTimeThread(function(host)
		local mod = GetDialogModeParam(host)
		local options = mod and mod.options
		if not options then return end
		local properties = mod.options:GetProperties()
		for i = 1, #properties do
			local prop = properties[i]
			local default_value = mod.options:GetDefaultPropertyValue(prop.id, prop)
			mod.options:SetProperty(prop.id, default_value)
		end
		ObjModified(mod.options)
	end, host)
end

function HasModsWithOptions()
	local mods_to_load = AccountStorage and AccountStorage.LoadMods
	if not mods_to_load then return end
	for i,id in ipairs(mods_to_load) do
		local mod_def = Mods[id]
		if mod_def and mod_def:HasOptions() then
			return true
		end
	end
end

function ModDef:UpdateEntities()
	--backwards compatibility for r342666
	self.bin_assets = nil

	local dirty
	if self.items then
		local entities = false
		self:ForEachModItem("ModItemEntity", function(item)
			if item.entity_name ~= "" then
				entities = entities or {}
				table.insert(entities, item.entity_name)
				dirty = dirty or item:IsDirty()
			end
		end)
		self.entities = entities
	end
	return dirty
end

function ModDef:UpdateCode()
	local dirty
	if self.items then
		local code = false
		local code_hash
		self:ForEachModItem(function(item)
			local name = item:GetCodeFileName() or ""
			if name ~= "" then
				code = code or {}
				code[#code + 1] = name
				local err, hash
				if name ~= "" then
					err, hash = AsyncFileToString(item:GetCodeFilePath(), nil, nil, "hash")
				end
				code_hash = xxhash(code_hash, name, hash)
				dirty = dirty or err or item:IsDirty()
			end
		end)
		dirty = dirty or code_hash ~= self.code_hash
		self.code = code
		self.code_hash = code_hash
	end
	return dirty
end

function ModDef:UpdateLocTables()
	if self.items then
		local loctables
		self:ForEachModItem("ModItemLocTable", function(item)
			loctables = loctables or {}
			item:RemovePathPrefix()
			loctables[#loctables + 1] = { filename = item.filename, language = item.language }
			item:AddPathPrefix()
		end)
		self.loctables = loctables
	end
end

function ModDef:MountContent()
	if not self.mounted then
		self.mounted = true
		self.mount_label = self.mount_label or self:GenerateMountLabel()
		if self.packed then
			MountPack(self.content_path, self.path .. ModsPackFileName, "label:" .. self.mount_label)
		else
			MountFolder(self.content_path, self.path, "label:" .. self.mount_label)
		end
	end

	local binAssetsLabel = self.mount_label .. "BinAssets"

	if self.packed and MountsByLabel(binAssetsLabel) == 0 then
		MountFolder("BinAssets/Materials", self.content_path .. "BinAssets", "seethrough label:" .. binAssetsLabel)
	end
end

function ModDef:UnmountContent()
	if not self.mounted then return end
	local binAssetsLabel = self.mount_label .. "BinAssets"
	if self.packed and MountsByLabel(binAssetsLabel) > 0 then 
		UnmountByLabel(binAssetsLabel)
	end
	UnmountByLabel(self.mount_label)
	self.mounted = false
end

function ModDef:IsMounted()
	return self.mounted
end

function ModDef:IsPacked()
	return self.packed
end

function ModDef:GetModRootPath()
	return ConvertToOSPath(SlashTerminate(self.path))
end

function ModDef:GetModContentPath()
	return self.content_path
end

function ModDef:IsTooOld()
	return self.lua_revision < ModMinLuaRevision
end

function ModDef:IsTooNew()
	return self.lua_revision > LuaRevision
end

function ModDef:RefreshAffectedResources()
	if not self.items then return end

	local all_affected_res = {}
	self:ForEachModItem(function(item)
		table.iappend(all_affected_res, item:GetAffectedResources() or empty_table)
	end)

	-- If there are changes to the affected resources, clear the cache
	if not self.affected_resources or not table.iequal(self.affected_resources, all_affected_res) then
		ClearModsAffectedResourcesCache()
	end
	
	self.affected_resources = all_affected_res
end


----- Saving

function ModDef:CanSaveMod(ged, ask_for_save_question)
	assert(self.items)
	if not self.items then return end
	
	local title = "Mod "..self.title
	if ask_for_save_question and ged:WaitQuestion(title, ask_for_save_question, "Yes", "No") ~= "ok" then
		return
	end
	if self:IsItemsFileModified() and ged:WaitQuestion(title,
	   "The items.lua file was modified externally.\n\nSaving will overwrite the external changes. Continue?", "Yes", "No") ~= "ok" then
		return
	end
	if PreloadFunctionsSourceCodes(self) == "error" and ged:WaitQuestion(title,
	   "Unable to get the code of all Lua functions.\n\nThe code of some functions will be lost. Continue?", "Yes", "No") ~= "ok" then
		return
	end
	return true
end

function ModDef:PreSave()
	ModElement.PreSave(self)
	self:RefreshAffectedResources()
end

function ModDef:SaveDef(serialize_only)
	self.external_links = self:GetValidatedExternalLinks()
	if self.content_path then
		local code_dirty
		if not serialize_only then
			Msg("ModDefUpdate", self)
			self.lua_revision = ModRequiredLuaRevision
			self.saved_with_revision = LuaRevision
			self.version = self.version + 1
			self.saved = os.time()
			self.default_options = self:GetDefaultOptions()
			self:UpdateEntities()
			self:UpdateLocTables()
			code_dirty = self:UpdateCode()
		end
		
		local data = pstr("return ", 32768)
		self:PreSave()
		data:appendv(self, "")
		self:PostSave()
		local err = AsyncStringToFile(self.content_path .. "metadata.lua", data)
		
		if not serialize_only then
			CreateRealTimeThread(function()
				Sleep(200)
				self:ForEachModItem(function(item)
					item:MarkClean()
				end)
				self:MarkClean()
				ObjModified(self)
			end)
			DelayedCall(50, SortModsList)
		end
		return err, code_dirty
	end
end

function ModDef:SaveItems()
	if not self:ItemsLoaded() then return "not loaded" end
	
	-- generate code
	local data = pstr("return ", 65536)
	local saved_preset_classes = {}
	self:ForEachModItem(function(item) item:PreSave() end)
	ValueToLuaCode(self.items, "", data)
	self:ForEachModItem(function(item) item:PostSave(saved_preset_classes) end)
	
	-- save to file
	local path = self.content_path .. "items.lua"
	local err = AsyncStringToFile(path, data)
	data:free()
	self:StoreItemsFileModifiedTime()
	
	-- trigger PresetSave, usually used for postprocessing data or applying changes
	for class in sorted_pairs(saved_preset_classes) do
		Msg("PresetSave", class)
	end
	
	CacheModDependencyGraph()
	return err
end

function ModDef:SaveOptions()
	if self.options then
		self.options.properties = nil
		self.options.__defaults = nil
	end
	if self.has_options then
		self.has_options = nil
	end
end

function ModDef:SaveWholeMod()
	GedSetUiStatus("mod_save", "Saving...")
	DiagnosticMessageSuspended = true
	PauseInfiniteLoopDetection("SaveMod")
	
	local err, code_dirty = self:SaveDef()
	self:SaveItems()
	self:SaveOptions()
	if code_dirty then
		ReloadLua()
	end
	
	ResumeInfiniteLoopDetection("SaveMod")
	DiagnosticMessageSuspended = false
	GedSetUiStatus("mod_save")
end

function ModDef:CompareVersion(other_mod, ignore_revision)
	assert(other_mod)
	local version_diffs = {
		self.version_major - (other_mod.version_major or self.version_major),
		self.version_minor - (other_mod.version_minor or self.version_minor),
		ignore_revision and 0 or (self.version - (other_mod.version or 0)),
	}
	
	for i = 1, #version_diffs do
		local diff = version_diffs[i]
		if diff ~= 0 then
			return diff
		end
	end
	return 0
end

function ModDef:GetVersionString()
	return string.format("%d.%02d-%03d", self.version_major, self.version_minor, self.version)
end

function ModDef:GetModLabel(plainText)
	local text = string.format("%s (id %s, v%s)", self.title, self.id, self:GetVersionString())
	return plainText and text or Untranslated(text)
end

function ModDefPersist(mod_info)
	setmetatable(mod_info, ModDef)
	local mod_def = Mods[mod_info.id]
	if not mod_def then
		ModLogF(true, "Savegame references Mod %s which is not present", mod_info:GetModLabel("plainText"))
		return mod_info
	end
	if not mod_def.items then
		ModLogF(true, "This savegame tries to load Mod %s, which is present, but not loaded", mod_def:GetModLabel("plainText"))
	elseif mod_def:CompareVersion(mod_info) ~= 0 then
		ModLogF(true, "This savegame tries to load Mod %s, which is loaded with a different version %s", mod_info:GetModLabel("plainText"), mod_def:GetVersionString())
	else
		ModLogF("This savegame loads Mod %s", mod_def:GetModLabel("plainText"))
	end
	return mod_def
end

function ModDef:__persist()
	local mod_info = {
		title = self.title,
		id = self.id,
		version_major = self.version_major,
		version_minor = self.version_minor,
		version = self.version,
		lua_revision = self.lua_revision,
	}
	return function()
		return ModDefPersist(mod_info)
	end
end

function OnMsg.PersistSave(data)
	data["ModsLoaded"] = ModsLoaded
end

function OnMsg.BugReportStart(print_func)
	local active_mods = {}
	for i,mod in ipairs(ModsLoaded) do
		table.insert(active_mods, string.format("%s (id %s, v%s, source %s, required Lua: %d, saved with Lua: %d",
			mod.title, mod.id, mod:GetVersionString(),  mod.source,
			mod.lua_revision, mod.saved_with_revision))
	end
	table.sort(active_mods)
	print_func("Active Mods:" .. (next(active_mods) and ("\n\t" .. table.concat(active_mods, "\n\t")) or "None") .. "\n")
	local ignored_mods = {}
	if SavegameMeta then
		for _, mod in ipairs(SavegameMeta.ignored_mods) do
			table.insert(ignored_mods, string.format("%s (id %s, v%s, source %s, required Lua: %d, saved with Lua: %d",
				mod.title or "no info", mod.id or "no info", mod.version or "no info",  mod.source or "no info",
				mod.lua_revision or 0, mod.saved_with_revision or 0))
		end
	end
	print_func("Ignored Mods:" .. (next(ignored_mods) and ("\n\t" .. table.concat(ignored_mods, "\n\t")) or "None") .. "\n")
	local affected_resources = GetAllLoadedModsAffectedResources()
	if next(affected_resources) then
		print_func("Affected resources from mods (doesn't include ignored mods and custom code):\n\t" .. table.concat(affected_resources, "\n\t"))
	end
	
	local codes = { }
	Msg("GatherModDownloadCode", codes)
	if next(codes) then
		print_func("Paste in the console to download active mods:")
		for source,code in pairs(codes) do
			print_func("\t", code)
		end
		print_func("\n")
	end
end


----- loading

ModEnvBlacklist = {
	--HG values
	IsDlcOwned = true,
	AccountStorage = true,
	async = true,
	AsyncOpWait = true,
	FirstLoad = true,
	InitDefaultAccountStorage = true,
	ReloadLua = true,
	SetAccountStorage = true,
	SaveAccountStorage = true,
	XPlayerActivate = true,
	XPlayersReset = true,
	WaitLoadAccountStorage = true,
	WaitSaveAccountStorage = true,
	_DoSaveAccountStorage = true,
	ConsoleExec = true,
	Crash = true,
	Stomp = true,
	Msg = true,
	OnMsg = true,
	ModMsgBlacklist = true,
	GetAutoCompletionList = true,
	GedOpInspectorSetGlobal = true,
	getfileline = true,
	CompileExpression = true,
	CompileFunc = true,
	GetFuncSourceString = true,
	GetFuncSource = true,
	FuncSource = true,
	LoadConfig = true,
	SVNDeleteFile = true,
	SVNAddFile = true,
	SVNMoveFile = true,
	SVNLocalInfo = true,
	SVNShowLog = true,
	SVNShowBlame = true,
	SVNShowDiff = true,
	SaveSVNFile = true,
	GetSvnInfo = true,
	GetCallLine = true,
	SaveLuaTableToDisk = true,
	LoadLuaTableFromDisk = true,
	insideHG = true,
	SaveLanguageOption = true,
	GetMachineID = true,
	SaveDLCOwnershipDataToDisk = true,
	LoadDLCOwnershipDataFromDisk = true,
	GetLuaSaveGameData = true,
	GetLuaLoadGamePermanents = true,
	--file operations
	DbgPackMod = true,
	AsyncAchievementUnlock = true,
	AsyncCopyFile = true,
	AsyncCreatePath = true,
	AsyncDeletePath = true,
	AsyncExec = true,
	AsyncFileClose = true,
	AsyncFileDelete = true,
	AsyncFileFlush = true,
	AsyncFileOpen = true,
	AsyncFileRead = true,
	AsyncFileRename = true,
	AsyncFileToString = true,
	AsyncFileWrite = true,
	AsyncGetFileAttribute = true,
	AsyncGetSourceInfo = true,
	AsyncListFiles = true,
	AsyncMountPack = true,
	AsyncPack = true,
	AsyncStringToFile = true,
	AsyncSetFileAttribute = true,
	AsyncUnmount = true,
	AsyncUnpack = true,	
	CheatPlatformUnlockAllAchievements = true,
	CheatPlatformResetAllAchievements = true,
	CopyFile = true,
	DeleteFolderTree = true,
	EV_OpenFile = true,
	FileToLuaValue = true,
	LoadFilesForSearch = true,
	MountFolder = true,
	MountPack = true,
	OS_OpenFile = true,
	PreloadFiles = true,
	StringToFileIfDifferent = true,
	Unmount = true,
	DeleteMod = true,
	--web operations
	AsyncWebRequest = true,
	AsyncWebSocket = true,
	hasRfnPrefix = true,
	LocalIPs = true,
	sockAdvanceDeadline = true,
	sockConnect = true,
	sockDelete = true,
	sockDisconnect = true,
	sockEncryptionKey = true,
	sockGenRSAEncryptedKey = true,
	sockGetGroup = true,
	sockGetHostName = true,
	sockGroupStats = true,
	sockListen = true,
	sockNew = true,
	sockProcess = true,
	sockResolveName = true,
	sockSend = true,
	sockSetGroup = true,
	sockSetOption = true,
	sockSetRSAEncryptedKey = true,
	sockStr = true,
	sockStructs = true,
	--mod loading
	ModEnvBlacklist = true,
	LuaModEnv = true,
	ModsReloadDefs = true,
	ModsPackFileName = true,
	ModsScreenshotPrefix = true,
	CanUnlockAchievement = true,
	ModIdBlacklist = true,
	ModsReloadItems = true,
	ProtectedModsReloadItems = true,
	ContinueModsReloadItems = true,
	
	--built-ins
	_G = true,
	getfenv = true,
	setfenv = true,
	getmetatable = true,
	--setmetatable = true,
	rawget = true,
	collectgarbage = true,
	load = true,
	loadfile = true,
	loadstring = true,
	dofile = true,
	pdofile = true,
	dofolder = true,
	dofolder_files = true,
	dofolder_folders = true,
	dostring = true,
	module = true,
	require = true,
	--libraries
	debug = true,
	io = true,
	os = true,
	package = true,
	lfs = true,
}

ModMsgBlacklist = {
	PersistGatherPermanents = true,
	PersistLoad = true,
	PersistSave = true,
	ModBlacklistPrefixes = true,
	DebugDownloadMods = true,
	PasswordChanged = true,
	UnableToUnlockAchievementReasons = true,
}

function OnMsg.Autorun()
	local string_starts_with = string.starts_with
	local prefixes = {"Debug"}
	Msg("ModBlacklistPrefixes", prefixes)
	for key, value in pairs(_G) do
		if type(key) == "string" then
			for _, prefix in ipairs(prefixes) do
				if string_starts_with(key, prefix, true) then
					ModEnvBlacklist[key] = true
					break
				end
			end
		end
	end
	ModEnvBlacklist.DebugPrint = nil -- this is just a log without screen output
end

const.MaxModDataSize = 32 * 1024

--[[@@@
Writes data into a persistent storage, that can be accessed between different game sessions.
The data must be a string, no longer than *const.MaxModDataSize* - make sure to always check if you're exceeding this size.
This storage is not shared, but is per mod. Anything stored here can only be read by the same mod using [ReadModPersistentData](#ReadModPersistentData).
@function err WriteModPersistentData(data)
@param data - the data to be stored (as a string).
@result err - error message or nil, if successful.
See also: [TupleToLuaCode](#TupleToLuaCode), [Compress](#Compress), [AsyncCompress](#AsyncCompress);
]]
local max_data_length = const.MaxModDataSize
local function WriteModPersistentData(mod, data)
	if type(data) ~= "string" then
		return "data must be a string"
	end

	if #data > max_data_length then
		return string.format("data longer than const.MaxModDataSize (%d bytes)", max_data_length)
	end
	
	if not AccountStorage.ModPersistentData then
		AccountStorage.ModPersistentData = { }
	end
	
	if AccountStorage.ModPersistentData[mod.id] == data then return end
	AccountStorage.ModPersistentData[mod.id] = data
	SaveAccountStorage(5000)
end

--[[@@@
Reads data from a persistent storage, that can be accessed between different game sessions.
This storage is not shared, but is per mod. Anything read here has been previously stored only by the same mod using [WriteModPersistentData](#WriteModPersistentData).
@function err, data ReadModPersistentData()
@result err - error message or nil, if successful.
@result data - data previously stored or nil.
See also: [LuaCodeToTuple](#LuaCodeToTuple), [Decompress](#Decompress), [AsyncDecompress](#AsyncDecompress);
]]
local function ReadModPersistentData(mod)
	return nil, AccountStorage.ModPersistentData and AccountStorage.ModPersistentData[mod.id]
end

--[[@@@
Writes `CurrentModStorageTable` into a persistent storage, that can be accessed between different game sessions.
This is an ease-of-use function for the most common use case of persistent storage - when storing data in a table.
It uses [WriteModPersistentData](#WriteModPersistentData) internally, thus the *const.MaxModDataSize* limit applies.
@function err WriteModPersistentStorageTable()
@result err - error message or nil, if successful.
]]
local function WriteModPersistentStorageTable(mod)
	local storage = rawget(mod.env, "CurrentModStorageTable")
	if type(storage) ~= "table" then
		storage = {}
	end
	local data = TupleToLuaCode(storage)
	return WriteModPersistentData(mod, data)
end

local function CreateModPersistentStorageTable(mod)
	if not AccountStorage then
		WaitLoadAccountStorage()
	end
	local storage
	local err, data = ReadModPersistentData(mod)
	if not err then
		err, storage = LuaCodeToTuple(data, mod.env)
	end
	if type(storage) ~= "table" then
		storage = {}
	end
	return storage
end

function LuaModEnv(env)
	assert(ModEnvBlacklist[1] == nil, "All entries in 'ModEnvBlacklist' must be keys")

	env = env or { }
	local env_meta = { __name = "ModEnv" }
	local original_G = _G
	
	--setup black/white lists
	local value_whitelist = { } --for faster access
	local env_blacklist = ModEnvBlacklist
	local meta_blacklist = { }
	meta_blacklist[env_meta] = true
	meta_blacklist[original_G] = true
	
	--setup environment
	for k in pairs(value_whitelist) do
		if env[k] == nil then
			env[k] = original_G[k]
		end
	end
	
	--setup environment metatable
	env_meta.__index = function(env, key)
		if env_blacklist[key] then return end
		local value = rawget(original_G, key)
		if value ~= nil then
			return value
		end
		if key == "class" then return "" end
		if key == "__ancestors" then return empty_table end
		error("Attempt to use an undefined global '" .. tostring(key) .. "'", 1)
	end
	
	env_meta.__newindex = function(env, key, value)
		if env_blacklist[key] then return end
		if not Loading and PersistableGlobals[key] == nil then
			error("Attempt to create a new global '" .. tostring(key) .. "'", 1)
		end
		rawset(original_G, key, value)
	end
	
	--setup exposed power functions
	local function safe_getmetatable(t)
		local meta = getmetatable(t)
		if meta_blacklist[meta] then return end
		return meta
	end
	local function safe_setmetatable(t, new_meta)
		local meta = getmetatable(t)
		if meta_blacklist[meta] then return end
		return setmetatable(t, new_meta)
	end
	
	local function safe_rawget(t, key)
		local t_value = rawget(t, key)
		if rawequal(t, env) and t_value == nil and not env_blacklist[key] then
			return rawget(original_G, key)
		end
		return t_value
	end
	
	local function safe_Msg(name, ...)
		if ModMsgBlacklist[name] then return end
		local raw_Msg = original_G.Msg
		return raw_Msg(name, ...)
	end
	local safe_OnMsg = { }
	setmetatable(safe_OnMsg, { __newindex = 
		function(_, name, func)
			if ModMsgBlacklist[name] then return end
			local raw_OnMsg = original_G.OnMsg
			raw_OnMsg[name] = func
		end
	})
	
	--finilize setting up the environment and fill in some tables
	env._G = env
	env.getmetatable = safe_getmetatable
	--env.setmetatable = safe_setmetatable
	env.rawget = safe_rawget
	env.os = { time = os.time }
	env.Msg = safe_Msg
	env.OnMsg = safe_OnMsg
	
	setmetatable(env, env_meta)
	return env
end

if FirstLoad then
	SharedModEnv = { }
end

function ModDef:SetupEnv()
	local env = self.env
	rawset(env, "CurrentModPath", self.content_path)
	rawset(env, "CurrentModId", self.id)
	rawset(env, "CurrentModDef", self)
	rawset(env, "CurrentModStorageTable", CreateModPersistentStorageTable(self))
	rawset(env, "CurrentModOptions", self.options)
	
	rawset(env, "WriteModPersistentData", function(...)
		return WriteModPersistentData(self, ...)
	end)
	rawset(env, "ReadModPersistentData", function(...)
		return ReadModPersistentData(self, ...)
	end)
	rawset(env, "WriteModPersistentStorageTable", function(...)
		return WriteModPersistentStorageTable(self, ...)
	end)
end

function OnMsg.PersistGatherPermanents(permanents)
	permanents["func:getmetatable"] = getmetatable
	permanents["func:setmetatable"] = setmetatable
	permanents["func:os.time"] = os.time
	permanents["func:Msg"] = Msg
end

function CanLoadUnpackedMods()
	return not Platform.console --or Platform.developer
end

function ListModFolders(path, source)
	path = SlashTerminate(path)
	local folders = io.listfiles(path, "*", "folders")
	table.sort(folders, CmpLower)
	
	if next(folders) then
		local folder_names = table.imap(folders, string.sub, #path + 1)
	end
	
	for i=1,#folders do
		folders[i] = { path = folders[i], source = source }
	end
	
	return folders
end

function SortModsList()
	if #(ModsList or "") <= 1 then return end
	table.sort(ModsList, function(a, b)
		if b:ItemsLoaded() then
			return a:ItemsLoaded() and a.title < b.title
		end
		return a:ItemsLoaded() or a.title < b.title
	end)
	ObjModified(ModsList)
end

if FirstLoad then
	g_ModDefSourceNotified = {}
end

function ModsReloadDefs()
	--load all places where a mod can be found
	local folders = { }
	if Platform.desktop then
		local f = ListModFolders("AppData/Mods/", "appdata")
		table.iappend(folders, f)
	end
	if config.AdditionalModFolder then
		local f = ListModFolders(config.AdditionalModFolder, "additional")
		table.iappend(folders, f)
	end
	Msg("GatherModDefFolders", folders)
	
	--to avoid issues, when loading metadata, mods are allowed to access only this function
	--nothing else exists in their environment
	local descriptor_classes = ClassDescendantsList("ModResourceDescriptor")
	local metadata_env = {
		PlaceObj = function(class, ...)
			if class ~= "ModDef" and class ~= "ModDependency" and not table.find(descriptor_classes, class) then return end
			return PlaceObj(class, ...)
		end,
		box = box,
	}

	local new_mods = { }
	
	local multiple_sources
	for i,folder in ipairs(folders) do
		--execute the mod metadata.lua file
		local env, ok, def
		local source = folder.source
		local pack_path = folder.path .. "/" .. ModsPackFileName
		--Get last subfolder from a path or complete path if it has no slash in it
		--SplitPath does not work for paths containing a dot
		local folder_name = string.sub(folder.path, (string.match(folder.path, "^.*()/") or 0) + 1)
		if io.exists(pack_path) then
			local prev_id = LocalStorage.ModIdCache and LocalStorage.ModIdCache[folder.path]
			local hpk_mounted_path = ModContentPath .. (prev_id or folder_name) .. "/"
			local mount_label = ModDef:GenerateMountLabel()
			local err = MountPack(hpk_mounted_path, pack_path, "label:" .. mount_label)
			if not err then
				env = LuaModEnv()

				ok, def = pdofile(hpk_mounted_path .. "metadata.lua", metadata_env, "t")
				if ok and IsKindOf(def, "ModDef") then
					def.packed = true
					def.mount_label = mount_label
					Msg("PackedModDefLoaded", pack_path, def)
					if prev_id ~= def.id then
						UnmountByLabel(mount_label)
						LocalStorage.ModIdCache = LocalStorage.ModIdCache or {}
						LocalStorage.ModIdCache[folder.path] = def.id
						SaveLocalStorage()
					else
						def.mounted = true
					end
				else
					UnmountByLabel(mount_label)
				end
			end
		elseif (folder.source == "appdata" or folder.source == "additional") or CanLoadUnpackedMods() then
			env = LuaModEnv()
			ok, def = pdofile(folder.path .. "/metadata.lua", metadata_env, "t")
		end
		
		--finilize loading the mod definition and replace old definitions, if needed
		if env and IsKindOf(def, "ModDef") then
			def.env = env
			def.path = folder.path .. "/" --don't need to use 'ChangePaths()' here
			def.content_path = ModContentPath .. def.id .. "/"
			def.source = source
			
			local mod_used
			if def:IsTooOld() then
				ModLogF("Outdated definition for %s loaded from %s. (Unsupported game version)", def:GetModLabel("plainText"), def.source)
			end
			
			local old = new_mods[def.id]
			if old then
				multiple_sources = table.create_set(multiple_sources, def.id, true)
				local cmp = old:CompareVersion(def)
				if cmp < 0 or (cmp == 0 and old.packed and not def.packed) then
					mod_used = true
				end
			else
				mod_used = true
			end
			
			if mod_used then
				if old then
					old:delete()
				end
				
				new_mods[def.id] = def
				def:SetupEnv()
				def:MountContent()
				def:OnLoad()
			else
				def:delete()
			end
		else
			local err = def
			if not err:ends_with("File Not Found") then
				ModLogF(true, "Failed to load mod metadata from %s. Error: %s", folder.path, err)
			end
		end
	end

	for id in pairs(multiple_sources) do
		local def = new_mods[id]
		if g_ModDefSourceNotified[id] ~= def.path then
			g_ModDefSourceNotified[id] = def.path
			local packed_str = def.packed and "packed" or "unpacked"
			ModLogF("Mod %s loaded from %s (%s)", def:GetModLabel("plainText"), def.source, packed_str)
		end
	end

	local old_mods = Mods
	local new_ids, old_ids = table.keys(new_mods), table.keys(old_mods)
	local any_changes = not (table.is_subset(new_ids, old_ids) and table.is_subset(old_ids, new_ids))
	if not any_changes then
		for id, new_mod in pairs(new_mods) do
			local old_mod = old_mods[id]
			if not old_mod or new_mod ~= old_mod then
				any_changes = true
				break
			end
		end
	end
	if not any_changes then
		for id, new_mod in pairs(new_mods) do
			new_mod:delete()
		end
	
		ModsList = ModsList or {}
		return
	end

	--delete all old mods
	local any_loaded = not not next(ModsLoaded)
	for id,mod in pairs(Mods or empty_table) do
		mod:delete()
	end

	Mods = new_mods
	
	-- add a reference to the mod in affected resources
	for id, mod in pairs(Mods) do
		if mod.affected_resources then
			for _, res in ipairs(mod.affected_resources) do
				res.mod = mod
			end
		end
	end
	
	-- if new mod defs are loaded/unloaded, clear the affected resources cache
	ClearModsAffectedResourcesCache()
	
	ModsList = {}
	for id, mod in pairs(Mods) do
		ModsList[#ModsList+1] = mod
		mod_print("once", "Loaded mod def %s (id %s, v%s) %s from %s", mod.title, mod.id, mod:GetVersionString(), mod.packed and "packed" or "unpacked", mod.source)
	end
	SortModsList()
	CacheModDependencyGraph()
	Msg("ModDefsLoaded")

	if any_loaded then
		ModsReloadItems()
	end
end

local function GetModAllDependencies(mod)
	local result = { }
	
	--local dependencies
	for i,dep in ipairs(mod.dependencies or empty_table) do
		if dep.id and dep.id ~= "" and not table.find(result, "id", dep.id) then
			table.insert(result, dep)
		end
	end
	return result
end

local function GetModDependenciesList(mod, result)
	result = result or { }
	if mod then
		local dependencies = GetModAllDependencies(mod)
		for i,dep in ipairs(dependencies) do
			local dep_id = dep.id
			local dep_mod = Mods[dep_id]
			if dep_mod then
				if table.find(result, dep_mod) then
					return "cycle"
				end
				table.insert(result, dep_mod)
				local err = GetModDependenciesList(dep_mod, result)
				if err then return err end
			else
				table.insert(result, dep_id)
			end
		end
	end
	return false, result
end

local function DetectDependencyError(dep, all, dep_mod, stack)
	if stack[dep.id] then --cycling dependencies
		return "cycle"
	elseif not table.find(all, dep.id) then --not in 'mods to load' list
		return "not loaded"
	elseif not dep:ModFits(dep_mod) then --incompatible
		return "incompatible"
	end
end

local function EnqueueMod(mod, all, queue, stack)
	if not mod then return "no mod" end
	if queue[mod.id] then return end
	
	local mod_queue = table.copy(queue)
	table.insert_unique(mod_queue, mod.id)
	mod_queue[mod.id] = mod

	local dependencies = GetModAllDependencies(mod)
	if next(dependencies) then
		stack[mod.id] = true
		for i,dep in ipairs(dependencies) do
			local dep_mod = Mods[dep.id]
			--forced mods don't go through dependency checks
			if not mod.force_reload then
				if dep_mod then --mod is preset
					local err = DetectDependencyError(dep, all, dep_mod, stack)
					if err then
						if err == "cycle" then
							local other_mods = { }
							for id in pairs(stack) do
								table.insert(other_mods, Untranslated(Mods[id].title))
							end
							ModLogF("Mod %s creates circular dependency cycle with %s.", mod:GetModLabel("plainText"), other_mods)
						elseif err == "not loaded" then
							ModLogF("Cannot load %s because required mod %s is not active.", mod:GetModLabel("plainText"), dep_mod:GetModLabel("plainText"))
						elseif err == "incompatible" then
							ModLogF("Cannot load %s because required mod %s is not compatible.", mod:GetModLabel("plainText"), dep_mod:GetModLabel("plainText"))
						end
						
						stack[mod.id] = nil
						if dep.required then
							return err
						end
					end
				else --mod is not present
					ModLogF("Cannot load %s because required mod %s is not found.", mod:GetModLabel("plainText"), dep.title)
					stack[mod.id] = nil
					return "not found"
				end
			end
			
			local err = EnqueueMod(dep_mod, all, mod_queue, stack)
			if err then
				--forced mods must be loaded no matter what
				if not mod.force_reload then
					stack[mod.id] = nil
					return err
				end
			end
		end
		stack[mod.id] = nil
	end
	
	for i, mod_id in ipairs(mod_queue) do
		if table.find(all, mod_id) then
			table.insert_unique(queue, mod_id)
			queue[mod_id] = mod_queue[mod_id]
		end
	end
end

local function GetLoadingQueue(list)
	local queue = { }
	for i, mod_id in ipairs(list) do
		EnqueueMod(Mods[mod_id], list, queue, { })
	end
	return queue
end


function GetModsToLoad()
	if not IsUserCreatedContentAllowed() then
		return empty_table
	end

	local list
	if (AccountStorage and AccountStorage.LoadAllMods) or config.LoadAllMods then
		list = table.keys(Mods)
		table.sort(list)
	end
	list = list or AccountStorage and table.icopy(AccountStorage.LoadMods) or {}

	-- Autodisable blacklisted mods
	AutoDisabledModsAlertText = { ["ban"] = {}, ["deprecate"] = {}}
	for idx, modId in ripairs(list) do
		local blacklistReason = GetModBlacklistedReason(modId)
		LocalStorage.AutoDisableDeprecated = LocalStorage.AutoDisableDeprecated or {} 
		local disableMod = (not LocalStorage.AutoDisableDeprecated[modId] and blacklistReason and blacklistReason == "deprecate") or (blacklistReason and blacklistReason == "ban")
		if disableMod and blacklistReason and Mods[modId] then
			table.insert(AutoDisabledModsAlertText[blacklistReason], Mods[modId]:GetModLabel("plainText"))
			TurnModOff(modId)
			LocalStorage.AutoDisableDeprecated = LocalStorage.AutoDisableDeprecated or {} 
			LocalStorage.AutoDisableDeprecated[modId] = true
			for _, presetData in pairs(LocalStorage.ModPresets) do
				if presetData.mod_ids[modId] then
					RemoveModFromModPreset(presetId, modId)
				end
			end
			table.remove(list, idx)
		end
	end
	
	SaveLocalStorage()
	
	list = table.ifilter(list, function(i, id)
		local mod = Mods[id]
		if not mod then
			ModLogF("Couldn't find mod %s from your account storage.", id)
			return
		end
		if not mod:IsTooOld() or mod.force_reload then
			return true
		else
			ModLogF("Outdated mod %s cannot be loaded. (Unsupported game version)", mod:GetModLabel("plainText"))
		end
	end)

	return GetLoadingQueue(list)
end

if FirstLoad then
g_CantLoadMods = {}
end

ErrorLoadingModsT = T(164802745041, "The following mods couldn't be loaded. Open the mod manager for more information:\n")
function WaitErrorLoadingMods(customErrorMsg)
	local errorMsg = customErrorMsg or ErrorLoadingModsT
	local modsToLoad = GetModsToLoad()
	local modsEnabledByUser
	if (AccountStorage and AccountStorage.LoadAllMods) or config.LoadAllMods then
		modsEnabledByUser = table.keys(Mods)
		table.sort(modsEnabledByUser)
	end
	modsEnabledByUser = modsEnabledByUser or AccountStorage and table.icopy(AccountStorage.LoadMods) or {}
	
	local modsFailedToLoad
	for idx, mod_id in ipairs(modsEnabledByUser) do
		if not table.find(modsToLoad, mod_id) then
			modsFailedToLoad = table.create_add(modsFailedToLoad, "<space>" .. (Mods[mod_id] and Mods[mod_id].title or mod_id))
			TurnModOff(mod_id, "updatePreset")
			g_CantLoadMods[mod_id] = true
		end
	end
	
	if g_ModsUIContextObj then
		g_ModsUIContextObj:GetInstalledMods()
	end
	
	if modsFailedToLoad then
		SaveAccountStorage(5000)
		modsFailedToLoad = table.concat(modsFailedToLoad, "\n")
		WaitMessage(
			terminal.dekstop,
			T(824112417429, "Warning"),
			T{675270242132, "<errorT><em><mods_list></em>", errorT = errorMsg, mods_list = Untranslated(modsFailedToLoad)},
			T(325411474155, "OK")
		)
	end
end

function ModsReloadItems(map_folder, force_reload, first_load)
	if not config.Mods then return end
	assert(IsRealTimeThread())
	
	local queue = GetModsToLoad()
	local list = table.copy(queue)
	table.sort(list)

	if not force_reload then
		--no changes to mods list?
		local loaded_ids = ModsLoaded and table.map(ModsLoaded, "id") or {}
		table.sort(loaded_ids)
		if table.iequal(loaded_ids, list) then
			return
		end
	end
	
	local reload_assets
	local reload_lua
	local has_data
	
	--unload old mods
	if ModsLoaded then
		for _,mod in ipairs(ModsLoaded) do
			if mod:ItemsLoaded() or mod.status == "deleted" then
				has_data = has_data or mod.has_data
				mod:UnloadItems()
				mod:UnloadOptions()
				--print("Unload mod", mod.id)
				if next(mod.code) then reload_lua = true end
				if next(mod.entities) then reload_assets = true end
			end
		end
	end
	
	--fill ModsLoaded with the new mods
	local old_loaded = ModsLoaded
	ModsLoaded = {}

	for i, id in ipairs(queue) do
		local mod = Mods[id]
		mod.force_reload = false
		assert(not table.find(ModsLoaded, mod))
		ModsLoaded[#ModsLoaded + 1] = mod
		if next(mod.code) then reload_lua = true end
		if next(mod.entities) then reload_assets = true end
	end

	--reload bin assets, if needed
	if reload_assets then
		RegisterModDelayedLoadEntities(ModsLoaded)
		if not first_load then
			ModsLoadAssets(map_folder)
			WaitDelayedLoadEntities()
		end
	end
	
	--loading options happens before the items and code to allow for access of CurrentModOptions
	for _, mod in ipairs(ModsLoaded) do
		mod:LoadOptions()
	end
	
	--reload Lua, if needed
	if first_load then
		return --will be continued during ReloadForDlc
	end
	
	if reload_lua then
		for i,mod in ipairs(old_loaded) do
			if not queue[mod.id] then
				--@@@msg ModUnloadLua, mod_id - fired just before unloading a mod with Lua code.
				Msg("ModUnloadLua", mod.id)
			end
		end
		ReloadLua()
	end

	return ContinueModsReloadItems(map_folder, reload_assets, has_data)
end

function ContinueModsReloadItems(map_folder, reload_assets, has_data)
	--load the items of the new mods
	for _, mod in ipairs(ModsLoaded) do
		if not mod:ItemsLoaded() then
			mod:LoadItems()
		end
		has_data = has_data or mod.has_data
	end
	mod_print("Loaded mod items for: %s", table.concat(table.map(ModsLoaded, "id"), ", "))

	--backwards compatibility for r342666
	local any_old_entity_mods
	for i, mod in ipairs(ModsLoaded) do
		if mod.bin_assets then
			mod:ForEachModItem("ModItemEntity", function(item)
				any_old_entity_mods = true
				DelayedLoadEntity(mod, item.entity_name)
			end)
		end
	end
	if any_old_entity_mods then
		RegisterModDelayedLoadEntities(ModsLoaded)
		ModsLoadAssets(map_folder)
		WaitDelayedLoadEntities()
		ReloadLua()
	end

	if reload_assets then
		ReloadClassEntities()
	end
	
	for _, mod in ipairs(ModsLoaded) do
		if mod:HasOptions() then
			Msg("ApplyModOptions", mod.id) --throw the msg here to make sure it is called after the lua is reloaded and everything for the mod is loaded
		end
	end

	PopulateParentTableCache(Mods)
	ObjModified(ModsList)
	--@@@msg ModsReloaded - fired right after mods are loaded, unloaded or changed.
	Msg("ModsReloaded")
	-- TODO: use has_data to raise a msg about changed data
end

function ProtectedModsReloadItems(map_folder, force_reload)
	LoadingScreenOpen("idLoadingScreen", "reload mod items")
	local old_render_mode = GetRenderMode()
	WaitRenderMode("ui")
	ModsReloadItems(map_folder, force_reload)
	WaitRenderMode(old_render_mode)
	LoadingScreenClose("idLoadingScreen", "reload mod items")
end

function ModsLoadAssets(map_folder)
	LoadingScreenOpen("idModEntitesReload", "ModEntitesReload")
	local old_render_mode = GetRenderMode()
	WaitRenderMode("ui")
	local lastMap = AreModdingToolsActive() and ModEditorMapName or CurrentMap --force reload the map to prevent issues with spawned objects from the mod on the current map
	ResetGameSession()
	ForceReloadBinAssets()
	DlcReloadAssets(DlcDefinitions)
	--actually reload the assets
	LoadBinAssets(map_folder or CurrentMapFolder)
	--wait & unmount
	while AreBinAssetsLoading() do
		Sleep(1)
	end

	ChangeMap(lastMap)
	WaitRenderMode(old_render_mode)
	hr.TR_ForceReloadNoTextures = 1
	LoadingScreenClose("idModEntitesReload", "ModEntitesReload")
end

if FirstLoad then
	LuaLoadedForMods = {}
	ModsPreGameMenuOpen = false
	ModsLoadCodeErrorsMessage = false
	ModsDisplayingMessage = false
end

local loadedWithErrorsT = T(306573510595, "Mod Loaded with Errors")

function OnMsg.PreGameMenuOpen()
	CreateRealTimeThread(function()
		ModsDisplayingMessage = true
		-- display mods that were loaded with errors
		if ModsLoadCodeErrorsMessage then
			WaitMessage(nil, loadedWithErrorsT, ModsLoadCodeErrorsMessage, T(1000136, "OK"))
			ModsLoadCodeErrorsMessage = false
		end
		-- display mods that were rejected (because of dependencies, blacklisting, etc.)
		WaitErrorLoadingMods()
		ModsDisplayingMessage = false
	end)
end

function DisplayModsLoadCodeErrorsMessage()
	CreateRealTimeThread(function()
		ModsDisplayingMessage = true
		WaitMessage(nil, loadedWithErrorsT, ModsLoadCodeErrorsMessage, T(1000136, "OK"))
		ModsLoadCodeErrorsMessage = false
		ModsDisplayingMessage = false
	end)
end

function ModsLoadCode() -- called while reloading Lua (in autorun.lua)
	local collected_errors = {}
	for _, mod in ipairs(ModsLoaded or empty_table) do
		local loading_errors = mod:LoadCode()
		if loading_errors then
			local errs = table.concat(loading_errors, "\n")
			ModLogF(true, string.format("Errors while loading mod %s:\n%s", mod.title, errs)) -- log in the mods log
			
			-- collect all mod loading errors to display to the user in a single message box
			table.insert(collected_errors,
				T{560233458867, "Mod <em><u(literal(title))></em>:\n<u(literal(errs))>", title = mod.title, errs = errs })
		end
	end
	
	if next(collected_errors) then
		ModsLoadCodeErrorsMessage = table.concat(collected_errors, "\n\n")
		--- if the pre-game menu hasn't been opened yet, the message will be displayed when it is
		if (config.MainMenu == 0 or ModsPreGameMenuOpen) and not ModsDisplayingMessage then
			DisplayModsLoadCodeErrorsMessage()
		end
	end
end

function ModsLoadLocTables()
	local list
	if not config.Mods then return end
	if AccountStorage and AccountStorage.LoadAllMods or config.LoadAllMods then
		list = table.keys(Mods)
		table.sort(list)
	end
	list = list or AccountStorage and AccountStorage.LoadMods or {}
	
	local loctables_loaded
	for i, id in ipairs(list) do
		local mod = Mods[id]
		if mod then
			if mod:IsTooOld() then
				ModLogF("Outdated mod %s cannot be loaded. (Unsupported game version)", mod:GetModLabel("plainText"))
			else
				for _, loctable in ipairs(mod.loctables or empty_table) do
					if loctable.language == GetLanguage() or loctable.language == "Any" then
						local file_path = mod.content_path .. loctable.filename
						if io.exists(file_path) then
							LoadTranslationTableFile(file_path)
							loctables_loaded = true
						end
					end
				end
			end
		end
	end
	if loctables_loaded then
		Msg("TranslationChanged")
	end
end

local function DebugWaitThreads(msg, ...)
	local threads = {}
	Msg(msg, threads, ...)
	while next(threads) do
		for i = #threads, 1, -1 do
			if not IsValidThread(threads[i]) then
				table.remove(threads, i)
			end
		end
		Sleep(100)
	end
end

function DebugWaitDownloadExternalMods(mods)
	DebugWaitThreads("DebugDownloadExternalMods", mods)
end

function DebugWaitCopyExternalMods(mods)
	DebugWaitThreads("DebugCopyExternalMods", mods)
end

function DebugDownloadSavegameMods(missings_mods)
	if not IsRealTimeThread() then
		CreateRealTimeThread(DebugDownloadSavegameMods)
		return
	end
	local mods = {}
	for _, mod in ipairs(missings_mods or SavegameMeta.active_mods) do
		if not Mods[mod.id] then
			mods[#mods + 1] = mod
		else
			printf("Mod with ID %s is already present in your local files.", mod.id)
		end
	end
	DebugWaitDownloadExternalMods(mods)
	DebugWaitCopyExternalMods(mods)
	for _, mod in ipairs(missings_mods or SavegameMeta.active_mods) do
		TurnModOn(mod.id)
	end
	SaveAccountStorage()
	ModsReloadDefs()
	ModsReloadItems()
end


----- ModItem

DefineClass.ModItem = {
	__parents = { "GedEditedObject", "InitDone", "ModElement", "Container" },
	properties = {
		{ category = "Mod", id = "name", name = "Name", default = "", editor = "text", },
		{ category = "Mod", id = "comment", name = "Comment", default = "", editor = "text", },
		{ category = "Mod", id = "Documentation", editor = "documentation", dont_save = true, sort_order = 9999999, }, -- display collapsible Documentation at this position
	},
	mod = false,
	EditorName = false,
	EditorView = Untranslated("<color 128 128 128><u(EditorName)></color><opt(ModItemDescription,' ','')><opt(u(comment),' <color 75 105 198>','</color>')>"),
	ModItemDescription = T(674857971939, "<u(name)>"),
	ContainerAddNewButtonMode = "children", -- add a + button to add child item in the tree view (if the ModItem can have children)
	GedTreeCollapsedByDefault = true,
}

function ModItem:IsOpenInGed()
	return not not GedObjects[ParentTableCache[self.mod]]
end

function ModItem:OnEditorNew(parent, ged, is_paste, duplicate_id, mod_id)
	-- Mod item presets can also be added through Preset Editors (see GedOpClonePresetInMod)
	-- In those cases the reference to the mod will be set from the mod_id parameter

	self.mod = (IsKindOf(parent, "ModDef") and parent or parent.mod) or (mod_id and Mods and Mods[mod_id])
	assert(self.mod, "Mod item has no reference to a mod")
end

function ModItem:OnAfterEditorNew(parent, ged, is_paste, old_id, mod_id)
	-- Mod item presets can also be added through Preset Editors (see GedOpClonePresetInMod)
	-- In those cases the reference to the mod will be set from the mod_id parameter

	self.mod = (IsKindOf(parent, "ModDef") and parent or parent.mod) or (mod_id and Mods and Mods[mod_id])
	assert(self.mod, "Mod item has no reference to a mod")
end

-- only used for ModItemPreset, which is not a ModItemUsingFiles
function ModItem:OnEditorDelete(mod, ged)
	local path = self:GetCodeFilePath()
	if path and path ~= "" then
		AsyncFileDelete(path)
	end
end

function ModItem:GetPropOSPathKey(prop_id)
	return string.format("%s_%s_%s", self.class, self.name, prop_id)
end

function ModItem:StoreOSPath(prop_id, value)
	local prop_meta = self:GetPropertyMetadata(prop_id)
	if prop_meta and prop_meta.os_path and prop_meta.dont_save then
		local key = self:GetPropOSPathKey(prop_id)
		table.set(LocalStorage, "ModItemOSPaths", self.mod.id, key, value)
		SaveLocalStorageDelayed()
	end
end

function ModItem:StoreOSPaths(prop_id, value)
	for i, prop_meta in ipairs(self:GetProperties()) do
		if prop_meta.os_path and prop_meta.dont_save then
			local prop_id = prop_meta.id
			local value = self:GetProperty(prop_id)
			self:StoreOSPath(prop_id, value)
		end
	end
end

function ModItem:RestoreOSPaths()
	for i, prop_meta in ipairs(self:GetProperties()) do
		if prop_meta.os_path and prop_meta.dont_save then
			local prop_id = prop_meta.id
			local key = self:GetPropOSPathKey(prop_id)
			local value = table.get(LocalStorage, "ModItemOSPaths", self.mod.id, key)
			if value ~= nil and not self:IsDefaultPropertyValue(prop_id, prop_meta, value) then
				self:SetProperty(prop_id, value)
			end
		end
	end
end

function ModItem:OnEditorSetProperty(prop_id, old_value, ged)
	self:StoreOSPath(prop_id, self:GetProperty(prop_id))
end

function ModItem:OnEditorSelect(selected, ged)
end

function ModItem:IsMounted()
	return self.mod and self.mod:IsMounted()
end

function ModItem:IsPacked()
	return self.mod and self.mod:IsPacked()
end

function ModItem:GetModRootPath()
	return self.mod and self.mod:GetModRootPath()
end

function ModItem:GetModContentPath()
	return self.mod and self.mod:GetModContentPath()
end

function ModItem:OnModLoad(mod)
	self:RestoreOSPaths()
	return ModElement.OnLoad(self, mod)
end

function ModItem:OnModUnload(mod)
	return ModElement.OnUnload(self, mod)
end

function ModItem:TestModItem(ged)
end

function ModItem:GetCodeFileName(name)
end

function ModItem:GetCodeFilePath(name)
	name = self:GetCodeFileName(name)
	if not name or name == "" then return "" end
	return self.mod and self.mod.content_path .. name
end

function ModItem:FindFreeFilename(name)
	local n = 1
	local file_name = name
	while io.exists(self:GetCodeFilePath(file_name)) do
		n = n + 1
		file_name = name .. tostring(n)
	end
	return file_name
end

function ModItem:CleanupForSave(injected_props, restore_data)
	restore_data = PropertyObject.CleanupForSave(self, injected_props, restore_data)
	restore_data[#restore_data + 1] = { obj = self, key = "mod", value = self.mod }
	self.mod = nil
	return restore_data
end

function ModItem:PreSave()
	self:StoreOSPaths()
	return ModElement.PreSave(self)
end

function ModItem:GetAffectedResources()
	return empty_table
end

function ModItem:GetMapName()
	-- return the map name if the mod item contains an editor map
end

function ModItem:ForEachModItem(classname, fn)
	if not fn then
		fn = classname
		classname = nil
	end
	if classname and not IsKindOf(self, classname) then return end
	return fn(self)
end

----- ModOptions

function ModOptionEditorContext(context, prop_meta)
	local value_fn = function() return context:GetProperty(prop_meta.id) end
	local prop_meta_subcontext = SubContext(prop_meta, {
		context_override = context,
	})
	local new_context = SubContext(context, {
		prop_meta = prop_meta_subcontext,
		value = value_fn,
	})
	
	if prop_meta.help and prop_meta.help ~= "" then
		new_context.RolloverTitle = Untranslated(prop_meta.name)
		new_context.RolloverText = Untranslated(prop_meta.help)
	end
	
	return new_context
end

DefineClass.ModOptionsObject = {
	__parents = { "PropertyObject" },
	
	__defaults = false,
	__mod = false,
}

function ModOptionsObject:Clone(class, parent)
	class = class or self.class
	local obj = g_Classes[class]:new(parent)
	obj.__mod = self.__mod
	obj:CopyProperties(self)
	return obj
end

function ModOptionsObject:GetProperties()
	local properties = rawget(self, "properties")
	if properties then return properties end
	
	local properties = {}
	self.properties = properties
	self.__defaults = {}

	local option_items = self.__mod:GetOptionItems()
	for i,option in ipairs(option_items) do
		local option_prop_meta = option:GetOptionMeta()
		table.insert(properties, option_prop_meta)
		self.__defaults[option.name] = option.DefaultValue
	end

	return properties
end

function ModOptionsObject:GetProperty(id)
	self:GetProperties()
	local value = rawget(self, id)
	if value ~= nil then return value end
	return self.__defaults[id]
end

function ModOptionsObject:SetProperty(id, value)
	rawset(self, id, value)
end

DefineClass.ModItemOption = {
	__parents = { "ModItem" },
	properties = {
		{ id = "name", name = "Id", editor = "text", default = "", translate = false, validate = ValidateIdentifier },
		{ id = "DisplayName", name = "Display Name", editor = "text", default = "", translate = false },
		{ id = "Help",        name = "Tooltip",      editor = "text", default = "", translate = false },
	},
	
	mod_option = false,
	ValueEditor = false,
	EditorSubmenu = "Mod options",
}

function ModItemOption:GetModItemDescription()
	if not self:IsDefaultPropertyValue("name", self:GetPropertyMetadata("name"), self:GetProperty("name")) then
		return Untranslated("<name> = <DefaultValue>")
	else
		return Untranslated("NewOption")
	end
end

function ModItemOption:OnEditorNew(parent, ged, is_paste)
	self.mod:LoadOptions()
end

function ModItemOption:OnModLoad()
	ModItem.OnModLoad(self)
	self.mod_option = self.class
end

function ModItemOption:GetOptionMeta()
	local display_name = self.DisplayName
	if not display_name or display_name == "" then
		display_name = self.name
	end
	
	return {
		id = self.name,
		name = T(display_name),
		editor = self.ValueEditor,
		default = self.DefaultValue,
		help = self.Help,
	}
end

function ModItemOption:NeedsResave()
	return self.mod.has_options --deprecated prop
end

DefineClass.ModItemOptionToggle = {
	__parents = { "ModItemOption" },
	properties = {
		{ id = "DefaultValue", name = "Default Value", editor = "bool", default = false },
	},
	
	ValueEditor = "bool",
	EditorName = "Option Toggle",
	Documentation = "Creates a UI entry which toggles between the 2 defined values when pressed.",
}

function ModItemOptionToggle:GetModItemDescription()
	return string.format("%s = %s", self.name, self.DefaultValue and "On" or "Off")
end

DefineClass.ModItemOptionNumber = {
	__parents = { "ModItemOption" },
	properties = {
		{ id = "DefaultValue", name = "Default Value", editor = "number", default = 0 },
		{ id = "MinValue",     name = "Min",           editor = "number", default = 0 },
		{ id = "MaxValue",     name = "Max",           editor = "number", default = 100 },
		{ id = "StepSize",     name = "Step Size",     editor = "number", default = 1 },
	},
	
	ValueEditor = "number",
	EditorName = "Option Number",
	Documentation = "Creates a UI entry with a slider.",
}

function ModItemOptionNumber:GetOptionMeta()
	local meta = ModItemOption.GetOptionMeta(self)
	meta.min = self.MinValue
	meta.max = self.MaxValue
	meta.step = self.StepSize
	meta.slider = true
	meta.show_value_text = true
	return meta
end

DefineClass.ModItemOptionChoice = {
	__parents = { "ModItemOption" },
	properties = {
		{ id = "DefaultValue", name = "Default Value", editor = "choice", default = "", items = function(self) return self.ChoiceList end },
		{ id = "ChoiceList",   name = "Choice List",   editor = "string_list", default = false }
	},
	
	ValueEditor = "choice",
	EditorName = "Option Choice",
	Documentation = "Creates a UI entry with a dropdown that contains all listed options.",
}

function ModItemOptionChoice:GetOptionMeta()
	local meta = ModItemOption.GetOptionMeta(self)
	meta.items = { }
	for i,item in ipairs(self.ChoiceList or empty_table) do
		table.insert(meta.items, { text = T(item), value = item })
	end
	return meta
end


----- ModDependency

local function GetModDependencyDescription(mod)
	return string.format("%s - %s - v %d.%d", mod.title, mod.id, mod.version_major, mod.version_minor)
end

function ModDependencyCombo()
	local result = { }
	for id,mod in pairs(Mods) do
		local text = GetModDependencyDescription(mod)
		local entry = { id = id, text = Untranslated(text) }
		table.insert(result, entry)
	end
	
	return result
end

DefineClass.ModDependency = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "id",             name = "Mod",            editor = "combo",  default = "", items = ModDependencyCombo },
		{ id = "title",          name = "Title",          editor = "text",   default = "", translate = false,
			read_only = function(dep) return dep.id ~= "" end,
			no_edit = function(dep) return dep.title == "" or dep.id == "" or Mods[dep.id] end }, --editor visible when mod is selected but is missing
		{ id = "version_major",  name = "Major Version",  editor = "number", default = 0 },
		{ id = "version_minor",  name = "Minor Version",  editor = "number", default = 0 },
		{ id = "required",       name = "Required",       editor = "bool",   default = true, help = "A non-required dependency mod will be loaded before your mod, if it is present." },
	},
	own_mod = false, --used for display purposes, assigned in CacheModDependencyGraph
}

function ModDependency:ModFits(mod_def)
	if not mod_def then return false, "no mod" end
	if self.id ~= mod_def.id then return false, "different mod" end
	if mod_def:CompareVersion(self, "ignore_revision") < 0 then return false, "incompatible" end
	return true
end

function ModDependency:GetEditorView()
	local mod = Mods[self.id]
	if mod then
		return GetModDependencyDescription(self) --needs to be self, so the correct version is displayed
	end
	
	return self.class
end

function ModDependency:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "id" then
		local mod = Mods[self.id]
		if mod then
			local err, list = GetModDependenciesList(mod)
			if err == "cycle" then
				ged:ShowMessage("Warning: Cycle", "This mod dependency creates a cycle (or refers to an already existing cycle)")
			end
			self.title = mod.title
			self.version_major = mod.version_major
			self.version_minor = mod.version_minor
		else
			self.title = nil
			self.version_major = nil
			self.version_minor = nil
		end
	end
end

-----

if FirstLoad then
	ModDependencyGraph = false
end

local function CollapseDependencyGraph(node, direction, root_id, all_nodes, visited, list, list_failed)
	list = list or { }
	list_failed = list_failed or { }
	visited = visited or { }
	
	if not visited[node] then
		visited[node] = true
		for i,dep in ipairs(node[direction]) do
			local dep_mod = Mods[dep.id]
			local successful = dep:ModFits(dep_mod)
			local target_list = successful and list or list_failed
			
			--avoid having two entries that have the same mod member
			local idx 
			if direction == "incoming" then
				idx = table.find(target_list, "own_mod", dep.own_mod)
			else
				idx = table.find(target_list, "id", dep.id)
			end
			if idx then
				--strive to have a required entry, instead of an optional one
				if not target_list[idx].required then
					target_list[idx] = dep
				end
			else
				--issues between other mods are not reported only if the direction is 'outgoing'
				--others do not interfere with the workings of this mod
				if direction == "outgoing" or successful or dep.id == root_id then
					table.insert(target_list, dep)
				end
			end
			
			if successful then
				local next_id = (direction == "outgoing") and dep.id or dep.own_mod.id
				CollapseDependencyGraph(all_nodes[next_id], direction, root_id, all_nodes, visited, list, list_failed)
			end
		end
	end
	
	return list, list_failed
end

function CacheModDependencyGraph()
	--'incoming' are mods that depend on this one
	--'outgoing' are mods that this one depends on
	
	local nodes = { }
	for id,mod in pairs(Mods) do
		local entry = nodes[id] or { incoming = { }, outgoing = { } }
		nodes[id] = entry
		entry.outgoing = GetModAllDependencies(mod)
		for i,dep in ipairs(entry.outgoing) do
			dep.own_mod = mod
			local dep_entry = nodes[dep.id] or { incoming = { }, outgoing = { } }
			nodes[dep.id] = dep_entry
			table.insert(dep_entry.incoming, dep)
		end
	end
	
	ModDependencyGraph = { }
	for id,mod in pairs(Mods) do
		local root_id = mod.id
		local outgoing, outgoing_failed = CollapseDependencyGraph(nodes[root_id], "outgoing", root_id, nodes)
		local incoming, incoming_failed = CollapseDependencyGraph(nodes[root_id], "incoming", root_id, nodes)
		ModDependencyGraph[id] = {
			outgoing = outgoing,
			incoming = incoming,
			outgoing_failed = outgoing_failed,
			incoming_failed = incoming_failed,
		}
	end
end

function WaitWarnAboutSkippedMods()
	local all_mods = AccountStorage and AccountStorage.LoadMods
	local skipped_mods = {}
	for _, id in ipairs(all_mods or empty_table) do
		local dependency_data = ModDependencyGraph and ModDependencyGraph[id]
		if dependency_data then
			for _, dep in ipairs(dependency_data.outgoing or empty_table) do
				if dep.required and not table.find(AccountStorage.LoadMods, dep.id) then
					table.insert_unique(skipped_mods, dep.own_mod.title)
				end
			end
			for _, dep in ipairs(dependency_data.outgoing_failed or empty_table) do
				if dep.required then
					table.insert_unique(skipped_mods, dep.own_mod.title)
				end
			end
		end
	end
	if #(skipped_mods or "") > 0 then
		local skipped = table.concat(skipped_mods, "\n")
		WaitMessage(terminal.desktop, 
			T(824112417429, "Warning"),
			T{949870544095, "The following mods will not be loaded because of missing or incompatible mods that they require:\n\n<skipped>", skipped = Untranslated(skipped)},
			T(325411474155, "OK")
		)
	end
end

----

if FirstLoad then
	ReportedMods = false
end
	
function ReportModLuaError(mod, err, stack)
	ReportedMods = ReportedMods or {}
	if ReportedMods[mod.id] then
		return
	end
	ReportedMods[mod.id] = true
	local v_major = mod.version_major or ModDef.version_major
	local v_minor = mod.version_minor or ModDef.version_minor
	local v = mod.version or ModDef.version
	local ver_str = string.format("%d.%02d-%03d", v_major or 0, v_minor or 0, v or 0)
	ModLogF(true, "Lua error in mod %s (id %s, v%s) from %s", mod.title, mod.id, ver_str, mod.source)
	Msg("OnModLuaError", mod, err, stack)
end

function OnMsg.ModsReloaded()
	SetSpecialLuaErrorHandling("Mods", #ModsLoaded > 0)
end

function OnMsg.OnLuaError(err, stack)
	for _, mod in ipairs(ModsLoaded) do
		if mod.content_path then
			if string.find_lower(err, mod.content_path) or string.find_lower(stack, mod.content_path) then
				ReportModLuaError(mod, err, stack)
			end
		end
	end
end

---

if not Platform.developer then
	if Platform.asserts then
		OnMsg.EngineStarted = function()
			ConsoleSetEnabled(true)
		end
	else
		OnMsg.ChangeMap = function(map)
			local dev_tools_visible = IsModEditorMap(map) or IsEditorActive()
			ConsoleSetEnabled(dev_tools_visible)
			local dev_interface = GetDialog(GetDevUIViewport())
			if dev_interface then
				dev_interface:SetUIVisible(dev_tools_visible)
			end
		end
	end
end

--Gossip loaded mods info
function GossipMods()
	local loadedMods = {}
	for _, mod in ipairs(ModsLoaded or empty_table) do
		table.insert(loadedMods, {id = mod.id, name = mod.title, version = mod.version})
	end
	NetGossip("Mods", loadedMods)
end

OnMsg.ModsReloaded = GossipMods
OnMsg.NetConnect = GossipMods

function GetModBlacklistedReason(modId)
	return ModIdBlacklist[modId]
end

function TFormat.BlacklistedMods(deprecatedMods, bannedMods)
	local deprecatedT = T{711775436656, "The following mods are now deprecated. They have been integrated into the base game and will be automatically disabled:\n<em><u(mods_list)></em>", mods_list = deprecatedMods}
	local bannedT = T{872385252314, "The following mods have been blacklisted and automatically blocked:\n<em><u(mods_list)></em>", mods_list = bannedMods}
	if deprecatedMods and bannedMods then
		return T{942032529432, "<deprecated>\n\n<banned>", deprecated = deprecatedT, banned = bannedT}
	elseif deprecatedMods then
		return deprecatedT
	elseif bannedMods then
		return bannedT
	end
end

function CheckBlacklistedMods()
	local deprecatedMods = next(AutoDisabledModsAlertText["deprecate"]) and table.concat(AutoDisabledModsAlertText["deprecate"], "\n") or false
	local bannedMods = next(AutoDisabledModsAlertText["ban"]) and table.concat(AutoDisabledModsAlertText["ban"], "\n") or false
	if not deprecatedMods and not bannedMods then return end
	
	CreateRealTimeThread(function()
		local textT = TFormat.BlacklistedMods(deprecatedMods, bannedMods)
		WaitMessage(
			terminal.dekstop,
			T(824112417429, "Warning"),
			textT,
			T(784547514723, "Ok")
		)
		AutoDisabledModsAlertText = {}
	end)
end

OnMsg.PreGameMenuOpen = CheckBlacklistedMods


----- ModResourceDescriptor

DefineClass.ModResourceDescriptor = {
	__parents = { "PropertyObject" },
	properties = {
	},
	mod = false, -- reference to the mod which affected the described resource
}

function ModResourceDescriptor:CheckForConflict(other)
	return false
end

function ModResourceDescriptor:GetResourceTextDescription(conflict_reason)
	return ""
end


----- Mod Conflicts

function ClearModsAffectedResourcesCache()
	ModsAffectedResourcesCache = { valid = false }
end

if FirstLoad then
	ModsAffectedResourcesCache = false
	ClearModsAffectedResourcesCache()
end

-- Populate the affected resources cache using the loaded mods
function FillModsAffectedResourcesCache()
	ClearModsAffectedResourcesCache()
	
	for idx, mod in ipairs(ModsLoaded) do
		if mod.affected_resources then
			for _, res in ipairs(mod.affected_resources) do
				if not ModsAffectedResourcesCache[res.class] then
					ModsAffectedResourcesCache[res.class] = {}
				end
				table.insert(ModsAffectedResourcesCache[res.class], res)
			end
		end
	end
	
	ModsAffectedResourcesCache.valid = true
end

-- Add the given to-be-loaded mod's affected resources to the affected resources cache if they aren't already in it
function AddToModsAffectedResourcesCache(mod)
	if not mod.affected_resources then return end
	
	for _, res in ipairs(mod.affected_resources) do
		if not ModsAffectedResourcesCache[res.class] then
			ModsAffectedResourcesCache[res.class] = {}
		end
		table.insert_unique(ModsAffectedResourcesCache[res.class], res)
	end
end

-- Remove the given to-be-loaded mod's affected resources from the affected resources cache if they are in it
function RemoveFromModsAffectedResourcesCache(mod)
	if not mod.affected_resources then return end
	
	for _, res in ipairs(mod.affected_resources) do
		if ModsAffectedResourcesCache[res.class] then
			local idx = table.find(ModsAffectedResourcesCache[res.class], res)
			
			if idx then
				table.remove(ModsAffectedResourcesCache[res.class], idx)
			end
		end
	end
end

-- Get the conflicts between all loaded (and to-be-loaded) mods.
-- There's a conflict when the two mods affect the same game resource described by ModResourceDescriptors.
function GetAllLoadedModsConflicts()
	if not ModsAffectedResourcesCache or not ModsAffectedResourcesCache.valid then
		FillModsAffectedResourcesCache()
	end
	
	local conflicts = {}
	for idx, mod in ipairs(ModsLoaded) do
		local mod_conflicts = GetSingleModConflicts(mod)
		table.iappend(conflicts, mod_conflicts)
	end

	return conflicts
end

-- Get the conflicts the given mod has with other loaded (and to-be-loaded) mods.
-- There's a conflict when the two mods affect the same game resource described by ModResourceDescriptors.
function GetSingleModConflicts(mod)
	if not ModsAffectedResourcesCache or not ModsAffectedResourcesCache.valid then
		FillModsAffectedResourcesCache()
	end
	
	local conflicts = {}
	for _, res in ipairs(mod.affected_resources or empty_table) do
		if ModsAffectedResourcesCache[res.class] then
		
			local resources_to_check = ModsAffectedResourcesCache[res.class] or empty_table
			for _, other_res in ipairs(resources_to_check) do
				if res ~= other_res and mod.id ~= other_res.mod.id then
					local conflict, reason = res:CheckForConflict(other_res)
					if conflict then
						local msg =  res:GetResourceTextDescription(reason)
						
						-- Check if this msg and mod pair has already been recorded
						-- This is for mods that conflict on the same resource multiple times
						local duplicate_msg = false
						for _, conf in ipairs(conflicts) do
							if conf.msg == msg and conf.mod1 == mod.id and conf.mod2 == other_res.mod.id then
								duplicate_msg = true
								break
							end
						end
						
						if not duplicate_msg then
							table.insert(conflicts, { mod1 = mod.id, mod2 = other_res.mod.id, msg = msg })
						end
					end
				end
			end

		end
	end
	
	table.sortby_field(conflicts, "mod2")
	return conflicts
end

-- Creates a formatted message about the given mod's conflicts based on the result of GetSingleModConflicts()
function GetModConflictsMessage(mod, conflicts)
	local msg = ""
	local prev_mod2 
	for _, conf in ipairs(conflicts) do
		local title2 = Mods[conf.mod2] and Mods[conf.mod2].title
		if not prev_mod2 then
			msg = string.format("<em>%s</em>:\n", title2)
			prev_mod2 = conf.mod2
		end
		
		if prev_mod2 == conf.mod2 then
			msg = string.format("%s\n - %s", msg, conf.msg)
		else
			msg = string.format("%s\n\n<em>%s</em>:\n - %s", msg, title2, conf.msg)
		end
		
		prev_mod2 = conf.mod2
	end
	
	return msg
end
