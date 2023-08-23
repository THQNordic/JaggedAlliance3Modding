function EmitterTypeCombo()
	local emitters = {""}
	for _, group in ipairs(Presets.RuleAutoPlaceSoundSources) do
		for _, rule in ipairs(group) do
			table.insert_unique(emitters, rule.EmitterType)
		end
	end
	table.sort(emitters)
	
	return emitters
end

DefineClass.AutoPlacedSoundSource = {
	__parents = {"SoundSource", "DecorGameStatesFilter"},
	
	properties = {
		{category = "Auto Sound", id = "rule_id", editor = "text", read_only = true, default = ""},
		{category = "Auto Sound", id = "emitter_type", editor = "text", read_only = true, default = ""},
		{category = "Auto Sound", id = "manual", editor = "bool", default = false},
		{id = "ActivationRequiredStates"},
	},
	
	color_modifier = RGB(255, 255, 255),
	editor_text_offset = point(0, 0, 50 * guic),
}

function AutoPlacedSoundSource:Setmanual(manual)
	self.manual = manual
	if manual then
		self.color_modifier = RGB(0, 100, 0)
		self:SetColorModifier(self.color_modifier)
		self:EditorTextUpdate(true)
	end
end

function AutoPlacedSoundSource:EditorGetText(sep, sep2)
	sep = sep or "\n	"
	sep2 = sep2 or " : "
	
	local text = SoundSource.EditorGetText(self)
	local sounds = {}
	for _, sound in ipairs(self.Sounds) do
		local sound_conds = {}
		for state, active in pairs(sound.GameStatesFilter) do
			if active then
				table.insert(sound_conds, state)
			end
		end
		if #sound_conds > 0 then
			table.insert(sounds, table.concat({sound.Sound, sep2, table.concat(sound_conds, ",")}, ""))
		else
			table.insert(sounds, sound.Sound)
		end
	end	
	local banks = table.concat(sounds, sep)
		
	return string.format("%s%s%s%s%s", self.manual and "MANUAL" or "AUTO", sep, text, sep, banks)
end

function AutoPlacedSoundSource:EditorGetTextColor()
	return MatchGameState(self.ActivationRequiredStates) and DecorGameStatesFilter.EditorGetTextColor(self) or const.clrRed
end

function AutoPlacedSoundSource:CheckUnderground()
	if self.manual then
		SoundSource.CheckUnderground(self)
	else
		if self:IsUnderground() then
			StoreErrorSource(self, string.format(
				"AutoPlacedSoundSource underground - run '%s' rule to replace them!", self.rule_id))
		end
	end
end

local manual_override = {"SetPos", "SetAngle", "SetAxis", "SetScale", "SetProperty"}
for _, func_name in ipairs(manual_override) do
	AutoPlacedSoundSource[func_name] = function(self, ...)
		local dialog = GetDialog("XPlaceObjectTool")
		local cursor_obj = dialog and dialog.cursor_object
		if not ChangingMap and self ~= cursor_obj and not GameInitThreads[self] then
			self:Setmanual(true)
		end
		SoundSource[func_name](self, ...)
	end
end

DefineClass.AutoPlacedSoundSourceWeight = {
	__parents = {"PropertyObject"},

	properties = {
		{id = "Sound", editor = "preset_id", default = "", preset_class = "SoundPreset" },
		{id = "ActivationRequiredStates",
			name = "States Required for Activation", editor = "set", default = set(),
			items = function() return GetGameStateFilter() end
		},
		{id = "Weight", name = "Weight", editor = "number", default = 10 },
	},
	
	EditorView = Untranslated("<Sound> (Weight: <Weight>)"),
}

DefineClass.ClassPattern = {
	__parents = {"PropertyObject"},
	
	properties = {
		{id = "OriginClass", name = "Origin Class", editor = "text", default = "",
			help = "Places the emmiter next to objects of this class"
		},
		{id = "OriginSpot", name = "Origin Spot", editor = "text", default = "Origin",
			help = "Places the emmiter around that spot"
		},
		{id = "OriginOffsetMethod", name = "Origin Offset Method", editor = "dropdownlist", default = "Offset",
			items = {"Offset", "Radius"}, help = "Whether to use offset above the spot or sphere around the spot",
		},
		{id = "OriginOffset", name = "Origin Offset", editor = "number", default = 0, scale = "m",
			no_edit = function(self) return self.OriginOffsetMethod ~= "Offset" end,
			help = "Places the emmiter that high above the OriginSpot",
		},
		{id = "OriginRadius", name = "Origin Radius", editor = "number", default = 0,
			no_edit = function(self) return self.OriginOffsetMethod ~= "Radius" end,
			help = "Places the emmiter in the semi-sphere around OriginSpot"
		},
	},
}

function ClassPattern:GetEditorView()
	if self.OriginOffsetMethod == "Offset" then
		return Untranslated("<OriginClass>: <OriginSpot>(<OriginOffset> above)", self)
	else
		return Untranslated("<OriginClass>: <OriginSpot>(<OriginRadius> around)", self)
	end
end

function ClassPattern:GetError()
	local classes = ExpandRuleClasses(self.OriginClass, self.OriginSpot, self.OriginOffsetMethod, self.OriginOffset, self.OriginRadius)
	if #classes == 0 then
		return string.format("No classes expanded for OriginClass='%s'!", self.OriginClass)
	end
end

DefineClass.EmitterTypeClass = {
	__parents = {"PropertyObject"},
	
	properties = {
		{id = "EmitterType", name = "Emitter Type", editor = "combo", default = "",
			items = EmitterTypeCombo
		},
	},
	
	EditorView = Untranslated("<EmitterType>"),
}

DefineClass.ClassCountAround = {
	__parents = {"PropertyObject"},
	
	properties = {
		{id = "Class", name = "Class", editor = "text", default = "" },
		{id = "Radius", name = "Radius", editor = "number", default = 10 * guim, scale = "m", slider = true, 
			min = 0, max = 100 * guim},
		{id = "CountMin", name = "Count Min", editor = "number", default = 5},
		{id = "CountMax", name = "Count Max", editor = "number", default = 10},
	},
	
	EditorView = Untranslated("<Class>:<Radius> - [<CountMin>-<CountMax>]"),
}

function ClassCountAround:GetError()
	local classes = ExpandRuleClasses(self.Class)
	local err
	if #classes == 0 then
		err = string.format("%s\nNo classes expanded for Class='%s'!", err or "", self.Class)
	end
	if self.CountMin == 0 and self.CountMax == 0 then
		err = string.format("%s\nCountMin(%d) or CountMax(%d) must be greater than zero!",
			err or "", self.CountMin, self.CountMax)
	end
	if self.CountMin > self.CountMax then
		err = string.format("%s\n[CountMin-CountMax] must be well defined interval but it's [%d-%d]!",
			err or "", self.CountMin, self.CountMax)
	end
	
	return err
end

if FirstLoad then
	s_ClassPatternExpandedClassesCache = {}
	s_APSS_RandSeed = false
end

local xxhash = xxhash

function ExpandRuleClasses(class_pattern, spot_name, spot_offset_type, spot_offset, spot_radius)
	local classes = {}
	if not class_pattern or class_pattern == "" then	
		return classes
	end
	
	local hash = xxhash(class_pattern, spot_name, spot_offset_type, spot_offset, spot_radius)
	local cached = s_ClassPatternExpandedClassesCache[hash]
	if cached then
		return cached
	end
	
	if g_Classes[class_pattern] then
		table.insert(classes, class_pattern)
		classes[class_pattern] = {spot_name = spot_name, spot_offset_type = spot_offset_type, spot_offset = spot_offset, spot_radius = spot_radius}
	else
		for class_name in pairs(g_Classes) do
			if string.match(class_name, class_pattern) then
				table.insert(classes, class_name)
				if spot_name or spot_offset_type or spot_offset or spot_radius then
					classes[class_name] = {spot_name = spot_name, spot_offset_type = spot_offset_type, spot_offset = spot_offset, spot_radius = spot_radius}
				end
			end
		end
	end
	s_ClassPatternExpandedClassesCache[hash] = classes
	
	return classes
end

local function GetMarkerDescr(marker, classes)
	if classes[marker.class] then
		return classes[marker.class]
	end
	
	for class_name, class_descr in ipairs(classes) do
		if IsKindOf(marker, class_name) then
			classes[marker.class] = class_descr
			return class_descr
		end
	end
end

local is_water = terrain.IsWater

-- VERY NAIVE - some areas may not emit sample at all
local function SampleRandomPoints(rule, samples, emitters_away, objs_away, areas, emitters, tries)
	tries = tries or 30
	
	local class_weights, total_weight = {}, 0
	for idx, entry in ipairs(rule.SoundCandidates) do
		total_weight = total_weight + entry.Weight
		class_weights[idx] = total_weight
	end
	
	local terrains
	if rule.Terrain then
		local terrains_selected = type(rule.Terrain) == "table" and rule.Terrain or {rule.Terrain}
		terrains = {}
		for _, terrain_type in ipairs(terrains_selected) do
			terrains[terrain_type] = true
		end
	end
	
	local min_dist2 = rule.MinDist * rule.MinDist
	
	local function close_to(sample_pos, samples)
		for _, sample in ipairs(samples) do
			if sample_pos:Dist2(sample:GetVisualPos()) < min_dist2 then
				return true
			end
		end
	end
	
	local function check_req(sample_pos)
		if not rule:MatchBorderRelation(sample_pos) then
			return false
		end
		
		-- check water requirements
		if rule.OnWater then
			if not is_water(sample_pos) then
				return false
			end
		elseif rule.WaterNearBy > 0 then
			if not terrain.IsWaterNearby(sample_pos, rule.WaterNearBy) then
				local dist2d2 = rule.WaterNearBy * rule.WaterNearBy
				local water_nearby = MapFindNearest(sample_pos, sample_pos, rule.WaterNearBy, "WaterObj",
					function (obj, pos)
						local closest_pt = ClampPoint(pos, obj:GetObjectBBox())
						return closest_pt:Dist2D2(pos) <= dist2d2
					end, sample_pos)
				if not water_nearby then
					return false
				end
			end
		end
		
		-- check land requirements
		if rule.OnLand then
			if is_water(sample_pos) then
				return false
			end
		elseif rule.LandNearBy > 0 then
			if not terrain.IsLandNearby(sample_pos, rule.LandNearBy) then
				return false
			end
		end
		
		-- check terrain type underneath
		if terrains then
			local terrain_preset = TerrainTextures[terrain.GetTerrainType(sample_pos)]
			if not terrains[terrain_preset.id] then
				return false
			end
		end

		-- check for required objects around
		if #(rule.ClassCountAround or empty_table) > 0 then
			local at_least_one_around_req_met
			for _, around in ipairs(rule.ClassCountAround) do
				if around.CountMin > 0 or around.CountMax > 0 then
					local classes = ExpandRuleClasses(around.Class)
					local classes_around = MapCount(sample_pos, around.Radius, classes)
					if classes_around >= around.CountMin and classes_around <= around.CountMax then
						at_least_one_around_req_met = true
						break
					end
				end
			end
			if not at_least_one_around_req_met then
				return false
			end
		end
		
		-- check for samples/emitters/objects around within min distanc
		close_to(sample_pos, objs_away)
		if close_to(sample_pos, samples) or close_to(sample_pos, emitters_away) or close_to(sample_pos, objs_away) then
			return false
		end
		
		return true
	end
	
	s_APSS_RandSeed = s_APSS_RandSeed or AsyncRand()
	local rand = BraidRandomCreate(s_APSS_RandSeed)
	
	local samples_tested = 0
	for _, area in ipairs(areas) do
		local randomized = (area.spot_offset_type == "Radius") and not area.water
		local area_tries = randomized and tries or 1		
		for try = 1, area_tries do
			local sample_pos
			if randomized then
				sample_pos = rule:GetPlacePos(rand, area.spot_pos, area.spot_radius)
			else
				sample_pos = area.spot_pos + point(0, 0, area.spot_offset)
			end
			samples_tested = samples_tested + 1
			if check_req(sample_pos) then
				local obj = PlaceObject("AutoPlacedSoundSource")
				obj:SetPos(sample_pos)
				obj.rule_id = rule.id
				obj.emitter_type = rule.EmitterType
				if rule.EmitterType and rule.EmitterType ~= "" then
					emitters[rule.EmitterType] = emitters[rule.EmitterType] or {}
					table.insert(emitters[rule.EmitterType], obj)
				end
				if #(rule.SoundCandidates or empty_table) > 0 then
					for s = 1, rule.SoundSamples do
						local slot = rand(total_weight)
						local idx = GetRandomItemByWeight(class_weights, slot)
						local entry = rule.SoundCandidates[idx]
						obj:AddSoundsEntry(entry.Sound, nil, entry.ActivationRequiredStates)
					end
				end
				table.insert(samples, obj)
				if IsEditorActive() then
					obj:EditorEnter()
				end
				break
			end
		end
	end
	
	return samples_tested
end

function IsCoast(pos, step)
	step = step or 10 * guim
	
	local x, y = pos:xy()
	local left_point = point(x - step, y)
	local right_point = point(x + step, y)
	local down_point = point(x, y + step)
	local up_point = point(x, y - step)
	
	return is_water(left_point) or is_water(right_point) or is_water(down_point) or is_water(up_point)
end

function IsBeachPoint(pos, step)
	return not is_water(pos) and IsCoast(pos, step or 10 * guim)
end

local function GetRuleClassesMarkers(rule)
	local classes, markers = {}, {}
	
	if #(rule.ClassPatterns or empty_table) > 0 then
		for _, entry in ipairs(rule.ClassPatterns) do
			local pattern = ExpandRuleClasses(entry.OriginClass, entry.OriginSpot, entry.OriginOffsetMethod, entry.OriginOffset, entry.OriginRadius)
			for k, v in pairs(pattern) do
				classes[k] = (type(v) == "table") and table.copy(v) or v
			end
		end
		MapForEach("map", classes, function(obj)
			if rule:Filter(obj) then
				markers = markers or {}
				table.insert(markers, obj)
			end
		end)
	end
	
	if rule.BeachPoints then
		local width, height = terrain.GetMapSize()
		local step = rule.BeachPointsWaterStep
		for y = step, height - step, step do
			for x = step, width - step, step do
				local pos = point(x, y)
				if IsBeachPoint(pos, step) and rule:Filter(pos) then
					markers = markers or {}
					table.insert(markers, pos)
				end
			end
		end
	end
	
	return classes, markers
end

function ProcessAutoPlacedSoundSources(rules, select_new)
	local time_total = GetPreciseTicks()
	
	PauseInfiniteLoopDetection("ProcessAutoPlacedSoundSources")
	
	rules = table.ifilter(rules, function(_, rule)
		return not rule.Regions or #rule.Regions == 0 or table.find_value(rule.Regions, mapdata.Region)
	end)
	if #rules == 0 then return end
	
	local to_delete = {}
	for _, rule in ipairs(rules) do
		if rule.DeleteOld then
			to_delete[rule.id] = true
		end
	end
	
	-- remove old auto placed sound sources and collect manual markers
	local manuals, emitters = {}, {}
	MapForEach("map", "AutoPlacedSoundSource", function(apss)
		if not apss.manual and to_delete[apss.rule_id] then
			DoneObject(apss)
		else
			table.insert(manuals, apss)
			if apss.emitter_type and apss.emitter_type ~= "" then
				emitters[apss.emitter_type] = emitters[apss.emitter_type] or {}
				table.insert(emitters[apss.emitter_type], apss)			
			end
		end
	end)
	
	local total_auto, total_manuals, total_samples_tested = 0, 0, 0
	for _, rule in ipairs(rules) do
		local time_rule = GetPreciseTicks()
		local classes, markers = GetRuleClassesMarkers(rule)
		local areas = {}
		if #classes > 0 or rule.BeachPoints then
			for _, marker in ipairs(markers) do
				if IsPoint(marker) then
					table.insert(areas, {water = true, spot_pos = marker, spot_offset = 0, spot_radius = 0})
				else
					local descr = GetMarkerDescr(marker, classes)
					local spot_index = marker:GetSpotBeginIndex(descr.spot_name)
					local spot_pos = marker:GetSpotPos(spot_index)
					table.insert(areas, {marker = marker, spot_pos = spot_pos, spot_offset_type = descr.spot_offset_type, 
						spot_offset = descr.spot_offset, spot_radius = descr.spot_radius})
				end
			end
		end
		local samples = {}
		for idx, manual in ipairs(manuals) do
			samples[idx] = manual
		end
		local samples_count = #samples
		local emitters_away = {}
		for _, emitter_away in ipairs(rule.EmittersAway) do
			local emitters_type = emitters[emitter_away.EmitterType] or empty_table
			for _, emitter in ipairs(emitters_type) do
				table.insert(emitters_away, emitter)
			end
		end
		local away_classes = ExpandRuleClasses(rule.OriginAwayClass)
		local objs_away = {}
		if #away_classes > 0 then
			MapForEach("map", away_classes, function(obj)
				table.insert(objs_away, obj)
			end)
		end
		local samples_tested = SampleRandomPoints(rule, samples, emitters_away, objs_away, areas, emitters)
		time_rule = GetPreciseTicks() - time_rule
		print(string.format("Rule %s(%.3fs): Placed %d AutoPlacedSoundSources, Manual Markers: %d, Samples tested: %d", rule.id, time_rule / 1000.0, #samples - samples_count, #manuals, samples_tested))
		total_auto = total_auto + #samples - samples_count
		total_manuals = total_manuals + #manuals
		total_samples_tested = total_samples_tested + samples_tested
		if select_new and  IsEditorActive() then
			local new_sounds = {}
			for i = samples_count + 1, #samples do
				local sample = samples[i]
				if IsKindOf(sample, "AutoPlacedSoundSource") and sample.rule_id == select_new then
					table.insert(new_sounds, samples[i])
				end
			end
			editor.AddToSel(new_sounds)
		end
	end
	
	ResumeInfiniteLoopDetection("ProcessAutoPlacedSoundSources")
	
	time_total = GetPreciseTicks() - time_total
	print(string.format("All Rules(%.3fs): Placed %d AutoPlacedSoundSources, Manual Markers: %d, Total samples tested: %d", time_total / 1000.0, total_auto, total_manuals, total_samples_tested))
end

local function GetRules(ged, obj)
	if IsKindOf(obj, "GedMultiSelectAdapter") then
		local group = obj.__objects[1].group
		for _, obj in ipairs(obj.__objects) do
			if group ~= obj.group then
				ged:ShowMessage("Error", "Selected rules are from diffrent groups - select only single group for execution!")
				return
			end
		end
		return Presets.RuleAutoPlaceSoundSources[group]
	elseif IsKindOf(obj, "RuleAutoPlaceSoundSources") then
		return Presets.RuleAutoPlaceSoundSources[obj.group]
	elseif type(obj) == "table" then
		return obj
	end
end

function RunSingleRule(ged, obj)
	local select_new = IsKindOf(obj, "RuleAutoPlaceSoundSources") and obj.id
	if select_new and IsEditorActive() then
		editor.ClearSel()
	end
	ProcessAutoPlacedSoundSources(GetRules(ged, obj), select_new)
end

local function RuleSelectedChanged(obj, selected, ged_editor)
	if not ged_editor.context or ged_editor.context.PresetClass ~= "RuleAutoPlaceSoundSources" then
		return
	end
	
	local rules = GetRules(obj)
	local selected_rules = {}
	for _, rule in ipairs(rules) do
		selected_rules[rule.id] = true
	end
	MapForEach("map", "AutoPlacedSoundSource", function(apss)
		if selected then
			if selected_rules[apss.rule_id] then
				apss:EditorEnter()
			end
		else
			apss:EditorExit()
		end
	end)
end

function OnMsg.GedClosed(ged_editor)
	if ged_editor.context.PresetClass ~= "RuleAutoPlaceSoundSources" then return end
	
	local rules = {}
	for _, group in ipairs(Presets.RuleAutoPlaceSoundSources) do
		table.iappend(rules, group)
	end	
	RuleSelectedChanged(rules, "selected", ged_editor)
end

OnMsg.GedOnEditorSelect= RuleSelectedChanged
OnMsg.GedOnEditorMultiSelect = RuleSelectedChanged
