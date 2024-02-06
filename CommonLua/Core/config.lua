-- Default config values which can be overridden per project

config.MapEditorRooms = not not const.SlabSizeX

config.SSRThresholdParentDistance = 0.05

if Platform.goldmaster then
	-- Makes presets read-only (unless they are mod items) and hides some editor functionalities among other things.
	-- Each game should set config.ModdingToolsInUserMode to false in the game-specific config if config.Mods is false for that game.
	config.ModdingToolsInUserMode = true
end

if (Platform.xbox_one and not Platform.xbox_one_x) or Platform.ps4 then
	config.ResReqMemPerSec = 64 * 1024
	hr.TR_UseDetailedTerrainDecals = 0
end

config.PatchPublicKey = config.PatchPublicKey or RSACreateKeyNoErr(
[[-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4KajkUYhkYjnDvsRDeig
LChvt/SKB95uB+IV02a5rVw03cO9xv7mzHsQOPeorDV6JYWYoXYqnBv773pZae/d
Vtcsyu/a8J5N+TrgXqH6a6E57LnOYpGH3S/CwXYGSoQWq6H5lpbA97OZzSnEC8Mw
5VoFqZ1wyYDW+YFOho0Ykz9wZbhlKLj7zRO/2aZiFQq0L9sbsbe53tVOSuABVtd9
d1sdUErectIhtIUCg+HxH4fI6ge1np3laa7s0spIkzvFC+zUxbHfNBBSXoJW/hRU
mqIul2nizv/j/1IIGc+gD8Ruml9tVE1xtR1YjkqbZfphnDM5FMxsn7xnZ/0tdtOl
0wIDAQAB
-----END PUBLIC KEY-----]])
