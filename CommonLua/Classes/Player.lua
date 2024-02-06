MapVar("Players", false)
MapVar("UIPlayer", false)


----- Player

DefineClass.Player = {
	__parents = { "CooldownObj", "LabelContainer" },
	player = false,
}

function Player:Init()
	self.player = self
end


----- PlayerObject

DefineClass.PlayerObject = {
	__parents = { "Object" },
	properties = {
		{ id = "player", editor = "object", default = false, read_only = true, },
	},
}

function PlayerObject:Done()
	self.player = nil
end

function PlayerObject:PostLoad()
	if IsEditorActive() then
		self.player = UIPlayer
	end
end


-----

function CreatePlayerObjects()
	return { Player:new{ handle = 1 } }
end

function OnMsg.NewMap()
	if not mapdata.GameLogic then return end
	SetPlayers(CreatePlayerObjects())
end

function SetPlayers(players, ui_player)
	Players = players or {}
	UIPlayer = ui_player or players and players[1] or false
	for _, player in ipairs(players) do
		Msg("PlayerObjectCreated", player)
	end
end