if FirstLoad then
	g_FirstTimeUser = false
	g_LocalStorageFile = "AppData/" .. (Platform.ged and "LocalStorageGed.lua" or "LocalStorage.lua")
end

-- All Set*Storage functions accept a table, or one of the strings "default" and "invalid"
local function InitWithDefault(storage, default)
	assert(storage)
	if storage=="invalid" then
		storage = false
	else
		if storage=="default" then
			storage = {}
		end
		assert(type(storage)=="table")
		-- Convert the storage from dumb table to object (if needed)
		if getmetatable(default) and not ObjectClass(storage) and ObjectClass(default) then
			storage = g_Classes[default.class]:new(storage)
		end
		table.set_defaults(storage, default, "deep")
	end
	return storage
end

function GetDefaultOptionFixupMeta()
	return {
		AppliedOptionFixups = {},
		last_applied_fixup_revision = 0
	}
end

function GetDefaultAccountOptions()
	return DefaultAccountStorage.Options
end

function SetPlatformDefaultEngineOptions()
	-- Overwrite default options with platform-specific defaults
	local result_options = table.copy(DefaultEngineOptions["default_options"])
	if Platform.steamdeck then
		table.overwrite(result_options, DefaultEngineOptions["steamdeck"])
	elseif Platform.desktop then
		table.overwrite(result_options, DefaultEngineOptions["desktop"])
	elseif Platform.xbox_one and not Platform.xbox_one_x then
		table.overwrite(result_options, DefaultEngineOptions["xbox_one"])
	elseif Platform.xbox_one and Platform.xbox_one_x then
		table.overwrite(result_options, DefaultEngineOptions["xbox_one_x"])
	elseif Platform.xbox_series and not Platform.xbox_series_x then
		table.overwrite(result_options, DefaultEngineOptions["xbox_series_s"])
	elseif Platform.xbox_series and Platform.xbox_series_x then
		table.overwrite(result_options, DefaultEngineOptions["xbox_series_x"])
	elseif Platform.ps4 and not Platform.ps4_pro then
		table.overwrite(result_options, DefaultEngineOptions["ps4"])
	elseif Platform.ps4 and Platform.ps4_pro then
		table.overwrite(result_options, DefaultEngineOptions["ps4_pro"])
	elseif Platform.ps5 then
		table.overwrite(result_options, DefaultEngineOptions["ps5"])
	elseif Platform.switch then
		table.overwrite(result_options, DefaultEngineOptions["switch"])
	end
	
	PlatformDefaultEngineOptions = result_options
end

function GetDefaultEngineOptions(platform_overwrites_only)
	if platform_overwrites_only then
		if Platform.steamdeck then
			return DefaultEngineOptions["steamdeck"]
		elseif Platform.desktop then
			return DefaultEngineOptions["desktop"]
		elseif Platform.xbox_one and not Platform.xbox_one_x then
			return DefaultEngineOptions["xbox_one"]
		elseif Platform.xbox_one and Platform.xbox_one_x then
			return DefaultEngineOptions["xbox_one_x"]
		elseif Platform.xbox_series and not Platform.xbox_series_x then
			return DefaultEngineOptions["xbox_series_s"]
		elseif Platform.xbox_series and Platform.xbox_series_x then
			return DefaultEngineOptions["xbox_series_x"]
		elseif Platform.ps4 and not Platform.ps4_pro then
			return DefaultEngineOptions["ps4"]
		elseif Platform.ps4 and Platform.ps4_pro then
			return DefaultEngineOptions["ps4_pro"]
		elseif Platform.ps5 then
			return DefaultEngineOptions["ps5"]
		elseif Platform.switch then
			return DefaultEngineOptions["switch"]
		end
	end
	
	return PlatformDefaultEngineOptions
end

function GetFullEngineOptions()
	local defaults = table.copy(GetDefaultEngineOptions())
	return table.overwrite(defaults, EngineOptions)
end

function GetFullAccountOptions()
	local defaults = table.copy(GetDefaultAccountOptions())
	return table.overwrite(defaults, AccountStorage.Options)
end

function SetDefaultEngineOptionsMetaTable()
	setmetatable(EngineOptions, { __index  =  GetDefaultEngineOptions()})
end

if FirstLoad then
--[[ 
	DefaultEngineOptions["default_options"] are the main engine option defaults. They are set 
	as a __index metatable to EngineOptions. This allows only the options with a different value
	than the default to be saved on disk while any missing option fallbacks to the default value.
	See SetDefaultEngineOptionsMetaTable().
	
	Some of the defaults (Display options mainly) are used very early to initialize the engine in
	InitRenderEngine() through LuaVars in the config. It's good to know that at that point only a 
	few lua files have been executed and there are no lua classes or game-specific options yet.
	
	The other keys in DefaultEngineOptions (other than "default_options") specify 
	platform-specific overwrites of the default values.
]]
	DefaultEngineOptions = {
		default_options = {
			-- Video
			VideoPreset = "High",
			Antialiasing = "TAA",
			Upscaling = "Off",
			ResolutionPercent = "100",
			Shadows = "High",
			Textures = "High",
			Anisotropy = "4x",
			Terrain = "High",
			Effects = "High",
			Lights = "High",
			Postprocess = "High",
			Bloom = "On",
			EyeAdaptation = "On",
			Vignette = "On",
			ChromaticAberration = "On",
			SSAO = "On",
			SSR = "High",
			ViewDistance = "High",
			ObjectDetail = "High",
			FPSCounter = "Off",
			Sharpness = const.DefaultSharpness or "Low",

			-- Audio
			MasterVolume = const.MasterDefaultVolume or 500,
			Music = const.MusicDefaultVolume or 300,
			Voice = const.VoiceDefaultVolume or 1000,
			Sound = const.SoundDefaultVolume or 650,
			Ambience = const.AmbienceDefaultVolume or 1000,
			UI = const.UIDefaultVolume or 1000,
			MuteWhenMinimized = true,
			RadioStation = const.MusicDefaultRadioStation or "",

			-- Gameplay
			CameraShake = "On",

			-- Display
			FullscreenMode = 0,
			Resolution = point(1920, 1080),
			Vsync = true,
			GraphicsApi = GetDefaultGraphicsApi(),
			GraphicsAdapterIndex = 0,
			MaxFps = "240",
			DisplayAreaMargin = 0,
			UIScale = 100,
			Brightness = 500,
			
			-- Engine option fixup metadata
			fixups_meta = GetDefaultOptionFixupMeta(),
		},
		-- Platform overwrites
		desktop = {
			Resolution = Platform.developer and point(1920, 1080) or false,
			FullscreenMode = Platform.developer and 0 or 1,
		},
		xbox_one = {
			Resolution = point(1920, 1080),
			FullscreenMode = 1,
			Vsync = true,
			GraphicsApi = "d3d12",
			VideoPreset = "XboxOne",
		},
		xbox_one_x = {
			Resolution = point(2560, 1440),
			FullscreenMode = 1,
			Vsync = true,
			GraphicsApi = "d3d12",
			VideoPreset = "XboxOneX",
		},
		xbox_series_s = {
			Resolution = point(2560, 1440),
			FullscreenMode = 1,
			Vsync = true,
			GraphicsApi = "d3d12",
			VideoPreset = "XboxSeriesS",
		},
		xbox_series_x = {
			Resolution = point(3840, 2160),
			FullscreenMode = 1,
			Vsync = true,
			GraphicsApi = "d3d12",
			VideoPreset = "XboxSeriesXQuality",
		},
		ps4 = {
			Resolution = point(1920, 1080),
			FullscreenMode = 1,
			Vsync = true,
			GraphicsApi = "gnm",
			VideoPreset = "PS4",
		},
		ps4_pro = {
			Resolution = point(2240, 1260),
			FullscreenMode = 1,
			Vsync = true,
			GraphicsApi = "gnm",
			VideoPreset = "PS4Pro",
		},
		ps5 = {
			Resolution = point(3840, 2160),
			FullscreenMode = 1,
			Vsync = true,
			GraphicsApi = "agc",
			VideoPreset = "PS5Quality",
		},
		switch = {
			Resolution = point(1280, 720),
			FullscreenMode = 1,
			Vsync = true,
			FPSCounter = "Off",
			UIScale = 100,
			GraphicsApi = "NVN",
			VideoPreset = "Switch",
		},
		steamdeck = {
			Resolution = false,
			FullscreenMode = 1,
			MaxFps = "30",
			UIScale = const.MaxUserUIScaleHighRes,
			VideoPreset = "SteamDeck",
		},
	}
	
	-- Some additional settings are inited in options.lua
	DefaultAccountStorage = {
		Shortcuts = {},
		achievements = { 
			unlocked = {}, 
			progress = {}, 
			target = {} 
		},
		tips = {
			current_tip = 0
		},
		Options = {
			-- Account
			Gamepad = (Platform.console or Platform.steamdeck) and true or false,

			-- Gameplay
			--Subtitles = true,
			--Colorblind = false,
			Language = "Auto",
			
			-- Account option fixup metadata
			fixups_meta = GetDefaultOptionFixupMeta(),
		},
		LoadMods = {},
		PlayStationStartedActivities = {},
	}
	
	DefaultLocalStorage = { 
		id_old_rect = {}, 
		dlgBugReport = {},
		MovieRecord = {},
		editor = {}, 
		FilteredCategories = {},
		LockedCategories = {},
	}
	
	PlatformDefaultEngineOptions = {}
	SetPlatformDefaultEngineOptions()
	
	EngineOptions = {}
	SetDefaultEngineOptionsMetaTable()
end

function SetAccountStorage(storage)
	storage = InitWithDefault(storage, DefaultAccountStorage)
	AccountStorage = storage
	Msg("AccountStorageChanged")
end

local function InitLocalStorage()
	if not io.exists(g_LocalStorageFile) then
		return InitWithDefault("default", DefaultLocalStorage)
	end
	local fenv = LuaValueEnv()
	local t = dofile(g_LocalStorageFile, fenv)
	assert(not t or type(t) == "table")
	if not t then
		g_FirstTimeUser = true
	end
	t = InitWithDefault(t or "default", DefaultLocalStorage)
	-- move developer settings outside of options
	if t.Options and not t.Developer then
		t.Developer = {
			General = t.Options.General,
			EditorHiddenTextOptions = t.Options.EditorHiddenTextOptions,
			MapStartup = t.Options.MapStartup,
		}
		t.Options.General = nil
		t.Options.EditorHiddenTextOptions = nil
		t.Options.MapStartup = nil
	end
	t.LuaRevision = t.LuaRevision or 0
	if not Platform.developer and t.LuaRevision == 0 then
		t = InitWithDefault("default", DefaultLocalStorage)
	end
	return t
end

if FirstLoad then
	AccountStorage = false
end

function SaveEngineOptions()
	Msg("EngineOptionsSaved")
	return SaveLocalStorage()
end

if FirstLoad then
	DefaultLocalStorage.Options = EngineOptions
	LocalStorage = InitLocalStorage()
	EngineOptions = LocalStorage.Options
	SetDefaultEngineOptionsMetaTable()
end

function SaveLocalStorage()
	LocalStorage.LuaRevision = LuaRevision
	
	local code = pstr("return ", 1024)
	TableToLuaCode(LocalStorage, nil, code)
	ThreadLockKey(g_LocalStorageFile)
	local err = AsyncStringToFile(g_LocalStorageFile, code, -2, 0)
	ThreadUnlockKey(g_LocalStorageFile)
	if err then
		print("once", "Failed to save a storage table to", g_LocalStorageFile, ":", err)
		return false, err
	end
	return true
end

function SaveLocalStorageDelayed()
	DelayedCall(0, SaveLocalStorage)
end