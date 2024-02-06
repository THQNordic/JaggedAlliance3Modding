LowEQGainItems = {
	{text = "-8 dB", value = 0},
	{text = "-7 dB", value = 1},
	{text = "-6 dB", value = 2},
	{text = "-5 dB", value = 3},
	{text = "-4 dB", value = 4},
	{text = "-3 dB", value = 5},
	{text = "-2 dB", value = 6},
	{text = "-1 dB", value = 7},
	{text = "0 dB (same as 1 kHz)", value = 8},
	{text = "+1 dB", value = 9},
	{text = "+2 dB", value = 10},
	{text = "+3 dB", value = 11},
	{text = "+4 dB", value = 12},
}

LowEQCutoffItems = {
	{text = "50 Hz" , value = 0},
	{text = "100 Hz", value = 1},
	{text = "150 Hz", value = 2},
	{text = "200 Hz", value = 3},
	{text = "250 Hz", value = 4},
	{text = "300 Hz", value = 5},
	{text = "350 Hz", value = 6},
	{text = "400 Hz", value = 7},
	{text = "450 Hz", value = 8},
	{text = "500 Hz", value = 9},
}

HighEQGainItems = {
	{text = "-8 dB", value = 0},
	{text = "-7 dB", value = 1},
	{text = "-6 dB", value = 2},
	{text = "-5 dB", value = 3},
	{text = "-4 dB", value = 4},
	{text = "-3 dB", value = 5},
	{text = "-2 dB", value = 6},
	{text = "-1 dB", value = 7},
	{text = "0 dB (same as 1 kHz)", value = 8},
}

HighEQCutoffItems = {
	{text = "1000 Hz" , value = 0},
	{text = "1500 Hz" , value = 1},
	{text = "2000 Hz" , value = 2},
	{text = "2500 Hz" , value = 3},
	{text = "3000 Hz" , value = 4},
	{text = "3500 Hz" , value = 5},
	{text = "4000 Hz" , value = 6},
	{text = "4500 Hz" , value = 7},
	{text = "5000 Hz" , value = 8},
	{text = "5500 Hz" , value = 9},
	{text = "6000 Hz" , value = 10},
	{text = "6500 Hz" , value = 11},
	{text = "7000 Hz" , value = 12},
	{text = "7500 Hz" , value = 13},
	{text = "8000 Hz" , value = 14},
}

ApplyReverbPreset = function(properties, interpTime, index)
	local params = {}
	local props = properties:GetProperties()
	for i=1, #props do
		local propid = props[i].id
		if type(properties[propid]) == "number" then
			params[propid] = properties[propid]
		end
	end
	
	SetReverbParameters(params, interpTime, index)
end

DefineClass.ReverbDef = {
	__parents = { "Preset" },
	GlobalMap = "ReverbDefs",

	properties = { 
		{ id = "DryGain",          name = "Dry Gain",                  editor = "number",       default = 100,  min = 0, max = 120, scale = 1, slider = true, hr = true, help = "Gain for the dry signal that is sent directly to Master" },
		{ id = "WetDryMix",        name = "Wet/Dry mix",               editor = "number",       default = 5,    min = 0, max = 100, scale = 1, slider = true, hr = true, help = "Percentage of the output that will be reverb." },
		{ id = "ReflectionsDelay", name = "Reflections delay (ms)",    editor = "number",       default = 5,    min = 0, max = 300, scale = 1, slider = true, hr = true, help = "The delay time of the first reflection relative to the direct path." },
		{ id = "ReverbDelay",      name = "Reverb delay (ms)",         editor = "number",       default = 5,    min = 0, max = 85, scale = 1, slider = true, hr = true, help = "Delay of reverb relative to the first reflection." },
		{ id = "EarlyDiffusion",   name = "Early diffusion",           editor = "number",       default = 8,    min = 0, max = 15, scale = 1, slider = true, hr = true, help = "Controls the character of the individual wall reflections. Set to minimum value to simulate a hard flat surface and to maximum value to simulate a diffuse surface." },
		{ id = "LateDiffusion",    name = "Late diffusion",            editor = "number",       default = 8,    min = 0, max = 15, scale = 1, slider = true, hr = true, help = "Controls the character of the individual wall reverberations. Set to minimum value to simulate a hard flat surface and to maximum value to simulate a diffuse surface." },
		{ id = "LowEQGain",        name = "Low EQ: Gain",              editor = "dropdownlist", default = 8,    items = LowEQGainItems, hr = true, help = "Adjusts the decay time of low frequencies relative to the decay time at 1 kHz. 0 results in the decay time of low frequencies being equal to the decay time at 1 kHz." },
		{ id = "LowEQCutoff",      name = "Low EQ: Cutoff",            editor = "dropdownlist", default = 4,    items = LowEQCutoffItems, hr = true, help = "Sets the corner frequency of the low pass filter that is controlled by the 'Low EQ: Gain' parameter." },
		{ id = "HighEQGain",       name = "High EQ: Gain",             editor = "dropdownlist", default = 8,    items = HighEQGainItems, hr = true, help = "Adjusts the decay time of high frequencies relative to the decay time at 1 kHz. When set to zero, high frequencies decay at the same rate as 1 kHz. When set to maximum value, high frequencies decay at a much faster rate than 1 kHz." },
		{ id = "HighEQCutoff",     name = "High EQ: Cutoff",           editor = "dropdownlist", default = 4,    items = HighEQCutoffItems, hr = true, help = "Sets the corner frequency of the high pass filter that is controlled by the 'High EQ: Gain' parameter." },
		{ id = "RoomFilterFreq",   name = "Room filter LP freq",       editor = "number",       default = 5000, min = 20, max = 20000, scale = 1, slider = true, hr = true, help = "Sets the corner frequency of the low pass filter for the room effect." },
		{ id = "RoomFilterMain",   name = "Room filter level (dB)",    editor = "number",       default = 0,    min = -10000, max = 0, scale = 100, slider = true, hr = true, help = "Sets the pass band intensity level of the low-pass filter for both the early reflections and the late field reverberation." },
		{ id = "RoomFilterHF",     name = "Room filter HF level (dB)", editor = "number",       default = 0,    min = -10000, max = 0, scale = 100, slider = true, hr = true, help = "Sets the intensity of the low-pass filter for both the early reflections and the late field reverberation at the corner frequency (RoomFilterFreq)." },
		{ id = "ReflectionsGain",  name = "Reflections gain (dB)",     editor = "number",       default = 0,    min = -10000, max = 2000, scale = 100, slider = true, hr = true, help = "Adjusts the intensity of the early reflections." },
		{ id = "ReverbGain",       name = "Reverb gain (dB)",          editor = "number",       default = 0,    min = -10000, max = 2000, scale = 100, slider = true, hr = true, help = "Adjusts the intensity of the reverberations." },
		{ id = "DecayTime",        name = "Decay time (ms)",           editor = "number",       default = 100,  min = 0, max = 1000, slider = true, hr = true, help = "Reverberation decay time at 1 kHz. This is the time that a full scale input signal decays by 60 dB." },
		{ id = "Density",          name = "Density (%)",               editor = "number",       default = 100,  min = 0, max = 100, slider = true, hr = true, help = "Controls the modal density in the late field reverberation. For colorless spaces, Density should be set to the maximum value (100). As Density is decreased, the sound becomes hollow (comb filtered). This is an effect that can be useful if you are trying to model a silo." },
		{ id = "RoomSize",         name = "Room size (feet)",          editor = "number",       default = 100,  min = 0, max = 100, slider = true, hr = true, help = "The apparent size of the acoustic space." },	},
	
	OnEditorSelect = function(properties)
		ApplyReverbPreset(properties, 0, 0)
		ApplyReverbPreset(properties, 0, 1)
	end,
	OnEditorSetProperty = function(properties)
		ApplyReverbPreset(properties, 0, 0)
		ApplyReverbPreset(properties, 0, 1)
	end,

	-- same functions for all properties
	Apply = function(self)
		local params = {}
		local props = self:GetProperties()
		for i=1, #props do
			local propid = props[i].id
			if type(self[propid]) == "number" then
				params[propid] = self[propid]
			end
		end
		
		SetReverbParameters(params,0)
	end,

	GetValue = function(self, id)
		local reverbs = GetReverbParameters()
		self[id] = reverbs[id]
	end,
	
	EditorMenubarName = "Reverb Editor",
	EditorMenubar = "Editors.Audio",
	EditorIcon = "CommonAssets/UI/Icons/church.png",
}

local function HasMoreThanTwoWallsMissing(room)
	local missing_walls = 0
	if not room:HasWallOnSide("West") then
		missing_walls = missing_walls + 1
	end
	if not room:HasWallOnSide("East") then
		missing_walls = missing_walls + 1
		if missing_walls > 1 then
			return true
		end
	end
	if not room:HasWallOnSide("North") then
		missing_walls = missing_walls + 1
		if missing_walls > 1 then
			return true
		end
	end
	if not room:HasWallOnSide("South") then
		missing_walls = missing_walls + 1
	end
	return missing_walls > 1
end

function FillVolumeReverbs()
	EnumVolumes(function(room) 
		if HasMoreThanTwoWallsMissing(room) then
			SetVolumeReverbIndex(room, 0)
		else
			SetVolumeReverbIndex(room, 1)
		end
	end)
end