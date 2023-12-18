local debug_popup
local skip_play_line = 1 << 0
local skip_wait_line = 1 << 1

----- Helper functions

function ConversationLineContext(field, annotation_prop)
	return function(obj, prop_meta, parent)
		local voiced_context 
		local extra_annotation = annotation_prop and obj[annotation_prop]
		if IsT(extra_annotation) then
			extra_annotation = _InternalTranslate(extra_annotation)
		end
		
		local voiced_context
		if extra_annotation then
			voiced_context = string.format("%s voice:%s", extra_annotation, obj[field])
		else
			voiced_context = string.format("voice:%s", obj[field])
		end
		
		local parent_conv = GetParentTableOfKind(obj, "Conversation")
		if parent_conv then
			voiced_context = voiced_context .. " section:" .. parent_conv.id
		end
		
		local parent_obj = GetParentTableOfKind(obj, "ConversationPhrase")
		if parent_obj and parent_obj.Keyword ~= "" then
			local keyword = parent_obj.Keyword
			if parent_obj.Keyword == "Greeting" then
				keyword = parent_obj.id
			end 
			
			voiced_context = voiced_context .. " keyword:" .. keyword
		end
		return voiced_context
	end
end

function ComposePhraseId(parents, phrase, start_at)
	local parent_ids = {}
	for i = start_at or 1, #parents do
		local parent = parents[i]
		local parent_id 
		if IsKindOfClasses(parent, "Condition", "Effect") then
			parent_id = parent.class
		elseif IsKindOfClasses(parent, "Conversation", "ConversationPhrase") then
			parent_id = parent.id
		elseif IsKindOf(parent, "ConversationInterjectionList") then
			parent_id = "Interjection"
		elseif not IsKindOf(parent, "ConversationInterjection") then
			parent_id = "?"
		end
		if parent_id then
			parent_ids[#parent_ids + 1] = parent_id
		end
	end
	if phrase and phrase.id then
		parent_ids[#parent_ids + 1] = phrase.id
	end
	return table.concat(parent_ids, ".")
end

function GetPhraseIdsCombo(conversation, skip_greetings, extra)
	local id, list = "", {}
	if type(conversation) == "string" then
		conversation = Conversations[conversation]
	end
	if conversation then
		conversation:ForEachSubObject("ConversationPhrase", function(obj, parents, key, list)
			if not (skip_greetings and obj.Keyword == "Greeting") then
				list[#list + 1] = ComposePhraseId(parents, obj, 2)
			end
		end, list)
		table.sort(list)
	end
	return table.iappend(type(extra) == "table" and extra or { extra }, list)
end

function GetConversationCharactersCombo(obj, prop_meta, validate_fn)
	if validate_fn == "validate_fn" then
		-- function for preset validation, checks whether the property value is from "items"
		return "validate_fn", function(value, obj, prop_meta)
			return value == "<default>" or UnitDataDefs[value]
		end
	end
	return table.keys2(UnitDataDefs, "sorted", "<default>")
end

function GetConversationUnit(group)
	for _, obj in ipairs(Groups[group] or empty_table) do
		if obj:IsKindOf("Unit") and not obj:IsDead() then
			return obj
		end
	end
end

function ForEachPhraseReferenceInPresets(conversation, fn)
	-- only look in presets defined in the ClassDef editor & saved in current project
	local preset_classes = {}
	ForEachPreset("ClassDef", function(preset)
		if preset:IsKindOf("PresetDef") and preset.save_in == "" then
			table.insert(preset_classes, preset.id)
		end
	end)
	
	-- look for PhraseSetEnabled objects
	for _, preset_class in ipairs(preset_classes) do
		ForEachPreset(preset_class, function(preset)
			preset:ForEachSubObject("PhraseSetEnabled", function(obj, parents)
				if obj.Conversation == conversation.id then
					fn(parents, obj, "PhraseId")
				end
			end)
		end)
	end
	
	-- look for Goto properties in ConversationsPhrase objects
	conversation:ForEachSubObject("ConversationPhrase", function(obj, parents)
		fn(parents, obj, "GoTo")
	end)
end


----- Phrase states
--
-- Phrase states are stored by phrase id in the form <Character>.<phrase_id1>. ... .<phrase_idn> (see GetPhraseId/PhraseById)
-- "Enabled" state is stored when explicitly set from by the PhraseSetEnabled effect; otherwise we return the preset's Enabled property.

GameVar("gv_PhraseStates", {})

function SetPhraseEnabledState(phrase_id, enabled)
	assert(PhraseById(phrase_id), string.format("Missing conversation phrase with id %s", phrase_id))
	local state = gv_PhraseStates[phrase_id]
	if not state then
		gv_PhraseStates[phrase_id] = { enabled = enabled and GameTime() or false }
		return
	end
	state.enabled = enabled and GameTime() or false
end

function GetPhraseEnabledTime(phrase_id)
	local state = gv_PhraseStates[phrase_id]
	if state and state.enabled ~= nil then
		return state.enabled
	end
	return PhraseById(phrase_id).Enabled and 0
end

function SetPhraseSeen(phrase_id, seen)
	local state = gv_PhraseStates[phrase_id]
	if not state then
		gv_PhraseStates[phrase_id] = { seen = seen }
		return
	end
	state.seen = seen
end

function GetPhraseSeen(phrase_id)
	local state = gv_PhraseStates[phrase_id]
	return state and state.seen
end

function PhraseById(phrase_id)
	local parents = string.split(phrase_id, "%.")
	local obj = Conversations[parents[1]]
	for i = 2, #parents do
		obj = table.find_value(obj or empty_table, "id", parents[i])
	end
	return obj
end

function GetPhraseRolloverText(phrase, conversation)
	if not phrase then return "" end
	if not phrase.ShowPhraseRollover then return "" end
	
	if phrase.PhraseRolloverText and phrase.PhraseRolloverText ~= "" then
		return T{phrase.PhraseRolloverText, conversation}
	end
	return T{phrase:GetPhraseRolloverTextAuto("game"), conversation}
end

function GetPhraseConditionsRollover(phrase, conversation)
	if not phrase then return "" end
	
	if phrase.PhraseConditionRolloverText and phrase.PhraseConditionRolloverText ~= "" then
		return T{phrase.PhraseConditionRolloverText, conversation}
	end
	if IsKindOf(phrase, "ConversationPhrase") then
		return T{phrase:GetPhraseConditionRolloverTextAuto("game"), conversation}
	end
	return ""
end

function GetPhraseConditionsFX(phrase, conversation)
	if not IsKindOf(phrase, "ConversationPhrase") then return end
	
	for _, cond in ipairs(phrase.Conditions or empty_table) do
		local fx = cond:HasMember("GetPhraseFX") and cond:GetPhraseFX()
		if #(fx or "") ~= 0 then 
			return fx
		end	
	end
	for _, eff in ipairs(phrase.Effects or empty_table) do
		local fx = eff:HasMember("GetPhraseFX") and eff:GetPhraseFX()
		if #(fx or "") ~= 0 then 
			return fx
		end	
	end
end

----- Debug popup

local state_colors = {
	{ id = "regular",     color = RGB(64, 196, 64) },
	{ id = "variant",     color = RGB(64, 64, 196) },
	{ id = "rejected",    color = RGB(196, 64, 64) },
	{ id = "disabled",    color = RGB(128, 128, 128), },
	{ id = "not_enabled", color = RGB(64, 64, 64), },
}

function CloseConversationDebugPopup()
	if debug_popup and debug_popup.window_state ~= "destroying" then
		debug_popup:Close()
		debug_popup = nil
		return true
	end
	debug_popup = nil
	return false
end

function OpenConversationDebugPopup(button, phrase_data, merc_id, conv_id)
	if CloseConversationDebugPopup() then
		return
	end
	
	local popup = XPopupList:new({
		LayoutMethod = "VList",
	}, terminal.desktop)
	-- title
	local entry = XTemplateSpawn("XComboListItem", popup.idContainer)
	entry:SetFontProps(XCombo)
	entry:SetText("Conversation: " .. conv_id or "" )
	entry:SetMinHeight(entry:GetFontHeight() + 10)

	for _, keyword_data in ipairs(phrase_data) do
		if keyword_data.keyword ~= "Back" then
			local entry = XTemplateSpawn("XComboListItem", popup.idContainer)
			entry:SetFontProps(XCombo)
			entry:SetText(keyword_data.keyword)
			for _, state in ipairs(state_colors) do
				if keyword_data[state.id] and #keyword_data[state.id] > 0 then
					entry:SetTextColor(state.color)
					break
				end
			end
			entry:SetMinHeight(entry:GetFontHeight())
			entry:SetRolloverText(GetConversationKeywordDebugInfo(keyword_data, merc_id))
			entry.OnPress = CloseConversationDebugPopup
		end
	end
	popup:SetAnchor(button.box)		
	popup:SetAnchorType("top")
	popup:SetDrawOnTop(true)
	popup:Open()
	
	debug_popup = popup
end

function GetConversationKeywordDebugInfo(keyword_data, merc_id)
	local list = {}
	for _, state in ipairs(state_colors) do
		for _, phrase_id in ipairs(keyword_data[state.id] or empty_table) do
			local phrase = PhraseById(phrase_id)
			local txt = phrase.Lines and phrase.Lines[1] and phrase.Lines[1]:HasMember("Text") and phrase.Lines[1].Text or ""
			if txt and txt ~= "" then
				txt = TDevModeGetEnglishText(txt):strip_tags()
				txt = utf8.len(txt) <= 30 and txt or (utf8.sub(txt, 1, 30) .. "...")
			end
			local color_tag = string.format("<color %d %d %d>", GetRGB(state.color))
			table.insert(list, string.format("%s%s</color>: %s", color_tag, phrase.id, txt))
			
			local context = {}
			for _, condition in ipairs(phrase.Conditions or empty_table) do
				local result, err = condition:Evaluate(merc_id, context) -- protected call
				local failed = err == nil and not result
				local ok_text = failed and "<color 196 64 64>FAIL" or "<color 64 196 64>OK"
				table.insert(list, string.format("   %s</color>: %s", ok_text, _InternalTranslate(Untranslated("<EditorView>"), condition, false)))
			end
		end
	end
	return #list > 0 and table.concat(list, "\n")
end


----- Conversation execution logic

local back_keyword_data = {
	active_phrase_id = "Back",
	keyword = "Back",
	keyword_text = T(438422501655, --[[Conversation UI]] "Back"),
	align = "Right",
	visual_state = "normal",
}
local goodbye_keyword_data = {
	active_phrase_id = "Goodbye",
	keyword = "Goodbye",
	keyword_text = T(848299426076, --[[Conversation UI]] "Goodbye"),
	align = "Right",
	visual_state = "normal",
}
local back_phrase = { Lines = empty_table, GoTo = "<back>", PlayGoToPhrase = true }
local ignore_phrases = { Back = true, More = true, Greeting = true }
local empty_phrase = { Lines = empty_table }

DefineClass.ConversationPlayer = {
	__parents = { "PropertyObject" },
	dlg = false,
	conv = false,
	merc_id = false,
	conv_id = false,
	test = false,
	seed = false,
	--sync
	current_line_idx = false,
	is_line_paused = false, --this is the pause toggled by acc settings, happens every line except last one i think, after vo;
	current_phrase_id = false, --current phrase id at the beginning of the phrase loop, ie starting loop with this should produce the same results;
	executing_current_phrase_id = false, --the phrase id in executephrase func;
	current_node_phrase_id = false, --this is mostly the same as phrase id, but with full path. but not really, because sometimes it is the next phrase id;
	net_phrase_id = false, --info coming from sync msgs, used to override locals in order to sync the state
	net_node_phrase_id = false,
	loop_thread = false, --phrase thread loops here;
	should_pause = true, --carries over acc settings of conv. controller
	sync_data = false, --keeps track of future events for the phrase currently being executed
}
if FirstLoad then
	ConversationSettingsApplied = true
end

function ConversationPlayer:RunConversationProtected()
	self.conv = Conversations[self.conv_id]
	if not ConversationSettingsApplied then
		--controller applies acc settings for conversation on both clients
		--it arrives differently so handle all cases
		WaitMsg("ConversationSettingsArrived")
	end
	local success, err = sprocall(ConversationPlayer.RunConversation, self)
	if self.dlg.can_control then
		NetSyncEvent("CloseConversationDialogEvent")
	end
end

function GetPhrase(phrase_id)
	 return not phrase_id and empty_phrase or -- shield for missing Greeting phrases
				phrase_id ~= "Back" and PhraseById(phrase_id) or back_phrase
end

function ConversationPlayer:RunConversation()
	local keyword = "Greeting"
	local node_phrase_id = self.conv_id
	local next_phrases, choice_count = self:ResolveChildPhrases(node_phrase_id)
	local has_greeting = next_phrases.Greeting and next_phrases.Greeting.active_phrase_id and next_phrases[keyword]
	if not has_greeting then
		StoreErrorSource(Conversations[self.conv_id], string.format("Conversation %s has no enabled Greeting phrases.", self.conv_id))
	end
		
	local aggregated_tag -- temporarily stores the auto-generated aggregated tag submenu of phrases to return to
	
	local function loop()
		--print("loop kw", keyword)
		local phrase_id = self.net_phrase_id or next_phrases[keyword] and next_phrases[keyword].active_phrase_id
		if not phrase_id and keyword=="Back" then
			phrase_id  = "Back"
		end
		self.net_phrase_id = false
		self.current_phrase_id = phrase_id
		local phrase = GetPhrase(phrase_id)
		local phrase_seen = phrase_id and phrase_id ~= "Back" and GetPhraseSeen(phrase_id)
		if phrase.AutoRemove then
			SetPhraseEnabledState(phrase_id, false)
		elseif phrase_id ~= "Back" then
			SetPhraseSeen(phrase_id, true)
		end
		
		-- resolve next conversation node
		node_phrase_id = phrase.id and node_phrase_id .. "." .. phrase.id or node_phrase_id
		::play_phrase::
		if self.net_node_phrase_id then
			node_phrase_id = self.net_node_phrase_id
			self.net_node_phrase_id = false
		else
			local go_to = #phrase == 0 and phrase.GoTo == "" and "<back>" or phrase.GoTo
			if go_to == "<back>" then
				node_phrase_id = node_phrase_id:match('(.*)%..*')
				aggregated_tag = nil
			elseif go_to == "<root>" then
					node_phrase_id = self.conv_id
				aggregated_tag = nil
			elseif go_to == "<end conversation>" then
				if phrase.Lines and #phrase.Lines > 0 then
					self:ExecutePhrase(phrase, phrase_seen, "end", phrase_id)
					self:ExecutePhraseEffects(phrase, phrase_id)
				end
				return "break"
			elseif go_to and go_to ~= "" then
				node_phrase_id = self.conv_id .. "." .. go_to
			end
		end
		self.current_node_phrase_id = node_phrase_id
		--print("in loop phrase id", phrase_id, "node id", node_phrase_id)
		if netInGame and self.dlg.can_control then
			NetSyncEvent("SyncConversationState", netUniqueId, phrase_id, node_phrase_id)
		end
		NetSyncEvent("AdviseConversationChoice", false)
		
		-- display phrase lines
		local has_lines = self:ExecutePhrase(phrase, phrase_seen, nil, phrase_id) 
		local goto_phrase = PhraseById(node_phrase_id)
		self:ExecutePhraseEffects(phrase, phrase_id)
		local to_stop = not has_lines and not phrase.PlayGoToPhrase and #goto_phrase ~= 0
		if phrase.PlayGoToPhrase or #goto_phrase == 0 then
			phrase = goto_phrase
			phrase_id = node_phrase_id
			if #goto_phrase == 0 then
				goto play_phrase
			else
				self:ExecutePhrase(phrase, GetPhraseSeen(phrase_id), nil, phrase_id)
				self:ExecutePhraseEffects(phrase, phrase_id)
			end
		end
		
		-- resolve next phrases and let the player choose
		local stored_node_phrase_id = node_phrase_id
		next_phrases, choice_count = self:ResolveChildPhrases(node_phrase_id)
		if to_stop and not next_phrases then
			return "break"
		end
		while choice_count == 0 and string.find(node_phrase_id, ".", 1, true) do
			-- if there are no choices, go one level up in the conversation tree
			node_phrase_id = node_phrase_id:match('(.*)%..*')
			next_phrases, choice_count = self:ResolveChildPhrases(node_phrase_id)
		end
		-- if still no choices, present the player with a Goodbye phrase (and the designers with a VME error)
		if choice_count == 0 then
			local phrases = {}
			phrases.Goodbye = goodbye_keyword_data
			phrases[#phrases + 1] = goodbye_keyword_data
			next_phrases = phrases
			
			StoreErrorSource(Conversations[self.conv_id], string.format("Conversation %s ended up without any enabled phrases at node %s.", self.conv_id, stored_node_phrase_id))
		end
		keyword, aggregated_tag = self:WaitKeywordChoice(next_phrases, aggregated_tag)
		if choice_count == 0 then return "break" end
	end
	
	while has_greeting do
		-- get next phrase and mark it as seen
		local done = false
		self.loop_thread = CreateRealTimeThread(function()
			--print("loop start")
			done = loop()
			Msg("ConvoLoopDone")
		end)
		WaitMsg("ConvoLoopDone")
		if done == "break" then
			break
		end
	end
end

function ConversationPlayer:GetState()
	return netUniqueId, self.current_phrase_id, self.executing_current_phrase_id, self.current_line_idx, self.is_line_paused, self.current_node_phrase_id
end

function ConversationPlayer:SyncState(current_phrase_id, node_phrase_id)
	--print("ConversationPlayer:SyncState", current_phrase_id, node_phrase_id)
	self.sync_data = false
	if self.current_node_phrase_id ~= node_phrase_id or self.current_phrase_id ~= current_phrase_id then
		--print("ConversationPlayer:SyncState", "sync", self.current_phrase_id, self.current_node_phrase_id)
		self.net_phrase_id = current_phrase_id
		self.net_node_phrase_id = node_phrase_id
		self.is_line_paused = false
		self.current_line_idx = false 
		DeleteThread(self.loop_thread)
		Msg("ConvoLoopDone")
	end
end

function ConversationPlayer:CheckPhraseConditions(phrase)
	local context, value = {}, true
	for _, condition in ipairs(phrase.Conditions or empty_table) do
		-- protected call - prevent conversation break when a condition crashes (consider result is true in this case)
		local result, err = condition:Evaluate(self.merc_id, context)
		if value and err == nil and not result then
			value = false
		end
	end
	return value and context
end

function ConversationPlayer:ResolveChildPhrases(node_phrase_id)
	local phrases = {}
	local node = PhraseById(node_phrase_id) -- can return a conversation or a phrase
	
	-- gather phrases for each keyword & categorize them
	local condition = {}
	local enabled_time = {}
	for _, phrase in ipairs(node) do
		local phrase_id = node_phrase_id .. "." .. phrase.id
		local enabled = GetPhraseEnabledTime(phrase_id)
		if enabled then
			if #phrase > 0 then
				local enabled_count = 0
				local child_phrases_data = self:ResolveChildPhrases(phrase_id)
				for _, child in ipairs(child_phrases_data) do
					enabled_count = enabled_count + (child.regular and #child.regular + #child.disabled + #child.variant or 0)
				end
				enabled = enabled and enabled_count > 0
			end
		end
		if enabled then
			enabled_time[phrase_id] = GetPhraseEnabledTime(phrase_id)
			condition[phrase_id] = self:CheckPhraseConditions(phrase)
		end
		
		local data = phrases[phrase.Keyword]
		if not data then
			data = {
				-- stores all phrases for diagnostic display in dev mode
				not_enabled = {},
				rejected = {}, -- conditions not met, hide phrase
				disabled = {}, -- conditions not met, disable phrase (ShowDisabled == true)
				regular = {}, -- non-variant phrases
				variant = {}, -- variant phrases
				
				active_phrase_id = false,
				keyword = phrase.Keyword,
				keyword_text = T{phrase.KeywordT, self.conv},
				tag = phrase.Tag,
				tag_text = T{phrase.TagT, self.conv},
				align = phrase.Align,
				visual_state = "dimmed", -- dimmed/normal/disabled
				branch_icon = phrase.StoryBranchIcon or "",
				phrase = phrase
			}
			phrases[phrase.Keyword] = data
			phrases[#phrases + 1] = data
		end
		
		if not enabled_time[phrase_id] then
			table.insert(data.not_enabled, phrase_id)
		elseif condition[phrase_id] then
			table.insert(phrase.VariantPhrase and data.variant or data.regular, phrase_id)
		else
			table.insert(phrase.ShowDisabled and data.disabled or data.rejected, phrase_id)
		end
	end
	
	-- resolve active_phrase_id & visual_state for each keyword
	for _, data in ipairs(phrases) do
		local keyword = data.keyword
		if #data.regular > 0 then
			table.sort(data.regular, function(a, b) return enabled_time[a] > enabled_time[b] end)
			data.active_phrase_id = data.regular[1]
			data.visual_state = GetPhraseSeen(data.active_phrase_id) and "dimmed" or "normal"
		elseif #data.variant > 0 then
			local unseen = table.ifilter(data.variant, function(idx, phrase_id) return not GetPhraseSeen(phrase_id) end)
			data.active_phrase_id = table.rand(#unseen > 0 and unseen or data.variant)
			data.visual_state = #unseen > 0 and "normal" or "dimmed"
		elseif #data.disabled > 0 then
			table.sort(data.disabled, function(a, b) return enabled_time[a] > enabled_time[b] end)
			data.active_phrase_id = data.disabled[1]
			data.visual_state = "disabled"
		end
		
		if data.active_phrase_id then
			local phrase = PhraseById(data.active_phrase_id)
			data.rollover_text = GetPhraseRolloverText(phrase, self.conv) -- conditions text and/or branch_icons rollover
		end
		if keyword == "Goodbye" then
			data.visual_state = "normal"
		end
	end
	
	-- add back phrase
	if IsKindOf(node, "ConversationPhrase") and not node.NoBackOption then
		phrases.Back = back_keyword_data
		phrases[#phrases + 1] = back_keyword_data
	end
	
	local count = 0
	for _, data in ipairs(phrases) do
		if not ignore_phrases[data.keyword] and data.active_phrase_id then
			count = count + 1
		end
	end
	return phrases, count
end

function ConversationPlayer:ExecutePhraseEffects(phrase, phrase_id)
	if self.dlg.can_control then
		NetSyncEvent("ExecutePhraseEffects", phrase_id)
	end
	WaitMsg("ExecutePhraseEffects" .. phrase_id)
end

function NetSyncEvents.ExecutePhraseEffects(phrase_id)
	local dlg = GetDialog("ConversationDialog")
	assert(dlg)
	local phrase = GetPhrase(phrase_id)
	dlg.player:_ExecutePhraseEffects(phrase, phrase_id)
	Msg("ExecutePhraseEffects" .. phrase_id)
end

function ConversationPlayer:_ExecutePhraseEffects(phrase, phrase_id)
	for _, quest_id in ipairs(phrase.GiveQuests or empty_table)do
		local quest = QuestGetState(quest_id)
		SetQuestVar(quest,"Given",true)
	end
	ExecuteEffectList(phrase.Effects, self.merc_id, phrase)
	for _, quest_id in ipairs(phrase.CompleteQuests or empty_table)do
		local quest = QuestGetState(quest_id)
		SetQuestVar(quest,"Completed",true)
	end
end

function ConversationPlayer:PickRandomIndexes(max, count)
	local idxs = {}
	count = Min(count, max)
	for i = 1, count do
		local idx, s = BraidRandom(self.seed, max - i + 1)
		idx = idx + 1
		self.seed = s
		local idx_initial = idx
		for _, idx1 in ipairs(idxs) do
			if idx >= idx1 then idx = idx + 1 end
		end
		local place
		for i, idx1 in ipairs(idxs) do
			if idx1 > idx then
				place = i
				break
			end
		end
		table.insert(idxs, place or #idxs + 1, idx)
	end
	return idxs
end

function ConversationPlayer:GatherInterjectionLines(interject_list, lines, is_radio_line, effects, phrase_seen)
	-- gather list of actors for each possible interjection
	local data = {}
	local max_actors = 0
	for _, interjection in ipairs(interject_list.Interjections or empty_table) do
		if EvalConditionList(interjection.Conditions) and
			interjection.Lines and #interjection.Lines > 0 and
			(not phrase_seen or interjection.AlwaysInterject)
		then
			-- gather all actors and check if they are present
			local actors, actor_count, can_play = {}, 0, true
			for _, line in ipairs(interjection.Lines) do
				local character = line.Character
				assert(character ~= "<default>")
				if UnitDataDefs[line.Character] and UnitDataDefs[line.Character].IsMercenary then
					if not GetConversationUnit(line.Character) then
						can_play = false
						break
					end
				elseif not is_radio_line[line] and not GetConversationUnit(line.Character) then
					can_play = false
					break
				end
				if not actors[character] then
					actors[character] = true
					actor_count = actor_count + 1
				end
			end
			
			-- add data for this interjection
			if can_play then
				data[#data + 1] = { interjection = interjection, actors = actors, actor_count = actor_count }
				max_actors = Max(max_actors, actor_count)
			end
		end
	end
	
	-- reject interjections for which another interjection with MORE actors is available
	if max_actors > 1 then
		for i = #data, 1, -1 do
			local item1 = data[i]
			if item1.actor_count < max_actors then
				for _, item2 in ipairs(data) do
					if item2.actor_count > item1.actor_count and table.is_subset(item1.actors, item2.actors) then
						table.remove(data, i)
						break
					end
				end
			end
		end
	end
	
	-- pick interjections to play at random, preserving order when playing
	local idxs = self:PickRandomIndexes(#data, interject_list.MaxPlayed)
	for i = 1, #idxs do
		local interjection = data[idxs[i]].interjection
		table.iappend(lines, interjection.Lines)
		table.iappend(effects, interjection.Effects or empty_table)
	end
end

function ConversationPlayer:GatherPhraseLines(phrase, phrase_seen, lines, is_radio_line, interjections, effects)
	local default_actor = self.conv.DefaultActor
	for i, line in ipairs(phrase.Lines) do
		local isInterjection = line:IsKindOf("ConversationInterjectionList")
		local isInterjectionLine = line.Character ~= "<default>" and (line.Character ~= default_actor and i ~= 1)

		if isInterjection or isInterjectionLine then
			local interjectionStartIdx = #lines + 1
			if isInterjectionLine and not isInterjection then
				if (GetConversationUnit(line.Character) or self.test) and (not phrase_seen or line.AlwaysInterject) then
					lines[#lines + 1] = line
				end
			else
				self:GatherInterjectionLines(line, lines, is_radio_line, effects, phrase_seen)
			end
			local range = { interjectionStartIdx, #lines }
			for i = interjectionStartIdx, #lines do -- Mark added interjections.
				interjections[i] = range
			end
		else
			assert(line.Character ~= "<default>")
			local unit = GetConversationUnit(line.Character)
			
			-- fallback when the character does not exists
			local is_radio_unit = self.test and self.test.radio and not unit
			if is_radio_unit and self.test.icon then is_radio_unit = self.test.icon end
			
			local unitFound = unit or is_radio_unit
			if not unitFound then
				assert(unitFound, string.format("Not a radio conversation but can not find the unit %s", line.Character))
				unit = true -- Dont break the conversation
			end	
			
			if (unit or self.test) and (not phrase_seen or line.Character == default_actor or line.AlwaysInterject) then
				lines[#lines + 1] = line
				is_radio_line[line] = is_radio_unit
			end
		end
	end
end

function ConversationPlayer:SetCharacterPortrait(character, side, is_radio)
	local dlg = self.dlg
	if dlg.unit_template_id == character and dlg.in_transition then return end -- Changing to the same one being transitioned to.
	dlg:DeleteThread("set-character")
	if not character then return end

	dlg:CreateThread("set-character", function()
		dlg:SetCharacter(side or "left", character, false, is_radio)
	end)
end

function ConversationPlayer:DisplayConversationLine(line, is_radio, is_not_last)	
	local dlg = self.dlg
	local unitTemplate = UnitDataDefs[line.Character]
	local name 
	if self.target_groups and table.find(self.target_groups, line.Character) then
		name = self.target_name
	end	
	if not name and unitTemplate then
		name = unitTemplate.Nick or unitTemplate.Name
	end	
	dlg.idCharacterName:SetText(name or "")
	self:SetCharacterPortrait(line.Character, "left", is_radio)
	
	dlg.idInterjectionContainer:DeleteChildren()
	dlg.idPhrase:SetTextStyle("ConversationPhrase")
	dlg.idPhrase:SetText("")

	-- This needs to happen after one layout to recover the stretching from interjections
	dlg:DeleteThread("bg_box")
	dlg:CreateThread("bg_box", function()
		dlg:SetupBackgroundSizeAndScrolling(dlg.idPhrase)
	end)
	
	local lineHasText = line.Text and line.Text ~= ""
	dlg.idDlgBackground:SetVisible(lineHasText)
	dlg.idTextContent:SetVisible(lineHasText)
	if lineHasText then
		dlg:PlayConversationLine(T{line.Text, self.conv}, "wait", line.SoundBefore, line.SoundAfter, line.SoundType)
		if is_not_last then
			dlg:DeleteThread("ShowNext")
			dlg:CreateThread("ShowNext", function()
				if dlg.waiting_voiceover then
					WaitMsg(dlg)
				end	
				dlg.idNextPhrase:SetVisible(true)
				dlg:InvalidateLayout()
			end)
		end
		return dlg.idPhrase
	end
end

function ConversationPlayer:DisplayConversationInterjection(line, interjection_group, all_lines)
	local dlg = self.dlg
	local interjectionWnd = XTemplateSpawn("ConversationDialogInterjection", dlg.idInterjectionContainer, dlg.idPhrase.context)
	
	-- The name text should be as long as the longest name in the interjection group
	local longestName = false
	for i = interjection_group[1], interjection_group[2] do
		local charName = all_lines[i].Character
		if not longestName or #charName > #longestName then
			longestName = charName
		end
	end
	if longestName then
		local unitTemplate = UnitDataDefs[longestName]
		if unitTemplate then
			interjectionWnd.idLongestInterjectionName:SetText(unitTemplate.Nick)
		end
	end

	-- First interjection in group has extra space on top.
	if line == all_lines[interjection_group[1]] then
		interjectionWnd:SetMargins(box(0, 12, 0, 0))
	end

	local unitTemplate = UnitDataDefs[line.Character]
	local name
	if self.target_groups and table.find(self.target_groups, line.Character) then
		name = self.target_name
	end	
	if not name and unitTemplate then
		name =  unitTemplate.Nick or unitTemplate.Name
	end	

	interjectionWnd.idCharacterName:SetText(name or "")
	self:SetCharacterPortrait(line.Character, "left", false)

	-- Display current interjection as selected.
	for i, interject in ipairs(dlg.idInterjectionContainer) do
		if interject ~= interjectionWnd then
			interject.idPhrase:SetTextStyle("ConversationPhraseDimmed")
		end
	end

	local node = interjectionWnd:ResolveId("node")
	local scroll = node.idScrollText
	RunWhenXWindowIsReady(interjectionWnd, function()
		scroll:ScrollIntoView(interjectionWnd.box)
	end)

	dlg:PlayConversationLine(T{line.Text, self.conv}, "wait", line.SoundBefore, line.SoundAfter,line.SoundType,interjectionWnd)
	return interjectionWnd.idPhrase
end

local execute_phrase_ret_val = false
local execute_phrase_thread = false
function NetSyncEvents.PhraseExecuted(phrase_id, val)
	execute_phrase_ret_val = val
	if IsValidThread(execute_phrase_thread) then
		local dlg = GetDialog("ConversationDialog")
		--[[
		if dlg.player.executing_current_phrase_id == phrase_id then
			dlg.waiting_voiceover = false
			DeleteThread(execute_phrase_thread)
			dlg.player.executing_current_phrase_id = false
		end
		]]
		--the above also works, but leaves the text white instead of grey
		--this ungracefully exits the thread gracefully
		if dlg.player.executing_current_phrase_id == phrase_id then
			dlg.waiting_voiceover = false
			CreateRealTimeThread(function()
				while dlg.player.executing_current_phrase_id == phrase_id and IsValidThread(execute_phrase_thread) do
					if dlg.player.is_line_paused then
						Msg("ConversationUnpause")
					else
						Msg(dlg)
					end
					Sleep(5)
				end
			end)
		end
	end
	Msg("PhraseExecuted" .. phrase_id)
	--print("PhraseExecuted" .. phrase_id)
end

function NetSyncEvents.ExecutePhrase(phrase_id, seen, meta)
	local dlg = GetDialog("ConversationDialog")
	assert(dlg)
	local phrase = GetPhrase(phrase_id)
	DeleteThread(execute_phrase_thread)
	execute_phrase_thread = CreateMapRealTimeThread(function(dlg, phrase, seen, meta)
		local ret = dlg.player:_ExecutePhrase(phrase, seen, meta, phrase_id)
		dlg.player.executing_current_phrase_id = false
		if dlg.can_control then
			NetSyncEvent("PhraseExecuted", phrase_id, ret)
		end
		execute_phrase_thread = false
	end, dlg, phrase, seen, meta, phrase_id)
end

function ConversationPlayer:ExecutePhrase(phrase, phrase_seen, meta, phrase_id)
	if self.dlg:IsUIControllable() then
		NetSyncEvent("ExecutePhrase", phrase_id, phrase_seen, meta)
	end
	WaitMsg("PhraseExecuted" .. phrase_id)
	Msg("PhraseExecuted", phrase_id)
	return execute_phrase_ret_val
end

function ConversationPlayer:_ExecutePhrase(phrase, phrase_seen, meta, phrase_id)
	self.executing_current_phrase_id = phrase_id
	--print("ConversationPlayer:ExecutePhrase", phrase.id)
	local dlg = self.dlg
	local open_anim = not dlg.unit_template_id
	if open_anim then
		dlg.idPhrase:SetVisible(false, true)
		dlg.idCharacterName:SetVisible(false, true)
		dlg.idUndertitleImage:SetVisible(false, true)
		dlg.idChoices:SetVisible(false, true)
	end
	-- filter out units not present on the map or dead
	local lines, is_radio_line, interjections, effects = {}, {}, {}, {}
	self:GatherPhraseLines(phrase, phrase_seen, lines, is_radio_line, interjections, effects)
	if #lines<1 then return false end
	
	-- setup phrase conditions rollover text
	dlg:ClearKeywords(not "phrase_choices_available")
	local rollover_text = GetPhraseConditionsRollover(phrase, self.conv)
	local fx = GetPhraseConditionsFX(phrase, self.conv)
	if fx then
		PlayFX(fx, "start")
	end
	
	local interjection_mode = false
	local function RestorePreInterjectionPortrait()
		-- Restore portrait from before interjection
		if interjection_mode then
			local restoreCharLine, restoreCharLineIdx = lines[interjection_mode - 1], interjection_mode - 1
			if restoreCharLine then
				self:SetCharacterPortrait(restoreCharLine.Character, "left", is_radio_line[restoreCharLineIdx])
			end
			interjection_mode = false
		end
	end
	
	dlg:StopPhraseRolloverFadeout()
	
	-- display lines one by one
	local last_idx = #lines
	local bPauseline = self.should_pause
	
	--print("lines count", #lines)
	for idx, line in ipairs(lines) do
		self.current_line_idx = idx
		dlg.idNextPhrase:SetVisible(false)
		
		local rollover = idx == last_idx and rollover_text ~= "" and rollover_text
		dlg.idPhraseRollover:SetText(rollover or "")
		dlg.idPhraseRollover.parent:UpdateAnimation(false, not not rollover)
		if rollover then
			dlg:InitiatePhraseRolloverFadeout()
		end
		
		local lastLineUI = false
		if interjections[idx] then
			if not interjection_mode then interjection_mode = idx end
			lastLineUI = self:DisplayConversationInterjection(line, interjections[idx], lines)
		else
			RestorePreInterjectionPortrait()
			lastLineUI = self:DisplayConversationLine(line, is_radio_line[line], idx < last_idx or meta == "end" )
		end
		
		if bPauseline and (idx < last_idx or meta == "end") and not dlg.hide_pause_hint then
			if not GetConvoSyncDataForState(self, skip_wait_line) then
				self.is_line_paused = true
				WaitMsg("ConversationUnpause")
				meta = "end-next"
				self.is_line_paused = false
			end
		end
	
		dlg.hide_pause_hint = false
		
		if lastLineUI then
			lastLineUI:SetTextStyle("ConversationPhraseDimmed")
		end
	end
	self.current_line_idx = false
	RestorePreInterjectionPortrait()
	ExecuteEffectList(effects, self.merc_id, phrase) --todo: sync me
	
	-- Require additional input for closing dialog.
	if meta == "end" then
		--print("lines wait")
		dlg:WaitPhraseChoice(meta)
	end
	--print("ret lines")
	return true
end

function ConversationPlayer:WaitKeywordChoice(next_phrases, aggregated_tag)
	-- gather & sort keywords to be displayed
	local left, right = {}, {}
	for _, data in ipairs(next_phrases) do
		if not ignore_phrases[data.keyword] and data.keyword ~= "Goodbye" and data.active_phrase_id then
			table.insert(data.align == "left" and left or right, data)
		end
	end
	table.insert(right, next_phrases.Back) -- might insert nil, which does nothing
	if next_phrases.Goodbye and next_phrases.Goodbye.active_phrase_id then
		table.insert(right, next_phrases.Goodbye)
	end
	
	-- initialize debug popup
	local conv_dlg = GetDialog("ConversationDialog")
	local btn = rawget(conv_dlg, "idDebugButton")
	if btn then
		self.dlg:SetDebugData(next_phrases, self.merc_id, self.conv_id)
		if CloseConversationDebugPopup() then
			OpenConversationDebugPopup(btn, next_phrases, self.merc_id, self.conv_id)
		end
	end

	-- trivial case - the keywords fit in the keyword slots
	if self:ArrangeKeywordsTrivial(left, right) then
		return self.dlg:WaitPhraseChoice()
	end	
	
	-- collapse keywords with tags into a second level; they go on top of the 'left' phrases
	local left_by_tag = {} -- # => { tag = , keyword = , keyword_text =, visual_state = , phrase1, phrase2, ... }
	self:FilterOutKeywordsByTag(left_by_tag, left)
	self:FilterOutKeywordsByTag(left_by_tag, right)
	left = table.iappend(left_by_tag, left)
	
	-- if still more than 6 keywords, add "More..." in 'right' before the special Back & Goodbye keywords
	if #left + #right > 6 then
		local idx = #right
		while idx > 1 and (right[idx].keyword == "Back" or right[idx].keyword == "Goodbye") do idx = idx - 1 end
		idx = idx + 1
		table.insert(right, idx, { keyword = "More", keyword_text = T(954617747960, --[[Conversation UI]] "More..."), visual_state = "dimmed" })
		while idx > 1 do
			idx = idx - 1
			local choice = table.remove(right, idx)
			table.insert(left, choice)
		end
	end
	
	-- navigate the resulting phrase tree, handling Back/More keywords	
	local first_idx, l, r = 1, table.copy(left), table.copy(right)
	if aggregated_tag then
		local aggregated_phrase = table.find_value(l, "tag", aggregated_tag)
		if aggregated_phrase and #aggregated_phrase > 0 then
			l, r = aggregated_phrase, { back_keyword_data }
		end
	end

	while true do		
		local result = self:ArrangeKeywordsTrivial(l, r, first_idx)
		assert(result)
		local choice = self.dlg:WaitPhraseChoice()
		if choice == "Back" then
			if not aggregated_tag then
				return choice
			end
			first_idx, l, r, aggregated_tag = 1, table.copy(left), table.copy(right), nil
		elseif choice == "More" then
			first_idx = first_idx + (6 - #right)
			if first_idx > #left then
				first_idx = 1
			end
			l,r = table.copy(left), table.copy(right)
		else
			local aggregated_phrase = not aggregated_tag and table.find_value(l, "tag", choice) -- tags may only be on the left
			if not aggregated_phrase or #aggregated_phrase == 0 then
				return choice, aggregated_tag
			end
			first_idx, l, r, aggregated_tag = 1, aggregated_phrase, { back_keyword_data }, choice
		end
	end
end

function ConversationPlayer:FilterOutKeywordsByTag(output_table, phrase_list)
	for i = #phrase_list, 1, -1 do
		local phrase = phrase_list[i]
		local tag = phrase.tag
		if tag and tag ~= "" then
			local data = table.find_value(output_table, "tag", tag)
			local removed = table.remove(phrase_list, i)
			if data or table.find(phrase_list, "tag", tag) then
				if not data then
					table.insert(output_table, { phrase,
						tag = tag,
						keyword = tag,
						keyword_text = phrase.tag_text,
						visual_state = phrase.visual_state == "dimmed" and "dimmed" or "normal" })
				else
					table.insert(data, phrase)
					if phrase.visual_state ~= "dimmed" then
						data.visual_state = "normal"
					end
				end
			else
				table.insert(phrase_list, i, removed)
			end
		end
	end
end

-- [n_left] = {[n_right] = {T_WheeleCoice_idx, b_flipX},}
local MapLeftRightSectorImageIdx = {
[0] = {[0] = {1, false}, [1] = {1, false}, [2] = {3, true} , [3] = {4, true}},
[1] = {[0] = {1, false}, [1] = {2, false}, [2] = {3, true} , [3] = {4, true}},
[2] = {[0] = {3, false}, [1] = {3, false}, [2] = {7, false}, [3] = {5, true}},
[3] = {[0] = {4, false}, [1] = {4, false}, [2] = {5, false}, [3] = {6, false}},
}

-- [n_left] = {{idx1, bflipX},{idx2, bflipx}} - T_WheeleChoiceHover
local SelectionSectorImageLeft = {
	[0] = {},
	[1] = {{},{6, false}, {}},
	[2] = {{4, false},{}, {5, false}},
	[3] = {{1, false}, {2, false}, {3, false}},
}

local SelectionSectorImageRight = {
	[0] = {},
	[1] = {{},{6, true}, {}},
	[2] = {{4, true},{}, {5, true}},
	[3] = {{1, true}, {2, true}, {3, true}},
}

function ConversationGetCircleImages(nLeft, nRight)
	nLeft = nLeft or 0
	nRight= nRight or 0
	local circle_data = MapLeftRightSectorImageIdx[nLeft] and MapLeftRightSectorImageIdx[nLeft][nRight] or {}
	return circle_data[1], circle_data[2]-- idx , flip x
end

function ConversationGetCircleSelectionImages(nLeft, nRight)
	nLeft = nLeft or 0
	nRight= nRight or 0
	return SelectionSectorImageLeft[nLeft], SelectionSectorImageRight[nRight]
end

function ConversationGetCircleSelectionImage(nLeft, nRight, left_or_right, sector_idx )
	nLeft = nLeft or 0
	nRight= nRight or 0
	if left_or_right=="left" then
		return SelectionSectorImageLeft[nLeft] and SelectionSectorImageLeft[nLeft][sector_idx] or {}
	elseif left_or_right=="right" then
		return SelectionSectorImageRight[nRight] and SelectionSectorImageRight[nRight][sector_idx] or {}
	end
end

local ChoiceArrowAngle = {
	[1] = 315-360,
	[2] = 270-360,
	[3] = 220-360,
	[4] = 45,
	[5] = 90,
	[6] = 135,
	[11] = 290-360,
	[31] = 250-360,
	[41] = 70,
	[61] = 110,
}

function ConversationGetCircleAngle(choice_idx)
	return ChoiceArrowAngle[choice_idx]*60
end

function ConversationPlayer:ArrangeKeywordsTrivial(left, right, first_idx)
	if first_idx then
		local page = {}
		for i = 1, 6 - #right do
			page[i] = left[i + first_idx - 1]
		end
		left = page
	end
	
	--local rhombus = self.dlg:ResolveId("idRhombus")
	local nLeft, nRight = #left , #right
	if nLeft <= 3 and nRight <= 3 then
		CreateMapRealTimeThread(function()
			local rhombus_img, rhombus_img_flip = ConversationGetCircleImages(nLeft, nRight)
			--rhombus:SetImage("UI/Conversation/T_WheelChoice_"..rhombus_img..".tga")
			--rhombus:SetFlipX(rhombus_img_flip)
			if self.dlg.window_state == "destroying" then return end

			self.dlg:ClearKeywords("phrase_choices_available")
			self.dlg:FillKeywords("left", left,nLeft, nRight)
			self.dlg:FillKeywords("right",right,nLeft,nRight)
		end)
		return true
	end
	if nLeft + nRight <= 6 then
		CreateMapRealTimeThread(function()
			table.reverse(right)
			while nRight>3 do
				local item = right[#right]
				table.remove(right)
				table.insert(left, item)
				nRight = nRight - 1
			end
			while nLeft>3 do
				local item = left[#left]
				table.remove(left)
				table.insert(right,item)
				nLeft = nLeft - 1
			end
			table.reverse(right)
			nLeft, nRight = #left , #right
			local rhombus_img, rhombus_image_flip = ConversationGetCircleImages(nLeft, nRight)
			--rhombus:SetImage("UI/Conversation/T_WheelChoice_"..rhombus_img..".tga")
			--rhombus:SetFlipX(rhombus_image_flip)
			
			self.dlg:ClearKeywords("phrase_choices_available")
			self.dlg:FillKeywords("left", left, nLeft, nRight)
			self.dlg:FillKeywords("right", right,nLeft, nRight)
		end)
		return true
	end
end

----- Conversation editor

local function PhraseHasEffects(phrase)
	if phrase.Effects and next(phrase.Effects)then
		return true
	else
		for _, phr in ipairs(phrase) do
			if PhraseHasEffects(phr) then
				return true
			end
		end
	end
	return false
end

function GedOpDeleteConversationPhrase(ged, root, selection)
	if IsTreeMultiSelection(selection) then
		return GedTreeMultiOp(ged, root, "GedOpDeleteConversationPhrase", "delete", selection)
	end
	
	local phrase = TreeNodeByPath(root, unpack_params(selection))
	local has_effects = PhraseHasEffects(phrase)
	if has_effects then
		local res = ged:WaitQuestion("Confirm Delete", string.format("The phrase %s or any of its subphrases has effects that will be deleted", phrase.id))
		if res == "ok" then
			return GedOpTreeDeleteItem(ged, root, selection)
		end
	else
		return GedOpTreeDeleteItem(ged, root, selection)
	end
end

if FirstLoad then
	g_GroupToConversation = {}
end

function RebuildGroupToConversation()
	g_GroupToConversation = {}
	ForEachPresetInCampaign("Conversation", function(preset)
		if preset.AssignToGroup and preset.Enabled then
			local t = g_GroupToConversation[preset.AssignToGroup] or {}
			t[#t+1] = preset
			g_GroupToConversation[preset.AssignToGroup] = t
		end
	end)
end

OnMsg.DataLoaded = RebuildGroupToConversation

function FindEnabledConversation(target, msg)
	local conversation, dbg_multiple_conversations
	for _, group in ipairs(target.Groups) do
		for _, preset in ipairs(g_GroupToConversation[group]) do
			if	((not msg and not next(preset.StartOnMsg)) or (msg and table.find(preset.StartOnMsg, msg))) and
				EvalConditionList(preset.Conditions, target)
			then
				if conversation then
					if not dbg_multiple_conversations then dbg_multiple_conversations = { conversation } end
					table.insert(dbg_multiple_conversations, preset.id)
				else
					conversation = preset.id
					if not Platform.developer then
						return conversation
					end
				end
			end
		end
	end
	if dbg_multiple_conversations then
		assert(not dbg_multiple_conversations, string.format("Multiple conversations are currently enabled for unit %s (%s)", target.unitdatadef_id, table.concat(dbg_multiple_conversations, ",")))
	end
	return conversation
end

----- Interface

DefineClass.ConversationDialog = {
	__parents = { "XDialog" },
	unit_template_id = false,
	has_back_phrase = false,
	has_goodbye_phrase = false,
	phrase_start_time = false,
	waiting_voiceover = false,
	hide_pause_hint = false,
	phrase_choices_available = false,
	can_control = true,
	radio_conversation =  false,
	current_linger = false,
	selected_phrase_idx = false,
	phrase_chosen = false,
	anim_hide = false,
}

function ConversationDialog:IsUIControllable()
	return not netInGame or self.can_control
end

function ConversationDialog:IsRadioConversation()
	return self.radio_conversation
end

function NetSyncEvents.ConversationDialogHostSettings(val)
	local dlg = GetDialog("ConversationDialog")
	assert(dlg)
	dlg.player.should_pause = val
	ConversationSettingsApplied = true
	Msg("ConversationSettingsArrived")
end

function NetSyncEvents.SyncConversationState(player_id, current_phrase_id, current_node_phrase_id)
	if netUniqueId == player_id then return end
	local dlg = GetDialog("ConversationDialog")
	if dlg then
		dlg.player:SyncState(current_phrase_id, current_node_phrase_id)
	end
end

function GetConvoSyncDataForState(player, flag)
	local sync_data = player.sync_data
	if not player.dlg.can_control and sync_data then
		local lid = player.current_line_idx
		if ((sync_data[lid] or 0) & flag) == flag then
			sync_data[lid] = sync_data[lid] & ~flag
			return true
		end
	end
	return false
end

function ConvoLogFutureSkip(dlg, current_phrase_id, current_executing_phrase_id, current_line_idx, is_line_paused)
	if not dlg.can_control and current_executing_phrase_id and current_line_idx then
		local function isDiffState(player)
			return player.current_phrase_id ~= current_phrase_id or
					player.executing_current_phrase_id ~= current_executing_phrase_id or
					player.current_line_idx ~= current_line_idx
		end
		local player = dlg.player
		if isDiffState(player) then
			local data = player.sync_data or {}
			player.sync_data = data
			--data[current_executing_phrase_id] = data[current_executing_phrase_id] or {}
			if not is_line_paused then
				data[current_line_idx] = (data[current_line_idx] or 0) | skip_play_line --click to skip PlayConversationLine
			else
				data[current_line_idx] = (data[current_line_idx] or 0) | skip_wait_line --click to skip waiting after display line
			end
		end
	end
end

function NetSyncEvents.PhraseChoice(phrase, player_id, current_phrase_id, current_executing_phrase_id, current_line_idx, is_line_paused, current_node_phrase_id)
	--print("NetSyncEvents.PhraseChoice")
	g_Voice:Stop()
	local dlg = GetDialog("ConversationDialog")
	if dlg then
		ConvoLogFutureSkip(dlg, current_phrase_id, current_executing_phrase_id, current_line_idx, is_line_paused)
		
		dlg.hide_pause_hint = dlg.waiting_voiceover
		dlg.waiting_voiceover = false
		Msg(dlg, phrase) --todo - maybe make sure it is waiting for phrase choice?
	end
	
end

function NetSyncEvents.ConversationUnpause(player_id, current_phrase_id, current_executing_phrase_id, current_line_idx, is_line_paused, current_node_phrase_id)
	local dlg = GetDialog("ConversationDialog")
	ConvoLogFutureSkip(GetDialog("ConversationDialog"), current_phrase_id, current_executing_phrase_id, current_line_idx, is_line_paused)
	local player = dlg.player
	if not player.is_line_paused then --line has finished playing on 1 client but not on the other
		if dlg.waiting_voiceover and player.current_phrase_id == current_phrase_id and player.current_line_idx == current_line_idx then
			dlg.hide_pause_hint = dlg.waiting_voiceover
			dlg.waiting_voiceover = false
			g_Voice:Stop()
			Msg(dlg)
		end
	end
	Msg("ConversationUnpause")
end

function NetSyncEvents.CloseConversationDialogEvent()
	CloseConversationDebugPopup()
	local dlg = GetDialog("ConversationDialog")
	assert(dlg)
	dlg:Close()
	
	Msg("CloseConversationDialog")
end

MapVar("g_LastConv", false)

function OnMsg.CloseConversationDialog()
	g_LastConv = GameTime()
end

function OpenConversationDialog(merc, conversation_id, context, source, target)
	if CanYield() then
		CloseWeaponModificationCoOpAware()
	end

	local merc_id = type(merc) == "string" and merc or merc.session_id
	local node = PhraseById(conversation_id)
	if node and not node.Enabled then
		return
	end
	local can_control = gv_UnitData[merc_id]:IsLocalPlayerControlled()
	local radio_conversation = context and context.radio
	
	for i, u in ipairs(g_Units) do
		if not u:IsIdleCommand() and u.command == "InteractWith" and (source ~= "interaction" or u ~= merc) then
			u:SetCommand("Idle")
			u:ClearCommandQueue()
		end
	end
	
	if not IsSetpiecePlaying() then
		if source == "interaction" then
			SnapCameraToObj(target)
		elseif source ~= "setpiece" then
			SnapCameraToObj(g_Units[merc_id])
		end
	end

	EndAllBanter()
	local igi = GetInGameInterfaceModeDlg()
	if IsKindOf(igi, "GamepadUnitControl") then
		igi:GamepadSelectionSetTarget(false)
	end
	
	local shouldPause = GetAccountStorageOptionValue("PauseConversation")
	ConversationSettingsApplied = false
	if can_control then
		NetSyncEvent("ConversationDialogHostSettings", shouldPause)
	end
	local dlg = OpenDialog("ConversationDialog", terminal.desktop, {
		conversation_id = conversation_id,
		can_control = can_control,
		radio_conversation = radio_conversation
	})
	local player = ConversationPlayer:new{
		dlg = dlg,
		merc_id = merc_id,
		conv_id = conversation_id,
		test = context,
		target_groups = target and target.Groups,
		target_name = target and target:GetDisplayName(),
		should_pause = shouldPause
	}
	player.seed = InteractionRand(nil, "Conversation")
	dlg.player = player
	dlg:CreateThread("RunConversation", ConversationPlayer.RunConversationProtected, player)
	return dlg
end

function ConversationGetPlayerMerc()
	local dlg = GetDialog("ConversationDialog")
	if dlg and dlg.player then
		return dlg.player.merc_id
	end
end

MapVar("g_CoOpConversationOptionAdvice", false)

function NetSyncEvents.AdviseConversationChoice(option)
	if g_CoOpConversationOptionAdvice == option then
		g_CoOpConversationOptionAdvice = false
	else
		g_CoOpConversationOptionAdvice = option
	end
	ObjModified("g_CoOpConversationOptionAdvice")
end

--[[
function GetMercForRadioConversation(sector)
	local merc_id 
	if gv_SatelliteView then	
		local dlg = GetSatelliteDialog()	
		if dlg.selected_merc then
			merc_id  = dlg.selected_merc and dlg.selected_merc.session_id
		end	
		if not merc_id and dlg.selected_squad then
			merc_id  = dlg.selected_squad.units and dlg.selected_squad.units[1]
		end
	else
		local unti = SelectedObj
		merc_id = IsKindOf(SelectedObj, "Unit") and SelectedObj:IsMerc() and SelectedObj.session_id
	end
	if not merc_id then
		for _, s in ipairs(GetPlayerMercSquads()) do
			local m = s and s.units and s.units[1]
			if m then
				merc_id = m
				break
			end
		end
	end
	return merc_id
end
--]]

function OnMsg.NewMap()
	CloseDialog("ConversationDialog")
end

local function OnMsgStartConversation(unit, msg)
	local conversation = FindEnabledConversation(unit, msg)
	if conversation then
		CreateRealTimeThread(FireNetSyncEventOnHost, SelectedObj, conversation)
	end
end

function OnMsg.UnitDied(unit) return OnMsgStartConversation(unit, "UnitDied") end
function OnMsg.VillainDefeated(unit) return OnMsgStartConversation(unit, "VillainDefeated") end

function ConversationDefaultActorCombo()
	return PresetsPropCombo("Conversation", "DefaultActor", {""})
end

DefineClass.ConversationEditorFilter = {
	__parents = { "GedFilter" },
	properties = {
		{ id = "Actor", name = "Actor", editor = "combo", default = false, items = ConversationDefaultActorCombo },
	}
}

function ConversationEditorFilter:FilterObject(conv)
	if not self.Actor or self.Actor == "" then return true end
	if conv.DefaultActor ~= self.Actor then
		return false
	end
	return true
end

function ConversationPhraseActorCombo()
	return PresetsPropCombo("Conversation", "Character", ConversationDefaultActorCombo()(), true)
end

DefineClass.ConversationEditorPhraseFilter = {
	__parents = { "GedFilter" },
	properties = {
		{ id = "Actor", name = "Actor", editor = "combo", default = false, items = ConversationPhraseActorCombo },
	}
}

function ConversationEditorPhraseFilter:FilterObject(phrase)
	if not self.Actor or self.Actor == "" then return true end
	if IsKindOf(phrase, "ConversationPhrase") and phrase.Lines then
		local found = false
		for _, line in ipairs(phrase.Lines or empty_table) do
			if line:IsKindOf("ConversationLine") then
				found = line.Character == self.Actor
			elseif line:IsKindOf("ConversationInterjectionList") then
				for _, interjection in ipairs(line.Interjections or empty_table) do
					found = table.find(interjection.Lines, "Character", self.Actor)
					if found then break end
				end
			end
			if found then break end
		end
		if not found then return false end
	end
	return true
end

-- all conversation-related Conditions & Effects inherit this class
DefineClass.ConversationFunctionObjectBase = { __parents = { "PropertyObject" } }


----- Editor debug info

if FirstLoad then
	g_ConversationEditorDebugInfo = false
end

DefineClass.ConversationDebugInfo = {
	__parents = {"PropertyObject"},
	properties = {
		{ id = "id", name = "Conversation ID", editor = "text", default = "ID" },
	},
	preset = false,
}

function ConversationDebugInfo:GetProperties()
	local conversation = Conversations[self.id] or empty_table
	local props = table.copy(PropertyObject.GetProperties(self))
	-- from quests
	ForEachPresetInCampaign("QuestsDef",function(preset, group, filter)
		preset:ForEachSubObject("ConversationFunctionObjectBase", function(obj, parents)
			if obj.Conversation == self.id then
				local path = GedParentsListToSelection(parents)
				local element = {
					id = (preset.id) .. #props,
					name = ComposeSubobjectName(parents),
					default = EditorViewAbridged(obj, obj.Conversation, "conversation"),
					category = "Quests",
					editor = "text",
					read_only = true, 
					buttons = {
						{
							name = "View", 
							func = "QuestsEditorSelect",
							param = {
								preset_id = preset.id, 
							},
						},
					},  

				}
				table.insert(props, element)
			end	
		end)
	end)

	-- from markers
	local map_name = GetMapName()
	if not g_DebugMarkersInfo or not g_DebugMarkersInfo[map_name] then
		GatherMarkerScriptingData()
	end
-- filter for current conversation
	ForEachDebugMarkerData("conversation", self.id, function(marker_info, res_item_info) 
		local element = {
			id = "h_" .. marker_info.handle .. "_" .. #props,
			name = marker_info.name,
			default = res_item_info.editor_view_abridged,
			category = marker_info.map and marker_info.map .. " GridMarker references" or "GridMarker references",
			editor = "text",
			read_only = true, 
		}
		local name = marker_info.map==map_name and "View" or "View on other map"
		element.buttons = {
				{
					name = name, 
					func = "GridMarkerEditorSelectDiffMap",
					param = {
				 		map = marker_info.map
				 	},
				}
			}
		table.insert(props, element)
	end)

	return props
end

function QuestsEditorSelect(root, obj, prop_id, socket, param)
	Quests[param.preset_id]:OpenEditor()
end

function OnMsg.GedOnEditorSelect(obj, selected, editor)
	if editor and editor.app_template == "ConversationEditor" then
		if selected and rawget(obj, "id") then
			local infoobj = ConversationDebugInfo:new{ preset = obj, id = obj.id,}
			g_ConversationEditorDebugInfo = infoobj
			editor:BindObj("state", infoobj)
		else
			g_ConversationEditorDebugInfo = false
		end
	end
end

----- Testing

if Platform.developer then
	function TestConversation(ged_or_id, conversation)
		CreateRealTimeThread(function()
			if type(ged_or_id) ~= "string" and not Game then
				ged_or_id:ShowMessage("Warning", "Testing a conversation requires a game session.")
				return
			end
			
			-- use a unit from a squad under the player's control, preferably present on the map
			local unit, message
			if g_CurrentSquad and g_CurrentSquad > 0 then
				local squad = gv_Squads[g_CurrentSquad]
				local units = squad.units
				if units then
					unit = units[1]
					message = string.format("Testing with merc '%s' (currently on the map).", unit.unitdatadef_id)
				end
			end
			if not unit then
				MapForEach("map", "Unit", function(o)
					if o.Squad and gv_Squads[o.Squad] == "player1" then
						unit, message = o, string.format("Testing with merc '%s' (currently on the map).", o.unitdatadef_id)
						return "break"
					end
				end)
			end
			if not unit then
				for _, s in ipairs(GetPlayerMercSquads()) do
					if s.Side == "player1" and #s.units then
						unit, message = s.units[1], string.format("Testing with merc '%s' (in a player squad outside map).", s.units[1].unitdatadef_id)
					end
				end
			end
			if not unit then
				unit, message = "Blood", "Testing with dummy merc 'Blood' (no player squads found)."
			end
			
			if type(ged_or_id) == "string" then
				OpenConversationDialog(unit, ged_or_id, "test_conversation")
			else
				local conversation_id = conversation.id
				if ged_or_id:WaitQuestion("Test conversation", message .. "\n\nReset the seen/enabled states of all phrases?", "Yes", "No") == "ok" then
					Conversations[conversation_id]:ForEachSubObject("ConversationPhrase", function(phrase, parents)
						gv_PhraseStates[ComposePhraseId(parents, phrase)] = nil
					end)
				end
				OpenConversationDialog(unit, conversation_id, "test_conversation")
			end
		end)
	end
end

function OnMsg.NetPlayerLeft()
	local cd = GetDialog("ConversationDialog")
	if cd then
		local mi = cd.player and cd.player.merc_id
		if mi then
			cd.can_control = gv_UnitData[mi]:IsLocalPlayerControlled()
		else
			cd.can_control = true
		end
	end
end

function OnMsg.BugReportStart(print_func, bugreport_dlg)
	local dlg = GetDialog("ConversationDialog")
	if dlg then
		local context = dlg:GetContext()
		local can_control = dlg:IsUIControllable() and "controllable" or "not controlable"
		print_func(string.format("Started Conversation: %s (%s), unit - %s\n",
				context and context.conversation_id or "", can_control, dlg.unit_template_id or ""))
	end
end

function OnMsg.CanSaveGameQuery(query)
	local dlg = GetDialog("ConversationDialog")
	if dlg then
		query.conversation = true
	end
end

function StartConversationEffect(conversation, context, wait)
	if not conversation then return end
	
	local dlg = GetDialog("ConversationDialog")
	if dlg and (dlg.window_state == "open" or dlg.window_state == "new") then
		if wait then
			WaitMsg("CloseConversationDialog")
		else
			print("Tried to start conversation", conversation, "while", dlg.context.conversation_id, "was playing")
			return
		end
	end

	local unit = context and context.target_units and context.target_units[1] and context.target_units[1].session_id
	if not unit then
		local squads = GetSquadsInSector(gv_CurrentSectorId)
		unit = squads[1] and squads[1].units and squads[1].units[1]
	end
	if not unit then return end

	OpenConversationDialog(
		unit,
		conversation,
		context and context.radio and context,
		context and type(context) == "string" and context
	)
	if wait then WaitMsg("CloseConversationDialog") end
end

const.TypewriterEffectSpeed  = 12
DefineClass.XTextTypewriterEffect = {
	__parents = { "XText" },
	HandleMouse = true,

	effect_head = 0,
	row_rects = false,
	rows_total_width = false
}

function XTextTypewriterEffect:SetText(text)
	self:DeleteThread("effect")
	self.effect_head = 0
	
	self:CreateThread("effect", function()
		while self.window_state ~= "destroying" do
			self.effect_head = self.effect_head + const.TypewriterEffectSpeed
			self:Invalidate()
			Sleep(10)
			
			if self.effect_head > self.rows_total_width then
				self.effect_head = self.rows_total_width
				break
			end
		end
		Msg("EndTypewriting")
	end)

	XText.SetText(self, text)
end

function XTextTypewriterEffect:UpdateDrawCache(...)
	XText.UpdateDrawCache(self, ...)
	
	local row_rects = {}
	local cache = self.draw_cache
	local totalWidth = 0
	for y, data in pairs(cache) do
		local height = 0
		local width = 0
		for i, segment in ipairs(data) do
			width = width + segment.width
			height = Max(height, segment.height)
		end
		row_rects[#row_rects + 1] = sizebox(0, y, width, height)
		totalWidth = totalWidth + width
	end
	table.sort(row_rects, function(a, b)
		return a:miny() < b:miny()
	end)
	self.row_rects = row_rects
	self.rows_total_width = totalWidth
	if totalWidth < self.effect_head or not self:GetThread("effect") then self.effect_head = totalWidth end -- Clamp back
end

local UIL = UIL
function XTextTypewriterEffect:DrawContent(clip_box)
	local destx = self.content_box:minx()
	local desty = self.content_box:miny()
	local sizex = self.content_box:sizex()
	local sizey = self.content_box:sizey()
	local row_rects = self.row_rects
	
	local head = self.effect_head
	local clipsPushed = 0
	if row_rects then
		local widthSoFar = 0
		for i, lineBox in ipairs(row_rects) do
			local width = lineBox:sizex()
			local x = lineBox:minx()
			local destBox
			if head > widthSoFar then
				local widthShouldBe = (head - widthSoFar)
				width = widthShouldBe
			else
				return
			end
			
			if width > 0 then
				destBox = sizebox(destx + x, desty + lineBox:miny(), width, lineBox:sizey())
			else
				destBox = clip_box
			end
			UIL.PushClipRect(destBox)
			XText.DrawContent(self, destBox)
			UIL.PopClipRect()
			
			widthSoFar = widthSoFar + lineBox:sizex()
		end
	end
end

function XTextTypewriterEffect:SkipEffect()
	-- Debounce multiple skips in one real time ms.
	if self:GetThread("effect-shutoff") then return end
	self:CreateThread("effect-shutoff", function()
		Sleep(1)
		self:DeleteThread("effect")
		self.effect_head = self.rows_total_width
		Msg("EndTypewriting")
		self:Invalidate()
	end)
end

-- support for generating voice recording scripts 

function HasCharacter(obj, character)
	if obj:IsKindOf("ConversationLine") then
		return obj.Character == character
	elseif obj:IsKindOf("ConversationInterjectionList") then
		for _, sub in ipairs(obj.Interjections) do
			if HasCharacter(sub, character) then
				return true
			end
		end
	elseif obj:IsKindOf("ConversationInterjection") then
		for _, sub in ipairs(obj.Lines) do
			if HasCharacter(sub, character) then
				return true
			end
		end
	elseif obj:IsKindOf("ConversationPhrase") then
		for _, sub in ipairs(obj.Lines) do
			if HasCharacter(sub, character) then
				return true
			end
		end
		for _, sub in ipairs(obj) do
			if HasCharacter(sub, character) then
				return true
			end
		end
	elseif obj:IsKindOf("Conversation") then
		for _, sub in ipairs(obj) do
			if HasCharacter(sub, character) then
				return true
			end
		end
	end
end

function GatherCharacters(obj, characters)
	if obj:IsKindOf("ConversationLine") then
		characters[obj.Character] = true
	elseif obj:IsKindOf("ConversationInterjectionList") then
		for _, sub in ipairs(obj.Interjections) do
			GatherCharacters(sub, characters)
		end
	elseif obj:IsKindOf("ConversationInterjection") then
		for _, sub in ipairs(obj.Lines) do
			GatherCharacters(sub, characters)
		end
	elseif obj:IsKindOf("ConversationPhrase") then
		for _, sub in ipairs(obj.Lines) do
			GatherCharacters(sub, characters)
		end
		for _, sub in ipairs(obj) do
			GatherCharacters(sub, characters)
		end
	elseif obj:IsKindOf("Conversation") then
		for _, sub in ipairs(obj) do
			GatherCharacters(sub, characters)
		end
	end
end

function PrintCharacterLines(obj, character, s, csv, already_reported, language)
	local found = false
	for _, sub in ipairs(obj.Lines) do
		if HasCharacter(sub, character) then
			found = true
		end
	end
	if found then
		for _, sub in ipairs(obj.Lines) do
			PrintCharacterPhrases(sub, character, s, csv, already_reported, language)
		end
		s:append("<br>\n")
		csv[#csv+1] = {}
	end
end

-- attempt to only print lines in conversation relevant to a character

function InBracketsIfPresent(s)
	if s then
		return " (" .. tostring(s) .. ")"
	else
		return ""
	end
end

function PrintCharacterPhrases(obj, character, s, csv, already_reported, language)
	
	if obj:IsKindOf("Conversation") then
		for _, sub in ipairs(obj) do
			if HasCharacter(sub, character) then
				PrintCharacterPhrases(sub, character, s, csv, already_reported, language)
			end
		end
	elseif obj:IsKindOf("ConversationPhrase") then
		if obj.Keyword then
			s:append("<div><i>Keyword: ", obj.Keyword, "</i></div>\n")
			csv.keyword = string.format("Keyword: %s%s", obj.Keyword, InBracketsIfPresent(obj.Comment))
		end
		PrintCharacterLines(obj, character, s, csv, already_reported, language)
		for _, sub in ipairs(obj) do
			if HasCharacter(sub, character) then
				PrintCharacterPhrases(sub, character, s, csv, already_reported, language)
			end
		end
	elseif obj:IsKindOf("ConversationInterjection") then
		PrintCharacterLines(obj, character, s, csv, already_reported, language)
	elseif obj:IsKindOf("ConversationInterjectionList") then
		for _, sub in ipairs(obj.Interjections) do
			if HasCharacter(sub, character) then
				PrintCharacterPhrases(sub, character, s, csv, already_reported, language)
			end
		end
	elseif obj:IsKindOf("ConversationLine") and obj.Text then
		local annotation = ""
		if obj.Annotation then
			annotation = " <i>(" .. obj.Annotation .. ")</i>"
		end
		
		local voice_id = VoiceActors[obj.Character] and VoiceActors[obj.Character].VoiceId or obj.Character
		if voice_id ~= obj.Character then
			voice_id = voice_id .. " (as " .. obj.Character .. ")"
		end
		local csv_annotation = {}
		csv_annotation[#csv_annotation+1] = obj.Annotation or nil
		csv_annotation = next(csv_annotation) and table.concat(csv_annotation, " ") or nil
		
		local tid = TGetID(obj.Text)
		local loc_text = g_BuildLocTables and g_BuildLocTables[language][tid] or TDevModeGetEnglishText(obj.Text)
		local csv_entry = { 
			line_type = "Conversation",
			direction = csv_annotation,			
			actor = voice_id,			
			text = loc_text,
			section = csv.caption or false,
			keyword = csv.keyword or false,
			caption = csv.caption or false,			
		}
		
		assert(already_reported)
		if obj.Character == character and not already_reported[tid] then
			s:appendf([[<div style="background:lightgreen"><b>%s ID:%d:</b>%s<br><b>%s</b></div>]] .. "\n", voice_id, tid, annotation, loc_text)
			csv_entry.id = tid
			already_reported[tid] = true
		else
			s:appendf("<div>%s:%s<br>%s</div>\n", voice_id, annotation, loc_text)
		end
		csv[#csv+1] = csv_entry
		csv.keyword = false
		csv.caption = false
	end
end

local css = "<style>body{font-family:courier,monospace;background:white;color:black;}i{color:gray}h1{background:lightgray}b{font-weight:bolder}div{padding-left:4em;text-indent:-4em}</style>\n"

-- pitstop format:
-- { caption, id, actor, direction, text }
-- caption lines have only caption, other fields don't have caption
-- lines for other characters have actor, direction, text
-- lines for current voice_id have ID, actor, direction, text

function GenerateConversationVoiceScripts(language)
	local character_pstrs, character_csvs, character_already_reported = {}, {}, {}
	
	PauseInfiniteLoopDetection("GenerateConversationVoiceScripts")
	
	if language and language ~= "English" then
		local loc_path = "svnProject"
		g_BuildLocTables = false
		LoadBuildLocTables(loc_path)			
	end
	
	
	for id, conversation in sorted_pairs(Conversations) do
		if conversation.IncludeInVoiceScripts then
			local characters = {}
			GatherCharacters(conversation, characters)
			for character in sorted_pairs(characters) do
				local voice_id = VoiceActors[character] and VoiceActors[character].VoiceId or character
				
				local csv = character_csvs[voice_id] or {}
				csv.caption = string.format("Conversation: %s%s", id, InBracketsIfPresent(conversation.Comment))
				
				local already_reported = character_already_reported[voice_id] or {}
				local p = character_pstrs[voice_id] or pstr(css)
				p:appendf("<h1>Conversation %s</h1>\n", id)
				PrintCharacterPhrases(conversation, character, p, csv, already_reported, language)
				p:append("<br>")
				character_pstrs[voice_id] = p
				character_csvs[voice_id] = csv
				character_already_reported[voice_id] = already_reported
			end
		end
	end
	AsyncCreatePath("svnProject/LocalizationDB/VoiceRecordings/" .. language .. "/html/")
	AsyncCreatePath("svnAssets/tmp/VoiceRecordings/".. language .. "/")
	local ids_used_for_voice = {}
	for voice_id, s in sorted_pairs(character_pstrs) do
		voice_id = string.gsub(voice_id, '[/?<>\\:*|"]', "_")
		AsyncStringToFile("svnProject/LocalizationDB/VoiceRecordings/" .. language .. "/html/" .. voice_id .. " conversations.html", s)
		for id in tostring(s):gmatch("ID:(%d+)") do
			ids_used_for_voice[tonumber(id)] = true
		end
		AsyncStringToFile("svnAssets/tmp/VoiceRecordings/" .. language .. "/" .. voice_id .. " conversations.lua", "return " .. ValueToLuaCode(character_csvs[voice_id]))
	end
	AsyncStringToFile("svnAssets/tmp/VoiceRecordings/" .. language .. "/ids_used_in_conversations.lua", "return " .. ValueToLuaCode(ids_used_for_voice))
	
	if not GetStack():find("ConsoleExec") then -- manually called from in-game console for debugging?
		quit() -- no, probably EXE launched from build script just to do this, quit afterwards
	end

	ResumeInfiniteLoopDetection("GenerateConversationVoiceScripts")
end

function CheckExecutedPhraseForPsycho(phrase)
	local function PsychoCheck(conditions)
		local psychoActivated
		for _, condition in ipairs(conditions) do
			if condition.HasPerk == "Psycho" and not condition.Negate and EvalConditionList({condition}) then
				psychoActivated = true
			elseif condition.class == "CheckOR" then
				psychoActivated = PsychoCheck(condition.Conditions)
			end
			
			if psychoActivated then
				return true
			end
		end
	end
	
	return PsychoCheck(phrase.Conditions)
end

function GetRadioConversationIconsCombo()
	return {
		{ text = "walkie talkie", value = "UI/Hud/radio" },
		{ text = "old phone", value = "UI/Hud/radio_conversation" }
	}
end