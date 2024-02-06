DefineClass.DuckingParam = {
	__parents = { "Preset" },
	GlobalMap = "DuckingParams",

	properties = { 
		{ id = "Name",		name = "Name",					editor = "text",	default = ""	,																help = "The name with which this ducking tier will appear in the sound type editor." },
		{ id = "Tier",		name = "Tier",					editor = "number", default = 0,		min = -1, max = 100,  								   help = "Which tiers will be affected by this one - lower tiers affect higher ones." },
		{ id = "Strength",	name = "Strength",				editor = "number",	default = 100,	min = 0,  max = 1000, scale = 1, slider = true, help = "How much will this tier duck the ones below it." },
		{ id = "Attack",	name = "Attack Duration",		editor = "number",	default = 100,  min = 0,  max = 1000, scale = 1, slider = true, help = "How long will this tier take to go from no effect to full ducking in ms." },
		{ id = "Release",	name = "Release Duration",	editor = "number",	default = 100,	min = 0,  max = 1000, scale = 1, slider = true, help = "How long will this tier take to go from full ducking to no effect in ms." },
		{ id = "Hold",		name = "Hold Duration",		editor = "number", default = 100, 	min = 0,  max = 5000, scale = 1, slider = true,	help = "How long will this tier take, before starting to decay the ducking strength, after the sound strength decreases." },
		{ id = "Envelope",	name = "Use side chain",		editor = "bool",	default = true,																help = "Should the sounds in this preset modify the other sounds based on the current strength of their sound, or apply a constant static effect." },
	},
	
	OnEditorSetProperty = function(properties)
		ReloadDucking()
	end,

	Apply = function(self)
		ReloadDucking()
	end,
	
	EditorMenubarName = "Ducking Editor",
	EditorMenubar = "Editors.Audio",
	EditorIcon = "CommonAssets/UI/Icons/church.png",
}

function ReloadDucking()
	local names = {}
	local tiers = {}
	local strengths = {}
	local attacks = {}
	local releases = {}
	local hold = {}
	local envelopes = {}
	local i = 1
	for _, p in pairs(DuckingParams) do
		names[i] = p.id
		tiers[i] = p.Tier
		strengths[i] = p.Strength
		attacks[i] = p.Attack
		releases[i] = p.Release
		hold[i] = p.Hold
		envelopes[i] = p.Envelope and 1 or 0
		i = i + 1
	end
	LoadDuckingParams(names, tiers, strengths, attacks, releases, hold, envelopes)
	ReloadSoundTypes()
end

function ChangeDuckingPreset(id, tier, str, attack, release, hold)
	if tier then
		DuckingParams[id].Tier = tier
	end
	if str then
		DuckingParams[id].Strength = str
	end
	if attack then
		DuckingParams[id].Attack = attack
	end
	if release then
		DuckingParams[id].Release = release
	end
	if hold then
		DuckingParams[id].Hold = hold
	end
	ReloadDucking()
end

OnMsg.DataLoaded = ReloadDucking