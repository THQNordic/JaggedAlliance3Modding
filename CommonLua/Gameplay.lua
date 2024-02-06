if FirstLoad then
	Game = false
end
PersistableGlobals.Game = true

if not Platform.ged then
DefineClass.GameClass = {
	__parents = { "CooldownObj", "GameSettings", "LabelContainer" },
}
end

function NewGame(game)
	DoneGame()
	if not IsKindOf(game, "GameClass") then
		game = GameClass:new(game)
	end
	game.save_id = nil
	Game = game
	InitGameVars()
	Msg("NewGame", game)
	NetGossip("NewGame", game.id, GetGameSettingsTable(game))
	return game
end

function DoneGame()
	local game = Game
	if not game then
		return
	end
	NetGossip("DoneGame", GameTime(), game.id)
	DoneGameVars()
	Game = false
	Msg("DoneGame", game)
	game:delete()
end

function DevReloadMap()
	ReloadMap(true)
end

function RestartGame()
	CreateRealTimeThread(function()
		LoadingScreenOpen("idLoadingScreen", "RestartGame")
		local map = GetOrigMapName()
		local game2 = CloneObject(Game)
		ChangeMap("")
		NewGame(game2)
		ChangeMap(map)
		LoadingScreenClose("idLoadingScreen", "RestartGame")
	end)
end

function RestartGameFromMenu(host, parent)
	CreateRealTimeThread(function(host, parent)
		if WaitQuestion(parent or host, T(354536203098, "<RestartMapText()>"), T(1000852, "Are you sure you want to restart the map? Any unsaved progress will be lost."), T(147627288183, "Yes"), T(1139, "No")) == "ok" then
			LoadingScreenOpen("idLoadingScreen", "RestartMap")
			if host.window_state ~= "destroying" then
				host:Close()
			end
			RestartGame()
			LoadingScreenClose("idLoadingScreen", "RestartMap")
		end
	end, host, parent)
end

function OnMsg.ChangeMap(map, mapdata)
	ChangeGameState("gameplay", false)
end

function GetDefaultGameParams()
end

function OnMsg.PreNewMap(map, mapdata)
	if map ~= "" and not Game and mapdata.GameLogic and mapdata.MapType ~= "system" then
		NewGame(GetDefaultGameParams())
	end
end

function OnMsg.ChangeMapDone(map)
	if map ~= "" and mapdata.GameLogic then
		ChangeGameState("gameplay", true)
	end
end

function OnMsg.LoadGame()
	assert( GetMap() ~= "" )
	ChangeGameState("gameplay", true)
	if not Game then return end
	Game.loaded_from_id = Game.save_id
	NetGossip("LoadGame", Game.id, Game.loaded_from_id, GetGameSettingsTable(Game))
end

function OnMsg.SaveGameStart()
	if not Game then return end
	Game.save_id = random_encode64(48)
	NetGossip("SaveGame", GameTime(), Game.id, Game.save_id)
end

function GetGameSettingsTable(game)
	local settings = {}
	assert(IsKindOf(game, "GameSettings"))
	for _, prop_meta in ipairs(GameSettings:GetProperties()) do
		settings[prop_meta.id] = game:GetProperty(prop_meta.id)
	end
	return settings
end

function OnMsg.NewMap()
	NetGossip("map", GetMapName(), MapLoadRandom)
end

function OnMsg.ChangeMap(map)
	if map == "" then
		NetGossip("map", "")
	end
end

function OnMsg.NetConnect()
	if Game then
		NetGossip("GameInProgress", GameTime(), Game.id, Game.loaded_from_id, GetMapName(), MapLoadRandom, GetGameSettingsTable(Game))
	end
end

function OnMsg.BugReportStart(print_func)
	if Game then
		print_func("\nGameSettings:", TableToLuaCode(GetGameSettingsTable(Game), " "), "\n")
	end
end


-- GameVars (persistable, reset on new game)

GameVars = {}
GameVarValues = {}

function GameVar(name, value, meta)
	if type(value) == "table" then
		local org_value = value
		value = function()
			local v = table.copy(org_value, false)
			setmetatable(v, getmetatable(org_value) or meta)
			return v
		end
	end
	if FirstLoad or rawget(_G, name) == nil then
		rawset(_G, name, false)
	end
	GameVars[#GameVars + 1] = name
	GameVarValues[name] = value or false
	PersistableGlobals[name] = true
end

function InitGameVars()
	for _, name in ipairs(GameVars) do
		local value = GameVarValues[name]
		if type(value) == "function" then
			value = value()
		end
		_G[name] = value or false
	end
end

function DoneGameVars()
	for _, name in ipairs(GameVars) do
		_G[name] = false
	end
end

function OnMsg.PersistPostLoad(data)
	-- create missing game vars (unexisting at the time of the save)
	for _, name in ipairs(GameVars) do
		if data[name] == nil then
			local value = GameVarValues[name]
			if type(value) == "function" then
				value = value()
			end
			_G[name] = value or false
		end
	end
end

function GetCurrentGameVarValues()
	local gvars = {}
	for _, name in ipairs(GameVars) do
		gvars[name] = _G[name]
	end
	return gvars
end

function GetPersistableGameVarValues()
	local gvars = {}
	for _, name in ipairs(GameVars) do
		if PersistableGlobals[name] then
			gvars[name] = _G[name]
		end
	end
	return gvars
end

----

GameVar("LastPlaytime", 0)
if FirstLoad then
	PlaytimeCheckpoint = false
end
function OnMsg.SaveGameStart()
	LastPlaytime = GetCurrentPlaytime()
	PlaytimeCheckpoint = GetPreciseTicks()
end
function OnMsg.LoadGame()
	PlaytimeCheckpoint = GetPreciseTicks()
end
function OnMsg.NewGame()
	PlaytimeCheckpoint = GetPreciseTicks() -- also called on LoadGame
end
function OnMsg.DoneGame()
	PlaytimeCheckpoint = false
end
function GetCurrentPlaytime()
	return PlaytimeCheckpoint and (LastPlaytime + (GetPreciseTicks() - PlaytimeCheckpoint)) or 0
end
function FormatElapsedTime(time, format)
	format = format or "dhms"
	local sec = 1000
	local min = 60 * sec
	local hour = 60 * min
	local day = 24 * hour
	
	local res = {}
	if format:find_lower("d") then
		res[#res + 1] = time / day
		time = time % day
	end
	if format:find_lower("h") then
		res[#res + 1] = time / hour
		time = time % hour
	end
	if format:find_lower("m") then
		res[#res + 1] = time / min
		time = time % min
	end
	if format:find_lower("s") then
		res[#res + 1] = time / sec
		time = time % sec
	end
	res[#res + 1] = time
	
	return table.unpack(res)
end

if Platform.asserts then

function OnMsg.NewMapLoaded()
	if not Game then return end
	local last_game = LocalStorage.last_game
	local count = 0
	for _, prop_meta in ipairs(GameSettings:GetProperties()) do
		if prop_meta.remember_as_last then
			local value = Game[prop_meta.id]
			last_game = last_game or {}
			if value ~= last_game[prop_meta.id] then
				last_game[prop_meta.id] = value
				count = count + 1
			end
		end
	end
	if count == 0 then return end
	LocalStorage.last_game = last_game
	SaveLocalStorageDelayed()
end

end -- Platform.asserts

