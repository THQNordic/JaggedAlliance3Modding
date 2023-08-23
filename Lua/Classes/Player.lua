DefineClass.ZuluPlayer = {
	__parents = { "CooldownObj", "LabelContainer" },
}

function CreatePlayerObjects()
	return {ZuluPlayer:new{handle = 1}}
end