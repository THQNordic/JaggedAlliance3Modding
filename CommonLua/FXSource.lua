local Behaviors
local BehaviorsList

MapVar("BehaviorLabels", {})
MapVar("BehaviorLabelsUpdate", {})
MapVar("BehaviorAreaUpdate", sync_set())

----

local function GatherFXSourceTags()
	local tags = {}
	Msg("GatherFXSourceTags", tags)
	ForEachPreset("FXSourcePreset", function(preset, group, tags)
		for tag in pairs(preset.Tags) do
			tags[tag] = true
		end
	end, tags)
	return table.keys(tags, true)
end

----

function FXSourceUpdate(self, game_state_changed, forced_match, forced_update)
	assert(not DisableSoundFX)
	if not IsValid(self) or not forced_update and self.update_disabled then
		return
	end
	local preset = self:GetPreset() or empty_table
	local fx_event = preset.Event
	if fx_event then
		local match = forced_match
		if match == nil then
			match = MatchGameState(self.game_states)
		end
		if not match then
			fx_event = false
		end
	end
	if fx_event and Behaviors then
		for name, set in pairs(preset.Behaviors) do
			local behavior = Behaviors[name]
			if behavior then
				local enabled = behavior:IsFXEnabled(self, preset)
				if set and not enabled or not set and enabled then
					fx_event = false
					break
				end
			end
		end
	end
	local current_fx = self.current_fx
	if fx_event == current_fx and not forced_update then
		return
	end
	if current_fx then
		PlayFX(current_fx, "end", self)
	end
	if fx_event then
		PlayFX(fx_event, "start", self)
	end
	self.current_fx = fx_event or nil
	if game_state_changed then
		if current_fx and not fx_event and preset.PlayOnce then
			self.update_disabled = true
		end
		self:OnGameStateChanged()
	end
end

----

DefineClass.FXSourceBehavior = {
	__parents = { "PropertyObject" },
	id = false,
	CreateLabel = false,
	LabelUpdateMsg = false,
	LabelUpdateDelay = 0,
	LabelUpdateDelayStep = 50,
	IsFXEnabled = return_true,
}

function FXSourceBehavior:GetEditorView()
	return Untranslated(self.id or self.class)
end

function FXSourceUpdateBehaviorLabels()
	local now = GameTime()
	local labels_to_update = BehaviorLabelsUpdate
	local sources_to_update = BehaviorAreaUpdate
	if not next(sources_to_update) then
		sources_to_update = false
	end
	local labels = BehaviorLabels
	local next_time = max_int64
	local pass_edits
	local FXSourceUpdate = FXSourceUpdate
	for _, name in ipairs(labels_to_update) do
		local def = Behaviors[name]
		local label = def and labels[name]
		if label then
			local delay = def.LabelUpdateDelay
			local time = labels_to_update[name]
			if now < time then
				if next_time < time then
					next_time = time
				end
			elseif now <= time + delay then
				if not pass_edits then
					pass_edits = true
					SuspendPassEdits("FXSource")
				end
				if delay == 0 then
					for _, source in ipairs(label) do
						FXSourceUpdate(source)
						if sources_to_update then
							sources_to_update:remove(source)
						end
					end
				else
					local step = def.LabelUpdateDelayStep
					local steps = 1 + delay / step
					local BraidRandom = BraidRandom
					local seed = xxhash(name, MapLoadRandom)
					for i, source in ipairs(label) do
						local delta
						delta, seed = BraidRandom(seed, steps)
						local time_i = time + delta * step
						if now == time_i then
							FXSourceUpdate(source)
							if sources_to_update then
								sources_to_update:remove(source)
							end
						elseif now < time_i and next_time > time_i then
							next_time = time_i
						end
					end
				end
			end
		end
	end
	if pass_edits then
		ResumePassEdits("FXSource")
	end
	return (next_time > now and next_time < max_int) and (next_time - now) or nil
end

--ErrorOnMultiCall("FXSourceUpdate")

MapGameTimeRepeat("FXSourceUpdateBehaviorLabels", nil, function()
	local sleep = FXSourceUpdateBehaviorLabels()
	WaitWakeup(sleep)
end)

function FXSourceUpdateBehaviorLabel(id)
	if not BehaviorLabels[id] then
		return
	end
	local list = BehaviorLabelsUpdate
	if not list[id] then
		list[#list + 1] = id
	end
	list[id] = GameTime()
	WakeupPeriodicRepeatThread("FXSourceUpdateBehaviorLabels")
end

function FXSourceUpdateBehaviorArea()
	local sources_to_update = BehaviorAreaUpdate
	if not next(sources_to_update) then return end
	SuspendPassEdits("FXSource")
	local FXSourceUpdate = FXSourceUpdate
	for _, source in ipairs(sources_to_update) do
		FXSourceUpdate(source)
	end
	table.clear(sources_to_update, true)
	ResumePassEdits("FXSource")
end

function FXSourceUpdateBehaviorAround(id, pos, radius)
	local def = Behaviors[id]
	local label = def and BehaviorLabels[id]
	if not label then
		return
	end
	local list = BehaviorAreaUpdate
	MapForEach(pos, radius, "FXSource", function(source, label, list)
		if label[source] then
			list:insert(source)
		end
	end, label, list)
	if not next(list) then
		return
	end
	WakeupPeriodicRepeatThread("FXSourceUpdateBehaviorArea")
end

MapGameTimeRepeat("FXSourceUpdateBehaviorArea", nil, function()
	FXSourceUpdateBehaviorArea()
	WaitWakeup()
end)

function OnMsg.ClassesBuilt()
	ClassDescendants("FXSourceBehavior", function(class, def)
		local id = def.id
		if id then
			Behaviors = table.create_set(Behaviors, id, def)
			assert(not def.LabelUpdateMsg or def.CreateLabel)
			if def.CreateLabel and def.LabelUpdateMsg then
				OnMsg[def.LabelUpdateMsg] = function()
					FXSourceUpdateBehaviorLabel(id)
				end
			end
		end
	end)
	BehaviorsList = Behaviors and table.keys(Behaviors, true)
end

local function RegisterBehaviors(source, labels, preset)
	if not Behaviors then
		return
	end
	preset = preset or source:GetPreset()
	if not preset or not preset.Event then
		return
	end
	for name, set in pairs(preset.Behaviors) do
		local behavior = Behaviors[name]
		if behavior and behavior.CreateLabel then
			labels = labels or BehaviorLabels
			local label = labels[name]
			if not label then
				labels[name] = {source, [source] = true}
			elseif not label[source] then
				label[#label + 1] = source
				label[source] = true
			end
		end
	end
end

function FXSourceRebuildLabels()
	BehaviorLabels = {}
	BehaviorLabelsUpdate = BehaviorLabelsUpdate or {}
	MapForEach("map", "FXSource", const.efMarker, RegisterBehaviors, BehaviorLabels)
end

local function UnregisterBehaviors(source, labels)
	for name, label in pairs(labels or BehaviorLabels) do
		if label[source] then
			table.remove_value(label, source)
			label[source] = nil
		end
	end
end

----

DefineClass.FXBehaviorChance = {
	__parents = { "FXSourceBehavior" },
	id = "Chance",
	CreateLabel = true,
	properties = {
		{ category = "FX: Chance", id = "EnableChance",   name = "Chance",          editor = "number", default = 100, min = 0, max = 100, scale = "%", slider = true },
		{ category = "FX: Chance", id = "ChangeInterval", name = "Change Interval", editor = "number", default = 0, min = 0, scale = function(self) return self.IntervalScale end, help = "Time needed to change the chance result." },
		{ category = "FX: Chance", id = "IntervalScale",  name = "Interval Scale",  editor = "choice", default = false, items = function() return table.keys(const.Scale, true) end },
		{ category = "FX: Chance", id = "IsGameTime",     name = "Game Time",       editor = "bool",   default = false, help = "Change interval time type. Game Time is needed for events messing with the game logic." },
	},
}

function FXBehaviorChance:IsFXEnabled(source, preset)
	local chance = preset and preset.EnableChance or 100
	if chance >= 100 then return true end
	local time = (preset.IsGameTime and GameTime() or RealTime()) / Max(1, preset.ChangeInterval or 0)
	local seed = xxhash(source.handle, time, MapLoadRandom)
	return (seed % 100) < chance
end

----

DefineClass.FXSourcePreset = {
	__parents = { "Preset" },
	properties = {
		{ category = "FX", id = "Event",          name = "FX Event",       editor = "combo",       default = false, items = function(fx) return ActionFXClassCombo(fx) end },
		{ category = "FX", id = "GameStates",     name = "Game State",     editor = "set",         default = set(), three_state = true, items = function() return GetGameStateFilter() end },
		{ category = "FX", id = "PlayOnce",       name = "Play Once",      editor = "bool",        default = false, help = "Kill the object if the FX is no more matched after changing game state", },
		{ category = "FX", id = "EditorPlay",     name = "Editor Play",    editor = "choice",      default = "force play", items = {"no change", "force play", "force stop"}, developer = true },
		{ category = "FX", id = "Entity",         name = "Editor Entity",  editor = "combo",       default = false, items = function() return GetAllEntitiesCombo() end },
		{ category = "FX", id = "Tags",           name = "Tags",           editor = "set",         default = set(), items = GatherFXSourceTags, help = "Help the game logic find this source if needed", },
		{ category = "FX", id = "Behaviors",      name = "Behaviors",      editor = "set",         default = set(), items = function() return BehaviorsList end, three_state = true,  },
		{ category = "FX", id = "ConditionText",  name = "Condition",      editor = "text",        default = "", read_only = true, no_edit = function(self) return not next(self.Behaviors) end  },
		{ category = "FX", id = "Actor",          name = "FX Actor",       editor = "combo",       default = false, items = function(fx) return ActorFXClassCombo(fx) end},
		{ category = "FX", id = "Scale",          name = "Scale",          editor = "number",      default = false },
		{ category = "FX", id = "Color",          name = "Color",          editor = "color",       default = false },
		{ category = "FX", id = "FXButtons",                               editor = "buttons",     default = false, buttons = {{ name = "Map Select", func = "ActionSelect" }} },
	},
	GlobalMap = "FXSourcePresets",
	EditorMenubarName = "FX Sources",
	EditorMenubar = "Editors.Art",
	EditorIcon = "CommonAssets/UI/Icons/atoms electron physic.png",
}

function FXSourcePreset:GetConditionText()
	local texts = {}
	for name, set in pairs(self.Behaviors) do
		if set then
			texts[#texts + 1] = name
		else
			texts[#texts + 1] = "not " .. name
		end
	end
	return table.concat(texts, " and ")
end

function FXSourcePreset:ActionSelect()
	if GetMap() == "" then
		return
	end
	editor.ClearSel()
	editor.AddToSel(MapGet("map", "FXSource", const.efMarker, function(obj, id)
		return obj.FxPreset == id
	end, self.id))
end

function FXSourcePreset:OnEditorSetProperty(prop_id)
	if GetMap() == "" then
		return
	end
	local prop = self:GetPropertyMetadata(prop_id)
	if not prop or prop.category ~= "FX" then
		return
	end
	MapForEach("map", "FXSource", const.efMarker, function(obj, self)
		if obj.FxPreset == self.id then
			obj:SetPreset(self)
		end
	end, self)
end

function FXSourcePreset:GetProperties()
	local orig_props = Preset.GetProperties(self)
	local props = orig_props
	if Behaviors then
		for name, set in pairs(self.Behaviors) do
			local classdef = Behaviors[name]
			local propsi = classdef and classdef.properties
			if propsi and #propsi > 0 then
				if props == orig_props then
					props = table.icopy(props)
				end
				props = table.iappend(props, propsi)
			end
		end
	end
	return props
end

DefineClass("FXSourceAutoResolve")

DefineClass.FXSource = {
	__parents = { "Object", "FXObject", "EditorEntityObject", "EditorCallbackObject", "EditorTextObject", "FXSourceAutoResolve" },
	flags = { efMarker = true, efWalkable = false, efCollision = false, efApplyToGrids = false },
	editor_text_offset = point(0, 0, -guim),
	editor_text_style = "FXSourceText",
	editor_entity = "ParticlePlaceholder",
	entity = "InvisibleObject",
	
	properties = {
		{ category = "FX Source", id = "FxPreset", name = "FX Preset", editor = "preset_id", default = false, preset_class = "FXSourcePreset", buttons = {{ name = "Start", func = "ActionStart" }, { name = "End", func = "ActionEnd" }} },
		{ category = "FX Source", id = "Playing",  name = "Playing",   editor = "bool",      default = false, dont_save = true, read_only = true },
	},
	
	current_fx = false,
	update_disabled = false,
	game_states = false,
	
	prefab_no_fade_clamp = true,
}

function FXSource:GetPlaying()
	return not not self.current_fx
end

function FXSource:EditorGetText()
	return (self.FxPreset or "") ~= "" and self.FxPreset or self.class
end

function FXSource:GetEditorLabel()
	local label = self.class
	if (self.FxPreset or "") ~= "" then
		label = label .. " (" .. self.FxPreset .. ")"
	end
	return label
end	

function FXSource:GetError()
	if not self.FxPreset then
		return "FX source has no FX preset assigned."
	end
end

function FXSource:GameInit()
	if ChangingMap then
		return -- sound FX are disabled during map changing
	end
	FXSourceUpdate(self)
end

FXSourceAutoResolve.EditorExit = FXSourceUpdate

function FXSourceAutoResolve:EditorEnter()
	CreateRealTimeThread(function()
		WaitChangeMapDone()
		if GetMap() == "" then
			return
		end
		local match
		if IsEditorActive() then
			local preset = self:GetPreset() or empty_table
			local editor_play = preset.EditorPlay
			if editor_play == "force play" then
				match = true
			elseif editor_play == "force stop" then
				match = false
			end
		end
		FXSourceUpdate(self, nil, match)
	end)
end

function FXSourceAutoResolve:OnEditorSetProperty(prop_id)
	if prop_id == "FxPreset" then
		FXSourceUpdate(self, nil, self:GetPlaying(), true)
		self:EditorTextUpdate()
	end
end

MapVar("FXSourceStates", false)
MapVar("FXSourceUpdateThread", false)

function FXSource:SetGameStates(states)
	states = states or false
	local prev_states = self.game_states
	if prev_states == states then
		return
	end
	local counters = FXSourceStates or {}
	FXSourceStates = counters
	for state in pairs(states) do
		counters[state] = (counters[state] or 0) + 1
	end
	for state in pairs(prev_states) do
		local count = counters[state] or 0
		assert(count > 0)
		if count > 1 then
			counters[state] = count - 1
		else
			counters[state] = nil
		end
	end
	self.game_states = states or nil
end

function FXSource:OnGameStateChanged()
end

function FXSource:SetFxPreset(id)
	if (id or "") == "" then
		self.FxPreset = nil
		self:SetPreset()
		return
	end
	self.FxPreset = id
	self:SetPreset(FXSourcePresets[id])
end

function FXSource:SetPreset(preset)
	UnregisterBehaviors(self)
	
	if not preset then
		self:SetGameStates(false)
		self:ChangeEntity(FXSource.entity)
		self.fx_actor_class = nil
		self:SetState("idle")
		self:SetScale(100)
		self:SetColorModifier(const.clrNoModifier)
		FXSourceUpdate(self, nil, false)
		return
	end
	
	RegisterBehaviors(self, nil, preset)
	self:SetGameStates(preset.GameStates)
	if preset.Entity then
		self.editor_entity = preset.Entity
		if IsEditorActive() then
			self:ChangeEntity(preset.Entity)
		end
	end
	if preset.Actor then
		self.fx_actor_class = preset.Actor
	end
	if preset.State then
		self:SetState(preset.State)
	end
	if preset.Scale then
		self:SetScale(preset.Scale)
	end
	if preset.Color then
		self:SetColorModifier(preset.Color)
	end
	if self.current_fx then
		FXSourceUpdate(self, nil, true)
	end
end

function FXSource:GetPreset()
	return FXSourcePresets[self.FxPreset]
end

function FXSource:Done()
	self:SetGameStates(false) -- unregister from FXSourceStates
	FXSourceUpdate(self, nil, false)
	UnregisterBehaviors(self)
end



function FXSource:ActionStart()
	FXSourceUpdate(self, nil, true, true)
	ObjModified(self)
end

function FXSource:ActionEnd()
	FXSourceUpdate(self, nil, false, true)
	ObjModified(self)
end

local function FXSourceUpdateAll(area, ...)
	SuspendPassEdits("FXSource")
	MapForEach(area, "FXSource", const.efMarker, FXSourceUpdate, ...)
	ResumePassEdits("FXSource")
end

function FXSourceUpdateOnGameStateChange(delay)
	if GetMap() == "" then
		return
	end
	delay = delay or GameTime() == 0 and 0 or config.MapSoundUpdateDelay or 1000
	DeleteThread(FXSourceUpdateThread)
	FXSourceUpdateThread = CreateGameTimeThread(function(delay)
		if delay <= 0 then
			FXSourceUpdateAll("map", "game_state_changed")
		else
			local boxes = GetMapBoxesCover(config.MapSoundBoxesCoverParts or 8, "MapSoundBoxesCover")
			local count = #boxes
			for i, box in ipairs(boxes) do
				FXSourceUpdateAll(box, "game_state_changed")
				Sleep((i + 1) * delay / count - i * delay / count)
			end
		end
		FXSourceUpdateThread = false
	end, delay)
end

function OnMsg.ChangeMapDone()
	FXSourceUpdateOnGameStateChange()
end

function OnMsg.GameStateChanged(changed)
	if ChangingMap or GetMap() == "" then return end
	local GameStateDefs, FXSourceStates = GameStateDefs, FXSourceStates
	if not FXSourceStates then return end
	for id in sorted_pairs(changed) do
		if GameStateDefs[id] and (FXSourceStates[id] or 0) > 0 then -- if a game state is changed, update sound sources
			FXSourceUpdateOnGameStateChange()
			break
		end
	end
end

if Platform.developer then

local function ReplaceWithSources(objs, fx_src_preset)
	if #(objs or "") == 0 then
		return 0
	end
	XEditorUndo:BeginOp{ objects = objs, name = "ReplaceWithFXSource" }
	editor.ClearSel()
	local sources = {}
	for _, obj in ipairs(objs) do
		local pos, axis, angle, scale, coll = obj:GetPos(), obj:GetAxis(), obj:GetAngle(), obj:GetScale(), obj:GetCollectionIndex()
		DoneObject(obj)
		local src = PlaceObject("FXSource")
		src:SetGameFlags(const.gofPermanent)
		src:SetAxisAngle(axis, angle)
		src:SetScale(scale)
		src:SetPos(pos)
		src:SetCollectionIndex(coll)
		src:SetFxPreset(fx_src_preset)
		sources[#sources + 1] = src
	end
	Msg("EditorCallback", "EditorCallbackPlace", sources)
	editor.AddToSel(sources)
	XEditorUndo:EndOp(sources)
	return #sources
end

function ReplaceMapSounds(snd_name, fx_src_preset)
	local objs = MapGet("map", "SoundSource", function(obj)
		for _, entry in ipairs(obj.Sounds) do
			if entry.Sound == snd_name then
				return true
			end
		end
	end)
	local count = ReplaceWithSources(objs, fx_src_preset)
	print(count, "sounds replaced and selected")
end

function ReplaceMapParticles(prtcl_name, fx_src_preset)
	local objs = MapGet("map", "ParSystem", function(obj)
		return obj:GetParticlesName() == prtcl_name
	end)
	local count = ReplaceWithSources(objs, fx_src_preset)
	print(count, "particles replaced and selected")
end

end
