-- Еngine for story bits (short UI interactions) via a system of triggers, categories, and cooldowns.
-- Depends on ClassDef and Constant groups with name "StoryBits"

if Platform.ged then return end

DefineConstInt("StoryBits", "TickDuration", 60, "sec", "Game time between Tick triggers")
config.StoryBitLogPrints = false

if FirstLoad then
	g_StoryBitTesting = config.StoryBitTesting or false
	VoiceActors = { "narrator" }
end

StoryBitTriggersCombo = {}

function DefineStoryBitTrigger(name, msg_name)
	StoryBitTriggersCombo[#StoryBitTriggersCombo + 1] = { text = name, value = msg_name }
	table.sortby_field(StoryBitTriggersCombo, "text")
	OnMsg[msg_name] = function(obj) StoryBitTrigger(msg_name, obj) end
end

function StoryBitPrint(text)
	assert(config.StoryBitLogPrints)
	print("<color 247 235 3>" .. text .. "</color>")
end


----- Debug log

if Platform.developer then
	local log_limit = 20
	GameVar("g_StoryBitsLog", {})
	GameVar("g_StoryBitsScopeStack", false)
	
	g_StoryBitsLogOld = false
	function OnMsg.ChangeMap()
		g_StoryBitsLogOld = g_StoryBitsLog
	end
	
	local function UpdateStoryBitLog()
		if #g_StoryBitsLog > log_limit then table.remove(g_StoryBitsLog, 1) end
		SuspendErrorOnMultiCall("StoryBitLog")
		ObjModified(g_StoryBitsLog)
		ResumeErrorOnMultiCall("StoryBitLog")
	end
	
	function StoryBitLogScope(...)
		local stack = g_StoryBitsScopeStack or { g_StoryBitsLog }
		if #stack == 0 then stack = { g_StoryBitsLog } end
		g_StoryBitsScopeStack = stack
		
		local scope = stack[#stack]
		scope[#scope + 1] = { name = print_format(...) }
		stack[#stack + 1] = scope[#scope]
		UpdateStoryBitLog()
	end
	
	function StoryBitLogScopeEnd()
		table.remove(g_StoryBitsScopeStack)
	end
	
	function StoryBitLog(...)
		local stack = g_StoryBitsScopeStack or { g_StoryBitsLog }
		if #stack == 0 then stack = { g_StoryBitsLog } end
		g_StoryBitsScopeStack = stack
		
		local scope = stack[#stack]
		scope[#scope + 1] = print_format(...)
		UpdateStoryBitLog()
	end
	function StoryBitLogDescribe(obj)
		return TTranslate(obj:GetEditorView(), obj, false)
	end
else
	function StoryBitLogScope(name) end
	function StoryBitLogScopeEnd(name) end
	function StoryBitLog(name) end
	function StoryBitLogDescribe(self, obj) return "" end
end


----- StoryBitCategory

DefineClass.StoryBitCategory = {
	__parents = { "Preset" },
	properties = {
		{ id = "Trigger", editor = "combo", default = "", items = function() return StoryBitTriggersCombo end, help = "The trigger that activates the StoryBits from that category. For randomly occuring ones use 'Tick'." },
		{ id = "Chance", editor = "number", default = 5, scale = "%", 
			help = function (obj, prop_meta)
				local chance = obj[prop_meta.id]
				return ListChances({"Selected", "Not selected"}, {chance, 100 - chance}, 100, 
					"The chance that this category will be selected when the trigger fires.",
					{ 1, 2, 3, 4, 5, 7, 10, 15, 20, 24 })
			end
		},
		{ id = "Cooldowns", editor = "preset_id_list", default = false, preset_class = "CooldownDef", },
		{ id = "Prerequisites", editor = "nested_list", base_class = "Condition", default = false, help = "Common prerequisites for all StoryBits from the category.", },
		{ id = "ActivationEffects", name = "Activation Effects", editor = "nested_list", default = false, base_class = "Effect", all_descendants = true },
	},
	GlobalMap = "StoryBitCategories",
	EditorMenubarName = "Story Bits Categories",
	EditorMenubar = "Scripting",
	EditorIcon = "CommonAssets/UI/Icons/list outline.png",
	PropertyTranslation = false,
}

function StoryBitCategory:GetError()
	local total = 0
	ForEachPreset("StoryBitCategory", function(preset, group, trigger)
		if preset.Trigger == trigger then
			total = total + preset.Chance
		end
	end, self.Trigger)
	if total > 100 then
		return string.format("Total chance of categories with trigger %s exceeds 100%%.", self.Trigger)
	end
end

function OnMsg.ClassesGenerate()
	DefineModItemPreset("StoryBitCategory", { EditorName = "Story bit category", EditorSubmenu = "Gameplay" })
end

----- StoryBit states

GameVar("g_StoryBitCategoryStates", {}) -- separate tables per trigger
GameVar("g_StoryBitStates", {})
GameVar("g_StoryBitActive", {}) -- running storybit states (they are not found in g_StoryBitStates as the state unregisters on activation)
GameVar("g_StoryBitsLoaded", {}) -- keep track of what storybits were present when the savegame was made

function OnMsg.LoadGame() -- cleanup states of story bits that no longer exist (as presets) or were moved to a different category
	for _, states_for_trigger in pairs(g_StoryBitCategoryStates) do
		for _, category_state in pairs(states_for_trigger) do
			local to_remove
			for _, storybit_state in ipairs(table.copy(category_state.storybit_states)) do
				local preset = StoryBits[storybit_state.id]
				if not preset then
					to_remove = to_remove or {}
					to_remove[#to_remove + 1] = storybit_state
				elseif preset.Category ~= category_state.id then
					category_state:UnregisterStoryBit(storybit_state)
					GetStoryBitCategoryState(storybit_state.id):RegisterStoryBit(storybit_state)
				end
			end
			for _, storybit_state in ipairs(to_remove) do
				g_StoryBitStates[storybit_state.id] = nil
				category_state:UnregisterStoryBit(storybit_state)
			end
		end
	end
	
	-- empty g_StoryBitsLoaded means this is an older save and we don't want to create states that might have been removed from g_StoryBitStates on purpose
	if next(g_StoryBitsLoaded) then
		-- load story bits, which were not present when the savegame was made
		ForEachPreset("StoryBit", TryCreateStoryBitState)
	end
end

DefineClass.StoryBitCategoryState = {
	__parents = { "InitDone" },
	id = false,
	trigger = false,
	storybit_states = false,
}

function StoryBitCategoryState:Init()
	self.storybit_states = {}
end

function StoryBitCategoryState:RegisterStoryBit(storybit_state)
	table.insert(self.storybit_states, storybit_state)
end

function StoryBitCategoryState:UnregisterStoryBit(storybit_state)
	table.remove_entry(self.storybit_states, storybit_state)
end

function StoryBitCategoryState:CheckPrerequisites(object)
	local category = StoryBitCategories[self.id]
	assert(category)
	if not category or not Game then
		return
	end
	for _, cooldown_id in ipairs(category.Cooldowns) do
		if Game:GetCooldown(cooldown_id) then
			dbg(StoryBitLog("Category", self.id, "rejected due to cooldown", cooldown_id))
			NetUpdateHash("StoryBitPrerequisites in cooldown", self.id, cooldown_id, object)
			return
		end
	end
	for _, condition in ipairs(category.Prerequisites) do
		local valid = condition:ValidateObject(object, "Storybit category ", self.id)
		if not valid or not condition:Evaluate(object, nil) then -- the conditions expect StoryBitState as context
			dbg(StoryBitLog("Category", self.id, "rejected due to condition:", StoryBitLogDescribe(condition)))
			NetUpdateHash("StoryBitPrerequisites fail", self.id, object)
			return
		end
	end
	NetUpdateHash("StoryBitPrerequisites match", self.id, object)
	return true
end

function StoryBitCategoryState:ArrangeStoryBits(list)
	list = table.copy(list)
	if g_StoryBitTesting then
		return StoryBitsSortForTesting(list)
	end
	table.shuffle(list, InteractionRand(nil, "ArrangeStoryBits"))
	return list
end

function StoryBitCategoryState:TryActivateStoryBit(object, sleep)
	if #self.storybit_states == 0 then return end
	StoryBitLogScope("Trying category", self.id)
	-- shuffle/order the story bits and activate the first with satisfied prerequisites
	local list = self:ArrangeStoryBits(self.storybit_states)
	local match_found
	for _, storybit_state in ipairs(list) do
		local obj = storybit_state.object
		if obj and not IsStoryBitObjectValid(obj) then -- remove story bit states associated with an already invalid object
			dbg(StoryBitLog("StoryBit", storybit_state.id, "deleted due to invalid object"))
			storybit_state:Unregister() -- list is a copy - it is safe to call Unregister()
		elseif storybit_state:CheckPrerequisites(object or obj, nil) and (not sleep or table.find(self.storybit_states, storybit_state)) then
			storybit_state:ActivateStoryBit(object or obj)
			self:StorybitActivated(storybit_state)
			match_found = true
			break
		else
			storybit_state.object = obj -- CheckPrerequisites sometimes "picks" an object, clean it up
		end
		
		-- for the StoryBitTick trigger, this distributes the load to prevent "stuttering"
		if sleep then Sleep(sleep) end
	end
	
	StoryBitLogScopeEnd()
	return match_found
end

function StoryBitCategoryState:StorybitActivated(storybit_state, no_cooldown)
	local category = StoryBitCategories[self.id]
	if category then
		if Game and not no_cooldown then
			for _, cooldown_id in ipairs(category.Cooldowns) do
				Game:SetCooldown(cooldown_id)
			end
		end
		ExecuteEffectList(category.ActivationEffects, storybit_state.object, storybit_state)
	end
end

function GetStoryBitCategoryState(storybit_id)
	local storybit = StoryBits[storybit_id]
	local category, trigger = storybit.Category, storybit.Trigger
	local states_for_trigger = g_StoryBitCategoryStates[trigger]
	if not states_for_trigger then
		states_for_trigger = {}
		g_StoryBitCategoryStates[trigger] = states_for_trigger
	end
	local state = states_for_trigger[category]
	if not state then
		state = StoryBitCategoryState:new{ id = category, trigger = trigger }
		states_for_trigger[category] = state
	end
	return state
end

DefineClass.StoryBitState = {
	__parents = { "InitDone" },
	id = false,
	time_created = false,
	object = false,
	player = false,
	run_thread = false,
	inherited_title = false,
	inherited_image = false,
	chosen_reply_id = false,
}

function StoryBitState:Init()
	self:Register()
end

function StoryBitState:Done()
	self:Unregister()
	self:StopRunThread()
	self:OnStopRunning()
end

function StoryBitState:__newindex(key, value)
	rawset(self, key, value)
end

function StoryBitState:Register()
	self.time_created = StoryBitGetGameTime()
	g_StoryBitStates[self.id] = self
	NetUpdateHash("g_StoryBitStates Register", self.id)
	GetStoryBitCategoryState(self.id):RegisterStoryBit(self)
end

function StoryBitState:Unregister()
	g_StoryBitStates[self.id] = nil
	NetUpdateHash("g_StoryBitStates Unregister", self.id)
	GetStoryBitCategoryState(self.id):UnregisterStoryBit(self)
end

function StoryBitState:CheckProjectSpecificPrerequisites(storybit, object, force)
	-- implement in project-specific code
	return true
end

function StoryBitState:CheckPrerequisites(object, force)
	local storybit = StoryBits[self.id]
	if not self:CheckProjectSpecificPrerequisites(storybit, object, force) then
		return
	end
	if not force then
		for cooldown_id in pairs(storybit.Sets) do
			if Game:GetCooldown(cooldown_id) then
				dbg(StoryBitLog("StoryBit", self.id, "rejected due to cooldown", cooldown_id))
				return
			end
		end
		local supress_time = storybit.SuppressTime
		if g_StoryBitTesting then
			supress_time = supress_time / 10
		end
		if supress_time > 0 and StoryBitGetGameTime() <= self.time_created + supress_time then
			dbg(StoryBitLog("StoryBit", self.id, "suppressed for", self.time_created + supress_time - StoryBitGetGameTime()))
			return
		end
	end
	
	self.player = nil
	
	local result = true
	for _, condition in ipairs(storybit.Prerequisites or empty_table) do
		local valid = condition:ValidateObject(object, "Storybit ", self.id)
		if not valid or not condition:Evaluate(object, self) then
			result = false
			if not force then 
				dbg(StoryBitLog("StoryBit", self.id, "rejected due to condition:", StoryBitLogDescribe(condition)))
				break 
			end
		end
	end
	if result then
		return true
	end
	
	self.player = nil
end

function StoryBitState:TestPrerequisites(object)
	local test = {}
	local storybit = StoryBits[self.id]
	for i, condition in ipairs(storybit.Prerequisites or empty_table) do
		local desc = self:PrepareT(condition:GetEditorView(), condition, "ignore_localization")
		test[i] = {
			text = _InternalTranslate(desc, nil, false),
			res = condition:ValidateObject(object, "Storybit ", self.id) and condition:Evaluate(object, self) and true or false,
		}
	end
	self.object = nil
	self.player = nil
	return test
end

function StoryBitState:TestCategoryPrerequisites(object)
	local test = {}
	local storybit = StoryBits[self.id]
	local category = StoryBitCategories[storybit.Category].Prerequisites
	for i, condition in ipairs(StoryBitCategories[storybit.Category].Prerequisites or empty_table) do
		local desc = self:PrepareT(condition:GetEditorView(), condition, "ignore_localization")
		test[i] = {
			text = _InternalTranslate(desc, nil, false),
			res = condition:ValidateObject(object, "Storybit ", self.id) and condition:Evaluate(object, self) and true or false,
		}
	end
	self.object = nil
	self.player = nil
	return test
end

function StoryBitState:PrepareT(loc_text, subcontext, ignore_localization)
	if not loc_text or loc_text == "" then return "" end
	if Platform.developer and not ignore_localization and type(loc_text) == "table" and loc_text.untranslated then
		assert(false, string.format("Story bit %s is displaying an untranslated description:\n%s", self.id, _InternalTranslate(loc_text)))
	end
	if subcontext then
		return T{loc_text, Context:new{
			ResolveValue = function(context, key)
				return self:ResolveValue(key, subcontext)
			end,
		}}
	end
	return T{loc_text, self}
end

function StoryBitState:ResolveValue(key, subcontext)
	local storybit = StoryBits[self.id]
	local value = subcontext and ResolveValue(subcontext, key)
	value = value or storybit:ResolveValue(key)
	value = value or rawget(storybit, key)
	value = value or self.object and self.object:ResolveValue(key)
	value = value or rawget(self, key)
	return value
end

function StoryBitState:PrepareReplyText(reply)
	-- condition text
	local cond_text = self:PrepareT(reply.PrerequisiteText)
	
	-- cost text
	local cost = reply.Cost
	local cost_text = cost > 0 and StoryBitFormatCost(cost)
	
	-- format text
	local reply = self:PrepareT(reply.Text)
	if cond_text ~= "" and cost_text then
		return T{624976250551, "<condition_text>[<condition>, cost: <cost>]</condition_text> <reply>", condition = cond_text, cost = cost_text, reply = reply }
	elseif cond_text ~= "" then
		return T{924726909309, "<condition_text>[<condition>]</condition_text> <reply>", condition = cond_text, reply = reply }
	elseif cost_text then
		return T{474009362220, "<condition_text>[Cost: <cost>]</condition_text> <reply>", cost = cost_text, reply = reply }
	else
		return reply
	end
end

function StoryBitState:PrepareOutcomeText(reply, reply_idx, enabled)
	local outcome_text = ""
	if reply.OutcomeText == "custom" then
		outcome_text = self:PrepareT(reply.CustomOutcomeText) or ""
	elseif reply.OutcomeText == "auto" then
		local storybit = StoryBits[self.id]
		local function next_outcome(storybit, idx)
			while not IsKindOf(storybit[idx], "StoryBitOutcome") do
				if IsKindOf(storybit[idx], "StoryBitReply") or idx > #storybit then return end
				idx = idx + 1
			end
			return idx
		end
	
		local idx = next_outcome(storybit, reply_idx + 1)
		if idx then
			local outcome_texts = {}
			for _, effect in ipairs(storybit[idx].Effects or empty_table) do
				local description = effect:GetDescription()
				if description and description ~= "" and not effect.NoIngameDescription then
					outcome_texts[#outcome_texts + 1] = self:PrepareT(description, effect)
				end
			end
			outcome_text = table.concat(outcome_texts, T(163645984724, ", "))
		end
	end
	
	if outcome_text == "" then
		return ""
	end
	return enabled and
		T{690643209328, "<outcome_text>(<outcome>)</outcome_text>", outcome = outcome_text} or
		T{269606479436, "<disabled_text>(<outcome>)</disabled_text>", outcome = outcome_text}
end

function StoryBitState:ActivateStoryBit(object, immediate)
	assert(not IsValidThread(self.run_thread))
	
	local id = self.id
	local storybit = StoryBits[id]
	if g_StoryBitTesting then
		StoryBitSaveTime(id)
	end
	
	dbg(StoryBitLog("StoryBit", id, "activated", immediate and "immediate" or ""))
	NetUpdateHash("StoryBitActivated", id, immediate and "immediate" or "")

	self:Unregister()
	DisableStoryBits(storybit.Disables, self)
	
	self:StopRunThread() -- here for safety only, there should be no running threads
	self.object = object or self.object
	self.run_thread = CreateGameTimeThread(self.RunWrapper, self, immediate)
	Msg("StoryBitActivated", id, self)
end

function StoryBitState:GetTitle()
	local storybit = StoryBits[self.id]
	local has_title = storybit.Title and storybit.Title ~= ""
	return has_title and storybit.Title or self.inherited_title
end

function StoryBitState:GetImage()
	local storybit = StoryBits[self.id]
	local obj = self.object
	local image = storybit.UseObjectImage
		and IsValid(obj)
		and PropObjHasMember(obj, "GetStoryBitPopupImage")
		and obj:GetStoryBitPopupImage()
	if (image or "") ~= "" then return image end
	local has_image = storybit.Image and storybit.Image ~= ""
	return has_image and storybit.Image or self.inherited_image
end

function StoryBitState:RunWrapper(immediate)
	self:OnStartRunning()
	local success = self:Run(immediate)
	self:OnStopRunning()
	if success then
		self:OpenPopup()
	end
	self:Complete()
end

function StoryBitState:StopRunThread()
	local thread = self.run_thread
	self.run_thread = nil
	if thread ~= CurrentThread() then
		DeleteThread(thread)
	else
		CreateGameTimeThread(DeleteThread, thread)
	end
end

function StoryBitState:Interrupt()
	self:StopRunThread()
	self:OnStopRunning()
	self.object = nil
	self.player = nil
	self:Register()
end

function StoryBitState:OnStartRunning()
	local running = g_StoryBitActive
	running[#running + 1] = self
	running[self.id] = (running[self.id] or 0) + 1
end

function StoryBitState:OnStopRunning()
	RemoveStoryBitNotification(self.id)
	assert(self.run_thread == CurrentThread() or not IsValidThread(self.run_thread))
	self.run_thread = nil
	local running = g_StoryBitActive
	if not running[self.id] then
		return
	end
	for i=#running,1,-1 do
		local state = running[i]
		if state == self or not IsValidThread(state.run_thread) then
			table.remove(running, i)
			running[state.id] = (running[state.id] or 0) - 1
			if running[state.id] <= 0 then
				running[state.id] = nil
			end
		end
	end
end

function StoryBitState:Run(immediate)
	dbg(StoryBitLog("["..StoryBitFormatGameTime().."]", self.id, "started", immediate and "immediate" or nil))
	
	local storybit = StoryBits[self.id]
	
	-- delay
	if not immediate then
		if storybit.DetachObj then
			self.object = false
		end
		StoryBitDelay(storybit.Delay)
	end
	
	if self.object and not IsStoryBitObjectValid(self.object) then
		return
	end
	
	if config.StoryBitLogPrints then
		StoryBitPrint("Story bits: Triggered story bit - " .. self.id)
	end
	
	-- activation effects
	for _, effect in ipairs(storybit.ActivationEffects or empty_table) do
		if effect:ValidateObject(self.object, "Storybit ", self.id) then
			effect:Execute(self.object, self)
		end
	end
	
	local expiration_time = storybit.ExpirationTime
	if not storybit.HasNotification and (not expiration_time or expiration_time == 0) then
		return true
	end
	
	assert(self.run_thread == CurrentThread())
	expiration_time = expiration_time or const.HourDuration
	expiration_time = expiration_time * (storybit:ExpirationModifier(self, self.object) or 100) / 100
	-- add notification, handle timeout with a thread
	local stop_wait
	if storybit.HasNotification then
		local notification_title = storybit.NotificationTitle ~= "" and storybit.NotificationTitle or self:GetTitle()
		local notification_text = storybit.NotificationText ~= "" and storybit.NotificationText or notification_title
		AddStoryBitNotification(self, storybit, 
			self:PrepareT(notification_title), 
			self:PrepareT(notification_text), 
			expiration_time,
			function()
				if storybit.NotificationAction == "complete" then
					stop_wait = true
					Wakeup(self.run_thread)
				elseif storybit.NotificationAction == "select object" then
					StoryBitViewAndSelectObject(self.object)
				elseif storybit.NotificationAction == "callback" then
					storybit:NotificationCallbackFunc(self)
				end
			end	)
	end
	local end_time = StoryBitGetGameTime() + expiration_time
	while not stop_wait and StoryBitGetGameTime() - end_time < 0 do
		WaitWakeup(100)
		if self.object and not IsStoryBitObjectValid(self.object) then
			return
		end
	end
	return true
end

function CheckCustomStoryBitReplyPrerequisites(reply)
	-- implement in project-specific code
	return true
end

function CheckCustomStoryBitOutcomePrerequisites(outcome)
	-- implement in project-specific code
	return true
end

function StoryBitState:OpenPopup()
	local storybit = StoryBits[self.id]
	if storybit and storybit.HasPopup then
		-- gather all replies
		local counter = 0
		local all_disabled = true
		local replies, choices, enabled, extra_texts = {}, {}, {}, {}
		local i = 1
		for idx, reply in ipairs(storybit) do
			if reply:IsKindOf("StoryBitReply") then
				counter = counter + 1
				local cost_satisfied = reply.Cost <= 0 or StoryBitCheckCost(reply.Cost)
				local project_specific_satisfied = CheckCustomStoryBitReplyPrerequisites(reply)
				local satisfied = cost_satisfied and project_specific_satisfied and EvalConditionList(reply.Prerequisites, self.object, self)
				all_disabled = all_disabled and not satisfied
				if not reply.HideIfDisabled or satisfied then
					enabled[i] = satisfied
					replies[i] = reply
					choices[i] = self:PrepareReplyText(reply)
					extra_texts[i] = self:PrepareOutcomeText(reply, idx, satisfied)
					i = i + 1
				end
			end
		end
		if counter > 0 and all_disabled then
			self:ShowError(false, "No available storybit replies!")
		end
		-- display popup
		Msg("StoryBitPopup", self.id, self)
		if storybit.PopupFxAction ~= "" then
			PlayFX(storybit.PopupFxAction, "start")
		end
		local reply_idx
		if config.NoUserInteraction then
			reply_idx = table.find(enabled, true) or 1 -- for testing purposes
		else
			reply_idx = WaitStoryBitPopup(self.id,
				self:PrepareT(self:GetTitle()), self:PrepareT(storybit.VoicedText), self:PrepareT(storybit.Text),
				self.object or storybit.Actor, self:GetImage(), choices, enabled, extra_texts)
		end
		local reply = replies[reply_idx]
		if reply then
			if config.StoryBitLogPrints then
				StoryBitPrint("Story bits: Reply selected - " .. _InternalTranslate(reply.Text))
			end
			self.chosen_reply_id = reply.unique_id
			local reply_counter = 0
			for _, reply_i in ipairs(storybit) do
				if reply_i:IsKindOf("StoryBitReply") then
					reply_counter = reply_counter + 1
					if reply_i.unique_id == reply.unique_id then
						Msg("StoryBitReplyActivated", self.id, self, reply_counter)
						break
					end
				end
			end
			-- gather possible outcomes
			local found, outcomes = false, {}
			local log_text = string.format("Storybit outcome for reply %d in %s", reply_idx, self.id)
			for _, outcome in ipairs(storybit) do
				if not found then
					found = outcome.unique_id == reply.unique_id
				else
					if outcome:IsKindOf("StoryBitReply") then
						break
					elseif outcome:IsKindOf("StoryBitOutcome") then
						local fulfilled = CheckCustomStoryBitOutcomePrerequisites(outcome)
						if fulfilled then
							for _, condition in ipairs(outcome.Prerequisites or empty_table) do
								local valid = condition:ValidateObject(self.object, log_text)
								if not valid or not condition:Evaluate(self.object, self) then
									fulfilled = false
									break
								end
							end
						end
						if fulfilled then
							outcomes[#outcomes + 1] = outcome
						end
					end
				end
			end
			
			-- charge the reply's cost if present
			local cost = reply.Cost
			if cost > 0 then
				StoryBitPayCost(cost)
			end
			
			-- trigger outcome selected by weighted random
			local outcome
			if g_StoryBitTesting then
				outcome = StoryBitOutcomeTestingPick(outcomes, storybit)
			else
				outcome = table.weighted_rand(outcomes, "Weight", InteractionRand(1000000, "StoryBitOutcome"))
			end
			if outcome then
				if (outcome.VoicedText and outcome.VoicedText ~= "" or outcome.Text and outcome.Text ~= "") and not config.NoUserInteraction then
					local image = outcome.Image
					if not image or image == "" then
						image = storybit.Image
					end
					local title = (outcome.Title and outcome.Title ~= "") and outcome.Title or self:GetTitle()
					WaitStoryBitPopup(self.id .. "Outcome", self:PrepareT(title), self:PrepareT(outcome.VoicedText), self:PrepareT(outcome.Text), outcome.Actor, image)
				end
				self:ProcessOutcomeEffects(outcome, log_text)
			end
		end
		if storybit.SelectObject and IsValid(self.object) then
			ViewAndSelectObject(self.object)
		end
	end
	self:ProcessOutcomeEffects(storybit, "Storybit " .. self.id)
end

function StoryBitState:Complete()
	Msg("StoryBitCompleted", self.id, self)
	self.object = nil
	self.player = nil
	local storybit = StoryBits[self.id]
	if not storybit.OneTime then
		self:Register()
	end
end

function StoryBitState:ShowError(fo, ...)
	local texts = {
		print_format("Error:", ...),
		print_format("Storybit:", self.id),
	}
	if fo then
		local desc = _InternalTranslate(self:PrepareT(fo:GetEditorView(), fo, "ignore_localization"), nil, false)
		texts[#texts + 1] = print_format("Source:", fo.class, desc)
	end
	local text = table.concat(texts, "\n")
	assert(false, text)
end

-- called with both StoryBitOutcome and StoryBit parameter
function StoryBitState:ProcessOutcomeEffects(outcome, parentobj_text)
	if not outcome then return end
	for _, effect in ipairs(outcome.Effects) do
		if effect:ValidateObject(self.object, parentobj_text) then
			if config.StoryBitLogPrints then
				local log_msg = "Story bits: Effect triggered - " .. effect.class
				if effect:HasMember("Effects") and type(effect.Effects) == "table" and #effect.Effects > 0 then
					log_msg = log_msg .. ": "
					for i = 1, #effect.Effects do
						if i == #effect.Effects then
							log_msg = log_msg .. effect.Effects[i].class
						else
							log_msg = log_msg .. effect.Effects[i].class .. ", "
						end
					end
				end
				StoryBitPrint(log_msg)
			end
			effect:Execute(self.object, self)
		end
	end
	-- try to select a random storybit from the outcome
	TryActivateRandomStoryBit(outcome.StoryBits, self.object, self)
	DisableStoryBits(outcome.Disables, self)
	self:EnableStoryBits(outcome.Enables)
end

function TryActivateRandomStoryBit(storybits, obj, context)
	if not next(storybits) then return end
	local items = {}
	for _, item in ipairs(storybits) do
		if CheckStoryBitPrerequisites(item.StoryBitId, obj) then
			items[#items + 1] = item
		end
	end
	local chosen_storybit = table.weighted_rand(items, "Weight", InteractionRand(1000000, "StoryBitOutcome"))
	if chosen_storybit then
		ForceActivateStoryBit(chosen_storybit.StoryBitId, obj, chosen_storybit.ForcePopup and "immediate", context, chosen_storybit.NoCooldown)
	end
end

function DisableStoryBits(list, disabled_by)
	if #(list or "") == 0 then return end
	if disabled_by then
		dbg(StoryBitLog("["..StoryBitFormatGameTime().."]", disabled_by.id, "disables storybits:", table.concat(list, ", ")))
	end
	local g_StoryBitStates = g_StoryBitStates
	local g_StoryBitActive = g_StoryBitActive
	local to_delete
	for _, id in ipairs(list) do
		local storybit_state = g_StoryBitStates[id]
		if storybit_state then
			assert(storybit_state ~= disabled_by)
			storybit_state:delete()
		end
		if g_StoryBitActive[id] then
			for _, storybit_state in ipairs(g_StoryBitActive) do
				if storybit_state.id == id then
					to_delete = to_delete or {}
					to_delete[#to_delete + 1] = storybit_state
				end
			end
		end
	end
	for _, storybit_state in ipairs(to_delete) do
		assert(storybit_state ~= disabled_by)
		storybit_state:delete()
	end
end

function StoryBitState:EnableStoryBits(list, enabled_by)
	if #(list or "") == 0 then return end
	enabled_by = enabled_by or self
	dbg(StoryBitLog("["..StoryBitFormatGameTime().."]", enabled_by.id, "activates storybits:", table.concat(list, ", ")))
	for _, id in ipairs(list) do
		local storybit_state = g_StoryBitStates[id]
		if not storybit_state then
			local storybit = StoryBits[id]
			if not storybit then
				self:ShowError(false, "No such storybit", id)
			else
				assert(not storybit.Enabled)
				StoryBitState:new{
					id = id,
					object = storybit.InheritsObject and enabled_by.object or nil,
					player = self.player,
					inherited_title = enabled_by:GetTitle(),
					inherited_image = enabled_by:GetImage(),
				}
			end
		end
	end
end


----- StoryBit trigger engine

function StoryBitTrigger(msg, object)
	if not mapdata.GameLogic or config.StoryBitsSuspended then
		return
	end
	
	NetUpdateHash("StoryBitTrigger", msg, object)
	
	local states = g_StoryBitCategoryStates[msg]
	if states == nil then
		--StoryBitLog("["..StoryBitFormatGameTime().."]", "Trigger", msg, "- no active story bits with this trigger!")
		return
	end

	StoryBitLogScope("["..StoryBitFormatGameTime().."]", "Trigger", msg, object and object.class or "")

	-- process follow ups if present
	local follow_ups = states["FollowUp"]
	if follow_ups and follow_ups:TryActivateStoryBit(object) then
		StoryBitLogScopeEnd()
		return
	end

	-- gather categories with this trigger
	if g_StoryBitTesting then
		local category = StoryBitCategoryTestingPick(states, object)
		if category then
			category:TryActivateStoryBit(object)
		end
	else
		local total, random = 0, InteractionRand(100, "StoryBitTrigger")
		local activated = false
		for category_name, category in sorted_pairs(states) do
			if category_name ~= "FollowUp" then
				local category_descr = StoryBitCategories[category_name]
				local chance = category_descr and category_descr.Chance or 0
				if random >= 0 and random < chance and category:CheckPrerequisites(object) then
					-- the execution passes through here just once, guaranteed
					if msg == "StoryBitTick" and #category.storybit_states > 0 then
						-- calculate sleep time to distribute the load of checking prerequisites (try to fit in 1/10 the tick time)
						local sleep_time = (const.StoryBits.TickDuration / 10) / #category.storybit_states
						assert(sleep_time ~= 0)
						CreateGameTimeThread(category.TryActivateStoryBit, category, object, Clamp(sleep_time, 1, 10))
					else
						category:TryActivateStoryBit(object)
					end
					activated = true
				end
				random = random - chance
				total = total + chance
			end
		end
		assert(total <= 100, string.format("Total chance of categories with trigger %s exceeds 100%%.", msg))
		--[[
		if not activated then
			StoryBitLog("No category was selected for activation (due to chance)")
		end
		--]]
	end
	
	StoryBitLogScopeEnd()
end

function OnMsg.Autorun()
	table.insert(StoryBitTriggersCombo, 1, { text = "Tick", value = "StoryBitTick" })
	table.insert(StoryBitTriggersCombo, 1, { text = "", value = "" })
end

function TryCreateStoryBitState(storybit)
	local id = storybit.id
	if g_StoryBitsLoaded[id] then return end
	g_StoryBitsLoaded[id] = true
	if not storybit.Enabled then return end 
	local chance = storybit.EnableChance
	if chance == 100 or InteractionRand(100, "StoryBitsTickThread") < chance then
		StoryBitState:new{ id = id }
	end
end

MapGameTimeRepeat("StoryBitsTickThread", nil, function(sleep)
	if not sleep then
		if not const.StoryBits or not next(StoryBits) or not mapdata.GameLogic then Halt() end -- no StoryBits defined
		
		if rawget(_G, "g_StoryBitsLogOld") then
			GedRebindRoot(g_StoryBitsLogOld, g_StoryBitsLog)
			g_StoryBitsLogOld = false
		end
		
		ForEachPreset("StoryBit", TryCreateStoryBitState)
		
		if not const.StoryBits.TickDuration then Halt() end -- no Tick defined	
	else
		procall(StoryBitTrigger, "StoryBitTick", nil)
	end
	return const.StoryBits.TickDuration
end)

function CheckStoryBitPrerequisites(id, object)
	local storybit_state = g_StoryBitStates[id]
	if storybit_state then 
		return storybit_state:CheckPrerequisites(object or storybit_state.object, nil)
	end
end

function ForceActivateStoryBit(id, object, immediate, activated_by, no_cooldown)
	local storybit_state = g_StoryBitStates[id] or StoryBits[id] and StoryBitState:new{ id = id }
	if not storybit_state then return end
	storybit_state.object = object or storybit_state.object
	if activated_by then
		storybit_state.inherited_title = activated_by:GetTitle()
		storybit_state.inherited_image = activated_by:GetImage()
		storybit_state.player = activated_by.player
	end
	-- the prerequisites have not been checked, do it now as they might pick an object for the story bit
	storybit_state:CheckPrerequisites(object, "force")
	storybit_state:ActivateStoryBit(nil, immediate)
	GetStoryBitCategoryState(id):StorybitActivated(storybit_state, no_cooldown)
end

function GedRpcTestStoryBit(socket, storybit)
	if not GameState.gameplay or not storybit then return end
	ForceActivateStoryBit(storybit.id, SelectedObj, "immediate")
end

function GedRpcTestPrerequisitesStoryBit(socket, storybit)
	if not GameState.gameplay or not storybit then return end

	local output = {}
	local id = storybit.id
	local storybit_state = g_StoryBitStates[id] or StoryBitState:new{ id = id, object = SelectedObj }
	for i, p in ipairs(storybit_state:TestPrerequisites(storybit_state.object)) do
		table.insert(output, string.format("Prerequisite %d: %s --> %s", i, p.text, p.res))
	end

	storybit_state.object = SelectedObj
	for i, p in ipairs(storybit_state:TestCategoryPrerequisites(storybit_state.object)) do
		table.insert(output, string.format("Category prerequisite %d: %s --> %s", i, p.text, p.res))
	end
	
	socket:ShowMessage("Test Prerequisites", table.concat(output, "\n"))
end

----- Override these in the game Lua code

const.TagLookupTable["condition_text"]  = ""
const.TagLookupTable["/condition_text"] = ""
const.TagLookupTable["outcome_text"]    = "<color 233 242 255>"
const.TagLookupTable["/outcome_text"]   = "</color>"
const.TagLookupTable["disabled_text"]   = "<color 196 196 196>"
const.TagLookupTable["/disabled_text"]  = "</color>"

function IsStoryBitObjectValid(obj)
	-- override to check for object-specific validity, e.g. is the unit alive
	if obj:IsKindOf("CObject") then
		return IsValid(obj)
	end
	return true
end

function AddStoryBitNotification(storybit_state, storybit, title, text, expiration_time, callback)
	-- display a notification about a StoryBit with the specified 'title' and 'text', invoke 'callback(id)' when the notification is clicked
end

function RemoveStoryBitNotification(id)
	-- remove the notification with the provided id
end

function StoryBitViewAndSelectObject(object)
	ViewAndSelectObject(object)
end

function WaitStoryBitPopup(id, title, voiced_text, text, actor, image, choices, choice_enabled, choice_extra_texts)
	-- display a game popup with the specified parameters
	-- 'choices' is an array of T values
	-- 'choice_enabled' specifies which choices are enabled
	-- 'choice_extra_texts' specifies optional extra comments for each choice, e.g. why is this choice present / not present
	local context = {
		translate = true,
		title = title,
		text = text,
		disabled = {},
		actor = actor,
	}
	local choices_count = #(choices or empty_table)
	for i, choice in ipairs(choices or empty_table) do
		context["choice" .. i] = T{876135565495, "<choice><newline><extra_text>", choice = choices[i], extra_text = choice_extra_texts[i]}
		context.disabled[i] = not choice_enabled[i]
	end
	return WaitPopupChoice(false, context)
end

function StoryBitFormatCost(cost)
	return T{504461186435, "<cost>", cost = cost}
end

function StoryBitCheckCost(cost)
	return true
end

function StoryBitPayCost(cost)
end

-- for a turn-based game, this could be the number of the turn instead; cooldown logic uses this function
function StoryBitGetGameTime()
	return GameTime()
end

-- for the Delay property; for a turn-based game 'time' will likely to be number of turns, and this should be reimplemented
function StoryBitDelay(time)
	Sleep(time)
end

-- formats time-stamps for the Story Bit Log debug utility
function StoryBitFormatGameTime()
	local time = GameTime() / 1000
	return string.format("%d:%02d:%02d", time / 3600, time / 60 % 60, time % 60)
end

function DumpStoryBits()
	ForEachPreset("StoryBit", function(storybit)
		if storybit.Enabled then
			local category = GetStoryBitCategoryState(storybit.id)
			local idx = table.find_value(category.storybit_states, "id", storybit.id)
			if not idx then
				print(storybit.id)
			end
		end
	end)
end

function DescribeStoryBits(dest_folder)
	local function AddText(tbl, indent, ...)
		tbl[#tbl + 1] = print_format(...)
		tbl[#tbl + 1] = "\n"
		for i = 1,indent do
			tbl[#tbl + 1] = "    "
		end
	end
	local function GetText(obj, indent)
		if IsT(obj) then
			return _InternalTranslate(obj)
		elseif type(obj) == "table" then
			indent = (indent or 0) + 1
			local tbl = {}
			local init
			if obj.class then
				local def = g_Classes[obj.class]
				AddText(tbl, indent, obj.class)
				for _, prop in ipairs(obj:GetProperties()) do
					local id = prop.id
					local value = obj:GetProperty(id)
					local default = def:GetProperty(id)
					if value ~= default then
						local text = GetText(value, indent) or ""
						if text ~= "" then
							AddText(tbl, indent, id, "=", text)
						end
					end
				end
			else
				AddText(tbl, indent)
				init = #tbl
			end
			for _, value in ipairs(obj) do
				local text = GetText(value, indent) or ""
				if text ~= "" then
					AddText(tbl, indent, text)
				end
			end
			if init and init == #tbl then
				return
			end
			return table.concat(tbl)
		elseif type(obj) ~= "function" then
			return tostring(obj)
		end
	end
	CreateRealTimeThread(function()
		local count, errs = 0, 0
		dest_folder = dest_folder or "AppData/StoryBitDscr"
		local err = AsyncCreatePath(dest_folder)
		if err then
			print(err, "while trying to create path", ConvertToOSPath(dest_folder))
			return
		end
		print("Describing story bits...")
		local texts = {}
		local function Describe(preset)
			local text = GetText(preset)
			local err = AsyncStringToFile(dest_folder .. "/" .. preset.id .. ".txt", text)
			if err then
				errs = errs + 1
				print(preset.id, "failed to save:", err)
				return
			end
			count = count + 1
			print(preset.id)
			texts[#texts + 1] = text
			texts[#texts + 1] = "\n\n------------------------------------------------------------------\n\n"
		end
		ForEachPreset("StoryBit", Describe)
		ForEachPreset("StoryBitCategory", Describe)
		local err = AsyncStringToFile(dest_folder .. "/__ALL__.txt", texts)
		print("\n", count, "presets described in", ConvertToOSPath(dest_folder))
		if errs > 0 then
			print(err, "preset descriptions failed")
		end
	end)
end

function StoryBitSaveTime(id)
	local timestamp = AccountStorage.StoryBitTimestamp or {}
	timestamp[id] = os.time()
	AccountStorage.StoryBitTimestamp = timestamp
	SaveAccountStorage(3000)
end

function DeleteStoryBitTestingBacklog()
	CreateRealTimeThread(function()
		local params = {
			title = Untranslated("Delete StoryBit Testing Backlog"),
			text = Untranslated("The testing backlog ensures that all events are tested before being triggered again. Are you sure to delete it?"),
			choice1 = Untranslated("OK"),
			choice1_img = "UI/CommonNew/message_box_ok.tga",
			choice2 = Untranslated("Cancel"),
			choice2_img = "UI/CommonNew/message_box_cancel.tga",
			start_minimized = false,
		}
		local res = WaitPopupNotification(false, params, nil, terminal.desktop)
		if res == 1 then
			AccountStorage.StoryBitTimestamp = nil
			SaveAccountStorage(3000)
		end
	end)
end

function StoryBitsSortForTesting(list)
	local timestamp = AccountStorage.StoryBitTimestamp or empty_table
	table.sort(list, function(a, b) return (timestamp[a.id] or 0) < (timestamp[b.id] or 0) end)
	return list
end

function StoryBitOutcomeTestingPick(outcomes, storybit)
	local ids = {}
	local id = storybit.id
	local counter = 0
	for _, outcome in ipairs(storybit) do
		if outcome:IsKindOf("StoryBitOutcome") then
			counter = counter + 1
			ids[outcome] = id .. "_outcome_" .. counter
		end
	end
	local timestamp = AccountStorage.StoryBitTimestamp or empty_table
	table.sort(outcomes, function(a, b)
		local ta = timestamp[ids[a]] or 0
		local tb = timestamp[ids[b]] or 0
		if ta < tb then
			return true
		end
		return a.Weight > b.Weight
	end)
	local result = outcomes[1]
	if not result then
		return
	end
	StoryBitSaveTime(ids[result])
	return result
end

function StoryBitCategoryTestingPick(states, object)
	local candidates
	for category_name, category in pairs(states) do
		if category_name ~= "FollowUp"
			and #category.storybit_states > 0 
			and category:CheckPrerequisites(object)
		then
			candidates = candidates or {}
			candidates[#candidates + 1] = category
		end
	end
	if not candidates then
		return
	end
	local timestamp = AccountStorage.StoryBitTimestamp or empty_table
	local max_weight = 7*24*60*60 -- one week
	local now = os.time()
	local category = table.weighted_rand(candidates, function(category)
		local weight = 0
		for _, state in ipairs(category.storybit_states) do
			local weight_i = Min(max_weight, now - (timestamp[state.id] or 0))
			weight = weight + weight_i
		end
		local weight_cat = Min(max_weight, now - (timestamp[category.id] or 0))
		local weight_res = MulDivRound(weight, weight_cat, max_weight)
		return 1 + weight_res
	end)
	if category then
		StoryBitSaveTime(category.id)
		return category
	end
end

function ToggleStoryBitTesting()
	g_StoryBitTesting = not g_StoryBitTesting
	UpdateStoryBitTestingUI()
end

function UpdateStoryBitTestingUI() end -- override in project

function InterruptStoryBitSupressionTimes()
	for id, state in pairs(g_StoryBitStates) do
		local storybit = StoryBits[id]
		local supress_time = storybit.SuppressTime
		state.time_created = -supress_time
	end
end

function ResolveEventPlayer(obj, context)
	return obj and rawget(obj, "player") or context and rawget(context, "player") or Players and Players[1]
end

------ Notification priorities -------
function GetGameNotificationPriorities()
	local priorities = {"Normal", "Important", "Critical", "StoryBit"}
	AddGameSpecificNotificationPriorities(priorities)
	return priorities
end

-- override in game-specific code to insert additional priorities
function AddGameSpecificNotificationPriorities(priorities)
end