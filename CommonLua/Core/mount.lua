if not FirstLoad then return end
if Platform.ps4 then
	OrbisStartFakeSubmitDone()
end

local unpacked = IsFSUnpacked()

-- Data & Lua
if unpacked then
	LuaPackfile = false
	DataPackfile = false
	MountFolder("Data", "svnProject/Data/", "label:Data")
else
	LuaPackfile = "Packs/Lua.hpk"
	DataPackfile = "Packs/Data.hpk"
	MountPack("Data", "Packs/Data.hpk", "in_mem,label:Data")
end

if config.Mods then
	MountFolder("ModTools/", GetExecDirectory() .. "ModTools/")
end

-- Fonts & UI
if unpacked then
	MountFolder("Fonts", "svnAssets/Bin/Common/Fonts/")
	MountFolder("UI", "svnAssets/Bin/Common/UI/")
else
	MountPack("Fonts", "Packs/Fonts.hpk")
	MountPack("UI", "Packs/UI.hpk")
end

-- Misc
if unpacked then
	MountFolder("Misc", "svnAssets/Source/Misc")
else
	MountPack("Misc", "Packs/Misc.hpk")
end


-- Shader cache mounting must happen on the C side,
-- because it has to happen after the graphics API has been determined,
-- but before various subsystems request their shaders in their Init() methods

if unpacked then
	MountFolder("Shaders", "svnProject/Shaders/", "seethrough")
	MountFolder("Shaders", "svnSrc/HR/Shaders/", "seethrough")
else
	if Platform.desktop or Platform.xbox or Platform.switch then
		MountPack("Shaders", "Packs/Shaders.hpk", "seethrough")
	end
end

-- Assets
if unpacked then
	MountFolder("CommonAssets", "svnSrc/CommonAssets/")
	MountFolder("BinAssets", "svnAssets/Bin/win32/BinAssets/")

	MountFolder("Meshes", "CommonAssets/Entities/Meshes/")
	MountFolder("Skeletons", "CommonAssets/Entities/Skeletons/")
	MountFolder("Entities", "CommonAssets/Entities/Entities/")
	MountFolder("Animations", "CommonAssets/Entities/Animations/")
	MountFolder("Materials", "CommonAssets/Entities/Materials/")
	MountFolder("Mapping", "CommonAssets/Entities/Mapping/")
	MountFolder("TexturesMeta", "CommonAssets/Entities/TexturesMeta/", "seethrough")
	MountFolder("Fallbacks", "CommonAssets/Entities/Fallbacks/")
	
	MountFolder("Meshes", "svnAssets/Bin/Common/Meshes/", "seethrough")
	MountFolder("Skeletons", "svnAssets/Bin/Common/Skeletons/", "seethrough")
	MountFolder("Entities", "svnAssets/Bin/Common/Entities/", "seethrough")
	MountFolder("Animations", "svnAssets/Bin/Common/Animations/", "seethrough")
	MountFolder("Materials", "svnAssets/Bin/Common/Materials/", "seethrough")
	MountFolder("Mapping", "svnAssets/Bin/Common/Mapping/", "seethrough")
	MountFolder("TexturesMeta", "svnAssets/Bin/Common/TexturesMeta/", "seethrough")
	MountFolder("Fallbacks", "svnAssets/Bin/win32/Fallbacks/", "seethrough")
else	
	MountPack("Meshes", "Packs/Meshes.hpk")
	MountPack("Skeletons", "Packs/Skeletons.hpk")
	MountPack("Animations", "Packs/Animations.hpk")
	MountPack("Fallbacks", "Packs/Fallbacks.hpk")
	
	MountPack("BinAssets", "Packs/BinAssets.hpk")
	MountPack("", "Packs/CommonAssets.hpk", "seethrough,label:CommonAssets")
end
	
const.LastBinAssetsBuildRevision = tonumber(dofile("BinAssets/AssetsRevision.lua") or 0) or 0

if not Platform.ged then
	-- Sounds & Music
	if unpacked then
		MountFolder("Sounds", "svnAssets/Source/Sounds/")
		MountFolder("Music", "svnAssets/Source/Music/")
		CreateLRUMemoryCache("Sounds", config.SoundCacheMemorySize or 0)
	end

	-- Movies
	if unpacked then
		MountFolder("Movies", "svnAssets/Bin/win32/Movies/")
	end
end

if FirstLoad and config.MemoryScreenshotSize then
	MountPack("memoryscreenshot", "", "create", config.MemoryScreenshotSize);
end

g_VoiceVariations = false

function MountLanguage()
	local unpacked = config.UnpackedLocalization or config.UnpackedLocalization == nil and IsFSUnpacked()
	UnmountByLabel("CurrentLanguage")
	g_VoiceVariations = false
	if unpacked then
		MountFolder("CurrentLanguage", "svnProject/LocalizationOut/" .. GetLanguage() .. "/CurrentLanguage/", "label:CurrentLanguage")
		local unpacked_voices = "svnAssets/Bin/win32/Voices/" .. GetVoiceLanguage() .. "/"
		if not io.exists(unpacked_voices) then
			SetVoiceLanguage("English")
			unpacked_voices = "svnAssets/Bin/win32/Voices/" .. GetVoiceLanguage() .. "/"
		end
		MountFolder("CurrentLanguage/Voices", "svnAssets/Bin/win32/Voices/" .. GetVoiceLanguage() .. "/", "label:CurrentLanguage")
		if config.VoicesTTS then
			MountFolder("CurrentLanguage/VoicesTTS", "svnAssets/Bin/win32/VoicesTTS/" .. GetVoiceLanguage() .. "/", "label:CurrentLanguage")
		end
	else
		local err = MountPack("", "Local/" .. GetLanguage() .. ".hpk", "seethrough,label:CurrentLanguage")
		if err then
			SetLanguage("English")
			MountPack("", "Local/" .. GetLanguage() .. ".hpk", "seethrough,label:CurrentLanguage")
		end
		
		err = MountPack("CurrentLanguage/Voices", "Local/Voices/" .. GetVoiceLanguage() .. ".hpk", "label:CurrentLanguage")
		if err then
			SetVoiceLanguage("English")
			MountPack("CurrentLanguage/Voices", "Local/Voices/" .. GetVoiceLanguage() .. ".hpk", "label:CurrentLanguage")
		end
		if config.VoicesTTS then
			MountPack("CurrentLanguage/VoicesTTS", "Local/VoicesTTS/" .. GetVoiceLanguage() .. ".hpk", "label:CurrentLanguage")
		end
	end
	if rawget(_G, "DlcDefinitions") then
		DlcMountVoices(DlcDefinitions)
	end	

	if config.GedLanguageEnglish then
		if unpacked then
			MountFolder("EnglishLanguage", "svnProject/LocalizationOut/English/")
		else
			MountPack("EnglishLanguage", "Local/English.hpk")
		end
	end
	
	local voice_variations_path = "CurrentLanguage/Voices/variations.lua"
	if io.exists(voice_variations_path) then
		local ok, vars = pdofile(voice_variations_path)
		if ok then
			g_VoiceVariations = vars
		else
			dbg(DebugPrint(string.format("Error loading voice variations: %s", vars)))
		end
	end
end

-- Localization
MountLanguage()

local function MountTextures(unpacked)
	if unpacked then
		MountFolder("Textures", "CommonAssets/Entities/Textures/", "priority:high")
		MountFolder("Textures", "svnAssets/Bin/win32/Textures/", "priority:high,seethrough")
		
		local billboardFolders = io.listfiles("svnAssets/Bin/win32/Textures/Billboards/", "*", "folders") 
		for _, folder in pairs(billboardFolders) do
			MountFolder("Textures/Billboards", folder .. "/", "priority:high,seethrough")
		end
	
		if Platform.osx then
			MountFolder("Textures/Cubemaps", "svnAssets/Bin/osx/Textures/Cubemaps/", "priority:high")
		end
	else
		if Platform.desktop or Platform.xbox or Platform.switch then
			MountPack("Textures", "Packs/Textures.hpk", "priority:high,seethrough")
			for i = 0, 9 do
				MountPack("", "Packs/Textures"..tostring(i)..".hpk", "priority:high,seethrough")
			end
		else
			MountPack("Textures", "Packs/Textures.hpk", "priority:high,seethrough")
		end
	end
end


-- Documentation

if unpacked then
	UnmountByPath("Docs")
	MountFolder("Docs", "svnSrc/Docs/")
	MountFolder("Docs", "svnProject/Docs/", "seethrough")
	MountFolder("Docs", "svnProject/Docs/ModTools/", "seethrough")
else
	MountFolder("Docs", "ModTools/Docs/")
end

function OnMsg.Autorun()
	local metaCheck = const.PrecacheDontCheck
	if Platform.test then
		metaCheck = Platform.pc and const.PrecacheCheckUpToDate or const.PrecacheCheckExists
	end
	local files = io.listfiles("BinAssets", "*.meta")
	for i = 1, #files do
		ResourceManager.LoadPrecacheMetadata(files[i], metaCheck)
	end
end

if not Platform.ged then
	-- Textures, Maps and Prefabs
	if unpacked then
		MountTextures(unpacked)
		MountFolder("Maps", "svnAssets/Source/Maps/", "create")
		MountFolder("Prefabs", "svnAssets/Source/Prefabs/", "create")
	else
		MountPack("Music", "Packs/Music.hpk")
		MountPack("Sounds", "Packs/Sounds.hpk", "seethrough,priority:high")
		CreateLRUMemoryCache("Sounds", config.SoundCacheMemorySize or 0)
		MountTextures(unpacked)
		MountPack("Textures/Cubemaps", "Packs/Cubemaps.hpk", "priority:high")
		MountPack("", "Packs/AdditionalTextures.hpk", "priority:high,seethrough,label:AdditionalTextures")
		MountPack("", "Packs/AdditionalNETextures.hpk", "priority:high,seethrough,label:AdditionalNETextures")
		MountPack("Prefabs", "Packs/Prefabs.hpk")
	end
elseif Platform.developer then	-- ged
		MountTextures(unpacked)
end

CreateRealTimeThread(function()
	if unpacked then
		LuaRevision = GetUnpackedLuaRevision(nil, nil, config.FallbackLuaRevision) or LuaRevision
		AssetsRevision = GetUnpackedLuaRevision(false, "svnAssets/.", config.FallbackAssetsRevision) or AssetsRevision
	else
		AssetsRevision = const.LastBinAssetsBuildRevision ~= 0 and const.LastBinAssetsBuildRevision or AssetsRevision
	end
	DebugPrint("Lua revision: " .. LuaRevision .. "\n")
	SetBuildRevision(LuaRevision)
	DebugPrint("Assets revision: " .. AssetsRevision .. "\n")
	if Platform.steam then
		DebugPrint("Steam AppID: " .. (SteamGetAppId() or "<unknown>") .. "\n")
	end
	if (BuildVersion or "") ~= "" then
		DebugPrint("Build version: " .. BuildVersion .. "\n")
	end
	if (BuildBranch or "") ~= "" then
		DebugPrint("Build branch: " .. BuildBranch .. "\n")
	end
end)

if Platform.ps4 then
	OrbisStopFakeSubmitDone()
end
