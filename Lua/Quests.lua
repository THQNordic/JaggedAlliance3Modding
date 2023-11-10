local depending_conversations_cache = {}

DefineClass.QuestEffectOnStatus = {
	__parents = {"PropertyObject"},
	properties = {
		{ id = "Prop", name = "Variable", help = "Set the bool var", editor = "combo", default = false, items = function(self) return GetQuestsVarsCombo(self.QuestId,"Bool") end, },
		{ id = "Effects", name = "Effects", help = "Effect when set variable", editor = "nested_list", default = false, base_class = "Effect", },
	},
	StoreAsTable = true,
}

function QuestHasVariable(quest, class)
	for _, vardef in ipairs(quest.Variables) do
		if IsKindOf(vardef, class) then
			return true
		end
	end
end

function GetQuestsVarsCombo(quest_id, params_type)
	local params = {}
	local quest = Quests[quest_id]
	if quest then
		local cls = "QuestVar"..params_type
		for _, key in ipairs(quest.Variables or empty_table) do
			if IsKindOf(key, cls) then
				table.insert(params, key.Name)
			end
		end
	end
	return params
end

function SetQuestVar(quest, var_id, new_val, dont_notify_quest_editor)
	NetUpdateHash("SetQuestVar", var_id, new_val)
	local prev_val = rawget(quest, var_id)
	if new_val ~= prev_val then	
		rawset(quest, var_id, new_val)
		QuestsDef.OnChangeVarValue(quest, var_id, prev_val, new_val)
		if not dont_notify_quest_editor and g_QuestEditorStateInfo then
			ObjModified(g_QuestEditorStateInfo)
		end
		Msg("QuestParamChanged", quest.id, var_id, prev_val, new_val)
	end
end

function GetQuestVar(quest_id, var_id)
	local quest = QuestGetState(quest_id)
	local var = rawget(quest, var_id)
	
	return var
end

local function SetQuestMetatable(quest_t, id)
	quest_t = quest_t or {}
	local mtable = {
		__index = function(self, key)
			local instanceVal = rawget(self,key)
			if instanceVal ~= nil then
				return instanceVal
			end
			local templateVal = Quests[id] and Quests[id]:HasMember(key) and Quests[id][key] or nil
			if templateVal ~= nil then
				return templateVal
			end
		end
	}
	setmetatable(quest_t, mtable)
end

function QuestGetState(id)
	if not id then return end
	if not gv_Quests[id] then
		local quest_t = {}
		SetQuestMetatable(quest_t, id)
		gv_Quests[id] = quest_t
	end
	return gv_Quests[id]
end

function OnMsg.PreLoadSessionData()
	for id, qtable in pairs(gv_Quests or empty_table) do
		if qtable.Parameters then
			qtable.Parameters = nil
		end
	
		SetQuestMetatable(qtable, id)
	end
end

function NetSyncEvents.InitQuestsSync()
	InitQuests()
end

function OnMsg.LoadSessionData()
	--this message comes from a rtt
	FireNetSyncEventOnHost("InitQuestsSync")
end

-- init quests' statuses and add given quests in gv_Quests
function OnMsg.CampaignStarted(game)
	InitQuests()	
end

function OnMsg.NewGame()
	if CurrentMap ~= "" and not netInGame then -- Tests trigger this
		InitQuests()
		HistoryOccurenceConditionEvaluation(0)
	end
end

-- Prevent two notes from having the exact same timestamp.
GameVar("LastNoteCampaignTime", false)

function GetQuestNoteCampaignTimestamp(quest_lines)
	local campaignTime = Game.CampaignTime
	
	if not LastNoteCampaignTime then
		LastNoteCampaignTime = campaignTime
	elseif LastNoteCampaignTime > campaignTime then
		LastNoteCampaignTime = LastNoteCampaignTime + 1
	elseif campaignTime == LastNoteCampaignTime then
		LastNoteCampaignTime = campaignTime + 1
	else
		LastNoteCampaignTime = campaignTime
	end
	
	return LastNoteCampaignTime
end

function InitQuests()
	for id, quest in sorted_pairs(Quests) do
		quest = QuestGetState(id)
		local questPreset = Quests[id]
		
		if quest then
			for _, var in ipairs(questPreset.Variables or empty_table) do
				local name = var.Name
				if rawget(quest, name) == nil then
					if IsKindOf(var, "QuestVarNum") and var.RandomRangeMax then
						local min = var.Value
						rawset(quest, name, min + InteractionRand(abs(var.RandomRangeMax - min + 1), "QuestVariableNumInit_" .. name))
					else
						rawset(quest, name, var.Value)
					end
				end
			end

			-- create visibility table, and set first line visible
			local visibility = rawget(quest, "note_lines")
			if visibility == nil or not next(visibility) then
				rawset(quest, "note_lines", {})
				if questPreset.LineVisibleOnGive > 0 and QuestIsBoolVar(quest,"Given", true) then
					local note_idx = questPreset.LineVisibleOnGive
					if table.find(questPreset.NoteDefs or empty_table, "Idx", note_idx) then
						quest.note_lines[note_idx] = GetQuestNoteCampaignTimestamp(quest.note_lines)
					end
				end
			end

			-- create state table
			local completion = rawget(quest, "notes_state")
			if completion == nil or not next(completion) then
				rawset(quest, "notes_state", {})
			end
		end
	end	
end

if FirstLoad then
QuestTCEEvalThread = false
end

function QuestTCEEvaluation(specificQuests)
	QuestTCEEvalThread = CurrentThread() or false

	TutorialHintVisibilityEvaluate()
	
	local quests = specificQuests or Quests or empty_table

	for questId, quest in sorted_pairs(quests) do
		quest = QuestGetState(questId)
		if not quest then goto continue end
		
		local questPreset = Quests[questId]
		if next(questPreset.TCEs or empty_table) and not rawget(quest, "completed_tce") then
			if next(questPreset.KillTCEsConditions) and EvalConditionList(questPreset.KillTCEsConditions, quest) then
				quest.completed_tce = true
			else
				for _, tce in ipairs(questPreset.TCEs) do
					tce:Update(quest)
				end
			end	
		end
		
		-- Quests from old saves might not have state tables initialized
		if not rawget(quest, "note_lines") then
			rawset(quest, "note_lines", {})
		end
		if not rawget(quest, "notes_state") then
			rawset(quest, "notes_state", {})
		end
		
		for _, note in ipairs(questPreset.NoteDefs) do
			local anyHideC = note.HideConditions and #note.HideConditions > 0
			local anyShowC = note.ShowConditions and #note.ShowConditions > 0
			local anyBoth = anyHideC and anyShowC
			
			-- If currently shown (by effect or LogLineOnGive) then consider that as
			-- having an implicit showing condition. Otherwise it will be hidden.
			local currentlyShown = not not quest.note_lines[note.Idx]
			if not anyShowC and (currentlyShown or note.Scouting) then
				anyShowC = true
			end
			
			local hide = anyHideC and EvalConditionList(note.HideConditions, quest)
			local show = anyShowC or (not anyShowC and anyHideC) -- No show, but have hide, then show by default
			
			-- Scouting condition.
			if note.Scouting or currentlyShown then
				show = show and currentlyShown
			end
			
			-- Evaluate show conditions only if not currently shown. (173193)
			if not currentlyShown then
				show = show and EvalConditionList(note.ShowConditions, quest)
			end

			show = show and not hide

			if show ~= currentlyShown then
				quest.note_lines[note.Idx] = show and GetQuestNoteCampaignTimestamp(quest.note_lines) or false
				if show then 
					QuestRolloverPopout(questId, note) 
				end
				Msg("QuestLinesUpdated", quest)
			end

			-- Completion state (171685)
			local noteState = quest.notes_state
			local complCond = note.CompletionConditions
			if complCond and next(complCond) and noteState[note.Idx] ~= "completed" then
				-- "All" evaluation
				if EvalConditionList(complCond, quest) then
					if note.AddInHistory then
						LogHistoryOccurence("QuestNote", { questId = quest.id, noteIdx = note.Idx, sector = note.Badges and note.Badges[1].Sector })
					end
					
					noteState[note.Idx] = "completed"
					Msg("QuestLinesUpdated", quest)
				end
			end
		end
		
		::continue::
	end
end

MapGameTimeRepeat("QuestTCEEvaluation", 1010, function(sleep)
	if not sleep then
		return
	end
	if mapdata.GameLogic and HasGameSession() and not IsSetpiecePlaying() then
		QuestTCEEvaluation()
		if g_QuestEditorStateInfo then
			ObjModified(g_QuestEditorStateInfo)
		end
		
		Sleep(0)
		TimersUpdateTime(gv_ActiveCombat == gv_CurrentSectorId and 0)
	end
end)

function OnMsg.OpenSatelliteView() QuestTCEEvaluation() end
function OnMsg.SatelliteTick()     QuestTCEEvaluation() end
function OnMsg.QuestParamChanged(questId)
	if CurrentThread() == QuestTCEEvalThread then return end

	-- Get and Evaluate only affected quests
	local quests = {}
	quests[questId] = Quests[questId]
	for id, _ in sorted_pairs(gv_QuestRelations[questId]) do
		quests[id] = Quests[id]
	end
	
	QuestTCEEvaluation(quests)
end
function OnMsg.InventoryItemOwnerChanged() QuestTCEEvaluation() end
function OnMsg.OperationCompleted() QuestTCEEvaluation() end
function OnMsg.ConflictEnd() QuestTCEEvaluation() end

DefineClass.QuestStateInfo = {
	__parents = {"PropertyObject"},
	properties = {
		{ id = "id", name = "Quest ID", editor = "text", default = "ID" },
		{ id = "btn_reset", category = "Actions", editor = "buttons", buttons = {{name = "Reset Quest", func = "ResetQuest"}}, default = false, },
		{ id = "FilterQuestVariable", name = "Filter by Quest Variable",  default = "", category = "Actions", editor = "combo", 
		items = function(self) 
			local quest = QuestGetState(self.id)
			local t = table.map(quest and quest.Variables or empty_table , "Name")
			table.insert(t, 1, "")
			return t
		end 
	}
	},
	preset = false,
}

function QuestStateInfo:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "FilterQuestVariable" then
		depending_conversations_cache = {}
	end
end

local function FilterQuestVar(filter, var)
	if filter=="" then return false end
	if type(var)=="table" then
		return var[filter]==nil
	end	
	return filter~=var 
end

function QuestStateInfo:GetProperties()
	local quest = QuestGetState(self.id) or empty_table
	local props = table.copy(PropertyObject.GetProperties(self))
	for _, var in ipairs(quest.Variables or empty_table) do
		local editor = "text"
		local name = var.Name
		local proptype = var.class
		if name and proptype~="QuestVarTCEState" then
			if rawget(quest, name)==nil then
				rawset(quest, name, var.Value)
			end
			local defval
			if proptype == "QuestVarNum" then
				editor = "number"
				defval = 0
			elseif proptype == "QuestVarBool" then
				editor = "bool"
				defval = false
			else
				editor = "text"
				defval = ""
			end
			local prop_id = "fakeprop"..#props
			local prop = {id = prop_id, name = name, editor = editor, default = defval}
			self["Set"..prop_id] = function(this, val)
				local quest = QuestGetState(self.id)
				SetQuestVar(quest,name, val, true)
				ObjModified(Presets.QuestsDef)
			end
			self["Get"..prop_id] = function(this, val)
				return QuestGetState(self.id)[name]
			end
			table.insert(props, prop)
		end
	end
	--TriggeredConditionalEvent
	for _, tce in ipairs(quest.TCEs or empty_table) do
		if tce.ParamId then
			local prop = {id = "fakeprop"..#props, name = tce.ParamId, read_only = true, category = "TriggeredConditionalEvent", editor = "text", default = tostring(quest[tce.ParamId])}
			table.insert(props, prop)
		end
		for __, cond in ipairs(tce.Conditions or empty_table) do
			local name = _InternalTranslate(cond:GetEditorView(), cond)
			local prop = {id = "fakeprop"..#props, name = name.." ["..tce.ParamId.."]", read_only = true, category = "TriggeredConditionalEvent", editor = "text", default = tostring(not not cond:Evaluate())}
			table.insert(props, prop)
		end
	end
	
	-- dependings
	local dependings = {}
	QuestGatherGameDepending(dependings, self.id)
	for _, entry in ipairs(dependings.conversations or empty_table) do
		table.insert(props, { 
			id = "fakeprop" .. #props,
			name = entry.name,
			default = entry.value,
			category = "Conversation references",
			editor = "text",
			read_only = true,
			buttons = {
				{
					name = "View",
					func = "ConversationEditorSelect",
				 	param = {
				 		preset_id = entry.id,
				 		sel_path = entry.sel_path
				 	},
				},
			},
			no_edit = function(self)
				return FilterQuestVar(self.FilterQuestVariable, entry.var)
			end,
		})
	end
	for _, entry in ipairs(dependings.markers or empty_table) do
		local element = {
			id = "h_" .. entry.handle .. "_" .. #props,
			name = entry.name,
			default = entry.value,
			category = entry.map and entry.map.." GridMarker references" or "GridMarker references",
			editor = "text",
			read_only = true,
			no_edit = function(self)
				return FilterQuestVar(self.FilterQuestVariable, entry.var)
			end,
		}
		local name = entry.map==GetMapName() and "View" or "View on other map"
		element.buttons = {
				{
					name = name,
					func = "GridMarkerEditorSelectDiffMap",
					param = {
				 		map = entry.map
				 	},
				}
			}
		table.insert(props, element)
	end
	-- other quests
	for _, entry in ipairs(dependings.quests or empty_table) do
		local element = {
			id = "fakeprop"..#props,
			name = entry.name,
			default = entry.value,
			category = "Quests references",
			editor = "text",
			read_only = true,
			no_edit = function(self)
				return FilterQuestVar(self.FilterQuestVariable, entry.var)
			end,
			buttons = {
				{
					name = "View",
					func = "QuestsEditorSelect",
					param = {
						preset_id = entry.id, 
					},
				},
			},
		}
		table.insert(props, element)
	end
	-- sector events
	for _, entry in ipairs(dependings.sector_events or empty_table) do
		local element = {
			id = "fakeprop"..#props,
			name = entry.name,
			default = entry.value,
			category = "Sector Events references",
			editor = "text",
			read_only = true,
			no_edit = function(self)
				return FilterQuestVar(self.FilterQuestVariable, entry.var)
			end,
			buttons = {
				{
					name = "View",
					func = "SatelliteSectorEditorSelect",
					param = {
						preset_id = entry.id, 
					},
				},
			},
		}
		table.insert(props, element)
	end
	-- banters
	for _, entry in ipairs(dependings.banters or empty_table) do
		local element = {
			id = "fakeprop"..#props,
			name = entry.name,
			default = entry.value,
			category = "Banter references",
			editor = "text",
			read_only = true,
			no_edit = function(self)
				return FilterQuestVar(self.FilterQuestVariable, entry.var)
			end,
			buttons = {
				{
					name = "View",
					func = "BanterEditorSelect",
					param = {
						preset_id = entry.id, 
					},
				},
			},
		}
		table.insert(props, element)
	end	return props
end

function SatelliteSectorEditorSelect(root, obj, prop_id, socket, param) 
	CreateRealTimeThread(function()
		OpenSatelliteView(Game.Campaign, {satellite_editor = true})
		if GedSatelliteSectorEditor then
			GedSatelliteSectorEditor:Send("rfnApp", "Exit")
			GedSatelliteSectorEditor = false
		end
		local sectors = GetSatelliteSectors(true)
		GedSatelliteSectorEditor = OpenGedApp("GedSatelliteSectorEditor", sectors) or false
		GedSatelliteSectorEditor:SetSelection("root", table.find(sectors, "Id",param.preset_id))
	end)
end

function GridMarkerEditorSelectDiffMap(root, obj, prop_id, socket, param)
	local map = param.map
	if map and map ~= GetMapName() then
		local res = socket:WaitQuestion(T(926807670091, "Select marker"), T(107076963807, "Changing map, all unsaved changes will be lost!"))
		if res == "ok" then
			CreateRealTimeThread(function(root, obj, prop_id, socket)
				ChangeMap(map)
				Sleep(100)
				GridMarkerEditorSelect(root, obj, prop_id, socket)
			end, root, obj, prop_id, socket)
		end
	else
		GridMarkerEditorSelect(root, obj, prop_id, socket)
	end
end

function OnMsg.ChangeMapDone()
	if g_QuestEditorStateInfo and not ChangingMap and GetMap() ~= "" then
		ObjModified(g_QuestEditorStateInfo)
	end
end

function ConversationEditorSelect(root, obj, prop_id, socket, param)
	CreateRealTimeThread(function(root, obj, prop_id, socket)
		local ged = OpenPresetEditor("Conversation")
		if ged then
		local preset_id = param.preset_id
		 local prop_meta = {id = preset_id, editor = "preset_id", default = preset_id, preset_class = "Conversation"}
			local preset = PresetIdPropFindInstance(obj, prop_meta, preset_id)	
			ged:SetSelection("root", PresetGetPath(preset))
			CreateRealTimeThread(function()
				Sleep(100)
				ged:SetSelection("SelectedPreset", param.sel_path)
			end, param)
		end
	end, root, obj, prop_id, socket)
end

function BanterEditorSelect(root, obj, prop_id, socket, param)
	Banters[param.preset_id]:OpenEditor()
end

function QuestStateInfo:ResetQuest()
	local quest = QuestGetState(self.id) or empty_table
	for key, val in pairs(quest) do
		if key~="note_lines" then
			quest[key] = nil
		end
	end
	ObjModified(Presets.QuestsDef)
	ObjModified(self)
end

if FirstLoad then
	g_QuestEditorStateInfo = false
end

function OnMsg.GedOnEditorSelect(obj, selected, editor)
	if editor and editor.app_template == "QuestsEditor" then
		if selected and rawget(obj, "id") then
			local infoobj = QuestStateInfo:new{ preset = obj, id = obj.id}
			g_QuestEditorStateInfo = infoobj
			editor:BindObj("state", infoobj)
		else
			g_QuestEditorStateInfo = false
		end
	end
end

-- all quest-related Conditions & Effects inherit this class via QuestConditionBase / QuestEffectBase
DefineClass.QuestFunctionObjectBase = { __parents = { "PropertyObject" } }

function QuestGetVariables(quest_id)
	local vars = {}
	for _, key in ipairs(Quests[quest_id] and Quests[quest_id].Variables or empty_table) do
		if key.Name then
			vars[key.Name] = true
		end
	end
	return vars
end

function QuestIsBoolVar(quest, varName, value)
	local val = quest and rawget(quest, varName)
	return val==value
end

function QuestCheckValidVariables()
	local var_cache = {}
	local function check_variable(obj, report_error_fn)
		if obj:HasMember("Vars") then
			local quest_id = obj.QuestId
			local vars = var_cache[quest_id] or QuestGetVariables(quest_id)
			var_cache[quest_id] = vars
			for var, condition in pairs(obj.Vars or empty_table) do
				if not vars[var] then
					report_error_fn(quest_id, var)
				end
			end
		end
	end
	
	ForEachPreset("Conversation", function(preset)
		preset:ForEachSubObject("QuestFunctionObjectBase", function(obj, parents)
			check_variable(obj, function(quest_id, var)
				StoreErrorSource(preset, string.format("Undeclared quest variable %s.%s used in conversation phrase %s", quest_id, var, ComposePhraseId(parents)))
			end)
		end)
	end)
	MapForEachMarker("GridMarker", nil, function(marker)
		marker:ForEachSubObject("QuestFunctionObjectBase", function(obj, parents)
			check_variable(obj, function(quest_id, var)
				StoreErrorSource(marker, string.format("Undeclared quest variable %s.%s used in marker of class %s", quest_id, var, marker.class))
			end)
		end)
	end)
end

if Platform.developer then
	OnMsg.NewMapLoaded = QuestCheckValidVariables
end

local function lEditorViewAbridged(obj, quest_id)
	local value = obj.class
	if obj:HasMember("GetEditorView") then
		value = _InternalTranslate(T{obj:GetEditorView(), obj})
		-- reverse some of the ways GetEditorView mentions the name of this quest to make display more terse, 
		-- without introducing yet another GetEditorView-like function. Note that other quests will be unaffected
		value = value:gsub(" %(" .. quest_id .. "%)", "")
		value = value:gsub("[Qq]uest " .. quest_id .. ":? ", "")
	end
	return value
end

function GedParentsListToSelection(parents)
	local selection = {}
	for i = 2, #parents do
		local idx = table.find(parents[i - 1], parents[i])
		if idx then
			selection[#selection + 1] = idx
		end
	end
	return selection
end

function QuestGatherGameDepending(depending, quest_id, check_var)
	local res 
	PauseInfiniteLoopDetection("QuestGatherGameDepending")
	res = res or QuestGatherRefsFromConversations(depending, quest_id, check_var)
	res = res or QuestGatherRefsFromMaps(depending, quest_id, check_var)
	res = res or QuestGatherRefsFromQuests(depending, quest_id, check_var)
	res = res or QuestGatherRefsFromSectorEvents(depending, quest_id, check_var)
	res = res or QuestGatherRefsFromBanters(depending, quest_id, check_var)
	res = res or QuestGatherRefsFromSetpieces(depending, quest_id, check_var)
	ResumeInfiniteLoopDetection("QuestGatherGameDepending")
	return res
end

function OnMsg.ObjModified(obj)
	if IsKindOf(obj, "Conversation") then
		depending_conversations_cache = {}
	end
end

function QuestGatherRefsFromConversations(depending, quest_id, check_var)
	local cached = depending_conversations_cache[quest_id]
	if cached and not check_var then
		depending.conversations = cached
		return
	end
	
	local out = depending.conversations or {}
	local res = {val = false}
	ForEachPreset("Conversation", function(preset, g, res)
		local rs = preset:ForEachSubObject("QuestFunctionObjectBase", function(obj, parents)
			if obj.QuestId == quest_id then
				local var = rawget(obj, "Prop") or rawget(obj, "Vars")
				if check_var then
					if not FilterQuestVar(check_var, var) then
						return true
					end
				else
					table.insert(out, {
						id = preset.id,
						name = ComposePhraseId(parents),
						value = lEditorViewAbridged(obj, quest_id),
						sel_path = GedParentsListToSelection(parents),
						var = var,
					})
				end
			end
		end)
		if check_var then 
			res.val = rs
			if rs then return "break" end
		end
		preset:ForEachSubObject("ConversationPhrase", function(obj, parents)
			local name = ComposePhraseId(parents, obj)
			local selection = GedParentsListToSelection(parents)
			selection[#selection +1] = table.find(parents[#parents], obj)
			local value
			if table.find(obj.CompleteQuests or empty_table, quest_id) then
				value = "complete quests: " .. table.concat(obj.CompleteQuests, ", ")
				if value then
					table.insert(out, {
						id = preset.id,
						name = name,
						value = value,
						sel_path = selection,
						var = "Completed",
					})
				end
			end
			local value
			if table.find(obj.GiveQuests or empty_table, quest_id) then
				value = "give quests: " .. table.concat(obj.GiveQuests, ", ")
			end
			if value then
				table.insert(out, {
					id = preset.id,
					name = name,
					value = value,
					sel_path = selection,
					var = "Given",
				})
			end
		end)
	end, res)
	if check_var then return res.val end
	depending.conversations = out
	depending_conversations_cache[quest_id] = out
end

function QuestGatherRefsFromMaps(depending, quest_id, check_var)
	local map_name = GetMapName()
	if not g_DebugMarkersInfo[map_name] then
		GatherMarkerScriptingData()
	end
	local out = depending.markers or {}
	-- filter for current quest_id
	local res
	ForEachDebugMarkerData("quest", quest_id, function(marker_info, res_item_info) 
		if check_var then
			if not FilterQuestVar(check_var, res_item_info.var) or not FilterQuestVar(check_var, res_item_info.var2) then
				res = true
			end
		else
			local t = {
				type = marker_info.type,
				name = marker_info.name,
				path = marker_info.path,
				handle = marker_info.handle,
				map = marker_info.map,

				reference_id = res_item_info.reference_id,
				value = res_item_info.editor_view_abridged,
				var = res_item_info.var,
			}
			out[#out + 1] = t
		end
	end)
	if check_var then return res end
	depending.markers = out
end

function QuestGatherRefsFromPreset(preset, out, quest_id, check_var)
	return preset:ForEachSubObject("QuestFunctionObjectBase", function(obj, parents)
		if obj.QuestId == quest_id then
			local var = rawget(obj, "Prop") or rawget(obj, "Vars")
			local var2 = rawget(obj, "Prop2")
			local idx = parents[2] and rawget(parents[2], "Idx")
			if check_var then
				if not FilterQuestVar(check_var, var) or not FilterQuestVar(check_var, var2) then
					return true
				end	
			else	
				table.insert(out, {
					id = preset.id,
					name = ComposeSubobjectName(parents).. (idx and "#"..idx or "") ,
					value = EditorViewAbridged(obj, quest_id, "quest"),
					var = var,
					class = obj.class,
				})
			end
		end
	end)
end

function QuestGatherRefsFromQuests(depending, quest_id, check_var)
function QuestGatherRefsFromQuests(depending, quest_id, check_var)
	local out = depending.quests or {}
	local res = {val = false}
	ForEachPreset("QuestsDef", function(preset, group, res)
		res.val = QuestGatherRefsFromPreset(preset, out, quest_id, check_var)
		if check_var and res.val then
			return "break"
		end	
	end, res)
	if check_var then return res.val end
	depending.quests = out
end
end

function QuestGatherRefsFromBanters(depending, quest_id, check_var)
	local out = depending.banters or {}
	local res = {val = false}
	ForEachPreset("BanterDef", function(preset, group, res)
		res.val = QuestGatherRefsFromPreset(preset, out, quest_id, check_var)
		if check_var and res.val then
			return "break"
		end	
	end, res)
	if check_var then return res.val end
	depending.banters = out
end

function QuestGatherRefsFromSetpieces(depending, quest_id, check_var)
	local out = depending.setpieces or {}
	local res = {val = false}
	ForEachPreset("SetpiecePrg", function(preset, group, res)
		res.val = QuestGatherRefsFromPreset(preset, out, quest_id, check_var)
		if check_var and res.val then
			return "break"
		end	
	end, res)
	if check_var then return res.val end
	depending.setpieces = out
end


-- sectors
function QuestGatherRefsFromSectorEvents(depending, quest_id, check_var)
	local out = depending.sector_events or {} 
	local idx = 0
	for sector_id, preset in pairs(gv_Sectors) do
		idx = idx+1
		local events = preset.Events
		for _, event in ipairs(events) do
			local res
			res = event:ForEachSubObject("QuestFunctionObjectBase", function(obj, parents)
				if obj.QuestId == quest_id then
					local var = rawget(obj, "Prop") or rawget(obj, "Vars")
					if check_var then
						if not FilterQuestVar(check_var, var) then
							return true
						end
					else
						table.insert(out, {
							id = sector_id, 
							idx = idx,
							name = sector_id.."."..ComposeSubobjectName(parents),
							value = EditorViewAbridged(obj, quest_id),
							var = var,
							class = obj.class,
						})
					end
				end
			end)
			if res then return true end
		end	
	end
	if check_var then return end
	depending.sector_events = out
end

--- Bug report log
function QuestBugReportInfo(quest_id)
	local quest = gv_Quests[quest_id]
	local texts = {}
	--variables
	if quest.Variables and next(quest.Variables) then
		local added =  false
		for _, var in ipairs(quest.Variables or empty_table) do
			local name = var.Name
			local proptype = var.class
			if name and proptype ~= "QuestVarTCEState" then
				local val =  rawget(quest, name)==nil and var.Value or quest[name]
				texts[#texts + 1] = string.format("%s = %s,",name,tostring(val))
			end
		end
	end
	--TriggeredConditionalEvent
	for _, tce in ipairs(quest.TCEs or empty_table) do
		texts[#texts + 1] = string.format("TCE %s: %s,", tce.ParamId, tostring(quest[tce.ParamId]))
		if QuestIsBoolVar(quest,"Given", true) and next(tce.Conditions) then	
			for __, cond in ipairs(tce.Conditions or empty_table) do
				local name = _InternalTranslate(cond:GetEditorView(), cond)
				texts[#texts + 1] = string.format("\t%s: %s,", name, tostring(not not cond:Evaluate()))
			end
		end
	end

	if quest.note_lines and next(quest.note_lines) then
		for idx, unlockTime in pairs(quest.note_lines or empty_table) do
			local linedef = quest.NoteDefs and table.find_value(quest.NoteDefs, "Idx", idx)
			local state = quest.notes_state and quest.notes_state[idx] or ""
			texts[#texts + 1] = string.format("\t[%d] %d (%s) %s", idx, unlockTime or -1, state, linedef and tostring(_InternalTranslate(linedef.Text) or ""))
		end
	end
	return table.concat(texts, "\n\t\t\t") .. "\n"
end

function OnMsg.BugReportStart(print_func, bugreport_dlg)
	local quests = gv_Quests or empty_table
	if not quests or not next(quests) then
		print_func("Quests status: No active quests")
	else
		print_func("Quests status:")
		local q_statuses = {}
		for id, quest_state in pairs(quests) do
			local status = "__invalid"
			if QuestIsBoolVar(quest_state,"Completed",true) then
				status = "completed"
			end
			if QuestIsBoolVar(quest_state,"NotStarted", true) then
				status = "not_started"
			end
			if QuestIsBoolVar(quest_state,"Given", true) then
				status = "given"
			end
			if QuestIsBoolVar(quest_state,"Failed", true) then
				status = "failed"
			end
			q_statuses[status] = q_statuses[status] or {}
			table.insert(q_statuses[status], id)
		end
		-- completed
		if q_statuses["completed"] then
			print_func(string.format("\tCompleted: %s",table.concat(q_statuses["completed"], ", ")))
		end
		-- not started
		if q_statuses["not_started"] then
			print_func(string.format("\tNot started: %s",table.concat(q_statuses["not_started"], ", ")))
		end
		q_statuses["completed"] = nil
		q_statuses["not_started"] = nil
		-- given and other
		for status, tbl in sorted_pairs(q_statuses) do
			print_func(string.format("\t%s:",status))
			for _, id in ipairs(tbl) do
				print_func(string.format("\t\tquest %s (%s):\n\t\t\t%s", id, status, QuestBugReportInfo(id)))
			end
		end		
	end
end

function GedOpDeleteQuest(ged, presets, selection)
	local group_idx = selection[1][1]
	local group = presets[group_idx]
	local sel_presets = selection[2]
	local texts = {}
	for _, presetidx in ipairs(sel_presets) do
		local preset_id = group[presetidx].id
		local dependings = {}
		QuestGatherGameDepending(dependings, preset_id)
		if next(dependings) then
			if next(dependings.conversations) or next(dependings.markers) then
				texts[#texts + 1] = preset_id.." is used in:"
			end	
			if next(dependings.conversations) then
				texts[#texts + 1] = "\tConversations:"
				for _, phrases_id in ipairs(dependings.conversations) do
					table.insert_unique(texts, "\t\t" .. phrases_id.name)
				end
			end
			if next(dependings.markers) then
				texts[#texts + 1] = "\tMarkers:"
				for _, marker_data in ipairs(dependings.markers) do
					table.insert_unique(texts, "\t\t" .. marker_data.name)
				end
			end
		end
	end	
	if next(texts) then
		local res = ged:WaitQuestion(T(205508473171, "Confirm Delete"), Untranslated("Quest(s) are in use and deleting them will result in an inconsistent state:\n\n"..table.concat(texts,"\n")))
		if res == "ok" then
			return GedOpPresetDelete(ged, presets, selection)
		end	
	else
		return GedOpPresetDelete(ged, presets, selection)
	end
end

DefineClass.QuestEditorFilter = {
	__parents = { "GedFilter", "XEditorToolSettings" },
	properties = {
		{ id = "Chapter", editor = "choice", default = "All", items = PresetsPropCombo("QuestsDef", "Chapter", "All") },
		{ id = "CheckVars", name = "Check for unreferences variables (slow!)", editor = "bool", default = false, persisted_setting = true, },
	}
}

function QuestEditorFilter:FilterObject(quest)
	local chapter = self:GetProperty("Chapter")
	return chapter == "All" or quest.Chapter == chapter
end

function QuestEditorFilter:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "CheckVars" and self:GetProperty("CheckVars") and not IsValidThread(DiagnosticMessageActivateGedThread) then
		InitializeWarningsForGedEditor(ged, "initial")
	end
	GedFilter.OnEditorSetProperty(self, prop_id, old_value, ged)
end

----------------------------- QuestLog Dialog ---------------------

function GetQuestsList(show_hidden)
	local quests = gv_Quests or empty_table
	if not quests then
		return {}
	end
	local list = {}
	for id, quest_state in sorted_pairs(quests) do
		if (not quest_state.Hidden or show_hidden) and QuestIsBoolVar(quest_state, "Given", true) then
			list[#list +1] = id
		end	
	end
	return list
end

function FormatQuestLineUI(line, quest, lineState)
	if not lineState or lineState == "invisible" then return end
	-- todo: different styles for disabled and completed
	return T{line.Text, quest}
end

function GetAllQuestsForTracker(loadingScreenForSector)	
	--Get all quests related to that sector (if not in satellite)
	local allActiveQuestsForSector = {} 
	if not GetDialog("PDADialogSatellite") or loadingScreenForSector then
		for _, quest in ipairs (GetQuestsAssociatedWithSector(loadingScreenForSector or gv_CurrentSectorId)) do
			if not quest.Completed and not quest.Failed then
				table.insert(allActiveQuestsForSector, quest.preset.id)
			end
		end
	end
	
	--if no quest for the current sector are found, add the tracked quest
	local onlyTrackedQuest = false
	if not next(allActiveQuestsForSector) and GetActiveQuest() and GetDialog("PDADialogSatellite") then
		if not gv_Quests[GetActiveQuest()].Completed and not gv_Quests[GetActiveQuest()].Failed then
			table.insert(allActiveQuestsForSector, GetActiveQuest())
			onlyTrackedQuest = true
		end
	end
	
	local questsTableForTracker = {}
	for _, questId in ipairs(allActiveQuestsForSector) do
		local notesData = GetQuestNotesTracker(questId, onlyTrackedQuest and questId == GetActiveQuest(), loadingScreenForSector)
		table.insert(questsTableForTracker, {Name = Quests[questId].DisplayName, Notes = notesData, Id = questId})
	end
	
	return questsTableForTracker
end

function GetQuestNotesTracker(quest_id, tracked, sectorId)
	local quest = gv_Quests and gv_Quests[quest_id]
	if not quest then return end

	-- Collect visible notes
	local lines = {}
	for _, line in ipairs(quest.NoteDefs or empty_table) do
		local state
		local shown = rawget(quest, "note_lines")
		local timeShown = shown and shown[line.Idx]
		if timeShown then
			state = "visible"
			local stateTable = rawget(quest, "notes_state")
			if stateTable and stateTable[line.Idx] then
				state = stateTable[line.Idx]
				if state == "completed" then goto continue end -- Dont show completed in quest tracker.
			end
		else
			state = "invisible"
		end

		local formattedText = FormatQuestLineUI(line, quest, state)
		if formattedText then
			lines[#lines + 1] = { timeShown or 0, formattedText, line.Badges, line }
		end

		::continue::
	end
	
	-- Sort by time
	table.sort(lines, function(a, b)
		return a[1] > b[1]
	end)
	
	local oneAdditionForTracked = false
	-- Format text
	for i, data in ipairs(lines) do
		if not tracked then
			if table.find(data[3], "Sector", sectorId or gv_CurrentSectorId) then
				--if not tracked, return latest note related to the sector
				return { {Text = data[2], note = data[4]} }
			end
		else
			--return latest notе if the quest is tracked
			return { {Text = data[2], note = data[4]} }
		end
	end
	
	return {}
end

function OnMsg.CloseSatelliteView()
	ObjModified(gv_Quests)
end

function GetQuestNoteLinesCombo(quest_id)
	local quest = Quests[quest_id]
	local lines = {{value = 0,text = ""}}
	if not quest then return lines end
	for idx, line in ipairs(quest.NoteDefs or empty_table) do
		lines[#lines + 1] = {text = _InternalTranslate(line.Text), value = line.Idx}
	end
	return lines
end

function UpdateQuestLog()
	ObjModified(gv_Quests)
	if g_QuestEditorStateInfo then
		ObjModified(g_QuestEditorStateInfo)
	end
end

local function lTableAnyTruthy(table)
	for i, v in pairs(table) do
		if v then return true end
	end
	return false
end

function GetAllQuestsWithVisibleNotesList()
	local quests = gv_Quests or empty_table
	if not quests then
		return {}
	end
	local list = {}
	for id, quest_state in sorted_pairs(quests) do
		local notes = quest_state.note_lines
		if lTableAnyTruthy(notes) then
			list[#list +1] = id
		end	
	end
	return list
end

function GetActiveQuest()
	local currentQuests = GetAllQuestsWithVisibleNotesList()
	local firstQuest, firstMainQuest = false
	for i, id in ipairs(currentQuests) do
		local questPreset = Quests[id]
		local questState = gv_Quests[id]
		if questPreset and not QuestIsBoolVar(questState, "Completed", true) then
			if questState.ActiveQuest then
				return id
			end
			if questPreset.Main and not firstMainQuest then
				firstMainQuest = id
			end
			if not firstQuest then
				firstQuest = id
			end
		end
	end
	
	-- If no active quest found, return the first main quest as active.
	if firstMainQuest then
		return firstMainQuest
	end
	
	-- Otherwise return the first quest. It is possible for there to be none.
	return firstQuest
end

function SetActiveQuest(questId)
	for i, s in pairs(gv_Quests) do
		s.ActiveQuest = false
	end
	gv_Quests[questId].ActiveQuest = true
	ObjModified(gv_Quests)
	Msg("ActiveQuestChanged")
end

function SetActiveQuestOrderBased(direction)
	local currentActive = GetActiveQuest()
	local _, questLogData = GetQuestLogData()
	local currentQuestIdx = table.find(questLogData, "id", currentActive)
	if not currentQuestIdx then return end

	local pointer = currentQuestIdx
	repeat
		if direction == "previous" then
			pointer = pointer - 1
		elseif direction == "next" then
			pointer = pointer + 1
		else -- Invalid direction
			break
		end
		if pointer < 1 then
			pointer = #questLogData
		elseif pointer > #questLogData then
			pointer = 1
		end

		local quest = questLogData[pointer]
		if quest.listId ~= "completed" then
			SetActiveQuest(quest.id)
			return
		end
	until pointer == currentQuestIdx
end

function OnMsg.QuestParamChanged() UpdateQuestLog() end
function OnMsg.QuestLinesUpdated() UpdateQuestLog() end
function OnMsg.LoyaltyChanged() UpdateQuestLog() end
function OnMsg.SectorSideChanged() UpdateQuestLog() end

QuestToSectorCache = false
QuestToHiddenBadgesCache = false

function OnMsg.PresetSave() -- Quests changed
	QuestToSectorCache = false
end

-- Quests contain notes, notes contain badges which are associated with sectors.
-- A quest is considered associated with a sector if it has an active note with a badge on that
-- sector and the badge isn't currently hidden.
function BuildQuestToSectorCache()
	if QuestToSectorCache then
		if QuestToSectorCache.gameId == Game.id then
			return
		end
	end
	QuestToSectorCache = {
		gameId = Game.id
	}
	
	for questName, questPreset in pairs(Quests) do
		for i, notePreset in ipairs(questPreset.NoteDefs) do
			local badges = notePreset and notePreset.Badges
			if not badges then goto continue end
			
			for badgeIdx, badge in ipairs(badges) do
				if not badge.Sector then goto continue end
				
				local sectorList = QuestToSectorCache[badge.Sector]
				if not sectorList then
					sectorList = {}
					QuestToSectorCache[badge.Sector] = sectorList
				end
				
				local questItem = table.find_value(sectorList, "name", questName)
				if not questItem then
					questItem = {
						name = questName,
						preset = questPreset,
						notes = {}
					}
					sectorList[#sectorList + 1] = questItem
				end
				
				local notes = questItem.notes
				local noteItem = table.find_value(notes, "noteIdx", notePreset.Idx)
				if not noteItem then
					noteItem = {
						noteIdx = notePreset.Idx,
						preset = notePreset,
						badges = {}
					}
					notes[#notes + 1] = noteItem
				end
				noteItem.badges[#noteItem.badges + 1] = badgeIdx
				
				::continue::
			end
			
			::continue::
		end
	end
end

function BuildHiddenBadgesCache()
	if QuestToHiddenBadgesCache then
		-- Since this is mass called from the UI without yielding will not have advanced.
		-- This way we can be sure they didn't change.
		if QuestToHiddenBadgesCache.time == RealTime() then
			return
		end
	end
	QuestToHiddenBadgesCache = {
		time = RealTime()
	}
	
	for questName, questPreset in pairs(Quests) do
		QuestToHiddenBadgesCache[questName] = GetQuestHiddenBadges(questName)
	end
end

function GetAllQuestsAssociatedWithSector(sector_id, list, onlyThisQuest)
	if not gv_Quests or not Game then return false end

	BuildQuestToSectorCache()
	BuildHiddenBadgesCache()
	
	local sectorList = QuestToSectorCache[sector_id]
	for i, questItem in ipairs(sectorList) do
		local questPreset = questItem.preset
		local questState = gv_Quests[questPreset.id]
		if not questPreset or not questState then goto continue end
		if QuestIsBoolVar(questState, "Completed", true) then goto continue end
		if onlyThisQuest and onlyThisQuest ~= questState then goto continue end
		
		local questName = questPreset.id
		local questNoteEnabled = questState.note_lines or empty_table
		local questNoteState = questState.notes_state or empty_table
		local hiddenNotes = QuestToHiddenBadgesCache[questName]
		
		local questDesc = false
		local notes = false
		for i, noteItem in ipairs(questItem.notes) do
			local notePreset = noteItem.preset
			local noteIdx = notePreset.Idx
			local timeEnabled = questNoteEnabled[noteIdx]
			if not timeEnabled then goto continue end
			
			local noteState = questNoteState[noteIdx]
			if noteState == "completed" then goto continue end
			
			-- Check if any of the note's badges which place it on this sector are currently hidden.
			-- In which case the quest is not on the sector.
			local hiddenBadges = hiddenNotes and hiddenNotes[noteIdx] or empty_table
			local badges = noteItem.badges
			local anyShown = false
			for i, badgeIdx in ipairs(badges) do
				if not hiddenBadges[badgeIdx] then
					anyShown = true
					break
				end
			end
			if not anyShown then goto continue end
			
			-- Add the note and quest to the list.
			if not notes then notes = {} end
			notes[#notes + 1] = { time = timeEnabled, Text = notePreset.Text }
			
			if not questDesc then
				questDesc = {
					preset = questPreset,
					state = questState,
					notes = notes
				}
				if not list then list = {} end
				list[#list + 1] = questDesc
			end
			
			::continue::
		end
		
		::continue::
	end
	
	for i, q in ipairs(list) do
		table.sortby_field(q.notes, "time")
	end
	
	if list then
		table.sort(list, function(a, b)
			local firstNoteA = a.notes and a.notes[1]
			local firstNoteB = b.notes and b.notes[1]
			return firstNoteA.time > firstNoteB.time
		end)
	end
	
	return list
end

-- Quests are considered associated with a sector when it has a badge on that sector
function GetQuestsAssociatedWithSector(sector_id, active_only)
	local quests = false

	if active_only then
		local activeQuest = GetActiveQuest()
		activeQuest = activeQuest and gv_Quests[activeQuest]
		if activeQuest then
			quests = GetAllQuestsAssociatedWithSector(sector_id, false, activeQuest)
		end
	else
		quests = GetAllQuestsAssociatedWithSector(sector_id, false)
	end

	return quests or empty_table
end

-- Quest badge logic

badgeFromLineParamIdentifier = "line_badge:" -- Badges placed by quest lines
badgeParamIdentifier = "badge:" -- Badges placed by the SetBadgeEffect
badgeRemoveIdentifier = "remove:" -- Used in the preset name of badges placed by the SetBadgeEffect when requested to be deleted
badgeHideIdentifierNote = "hide_n:" -- Used by HideQuestBadge to hide badges placed by notes
badgeHideIdentifierLine = "hide_l:" -- ^ but by log lines


function OnMsg.QuestParamChanged(questId)
	-- Update only related quest badges.
	UpdateQuestBadges(questId) -- Update badges for self
	for id, times in pairs(gv_QuestRelations[questId]) do -- And for affected quests
		UpdateQuestBadges(id)
	end
	
	-- TODO: Only update sectors related to the quest. ??
	if g_SatelliteUI then
		g_SatelliteUI:DelayedUpdateAllSectorVisuals()
	end
end
function OnMsg.QuestLinesUpdated(quest) UpdateQuestBadges(quest) end
function OnMsg.EnterSector() UpdateAllQuestBadges() end
function OnMsg.ActiveQuestChanged()
	UpdateAllQuestBadges()
end

local function lFindTargetForQuestBadge(groupName, all, isRemove)
	if all then
		local filteredUnits = table.ifilter(g_Units, function(i, u)
			return u.unitdatadef_id == groupName or u:IsInGroup(groupName)
		end)
		local markers = MapGetMarkers("GridMarker", groupName, function(m)
			return not IsKindOf(m, "UnitMarker")
		end)
		if not markers or #markers == 0 then
			return filteredUnits
		elseif #filteredUnits == 0 then
			return markers
		else
			return table.iappend(filteredUnits, markers)
		end
	else
		for i, u in ipairs(g_Units) do
			if u.unitdatadef_id == groupName or u:IsInGroup(groupName) then
				return {u}
			end
		end
		local marker = MapGetFirstMarker("GridMarker", function(m)
			return m:IsInGroup(groupName) and not IsKindOf(m, "UnitMarker")
		end)
		if IsKindOf(marker, "Interactable") then
			local visual = ResolveInteractableVisualObjects(marker, nil, nil, "findFirst")
			if not visual then
				if isRemove then return {marker} end
				return false
			end
		end
		
		if marker then return {marker} end
	end
	
	return false
end

function UpdateAllQuestBadges()
	for id, q in pairs(gv_Quests) do
		UpdateQuestBadges(q)
	end
end

function GetQuestHiddenBadges(questId)
	local questState = gv_Quests[questId]
	local hiddenNotes = false
	
	for name, p in pairs(questState) do
		if type(name) ~= "string" then goto continue end
		local prefix = name:starts_with(badgeHideIdentifierNote) and badgeHideIdentifierNote or
			name:starts_with(badgeHideIdentifierLine) and badgeHideIdentifierLine
		if not prefix then goto continue end
			
		local params = string.split(name:sub(#prefix + 1), "@")
		
		local lineIdx = params[1] or 1
		local badgeIdx = params[2] or 1
		if lineIdx then lineIdx = tonumber(lineIdx) end
		if badgeIdx then badgeIdx = tonumber(badgeIdx) end
		
		-- Lazily allocate
		if not hiddenNotes then hiddenNotes = {} end
		
		local arr = hiddenNotes[lineIdx]
		if not arr then
			hiddenNotes[lineIdx] = {}
			arr = hiddenNotes[lineIdx]
		end
		arr[badgeIdx] = true
		 
		::continue::
	end
	
	return hiddenNotes
end

function UpdateQuestBadges(quest)
	local shouldHaveBadges = {}
	local questId = type(quest) == "string" and quest or quest.id
	local questPreset = Quests[questId]
	local questState = gv_Quests[questId]
	if not questState or QuestIsBoolVar(questState, "Given", false) then return end
	local completedQuest = QuestIsBoolVar(questState, "Completed", true)

	local hiddenNotes = GetQuestHiddenBadges(questId)
	local isActiveQuest = true --questId == GetActiveQuest()
	
	-- Check quest notes for badges
	if isActiveQuest then
		for idx, timeEnabled in pairs(questState.note_lines) do
			local preset = table.find_value(questPreset.NoteDefs, "Idx", idx)
			local badges = preset and preset.Badges
			if not badges or not timeEnabled then goto continue end

			-- Don't show badges of completed lines.
			local state = questState.notes_state
			if state and state[idx] == "completed" then goto continue end

			local hiddenBadges = hiddenNotes and hiddenNotes[idx] or empty_table
			for i, badge in ipairs(badges) do
				if (not badge.Sector or badge.Sector == gv_CurrentSectorId) and badge.BadgeUnit and not hiddenBadges[i] then
					shouldHaveBadges[#shouldHaveBadges + 1] = {
						unit = badge.BadgeUnit,
						preset = badge.BadgePreset,
						place_on_all = badge.PlaceOnAllOfGroup
					}
				end
			end
			::continue::
		end
	end

	-- Remove badges which should no longer stay
	for name, p in pairs(questState) do
		if type(name) ~= "string" then goto continue end

		local effectPlaced = name:starts_with(badgeParamIdentifier)		
		local prefix = name:starts_with(badgeFromLineParamIdentifier) and badgeFromLineParamIdentifier or
			effectPlaced and badgeParamIdentifier
		if not prefix then goto continue end
		
		local unitName = name:sub(#prefix + 1)
		
		-- Ensure badges added by the BadgeSetEffect stay.
		if effectPlaced then
			if p:starts_with(badgeRemoveIdentifier) then
				p = p:sub(#badgeRemoveIdentifier + 1)
			else
				shouldHaveBadges[#shouldHaveBadges + 1] = { unit = unitName, preset = p, dontAddParam = true }
				goto continue -- No reason to make it look, as we just added it
			end
		end
		
		-- Check if the badge is in the should stay list.
		local shouldStay = table.find(shouldHaveBadges, "unit", name:sub(#prefix + 1))
		if shouldStay then goto continue end
		
		-- Remove.
		questState[name] = nil
		local units = lFindTargetForQuestBadge(unitName, true, "remove")
		for i, unit in ipairs(units) do
			--CombatLog("debug", "Despawned quest badge from " .. unitName)
			DeleteBadgesFromTargetOfPreset(p, unit)
		end

		::continue::
	end
	
	-- Spawn badges which should exist.
	for i, sh in ipairs(shouldHaveBadges) do
		local preset = sh.preset
		local unitName = sh.unit

		if not unitName then
			StoreErrorSource(questPreset, "Invalid unit name for badge from quest, log line preset", ValueToLuaCode(preset))
			goto continue
		end

		-- Badges set by effects on the quest already exist as params.
		if not sh.dontAddParam then
			local paramName = badgeFromLineParamIdentifier .. unitName
			questState[paramName] = sh.preset
		end

		local targetsForBadge = lFindTargetForQuestBadge(unitName, sh.place_on_all)
		-- Spawn the badge only if missing
		for i, unitTarget in ipairs(targetsForBadge) do
			local hasBadgeOfPreset = g_Badges[unitTarget] and table.find(g_Badges[unitTarget], "preset", preset)
			local enabled = not IsKindOf(unitTarget, "GridMarker") or unitTarget:IsMarkerEnabled()
			if not enabled and hasBadgeOfPreset then
				--CombatLog("debug", "Despawned quest badge from disabled marker " .. unitName)
				DeleteBadgesFromTargetOfPreset(sh.preset, unitTarget)
			elseif enabled and not hasBadgeOfPreset then
				--CombatLog("debug", "Spawned quest badge on " .. unitName)
				CreateBadgeFromPreset(sh.preset, unitTarget, questId)
				if IsKindOf(unitTarget, "Interactable") then
					unitTarget.discovered = true
				end
			end
		end
		
		::continue::
	end
end

-- Quest hint
----------------------------

function ShowQuestScoutingNote(noteTuple)
	local questId = noteTuple[1]
	local questPreset = Quests[questId]
	local questState = gv_Quests[questId]
	assert(questPreset)
	
	local found = false
	local noteId = noteTuple[2]
	for i, note in ipairs(questPreset.NoteDefs) do
		local idx = note.Idx
		if idx == noteId then
			questState.note_lines[idx] = GetQuestNoteCampaignTimestamp(questState.note_lines)
			found = note
		end
	end
	assert(found)
	return found
end

local function lGetQuestScoutingNotesInSector(questDef, sectors)
	local validNotes = false
	for i, note in ipairs(questDef.NoteDefs) do
		if not note.Scouting then goto continue end
		if not EvalConditionList(note.ShowConditions) then goto continue end
	
		local badges = note.Badges
		for i, b in ipairs(badges) do
			if table.find(sectors, b.Sector) then
				if not validNotes then validNotes = {} end
				validNotes = { questDef.id, note.Idx }
			end
		end
		
		::continue::
	end
	
	return validNotes
end

function GetQuestsThatCanProvideHints(sectorId)
	local _, sectorsAround = GetAvailableIntelSectors(sectorId)
	local questsWithHintsAvailable = {}
	for name, questDef in sorted_pairs(Quests) do
		local questState = gv_Quests[name]
		local questNonGivenOrGiven = (QuestIsBoolVar(questState, "Given", true) or QuestIsBoolVar(questState, "NotStarted", true))
		local notes = lGetQuestScoutingNotesInSector(questDef, sectorsAround)
		if questNonGivenOrGiven and notes then
			questsWithHintsAvailable[#questsWithHintsAvailable + 1] = notes
		end
	end
	
	return questsWithHintsAvailable
end

function IsBoatAvailable()
	return true
end

function GetQuestRewardConstItems()
	local res = {}
	for k,v in pairs(const) do
		if k:starts_with("XPQuestReward") then
			res[#res+1] = { k, v }
		end
	end
	table.sortby_field(res, 2)
	return table.map(res, 1)
end

-- Tutorial Hints
GameVar("TutorialHintsState", function() return { visible = {}, mode = {} } end)

function OpenHelpMenu(atHint)
	local parent = false
	local pda = GetDialog("PDADialog")
	if pda then
		parent = pda.idDisplayPopupHost
	end
	local popupUI = XTemplateSpawn("PopupNotification", parent, TutorialGetHelpMenuHints())
	popupUI:Open()
	popupUI.idHintChoices:SetVisible(true)
	popupUI.idPopupTitle:SetText(T(174457905586, "HELP TOPICS"))
	popupUI:SetSelectedHint(atHint)
end

function TutorialGetHelpMenuHints()
	local state = TutorialHintsState
	if not state then return empty_table end
	
	local byMode = {}
	for hintId, hintPreset in sorted_pairs(TutorialHints) do
		local hintVisible = state.visible[hintId]
		if not hintVisible then goto continue end
		
		if hintPreset.group == "TutorialPopups" then goto continue end
		
		local mode = state.mode[hintId] or "visible"
		if not byMode[mode] then byMode[mode] = {} end
		
		local data = { 
			preset = hintPreset,
			popupPreset = PopupNotifications[hintPreset.PopupId],
			Title = hintPreset.PopupId and PopupNotifications[hintPreset.PopupId].Title or Untranslated("UNTITLED"),
			Text = hintPreset.Text,
			mode = mode,
			id = hintId
		}
		table.insert(byMode[mode], data)
		::continue::
	end
	
	-- Sort all modes alphabetically
	for i, modeTable in pairs(byMode) do
		TSort(modeTable, "Text", true)
	end
	
	local modeSorted = {}
	local dismissed = byMode["dismissed"] or empty_table
	local function AddToArray(mode)
		local modeArray = byMode[mode] or empty_table
		table.iappend(modeSorted, modeArray)
	end
	AddToArray("dismissed")
	AddToArray("completed")
	AddToArray("ui-hidden")
	AddToArray("visible")
	
	return modeSorted
end

function TutorialIsHintRead(context)
	local hintId = context.preset.id
	local read = TutorialHintsState.read and TutorialHintsState.read[hintId]
	return read
end

function TutorialGetCurrentHints()
	local state = TutorialHintsState
	if not state then return empty_table end
	
	local tutorialHints = {}
	for hintId, hintPreset in sorted_pairs(TutorialHints) do
		local hintVisible = state.visible[hintId]
		local mode = state.mode[hintId]
		if hintVisible and (mode ~= "completed" and mode ~= "ui-hidden" and mode ~= "dismissed") then
			tutorialHints[#tutorialHints + 1] = { 
				preset = hintPreset,
				Title = hintPreset.PopupId and PopupNotifications[hintPreset.PopupId].Title or Untranslated("UNTITLED"),
				Text = hintPreset.Text
			}
		end
	end
	return tutorialHints
end

function TutorialDismissHint(hintPreset)
	TutorialHintsState.mode[hintPreset.id] = "dismissed"
	ObjModified(TutorialHintsState)
end

function OnMsg.OpenSatelliteView()
	TutorialHintVisibilityEvaluate()
end

-- http://mantis.haemimontgames.com/view.php?id=172918
function TutorialHintVisibilityEvaluate()
	local state = TutorialHintsState
	if not state then return end
	
	for hintId, note in sorted_pairs(TutorialHints) do
 		local mode = state.mode[hintId]
		if mode == "completed" or mode == "dismissed" then goto continue end

		local updated = false
		local hide = note.HideConditions and #note.HideConditions > 0 and EvalConditionList(note.HideConditions, note) 
		local currentHidden = mode == "ui-hidden"
		if hide ~= currentHidden then
			state.mode[hintId] = hide and "ui-hidden" or false
			updated = true
		end
		
		if not state.visible[hintId] and EvalConditionList(note.ShowConditions, note) then
			state.visible[hintId] = GetQuestNoteCampaignTimestamp()
			if g_Combat then TutorialHintsState.IsHintPerTurnPlayed = true end
			updated = true
			
			if note.PopupId and note.group ~= "StartingHelp" then
				CreateRealTimeThread(function()
					WaitPlayerControl({ skip_popup = true, no_coop_pause = true })
					WaitLoadingScreenClose()
					ShowPopupNotification(note.PopupId)
				end)
			end
		end
		
		if state.visible[hintId] and EvalConditionList(note.CompletionConditions, note) then
			state.mode[hintId] = "completed"
			updated = true
		end
		
		if updated then
			DelayedCall(0, ObjModified, TutorialHintsState)
		end
		
		::continue::
	end
end

function OnMsg.OnBandage(healer,self)
	local playerSide = self.team:IsPlayerControlled() and healer.team:IsPlayerControlled()
	if TutorialHintsState.visible.CombatHeal and not TutorialHintsState.mode.CombatHeal and self and healer and playerSide then
		TutorialHintsState.IsBandaged = true
	end
	
	if playerSide then
		TutorialHintsState.Bandage = true -- new tutorial
	end
end

function OnMsg.OperationCompleted(self, mercs)
	if self.id == "TreatWounds" then TutorialHintsState.TreatWoundsCompleted = true end
	if self.id == "MilitiaTraining" then TutorialHintsState.TrainMilitiaCompleted = true end
end

function OnMsg.OverwatchChanged(unit)
	if TutorialHintsState.IsHintPerTurnPlayed then return end
	if not TutorialHintsState.Overwatch and unit and unit.command == "OverwatchAction" and not unit:IsMerc() then 
		for _, obj in ipairs(g_Units) do
			if IsMerc(obj) and obj:IsThreatened() then
				TutorialHintsState.Overwatch = true
				break
			end
		end
	elseif not TutorialHintsState.PinDown and unit and unit.command == "PinDown" and not unit:IsMerc() and unit.aim_args and unit.aim_args.target and unit.aim_args.target:IsMerc() then
		TutorialHintsState.PinDown = true 
	end
end

function OnMsg.UnitDowned(unit)
	if not TutorialHintsState.IsHintPerTurnPlayed and not TutorialHintsState.UnitDowned and unit:IsMerc() and not unit:HasStatusEffect("Unconscious") then 
		TutorialHintsState.UnitDowned = unit 
	end
end

function OnMsg.SquadStartedTravelling(squad)
	for _, entry in pairs(squad.route) do
		if type(entry) == "table" then 
			if HasWaterTravel(entry) then
				TutorialHintsState.BoatTutorial = true
				break
			end
		end
	end
end

function OnMsg.TurnStart(g_CurrentTeam)
	if (g_Teams[g_CurrentTeam].side == "player1" or g_Teams[g_CurrentTeam].side == "player2") then 
		TutorialHintsState.IsHintPerTurnPlayed = false
		if g_Combat.current_turn > 2 and gv_CurrentSectorId ~= "I1" then
			TutorialHintsState.ReconTutorial = true
		end
	end
end

function OnMsg.CombatEnd()
	TutorialHintsState.IsHintPerTurnPlayed = false
end

function FirstMove(unit)
	if not TutorialHintsState.FirstMove and unit:IsMerc() then
		TutorialHintsState.FirstMove = true
	end
end

function OnMsg.UnitGoToStart(self)
	FirstMove(self)
end

function OnMsg.UnitMovementStart(self)
	FirstMove(self)
end

function OnMsg.MoraleChange()
	if not TutorialHintsState.IsHintPerTurnPlayed and not TutorialHintsState.MoraleChange and (not gv_SatelliteView and gv_CurrentSectorId ~= "I1") then
		TutorialHintsState.MoraleChange = true
	end
end

function OnMsg.OnAttack(self, action, target, results, attack_args)
	if results.aim and results.aim > 0 then
		TutorialHintsState.SecondAimedTutorial = gv_CurrentSectorId ~= "I1" and gv_CurrentSectorId ~= "I2" and TutorialHintsState.FirstAimedTutorial and true
		TutorialHintsState.FirstAimedTutorial = gv_CurrentSectorId == "I2" and true
	end
	TutorialHintsState.WeaponRange = TutorialHintsState.WeaponRangeShown and true
	if gv_CurrentSectorId == "I1" or gv_CurrentSectorId == "I2" then return end
	
	-- Show tutorial if 10 attacks without aiming.
	TutorialHintsState.AimedAttack = ((type(TutorialHintsState.AimedAttack) == "number") and TutorialHintsState.AimedAttack or 0) + 1
	if results.aim and results.aim > 0 and TutorialHintsState.AimedAttack > 10 then
		TutorialHintsState.AimedAttack = 0
	end
end

function OnMsg.SquadStartedTravelling(squad)
	if squad and squad.Side == "player1" then
		TutorialHintsState.TravelPlaced = true
		TutorialHintVisibilityEvaluate()
	end
end

function AimedAttackTutorialCondition(crosshair)
	if not g_Combat then return end
	if TutorialHintsState.FirstAimedTutorial and gv_CurrentSectorId == "I2" then return end
	if TutorialHintsState.SecondAimedTutorial then return end
	if gv_PlayerSectorCounts.Mine > 0 then return false end

	if not crosshair then
		local dlg = GetDialog("IModeCombatAttack")
		crosshair = dlg and dlg.crosshair
	end
	
	-- Already aimed
	if crosshair and crosshair.aim > 0 then return false end

	local canAim = crosshair and crosshair.maxAimPossible > 0
	
	if canAim and gv_CurrentSectorId == "I2" and not TutorialHintsState.FirstAimedTutorial then 
		return true 
	end
	local aimedAttackCountInRange = ((type(TutorialHintsState.AimedAttack) == "number") and TutorialHintsState.AimedAttack or 0) >= 10
	
	return canAim and aimedAttackCountInRange
end

-- The quest tracker rollover pops out when the active quest is modified.
-- If a non-active quest is modified an icon appears on the quest tracker under the quest log is opened.
GameVar("UnseenQuest", false)
MapVar("NewlyAddedQuests", {})

local function lQuestChanged(quest)
	local id = quest.id or quest
	local activeQuest = GetActiveQuest()
	if id ~= activeQuest then
		UnseenQuest = true
		ObjModified(gv_Quests)
	end
end
OnMsg.QuestParamChanged = lQuestChanged
OnMsg.QuestLinesUpdated = lQuestChanged


function QuestRolloverPopout(newQuest, newNote)
	CreateRealTimeThread(function(newQuest, newNote)
		Sleep(100) -- Sometimes there are multiple quest changes back to back.
		WaitPlayerControl()
		while GetDialog("PDADialog") and not gv_SatelliteView do
			WaitMsg("ClosePDA", 100)
		end
		
		local igi = GetInGameInterfaceModeDlg()
		if not igi then 
			return 
		elseif not igi.idQuestPopout or not igi.idNewQuestPopout then
			return
		end
		
		--check one more time the hide cond as in cases where the new note waits a lot before showing, the hide cond could have changed
		local hideCond = newNote.HideConditions and #newNote.HideConditions > 0 and EvalConditionList(newNote.HideConditions, gv_Quests[newQuest])
		if hideCond then return end
		
		ObjModified(gv_Quests)
		local questPopout = igi.idQuestPopout
		local quests = questPopout.idQuestContent
		local foundNote = false
		for qIdx, quest in ipairs(quests) do
			local questNotes = quest.idNotes
			local nonNote = 0
			for idx, note in ipairs(questNotes) do
				if IsKindOf(note, "XText") then
					if note.context.Notes[idx - nonNote].note == newNote then
						foundNote = note
						--Effect for new notes in already shown quest, TBD
					end
				else
					nonNote = nonNote + 1
				end
			end
		end
		
		local notesToDisplayNum = 0
		local alreadyDisplayed
		for _, quest in ipairs(NewlyAddedQuests) do
			for _, note in ipairs(quest.Notes) do
				notesToDisplayNum = notesToDisplayNum + 1
				if note.Idx == newNote.Idx then
					alreadyDisplayed = true
				end
			end
		end
		if alreadyDisplayed or notesToDisplayNum > 4 then return end --If a note is already displayed OR the cap of notes is reached - do not show it

		local questNameT = gv_Quests[newQuest].DisplayName
		if not foundNote then
			local questAlreadyDisplayedIdx = table.find(NewlyAddedQuests, "Name", questNameT)
			if questAlreadyDisplayedIdx then
				table.insert(NewlyAddedQuests[questAlreadyDisplayedIdx].Notes, { 
					Text = FormatQuestLineUI(newNote, gv_Quests[newQuest], "visible"), 
					note = newNote
				})
			else
				table.insert(NewlyAddedQuests, 1, {
					Name = gv_Quests[newQuest].DisplayName, 
					Notes = {{Text = FormatQuestLineUI(newNote, gv_Quests[newQuest], "visible"), note = newNote}} 
				})
			end
			igi.idNewQuestPopout.parent:SetVisible(true)
			ObjModified("NewQuests")
		end

		Sleep(const.NewQuestShowTime)
		if foundNote then
			--Revert effect for new notes in already shown quest, TBD
		else
			if NewlyAddedQuests then
				local questIdx = table.find(NewlyAddedQuests, "Name", questNameT)
				if questIdx then
					local noteIdx = table.find(NewlyAddedQuests[questIdx].Notes, "note", newNote)
					if noteIdx then
						table.remove(NewlyAddedQuests[questIdx].Notes, noteIdx)
					end
				end
				if questIdx and not next(NewlyAddedQuests[questIdx].Notes) then
					table.remove(NewlyAddedQuests, questIdx)
				end
			end
			if not next(NewlyAddedQuests) and igi.idNewQuestPopout then
				igi.idNewQuestPopout.parent:SetVisible(false)
			end
			ObjModified("NewQuests")
		end
	end, newQuest, newNote)
end

function OnMsg.PDATabOpened(id)
	if id == "quests" then
		UnseenQuest = false
		ObjModified(gv_Quests)
	end
end

function TFormat.QuestVariable(_, questId, questParam)
	return GetQuestVar(questId, questParam)
end

function SavegameSessionDataFixups.AddLastQuestNote(data, meta)
	local latestQuestNoteTime = 0
	for _, quest in pairs(data.gvars.gv_Quests) do
		if next(quest.note_lines) then
			local latestInThisQuest = 0
			for _, time in pairs(quest.note_lines) do
				if time and latestInThisQuest < time then
					latestInThisQuest = time
				end
			end
			if latestQuestNoteTime < latestInThisQuest then
				latestQuestNoteTime = latestInThisQuest
			end
		end
	end
	
	data.gvars.LastNoteCampaignTime = latestQuestNoteTime == 0 and false or latestQuestNoteTime
end

function SavegameSessionDataFixups.PantagruelTCE(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["RescueBiff"] then return end
	if not session_data.gvars.gv_Quests["RescueBiff"]["TCE_SecondPantagruelChimurenga"] then return end
	session_data.gvars.gv_Quests["RescueBiff"]["TCE_SecondPantagruelChimurenga"] = false
end

function SavegameSessionDataFixups.G6ForcedConflict(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Sectors then return end
	if not session_data.gvars.gv_Sectors.G6 then return end
	session_data.gvars.gv_Sectors.G6.ForcedConflict = false
end

function OnMsg.EnterSector() 
	if gv_CurrentSectorId == "G6" then
		if not gv_Sectors.G6 then return end
		if not gv_Sectors.G6.conflict or gv_Sectors.G6.conflict["no_exploration_resolve"] then return end
		CheckMapConflictResolvedForFixup()
	end
end

function SavegameSessionDataFixups.Sanatorium(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["Sanatorium"] then return end
	if not session_data.gvars.gv_Quests["Sanatorium"]["Completed"] then return end
	session_data.gvars.gv_Quests["Sanatorium"]["Failed"] = false
end

function SavegameSessionDataFixups.BiffDeadOnArrivalConflict(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["RescueBiff"] then return end
	if not session_data.gvars.gv_Quests["RescueBiff"]["TCE_BiffDeadOnArrival"] then return end
	if not session_data.gvars.gv_Sectors then return end
	if not session_data.gvars.gv_Sectors["A8"].conflict then return end
	if not session_data.gvars.gv_Sectors["A8"].conflict.locked then return end
	session_data.gvars.gv_Sectors["A8"].conflict.locked = false
end


function SavegameSessionDataFixups.IlleMoratFirstEnter(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Sectors then return end
	if not session_data.gvars.gv_Sectors.D17 then return end
	if not session_data.gvars.gv_Quests["Beast"] then return end	
	if session_data.gvars.gv_Sectors.D17.last_enter_campaign_time ~= 0 then
	session_data.gvars.gv_Quests["Beast"]["IlleMorat_FirstEnter"] = true
	end
end

function SavegameSessionDataFixups.BeastKillTCE(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["Beast"] then return end
	if session_data.gvars.gv_Quests["Beast"]["TCE_RemoveConflict"] then return end
	session_data.gvars.gv_Quests["Beast"]["completed_tce"] = false	
end

function SavegameSessionDataFixups.FaucheuxEndgame(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["05_TakeDownFaucheux"] then return end
	if not session_data.gvars.gv_Quests["05_TakeDownFaucheux"]["FaucheuxEscaped"] then return end
	session_data.gvars.gv_Quests["05_TakeDownFaucheux"]["FaucheuxDead"] = false
	
	if not session_data.gvars.gv_Quests["06_Endgame"] then return end
	session_data.gvars.gv_Quests["06_Endgame"]["Outro_PeaceRestored"] = false
end

function SavegameSessionDataFixups.PierreHanging(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["RescueHerMan"] then return end	
	if not session_data.gvars.gv_Quests["RescueHerMan"]["HangingActive"] then return end
	if not session_data.gvars.gv_Quests["PierreDefeated"] then return end
	if not session_data.gvars.gv_Quests["PierreDefeated"]["PierreJoined"] then return end
	session_data.gvars.gv_Quests["RescueHerMan"]["HangingActive"] = false
end

function SavegameSessionDataFixups.OldDiamond(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["OldDiamond"] then return end
	if not session_data.gvars.gv_Sectors["K10"].conflict then return end
	if not session_data.gvars.gv_Quests["OldDiamond"]["TCE_ImpostorsFight"] then return end
	
	session_data.gvars.gv_Sectors["K10"].conflict = false
	session_data.gvars.gv_Sectors["K10"].ForceConflict = false
	session_data.gvars.gv_Quests["OldDiamond"]["TCE_ImpostorsFight"] = false
end


function SavegameSessionDataFixups.TheDump(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["TheTrashFief"] then return end
	if not session_data.gvars.gv_Sectors["L9"].conflict then return end
	if not session_data.gvars.gv_Quests["TheTrashFief"]["Completed"] then return end	
	
	session_data.gvars.gv_Quests["TheTrashFief"]["Completed"] = false
	session_data.gvars.gv_Quests["TheTrashFief"]["Failed"] = true	
	session_data.gvars.gv_Sectors["L9"].ForceConflict = false	
	session_data.gvars.gv_Sectors["L9"].conflict.locked = false
	
end

function SavegameSessionDataFixups.ReturnToErnie(session_data)
	if not session_data then return end
	if not session_data.gvars then return end
	if not session_data.gvars.gv_Quests then return end
	if not session_data.gvars.gv_Quests["ErnieSideQuests_WorldFlip"] then return end
	if not session_data.gvars.gv_Quests["ErnieSideQuests_WorldFlip"]["TCE_GatherPartisans"] then return end
	
	session_data.gvars.gv_Quests["ErnieSideQuests_WorldFlip"]["TCE_GatherPartisans"] = false
end

function OnMsg.GatherMusic(used_music)
	for _, group in ipairs(Presets.QuestsDef or empty_table) do
		for _, quest in ipairs(group or empty_table) do
			for _, tce in ipairs(quest.TCEs or empty_table) do
				for _, effect in ipairs(tce.Effects or empty_table) do
					if IsKindOf(effect, "MusicSetSectorPlaylist") then
						local sector = table.find_value(Presets.CampaignPreset.Default[1].Sectors, "Id", effect.SectorID)
						if IsDemoSector(sector.Map) then
							GatherMusic(effect.MusicExploration, used_music)
							GatherMusic(effect.MusicCombat, used_music)
							GatherMusic(effect.MusicConflict, used_music)
						end
					elseif IsKindOf(effect, "MusicSetTrack") then
						used_music[effect.Track] = true
					elseif IsKindOf(effect, "MusicSetPlaylist") then
						GatherMusic(effect.Playlist)
					end
				end
			end
		end
	end
end

-- Optimizations

if FirstLoad then
	gv_QuestRelations = {}
end

function BuildQuestRelations()
	-- {
	--		<questId> = {otherQuest1 = <amount>, otherQuest2 = <amount>, ...},
	--		<questId> = {otherQuest1 = <amount>, otherQuest2 = <amount>, ...},
	--	}
	gv_QuestRelations = {}
	local relations = gv_QuestRelations
	
	-- Add relations to external quests
	local function CheckAddRelation(script, quest)
		if IsKindOf(script, "QuestConditionBase") or IsKindOf(script, "QuestEffectBase") then
			if script.QuestId and script.QuestId ~= quest.id then
				relations[quest.id] = relations[quest.id] or {}
				relations[quest.id][script.QuestId] = (relations[quest.id][script.QuestId] or 0) + 1
				
				relations[script.QuestId] = relations[script.QuestId] or {}
				relations[script.QuestId][quest.id] = (relations[script.QuestId][quest.id] or 0) + 1
			end
			
			if script.QuestId2 and script.QuestId2 ~= quest.id then				
				relations[quest.id] = relations[quest.id] or {}
				relations[quest.id][script.QuestId2] = (relations[quest.id][script.QuestId2] or 0) + 1
				
				relations[script.QuestId2] = relations[script.QuestId2] or {}
				relations[script.QuestId2][quest.id] = (relations[script.QuestId2][quest.id] or 0) + 1
			end
		end
		
		for _, inner in ipairs(script.Conditions) do
			CheckAddRelation(inner, quest)
		end
		
		for _, inner in ipairs(script.Effects) do
			CheckAddRelation(inner, quest)
		end
	end
	
	for _, quest in ipairs(PresetArray("QuestsDef")) do
		-- TCEs
		for _, tce in ipairs(quest.TCEs) do
			for _, condition in ipairs(tce.Conditions) do
				CheckAddRelation(condition, quest)
			end
			
			for _, effect in ipairs(tce.Effects) do
				CheckAddRelation(effect, quest)
			end
		end
		
		-- Kill TCE Conditions
		for _, condition in ipairs(quest.KillTCEsConditions) do
			CheckAddRelation(condition, quest)
		end
		
		-- Notes
		for _, note in ipairs(quest.NoteDefs) do
			for _, condition in ipairs(note.CompletionConditions) do
				CheckAddRelation(condition, quest)
			end
			for _, condition in ipairs(note.HideConditions) do
				CheckAddRelation(condition, quest)
			end
			for _, condition in ipairs(note.ShowConditions) do
				CheckAddRelation(condition, quest)
			end
		end
		
		-- effect on rise bool var
		for _, obj in ipairs(quest.EffectOnChangeVarValue) do
			for _, effect in ipairs(obj.Effects) do
				CheckAddRelation(effect, quest)
			end
		end
	end
	
	local withoutRelations = {}
	for _, quest in ipairs(PresetArray("QuestsDef")) do
		if not relations[quest.id] then
			withoutRelations[quest.id] = true
		end
	end
	
	return relations, withoutRelations
end

function OnMsg.PreLoadSessionData()
	BuildQuestRelations()
end

function OnMsg.NewGame()
	BuildQuestRelations()
end

function OnMsg.PresetSave(className)
	if className == "QuestsDef" then
		BuildQuestRelations()
	end
end

function BuildTCESectorRelations(quest)	
	local function CheckAddRelation(storage, condition)
		if IsKindOf(condition, "PlayerIsInSectors") then
			if not condition.Negate then
				table.iappend(storage, condition.Sectors)
			end
		elseif IsKindOf(condition, "CheckAND") then
			for _, inner in ipairs(condition.Conditions) do
				CheckAddRelation(storage, inner)
			end
		end
	end

	for _, tce in ipairs(quest.TCEs) do
		tce.requiredSectors = {}
		if tce.Trigger == "activation" then
			for _, condition in ipairs(tce.Conditions) do
				CheckAddRelation(tce.requiredSectors, condition)
			end
		end
	end
end

function OnMsg.OnPreSavePreset(preset)
	if preset.class == "QuestsDef" then
		BuildTCESectorRelations(preset)
	end
end
