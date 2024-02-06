ReactionTargets = {}

DefineClass.MsgDef = {
	__parents = { "Preset" },
	properties = {
		{ id = "Params", editor = "text", default = "", buttons = {{ name = "Copy", func = "CopyHandler" }}, },
		{ id = "Target", editor = "choice", default = "", items = function() return ReactionTargets end },
		{ id = "Description", editor = "text", default = "" },
	},
	GlobalMap = "MsgDefs",
	EditorMenubarName = "Msg defs",
	EditorMenubar = "Editors.Engine",
	EditorIcon = "CommonAssets/UI/Icons/message typing.png",
}

function MsgDef:CopyHandler()
	local handler = string.format("function OnMsg.%s(%s)\n\t\nend\n\n", self.id, self.Params)
	CopyToClipboard(handler)
end

function OnMsg.ClassesGenerate()
	DefineModItemPreset("MsgDef", { EditorName = "Message definition", EditorSubmenu = "Other", Documentation = "Refer to Messages and Reactions documentation for more info." })
end


DefineClass.Reaction = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Event", editor = "preset_id", default = "", preset_class = "MsgDef", 
			preset_filter = function(preset, obj) return preset.Target == obj.ReactionTarget end },
		{ id = "Description", name = "Description", editor = "help", default = false, dont_save = true, read_only = true, 
			help = function (self) return self:GetHelp() end, },
		{ id = "Handler", editor = "func", default = false, lines = 6, max_lines = 60,
			name = function(self) return self.Event end,
			params = function (self) return self:GetParams() end, },
	},
	ReactionTarget = "",
	StoreAsTable = true,
	EditorView = T(205999281210, "<u(Event)>(<u(Params)>)"),
}

function Reaction:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Event" and type(self.Handler) == "function" then
		-- force reevaluation of the Handler's params when the event changes
		GedSetProperty(ged, self, "Handler", GameToGedValue(self.Handler, self:GetPropertyMetadata("Handler"), self))
	end
end

function Reaction:GetParams()
	local def = MsgDefs[self.Event]
	if not def then return "" end
	local params = def.Params or ""
	if params == "" then
		return self.ReactionTarget == "" and "self" or "self, target"
	end
	return (self.ReactionTarget == "" and "self, " or "self, target, ") .. params
end

function Reaction:GetHelp()
	local def = MsgDefs[self.Event]
	return def and def.Description or ""
end


----- ReactionScript

DefineClass.ReactionScript = {
	__parents = { "Reaction" },
	properties = {
		{ id = "Handler", editor = "script", default = false, lines = 6, max_lines = 60,  
			name = function(self) return self.Event end,
			params = function (self) return self:GetParams() end, },
	},
}


function DefineReactionsPreset(name, target, reactions_member, parent)
	assert(name)
	reactions_member = reactions_member or (name .. "_reactions")
	ReactionTargets[#ReactionTargets + 1] = target
	local ReactionClassName = name .. "Reaction"
	DefineClass[ReactionClassName] = {
		__parents = { "Reaction" },
		ReactionTarget = target,
	}
	DefineClass(name .. "ReactionScript", ReactionClassName, "ReactionScript")
	DefineClass[name .. "ReactionsPreset"] = {
		__parents = { parent or "Preset" },
		properties = {
			{ category = "Reactions", id = reactions_member, name = name .. " Reactions", default = false, 
				editor = "nested_list", base_class = ReactionClassName, auto_expand = true, inclusive = true },			
		},
		ReactionTarget = target,
		ReactionsMember = reactions_member,
		EditorMenubarName = false,
	}
end


----- ReactionObject

DefineClass.ReactionObject = {
	__parents = { "PropertyObject" },
	reaction_handlers = false,
	reaction_handlers_in_use = 0,
}

local move = table.move
local icopy = table.icopy
function ReactionObject:AddReactions(instance, list, insert_locations)
	if #(list or "") == 0 then return end
	local reaction_handlers_in_use = self.reaction_handlers_in_use
	instance = instance or false
	local reaction_handlers = self.reaction_handlers
	if not reaction_handlers then
		reaction_handlers = {}
		self.reaction_handlers = reaction_handlers
	end
	local ModMsgBlacklist = config.Mods and ModMsgBlacklist or empty_table
	for _, reaction in ipairs(list) do
		local event_id = reaction.Event
		local handler = reaction.Handler
		if not ModMsgBlacklist[event_id] and handler then
			local handlers = reaction_handlers[event_id]
			if handlers then
				if reaction_handlers_in_use > 0 then
					handlers = icopy(handlers)
					reaction_handlers[event_id] = handlers
				end
				local index = insert_locations and insert_locations[event_id] or #handlers + 1
				move(handlers, index, #handlers, index + 2)
				handlers[index] = instance
				handlers[index + 1] = handler
				if insert_locations and insert_locations[event_id] then
					insert_locations[event_id] = index + 2
				end
			else
				reaction_handlers[event_id] = { instance, handler }
			end
		end
	end
end

function ReactionObject:RemoveReactions(instance)
	-- remove all handlers for this instance
	instance = instance or false
	local reaction_handlers = self.reaction_handlers
	for event_id, handlers in pairs(reaction_handlers) do
		local reaction_handlers_in_use = self.reaction_handlers_in_use
		for i = #handlers - 1, 1, -2 do
			if instance == handlers[i] then
				if #handlers == 2 then
					reaction_handlers[event_id] = nil
				else
					if reaction_handlers_in_use > 0 then
						handlers = icopy(handlers)
						reaction_handlers[event_id] = handlers
						reaction_handlers_in_use = 0
					end
					move(handlers, i + 2, #handlers + 2, i)
				end
			end
		end
	end
end

-- to be used when the reactions list or handlers have changed
function ReactionObject:ReloadReactions(instance, list)
	assert(self.reaction_handlers_in_use == 0)
	local insert_locations
	local reaction_handlers = self.reaction_handlers
	for event_id, handlers in pairs(reaction_handlers) do
		-- remove all handlers for this instance
		for i = #handlers - 1, 1, -2 do
			if instance == handlers[i] then
				if #handlers == 2 then
					reaction_handlers[event_id] = nil
				else
					if i ~= #handlers - 1 then
						insert_locations = insert_locations or {}
						insert_locations[event_id] = i
					end
					move(handlers, i + 2, #handlers + 2, i)
				end
			end
		end
	end
	-- insert the new handlers at the appropriate places
	self:AddReactions(instance, list, insert_locations)
end

function ReactionObject:AddEventReaction(event_id, instance, handler)
	local ModMsgBlacklist = config.Mods and ModMsgBlacklist or empty_table
	if not handler or ModMsgBlacklist[event_id] then return end
	local reaction_handlers = self.reaction_handlers
	if not reaction_handlers then
		reaction_handlers = {}
		self.reaction_handlers = reaction_handlers
	end
	local handlers = reaction_handlers[event_id]
	if handlers then
		if self.reaction_handlers_in_use > 0 then
			handlers = icopy(handlers)
			reaction_handlers[event_id] = handlers
		end
		handlers[#handlers + 1] = instance
		handlers[#handlers + 1] = handler
	else
		reaction_handlers[event_id] = { instance, handler }
	end
end

function ReactionObject:RemoveEventReactions(event_id, instance)
	local reaction_handlers = self.reaction_handlers
	local handlers = reaction_handlers and reaction_handlers[event_id]
	local reaction_handlers_in_use = self.reaction_handlers_in_use
	for i = #(handlers or "") - 1, 1, -2 do
		if instance == handlers[i] then
			if #handlers == 2 then
				reaction_handlers[event_id] = nil
			else
				if reaction_handlers_in_use > 0 then
					handlers = icopy(handlers)
					reaction_handlers[event_id] = handlers
					reaction_handlers_in_use = 0
				end
				move(handlers, i + 2, #handlers + 2, i)
			end
		end
	end
end

local procall = procall
function ReactionObject:CallReactions(event_id, ...)
	local reaction_handlers = self.reaction_handlers
	local handlers = reaction_handlers and reaction_handlers[event_id]
	if #(handlers or "") == 0 then return end
	if #handlers > 2 then
		self.reaction_handlers_in_use = self.reaction_handlers_in_use + 1
		for i = 1, #handlers - 2, 2 do
			procall(handlers[i + 1], handlers[i], self, ...)
		end
		self.reaction_handlers_in_use = self.reaction_handlers_in_use - 1
	end
	procall(handlers[#handlers], handlers[#handlers - 1], self, ...)
end

function ReactionObject:CallReactions_And(event_id, ...)
	local reaction_handlers = self.reaction_handlers
	local handlers = reaction_handlers and reaction_handlers[event_id]
	if #(handlers or "") == 0 then return true end
	local result = true
	if #handlers > 2 then
		self.reaction_handlers_in_use = self.reaction_handlers_in_use + 1
		for i = 1, #handlers - 2, 2 do
			local success, res = procall(handlers[i + 1], handlers[i], self, ...)
			if success then
				result = result and res
			end
		end
		self.reaction_handlers_in_use = self.reaction_handlers_in_use - 1
	end
	local success, res = procall(handlers[#handlers], handlers[#handlers - 1], self, ...)
	if success then
		result = result and res
	end
	return result
end

function ReactionObject:CallReactions_Or(event_id, ...)
	local reaction_handlers = self.reaction_handlers
	local handlers = reaction_handlers and reaction_handlers[event_id]
	if #(handlers or "") == 0 then return false end
	local result = false
	if #handlers > 2 then
		self.reaction_handlers_in_use = self.reaction_handlers_in_use + 1
		for i = 1, #handlers - 2, 2 do
			local success, res = procall(handlers[i + 1], handlers[i], self, ...)
			if success then
				result = result or res
			end
		end
		self.reaction_handlers_in_use = self.reaction_handlers_in_use - 1
	end
	local success, res = procall(handlers[#handlers], handlers[#handlers - 1], self, ...)
	if success then
		result = result or res
	end
	return result
end

function ReactionObject:CallReactions_Modify(event_id, value, ...)
	local reaction_handlers = self.reaction_handlers
	local handlers = reaction_handlers and reaction_handlers[event_id]
	if #(handlers or "") == 0 then return value end
	if #handlers > 2 then
		self.reaction_handlers_in_use = self.reaction_handlers_in_use + 1
		for i = 1, #handlers - 2, 2 do
			local success, res = procall(handlers[i + 1], handlers[i], self, value, ...)
			if success and res ~= nil then
				value = res
			end
		end
		self.reaction_handlers_in_use = self.reaction_handlers_in_use - 1
	end
	local success, res = procall(handlers[#handlers], handlers[#handlers - 1], self, value, ...)
	if success and res ~= nil then
		value = res
	end
	return value
end


function ListCallReactions(list, event_id, ...)
	for _, obj in ipairs(list) do
		obj:CallReactions(event_id, ...)
	end
end

----- MsgReactions

DefineReactionsPreset("Msg", "", "msg_reactions") -- DefineClass.MsgReactionsPreset

-- MsgReactions is defined in cthreads.lua
local MsgReactions = MsgReactions
function ReloadMsgReactions()
	table.clear(MsgReactions)
	local list = {}
	ClassDescendants("MsgReactionsPreset", function(classname, classdef, list)
		list[#list + 1] = classdef.PresetClass or classname
	end, list)
	table.sort(list)
	local ModMsgBlacklist = config.Mods and ModMsgBlacklist or empty_table
	local last_preset
	for i, preset_type in ipairs(list) do
		if preset_type ~= last_preset then
			last_preset = preset_type
			ForEachPreset(preset_type, function(preset_instance)
				for _, reaction in ipairs(preset_instance.msg_reactions or empty_table) do
					local event_id = reaction.Event
					local handler = reaction.Handler
					if not ModMsgBlacklist[event_id] and handler then
						local handlers = MsgReactions[event_id]
						if handlers then
							handlers[#handlers + 1] = preset_instance
							handlers[#handlers + 1] = handler
						else
							MsgReactions[event_id] = { preset_instance, handler }
						end
					end
				end
			end)
		end
	end
end

OnMsg.ModsReloaded = ReloadMsgReactions
OnMsg.DataLoaded = ReloadMsgReactions
OnMsg.PresetSave = ReloadMsgReactions
OnMsg.DataReloadDone = ReloadMsgReactions
