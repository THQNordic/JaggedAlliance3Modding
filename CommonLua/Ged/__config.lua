config.GedLanguageEnglish = true -- added here just to be searchable
if config.GedLanguageEnglish then
	GetLanguage = function() return "English" end
end

config.GraphicsApi = GetDefaultGraphicsApi()

config.RunUnfocused = 1
config.Map = false

config.FullscreenMode = 0
config.Width = 1200
config.Height = 700
config.DisableOptions = true

--Libs.Network = true

hr.EnableShaderCompilation = 1
hr.ShowShaderCompilation = 1

hr.ShaderOptimization = 0
hr.RenderTrails = 0
hr.EnablePostprocess = 1

config.SoundTypesPath = "CommonLua/Ged/__SoundTypes.lua"
config.Music = 0

config.ObjectPoolMem    = 16  * 1024 -- in KB
config.BonesMemory      = 512 * 1024 -- in Bytes

config.MemorySavegameSize = 32 * 1024 * 1024

hr.UIL_TextureWidth = 4096
hr.UIL_TextureHeight = 4096

-- Bug Report config
if not Platform.goldmaster then
	dofile("Lua/Dev/MantisConfig.lua")
	
	function OnMsg.BugReportStart(print_func)
		for _, app in ipairs(terminal.desktop) do
			if app:IsKindOf("GedApp") then
				print_func("GedApp: " .. app:GetAppId() .. " Class: " .. (app:HasMember("PresetClass") and app.PresetClass or "none"))
				print_func("State: " .. TableToLuaCode(app:GetState()))
			end
		end
	end
end

-- text controls plugins config
--config.DefaultExternelTextEditorPath = "C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\Community\\Common7\\IDE\\devenv.exe"
config.DefaultExternalTextEditorTempFile = "tempedit.lua"
config.DefaultExternelTextEditorCmd = "start notepad++ %s"
config.DefaultTextEditPlugins = { "XExternalTextEditorPlugin" }
