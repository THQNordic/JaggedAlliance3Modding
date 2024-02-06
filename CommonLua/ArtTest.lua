function bat() --debug function
	CreateRealTimeThread(ChangeMap, "ArtTest")
end

local project_name = string.lower(const.ProjectName)

local path = { }
path.assets = { }
path.assets.root = GetExecDirectory() .. "Assets/"
path.assets.entities = path.assets.root .. "Bin/Common/Entities/"
path.assets.art_producer_lua = path.assets.root .. "CurrentArtProducer.lua"
path.assets.exporter = path.assets.root .. "HGExporter/"
path.assets.entity_producers_lua = path.assets.root .. "Spec/EntityProducers.lua"
path.max = { }
path.max.root = "AppData/../../Local/Autodesk/3dsmax/2019 - 64bit/ENU/scripts/"
path.max.startup = path.max.root .. "startup/HGExporterUtility_" .. project_name .. ".ms"
path.max.exporter = path.max.root .. "HGExporter_" .. project_name .. "/"
path.max.exporter_startup = path.max.exporter .. "Startup/HGExporterUtility.ms"
path.max.art_producer_ms = path.max.exporter .. "CurrentArtProducer.ms"
path.max.grannyexp_ini = path.max.exporter .. "grannyexp.ini"

local atprint = CreatePrint({
	"ArtPreview",
	format = "printf",
})

ArtTest = { }

function ArtTest.OpenChangeProducerDialog()
	local producers = table.icopy(ArtSpecConfig.EntityProducers)
	table.insert(producers, 1, "Any")
	local new_producer = WaitListChoice(terminal.desktop, producers, "Choose art producer:", 1)
	ArtTest.SetProducer(new_producer or "Any")
	CreateRealTimeThread(ChangeMap, "ArtTest")
end

function ArtTest.SetProducer(new_producer)
	if not new_producer then return end
	
	atprint("Setting new art producer %s", new_producer)
	
	--set producer
	rawset(_G, "g_ArtTestProducer", new_producer)
	
	AsyncCreatePath(path.assets.root)
	
	--write to Lua file for the game
	local lua_content = string.format("return \"%s\"", new_producer)
	AsyncStringToFile(path.assets.art_producer_lua, lua_content)
	
	--write to Max Script file for the exporter
	local ms_content = string.format("global g_ArtTestProducer = \"%s\"", new_producer)
	AsyncStringToFile(path.max.art_producer_ms, ms_content)
	
	local os_path_assets = ConvertToOSPath(path.assets.root)
	if string.ends_with(os_path_assets, "\\") then
		os_path_assets = string.sub(os_path_assets, 1, #os_path_assets - 1)
	end
	
	ArtTest.InstallMaxExporter()
end

function ArtTest.SetProducer_3DSMax(new_producer)
	if not new_producer then return end
	
	local globalappdirs = string.match(GetAppCmdLine() or "", "-globalappdirs")
	if not globalappdirs then
		atprint("Please run the game with the -globalappdirs command line parameter to install/update the Autodesk 3DS Max exporter")
		return
	end

	local os_path_assets = ConvertToOSPath(path.assets.root)
	if string.ends_with(os_path_assets, "\\") then
		os_path_assets = string.sub(os_path_assets, 1, #os_path_assets - 1)
	end

	if io.exists(path.max.grannyexp_ini) then --TODO proper ini handling
		local err, ini = AsyncFileToString(path.max.grannyexp_ini)
		local first, last = string.find(ini, "assetsPath=.*\n")
		if first and last and first <= last then
			ini = string.format("%sassetsPath=%s%s",
				string.sub(ini, 1, first), 
				os_path_assets,
				string.sub(ini, last - 1))
		else
			ini = string.format("%s\n[Directories]\nassetsPath=%s", ini, os_path_assets)
		end
	else
		local ini = string.format("[Directories]\nassetsPath=%s", os_path_assets)
		AsyncStringToFile(path.max.grannyexp_ini, ini)
	end
end

function ArtTest.InstallMaxExporter()
	local globalappdirs = string.match(GetAppCmdLine() or "", "-globalappdirs")
	if not globalappdirs then
		atprint("Please run the game with the -globalappdirs command line parameter to install/update the Autodesk 3DS Max exporter")
		return
	end

	--crate assets folder structure (where entities will be exported)
	local structure = {
		"Bin/",
		"Bin/Common/",
		"Bin/Common/Animations",
		"Bin/Common/Entities",
		"Bin/Common/Mapping",
		"Bin/Common/Materials",
		"Bin/Common/Meshes",
		"Bin/Common/TexturesMeta",
		"Bin/win32/",
		"Bin/win32/Textures",
		"Bin/win32/Fallbacks",
		"Bin/win32/Fallbacks/Textures",
	}
	for i,subpath in ipairs(structure) do
		local full_path = path.assets.root .. subpath
		local os_path = ConvertToOSPath(full_path)
		local err = AsyncCreatePath(os_path)
		if err then
			atprint("Failed creating exporter target folder structure - %s", err)
			return
		end
	end

	--copy exporter folder structure
	local err, folders = AsyncListFiles(path.assets.exporter, "*", "recursive,relative,folders")
	if err then
		atprint("Failed listing Autodesk 3DS Max exporter folder structure - %s", err)
		return err
	end
	
	local os_path = ConvertToOSPath(path.max.exporter)
	local err = AsyncCreatePath(os_path)
	if err then
		atprint("Failed copying Autodesk 3DS Max exporter folder structure - %s", err)
		return err
	end
	
	for _, folder in ipairs(folders) do
		if not string.find(folder, ".svn") then
			local os_path = ConvertToOSPath(path.max.exporter .. folder)
			local err = AsyncCreatePath(os_path)
			if err then
				atprint("Failed copying Autodesk 3DS Max exporter folder structure - %s", err)
				return err
			end
		end
	end

	--copy exporter files
	local err, files = AsyncListFiles(path.assets.exporter, "*", "recursive,relative")
	if err then
		atprint("Failed listing Autodesk 3DS Max exporter files - %s", err)
		return err
	end
	
	for _,file in ipairs(files) do
		if not string.find(file, ".svn") then
			local os_dest_path = ConvertToOSPath(path.max.exporter .. file)
			local err = AsyncCopyFile(path.assets.exporter .. file, os_dest_path, "raw")
			if err then
				atprint("Failed copying Autodesk 3DS Max exporter files - %s", err)
				return err
			end
		end
	end
	
	--copy exporter startup file
	local err = AsyncCopyFile(path.max.exporter_startup, path.max.startup)
	if err then
		atprint("Failed copying Autodesk 3DS Max exporter startup file - %s", err)
		return err
	end
	
	ArtTest.SetProducer_3DSMax(rawget(_G, "g_ArtTestProducer"))
	
	atprint("Installed Autodesk 3DS Max exporter. Restart Autodesk 3DS Max.")
end

function ArtTest.Start()
	atprint("Starting art preview mode")
	
	if io.exists(path.assets.art_producer_lua) then
		local producer = dofile(path.assets.art_producer_lua)
		if type(producer) == "string" then
			rawset(_G, "g_ArtTestProducer", producer)
		end
	end
	
	local art_producer = rawget(_G, "g_ArtTestProducer")
	local no_art_producer = (art_producer == nil)
	if no_art_producer then
		ArtTest.OpenChangeProducerDialog()
		return
	else
		--updates all files
		ArtTest.SetProducer(art_producer)
		atprint("Selected art producer %s", art_producer)
	end
	
	ArtTest.LoadExternalEntities()
	ArtTest.SetUpMap()
end

local mounted
function ArtTest.LoadExternalEntities()
	if not mounted then
		mounted = true
		
		MountFolder(path.assets.root .."Bin/Common/Entities/Meshes/",      path.assets.root .."Bin/Common/Meshes/")
		MountFolder(path.assets.root .."Bin/Common/Entities/Animations/",  path.assets.root .."Bin/Common/Animations/")
		MountFolder(path.assets.root .."Bin/Common/Entities/Materials/",   path.assets.root .."Bin/Common/Materials/")
		MountFolder(path.assets.root .."Bin/Common/Entities/Mapping/",     path.assets.root .."Bin/Common/Mapping/")
		MountFolder(path.assets.root .."Bin/Common/Entities/Textures/",    path.assets.root .."Bin/win32/Textures/")
		atprint("Mounted all entity folders")
	end

	local err, all_entities = AsyncListFiles(path.assets.entities, "*.ent")
	if err then
		atprint("Failed to enumerate entities - %s", err)
		return
	end
	if not all_entities or #all_entities == 0 then
		atprint("No entities to load")
		return
	end
	
	for i,ent_file in ipairs(all_entities) do
		DelayedLoadEntity(false, false, ent_file)
	end
	atprint("Will load %d entities", #all_entities)
	
	LoadingScreenOpen("idArtTestLoadEntities", "ArtTestLoadEntities")
	local old_render_mode = GetRenderMode()
	WaitRenderMode("ui")
	ForceReloadBinAssets()
	DlcReloadAssets(DlcDefinitions)
	--actually reload the assets
	LoadBinAssets(CurrentMapFolder)
	--wait & unmount
	WaitNextFrame(2)
	while AreBinAssetsLoading() do
		Sleep(1)
	end
	WaitRenderMode(old_render_mode)
	LoadingScreenClose("idArtTestLoadEntities", "ArtTestLoadEntities")
	WaitDelayedLoadEntities()
	--ReloadClassEntities()
	ReloadLua()
	atprint("Reloaded all entities")
end

function ArtTest.SetUpMap()
	cameraMax.Activate(1)
	atprint("Camera set up")
	
	local preview_objs = ArtTest.PlacePreviewObjects()
	
	if preview_objs and next(preview_objs) then
		ViewPos(preview_objs[1]:GetVisualPos())
		atprint("Showing first preview object")
	end
end

function ArtTest.GetObjectClassesToPreview()
	local current_producer = rawget(_G, "g_ArtTestProducer") or "Any"
	local result = { }
	
	if io.exists(path.assets.entity_producers_lua) then
		local entity_producers = dofile(path.assets.entity_producers_lua)
		for entity_id,produced_by in pairs(entity_producers) do
			if (current_producer == "Any" or produced_by == current_producer) and g_Classes[entity_id] then
				table.insert(result, entity_id)
			end
		end
	end
	
	return result
end

local spacing = 10 * guim
function ArtTest.PlacePreviewObjects(classes)
	local current_producer = rawget(_G, "g_ArtTestProducer") or "Any"
	
	local y = 0
	local result = { }
	
	local classes = classes or ArtTest.GetObjectClassesToPreview()
	if not classes or #classes == 0 then
		atprint("No preview objects to place")
		return
	end
	
	for i,classname in ipairs(classes) do
		local class = g_Classes[classname]
		local entity = class:GetEntity()
		local entity_bbox = GetEntityBBox(entity)
		local _, radius = entity_bbox:GetBSphere()
		
		local x = 0
		local half_spacing = radius + spacing
		
		for i,state in pairs(EnumValidStates(entity)) do
			x, y = x + half_spacing, y + half_spacing
			local pos = point(x, y)
			local preview_pos = point(x, y, terrain.GetHeight(x, y))
			x, y = x + half_spacing, y + half_spacing
			
			local preview_obj = PlaceObject(classname)
			preview_obj:SetPos(preview_pos)
			preview_obj:SetState(state)
			table.insert(result, preview_obj)
			
			local text_obj = PlaceObject("Text")
			text_obj:SetDepthTest(false)
			text_obj:SetText(entity .. "\n" .. GetStateName(state))
			text_obj:SetPos(pos + point(radius, radius))
		end
	end
	
	atprint("Placed %d preview objects", #result)
	return result
end

----

function OnMsg.ChangeMapDone()
	if CurrentMap == "ArtTest" then
		CreateRealTimeThread(ArtTest.Start)
	end
end

if FirstLoad and config.ArtTest then
	CreateRealTimeThread(ChangeMap, "ArtTest")
end
