--[==[

DLC OS-specific files have the following structure:
 
DLC content is:
 |- autorun.lua
 |- revisions.lua
 |- Lua.hpk (if containing newer version of Lua, causes reload) 
 |- Data.hkp (if containing newer version of Data)
 |- Data/... (additional data)
 |- Maps/...
 |- Sounds.hpk
 |- EntityTextures.hpk (additional entity textures)
 |- ...

The Autorun returns a table with a description of the dlc:
return {
	name = "Colossus",
	display_name = T{"Colossus"}, -- optional, must be a T with an id if present
	pre_load = function() end,
	post_load = function() end,
	required_lua_revision = 12345, -- skip loading this DLC below this revision
}


DLC mount steps:

1. Enumerate and mount OS-specific DLC packs (validating them on steam/pc)
	-- result is a list of folders containing autorun.lua files
	
2. Execute autorun.lua and revisions.lua; autorun.lua should set g_AvailableDlc[dlc.name] = true
	
3. Check required_lua_revision and call dlc:pre_load() for each dlc that passes the check

4. If necessary reload localization, lua and data from the lasest packs (it can update the follow up Dlc load steps)

5. If necessary reload the latest Dlc assets
	-- reload entities
	-- reload BinAssets
	-- reload sounds
	-- reload music

6. Call the dlc:post_load() for each dlc
]==]

if FirstLoad then
	-- "" and false are "no dlc" values for the missions and achievements systems respectively
	g_AvailableDlc = {[""] = true, [false] = true} -- [achievement name] = true ; DLC code is expected to properly init this!
	g_DlcDisplayNames = {} -- [achievement name] = "translated string"
	DlcFolders = false
	DlcDefinitions = false
	DataLoaded = false
end

if FirstLoad and Platform.playstation then
	local err, list = AsyncPlayStationAddcontList(0)
	g_AddcontStatus = {}
	if not err then
		for _, addcont in ipairs(list) do
			g_AddcontStatus[addcont.label] = addcont.status
		end
	end
end
	
dlc_print = CreatePrint{
	--"dlc" 
}

--[[@@@
Returns if the player has a specific DLC installed.
@function bool IsDlcAvailable(string dlc)
@param dlc - The ID of a DLC.
@result bool - If the DLC is available and loaded.
]]
function IsDlcAvailable(dlc)
	dlc = dlc or false
	return g_AvailableDlc[dlc]
end

function IsDlcOwned(dlc)
end

function DLCPath(dlc)
	if not dlc or dlc == "" then return "" end
	return "DLC/" .. dlc
end

-- Use, for example, for marking savegames. In all other cases use IsDlcAvailable
function GetAvailableDlcList()
	local dlcs = {}
	for dlc, v in pairs(g_AvailableDlc) do
		if v and dlc ~= "" and dlc ~= false then
			dlcs[ 1 + #dlcs ] = dlc
		end
	end
	table.sort(dlcs)
	return dlcs
end

function GetDeveloperDlcs()
	local dlcs = Platform.developer and IsFSUnpacked() and io.listfiles("svnProject/Dlc/", "*", "folders") or empty_table
	for i, folder in ipairs(dlcs) do
		dlcs[i] = string.gsub(folder, "svnProject/Dlc/", "")
	end
	table.sort(dlcs)
	return dlcs
end

DbgAllDlcs = false
DbgAreDlcsMissing = return_true
DbgIgnoreMissingDlcs = rawget(_G, "DbgIgnoreMissingDlcs") or {}

if Platform.developer and IsFSUnpacked() then
	DbgAllDlcs = GetDeveloperDlcs()
	function DbgAreDlcsMissing()
		for _, dlc in ipairs(DbgAllDlcs or empty_table) do
			if not DbgIgnoreMissingDlcs[dlc] and not g_AvailableDlc[dlc] then
				return dlc
			end
		end
	end
end

-- Helper function for tying a savegame to a set of required DLCs
--	metadata = FillDlcMetadata(metadata, dlcs)
function FillDlcMetadata(metadata, dlcs)
	metadata = metadata or {}
	dlcs = dlcs or GetAvailableDlcList()
	local t = {}
	for _, dlc in ipairs(dlcs) do
		t[#t+1] = {id = dlc, name = g_DlcDisplayNames[dlc] or dlc}
	end
	metadata.dlcs = t
	return metadata
end

-- Step 1. Enumerate and mount OS-specific DLC packs (validating them on steam/pc)
function DlcMountOsPacks()
	dlc_print("Mount Os Packs")
	local folders = {}
	local error = false
	
	if Platform.demo then
		dlc_print("Mount Os Packs early out: no DLCs in demo")
		return folders, error
	end
	
	if Platform.playstation then
		for label, status in pairs(g_AddcontStatus) do
			if status == const.PlaystationAddcontStatusInstalled then
				local addcont_error, mount_point = AsyncPlayStationAddcontMount(0, label)
				local pack_error = MountPack(label, mount_point .. "/content.hpk")
				error = error or addcont_error or pack_error
				table.insert(folders, label)
			end
		end
		dlc_print(string.format("PS4 Addcont: %d listed (%d mounted)", #g_AddcontStatus, #folders))
	end
	if Platform.appstore then
		local content = AppStore.ListDownloadedContent()
		for i=1, #content do
			local folder = "Dlc" .. i
			local err = MountPack(folder, content[i].path)
			if not err then
				folders[#folders+1] = folder
			end
		end
	end
	if Platform.xbox then
		local list
		error, list = Xbox.EnumerateLocalDlcs()
		if not error then
			for idx = 1, #list do
				local folders_index = #folders+1
				
				local err, mountDir = AsyncXboxMountDLC(list[idx][1])
				if not err then
					err = MountPack("Dlc" .. folders_index, mountDir .. "/content.hpk")
					error = error or err
					if not err then
						folders[folders_index] = "Dlc" .. folders_index
					end
				end
			end
		end
	end
	if Platform.windows_store then
		local err, list = WindowsStore.MountDlcs()
		if not err then
			for i=1, #list do
				local folder = list[i]
				local folders_index = #folders+1
				err = MountPack("Dlc" .. folders_index, folder .. "/content.hpk")
				if not err then
					folders[folders_index] = "Dlc" .. folders_index
				end
			end
		end
	end
	
	if not DlcFolders then -- Load the embedded DLCs only once
		if Platform.developer and IsFSUnpacked() then
			local dev_list = Platform.developer and IsFSUnpacked() and io.listfiles("svnProject/Dlc/", "*", "folders") or empty_table
			for _, folder in ipairs(dev_list) do
				local dlc = string.gsub(folder, "svnProject/Dlc/", "")
				if not (LocalStorage.DisableDLC and LocalStorage.DisableDLC[dlc]) then
					folders[#folders + 1] = folder
				end
			end
		else
			local files = io.listfiles("AppData/DLC/", "*.hpk", "non recursive") or {}
			table.iappend(files, io.listfiles("DLC/", "*.hpk", "non recursive"))
			if Platform.linux then
				table.iappend(files, io.listfiles("dlc/", "*.hpk", "non recursive"))
			end
			if Platform.pgo_train then
				table.iappend(files, io.listfiles("../win32-dlc", "*.hpk", "non recursive"))
			end
			dlc_print("Dlc os packs: ", files)
			for i=1,#files do
				local folder = "Dlc" .. tostring(#folders+1)
				local err = MountPack(folder, files[i])
				if not err then
					table.insert(folders, folder)
				end
			end	
		end
	end
		
	dlc_print("Dlc folders: ", folders)
	return folders, error
end

-- 2. Execute autorun.lua and revisions.lua
function DlcAutoruns(folders)
	dlc_print("Dlc Autoruns")
	local dlcs = {}
	
	-- dlc.folder points to the autorun mount
	for i = 1, #folders do
		local folder = folders[i]
		local dlc = dofile(folder .. "/autorun.lua")
		if type(dlc) == "function" then
			dlc = dlc(folder)
		end
		if type(dlc) == "table" then
			dlc_print("Autorun executed for", dlc.name)
			dlc.folder = folder
			if Platform.developer and folder:starts_with("svnProject/Dlc") then
				dlc.lua_revision, dlc.assets_revision = LuaRevision, AssetsRevision
			else
				dlc.lua_revision, dlc.assets_revision = dofile(folder .. "/revisions.lua")
			end
			table.insert(dlcs, dlc)
			DebugPrint(string.format("DLC %s loaded, lua revision %d, assets revision %d\n", tostring(dlc.name), dlc.lua_revision or 0, dlc.assets_revision or 0))
		else
			print("Autorun failed:", folder)
		end
	end
	return dlcs
end

-- 3. Call the dlc:pre_load() to all dlcs. Let a DLC decide that it doesn't want to be installed
function DlcPreLoad(dlcs)
	local revision
	for i = #dlcs, 1, -1 do
		local required_lua_revision = dlcs[i].required_lua_revision
		if required_lua_revision and required_lua_revision <= LuaRevision then
			required_lua_revision = nil -- the required revision is lower, ignore condition
		end
		revision = Max(revision, required_lua_revision)
		local pre_load = dlcs[i].pre_load or empty_func
		if required_lua_revision or pre_load(dlcs[i]) == "remove" then
			dlc_print("Dlc removed:", dlcs[i].name, required_lua_revision or "")
			table.remove_value(DlcFolders, dlcs[i].folder)
			table.remove(dlcs, i)
		end
	end
	return revision
end

function GetDlcRequiresTitleUpdateMessage()
	local id = TGetID(MessageText.DlcRequiresUpdate)
	if id and TranslationTable[id] then
		return TranslationTable[id]
	end
	
	-- fallback
	local language, strMessage = GetLanguage(), nil
	if     language == "French" then
		strMessage = "Certains contenus téléchargeables nécessitent l'installation d'une mise à jour du jeu pour fonctionner."
	elseif language == "Italian" then
		strMessage = "Alcuni contenuti scaricabili richiedono un aggiornamento del titolo per essere utilizzati."
	elseif language == "German" then
		strMessage = "Bei einigen Inhalten zum Herunterladen ist ein Update notwendig, damit sie funktionieren."
	elseif language == "Spanish" or language == "Latam" then
		strMessage = "Ciertos contenidos descargables requieren una actualización para funcionar."
	elseif language == "Polish" then
		strMessage = "Część zawartości do pobrania wymaga aktualizacji gry."
	elseif language == "Russian" then
		strMessage = "Загружаемый контент требует обновления игры."
	else
		strMessage = "Some downloadable content requires a title update in order to work."
	end
	return strMessage
end


local function find(dlcs, path, rev, rev_name)
	local found
	for i = #dlcs, 1, -1 do
		local dlc = dlcs[i]
		if dlc[rev_name] > rev and io.exists(dlc.folder .. path) then
			rev = dlc[rev_name]
			found = dlc
		end
	end
	if found then
		return found.folder .. path, found
	end
end

-- 4. If necessary reload localization, lua and data from the lasest packs (it can update the follow up Dlc load steps)
function DlcReloadLua(dlcs, late_dlc_reload)
	local lang_reload
	local reload = late_dlc_reload
	
	-- mount latest localization
	local lang_pack = find(dlcs, "/Local/" .. GetLanguage() .. ".hpk", LuaRevision, "lua_revision")
	if lang_pack then
		dlc_print(" - localization:", lang_pack)
		MountPack("", lang_pack, "", "CurrentLanguage")
		lang_reload = true
	end
	
	-- English language for e.g. the Mod Editor on PC
	if config.GedLanguageEnglish then
		local engl_pack = find(dlcs, "/Local/English.hpk", LuaRevision, "lua_revision")
		if engl_pack then
			MountPack("", engl_pack, "", "EnglishLanguage")
		end
	end
	
	-- reload entities
	local binassets_path = "/BinAssets.hpk"
	local binassets_pack = find(dlcs, binassets_path, AssetsRevision, "assets_revision")
	if binassets_pack then
		dlc_print(" - BinAssets:", binassets_pack)
		UnmountByPath("BinAssets")
		local err = MountPack("BinAssets", binassets_pack)
		dlc_print(" - BinAssets:", binassets_pack, "ERROR", err)
		ReloadEntities("BinAssets/entities.dat")
		ReloadTextureHeaders()
		reload = true
	end
	
	-- reload Lua
	if late_dlc_reload then -- clean the global tables to prevent duplication
		Presets = {}
		ClassDescendants("Preset", function(name, class)
			if class.GlobalMap then
				_G[class.GlobalMap] = {}
			end
		end)
	end
	
	local lua_pack, dlc = find(dlcs, "/Lua.hpk", LuaRevision, "lua_revision")
	if lua_pack then
		dlc_print(" - lua:", dlc.folder .. "/Lua.hpk")
		assert(not config.RunUnpacked)
		UnmountByLabel("Lua")
		LuaPackfile = lua_pack
		reload = true
	end
	local data_pack, dlc = find(dlcs, "/Data.hpk", LuaRevision, "lua_revision")
	if data_pack then
		assert(io.exists(dlc.folder .. "/Data.hpk"))
		UnmountByLabel("Data")
		DataPackfile = data_pack
	end
	for i = 1, #dlcs do
		if io.exists(dlcs[i].folder .. "/Code/") then
			reload = true
			break
		end
	end

	reload = reload or config.Mods and next(ModsLoaded)
	if reload then
		ReloadLua(true)
	end
	
	if lang_reload and not reload then
		LoadTranslationTables()
	end
end

function DlcMountVoices(dlcs, skip_sort)
	UnmountByLabel("DlcVoices")
	if not dlcs then return end
	-- Mount all available voices packs in the multi (order by assets revision in case we want to fix a voice from one DLC from a later one)
	local sorted_dlcs
	if not skip_sort then
		sorted_dlcs = table.copy(dlcs)
		table.stable_sort(sorted_dlcs, function (a, b) return a.assets_revision < b.assets_revision end)
	end
	for i, dlc in ipairs(sorted_dlcs or dlcs) do
		local voice_pack = string.format("%s/Local/Voices/%s.hpk", dlc.folder, GetVoiceLanguage())
		if MountPack("CurrentLanguage/Voices", voice_pack, "seethrough,label:DlcVoices") then
			dlc_print(" - localization voice: ", voice_pack)
		end
	end
end

function DlcMountMapPacks(dlcs)
	for _, dlc in ipairs(dlcs) do
		for _, map_pack in ipairs(io.listfiles(dlc.folder .. "/Maps", "*.hpk")) do
			local map_name = string.match(map_pack, ".*/Maps/([^/]*).hpk")
			if map_name then
				MapPackfile[map_name] = map_pack
			end
		end
	end
end

function DlcMountUI(dlcs)
	local asset_path = dlcs.folder .. "/UI/"
	if io.exists(asset_path) then
		local err = MountFolder("UI", asset_path, "seethrough")
		dlc_print(" - UI:", asset_path, "ERROR", err)
	end
end

function DlcMountNonEntityTextures(dlcs)
	local asset_path = find(dlcs, "/AdditionalNETextures.hpk", AssetsRevision, "assets_revision")
	if asset_path then
		UnmountByLabel("AdditionalNETextures")
		local err = MountPack("", asset_path, "priority:high,seethrough,label:AdditionalNETextures")
		dlc_print(" - non-entity textures:", asset_path, "ERROR", err)
	end
end

function DlcMountAdditionalEntityTextures(dlcs)
	local asset_path = find(dlcs, "/AdditionalTextures.hpk", AssetsRevision, "assets_revision")
	if asset_path then
		UnmountByLabel("AdditionalTextures")
		local err = MountPack("", asset_path, "priority:high,seethrough,label:AdditionalTextures")
		dlc_print(" - entity textures:", asset_path, "ERROR", err)
	end
end

function DlcMountSounds(dlcs)
	local asset_path = dlcs.folder .. "/Sounds/"
	if io.exists(asset_path) then
		local err = MountFolder("Sounds", asset_path, "seethrough")
		dlc_print(" - Sounds:", asset_path, "ERROR", err)
	end
end

function DlcMountMeshesAndAnimations(dlcs)
	local meshes_pack = find(dlcs, "/Meshes.hpk", AssetsRevision, "assets_revision")
	if meshes_pack then
		dlc_print(" - Meshes:", meshes_pack)
		UnmountByPath("Meshes")
		MountPack("Meshes", meshes_pack)
	else
		-- If we reload DLCs in packed mode, make sure to have the original meshes first
		if MountsByPath("Meshes") == 0 and not IsFSUnpacked() then
			MountPack("Meshes", "Packs/Meshes.hpk")
		end
	end
	local animations_pack = find(dlcs, "/Animations.hpk", AssetsRevision, "assets_revision")
	if animations_pack then
		dlc_print(" - Animations:", animations_pack)
		UnmountByPath("Animations")
		MountPack("Animations", animations_pack)
	else
		if MountsByPath("Animations") == 0 and not IsFSUnpacked() then 
			MountPack("Animations", "Packs/Animations.hpk")
		end
	end

	-- mount additional meshes and animations for each DLC
	for i, dlc in ipairs(dlcs) do
		MountPack("", dlc.folder .. "/DlcMeshes.hpk", "seethrough,label:DlcMeshes")
		MountPack("", dlc.folder .. "/DlcAnimations.hpk", "seethrough,label:DlcAnimations")
		MountPack("", dlc.folder .. "/DlcSkeletons.hpk", "seethrough,label:DlcSkeletons")
		MountPack("BinAssets", dlc.folder .. "/DlcBinAssets.hpk", "seethrough,label:DlcBinAssets")
	end

	--common assets should be processed before the rest
	UnmountByLabel("CommonAssets")
	MountPack("", "Packs/CommonAssets.hpk", "seethrough,label:CommonAssets")
end

function DlcReloadShaders(dlcs)	
	-- box DX9 and DX11 shader packs should be provided or missing
	local asset_path, dlc = find(dlcs, "/ShaderCache" .. config.GraphicsApi .. ".hpk", AssetsRevision, "assets_revision")
	if asset_path then
		dlc_print(" - ShaderCache:", asset_path)
		UnmountByPath("ShaderCache")
		MountPack("ShaderCache", asset_path, "seethrough,in_mem,priority:high")
		-- NOTE: new shader cache will be reloaded not on start up(main menu) but on next map/savegame load
		hr.ForceShaderCacheReload = true
	end
end

function DlcAddMusic(dlcs)
	local asset_path = dlcs.folder .. "/Music/"
	if io.exists(asset_path) then
		local err = MountFolder("Music/" .. dlc.name, asset_path)
		dlc_print(" - Music:", asset_path, "ERROR", err)
		Playlists[dlc.name] = PlaylistCreate("Music/" .. dlc.name)
	end
end

function DlcAddCubemaps(dlcs)
	local asset_path = dlcs.folder .. "/Cubemaps/"
	if io.exists(asset_path) then
		local err = MountFolder("Cubemaps", asset_path, "seethrough")
		dlc_print(" - Cubemaps:", asset_path, "ERROR", err)
	end
end

function DlcAddBillboards(dlcs)
	local asset_path = dlcs.folder .. "/Textures/Billboards/"
	if io.exists(asset_path) then
		local err = MountFolder("Textures/Billboards", asset_path, "seethrough")
		dlc_print(" - Billboards:", asset_path, "ERROR", err)
	end
end

function DlcMountMovies(dlcs)
	if IsFSUnpacked() then return end
	for _, dlc in ipairs(dlcs) do
		local path = dlc.folder .. "/Movies/"
		if io.exists(path) then
			local err = MountFolder("Movies/", path, "seethrough")
			dlc_print(" - DlcMovies:", path, err and "ERROR", err)
		end
	end
end

function DlcMountBinAssets(dlcs)
	if IsFSUnpacked() then return end
	for _, dlc in ipairs(dlcs) do
		local path = dlc.folder .. "/BinAssets/"
		if io.exists(path) then
			local err = MountFolder("BinAssets/", path, "seethrough")
			dlc_print(" - DlcBinAssets:", path, err and "ERROR", err)
		end
	end
end

function DlcMountMisc(dlcs)
	UnmountByLabel("DlcMisc")
	for _, dlc in ipairs(dlcs) do
		local path = dlc.folder .. "/Misc/"
		if io.exists(path) then
			local err = MountFolder("Misc/", path, "seethrough,label:DlcMisc")
			dlc_print(" - DlcMisc:", path, err and "ERROR", err)
		end
	end
end

-- 5. If necessary reload the latest Dlc assets
function DlcReloadAssets(dlcs)
	dlcs = table.copy(dlcs)
	table.stable_sort(dlcs, function (a, b) return a.assets_revision < b.assets_revision end)
	
	-- mount map packs found in Maps/
	DlcMountMapPacks(dlcs)
	for _, dlc in pairs(dlcs) do
		-- mount the dlc UI
		DlcMountUI(dlc)
		-- mount the dlc sounds
		DlcMountSounds(dlc)
		-- mount the dlc music to the default playlist
		DlcAddMusic(dlc)
		-- mount the dlc cubemaps
		DlcAddCubemaps(dlc)
		-- mount the dlc billboards
		DlcAddBillboards(dlc)
	end
	-- mount the most recent additional non-entity textures
	DlcMountNonEntityTextures(dlcs)
	-- mount the most recent additional entity textures
	DlcMountAdditionalEntityTextures(dlcs)
	-- mount latest meshes and animations plus additional ones in Dlcs
	DlcMountMeshesAndAnimations(dlcs)
	-- find latest shaders; OpenGL shaders are not reloaded
	DlcReloadShaders(dlcs)
	-- mount movies
	DlcMountMovies(dlcs)
	-- 
	DlcMountBinAssets(dlcs)
	-- mount Misc
	DlcMountMisc(dlcs)
	-- mount voices
	DlcMountVoices(dlcs, true)
end

-- 6. Call the dlc.post_load() for each dlc
function DlcPostLoad(dlcs)
	for _, dlc in ipairs(dlcs) do
		if dlc.post_load then dlc:post_load() end
	end
end

function DlcErrorHandler(err)
	print("DlcErrorHandler", err, GetStack())
end

function WaitInitialDlcLoad() -- does nothing on reloads (like what happens on Xbox)
	if not DlcFolders then
		WaitMsg("DlcsLoaded")
	end
end

function LoadDlcs(force_reload)
	if Platform.developer and (LuaRevision == 0 or AssetsRevision == 0) then
		for i=1, 50 do
			Sleep(50)
			if LuaRevision ~= 0 and AssetsRevision ~= 0 then break end
		end
		if LuaRevision == 0 or AssetsRevision == 0 then
			print("Couldn't get LuaRevision or AssetsRevision, DLC loading may be off")
		end
	end

	if DlcFolders and not force_reload then
		return
	end
	
	if force_reload then
		ForceReloadBinAssets()
		DlcFolders = false
	end
	
	if Platform.appstore then
		local err = CopyDownloadedDLCs()
		if err then
			print("Failed to copy downloaded DLCs", err)
		end
	end
	
	LoadingScreenOpen("idDlcLoading", "dlc loading", T(808151841545, "Checking for downloadable content... Please wait."))
	
	-- 1. Mount OS packs
	local bCorrupt = false
	local folders, err = DlcMountOsPacks()
	if err == "File is corrupt" then
		bCorrupt = true
		err = false
	end
	
	if err then 
		DlcErrorHandler(err)
	end
	
	local dlcs = DlcAutoruns(folders)
	table.stable_sort(dlcs, function (a, b) return a.lua_revision < b.lua_revision end)

	UnmountByLabel("Dlc")
	local seen_dlcs = {}
	for i, dlc in ripairs(dlcs) do
		if seen_dlcs[dlc.name] then
			table.remove(dlcs, i)
		else
			seen_dlcs[dlc.name] = true
			dlc.title = dlc.title or dlc.display_name and _InternalTranslate(dlc.display_name) or dlc.name
			if not dlc.folder:starts_with("svnProject/Dlc/") then
				local org_folder = dlc.folder
				dlc.folder = "Dlc/" .. dlc.name
				MountFolder(dlc.folder, org_folder, "priority:high,label:Dlc")
			end
		end
	end
	DlcFolders = table.map(dlcs, "folder")
	DlcDefinitions = table.copy(dlcs)

	local bRevision = DlcPreLoad(dlcs)
	dlc_print("Dlc tables after preload:\n", table.map(dlcs, "name"))
	
	if config.Mods then
		-- load mod items in the same loading screen
		ModsReloadDefs()
		ModsReloadItems(nil, nil, true)
	end

	DlcReloadLua(dlcs, force_reload)
	DlcReloadAssets(dlcs)


	local metaCheck = const.PrecacheDontCheck
	if Platform.test then
		metaCheck = Platform.pc and const.PrecacheCheckUpToDate or const.PrecacheCheckExists
	end
	for _, dlc in ipairs(dlcs) do
		ResourceManager.LoadPrecacheMetadata("BinAssets/resources-" .. dlc.name .. ".meta", metaCheck)
	end
	
	DlcPostLoad(dlcs)
	
	-- Collect and translate the DLC display names. 
	--	We are just after the step that would reload the localization, so this would handle the case
	--		where a DLC display name is translated in the new DLC-provided localization
	local dlc_names = GetAvailableDlcList()
	for i=1, #dlc_names do
		local dlc_metadata = table.find_value(dlcs, "name", dlc_names[i])
		assert(dlc_metadata)
		local display_name = dlc_metadata.display_name
		if display_name then
			if not IsT(display_name) or not TGetID(display_name) then
				print("DLC", dlc_names[i], "display_name must be a localized T!")
			end
			display_name = _InternalTranslate(display_name)
			assert(type(display_name)=="string")
			g_DlcDisplayNames[ dlc_names[i] ] = display_name
		end
	end
	
	local dlc_names = GetAvailableDlcList()
	if next(dlc_names) then
		local infos = {}
		for i=1, #dlc_names do
			local dlcname = dlc_names[i]
			infos[i] = string.format("%s(%s)", dlcname, g_DlcDisplayNames[dlcname] or "")
		end
		print("Available DLCs:", table.concat(infos, ","))
	end
	Msg("DlcsLoaded")

	LoadData(dlcs)

	if config.Mods and next(ModsLoaded) then
		ContinueModsReloadItems()
	end

	if not Platform.developer then
		if not config.Mods or not Platform.pc then -- the mod creation (available on PC only) needs the data and lua sources to be able to copy functions
			UnmountByLabel("Lua")
			UnmountByLabel("Data")
		end
	end

	-- Messages should be shown after LoadData(), as there are UI presets that need to be present
	local interactive = not (Platform.developer and GetIgnoreDebugErrors())
	if interactive then
		if bCorrupt then
			WaitMessage(GetLoadingScreenDialog() or terminal.desktop, "", T(619878690503, --[[error_message]] "A downloadable content file appears to be damaged and cannot be loaded. Please delete it from the Memory section of the Dashboard and download it again."), nil, terminal.desktop)
		end
		if bRevision then
			local message = Untranslated(GetDlcRequiresTitleUpdateMessage())
			WaitMessage(GetLoadingScreenDialog() or terminal.desktop, "", message)
		end
	end
	
	LoadingScreenClose("idDlcLoading", "dlc loading")
	UIL.Invalidate()
end

function LoadData(dlcs)
	PauseInfiniteLoopDetection("LoadData")
	collectgarbage("collect")
	collectgarbage("stop")

	Msg("DataLoading")
	MsgClear("DataLoading")

	LoadPresetFiles("CommonLua/Data")
	LoadPresetFolders("CommonLua/Data")
	ForEachLib("Data", function (lib, path)
		LoadPresetFiles(path)
		LoadPresetFolders(path)
	end)
	LoadPresetFolder("Data")
	
	for _, dlc in ipairs(dlcs or empty_table) do
		LoadPresetFolder(dlc.folder .. "/Presets")
	end
	Msg("DataPreprocess")
	MsgClear("DataPreprocess")
	Msg("DataPostprocess")
	MsgClear("DataPostprocess")
	Msg("DataLoaded")
	MsgClear("DataLoaded")
	DataLoaded = true
	
	local mem = collectgarbage("count")
	collectgarbage("collect")
	collectgarbage("restart")
	-- printf("Load Data mem %dk, peak %dk", collectgarbage("count"), mem)
	ResumeInfiniteLoopDetection("LoadData")
end

function WaitDataLoaded()
	if not DataLoaded then
		WaitMsg("DataLoaded")
	end
end

if Platform.xbox then
	local oldLoadDlcs = LoadDlcs
	function LoadDlcs(...)
		SuspendSigninChecks("load dlcs")
		SuspendInviteChecks("load dlcs")
		sprocall(oldLoadDlcs, ...)
		ResumeSigninChecks("load dlcs")
		ResumeInviteChecks("load dlcs")
	end
end


function OnMsg.BugReportStart(print_func)
	local list = GetAvailableDlcList()
	table.sort(list)
	print_func("Dlcs: " .. table.concat(list, ", "))
end

function DlcComboItems(additional_item)
	local items = {{ text = "", value = ""}}
	for _, def in ipairs(DlcDefinitions) do
		if not def.deprecated then
			local name, title = def.name, def.title
			if name ~= title then
				title = name .. " (" .. title .. ")"
			end
			items[#items + 1] = {text = title, value = name}
		end
	end
	if additional_item then
		table.insert(items, 2, additional_item)
	end
	return items
end

function DlcCombo(additional_item)
	return function()
		return DlcComboItems(additional_item)
	end
end

function RedownloadContent(list, progress)
	if not NetIsConnected() then return "disconnected" end
	progress(0)
	AsyncCreatePath("AppData/DLC")
	AsyncCreatePath("AppData/DownloadedDLC")
	for i = 1, #list do
		local dlc_name = list[i]
		local name = dlc_name .. ".hpk"
		local download_file = string.format("AppData/DownloadedDLC/%s.download", dlc_name)
		local dlc_file = string.format("AppData/DLC/%s.hpk", dlc_name)
		local err, def = NetCall("rfnGetContentDef", name)
		if not err and def then
			local err, local_def = CreateContentDef(download_file, def.chunk_size)
			if err == "Path Not Found" or err == "File Not Found" then
				err, local_def = CreateContentDef(dlc_file, def.chunk_size)
			end
			if local_def then local_def.name = name end
			local start_progress = 100 * (i - 1) / #list
			local file_progress = 100 * i / #list - start_progress
			start_progress = start_progress + file_progress / 10
			progress(start_progress)
			err = NetDownloadContent(download_file, def, 
				function (x, y) 
					progress(start_progress + MulDivRound(file_progress * 9 / 10, x, y))
				end, 
				local_def)
			if not err then
				local downloaded_dlc_file = string.format("AppData/DownloadedDLC/%s.hpk", dlc_name)
				os.remove(downloaded_dlc_file)
				os.rename(download_file, downloaded_dlc_file)
			end
		end
		progress(100 * i / #list)
	end
end

function CopyDownloadedDLCs()
	AsyncCreatePath("AppData/DLC")
	AsyncCreatePath("AppData/DownloadedDLC")
	local err, new_dlcs = AsyncListFiles("AppData/DownloadedDLC", "*.hpk", "relative")
	if err then return err end
	for i = 1, #new_dlcs do
		local src = "AppData/DownloadedDLC/" .. new_dlcs[i]
		if not AsyncCopyFile(src, "AppData/DLC/" .. new_dlcs[i], "raw") then
			AsyncFileDelete(src)
		end
	end
end

function DlcsLoadCode()
	for i = 1, #(DlcFolders or "") do
		dofolder(DlcFolders[i] .. "/Code/")
	end
end

function ReloadDevDlcs()
	CreateRealTimeThread(function()
		OpenPreGameMainMenu()
		DlcFolders = false
		for dlc in pairs(LocalStorage.DisableDLC or empty_table) do
			g_AvailableDlc[dlc] = nil
		end
		SaveLocalStorage()
		ClassDescendants("Preset", function(name, preset, Presets)
			--purge presets, which are saved in Data, we are reloading it
			if preset:GetSaveFolder() == "Data" then
				if preset.GlobalMap then
					_G[preset.GlobalMap] = {}
				end
				Presets[preset.PresetClass or name] = {}
			end
		end, Presets)
		LoadDlcs("force reload")
	end)
end

function SetAllDevDlcs(enable)
	local disabled  = not enable
	LocalStorage.DisableDLC = LocalStorage.DisableDLC or {}
	for _, file in ipairs(io.listfiles("svnProject/Dlc/", "*", "folders")) do
		local dlc = string.gsub(file, "svnProject/Dlc/", "")
		if (LocalStorage.DisableDLC[dlc] or false) ~= disabled then
			LocalStorage.DisableDLC[dlc] = disabled
			DelayedCall(0, ReloadDevDlcs)
		end
	end
end

function SaveDLCOwnershipDataToDisk(data, file_path)
	local machine_id = GetMachineID()
	if (machine_id or "") ~= "" then -- don't save to disk without machine id
		data.machine_id = machine_id
		--encrypt data and machine id and save to disk
		SaveLuaTableToDisk(data, file_path, g_encryption_key)
	end
end

function LoadDLCOwnershipDataFromDisk(file_path)
	if io.exists(file_path) then
		--decrypt the file
		local data, err = LoadLuaTableFromDisk(file_path, nil, g_encryption_key)
		if not err then
			if data and (data.machine_id or "") == GetMachineID() then -- check against current machine id
				data.machine_id = nil -- remove the machine_id from the data, no need for it
				return data
			end
		end
	end
	return {}
end
