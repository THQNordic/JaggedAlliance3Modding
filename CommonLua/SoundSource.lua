MaxSoundOffset = 60 * 1000
MaxSoundLoudDistance = 200 * guim
DefaultSoundLoudDistance = 10 * guim

DefineClass.OneShotSoundEmitter = {
	__parents = { "Object" },
	flags = { efVisible = false, efAudible = true },
}

MapVar("AmbientSoundsEnabled", true)

DefineClass.SoundSourceSound = {
	__parents = { "ResolveByCopy" },
	properties = {
		{ id = "Sound", editor = "preset_id", default = "", preset_class = "SoundPreset" },
		{ id = "GameStatesFilter", name= "GameState", editor = "set", default = set(),
			three_state = true, items = function() return GetGameStateFilter() end,
			buttons = {{name = "Check Game States", func = "PropertyDefGameStatefSetCheck"}},
		},
	},
	EditorView = Untranslated("<Sound>"),
}

function SoundSourceSound:OnAfterEditorNew(parent, ged, is_paste)
	local sound_obj = ged.selected_object
	if sound_obj then
		local states = table.copy(sound_obj.ActivationRequiredStates or empty_table)
		self:SetProperty("GameStatesFilter", states)
	end
end

DefineClass.SoundSourceBase = {
	__parents = { "Object", "ComponentSound" },
	
	flags = { gofOnSurface = true, },
	
	properties = {
		{ category = "Sound", id = "Sounds", editor = "nested_list", default = false, base_class = "SoundSourceSound", inclusive = true, },
		{ category = "Sound", id = "FadeTime", editor = "number", default = 0 },
		{ category = "Sound", id = "LoudDistance", editor = "number", default = 0, min = 0, max = MaxSoundLoudDistance, slider = true, scale = "m", help = "No attenuation below that distance (in meters). In case of zero the sound bank loud distance is used." },
	},
	
	current_sound = false,
}

function SoundSourceBase:AddSoundsEntry(sound, remove_state, states_to_set)
	local sounds = self.Sounds or {}
	self.Sounds = sounds
	local entry = SoundSourceSound:new{ Sound = sound }
	table.insert(sounds, entry)
	local states = table.copy(states_to_set or entry.GameStatesFilter)
	if remove_state then
		states[remove_state] = nil
	end
	entry:SetProperty("GameStatesFilter", states)
end

function SoundSourceBase:MatchingSoundsAvailable()
	for _, sound in ipairs(self.Sounds or empty_table) do
		if MatchGameState(sound.GameStatesFilter) then
			return true
		end
	end
end

function SoundSourceBase:IsSoundAvailable(sound, is_editor)
	for _, sound_source in ipairs(self.Sounds) do
		if sound_source.Sound == sound and (not is_editor or MatchGameState(sound_source.GameStatesFilter)) then
			return true
		end
	end
end

function SoundSourceBase:GetAvailableSounds(ignore_editor)
	local sounds
	for _, sound in ipairs(self.Sounds or empty_table) do
		if (ignore_editor or not IsEditorActive()) and MatchGameState(sound.GameStatesFilter) then
			if not sounds then
				sounds = sound.Sound
			elseif type(sounds) == "table" then
				table.insert_unique(sounds, sound.Sound)
			elseif sounds ~= sound.Sound then
				sounds = { sounds, sound.Sound }
			end
		end
	end
	return sounds
end

function SoundSourceBase:GetAvailableSoundsList(ignore_editor)
	local sounds = self:GetAvailableSounds(ignore_editor)
	if not sounds then
		return empty_table
	end
	if type(sounds) ~= "table" then
		return { sounds }
	end
	return sounds
end

function SoundSourceBase:PickSound()
	local sounds = self:GetAvailableSounds()
	if type(sounds) ~= "table" then
		return sounds
	elseif #sounds < 2 then
		return sounds[1]
	end
	return sounds[AsyncRand(#sounds) + 1]
end

function SoundSourceBase:ReplaySound(fade_time)
	if not AmbientSoundsEnabled or not IsValid(self) then
		return
	end
	local sound = self:PickSound() or ""
	-- negative values in SetSound will lead to the SoundBank's loud_distance being used
	local loud_distance = self.LoudDistance ~= 0 and self.LoudDistance or -1
	self:SetSound(sound, 1000, fade_time or 0, loud_distance)
end

function SoundSourceBase:SetSound(sound, ...)
	if (sound or "") == "" then
		sound = nil
	end
	self.current_sound = sound
	if not sound then
		self:StopSound(3000)
		return
	end
	return Object.SetSound(self, sound, ...)
end

function SoundSourceBase:InterruptSound(fade_time)
	self.current_sound = false
	fade_time = fade_time or self.FadeTime
	self:StopSound(fade_time)
end

function SoundSourceBase:SetupSound()
	self:InterruptSound()
	self:ReplaySound(self.FadeTime)
end

function SoundSourceBase:GetEditorLabel()
	local label = self.class
	if self.Sounds and #self.Sounds > 0 then
		local sound_ids = table.map(self.Sounds, "Sound")
		label = label .. " (" .. string.trim(table.concat(sound_ids, ", "), 40, "...") .. ")"
	end
	return label
end

DefineClass("SoundSourceAutoResolve")

DefineClass.SoundSourceBaseImpl = 
{
	__parents = {"EditorTextObject", "SoundSourceBase", "StripCObjectProperties", "SoundSourceAutoResolve"},
	flags = { gofPermanent = true, efMarker = true },
	editor_text_spot = false,
	editor_text_offset = point(0, 0, 50*guic),
	editor_text_style = "SoundSourceText",
	entity = "SpotHelper",
	color_modifier = RGB(100, 100, 0),
	mesh_max_loud = false,
	mesh_min_loud = false,
	entity_scale = 250,
	prefab_no_fade_clamp = true,
	editor_interrupted = false,
}

function SoundSourceBaseImpl:EditorGetTextColor()
	return self:MatchingSoundsAvailable() and const.clrWhite or const.clrRed
end

function SoundSourceBaseImpl:EditorGetText()
	local sounds = self:GetAvailableSoundsList("ignore editor")
	if not next(sounds) then
		local mismatching = {self.class}
		for _, sound_descr in ipairs(self.Sounds) do
			local row = {}
			for name, state in pairs(sound_descr.GameStatesFilter) do
				if state ~= GameState[name] then
					table.insert(row, string.format("%s%s", state and "" or "NOT ", name))
				end
			end
			if #row > 0 then
				table.insert(mismatching, string.format("%s: %s", sound_descr.Sound, table.concat(row, ", ")))
			end
		end
		
		return table.concat(mismatching, "\n")
	else
		return table.concat(sounds, "/")
	end
end

function SoundSourceBaseImpl:Init()
	self:SetScale(self.entity_scale)
	self:SetColorModifier(self.color_modifier)
end

function SoundSourceBaseImpl:GameInit()
	self:SetupSound()
end

function SoundSourceBaseImpl:OnEditorSetProperty(prop_id, old_value, ged)
	self:SetupSound()
	self:UpdateMesh()
end

function SoundSourceBaseImpl:ResolveLoudDistance()
	local radius = self.LoudDistance
	if radius == 0 then
		local sounds = SoundPresets
		for _, sound in ipairs(self:GetAvailableSoundsList("ignore editor")) do
			local preset = sounds[sound]
			if preset then
				radius = Max(radius, preset.loud_distance)
			end
		end
	end
	return radius
end

function SoundSourceBaseImpl:GetSoundHash()
	return xxhash(table.unpack(self:GetAvailableSoundsList("ignore editor")))
end

function SoundSourceBaseImpl:UpdateMesh()
	local debug = listener and listener.Debug or 0
	local editor_selected = editor.IsSelected(self)
	local visible = editor_selected or debug > 0
	if visible then
		local radius = self:ResolveLoudDistance()
		if IsValid(self.mesh_max_loud) then
			self.mesh_max_loud:SetEnumFlags(const.efVisible)
			self.mesh_max_loud:SetScale(MulDivRound(radius, 100, MulDivRound(100*guim, self:GetScale(), 100)))
			self.mesh_max_loud:SetColorModifier( editor_selected and const.clrWhite or const.clrOrange )
		end
		if IsValid(self.mesh_min_loud) then
			self.mesh_min_loud:SetEnumFlags(const.efVisible)
			local mute_threshold = tonumber(listener.PlayThreshold) * radius
			self.mesh_min_loud:SetScale(MulDivRound(mute_threshold, 100, MulDivRound(100*guim, self:GetScale(), 100)))
			self.mesh_min_loud:SetColorModifier( editor_selected and const.clrMagenta or const.clrRed )
		end
	else
		if IsValid(self.mesh_max_loud) then
			self.mesh_max_loud:ClearEnumFlags(const.efVisible)
		end
		if IsValid(self.mesh_min_loud) then
			self.mesh_min_loud:ClearEnumFlags(const.efVisible)
		end
	end
	if IsEditorActive() then
		self:InterruptSound()
		self.editor_interrupted = true
		if editor_selected then
			self.editor_interrupted = false
			self:ReplaySound(self.FadeTime)
		end
	end
end

function SoundSourceBaseImpl:IsUnderground()
	local pos = self:GetPos()
	local z_offset = self:GetObjectBBox():sizez()
	return pos:IsValidZ() and (pos:z() + z_offset < terrain.GetHeight(pos))
end

DefineClass.SoundSource = 
{
	__parents = {"EditorVisibleObject", "SoundSourceBaseImpl"},
}

function SoundSource:EditorEnter(...)
	self:SetEnumFlags(const.efVisible)
	self.mesh_max_loud = CreateCircleMesh(100*guim, const.clrWhite, point30)
	self.mesh_min_loud = CreateCircleMesh(100*guim, const.clrWhite, point30)
	self:Attach(self.mesh_max_loud)
	self:Attach(self.mesh_min_loud)
	self:UpdateMesh()
end

function SoundSource:EditorExit(...)
	DoneObject(self.mesh_max_loud)
	DoneObject(self.mesh_min_loud)
	self.mesh_max_loud = nil
	self.mesh_min_loud = nil
end

function OnMsg:EditorSelectionChanged()
	MapForEach("map", "SoundSource", SoundSource.UpdateMesh)
end

function UpdateSoundSource(obj, is_editor)
	if not obj:IsSoundAvailable(obj.current_sound, is_editor) then
		obj:SetupSound()
	end
end

MapVar("UpdateSoundSourcesThread", false)
MapVar("MapSoundBoxesCover", false)
PersistableGlobals.MapSoundBoxesCover = false

function UpdateSoundSourcesDelayed(delay)
	DeleteThread(UpdateSoundSourcesThread)
	MapSoundBoxesCover = MapSoundBoxesCover or GetMapBoxesCover(config.MapSoundBoxesCoverParts or 8, "MapSoundBoxesCover")
	UpdateSoundSourcesThread = CreateMapRealTimeThread(function(delay)
		local count = #MapSoundBoxesCover
		for i, box in ipairs(MapSoundBoxesCover) do
			MapForEach(box, "SoundSource", UpdateSoundSource, IsEditorActive())
			Sleep((i + 1) * delay / count - i * delay / count)
		end
		UpdateSoundSourcesThread = false
	end, delay or config.MapSoundUpdateDelay or 1000)
	MakeThreadPersistable(UpdateSoundSourcesThread)
end

function UpdateSoundSourcesInstant()
	MapForEach("map", "SoundSource", UpdateSoundSource, IsEditorActive())
end

OnMsg.PostNewMapLoaded = UpdateSoundSourcesInstant

function OnMsg.GameStateChanged(changed)
	if ChangingMap or GetMap() == "" then return end
	local GameStateDefs = GameStateDefs
	for id, v in sorted_pairs(changed) do
		if GameStateDefs[id] then -- if a game state is changed, update sound sources
			UpdateSoundSourcesDelayed()
			break
		end
	end
end

function SoundSourceAutoResolve:GetError()
	local errors = {}
	if self:IsUnderground() then
		table.insert(errors, "SoundSource underground - move it manually up!")
	end
	
	local invalid_sound_banks = {}
	for _, sound in ipairs(self.Sounds) do
		local prop_meta = sound:GetPropertyMetadata("Sound")
		local extra = prop_meta.extra_item
		local bank = sound.Sound
		if bank and bank ~= "" and bank ~= extra and not PresetIdPropFindInstance(sound, prop_meta, bank) then
			table.insert(invalid_sound_banks, bank)
		end
	end
	if #invalid_sound_banks > 0 then
		table.insert(errors, "Invalid sound banks: " .. table.concat(invalid_sound_banks, " "))
	end
	
	if #errors > 0 then
		return table.concat(errors, "\n")
	end
end

function SavegameFixups.RestartAmbientSounds()
	MapForEach("map", "SoundSource", function(obj)
		obj:SetupSound()
	end)
end

if Platform.developer then

-- TODO Remove when GetError starts getting called on map save and load.
local function CheckMapForErrors()
	MapForEach("map", "SoundSource", function(ss)
		local err = ss:GetError()
		if err then
			StoreErrorSource(ss, err)
		end
	end)
end

OnMsg.SaveMap = CheckMapForErrors
OnMsg.NewMapLoaded = CheckMapForErrors

end
