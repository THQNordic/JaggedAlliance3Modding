DefineClass.VoiceResponsesEventGroups = {
	__parents = { "Preset" },
}

DefineClass.VoiceResponseType = {
	__parents = { "Preset", "CampaignSpecific" },
	properties = {
		{ id = "BelongsTo", name = "Belongs to", editor = "choice", default = "Merc", items = { "All", "Merc", "Villain", "AI" }, horizontal = true, },
		{ id = "Mandatory", name = "Mandatory", editor = "bool", default = false },
		{ id = "UsesOtherLines", name = "Use other lines", editor = "preset_id", preset_class = "VoiceResponseType", item_default = "", default = ""},
		{ id = "Cooldown", name = "Cooldown", editor = "number", default = 1000 },
		{ id = "PerLineCooldown", name = "PerLineCooldown", editor = "number", default = 0, help = "This cd is applied as the name suggests to each individual line of the voice response type. The cd is only reset on map change."  },
		{ id = "Subtitled", name = "Play Subtitle", editor = "bool", default = false },
		{ id = "UseSnype", name = "Use Snype", editor = "bool", default = false },
		{ id = "SoundType", name = "Sound Type", editor = "dropdownlist", default = false,
			items = PresetsCombo("SoundTypePreset", "Voiceover"),
			help = "If set will be played as that sound type",
		},
		{ id = "SynchGroup", name = "Synchronize Among Unit Group", editor = "bool", default = false,
			help = "If set to true two units of the same group will not play the same line twice in succession." },
		{ id = "EventGroup", name = "EventGroup", editor = "combo", default = false, items = function() return PresetGroupCombo("VoiceResponsesEventGroups", "Default") end},
		{ id = "Suppresses", name = "Suppresses", editor = "preset_id_list", preset_class = "VoiceResponseType", item_default = "", default = {}},
		{ id = "SuppressAll", name = "SuppressAll", editor = "bool", default = false},
		{ id = "ChanceToPlay", name = "Chance to Play", editor = "number", default = 100, min = 0, max = 100 },
		{ id = "OncePerTurn", name = "Once per turn", editor = "bool", default = false },
		{ id = "OncePerCombat", name = "Once per combat", editor = "bool", default = false },
		{ id = "OncePerGame", name = "Once per game", editor = "bool", default = false },
		{ id = "MinLines", name = "Minimal number of lines", editor = "number", default = 0 },
		{ id = "Liked", name = "Is it related to liked merc ", editor = "bool", default = false },
		{ id = "Disliked", name = "Is it related to disliked merc ", editor = "bool", default = false },
		{ id = "LearnToLike", name = "Is it related to learn to like merc ", editor = "bool", default = false },
		{ id = "LearnToDislike", name = "Is it related to learn to dislike merc ", editor = "bool", default = false },
		{ category = "Custom Group", id = "CustomGroup", name = "Custom Group", editor = "text", default = "", help = "This group name will search for other vr's with the same group and play only the one that has a true play condition. (if not empty, the cond property will be shown)", },
		{ category = "Custom Group", id = "PlayConditions", name = "Play Conditions", 
			editor = "nested_list", default = false, base_class = "Condition", inclusive = true, no_edit = function(self) return self.CustomGroup == ""  end },
	},
	EditorIcon = "CommonAssets/UI/Icons/announcement bullhorn marketing megaphone speaker.png",
	EditorMenubarName = "Voice response types",
	EditorMenubar = "Characters",
	EditorView = Untranslated("<Color><id><ColorClose> <color 75 105 198><BelongsTo></color><color 0 128 0><opt(u(Comment),' ','')><color 128 128 128><opt(u(save_in),' - ','')>"),
	HasSortKey = true,
	GlobalMap = "VoiceResponseTypes",
	Documentation = "Creates a new voice response type that could be defined for a Unit Voice Responses preset.",
}

if config.Mods then 
DefineModItemPreset("VoiceResponseType", { EditorName = "Voice response type", EditorSubmenu = "Unit" })
end

local l_VoiceResponsePropsCache = {}

local function update_voice_responses()
	ForEachPreset("VoiceResponse", function(preset) 
		l_VoiceResponsePropsCache[preset] = false -- invalidate property cache for VoiceResponse
		ObjModified(preset) -- update in Ged if Voice Response editor is open
	end)
end

VoiceResponseType.OnEditorNew = update_voice_responses
VoiceResponseType.OnEditorDelete = update_voice_responses

OnMsg.DataLoaded = update_voice_responses

function VoiceResponseType:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Id" then
		ForEachPreset("VoiceResponse", function(preset)
			local old = rawget(preset, old_value)
			rawset(preset, self.id, old)
			preset[old_value] = nil
			ObjModified(preset)
		end)
		return
	end
	update_voice_responses()
end

function VoiceResponseType:GetColor()      return self.Mandatory and "<color 188 168 70>" or "" end
function VoiceResponseType:GetColorClose() return self.Mandatory and "</color>"           or "" end

function VoiceResponseType:GetError()
	if self.SuppressAll and  not (self.Subtitled or self.UseSnype) then
		return "VoiceResponseType of type SurpressAll is not Subtitled or Snype"
	end
end

function GetVoiceResponseCombo(effect, target)
	local enabled = { ["All"] = true } -- see VoiceResponseType.BelongsTo property
	if target == "any merc" or target == "player mercs on map" then
		enabled.Merc = true
	elseif target == "any" or target == "current unit" then
		enabled.Merc = true
		enabled.Villain = true
		enabled.AI = true
	else
		local unit_data = UnitDataDefs[target]
		if unit_data then
			enabled.Merc = IsMerc(unit_data)
			enabled.Villain = unit_data.villain
		end
	end
	
	local ids = {}
	ForEachPreset("VoiceResponseType", function(preset)
		if enabled[preset.BelongsTo] then
			ids[#ids + 1] = preset.id
		end
	end)
	return ids
end

----- VoiceResponse preset
DefineClass.VoiceResponse = {
	__parents = { "Preset" },
	properties = {
		{ category = "Preset", id = "InheritFrom", editor = "preset_id", preset_class = "VoiceResponse", default = "" },
		{ category = "Preset", id = "Id", editor = "combo", default = "", 
		items = function() 
			local ids ={}
			for k,unit in pairs(UnitDataDefs) do  
				ids[#ids+1] = unit.id
			end
			return ids
		end,
		validate = function(self, value)
			local groups = Presets[self.PresetClass or self.class]
			local presets = groups and groups[self.group]
			local with_same_id = presets and presets[value]
			if with_same_id and with_same_id ~= self and with_same_id:GetSaveFolder() == self:GetSaveFolder() then
				return "A preset with this Id already exists in this group (for the same location)"
			end
		end
		},
		-- plus dynamic properties - a list of phrases for each VoiceResponseType preset
	},
	
	EditorIcon = "CommonAssets/UI/Icons/announcement bullhorn marketing megaphone speaker.png",
	EditorMenubarName = "Voice responses",
	EditorMenubar = "Characters",
	EditorShortcut = "Ctrl-Alt-V",
	EditorView = Untranslated("<id> <color 75 105 198><Stats><color 0 128 0><opt(u(Comment),' ','')><color 128 128 128><opt(u(save_in),' - ','')>"),
	GlobalMap = "VoiceResponses",
	Documentation = "Creates a new voice responses preset that contains all texts related to an ID of Unit preset.",
	
	SingleFile = false,
	
	-- these are global (updated in the class table)
	conversation_line_cache = false,
	banter_line_cache = false,
}

if config.Mods then 
DefineModItemPreset("VoiceResponse", { EditorName = "Unit voice responses", EditorSubmenu = "Unit" })
end

function VoiceResponse:GetProperties()
	if not l_VoiceResponsePropsCache[self] then
		l_VoiceResponsePropsCache[self] = table.copy(self.properties)
		ForEachPreset("VoiceResponseType", function(preset)
			local comment = ""
			if preset.Comment ~= "" then
				comment = " - " .. preset.Comment
			end
			
			local shouldSkip = function(self)
				local unitdef = UnitDataDefs[self.id]
				if preset.Liked or preset.Disliked or preset.LearnToLike or preset.LearnToDislike then
					local merc = self.id
					local like_table = empty_table
					local note = "None"
					local response_index = tonumber(preset.id:sub(-1))
					
					if preset.Liked then
						like_table = unitdef:GetProperty("Likes")
					elseif preset.Disliked then
						like_table = unitdef:GetProperty("Dislikes")
					elseif preset.LearnToLike then
						like_table = unitdef:GetProperty("LearnToLike")
					elseif preset.LearnToDislike then
						like_table = unitdef:GetProperty("LearnToDislike")
					end
					
					if #like_table < response_index then
						return true
					end
				end
				
				-- Quirks check.
				if preset.group == "Quirks" then
					if table.find(unitdef:GetProperty("StartingPerks"), preset.id) then
						return false
					end
					
					return true
				end
				
				return false
			end
			
			local name_and_comment = function(self, meta, parent)
				local comment = preset.id
				if preset.Comment ~= "" then
					comment = comment .. " - " .. preset.Comment		
					local unitdef = UnitDataDefs[self.id]
					if preset.Liked or preset.Disliked or preset.LearnToLike or preset.LearnToDislike then
						local like_index = tonumber(preset.id:sub(-1))
						local like_table = empty_table
						local note = "None"
						
						if preset.Liked then
							like_table = unitdef:GetProperty("Likes")
						elseif preset.Disliked then
							like_table = unitdef:GetProperty("Dislikes")
						elseif preset.LearnToLike then
							like_table = unitdef:GetProperty("LearnToLike")
						elseif preset.LearnToDislike then
							like_table = unitdef:GetProperty("LearnToDislike")
						end
						if #like_table >= like_index then
							note = like_table[like_index]
						end

						comment = comment .. " " .. note .. "."
						return comment
					elseif preset.id == "AnimalFound" and table.find(unitdef and unitdef:GetProperty("StartingPerks"), preset.id) then
						comment = comment .. " This character is zoophobic."
					end
					
					if preset.UsesOtherLines and preset.UsesOtherLines ~= "" then
						comment = comment .. " Uses " .. preset.UsesOtherLines .. " if blank."
					end
				end
				--print(comment)
				return comment
			end
			
			table.insert(l_VoiceResponsePropsCache[self], {
				id = preset.id,
				name = name_and_comment,
				category = function(self, meta, parent)
					local data = self:GetProperty(meta.id)
					return (not data or #data == 0) and (preset.Mandatory or preset.MinLines > 0) and "Unwritten" or preset.group
				end,
				editor = "T_list",
				default = false,
				buttons = { { name = "Edit props", func = function() preset:OpenEditor() end, is_hidden = function(obj) return IsKindOf(obj, "ModItem") end,} },
				per_item_buttons = { {name = "Test Voice Response", icon = "CommonAssets/UI/Ged/play.tga", func = "TestVoiceResponse"} },
				no_edit = function(self)
					local unitdata = UnitDataDefs[self.id]
					local is_merc = unitdata and unitdata.IsMercenary
					local is_villain = unitdata and unitdata:GetProperty("villain")
					return is_merc and preset.BelongsTo == "AI" or
					   not is_merc and preset.BelongsTo == "Merc" or
					   not is_villain and preset.BelongsTo == "Villain" or
					   shouldSkip
				end,
				context = function(self, meta, parent)
					local context_string = 
						"VoiceResponse " ..
						name_and_comment(self, meta, parent) ..
						(preset.PlayConditions and " share_id:true" or "")
					return VoicedContextFromField("id", context_string)(parent, meta, parent)
				end,
				help = function(self)
					return string.format("Cooldown: %d\nSubtitled: %s\nUse Snype: %s\nSynch group: %s\nChange to play: %d\nOncePerTurn: %s\nOnce per combat: %s",
						preset.Cooldown, tostring(preset.Subtitled), tostring(preset.UseSnype), tostring(preset.SynchGroup), preset.ChanceToPlay, tostring(preset.OncePerTurn) , tostring(preset.OncePerCombat))
				end
			})
			
			::continue::
		end)
	end
	
	-- don't bother with the read-only properties when saving (saves a lot of time)
	if self:EditorData().saving then
		return l_VoiceResponsePropsCache[self]
	end
	
	local props = table.copy(l_VoiceResponsePropsCache[self])
	self:AddConversationRefs(props)
	self:AddBanterRefs(props)
	return props
end

function VoiceResponse:TestVoiceResponse(root, prop_id, socket, param, idx)
	Sleep(1000)
	PlaySound(GetVoiceFilename(self[prop_id][idx]), "Voiceover")
end

function VoiceResponse:OnPreSave(user_requested)
	self:EditorData().saving = true
end

function VoiceResponse:OnPostSave(user_requested)
	self:EditorData().saving = nil
end

function VoiceResponse:BuildConversationLinesCache()
	local cache = {}
	ForEachPreset("Conversation", function(conv)
		conv:ForEachSubObject("ConversationLine", function(line, parents)
			local for_character = cache[line.Character] or {}
			for_character[#for_character + 1] = line
			for_character[line] = { conv = conv, parents = table.copy(parents) }
			cache[line.Character] = for_character
		end)
	end)
	VoiceResponse.conversation_line_cache = cache
end

function VoiceResponse:BuildBanterLinesCache()
	local cache = {}
	ForEachPreset("BanterDef", function(banter)
		for _, line in ipairs(banter.Lines) do
			local for_character = cache[line.Character] or {}
			if not for_character[banter] then
				for_character[#for_character + 1] = line
				for_character[line] = banter
				for_character[banter] = true
				cache[line.Character] = for_character
			end
		end
	end)
	VoiceResponse.banter_line_cache = cache
end

function OnMsg.ObjModified(obj)
	if obj == Presets.Conversation then
		VoiceResponse.conversation_line_cache = false
	elseif obj == Presets.BanterDef then
		VoiceResponse.banter_line_cache = false
	end
end

function VoiceResponse:AddConversationRefs(props)
	if not VoiceResponse.conversation_line_cache then
		VoiceResponse:BuildConversationLinesCache()
	end
	
	local cache = VoiceResponse.conversation_line_cache[self.id]
	for i, line in ipairs(cache) do
		local data = cache[line]
		local conv, parents = data.conv, data.parents
		local conv_category = "Conversation - Interjections"
		if conv.group == "Test Merc Hire" then
			conv_category = "Conversation - Hire"
		end
		table.insert(props, {
			id = "convref" .. i,
			name = ComposePhraseId(parents),
			category = conv_category,
			buttons = { {
				name = "Open",
				func = "ConversationEditorSelect",
				param = { preset_id = conv.id, sel_path = GedParentsListToSelection(parents) },
			} },
			editor = "text",
			translate = true,
			read_only = true,
			lines = 1,
			default = line.Text,
		})
	end
end

function VoiceResponse:AddBanterRefs(props)
	if not VoiceResponse.banter_line_cache then
		VoiceResponse:BuildBanterLinesCache()
	end
	
	local cache = VoiceResponse.banter_line_cache[self.id]
	for i, line in ipairs(cache) do
		local banter = cache[line]
		local banter_category = "Banter - Map"
		if banter.group == "MercBanters" then
			banter_category = "Banter - Marker"
		end
		
		table.insert(props, {
			id = "banterref" .. i,
			name = banter.id,
			category = banter_category,
			buttons = { {
				name = "Open",
				func = function() banter:OpenEditor() end
			} },
			editor = "text",
			translate = true,
			read_only = true,
			lines = 1,
			default = line.Text,
		})
	end
end

function VoiceResponse:ResolveResponses(id)
	local lines = table.copy(self:GetProperty(id) or empty_table)
	local parent = VoiceResponses[self.InheritFrom]
	while parent do
		table.iappend(lines, parent:GetProperty(id) or empty_table)
		parent = VoiceResponses[parent.InheritFrom]
	end
	return lines
end

function VoiceResponse:GetStats()
	local responses = 0
	local hire_lines = 0
	ForEachPreset("VoiceResponseType", function(preset)
		responses = responses + #(self:ResolveResponses(preset.id) or empty_table)
		if preset.group == "Hiring" then
			hire_lines = hire_lines + #(self:ResolveResponses(preset.id) or empty_table)
		end
	end)
	
	local merc_banters = 0
	local map_banters = 0
	local interjections = 0
	for _, property in ipairs(self:GetProperties() or empty_table) do
		if property.category == "Banter - Marker" then
			merc_banters = merc_banters + 1
		elseif property.category == "Banter - Map" then
			map_banters = map_banters + 1
		elseif property.category == "Conversation - Interjections" then
			interjections = interjections + 1
		end
	end
	
	return string.format("[%d voice responses, %d banters (marker), %d banter (map), %d interjections, %d hire lines]", responses, merc_banters, map_banters, interjections,hire_lines)
end

function VoiceResponse:GetPropertyMetadata(prop_id)
	-- search in cached common properties list first (one without the fake properties for conversation/banter references)
	return table.find_value(l_VoiceResponsePropsCache[self] or empty_table, "id", prop_id) or PropertyObject.GetPropertyMetadata(self, prop_id)
end

function VoiceResponse:GetWarning()
	local err
	if not UnitDataDefs[self.id] then
		return "Please enter a valid Id before editing"
	end	
	
	if UnitDataDefs[self.id].Affiliation == "Civilian" or UnitDataDefs[self.id].Affiliation == "Other" or self.id == "CorazonGuard" then return end
	
	ForEachPreset("VoiceResponseType", function(preset)
		for _,line in ipairs(rawget(self, preset.id) or empty_table) do
			if line == "" then
				err = string.format("Empty voice line for %s", preset.id)
			end
		end

		local prop_meta = self:GetPropertyMetadata(preset.id) or empty_table
		if not prop_eval(prop_meta.no_edit, self, prop_meta) then
			local response_count = #self:ResolveResponses(preset.id)
			if preset.Mandatory and response_count == 0 then
				err = string.format("Missing mandatory voice response for %s", preset.id)
			end
			
			if response_count < preset.MinLines then
				err = string.format("Not enough voice lines for %s", preset.id)
			end
		end
	end)
	return err
end

function VoiceResponse:GetError()
	local vrCount = 0
	ForEachPreset("VoiceResponseType", function(preset)
		for _, line in ipairs(rawget(self, preset.id) or empty_table) do
			if line ~= "" then
				vrCount = vrCount + 1
			end
		end
	end)

	if vrCount == 0 then
		return "No VR's are found for this preset."
	end
end

function CreateOnEnterMapVisualMsg()
	CreateGameTimeThread(function()
		WaitSyncLoadingDone()
		Msg("OnEnterMapVisual")
		ListCallReactions(g_Units, "OnUnitEnterMapVisual")
	end)
end
