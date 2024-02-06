local ai_debug = Platform.developer and Platform.pc
local bias_base = 1000000 -- fixed point value equivalent to 1 or 100%

DefineClass.DumbAIPlayer = {
	__parents = { "InitDone" },
	
	actions = false,
	action_log = false,
	log_size = 10,
	running_actions = false,
	biases = false,
	resources = false,
	display_name = false,
	
	absolute_actions = 10,
	absolute_threshold = 10000,
	relative_threshold = 50, -- percent of the highest eval
	think_interval = 1000,

	seed = 0,
	think_thread = false,
	ai_start = 0,

	GedEditor = "DumbAIDebug",
	
	-- production
	production_interval = 60000,
	next_production = 0,
	production_rules = false,
	next_production_times = false,
}

function DumbAIPlayer:Init()
	self.actions = {}
	self.action_log = {}
	self.running_actions = {}
	self.biases = {}
	self.resources = {}
	for _, def in ipairs(Presets.AIResource.Default) do
		self.resources[def.id] = 0
	end
	self.ai_start = GameTime()
	self.production_rules = {}
	self.next_production = GameTime()
	self.next_production_times = setmetatable({}, weak_keys_meta)
end

function DumbAIPlayer:Done()
	DeleteThread(self.think_thread)
	GedObjectDeleted(self)
end

function DumbAIPlayer:AddAIDef(ai_def)
	if not ai_def then return end
	local actions = self.actions
	for _, action in ipairs(ai_def) do
		actions[#actions + 1] = action
	end
	local resources = self.resources
	for _, res in ipairs(ai_def.initial_resources) do
		local resource = res.resource
		resources[resource] = resources[resource] + res:Amount()
	end
	local production_rules = self.production_rules
	for _, rule in ipairs(ai_def.production_rules or empty_table) do
		production_rules[#production_rules + 1] = rule
	end
	local label = "AIDef " .. ai_def.id
	for _, bias in ipairs(ai_def.biases) do
		self:AddBias(bias.tag, bias.bias, nil, label)
	end
end

function DumbAIPlayer:RemoveAIDef(ai_def)
	if not ai_def then return end
	local actions = self.actions
	for _, action in ipairs(ai_def) do
		table.remove_entry(actions, action)
	end
	local production_rules = self.production_rules
	for _, rule in ipairs(ai_def.production_rules or empty_table) do
		table.remove_entry(production_rules, rule)
	end
	local label = "AIDef " .. ai_def.id
	for _, bias in ipairs(ai_def.biases) do
		self:RemoveBias(bias.tag, nil, label)
	end
end


-- AI bias

local function recalc_bias(tag_biases)
	local acc = bias_base
	for _, bias in ipairs(tag_biases) do
		acc = MulDivRound(acc, bias.change, bias_base)
	end
	tag_biases.acc = acc
end

function DumbAIPlayer:AddBias(tag, change, source, label)
	local tag_biases = self.biases[tag]
	if not tag_biases then
		tag_biases = { acc = bias_base }
		self.biases[tag] = tag_biases
	end
	if label then
		local idx = table.find(tag_biases, "label", label)
		if idx then
			table.remove(tag_biases, idx)
		end
	end
	local bias = {
		change = change,
		label = label or nil,
		source = ai_debug and source or nil,
	}
	tag_biases[#tag_biases + 1] = bias
	recalc_bias(tag_biases)
	return bias
end

function DumbAIPlayer:RemoveBias(tag, bias, label)
	local tag_biases = self.biases[tag]
	if tag_biases then
		table.remove_entry(tag_biases, bias)
		local idx = table.find(tag_biases, "label", label)
		if idx then
			table.remove(tag_biases, idx)
		end
		recalc_bias(tag_biases)
	end
end

function DumbAIPlayer:BiasValue(value, tags)
	local biases = self.biases
	for _, tag in ipairs(tags or empty_table) do
		local tag_biases = biases[tag]
		if tag_biases then
			value = MulDivRound(value, tag_biases.acc, bias_base)
		end
	end
	return value
end

function DumbAIPlayer:BiasValueByTag(value, tag)
	local tag_biases = self.biases[tag]
	if tag_biases then
		value = MulDivRound(value, tag_biases.acc, bias_base)
	end
	return value
end

-- AI main loop

function DumbAIPlayer:AIUpdate(seed)
	local resources = self.resources
	for _, rule in ipairs(self.production_rules) do
		local time = self.next_production_times[rule] or 0
		if GameTime() >= time then
			self.next_production_times[rule] = time + rule.production_interval
			procall(rule.Run, rule, resources, self)
		end
	end
end

function DumbAIPlayer:LogAction(action)
	table.insert(self.action_log, {action = action, time = GameTime()})
	while #self.action_log > self.log_size do
		table.remove(self.action_log, 1)
	end
end

function DumbAIPlayer:GetDisplayName()
	return self.display_name or ""
end

function DumbAIPlayer:AIStartAction(action)
	self.running_actions[action] = (self.running_actions[action] or 0) + 1
	local resources = self.resources
	for _, res in ipairs(action.required_resources) do
		local resource = res.resource
		resources[resource] = resources[resource] - res.amount
	end
	CreateGameTimeThread(function(self, action, ai_debug)
		sprocall(action.Run, action, self)
		Sleep(self:BiasValueByTag(action.delay, "action_delay"))
		if (action.log_entry or "") ~= "" then
			self:LogAction(action)
		end
		local resources = self.resources
		for _, res in ipairs(action.resulting_resources) do
			local resource = res.resource
			resources[resource] = resources[resource] + res:Amount()
		end
		sprocall(action.OnEnd, action, self)
		assert((self.running_actions[action] or 0) > 0)
		self.running_actions[action] = (self.running_actions[action] or 0) - 1
		if ai_debug then
			ObjModified(self)
		end
	end, self, action, ai_debug)
end

function DumbAIPlayer:AILimitActions(actions)
	local active_actions = {}
	local resources = self.resources
	local running_actions = self.running_actions
	for _, action in ipairs(actions) do
		if (running_actions[action] or 0) < action.max_running then
			for _, res in ipairs(action.required_resources) do
				assert(res:Amount() == res.amount, "randomized amounts are not supported for required_resources")
				if resources[res.resource] < res.amount then
					action = nil
					break
				end
			end
			if action and action:IsAllowed(self) then
				local eval = action:Eval(self) or action.base_eval
				action.eval = self:BiasValue(eval, action.tags)
				active_actions[#active_actions + 1] = action
			end
		end
	end
	table.sortby_field_descending(active_actions, "eval")
	-- limit by number of actions
	local count = self:BiasValueByTag(self.absolute_actions, "ai_absolute_actions")
	count = Min(count, #active_actions)
	if count < 1 then
		return active_actions, 0
	end
	-- limit by evaluation
	local threshold = self:BiasValueByTag(self.absolute_threshold, "ai_absolute_threshold")
	local rel_threshold = self:BiasValueByTag(self.relative_threshold, "ai_relative_threshold")
	threshold = Max(threshold, MulDivRound(active_actions[1].eval, rel_threshold, 100))

	while count > 0 
		and active_actions[count].eval < threshold do
		count = count - 1
	end
	return active_actions, count
end

function DumbAIPlayer:AIThink(seed)
	seed = seed or AsyncRand()
	self:AIUpdate(seed)
	local actions, count = self:AILimitActions(self.actions)
	local action = actions[BraidRandom(seed, count) + 1]
	if action then
		self:AIStartAction(action)
	end
	if ai_debug then
		if #self > 40 then -- remove entries beyond 40
			for i = 1, #self do
				self[i] = self[i + 1]
			end
		end
		if #self > 0 and not self[#self][3] then
			self[#self] = nil -- replace last entry if there was no action selected
		end
		self[#self + 1] = {
			GameTime() - self.ai_start,
			seed,
			action or false,
			actions,
			count,
			table.copy(self.resources),
			action and action.eval,
		}
		ObjModified(self)
	end
	return action
end

function DumbAIPlayer:CreateAIThinkThread()
	DeleteThread(self.think_thread)
	self.think_thread = CreateGameTimeThread(function(self)
		local rand, think_seed = BraidRandom(self.seed)
		while true do
			Sleep(self:BiasValueByTag(self.think_interval, "ai_think_interval"))
			rand, think_seed = BraidRandom(think_seed)
			self:AIThink(rand)
		end
	end, self)
end

-- AI Debug

if ai_debug then

local function format_bias(n)
	return string.format("%d.%02d", n / bias_base, (n % bias_base) * 100 / bias_base)
end

local function DumbAIDebugActions(texts, actions, count, eval)
	texts[#texts + 1] = "<style GedTitleSmall><center>Actions selection</style>"
	for i, action in ipairs(actions) do
		if i == count + 1 then
			texts[#texts + 1] = ""
			texts[#texts + 1] = "<style GedTitleSmall><center>Low evaluation</style>"
		end
		if eval then
			texts[#texts + 1] = string.format("<left>%s<right>%s", action.id, format_bias(action.eval))
		else
			texts[#texts + 1] = string.format("<left>%s", action.id)
		end
	end
end

local function DumbAIDebugResources(texts, resources)
	texts[#texts + 1] = "<style GedTitleSmall><center>Resources</style>"
	for _, def in ipairs(Presets.AIResource.Default) do
		local resource = def.id
		texts[#texts + 1] = string.format("<left>%s<right>%d", resource, resources[resource])
	end
end

function GedDumbAIDebugState(ai_player)
	local texts = {}
	DumbAIDebugResources(texts, ai_player.resources)
	texts[#texts + 1] = ""
	texts[#texts + 1] = "<style GedTitleSmall><center>Tag biases</style>"
	for _, def in ipairs(Presets.AITag.Default) do
		local tag = def.id
		local tag_biases = ai_player.biases[tag]
		if tag_biases then
			texts[#texts + 1] = string.format("<left>%s<right>%d%%", tag, MulDivRound(tag_biases.acc, 100, bias_base))
		end
	end
	
	texts[#texts + 1] = ""
	local actions, count = ai_player:AILimitActions(ai_player.actions)
	DumbAIDebugActions(texts, actions, count, true)
	return table.concat(texts, "\n")
end

local function time(time)
	time = tonumber(time)
	if time then
		local sign = time < 0 and "-" or ""
		local sec = abs(time) / 1000
		local min = sec / 60
		local hours = min / 60
		local days = hours / 24
		if days > 0 then
			return string.format("%s%dd%02dh%02dm%02ds", sign, days, hours % 24, min % 60, sec % 60)
		else
			return string.format("%s%dh%02dm%02ds", sign, hours, min % 60, sec % 60)
		end
	end
end

function GedDumbAIDebugLog(ai_player)
	local list = {}
	for i, entry in ipairs(ai_player) do
		local t, seed, action, actions, count, resources, eval = table.unpack(entry)
		list[i] = string.format("%s %s %s", time(t) or "???", action and action.id or "---", action and format_bias(eval) or "")
	end
	return list
end

function GedDumbAIDebugLogEntry(entry)
	local texts = {}
	local time, seed, action, actions, count, resources = table.unpack(entry)
	DumbAIDebugResources(texts, resources)
	texts[#texts + 1] = ""
	DumbAIDebugActions(texts, actions, count)
	return table.concat(texts, "\n")
end

-- Test

__TestAI = false

function TestAI()
	if __TestAI then __TestAI:delete() end
	__TestAI = DumbAIPlayer:new{
		think_interval = const.HourDuration,
		production_interval = const.DayDuration,
	}
	__TestAI:AddAIDef(Presets.DumbAIDef.Default.default)
	__TestAI:AddAIDef(Presets.DumbAIDef.MissionSponsors.IMM)
	__TestAI:CreateAIThinkThread()
	__TestAI:OpenEditor()
	Resume()
end

end

function DumbAIPlayer:GetCurrentStanding()
	return self.resources.standing
end