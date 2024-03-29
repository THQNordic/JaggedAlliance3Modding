function MsgDef:GetError()
	local params = string.split(self.Params, ",")
	for _, param in ipairs(params) do
		param = string.trim_spaces(param)
		if param == "reaction_actor" or param == "reaction_def" then 
			-- reaction_actor is used as a parameter name when processing actors obtained via GetReactionActors; 
			-- Having it as a Msg parameter would cause two parameters with the same name to be present in the function, 
			-- effectively causing the msg parameter overwrite the value
			return string.format("Msgs should not have a parameter named '%s'!", param)
		end
	end
end

-- end MsgDef append

-- ActorReaction
local function ReactionActorsComboItems(self)
	local items = { false }
	local msgdef = MsgDefs[self.Event] or empty_table
	if (msgdef.Params or "") ~= "" then
		local params = string.split(msgdef.Params, ",")
		for _, param in ipairs(params) do
			items[#items + 1] = string.trim_spaces(param)
		end
	end
	
	return items
end

DefineClass.ActorReaction = {
	__parents = { "Reaction" },
	properties = {
		{ id = "FlagsDef", name = "Flags", editor = "string_list", default = {}, item_default = "", 
			base_class = "PresetParam", default = false, help = "Create named parameters for numeric values and use them in multiple places.\n\nFor example, if an event checks that an amount of money is present, subtracts this exact amount, and displays it in its text, you can create an Amount parameter and reference it in all three places. When you later adjust this amount, you can do it from a single place.\n\nThis can prevent omissions and errors when numbers are getting tweaked later.",
		},		
		{ id = "ActorParam", editor = "dropdownlist", items = ReactionActorsComboItems, default = false, 
			no_edit = function(self)
				local msgdef = MsgDefs[self.Event] or empty_table
				return not msgdef
			end,
		},
		{ id = "Handler", editor = "func", default = false, lines = 6, max_lines = 60, no_edit = true,
			name = function(self) return self.Event end,
			params = function (self) return self:GetParams() end, },
		{ id = "HandlerCode", editor = "func", default = false, lines = 6, max_lines = 60,
			name = function(self) return self.Event or "Handler" end,
			params = function (self) return self:GetExecParams() end, },
	},
	Flags = false,
}

function ActorReaction:GetExecParams()
	local def = MsgDefs[self.Event]
	if not def then return "" end
	local actor = self:GetActor()
	if actor then	
		return self:GetParams()
	end
	-- insert "reaction_actor after self
	local params = def.Params or ""
	if params == "" then
		return self.ReactionTarget == "" and "self, reaction_actor" or "self, reaction_actor, target"
	end
	return (self.ReactionTarget == "" and "self, reaction_actor, " or "self, reaction_actor, target, ") .. params
end

function ActorReaction:__generateHandler(index)
	if type(self.HandlerCode) ~= "function" then return end
	
	local msgdef = MsgDefs[self.Event] or empty_table
	local msgparams = msgdef.Params or ""
	if msgparams == "" then
		msgparams = "nil"
	end
	local code = pstr("", 1024)
	
	local params = self:GetParams()
	local exec_params = self:GetExecParams()

	local h_name, h_params, h_body = GetFuncSource(self.HandlerCode)

	local actor = self:GetActor()
	local handler_call = ""
	if type(h_body) == "string" then
		handler_call = h_body
	elseif type(h_body) == "table" then
		handler_call = table.concat(h_body, "\n")
	end
	
	
	code:appendf("local reaction_def = (self.msg_reactions or empty_table)[%d]", index)
	
	if actor then
		code:appendf("\nif self:VerifyReaction(\"%s\", reaction_def, %s, %s) then", self.Event, actor, msgparams)
		code:appendf("\n\t%s", handler_call)
		code:appendf("\nend")
	else	
		code:appendf("\nlocal actors = self:GetReactionActors(\"%s\", reaction_def, %s)", self.Event, msgparams)
		code:append("\nfor _, reaction_actor in ipairs(actors) do")
			code:appendf("\n\tif self:VerifyReaction(\"%s\", reaction_def, reaction_actor, %s) then", self.Event, msgparams)
			code:appendf("\n\t\t%s", handler_call)
			code:appendf("\n\tend")
		code:append("\nend")		
	end
	
	code = tostring(code)
	self.Handler = CompileFunc("Handler", params, code)
end

function ActorReaction:GetActor()
	return self.ActorParam
end

function ActorReaction:HasFlag(flag)
	return self.Flags and self.Flags[flag]
end

function ActorReaction:OnEditorSetProperty(prop_id, old_value, ged)
	local need_update
	if prop_id == "Event" then
		self.ActorParam = false
		need_update = true
	elseif prop_id == "ActorParam" then
		need_update = true
	end
	
	if need_update then
		self:__generateHandler(1) -- OnPreSave will give the correct index, for now we just need to update the parameters
		-- force reevaluation of the Handler's params when the event changes
		GedSetProperty(ged, self, "Handler", GameToGedValue(self.Handler, self:GetPropertyMetadata("Handler"), self))
	end
	self.Flags = (#(self.FlagsDef or empty_table) > 0) and {} or nil
	for _, flag in ipairs(self.FlagsDef) do
		self.Flags[flag] = true
	end
end
DefineClass("MsgActorReaction", "MsgReaction", "ActorReaction")
-- end ActorReaction

-- ReactionEffects
DefineClass.ActorReactionEffects = {
	__parents = { "ActorReaction" },
	properties = {
		{ id = "Handler", editor = "func", default = false, lines = 6, max_lines = 60, no_edit = true,
			name = function(self) return self.Event end,
			params = function (self) return self:GetParams() end, },
		{ id = "HandlerCode", editor = "func", default = false, lines = 6, max_lines = 60, no_edit =  true, dont_save = true,
			name = function(self) return self.Event or "Handler" end,
			params = function (self) return self:GetParams() end, },			
		{ id = "Effects", editor = "nested_list", default = false, template = true, base_class = "ConditionalEffect", inclusive = true, },
	},
}

function ActorReactionEffects:__generateHandler(index)
	local msgdef = MsgDefs[self.Event] or empty_table
	local actor = self:GetActor()
	local params = self:GetParams()
	local code = string.format("ExecReactionEffects(self, %d, \"%s\", %s, %s)", index, self.Event, actor or "nil", params)
	self.Handler = CompileFunc("Handler", self:GetParams(), code)
end

function ExecReactionEffects(self, index, event, reaction_actor, ...)
	if not IsKindOf(self, "MsgReactionsPreset") then return end
		
	local reaction_def = (self.msg_reactions or empty_table)[index]
	if not reaction_def or reaction_def.Event ~= event then return end
	
	local context = {}
	local effects = reaction_def.Effects
	context.target_units = {reaction_actor}
	if not IsKindOf(self, "MsgActorReactionsPreset") then
		ExecuteEffectList(effects, reaction_actor, context) -- reaction_actor can be nil
		return
	end
			
	if reaction_actor then
		if self:VerifyReaction(event, reaction_def, reaction_actor, ...) then
			ExecuteEffectList(effects, reaction_actor, context)
		end
	else
		local actors = self:GetReactionActors(event, reaction_def, ...)
		for _, reaction_actor in ipairs(actors) do
			if self:VerifyReaction(event, reaction_def, reaction_actor, ...) then
				context.target_units[1] = reaction_actor
				ExecuteEffectList(effects, reaction_actor, context)
			end
		end
	end
end
DefineClass("MsgActorReactionEffects", "MsgReaction", "ActorReactionEffects")
-- end ReactionEffects

-- MsgActorReactionsPreset
DefineClass.MsgActorReactionsPreset = {
	__parents = { "UnitReactionsPreset" },
}

function MsgActorReactionsPreset:VerifyReaction(event, reaction, actor, ...)
	return
end

function MsgActorReactionsPreset:GetReactionActors(event, reaction, ...)
	return
end

function MsgActorReactionsPreset:OnPreSave()
	for i, reaction in ipairs(self.msg_reactions) do
		if IsKindOf(reaction, "ActorReaction") then
			reaction:__generateHandler(i)
		end
	end
end

-- end MsgActorReactionsPreset

-- misc/utility

function ZuluReactionResolveUnitActorObj(session_id, unit_data)
	local obj
	local mapUnit = g_Units[session_id]
	if gv_SatelliteView or (mapUnit and (not IsValid(mapUnit) or mapUnit.is_despawned)) then
		return unit_data or gv_UnitData[session_id]
	end
	return mapUnit or unit_data or gv_UnitData[session_id]
end

function ZuluReactionGetReactionActors_Light(event, reaction_def, ...)
	local objs = {}
	if reaction_def:HasFlag("SatView") then
		for session_id, data in pairs(gv_UnitData) do
			local obj = ZuluReactionResolveUnitActorObj(session_id, data)
			if self:VerifyReaction(event, obj, ...) then
				objs[#objs + 1] = obj
			end
		end
	else
		table.iappend(objs, g_Units)
	end
	table.sortby_field(objs, "session_id")
	return objs
end