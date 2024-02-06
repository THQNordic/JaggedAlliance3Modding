GameVar("MapLoadRandom", function() return InitMapLoadRandom() end)
GameVar("InteractionSeeds", {})
GameVar("InteractionSeed", function() return MapLoadRandom end)

function InitMapLoadRandom()
	if config.FixedMapLoadRandom then
		return config.FixedMapLoadRandom
	elseif Game and (Game.seed_text or "") ~= "" then
		return xxhash(Game.seed_text)
	elseif netInGame and Libs.Network == "sync" then
		return bxor(netGameSeed, mapdata and mapdata.NetHash or 0)
	else
		return AsyncRand()
	end
end

function OnMsg.PreNewMap()
	MapLoadRandom = InitMapLoadRandom()
	ResetInteractionRand(0)
end

function OnMsg.NewMapLoaded()
	if Game then
		DebugPrint("Game Seed: ", Game.seed_text, "\n")
	end
end

local BraidRandom = BraidRandom
local xxhash = xxhash

function ResetInteractionRand(seed)
	NetUpdateHash("ResetInteractionRand", seed)
	InteractionSeeds = {}
	InteractionSeed = xxhash(seed, MapLoadRandom)
end

function InteractionRand(max, int_type, obj, target)
	assert(type(max) ~= "string")
	int_type = int_type or "none"
	assert(type(int_type) == "string")
	assert(not IsValid(obj) or obj:IsSyncObject() or IsHandleSync(obj.handle) or obj:GetGameFlags(const.gofPermanent) ~= 0)
	if type(max) == "number" and max <= 1 then
		return 0
	end

	local interaction_seeds = InteractionSeeds
	assert(interaction_seeds)
	if not interaction_seeds then
		return 0
	end
	
	local interaction_seed = interaction_seeds[int_type] or xxhash(InteractionSeed, int_type)
	local rand
	rand, interaction_seed = BraidRandom(interaction_seed, max)
	interaction_seeds[int_type] = interaction_seed

	NetUpdateHash("InteractionRand", rand, max, int_type, obj)

	return rand, interaction_seed
end

function InteractionRandRange(min, max, int_type, ...)
	return min + InteractionRand(max - min + 1, int_type, ...)
end

function InteractionRandRange2(range, int_type, ...)
	return range.from + InteractionRand(range.to - range.from + 1, int_type, ...)
end

function OnMsg.NewMapLoaded()
	DebugPrint("MapLoadRandom: ", MapLoadRandom, "\n")
end

function InteractionRandCreate(int_type, obj, target)
	return BraidRandomCreate(InteractionRand(nil, int_type, obj, target))
end
