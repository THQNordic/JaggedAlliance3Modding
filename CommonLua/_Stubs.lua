if not config.Mods then
	DefineClass.ModItem = {}
	DefineClass.ModDef = {}
	DefineClass.ModItemPreset = { __parents = {"ModItem"} }
	function ModsLoadCode() end
	function ModsReloadDefs() end
	function ModsLoadLocTables() end
	function ModsReloadItems() end
	function DefineModItemPreset() end
	function DefineModItemCompositeObject() end
end

function OpenPreGameMainMenu() end
function GetPreGameMainMenu() end
function OpenIngameMainMenu() end
function GetInGameMainMenu() end
function CloseIngameMainMenu() end

function QuitGame(parent)
	parent = parent or terminal.desktop
	CreateRealTimeThread(function(parent)
		if WaitQuestion(parent, T(1000859, "Quit game?"), T(1000860, "Are you sure you want to exit the game?"), T(147627288183, "Yes"), T(1139, "No")) == "ok" then
			Msg("QuitGame")
			quit()
		end
	end, parent)
end

ToggleSoundDebug = empty_func
ToggleListenerUpdate = empty_func
DbgHideTerrainGrid = empty_func
DbgShowTerrainGrid = empty_func
SuspendFileSystemChanged = empty_func
ResumeFileSystemChanged = empty_func
NetPauseUpdateHash = empty_func
NetResumeUpdateHash = empty_func

if FirstLoad then
	FileSystemChangedFiles = false
end