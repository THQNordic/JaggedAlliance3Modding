if FirstLoad then
	SoundBankPresetsPlaying = {}
	SoundEditorGroups = {}
	SoundEditorSampleInfoCache = {}
	SoundFilesCache = {}
	SoundFilesCacheTime = 0
end

config.SoundTypesPath = config.SoundTypesPath or "Lua/Config/__SoundTypes.lua"
config.SoundTypeTest = config.SoundTypeTest or "SoundTest"

local function EditorSoundStoped(sound_group, id)
	local group = SoundEditorGroups[sound_group]
	if group then
		table.remove_value(group, id)
		if #group == 0 then
			SetOptionsGroupVolume(sound_group, group.old_volume)
			SoundEditorGroups[sound_group] = nil
			print("Restoring volume to", group.old_volume, "for group", sound_group)
		end
	end
end

local function EditorSoundStarted(sound_group, id)
	local group = SoundEditorGroups[sound_group] or {}
	table.insert(group, id)
	if #group == 1 then
		group.old_volume = GetOptionsGroupVolume(sound_group)
		SoundEditorGroups[sound_group] = group
		print("Temporarily setting the volume of", sound_group ,"to 1000.")
	end
	SetOptionsGroupVolume(sound_group, 1000)
end

local function PlayStopSoundPreset(id, obj, sound_group, sound_type)
	if SoundBankPresetsPlaying[id] then
		StopSound(SoundBankPresetsPlaying[id])
		SoundBankPresetsPlaying[id] = nil
		EditorSoundStoped(sound_group, id)
		ObjModified(obj)
		return nil
	end
	
	local result, err = PlaySound(id, sound_type)
	if result then
		SoundBankPresetsPlaying[id] = result
		EditorSoundStarted(sound_group, id)
		ObjModified(obj)
		
		local looping, duration = IsSoundLooping(result), GetSoundDuration(result)
		print("Playing sound", id, "looping:", looping, "duration:", duration)
		if not looping and duration then
			CreateRealTimeThread(function() 
				Sleep(duration)
				SoundBankPresetsPlaying[id] = nil
				EditorSoundStoped(sound_group, id)
				ObjModified(obj)
			end)
		end
	else
		print("Failed to play sound", id, ":", err)
	end
end

function GedPlaySoundPreset(ged)
	local sel_obj = ged:ResolveObj("SelectedObject")
	
	if IsKindOf(sel_obj, "SoundPreset") then
		PlayStopSoundPreset(sel_obj.id, Presets.SoundPreset, SoundTypePresets[sel_obj.type].options_group, config.SoundTypeTest)
	elseif IsKindOf(sel_obj, "SoundFile") then
		local preset = ged:GetParentOfKind("SelectedObject", "SoundPreset")
		if preset then
			PlayStopSoundPreset(sel_obj.file, preset, SoundTypePresets[preset.type].options_group, config.SoundTypeTest or preset.type)
		end
	end
end

DefineClass.SoundPreset = {
	__parents = {"Preset"},
	properties = {
		-- "sound"
		{ id = "type", editor = "preset_id", preset_class = "SoundTypePreset", name = "Sound Type", default = "" },
		{ id = "looping", editor = "bool", default = false, read_only = function (self) return self.periodic end, help = "Looping sounds are played in an endless loop without a gap." },
		{ id = "periodic", editor = "bool", default = false, read_only = function (self) return self.looping end, help = "Periodic sounds are repeated with random pauses between the repetitions; a different sample is chosen randomly each time." },
		{ id = "animsync", name = "Sync with animation", editor = "bool", default = false, read_only = function (self) return self.looping end, help = "Plays at the start of each animation. Anim synced sounds are periodic as well." },
		{ id = "volume", editor = "number", default = 100, min = 0, max = 300, slider = true, help = "Per-sound bank volume attenuation",
			buttons = { { name = "Adjust by %", func = "GedAdjustVolume" } },
		},
		{ id = "loud_distance", editor = "number", default = 0, min = 0, max = MaxSoundLoudDistance, slider = true, scale = "m", help = "No attenuation below that distance (in meters). In case of zero the sound group loud_distance is used." },
		{ id = "silence_frequency", editor = "number", default = 0, min = 0, help = "A random sample is chosen to play each time from this bank, using a weighted random; if this is non-zero, nothing will play with chance corresponding to this weight."},
		{ id = "silence_duration", editor = "number", default = 1000, min = 0, no_edit = function (self) return not self.periodic end, help = "Duration of the silence, if the weighted random picks silence. (Valid only for periodic sounds.)" },
		{ id = "periodic_delay", editor = "number", default = 0, min = 0, no_edit = function (self) return not self.periodic end, help = "Delay between repeating periodic sounds, fixed part."},
		{ id = "random_periodic_delay", editor = "number", default = 1000, min = 0, no_edit = function (self) return not self.periodic end, help = "Delay between repeating periodic sounds, random part."},
		{ id = "loop_start", editor = "number", default = 0, min = 0, no_edit = function (self) return not self.looping end, help = "For looping sounds, specify start of the looping part, in milliseconds." },
		{ id = "loop_end", editor = "number", default = 0, min = 0, no_edit = function (self) return not self.looping end, help = "For looping sounds, specify end of the looping part, in milliseconds."  },
		
		{ id = "unused", editor = "bool", default = false, read_only = true, dont_save = true },
	},
	
	GlobalMap = "SoundPresets",
	ContainerClass = "SoundFile",
	GedEditor = "SoundEditor",
	EditorMenubarName = "Sound Bank Editor",
	EditorMenubar = "Editors.Audio",
	EditorIcon = "CommonAssets/UI/Icons/bell message new notification sign.png",
	PresetIdRegex = "^[%w _+-]*$",
	FilterClass = "SoundPresetFilter",
	
	EditorView = Untranslated("<EditorColor><id> <color 75 105 198><type><color 128 128 128><opt(u(save_in), ' - ', '')><opt(SampleCount, ' <color 128 128 128>', '</color>')><opt(UnusedStr, ' <color 240 0 0>', '</color>')>")
}

if FirstLoad then
	SoundPresetAdjustPercent = false
	SoundPresetAdjustPercentUI = false
end

function OnMsg.GedExecPropButtonStarted()
	SoundPresetAdjustPercentUI = false
end

function OnMsg.GedExecPropButtonCompleted(obj)
	ObjModified(obj)
end

function SoundPreset:GetUnusedStr()
	return self.unused and "unused" or ""
end

function SoundPreset:GedAdjustVolume(root, prop_id, ged, btn_param, idx)
	if not SoundPresetAdjustPercentUI then
		SoundPresetAdjustPercentUI = true
		SoundPresetAdjustPercent = ged:WaitUserInput("Enter adjust percent")
		if not SoundPresetAdjustPercent then
			ged:ShowMessage("Invalid Value", "Please enter a percentage number.")
			return
		end
	end
	if SoundPresetAdjustPercent then
		self.volume = MulDivRound(self.volume, 100 + SoundPresetAdjustPercent, 100)
		ObjModified(self)
	end
end

function SoundPreset:GetSoundFiles()
	if GetPreciseTicks() < 0 and SoundFilesCacheTime >= 0 or GetPreciseTicks() > SoundFilesCacheTime + 1000 then
		SoundFilesCache = {}
		local files = io.listfiles("Sounds", "*", "recursive")
		for _, name in ipairs(files) do
			SoundFilesCache[name] = true
		end
		SoundFilesCacheTime = GetPreciseTicks()
	end
	return SoundFilesCache
end

function SoundPreset:GetError()
	local stype = SoundTypePresets[self.type]
	if not stype then
		return "Please set a valid sound type."
	end
	
	local err_table = { "", "error" } -- indexes of subobjects to be underlined are inserted in this table
	
	-- Positional sounds should be mono
	if stype.positional then
		for idx, sample in ipairs(self) do
			local data = sample:GetSampleData()
			if data and data.channels > 1 then
				err_table[1] = "The underlined positional sounds should be mono only."
				table.insert(err_table, idx)
			end
		end
	end
	if #err_table > 2 then
		return err_table
	end
	
	-- Invalid characters in file name
	for idx, sample in ipairs(self) do
		local file = sample.file
		for i = 1, #file do
			if file:byte(i) > 127 then
				err_table[1] = "Invalid character(s) are found in the underlined sample file names."
				table.insert(err_table, idx)
				break
			end
		end
	end
	if #err_table > 2 then
		return err_table
	end
	
	-- File missing
	local filenames = self:GetSoundFiles()
	for idx, sample in ipairs(self) do
		if not filenames[sample:Getpath()] then
			err_table[1] = "The underlined sound files are missing or empty."
			table.insert(err_table, idx)
		end
	end
	if #err_table > 2 then
		return err_table
	end
	
	-- Duplicate files
	local file_set = {}
	for idx, sample in ipairs(self) do
		local file = sample.file
		if file_set[file] then
			err_table[1] = "Duplicate sample files."
			table.insert(err_table, idx)
			table.insert(err_table, file_set[file])
		end
		file_set[file] = idx
	end
	if #err_table > 2 then
		return err_table
	end
end

function SoundPreset:EditorColor()
	if SoundBankPresetsPlaying[self.id] then
		return "<color 0 128 0>"
	end
	return #self == 0 and "<alpha 128>" or ""
end

function SoundPreset:GetSampleCount()
	return #self == 0 and "" or #self
end

function SoundPreset:OnEditorNew()
	LoadSoundBank(self)
end

function SoundPreset:OverrideSampleFuncs()
end

function SoundPreset:Setlooping(val)
	if type(val) == "number" then
		self.looping = (val == 1)
	else
		self.looping = not not val
	end
end 

function SoundPreset:Getlooping(val)
	if type(self.looping) == "number" then
		return self.looping ~= 0
	end
	return self.looping and true or false
end

local bool_filter_items = { { text = "true", value = true }, { text = "false", value = false }, { text = "any", value = "any" } }
DefineClass.SoundPresetFilter = {
	__parents = { "GedFilter" },
	
	properties = {
		{ id = "SoundType", name = "Sound type", editor = "choice", default = "", items = PresetsCombo("SoundTypePreset", false, "") },
		{ id = "Looping", editor = "choice", default = "any", items = bool_filter_items },
		{ id = "Periodic", editor = "choice", default = "any", items = bool_filter_items },
		{ id = "AnimSync", name = "Sync with animation", editor = "choice", default = "any", items = bool_filter_items },
		{ id = "Unused", name = "Unused", editor = "choice", default = "any", items = bool_filter_items },
	},
}

function SoundPresetFilter:FilterObject(o)
	if self.SoundType ~= ""    and o.type     ~= self.SoundType then return false end
	if self.Looping   ~= "any" and o.looping  ~= self.Looping   then return false end
	if self.Periodic  ~= "any" and o.periodic ~= self.Periodic  then return false end
	if self.AnimSync  ~= "any" and o.animsync ~= self.AnimSync  then return false end
	if self.Unused  ~= "any"   and o.unused   ~= self.Unused    then return false end
	return true
end


local sample_base_folder = "Sounds"
local function folder_fn(obj) return obj:GetFolder() end
local function filter_fn(obj) return obj:GetFileFilter() end
DefineClass.SoundFile = {
	__parents = {"PropertyObject"},
	properties = {
		{ id = "file", editor = "browse", no_edit = true, default = "" },
		{ id = "path", dont_save = true, name = "Path", editor = "browse", default = "", folder = folder_fn, filter = filter_fn, mod_dst = function() return GetModAssetDestFolder("Sound") end},
		{ id = "frequency", editor = "number", min = 0},
	},
	frequency = 100,
	EditorView = Untranslated("<GedColor><file><if(not(file))>[No name]</if> <color 0 128 0><frequency></color> <SampleInformation>"),
	EditorName = "Sample",
	StoreAsTable = true,
}

DefineClass.Sample = {
	__parents = {"SoundFile"},
	StoreAsTable = false,
}

function SoundFile:GetFolder()
	return sample_base_folder
end

function SoundFile:GetFileFilter()
	local file_ext = self:GetFileExt()
	return string.format("Sample File(*.%s)|*.%s", file_ext, file_ext)
end

function SoundFile:GetFileExt()
	return "wav"
end

function SoundFile:GetStripPattern()
	local file_ext = self:GetFileExt()
	return "(.*)." .. file_ext .. "%s*$"
end

function SoundFile:GetSampleData()
	local info = SoundEditorSampleInfoCache[self:Getpath()]
	if not info then
		info = GetSoundInformation(self:Getpath())
		SoundEditorSampleInfoCache[self:Getpath()] = info
	end
	return info
end

function SoundFile:SampleInformation()
	local info = self:GetSampleData()
	if not info then return "" end
	local channels = info.channels > 1 and "stereo" or "mono"
	local bits = info.bits_per_sample
	local duration = info.duration or 0
	return string.format("<color 240 0 0>%s</color> <color 75 105 198>%s</color> %0.3fs", channels, bits, duration / 1000.0)
end

function SoundFile:GetBitsPerSample()
	local info = SoundEditorSampleInfoCache[self:Getpath()]
	if not info then
		info = GetSoundInformation(self:Getpath())
		SoundEditorSampleInfoCache[self:Getpath()] = info
	end
	return info.bits_per_sample
end

function SoundFile:GedColor()
	if not io.exists(self:Getpath()) then return "<color 240 0 0>" end
	
	if SoundBankPresetsPlaying[self.file] then
		return "<color 0 128 0>"
	end
	return ""
end

function SoundFile:OnEditorSetProperty(prop_id, old_value, ged)
	if rawget(_G, "SoundStatsInstance") then
		local sound = ged:GetParentOfKind("SelectedObject", "SoundPreset")
		LoadSoundBank(sound)
		ObjModified(ged:ResolveObj("root"))
		ObjModified(sound)
	end
end

function SoundFile:Setpath(path)
	local normalized = string.match(path, self:GetStripPattern())
	if normalized then
		self.file = normalized
	else
		print("Invalid sound path - must be in project's Sounds/ folder")
	end
end

function SoundFile:Getpath()
	return self.file .. "." .. self:GetFileExt()
end

function SoundFile:OnEditorNew(preset, ged, is_paste)
	preset:OverrideSampleFuncs(self)
	local is_mod_item = TryGetModDefFromObj(preset)
	if not is_paste and not is_mod_item then
		CreateRealTimeThread(function()
			local os_path = self:GetFolder()
			if type(os_path) == "table" then
				os_path = os_path[1][1]
			end
			os_path = ConvertToOSPath(os_path .. "/")
			local path_list = ged:WaitBrowseDialog(os_path, self:GetFileFilter(), false, true)
			if path_list and #path_list > 0 then
				local current_index = (table.find(preset, self) or -1) + 1
				for i = #path_list, 2, -1 do
					local path = path_list[i]
					local next_sample = SoundFile:new({})
					next_sample:Setpath(ConvertFromOSPath(path, "Sounds/"))
					table.insert(preset, current_index, next_sample)
				end
				self:Setpath(ConvertFromOSPath(path_list[1], "Sounds/"))
				SuspendObjModified("NewSample")
				ObjModified(self)
				ObjModified(preset)
				ged:OnParentsModified("SelectedObject")
				ResumeObjModified("NewSample")
			end
		end)
	end
end

function LoadSoundPresetSoundBanks()
	ForEachPresetGroup(SoundPreset, function(group)
		local preset_list = Presets.SoundPreset[group]
		LoadSoundBanks(preset_list)
	end)
end

if FirstLoad then
	l_test_counter_1 = 0
	l_test_counter_2 = 0
end

function IsSoundEditorOpened()
	if not rawget(_G, "GedConnections") then return false end
	for key, conn in pairs(GedConnections) do
		if conn.app_template == SoundPreset.GedEditor then
			return true
		end
	end
	return false
end

function IsSoundTypeEditorOpened()
	if not rawget(_G, "GedConnections") then return false end
	for key, conn in pairs(GedConnections) do
		if conn.app_template == SoundTypePreset.GedEditor then
			return true
		end
	end
	return false
end

----

if FirstLoad then
	SoundMuteReasons = {}
	SoundUnmuteReasons = {}
end

function UpdateMuteSound()
	local mute_force, unmute_force = 0, 0
	for reason, force in pairs(SoundMuteReasons) do
		mute_force = Max(mute_force, force)
		--print("Mute", ValueToStr(reason), force)
	end
	for reason, force in pairs(SoundUnmuteReasons) do
		unmute_force = Max(unmute_force, force)
		--print("Unmute", ValueToStr(reason), force)
	end
	--print("Mute:", mute_force, "Unmute:", unmute_force)
	SetMute(mute_force > unmute_force)
end

local function DoSetMuteSoundReason(reasons, reason, force)
	reason = reason or false
	force = force or 0
	reasons[reason] = force > 0 and force or nil
	UpdateMuteSound()
end
function SetMuteSoundReason(reason, force)
	return DoSetMuteSoundReason(SoundMuteReasons, reason, force or 1)
end
function ClearMuteSoundReason(reason)
	return DoSetMuteSoundReason(SoundMuteReasons, reason, false)
end

function SetUnmuteSoundReason(reason, force)
	return DoSetMuteSoundReason(SoundUnmuteReasons, reason, force or 1)
end
function ClearUnmuteSoundReason(reason)
	return DoSetMuteSoundReason(SoundUnmuteReasons, reason, false)
end

------------------- Editor -----------------

function OnMsg.GedOpened(ged_id)
	local conn = GedConnections[ged_id]
	if not conn then return end
	if conn.app_template == SoundPreset.GedEditor then
		SoundStatsInstance = SoundStatsInstance or SoundStats:new()
		conn:BindObj("stats", SoundStatsInstance)
		SoundStatsInstance:Refresh()
		SetUnmuteSoundReason("SoundEditor", 1000)
	end
	if conn.app_template == SoundTypePreset.GedEditor then
		ActiveSoundsInstance = ActiveSoundsInstance or ActiveSoundStats:new()
		conn:BindObj("active_sounds", ActiveSoundsInstance)
		ActiveSoundsInstance.ged_conn = conn
		ActiveSoundsInstance:RescanAction()
		SetUnmuteSoundReason("SoundTypeEditor", 1000)
	end
end

function OnMsg.GedClosing(ged_id)
	local conn = GedConnections[ged_id]
	if not conn then return end
	if conn.app_template == SoundPreset.GedEditor then
		ClearUnmuteSoundReason("SoundEditor")
	end
	if conn.app_template == SoundTypePreset.GedEditor then
		ClearUnmuteSoundReason("SoundTypeEditor")
	end
end

function SoundPreset:SaveAll(...)
	Preset.SaveAll(self, ...)
	LoadSoundPresetSoundBanks()
end

----------------- Stats ------------------
if FirstLoad then
	SoundStatsInstance = false
	ActiveSoundsInstance = false
end

local sound_flags = {"Playing", "Looping", "NoReverb", "Positional", "Disable", "Replace", "Pause", "Periodic", "AnimSync", "DeleteSample", "Stream", "Restricted"}
local volume_scale = const.VolumeScale
local function FlagsToStr(flags)
	return flags and table.concat(table.keys(flags, true), " | ") or ""
end
	
DefineClass.SoundInfo = {
	__parents = { "PropertyObject" },
	properties = {
		-- Stats
		{ id = "sample",  editor = "text", default = "" },
		{ id = "sound_bank",  editor = "preset_id", default = "", preset_class = "SoundPreset" },
		{ id = "sound_type",  editor = "preset_id", default = "", preset_class = "SoundTypePreset" },
		{ id = "format",  editor = "text", default = "" },
		{ id = "channels",  editor = "number", default = 1 },
		{ id = "duration",  editor = "number", default = 0, scale = "sec" },
		{ id = "state",  editor = "text", default = "" },
		{ id = "sound_flags",  editor = "prop_table", default = false, items = sound_flags, no_edit = true },
		{ id = "type_flags",  editor = "prop_table", default = false, items = sound_flags, no_edit = true },
		{ id = "SoundFlags",  editor = "text", default = "" },
		{ id = "TypeFlags",  editor = "text", default = "" },
		{ id = "obj",  editor = "object", default = false, no_edit = true }, -- "text" because "object" doesn't work for CObject
		{ id = "ObjText", name = "obj", editor = "text", default = false, buttons = { {name = "Show", func = "ShowObj" }} }, -- "text" because "object" doesn't work for CObject
		{ id = "current_pos",  editor = "point", default = false, buttons = { {name = "Show", func = "ShowCurrentPos" }} },
		{ id = "Attached", editor = "bool", default = false, help = "Is the sound attached to the object. An object can have a single attached sound to play" },
		{ id = "sound_handle", editor = "number", default = 0, no_edit = true },
		{ id = "SoundHandleHex", name = "sound_handle", editor = "text", default = "" },
		{ id = "play_idx", editor = "number", default = -1, help = "Index in the list of actively playing sounds" },
		{ id = "volume", editor = "number", default = 0, scale = volume_scale },
		{ id = "final_volume", editor = "number", default = 0, scale = volume_scale, help = "The final volume formed by the sound's volume and the type's final volume" },
		{ id = "loud_distance", editor = "number", default = 0, scale = "m" },
		{ id = "time_fade", editor = "number", default = 0 },
		{ id = "loop_start", editor = "number", default = 0, scale = "sec" },
		{ id = "loop_end", editor = "number", default = 0, scale = "sec" },
	},
	
	GetSoundFlags = function(self)
		return FlagsToStr(self.sound_flags)
	end,
	GetTypeFlags = function(self)
		return FlagsToStr(self.type_flags)
	end,
	GetAttached = function(self)
		local obj = self.obj
		if not IsValid(obj) then
			return false
		end
		local sample, sbank, stype, shandle = obj:GetSound()
		return shandle == self.sound_handle
	end,
	GetObjText = function(self)
		local obj = self.obj
		return IsValid(obj) and obj.class or ""
	end,
	GetSoundHandleHex = function(self)
		return string.format("%d (0x%X)", self.sound_handle, self.sound_handle)
	end,
	ShowCurrentPos = function(self)
		local pos = self.current_pos
		if IsValidPos(self.current_pos) then
			ShowMesh(3000, function()
				return {
					PlaceSphere(pos, guim/2),
					PlaceCircle(pos, self.loud_distance)
				}
			end)
			local eye = pos + point(0, 2*self.loud_distance, 3*self.loud_distance)
			SetCamera(eye, pos, nil, nil, nil, nil, 300)
		end
	end,
	ShowObj = function(self)
		local obj = self.obj
		if IsValid(obj) then
			local pos = obj:GetVisualPos()
			local eye = pos + point(0, self.loud_distance, 2*self.loud_distance)
			SetCamera(eye, pos, nil, nil, nil, nil, 300)
			if obj:GetRadius() == 0 then
				return
			end
			CreateRealTimeThread(function(obj)
				local highlight
				SetContourReason(obj, 1, "ShowObj")
				for i=1,20 do
					if not IsValid(obj) then
						break
					end
					highlight = not highlight
					DbgSetColor(obj, highlight and 0xffffffff or 0xff000000)
					Sleep(100)
				end
				ClearContourReason(obj, 1, "ShowObj")
				DbgSetColor(obj)
			end, obj)
		end
	end,
	GetEditorView = function(self)
		if self.sound_bank then
			return string.format("%s.%s", self.sound_type, self.sound_bank)
		end
		local text = self.sample
		if string.starts_with(text, "Sounds/", true) then
			text = text:sub(8)
		end
		return text
	end,
}

DefineClass.ActiveSoundStats = {
	__parents = { "InitDone" },
	properties = {
		-- Stats
		{ id = "AutoUpdate", name = "Auto Update (ms)", editor = "number", default = 0, category = "Stats" },
		{ id = "HideMuted", name = "Hide Muted", editor = "bool", default = false, category = "Stats" },
		{ id = "active_sounds", name = "Active Sounds", editor = "nested_list", base_class = "SoundInfo", default = false, category = "Stats", read_only = true, buttons = {{name = "Rescan", func = "RescanAction" }} },
	},
	sound_hash = false,
	ged_conn = false,
	auto_update = 0,
	auto_update_thread = false,
}

function ActiveSoundStats:Done()
	DeleteThread(self.auto_update_thread)
end

function ActiveSoundStats:SetHideMuted(value)
	self.HideMuted = value
	self:RescanAction()
end

function ActiveSoundStats:IsShown()
	local ged_conn = self.ged_conn
	local active_sounds = table.get(ged_conn, "bound_objects", "active_sounds")
	return active_sounds == self and ged_conn:IsConnected()
end

function ActiveSoundStats:SetAutoUpdate(auto_update)
	self.auto_update = auto_update
	DeleteThread(self.auto_update_thread)
	if auto_update <= 0 then
		return
	end
	self.auto_update_thread = CreateRealTimeThread(function()
		while true do
			Sleep(auto_update)
			if self:IsShown() then
				self:RescanAction()
			end
		end
	end)
end

function ActiveSoundStats:GetAutoUpdate()
	return self.auto_update
end

function ActiveSoundStats:RescanAction()
	local list = GetActiveSounds()
	table.sort(list, function(s1, s2)
		return s1.sample < s2.sample or s1.sample == s2.sample and s1.sound_handle < s2.sound_handle
	end)
	local active_sounds = self.active_sounds or {}
	self.active_sounds = active_sounds
	local sound_hash = self.sound_hash or {}
	self.sound_hash = sound_hash
	local hide_muted = self.HideMuted
	local k = 1
	for i, info in ipairs(list) do
		if not hide_muted or info.final_volume > 0 then
			local hash = table.hash(info, nil, 1)
			if not active_sounds[k] or sound_hash[k] ~= hash then
				active_sounds[k] = SoundInfo:new(info)
				sound_hash[k] = hash
				k = k + 1
			end
		end
	end
	if #active_sounds ~= k then
		table.iclear(active_sounds, k + 1)
	end
	ObjModified(self)
end

DefineClass.SoundStats = {
	__parents = { "PropertyObject" },
	properties = {
		-- Stats
		{ id = "total_sounds", name = "Sounds", editor = "number", default = 0, category = "Stats", read_only = true},
		{ id = "total_samples", name = "Samples", editor = "number", default = 0, category = "Stats", read_only = true},
		{ id = "total_size", name = "Total MBs", editor = "number", default = 0, scale=1024*1024, category = "Stats", read_only = true},
		{ id = "compressed_total_size", name = "Total compressed MBs", editor = "number", default = 0, scale=1024*1024, category = "Stats", read_only = true},
		{ id = "unused_samples", name = "Unused samples", editor = "number", default = 0, scale=1, category = "Stats", read_only = true, buttons = {{name = "List", func = "PrintUnused" }, {name = "Refresh", func = "RefreshAction" }}},
		{ id = "unused_total_size", name = "Total unused MBs", editor = "number", default = 0, scale=1024*1024, category = "Stats", read_only = true},
		{ id = "compressed_unused_total_size", name = "Total unused compressed MBs", editor = "number", default = 0, scale=1024*1024, category = "Stats", read_only = true},
		{ id = "unused_count", name = "Unused Banks Count", editor = "number", default = 0, buttons = {{name = "Search", func = "SearchUnusedBanks" }}, category = "Stats", read_only = true},
	},
	refresh_thread = false,
	walked_files = false,
	unused_samples_list = false,
}

function SoundStats:SearchUnusedBanks(root, name, ged)
	local st = GetPreciseTicks()
	local data_strings = {}
	for class, groups in sorted_pairs(Presets) do
		if class ~= "SoundPreset" then
			for _, group in ipairs(groups) do
				for _, preset in ipairs(group) do
					for key, value in pairs(preset) do
						if type(value) == "string" then
							data_strings[value] = true
						end
					end
				end
			end
		end
	end
	local count = 0
	local unused = {}
	for name, sound in pairs(SoundPresets) do
		sound.unused = nil
		if #sound > 0 and not data_strings[name] then
			unused[#unused + 1] = sound
		end
	end
	-- TODO: search the unused in the code, then in the maps
	self.unused_count = #unused
	for _, sound in ipairs(unused) do
		sound.unused = true
	end
	print(#unused, "unused sounds found in", GetPreciseTicks() - st, "ms")
end

function SoundStats:PrintUnused(root, name, ged)
	local txt = ""
	for _, sample in ipairs(self.unused_samples_list) do
		txt = txt .. sample .. "\n"
	end
	ged:ShowMessage("List", txt)
end

function SoundStats:Getunused_samples()
	return #(self.unused_samples_list or "")
end

function SoundStats:RefreshAction(root)
	self:Refresh()
end

function SoundStats:Refresh()
	self.refresh_thread = self.refresh_thread or CreateRealTimeThread(function()
		SoundEditorSampleInfoCache = {}

		local total_sounds, total_samples, total_size, compressed_total_size = 0, 0, 0, 0
		local walked_files = {}
		local original_sizes, compressed_sizes = {}, {}
		self.unused_samples_list = {}
		self.total_sounds = 0
		self.total_samples = 0
		self.total_size = 0
		self.compressed_total_size = 0
		self.unused_total_size = 0
		self.compressed_unused_total_size = 0
		ObjModified(self) -- hide all values

		local function compressed_sample_path(path)
			local dir, name = SplitPath(path)
			return "svnAssets/Bin/win32/" .. dir .. name .. ".opus"
		end

		ForEachPreset(SoundPreset, function(sound)
			total_sounds = total_sounds + 1
			total_samples = total_samples + #sound
			for i, sample in ipairs(sound) do
				local path = sample:Getpath()
				if not walked_files[path] then
					walked_files[path] = true
					
					local original_size = io.getsize(path) or 0
					original_sizes[path] = original_size
					if original_size > 0 then
						total_size = total_size + original_size
					end

					local compressed_path = compressed_sample_path(path)
					local compressed_size = io.getsize(compressed_path) or 0
					compressed_sizes[path] = compressed_size
					if compressed_size > 0 then
						compressed_total_size = compressed_total_size + compressed_size
					end
				end
			end
		end)
        
		self.total_sounds = total_sounds
		self.total_samples = total_samples
		self.total_size = total_size
		self.compressed_total_size = compressed_total_size
		self.walked_files = walked_files
		self.unused_samples_list = self:CalcUnusedSamples()
		local unused_total_size, compressed_unused_total_size = 0, 0
		for i, file in ipairs(self.unused_samples_list) do
			unused_total_size = unused_total_size + io.getsize(file)
			local compressed_file = compressed_sample_path(file)
			compressed_unused_total_size = compressed_unused_total_size + io.getsize(compressed_file)
		end
		self.unused_total_size = unused_total_size
		self.compressed_unused_total_size = compressed_unused_total_size
		
		local active_sounds = GetActiveSounds()
		for i, info in ipairs(active_sounds) do
			active_sounds[i] = SoundInfo:new(info)
		end
		self.active_sounds = active_sounds
		
		ObjModified(self)
		ObjModified(Presets.SoundPreset)
		self.refresh_thread = false
    end)
end


local function ListSamples(dir, type)
	dir = dir or "Sounds"
	local sample_file_ext = Platform.developer and "wav" or "opus"
	type = type or ("*." .. sample_file_ext)
	local samples = io.listfiles(dir, type, "recursive")
	local normalized = {}
	local rem_ext_pattern = "(.*)." .. sample_file_ext
	for i=1,#samples do
		local str = samples[i]
		if str then
			normalized[#normalized + 1] = str
		end
	end
	return normalized
end

function SoundStats:CalcUnusedSamples()
	local files = ListSamples("Sounds")
	local unused = {}
	local used = self.walked_files
	
	for i, file in ipairs(files) do
		if not used[file] then
			table.insert(unused, file)
		end
	end
	table.sort(unused)
	return unused
end

function SoundPreset:OnEditorSetProperty(prop_id, old_value, ged)
	LoadSoundBank(self)
	if SoundStatsInstance then
		SoundStatsInstance:Refresh()
	end
	Preset.OnEditorSetProperty(self, prop_id, old_value, ged)
end

local function ApplySoundBlacklist(replace)
	ForEachPreset(SoundPreset, function(sound)
		for j = #sound, 1, -1 do
			local sample = sound[j]
			sample.file = replace[sample.file] or sample.file
		end
	end)
end

function OnMsg.DataLoaded()
	if config.ReplaceSound and rawget(_G, "ReplaceSound") then
		ApplySoundBlacklist(ReplaceSound)
	end
	rawset(_G, "ReplaceSound", nil)
	LoadSoundPresetSoundBanks()
end

function OnMsg.DoneMap()
	PauseSounds(2)
end

function OnMsg.GameTimeStart()
	ResumeSounds(2)
end

function OnMsg.PersistPostLoad()
	ResumeSounds(2)
end

local function RegisterTestType()
	if not config.SoundTypeTest or SoundTypePresets[config.SoundTypeTest] then return end
	local preset = SoundTypePreset:new{
		options_group = "",
		positional = false,
		pause = false,
		Comment = "Used when playing sounds from the sound editor"
	}
	preset:SetGroup("Test")
	preset:SetId(config.SoundTypeTest)
	preset:PostLoad()
	g_PresetLastSavePaths[preset] = false
end

function SoundGroupsCombo()
	local items = table.icopy(config.SoundGroups)
	table.insert(items, 1, "")
	return items
end

local debug_levels = {
	{ value = 1, text = "simple", help = "listener circle + vector to playing objects" },
	{ value = 2, text = "normal", help = "simple + loud distance circle + volume visualization" },
	{ value = 3, text = "verbose", help = "normal + sound texts for all map sound" },
}

DefineClass.SoundTypePreset = {
	__parents = {"Preset"},
	properties = {
		{ id = "SaveIn", editor = false },
		{ id = "options_group", editor = "choice", items = SoundGroupsCombo, name = "Options Group", default = Platform.ged and "" or config.SoundGroups[1] },
		{ id = "channels", editor = "number", default = 1, min = 1 },
		{ id = "importance", editor = "number", default = 0, min = -128, max = 127, slider = true, help = "Used when trying to replace a playing sound with different sound type." },
		{ id = "volume", editor = "number", default = 100, min = 0, max = 300, slider = true}, -- TODO: write "help" items
		{ id = "ducking_preset", editor = "preset_id", name = "Ducking Preset", default = "NoDucking", preset_class = "DuckingParam", help = "Objects with lower ducking tier will reduce the volume of objects with higher ducking tier, when they are active. -1 tier is excluded from ducking" },
		{ id = "GroupVolume", editor = "number", name = "Group Volume", default = const.MaxVolume, scale = const.MaxVolume / 100, read_only = true, dont_save = true },
		{ id = "OptionsVolume", editor = "number", name = "Option Volume", default = const.MaxVolume, scale = const.MaxVolume / 100, read_only = true, dont_save = true },
		{ id = "FinalVolume", editor = "number", name = "Final Volume", default = const.MaxVolume, scale = const.MaxVolume / 100, read_only = true, dont_save = true },
		{ id = "fade_in", editor = "number", name = "Min Fade In (ms)", default = 0, help = "Min time to fade in the sound when it starts playing" },
		{ id = "replace", editor = "bool", default = true, help = "Replace a playing sound if no free channels are available" },
		{ id = "positional", editor = "bool", default = true, help = "Enable 3D (only for mono sounds)" },
		{ id = "reverb", editor = "bool", default = false, help = "Enable reverb effects for these sounds" },
		{ id = "enable", editor = "bool", default = true, help = "Disable all sounds from this type" },
		--{ id = "exclusive", editor = "bool", default = true, help = "Disable all other, non exclusive sounds" },
		{ id = "pause", editor = "bool", default = true, help = "Can be paused" },
		{ id = "restricted", editor = "bool", default = false, help = "Can be broadcast" },
		{ id = "loud_distance", editor = "number", default = DefaultSoundLoudDistance, min = 0, max = MaxSoundLoudDistance, slider = true, scale = "m", help = "No attenuation below that distance (in meters). In case of zero the sound group loud_distance is used." },
		{ id = "dbg_color", name = "Color", category = "Debug", editor = "color", default = 0, developer = true, help = "Used for sound debug using visuals", alpha = false },
		{ id = "DbgLevel", name = "Debug Level", category = "Debug", editor = "set", default = set(), max_items_in_set = 1, items = debug_levels, developer = true, dont_save = true, help = "Change the sound debug level." },
		{ id = "DbgFilter", name = "Use As Filter", category = "Debug", editor = "bool", default = false, developer = true, dont_save = true, help = "Set to sound debug filter." },
	},

	GlobalMap = "SoundTypePresets",
	GedEditor = "SoundTypeEditor",
	EditorMenubarName = "Sound Type Editor",
	EditorMenubar = "Editors.Audio",
	EditorIcon = "CommonAssets/UI/Icons/headphones.png",
}

function SoundTypePreset:GetDbgFilter()
	return listener.DebugType == self.id
end

function SoundTypePreset:SetDbgFilter(value)
	if value then
		listener.DebugType = self.id
		if listener.Debug == 0 then
			listener.Debug = 1
		end
	elseif listener.DebugType == self.id then
		listener.DebugType = ""
		if listener.Debug == 1 then
			listener.Debug = 0
		end
	end
end

function SoundTypePreset:GetDbgLevel()
	if listener.Debug == 0 then
		return set()
	end
	return set(listener.Debug)
end

function SoundTypePreset:SetDbgLevel(value)
	listener.Debug = next(value) or 0
end

function SoundTypePreset:GetEditorView()
	local txt = "<GetId>  <color 128 128 128><group>/<options_group></color>"
	if self.dbg_color ~= 0 then
		local r, g, b = GetRGB(self.dbg_color)
		txt = txt .. string.format(" <color %d %d %d>|</color>", r, g, b)
	end
	return Untranslated(txt)
end

function SoundTypePreset:GetFinalVolume()
	local _, final = GetTypeVolume(self.id)
	return final
end

function SoundTypePreset:GetGroupVolume()
	return GetGroupVolume(self.group)
end

function SoundTypePreset:GetOptionsVolume()
	return GetOptionsGroupVolume(self.options_group)
end

function SoundTypePreset:GetPresetSaveLocations()
	return {{ text = "Common", value = "" }}
end

function SoundTypePreset:GetSavePath()
	return config.SoundTypesPath
end

function OnMsg.ClassesBuilt()
	ReloadSoundTypes(true)
end

function SoundTypePreset:Setstereo(value)
	self.stereo = value
	if value then
		self.positional = false
		self.reverb = false
	end
end

function SoundTypePreset:Setreverb(value)
	self.reverb = value
	if value then
		self.stereo = false
	end
end

function SoundTypePreset:Setpositional(value)
	self.positional = value
	if value then
		self.stereo = false
	end
end

function ReloadSoundTypes(reload)
	if reload then
		for id, sound in pairs(SoundTypePresets) do
			DoneObject(sound)
		end
		assert(not next(SoundTypePresets))
		LoadPresets(SoundTypePreset:GetSavePath()) -- sound types come from a single file
	end
	RegisterTestType()
	ForEachPresetGroup(SoundTypePreset, function(group)
		LoadSoundTypes(Presets.SoundTypePreset[group])
	end)
	ApplySoundOptions(EngineOptions)
	ObjModified(Presets.SoundTypePreset)
end

------------------- Editor -----------------


function OnMsg.GedOpened(ged_id)
	local conn = GedConnections[ged_id]
	if conn and conn.app_template == SoundTypePreset.GedEditor then
		SoundTypeStatsInstance = SoundTypeStatsInstance or SoundTypeStats:new()
		conn:BindObj("stats", SoundTypeStatsInstance)
		SoundTypeStatsInstance:Refresh()
	end
end

function OnMsg.GedClosing(ged_id)
    local conn = GedConnections[ged_id]
	if conn.app_template == SoundTypePreset.GedEditor then
		ReloadSoundTypes(true)
	end
end

function SoundTypePreset:OnEditorSetProperty(prop_id, old_value, ged)
	if SoundTypeStatsInstance then
		SoundTypeStatsInstance:Refresh()
	end
	Preset.OnEditorSetProperty(self, prop_id, old_value, ged)
end

----------------- Stats ------------------
if FirstLoad then
	SoundTypeStatsInstance = false
end

DefineClass.SoundTypeStats = {
	__parents = { "PropertyObject" },
	properties = {
		-- Stats
		{ id = "total_channels", name = "Channels", editor = "number", default = 0, category = "Stats", read_only = true},
	},
}

function SoundTypeStats:Refresh()
	
	local total_channels = 0
	ForEachPreset(SoundTypePreset, function(sound_type) 
		total_channels = total_channels + sound_type.channels
	end)
	self.total_channels = total_channels
	ObjModified(self)
end

function SoundTypePreset:OnEditorSetProperty(obj, prop_id, old_value)
	if SoundTypeStatsInstance then
		SoundTypeStatsInstance:Refresh()
	end
end