----- Play box / play area utility function

function GetPlayBox(border)
	local pb = mapdata.PassBorder + (border or 0)
	local mw, mh = terrain.GetMapSize()
	local maxh = const.MaxTerrainHeight
	return boxdiag(pb, pb, 0, mw - pb, mh - pb, maxh)
end

function ClampToPlayArea(pt)
	return terrain.ClampPoint(pt, mapdata.PassBorder)
end

function GetTerrainCursorClamped()
	return ClampToPlayArea(GetTerrainCursor())
end


----- Misc

if FirstLoad then
	UpdateMapDataThread = false
end

MapTypesCombo = { "game", "system" }

function HGMembersCombo(group, extra_item)
	return function()
		local combo = extra_item and { extra_item } or {}
		for name, _ in sorted_pairs(table.get(Presets, "HGMember", group)) do
			if type(name) == "string" then
				table.insert(combo, name)
			end
		end
		return combo
	end
end

function MapOrientCombo()
	return {
		{ text = "East", value = 0 },
		{ text = "South", value = 90 },
		{ text = "West", value = 180 },
		{ text = "North", value = 270 },
	}
end

function MapNorthOrientCombo()
	return {
		{ text = "East(90)", value = 90 },
		{ text = "South(180)", value = 180 },
		{ text = "West(270)", value = 270 },
		{ text = "North(0)", value = 0 },
	}
end

local map_statuses = { 
	{ id = "Not started",       color = "<color 205 32 32>" },
	{ id = "In progress",       color = "" },
	{ id = "Awaiting feedback", color = "<color 180 0 180>" },
	{ id = "Blocked",           color = "<color 205 32 32>" },
	{ id = "Ready",             color = "<color 0 128 0>" },
}
for _, item in ipairs(map_statuses) do map_statuses[item.id] = item.color end


----- MapDataPresetFilter

local filter_by = {
	{ id = "Map production status",       color_prop = "Status",          prop_match = function(id) return id == "Author" or id == "Status" end },
	{ id = "Scripting production status", color_prop = "ScriptingStatus", prop_match = function(id) return id:starts_with("Scripting") end, },
	{ id = "Sounds production status",    color_prop = "SoundsStatus",    prop_match = function(id) return id:starts_with("Sounds") end },
}

DefineClass.MapDataPresetFilter = {
	__parents = { "GedFilter" },
	
	properties = {
		no_edit = function(self, prop_meta)
			local match_fn = table.find_value(filter_by, "id", self.FilterBy).prop_match
			return prop_meta.id ~= "FilterBy" and prop_meta.id ~= "_" and prop_meta.id ~= "Tags" and not (match_fn and match_fn(prop_meta.id))
		end,
		{ id = "FilterBy",        name = "Filter/colorize by", editor = "choice", default = filter_by[1].id, items = filter_by },
		{ id = "Author",          name = "Map author",         editor = "choice", default = "", items = HGMembersCombo("Level Design", "") },
		{ id = "Status",          name = "Map status",         editor = "choice", default = "", items = table.iappend({""}, map_statuses) },
		{ id = "ScriptingAuthor", name = "Scripting author",   editor = "choice", default = "", items = HGMembersCombo("Design", "") },
		{ id = "ScriptingStatus", name = "Scripting status",   editor = "choice", default = "", items = table.iappend({""}, map_statuses) },
		{ id = "SoundsStatus",    name = "Sounds status",      editor = "choice", default = "", items = table.iappend({""}, map_statuses) },
		{ id = "Tags",            name = "Tags",               editor = "set",    default = set({ old = false }), three_state = true, items = { "old", "prefab", "random", "test", "playable" } },
	},
}

function MapDataPresetFilter:FilterObject(o)
	if not IsKindOf(o, "MapDataPreset") then return true end
	
	local filtered = true
	-- Tags
	if self.Tags.old then
		filtered = filtered and IsOldMap(o.id)
	elseif self.Tags.old == false then
		filtered = filtered and not IsOldMap(o.id)
	end
	
	if self.Tags.prefab then
		filtered = filtered and o.IsPrefabMap
	elseif self.Tags.prefab == false then
		filtered = filtered and not o.IsPrefabMap
	end
	
	if self.Tags.random then
		filtered = filtered and o.IsRandomMap
	elseif self.Tags.random == false then
		filtered = filtered and not o.IsRandomMap
	end
	
	if self.Tags.test then
		filtered = filtered and IsTestMap(o.id)
	elseif self.Tags.test == false then
		filtered = filtered and not IsTestMap(o.id)
	end
	
	if self.Tags.playable then
		filtered = filtered and o.GameLogic
	elseif self.Tags.playable == false then
		filtered = filtered and not o.GameLogic
	end
	-- end of Tags

	if self.FilterBy == "Map production status" then
		return filtered and (self.Author == "" or self.Author == o.Author) and (self.Status == "" or self.Status == o.Status)
	elseif self.FilterBy == "Scripting production status" then
		return filtered and (self.ScriptingAuthor == "" or self.ScriptingAuthor == o.ScriptingAuthor) and (self.ScriptingStatus == "" or self.ScriptingStatus == o.ScriptingStatus)
	elseif self.FilterBy == "Sounds production status" then
		return filtered and self.SoundsStatus == "" or self.SoundsStatus == o.SoundsStatus
	end
	
	return filtered
end

function MapDataPresetFilter:TryReset(ged, op, to_view)
	return false
end


----- MapDataPreset

DefineClass.MapDataPreset = {
	__parents = { "Preset" },
	properties = {
		{ category = "Production", id = "Author",          name = "Map author",       editor = "choice", items = HGMembersCombo("Level Design"), default = false },
		{ category = "Production", id = "Status",          name = "Map status",       editor = "choice", items = map_statuses, default = map_statuses[1].id },
		{ category = "Production", id = "ScriptingAuthor", name = "Scripting author", editor = "choice", items = HGMembersCombo("Design"), default = false },
		{ category = "Production", id = "ScriptingStatus", name = "Scripting status", editor = "choice", items = map_statuses, default = map_statuses[1].id },
		{ category = "Production", id = "SoundsStatus",    name = "Sounds status",    editor = "choice", items = map_statuses, default = map_statuses[1].id },
		
		{ category = "Base", id = "DisplayName", name = "Display name", editor = "text", default = "", translate = true, help = "Translated Map name" },
		{ category = "Base", id = "Description", name = "Description", editor = "text", lines = 5, default = "", translate = true, help = "Translated Map description" },
		{ category = "Base", id = "MapType", editor = "combo", default = "game", items = function () return MapTypesCombo end, developer = true },
		{ category = "Base", id = "GameLogic", editor = "bool", default = true, no_edit = function(self) return self.MapType == "system" end, developer = true },
		{ category = "Base", id = "ArbitraryScale", name = "Allow arbitrary object scale", editor = "bool", default = false, developer = true },
		{ category = "Base", id = "Width",  name = "Width (tiles)",  editor = "number", min = 1, max = const.MaxMapWidth  or 6145, step = 128, slider = true, default = 257, no_validate = true },
		{ category = "Base", id = "Height", name = "Height (tiles)", editor = "number", min = 1, max = const.MaxMapHeight or 6145, step = 128, slider = true, default = 257, no_validate = true },
		{ category = "Base", id = "_mapsize", editor = "help", help = function(self) return string.format("Map size (meters): %dm x %dm", MulDivTrunc(self.Width - 1, const.HeightTileSize, guim), MulDivTrunc(self.Height - 1, const.HeightTileSize, guim)) end, },
		{ category = "Base", id = "NoTerrain", editor = "bool", default = false, },
		{ category = "Base", id = "DisablePassability", editor = "bool", default = false, },
		{ category = "Base", id = "ModEditor", editor = "bool", default = false, },
		
		{ category = "Camera", id = "CameraUseBorderArea", editor = "bool", default = true, help = "Use Border marker's area for camera area." },
		{ category = "Camera", id = "CameraArea", editor = "number", default = 100, min = 0, max = max_int, help = "With center of map as center, this is the length of the bounding square side in voxels." },
		{ category = "Camera", id = "CameraFloorHeight", editor = "number", default = 5, min = 0, max = 20, help = "The voxel height of camera floors."},
		{ category = "Camera", id = "CameraMaxFloor", editor = "number", default = 5, min = 0, max = 20, help = "The highest camera floors, counting from 0."},
		{ category = "Camera", id = "CameraType", editor = "choice", default = "Max", items = GetCameraTypesItems},	
		{ category = "Camera", id = "CameraPos", editor = "point", default = false},
		{ category = "Camera", id = "CameraLookAt", editor = "point", default = false},
		{ category = "Camera", id = "CameraFovX", editor = "number", default = false},
		{ category = "Camera", id = "buttons", editor = "buttons", default = "RTS", buttons = {{name = "View Camera", func = "ViewCamera"}, {name = "Set Camera", func = "SetCamera"}}},
			
		{ category = "Random Map", id = "IsPrefabMap", editor = "bool", default = false, read_only = true },
		{ category = "Random Map", id = "IsRandomMap", editor = "bool", default = false, },
		
		{ category = "Visual", id = "Lightmodel", editor = "preset_id", default = false, preset_class = "LightmodelPreset", help = "", developer = true},
		{ category = "Visual", id = "EditorLightmodel", editor = "preset_id", default = false, preset_class = "LightmodelPreset", help = "", developer = true},
		{ category = "Visual", id = "AtmosphericParticles", editor = "combo", default = "", items = ParticlesComboItems, buttons = {{name = "Edit", func = "EditParticleAction"}}, developer = true},

		{ category = "Orientation", id = "MapOrientation", name = "North", editor = "choice", items = MapNorthOrientCombo, default = 0, buttons = {{name = "Look North", func = "LookNorth"}} },
		
		{ category = "Terrain", id = "Terrain", editor = "bool", default = true, help = "Enable drawing of terrain", developer = true},
		{ category = "Terrain", id = "BaseLayer", name = "Terrain base layer", editor = "combo", items = function() return GetTerrainNamesCombo() end, default = "", developer = true},
		{ category = "Terrain", id = "ZOrder", editor = "choice", default = "z_order", items = { "z_order", "z_order_2nd" }, help = "Indicates which Z Order property from terrains to use for sorting", developer = true},
		{ category = "Terrain", id = "OrthoTop", editor = "number", default = 50*guim, scale = "m", developer = true },
		{ category = "Terrain", id = "OrthoBottom", editor = "number", default = 0, scale = "m", developer = true },
		{ category = "Terrain", id = "PassBorder", name = "Passability border", editor = "number", default = 0, scale = "m", developer = true, help = "Width of the border zone with no passability" },
		{ category = "Terrain", id = "PassBorderTiles", name = "Passability border (tiles)", editor = "number", default = 0, developer = true },
		{ category = "Terrain", id = "TerrainTreeRows", name = "Number of terrain trees per row(NxN grid)", editor = "number", default = 4, developer = true },
		{ category = "Terrain", id = "HeightMapAvg", name = "Height Avg", editor = "number", default = 0, scale = "m", read_only = true },
		{ category = "Terrain", id = "HeightMapMin", name = "Height Min", editor = "number", default = 0, scale = "m", read_only = true },
		{ category = "Terrain", id = "HeightMapMax", name = "Height Max", editor = "number", default = 0, scale = "m", read_only = true },
		
		{ category = "Audio", id = "Playlist",     editor = "combo", default = "", items = PlaylistComboItems, developer = true},
		{ category = "Audio", id = "Blacklist",    editor = "prop_table", default = false, no_edit = true },
		{ category = "Audio", id = "BlacklistStr", name = "Blacklist", editor = "text", lines = 5, default = "", developer = true, buttons = {{name = "Add", func = "ActionAddToBlackList"}}, dont_save = true },
		{ category = "Audio", id = "Reverb",       editor = "preset_id", default = false, preset_class = "ReverbDef", developer = true},
		
		{ category = "Objects", id = "MaxObjRadius",    editor = "number", default = 0, scale = "m", read_only = true, buttons = {{name = "Show", func = "ShowMapMaxRadiusObj"}} },
		{ category = "Objects", id = "MaxSurfRadius2D", editor = "number", default = 0, scale = "m", read_only = true, buttons = {{name = "Show", func = "ShowMapMaxSurfObj"}} },
		
		{ category = "Markers", id = "LockMarkerChanges", name = "Lock markers changes", editor = "bool", default = false, help = "Disable changing marker meta (e.g. prefab markers)." },
		{ category = "Markers", id = "markers", editor = "prop_table", default = {}, no_edit = true },
		{ category = "Markers", id = "MapMarkersCount", name = "Map markers count", editor = "number", default = 0, read_only = true },

		{ category = "Compatibility", id = "PublishRevision",   name = "Published revision",        editor = "number", default = 0, help = "The first revision where the map has been officially published. Should be filled to ensure compatibility after map changes." },
		{ category = "Compatibility", id = "CreateRevisionOld", name = "Compatibility revision",    editor = "number", default = 0, read_only = true, help = "Revision when the compatibility map ('old') was created. The 'AssetsRevision' of the 'old' maps is actually the revision of the original map." },
		{ category = "Compatibility", id = "ForcePackOld",      name = "Compatibility pack",        editor = "bool",   default = false, help = "Force the map to be packed in builds when being a compatibility map ('old')." },
		
		{ category = "Developer", id = "StartupEnable", name = "Use startup",    editor = "bool",       default = false, dev_option = true },
		{ category = "Developer", id = "StartupCam",    name = "Startup cam",    editor = "prop_table", default = false, dev_option = true, no_edit = PropChecker("StartupEnable", false), buttons = {{name = "Update", func = "UpdateStartup"}, {name = "Goto", func = "GotoStartup"}} },
		{ category = "Developer", id = "StartupEditor", name = "Startup editor", editor = "bool",       default = false, dev_option = true, no_edit = PropChecker("StartupEnable", false) },
		
		{ category = "Developer", id = "LuaRevision",     editor = "number", default = 0, read_only = true },
		{ category = "Developer", id = "OrgLuaRevision",  editor = "number", default = 0, read_only = true },
		{ category = "Developer", id = "AssetsRevision",  editor = "number", default = 0, read_only = true },
	
		{ category = "Developer", id = "NetHash",         name = "Net hash",     editor = "number", default = 0, read_only = true },
		{ category = "Developer", id = "ObjectsHash",     name = "Objects hash", editor = "number", default = 0, read_only = true },
		{ category = "Developer", id = "TerrainHash",     name = "Terrain hash", editor = "number", default = 0, read_only = true },
		{ category = "Developer", id = "SaveEntityList",  name = "Save entity list",   editor = "bool", default = false, help = "Saves all entities used on that map, e.g. Objects, Markers, Auto Attaches..." },
		{ category = "Developer", id = "InternalTesting", name = "Used for testing", editor = "bool", default = false, help = "This map is somehow related to testing." },
		
	},

	Zoom = false,
	
	SingleFile = false,
	GlobalMap = "MapData",
	
	GedEditor = "GedMapDataEditor",
	EditorMenubarName = false, -- Used to avoid generating an Action to open this editor (added manually)
	
	EditorViewPresetPostfix = Untranslated("<color 128 128 128><opt(u(Author),' [',']')></color>"),
	FilterClass = "MapDataPresetFilter",
}

if config.ModdingToolsInUserMode then
	MapDataPreset.FilterClass = nil
end

function EditParticleAction(root, obj, prop_id, ged)
	local parsysid = obj[prop_id]
	if parsysid and parsysid ~= "" then
		EditParticleSystem(parsysid)
	end
end

function LookNorth(root, obj, prop_id, ged)
	local pos, lookat, camtype = GetCamera()
	local cam_orient = CalcOrientation(pos, lookat)
	local map_orient = (obj.MapOrientation - 90) * 60
	local cam_vector = RotateAxis(lookat - pos, point(0, 0, 4096), map_orient - cam_orient)
	if camtype == "Max" then
		InterpolateCameraMaxWakeup({ pos = pos, lookat = lookat }, { pos = pos - cam_vector, lookat = pos }, 650, nil, "polar", "deccelerated")
	else
		SetCamera(pos - cam_vector, pos, camtype)
	end
end

function DeveloperChangeMap(...)
	local editor_mode = Platform.editor and IsEditorActive()
	
	if not editor.IsModdingEditor() then
		-- Ivko: Consider removing this temporary going out of editor, which has caused countless problems
		XShortcutsSetMode("Game") -- This will exit the editor by the virtue of the mode_exit_func
	end
	CloseMenuDialogs()
	Msg("DevUIMapChangePrep", ...)
	ChangeMap(...)
	StoreLastLoadedMap()
	
	if editor_mode then
		EditorActivate()
	end
end

function GedMapDataOpenMap(ged)
	local preset = ged.selected_object
	if IsKindOf(preset, "MapDataPreset") then
		CreateRealTimeThread(DeveloperChangeMap, preset.id)
	elseif IsKindOf(preset, "MapVariationPreset") then
		EditorActivate()
		CreateRealTimeThread(DeveloperChangeMap, preset:GetMap(), preset.id)
	end
end

function MapDataPreset:GetPresetStatusText()
	return "Double click to open map."
end

function MapDataPreset:GetEditorViewPresetPrefix()
	local ged = FindGedApp(MapDataPreset.GedEditor)
	local filter = ged and ged:FindFilter("root")
	local color_prop = filter and table.find_value(filter_by, "id", filter.FilterBy).color_prop or "Status"
	return map_statuses[self[color_prop]] or ""
end

function MapDataPreset:GetMapName()
	return self.id
end

function MapDataPreset:SetPassBorderTiles(tiles)
	self.PassBorder = tiles * const.HeightTileSize
	ObjModified(self)
end

function MapDataPreset:GetPassBorderTiles()
	return self.PassBorder / const.HeightTileSize
end

function MapDataPreset:ActionAddToBlackList(preset, prop_id, ged)
	local track, err = ged:WaitUserInput("", "Select track", PlaylistTracksCombo())
	if not track or track == "" then
		return
	end
	local blacklist = self.Blacklist or {}
	table.insert_unique(blacklist, track)
	preset.Blacklist = #blacklist > 0 and blacklist or nil
	ObjModified(self)
end

function MapDataPreset:GetMapMarkersCount()
	return #(self.markers or "")
end

function MapDataPreset:SetBlacklistStr(str)
	local blacklist = string.tokenize(str, ',', nil, true)
	self.Blacklist = #blacklist > 0 and blacklist or nil
	ObjModified(self)
end

function MapDataPreset:SetTerrainTreeSize(value)
	hr.TR_TerrainTreeRows = value
	ObjModified(self)
end

function MapDataPreset:GetBlacklistStr()
	return self.Blacklist and table.concat(self.Blacklist, ",\n") or ""
end

function MapDataPreset:SetSaveIn(save_in)
	if self.save_in == save_in then return end
	if save_in ~= "" and Playlists[save_in] then
		if self.Playlist == self:GetDefaultPropertyValue("Playlist") or self.save_in ~= "" and self.Playlist == self.save_in then
			self.Playlist = save_in
		end
	elseif self.save_in ~= "" and Playlists[self.save_in] and self.Playlist == self.save_in then
		self.Playlist = self:GetDefaultPropertyValue("Playlist")
	end
	Preset.SetSaveIn(self, save_in)
	ObjModified(self)
end

function MapDataPreset:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "MapType" then
		if self.MapType == "system" then
			self.GameLogic = false
		end
		ObjModified(self)
	elseif prop_id == "PassBorder" then
		if self.PassBorder == old_value or GetMapName() ~= self:GetMapName() then
			return
		end
		CreateRealTimeThread(function()
			SaveMap("no backup")
			ChangeMap(GetMapName())
		end)
	elseif prop_id == "EditorLightmodel" and GetMapName() == self.id then
		self:ApplyLightmodel()
	end

	if CurrentMap ~= "" then
		DeleteThread(UpdateMapDataThread)
		UpdateMapDataThread = CreateMapRealTimeThread(function()
			Sleep(100)
			self:ApplyMapData()
			AtmosphericParticlesUpdate()
		end)
	end
end

function MapDataPreset:GetError()
	if (self.Width - 1) % 128 ~= 0 or (self.Height - 1) % 128 ~= 0 then
		return "Map width and height minus 1 must divide by 128 - use the sliders to set them"
	end
end

function MapDataPreset:GetSaveFolder(save_in)
	return self.ModMapPath or string.format("Maps/%s/", self.id)
end

function MapDataPreset:GetSavePath(save_in, group)
	return self:GetSaveFolder(save_in) .. "mapdata.lua"
end

function MapDataPreset:GenerateCode(code)
	local sizex, sizey = terrain.GetMapSize()
	self.Width = self.Width or (sizex and sizex / guim + 1)
	self.Height = self.Height or (sizey and sizey / guim + 1)

	code:append("DefineMapData")
	code:appendt(self)
end

function MapDataPreset:GetSaveData(file_path, presets, ...)
	assert(#presets <= 1)
	return Preset.GetSaveData(self, file_path, presets, ...)
end

function MapDataPreset:HandleRenameDuringSave(save_path, path_to_preset_list)
	local presets = path_to_preset_list[save_path]
	if #presets ~= 1 then return end
	
	local last_save_path = g_PresetLastSavePaths[presets[1]]
	if last_save_path and last_save_path ~= save_path then
		local old_dir = SplitPath(last_save_path)
		local new_dir = SplitPath(save_path)
		SVNMoveFile(old_dir, new_dir)
	end
end

function MapDataPreset:ChooseLightmodel()
	return self.Lightmodel
end

function MapDataPreset:ApplyLightmodel()
	if IsEditorActive() then
		SetLightmodel(1, self.EditorLightmodel, 0)
	else
		SetLightmodel(1, LightmodelOverride and LightmodelOverride.id or self:ChooseLightmodel(), 0)
	end
end

local function ToggleEditor()
	if mapdata.EditorLightmodel then
		mapdata:ApplyLightmodel()
	end
end

OnMsg.GameEnterEditor = ToggleEditor
OnMsg.GameExitEditor = ToggleEditor

function MapDataPreset:ApplyMapData(setCamera)
	self:ApplyLightmodel()
	AtmosphericParticlesApply()

	if config.UseReverb and self.Reverb then
		local reverb = ReverbDefs[self.Reverb]
		if not reverb then
			self.Reverb = false
		else
			reverb:Apply()
		end
	end
	
	if setCamera and self.CameraPos and self.CameraPos ~= InvalidPos() and 
		self.CameraLookAt and self.CameraLookAt ~= InvalidPos() 
	then
		SetCamera(self.CameraPos, self.CameraLookAt, self.CameraType, self.Zoom, nil, self.CameraFovX)
	end

	hr.TR_TerrainTreeRows = self.TerrainTreeRows

	SetMusicBlacklist(self.Blacklist)
	if self.Playlist ~= "" then
		SetMusicPlaylist(self.Playlist)
	end
end

function MapDataPreset:GetPlayableSize()
	local sizex, sizey = terrain.GetMapSize()
	return sizex - 2 * mapdata.PassBorder, sizey - 2 * mapdata.PassBorder
end

function MapDataPreset:SetCamera()
	local zoom, props
	self.CameraPos, self.CameraLookAt, self.CameraType, zoom, props, self.CameraFovX = GetCamera()
	GedObjectModified(self)
end

function MapDataPreset:ViewCamera()
	if self.CameraPos and self.CameraLookAt and self.CameraPos ~= InvalidPos() and self.CameraLookAt ~= InvalidPos() then
		SetCamera(self.CameraPos, self.CameraLookAt, self.CameraType, nil, nil, self.CameraFovX)
	end
end

function OnMsg.NewMap()
	if mapdata.MapType == "system" then mapdata.GameLogic = false end
	if IsKindOf(mapdata, "MapDataPreset") then
		mapdata:ApplyMapData("set camera")
	end
end

function LoadAllMapData()
	MapData = {}
	
	local map
	local fenv = LuaValueEnv{
		DefineMapData = function(data)
			local preset = MapDataPreset:new(data)
			preset:SetGroup(preset:GetGroup())
			preset:SetId(map)
			preset:PostLoad()
			g_PresetLastSavePaths[preset] = preset:GetSavePath()
			MapData[map] = preset
		end,
	}
	
	if IsFSUnpacked() then
		local err, folders = AsyncListFiles("Maps", "*", "relative folders")
		if err then return end
		for i = 1, #folders do
			map = folders[i]
			local ok, err = pdofile(string.format("Maps/%s/mapdata.lua", map), fenv)
			assert( ok, err )
		end
	else
		local function LoadMapDataFolder(folder)
			local err, files = AsyncListFiles(folder, "*.lua")
			if err then return end
			for i = 1, #files do
				local dir, file, ext = SplitPath(files[i])
				if file ~= "__load" then
					map = file
					dofile(files[i], fenv)
				end
			end
		end
		
		LoadMapDataFolder("Data/MapData")
		for _, dlc_folder in ipairs(DlcFolders) do
			LoadMapDataFolder(dlc_folder .. "/Maps")
		end
	end
	
	Msg("MapDataLoaded")
end

function OnMsg.PersistSave(data)
	if IsKindOf(mapdata, "MapDataPreset") then
		data.mapdata = {}
		local props = mapdata:GetProperties()
		for _, meta in ipairs(props) do
			local id = meta.id
			data.mapdata[id] = mapdata:GetProperty(id)
		end
	end
end

function OnMsg.PersistLoad(data)
	if data.mapdata then
		mapdata = MapDataPreset:new(data.mapdata)
	end
end

function MapDataPreset:UpdateStartup()
	if GetMap() == "" then
		return
	end
	self:SetStartupCam{GetCamera()}
	self:SetStartupEditor(IsEditorActive())
	ObjModified(self)
end

function MapDataPreset:GotoStartup()
	if GetMap() == "" then
		return
	end
	local in_editor = self:GetStartupEditor()
	if in_editor then
		EditorActivate()
	end
	local startup_cam = self:GetStartupCam()
	if startup_cam then
		SetCamera(table.unpack(startup_cam))
	end
end

for _, prop in ipairs(MapDataPreset.properties) do
	if prop.dev_option then
		prop.developer = true
		prop.dont_save = true
		MapDataPreset["Get" .. prop.id] = function(self)
			return GetDeveloperOption(prop.id, "MapStartup", self.id, false)
		end
		MapDataPreset["Set" .. prop.id] = function(self, value)
			SetDeveloperOption(prop.id, value, "MapStartup", self.id)
		end
	end
end

local function MapStartup()
	if MapReloadInProgress or GetMap() == "" or not mapdata:GetStartupEnable() then
		return
	end
	mapdata:GotoStartup()
end
local function MapStartupDelayed()
	DelayedCall(0, MapStartup)
end
OnMsg.EngineStarted = MapStartupDelayed
OnMsg.ChangeMapDone = MapStartupDelayed


----- Map variations data
--
-- MapVariationPreset stores data about map variations that are edited as map patches applied over the base map:
--  * id - variation name
--  * group - base map name
--  * save_in - DLC to be saved in (or "")

DefineClass.MapVariationPreset = {
	__parents = { "Preset" },
	GedEditor = "GedMapVariationsEditor",
}

-- custom property tweaks
function OnMsg.ClassesGenerate()
	-- patch Group property => "Map"
	local group_prop = table.copy(table.find_value(Preset.properties, "id", "Group"))
	group_prop.name = "Map"
	local old_validate = group_prop.validate
	group_prop.validate = function(...)
		local err = old_validate(...)
		if err then
			return err:gsub(" group", " map"):gsub("preset", "map variation"):gsub("Preset", "Map variation")
		end
	end
	
	-- patch Save In to only list DLCs (and not libs)
	local savein_prop = table.copy(table.find_value(Preset.properties, "id", "SaveIn"))
	savein_prop.items = function() return DlcComboItems() end
	
	MapVariationPreset.properties = { group_prop, savein_prop }
end

function MapVariationPreset:GetMap()
	return self.group
end

function MapVariationPreset:GetMapPatchPath(id, map, save_in)
	id = id or self.id
	map = map or self:GetMap()
	save_in = save_in or self.save_in
	if save_in == "" then
		return string.format("%s%s.patch", GetMapFolder(map), id)
	end
	return string.format("svnProject/Dlc/%s/MapVariations/%s - %s.patch", save_in, map, id)
end

function MapVariationPreset:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Id" or prop_id == "Group" or prop_id == "SaveIn" then
		local new_path = self:GetMapPatchPath()
		local old_path =
			prop_id == "Id" and self:GetMapPatchPath(old_value) or
			prop_id == "Group" and self:GetMapPatchPath(nil, old_value) or
			prop_id == "SaveIn" and self:GetMapPatchPath(nil, nil, old_value)
		if old_path ~= new_path then
			ExecuteWithStatusUI("Moving map variation...", function()
				SVNMoveFile(old_path, new_path)
				if IsMapVariationEdited(self) then
					StopEditingCurrentMapVariation()
				end
				self:Save()
			end)
		end
	end
end

function MapVariationPreset:GetError()
	if Platform.developer and not io.exists(self:GetMapPatchPath()) then
		return string.format("Patch file %s doesn't exist.", self:GetMapPatchPath())
	end
end

function MapVariationPreset:OnEditorDelete()
	ExecuteWithStatusUI("Deleting map variation...", function()
		local filename = self:GetMapPatchPath()
		SVNDeleteFile(filename)
		local path = SplitPath(filename)
		if #io.listfiles(path, "*.*") == 0 then
			SVNDeleteFile(path)
		end
		if IsMapVariationEdited(self) then
			StopEditingCurrentMapVariation()
		end
		self:Save()
	end)
end

function MapVariationPreset:OnEditorNew(parent, ged, is_paste, old_id)
	assert(is_paste) -- should be a Duplicate action, new MapVariationPreset instances are created via the Map editor
	ExecuteWithStatusUI("Copying map variation...", function()
		local old_path = self:GetMapPatchPath(old_id)
		local new_path = self:GetMapPatchPath()
		local err = AsyncCopyFile(old_path, new_path, "raw")
		if err then
			ged:ShowMessage("Error copying file", string.format("Failed to copy '%s' to its new location '%s'.", old_path, new_path))
			return
		end
		SVNAddFile(new_path)
		self:Save()
	end)
end

function MapVariationPreset:GetPresetStatusText()
	return "Double click to open in map editor."
end


----- Map variation global functions

function MapVariationNameText(preset)
	local name, save_in = preset.id, preset.save_in
	return name .. (save_in ~= "" and string.format(" (%s)", save_in) or "")
end

function MapVariationItems(map)
	local ret = {}
	for _, preset in ipairs(Presets.MapVariationPreset[CurrentMap]) do
		table.insert(ret, { text = MapVariationNameText(preset), value = preset })
	end
	table.sortby_field(ret, "text")
	return ret
end

function FindMapVariation(name, save_in)
	local map_variations = Presets.MapVariationPreset[CurrentMap]
	if not map_variations then return end
	
	if not save_in or save_in == "" then
		return map_variations[name]
	end
	for _, preset in ipairs(map_variations) do
		if preset.id == name and preset.save_in == save_in then
			return preset
		end
	end
end

function CreateMapVariation(name, save_in)
	assert(IsEditorActive() and CurrentMap ~= "")
	local preset = FindMapVariation(name, save_in)
	if not preset then
		preset = MapVariationPreset:new{ id = name, save_in = save_in, group = CurrentMap }
		preset:Register()
		preset:Save()
	end
	
	CurrentMapVariation = preset
end

function ApplyMapVariation(name, save_in)
	if name then
		local preset = FindMapVariation(name, save_in)
		if preset then
			XEditorApplyMapPatch(preset:GetMapPatchPath())
			CurrentMapVariation = preset
			return
		end
	end
	CurrentMapVariation = false
end

if config.Mods then

-- Load all mod related mapdata into the game (it looks for it in every "Maps" folder of each loaded mod)
function OnMsg.ModsReloaded()
	local fenv = LuaValueEnv{
		DefineMapData = function(data)
			if MapData[data.id] then
				 MapData[data.id]:delete() -- remove previous version of the map data, which is potentially loaded
			end
			local preset = MapDataPreset:new(data)
			preset.mod = true -- display as [ModItem] in the MapData editor
			preset:SetGroup(preset:GetGroup())
			preset:SetId(preset.id)
			preset:PostLoad()
			g_PresetLastSavePaths[preset] = preset.ModMapPath
			MapData[preset.id] = preset
		end,
	}
	
	for _, mod in ipairs(ModsLoaded) do
		local err, mapdataFiles = AsyncListFiles(mod.content_path .. "Maps/", "mapdata.lua", "recursive")
		if not err and next(mapdataFiles) then
			for _, mapdataFile in ipairs(mapdataFiles) do
				local ok, err = pdofile(mapdataFile, fenv)
				assert(ok, err)
			end
		end
	end
end

end
