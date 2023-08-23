UndefineClass("CharacterEffect")
UndefineClass("StatusEffect")
UndefineClass("Perk")

DefineClass("CharacterEffect", "Modifiable", "CharacterEffectProperties")
DefineClass("StatusEffect", "CharacterEffect")
DefineClass("Perk", "CharacterEffect", "PerkProperties")

const.DbgStatusEffects = false

function CharacterEffect:ResolveValue(key)
	local value = self:GetProperty(key)
	if value then return value end
	
	-- Check in the instance parameters first.
	if self.InstParameters then
		local found = table.find_value(self.InstParameters, "Name", key)
		if found then
			return found.Value
		end
	end
	-- Check in the template
	local template = CharacterEffectDefs[self.class]
	return template and template:ResolveValue(key)
end

function CharacterEffect:__toluacode(indent, pstr, GetPropFunc)
	if not pstr then
		return string.format("PlaceCharacterEffect('%s', %s)", self.class, ObjPropertyListToLuaCode(self, indent, GetPropFunc))
	end
	pstr:appendf("PlaceCharacterEffect('%s', ", self.class)
	ObjPropertyListToLuaCode(self, indent, GetPropFunc, pstr)
	return pstr:append(")")
end

-- CompositeDef code
DefineClass.CharacterEffectCompositeDef = {
	__parents = { "CompositeDef", "MsgReactionsPreset" },
	
	-- Composite def
	ObjectBaseClass = "CharacterEffect",
	ComponentClass = false,
	
	-- Preset
	EditorMenubarName = "Character Effect Editor",
	EditorMenubar = "Combat",
	EditorMenubarSortKey = "-8",
	EditorShortcut = "",
	EditorIcon = "CommonAssets/UI/Icons/atom molecule science.png",
	EditorPreview = Untranslated("<Group> <StatValue>"),
	GlobalMap = "CharacterEffectDefs",
	
	HasParameters = true,
	HasSortKey = true,
	
	-- 'true' is much faster, but it doesn't call property setters & clears default properties upon saving
	StoreAsTable = false,
	-- Serialize props as an array => {key, value, key value}
	store_as_obj_prop_list = true
}

DefineModItemCompositeObject("CharacterEffectCompositeDef", {
	EditorName = "Character effect",
	EditorSubmenu = "Unit",
})

if config.Mods then 
	function ModItemCharacterEffectCompositeDef:delete()
		CharacterEffectCompositeDef.delete(self)
		ModItemCompositeObject.delete(self)
	end


	function ModItemCharacterEffectCompositeDef:TestModItem(ged)
		ModItemCompositeObject.TestModItem(self, ged)
		if IsKindOf(SelectedObj, "Unit") then
			SelectedObj:AddStatusEffect(self.id)
		else
			ModLog(T(187070922299, "Cannot add the status effect as no unit is selected."))
		end
	end
end

function CharacterEffectCompositeDef:delete()
	MsgReactionsPreset.delete(self)
end

function CharacterEffectCompositeDef:ResolveValue(key)
	local value = self:GetProperty(key)
	if value then return value end

	if self.HasParameters and self.Parameters then
		local found = table.find_value(self.Parameters, "Name", key)
		if found then
			return found.Value
		end
	end
end

-- Overwrite of the old PlaceCharacterEffect
function PlaceCharacterEffect(item_id, instance, ...)
	local id = item_id
	
	local class = g_Classes[id]
	if not class then
		assert(string.format("Class %s not found", id))
		-- In case the class was deleted and we're loading an older save file
		return PlaceCharacterEffect("MissingEffect", instance, ...)
	end
	
	local obj
	if CharacterEffectCompositeDef.store_as_obj_prop_list then
		obj = class:new({}, ...)
		SetObjPropertyList(obj, instance)
	else
		obj = class:new(instance, ...)
	end
	
	return obj
end

function CharacterEffectCompositeDef:OnPreSave()
	for _, reaction in ipairs(self.msg_reactions) do
		if reaction:HasMember("__generateHandler") then
			reaction:__generateHandler()
		end
	end
end

function CharacterEffectCompositeDef:GetError()
	local effect_reactions = {}
	for _, reaction in ipairs(self.msg_reactions) do
		if effect_reactions[reaction.Event] then
			return string.format("Multiple reactions defined for event %s, only the first one will be executed!", reaction.Event)
		end
		effect_reactions[reaction.Event] = true
	end
end
-- end of CompositeDef code

DefineClass.StatusEffectObject = {
	__parents = { "PropertyObject", "InitDone" },
	
	properties = {
		{ id = "StatusEffects", editor = "nested_list", default = false, no_edit = true, },
		{ id = "StatusEffectImmunity", editor = "nested_list", default = false, no_edit = true, },
	},
}

function StatusEffectObject:Init()
	self.StatusEffects = {}
	self.StatusEffectImmunity = {}
end

function StatusEffectObject:UpdateStatusEffectIndex()
	local effects = self.StatusEffects
	for i, effect in ipairs(effects) do
		if effect and effect.class then
			effects[effect.class] = i
		end
	end
end

function StatusEffectObject:GetStatusEffect(id)
	local idx = self.StatusEffects[id]
	return idx and self.StatusEffects[idx]
end

function StatusEffectObject:HasStatusEffect(id)
	return self.StatusEffects[id]
end

function StatusEffectObject:ReportStatusEffectsInLog()
	return const.DbgStatusEffects
end

function StatusEffectObject:AddStatusEffectImmunity(effect, reason)
	self.StatusEffectImmunity[effect] = self.StatusEffectImmunity[effect] or {}
	self.StatusEffectImmunity[effect][reason] = true
	self:RemoveStatusEffect(effect)
end

function StatusEffectObject:RemoveStatusEffectImmunity(effect, reason)
	if self.StatusEffectImmunity[effect] then
		self.StatusEffectImmunity[effect][reason] = nil
		if next(self.StatusEffectImmunity[effect]) == nil then
			self.StatusEffectImmunity[effect] = nil
		end
	end
end

function StatusEffectObject:AddStatusEffect(id, stacks)
	NetUpdateHash("StatusEffectObject:AddStatusEffect", self, id, IsValid(self) and self:HasMember("GetPos") and self:GetPos())
	if self.StatusEffectImmunity[id] or (IsKindOfClasses(self, "Unit", "UnitData") and self:IsDead()) then 
		return 
	end
	stacks = stacks or 1
	local preset = CharacterEffectDefs[id]
	local effect = self:GetStatusEffect(id)
	local cur_stacks = effect and effect.stacks or 0
	if cur_stacks >= preset:GetProperty("max_stacks") then
		return
	end
	
	local context = {}
	context.target_units = {self}
	local ok = EvalConditionList(preset:GetProperty("Conditions"), self, context)
	if not ok then
		return
	end	
	
	local refresh
	local newStack = false
	
	if not effect then
		effect = PlaceCharacterEffect(id)
		effect.stacks = Min(stacks, effect.max_stacks)
		table.insert(self.StatusEffects, effect)
		self.StatusEffects[id] = #self.StatusEffects
		newStack = true
		
		table.sort(self.StatusEffects, function(a,b) 
			return CharacterEffectDefs[a.class].SortKey < CharacterEffectDefs[b.class].SortKey
		end)
		self:UpdateStatusEffectIndex()
		
		for _, mod in ipairs(preset:GetProperty("Modifiers")) do
			self:AddModifier("StatusEffect:"..id, mod.target_prop, mod.mod_mul*10, mod.mod_add)
		end
	else
		newStack = effect.stacks
		effect.stacks = Min(effect.stacks + stacks, effect.max_stacks)
		newStack = effect.stacks > newStack
		refresh = true
	end
	effect.CampaignTimeAdded = Game.CampaignTime
	if Platform.developer and self:ReportStatusEffectsInLog() and newStack then
		if not self:IsDead() then
			CombatLog("debug", T{Untranslated("<em><effect></em> (<name>)"), name = self:GetLogName(), effect = effect.DisplayName or Untranslated(id)})
		end
	end
	if effect.AddEffectText and effect.AddEffectText ~= "" and not refresh then
		if not self:IsDead() then
			CombatLog("short", T{effect.AddEffectText, self})
		end		
	end	
	if IsValid(self) and effect.HasFloatingText and newStack then
		CreateMapRealTimeThread(function()
			WaitPlayerControl()
			CreateFloatingText(self, T{961020758708, "+ <DisplayName>", effect}, nil, nil, true)
		end)
	end
	
	if effect.lifetime ~= "Indefinite" and IsKindOf(self, "Unit") and g_Combat then
		local duration = effect.lifetime == "Until End of Next Turn" and 1 or 0
		if g_CurrentTeam and g_Teams[g_CurrentTeam] and not g_Teams[g_CurrentTeam].player_team then
			duration = duration + 1
		end
		self:SetEffectExpirationTurn(id, "expiration", g_Combat.current_turn + duration)
	end

	ObjModified(self.StatusEffects)
	Msg("StatusEffectAdded", self, id, stacks)
	return effect
end

function StatusEffectObject:RemoveStatusEffect(id, stacks, reason)
	local has = self:HasStatusEffect(id)
	if not has then return end
	NetUpdateHash("StatusEffectObject:RemoveStatusEffect", self, id, self:HasMember("GetPos") and self:GetPos())
	
	local effect = self.StatusEffects[has]
	local preset = CharacterEffectDefs[id]
	if not effect.stacks then -- shield from faulty effects
		table.remove(self.StatusEffects, has)
		self.StatusEffects[id] = nil
		self:UpdateStatusEffectIndex()
		for _, mod in ipairs(preset:GetProperty("Modifiers")) do
			self:RemoveModifier("StatusEffect:"..id, mod.target_prop)
		end
		return
	end
	
	if reason == "death" and effect.dontRemoveOnDeath then
		return
	end
	
	local lost
	local to_remove = (stacks == "all" and effect.stacks) or stacks or 1
	local removedStacks = Min(effect.stacks, to_remove)
	effect.stacks = Max(0, effect.stacks - to_remove)
	if effect.stacks == 0 then
		table.remove(self.StatusEffects, has)
		self.StatusEffects[id] = nil
		self:UpdateStatusEffectIndex()
		for _, mod in ipairs(preset:GetProperty("Modifiers")) do
			self:RemoveModifier("StatusEffect:"..id, mod.target_prop)
		end
		lost = true
		if Platform.developer and self:ReportStatusEffectsInLog() then
			if not self:IsDead() then
				CombatLog("debug", T{Untranslated("<name> lost effect <effect>"), name = self:GetLogName(), effect = effect.DisplayName or Untranslated(id)})
			end
		end
		if effect.RemoveEffectText then
			if not self:IsDead() then
				CombatLog("short", T{effect.RemoveEffectText, self})
			end
		end
	end

	ObjModified(self.StatusEffects)
	Msg("StatusEffectRemoved", self, id, removedStacks, reason)
end

function StatusEffectObject:HasVisibleEffects()
	for _, effect in ipairs(self.StatusEffects) do
		if effect.Shown then
			return true
		end
	end
	return false
end

function StatusEffectObject:GetUIVisibleStatusEffects(addBadgeHidden)
	local vis = {}
	
	for _, effect in ipairs(self.StatusEffects) do
		if effect and effect.Shown and effect.Icon and (addBadgeHidden or not effect.HideOnBadge) then
			vis[#vis + 1] = effect
		end
	end
	
	return vis
end

function StatusEffectObject:RemoveAllCharacterEffects()
	while #self.StatusEffects > 0 do
		self:RemoveStatusEffect(self.StatusEffects[1].class, "all")
	end
end

function StatusEffectObject:RemoveAllStatusEffects(reason)
	for i = #self.StatusEffects, 1, -1 do
		local effect = self.StatusEffects[i]
		if IsKindOf(effect, "StatusEffect") then
			self:RemoveStatusEffect(effect.class, "all", reason)
		end
	end
end

PerkSortTable = {
	Personal = 1,
	Personality = 2,
	Specialization = 3,
	Quirk = 4,
	Gold = 5,
	Silver = 6,
	Bronze = 7,
}

function StatusEffectObject:GetPerks(tier_level, sort)
	if not self.StatusEffects then return empty_table end
	local result = table.ifilter(self.StatusEffects, function(i, s)	
		return IsKindOf(s, "Perk") 
				and (not tier_level or s.Tier==tier_level)
	end)
	
	if sort then
		table.sort(result, function(a, b)
			local z = PerkSortTable[a.Tier] or 0
			local x = PerkSortTable[b.Tier] or 0
			if z==x then 
				return a.class<b.class 
			end
			return z < x
		end)
	end
	
	return result
end

function StatusEffectObject:GetPerksByStat(stat)
	if not self.StatusEffects or not stat then return empty_table end
	return table.ifilter(self.StatusEffects, function(i, s)	
		return IsKindOf(s, "Perk") and (s.Stat == stat)
	end)
end

function StatusEffectObject:HasAnyStatusEffects()
	for _, effect in ipairs(self.StatusEffects) do
		if IsKindOf(effect, "StatusEffect") then
			return true
		end
	end
	return false
end

function PersonalPerkStartingOfButtons(o)
	local mercs = {}
	ForEachPreset("UnitDataCompositeDef", function(data)
		if data.StartingPerks and table.find(data.StartingPerks, o.id) then
			mercs[#mercs + 1] = {
				name = data.id,
				func = function()
					 data:OpenEditor()
				end
			}
		end
	end)
	return mercs
end

function StatusEffectObject:StatusEffectsCleanUp()
	local effects = self.StatusEffects
	local toRemove = {}
	for key, value in pairs(effects) do
		if type(key) == "string" and not CharacterEffectDefs[key] then
			toRemove[#toRemove+1] = value
			effects[key] = nil
		end
	end
	for _, idx in ipairs(toRemove) do
		table.remove(effects, idx)
	end
end

AppendClass.MsgDef = {
	properties = {
		{ id = "SingleActor", editor = "bool", default = false, help = "When the event is fired for a single object/actor" },
		{ id = "Actor", editor = "combo", default = false, no_edit = function(self) return not self.SingleActor end,
			items = function(self)
				local items = { false }
				if (self.Params or "") ~= "" then
					local params = string.split(self.Params, ",")
					for _, param in ipairs(params) do
						items[#items + 1] = string.trim_spaces(param)
					end
				end
				return items
			end, 
			help = "Specifies the object for which the Msg is fired, if any"
		}, 
	},
}

function GetCharacterEffectId(self)
	if IsKindOf(self, "CharacterEffect") then 
		return self.class 
	end
	if IsKindOf(self, "CharacterEffectCompositeDef") then 
		return self.id 
	end
end

function CE_ExecReactionEffects(self, event, actor)
	local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", event)
	if not reaction_idx then return end
	local id = GetCharacterEffectId(self)
	if event == "StatusEffectRemoved" and actor then id = nil end -- msg comes after the removal so we shouldn't check if the unit still has it	
	local context = {}
	context.target_units = {actor}
	if id then
		if actor then
			if IsKindOf(actor, "StatusEffectObject") and actor:HasStatusEffect(id) then				
				ExecuteEffectList(self.msg_reactions[reaction_idx].Effects, actor, context)
			end
		else
			local objs = {} -- gather applicable objects first, use sorted_pairs on the filtered table
			for session_id, data in pairs(gv_UnitData) do
				local obj
				local mapUnit = g_Units[session_id]
				if gv_SatelliteView or (mapUnit and (not IsValid(mapUnit) or mapUnit.is_despawned)) then
					obj = data
				else
					obj = mapUnit
				end

				if obj and obj:HasStatusEffect(id) then
					objs[session_id] = obj
				end
			end
			for _, obj in sorted_pairs(objs) do
				context.target_units = {obj}
				ExecuteEffectList(self.msg_reactions[reaction_idx].Effects, obj, context)
			end
		end
	else
	
		ExecuteEffectList(self.msg_reactions[reaction_idx].Effects, actor, context) -- actor can be nil here
	end
end

AppendClass.Reaction = {
	properties = {
		{ id = "Handler", editor = "func", default = false, lines = 6, max_lines = 60, no_edit = true,
			name = function(self) return self.Event end,
			params = function (self) return self:GetParams() end, },
		{ id = "HandlerCode", editor = "func", default = false, lines = 6, max_lines = 60,
			name = function(self) return self.Event or "Handler" end,
			params = function (self) return self:GetParams() end, },
	},
}

function Reaction:__generateHandler()
	if type(self.HandlerCode) ~= "function" then return end
	
	local msgdef = MsgDefs[self.Event] or empty_table
	local code = string.format("local reaction_idx = table.find(self.msg_reactions or empty_table, \"Event\", \"%s\")\n", self.Event) ..
		"if not reaction_idx then return end\n"
	
	local params = self:GetParams()
	local handler_code = GetFuncSourceString(self.HandlerCode, "exec", params)
	if not handler_code or handler_code == "GetMissingSourceFallback()" then 
		handler_code = "function exec() end"
	end
	local actor = msgdef.SingleActor and msgdef.Actor
	local handler_call = string.format("exec(%s)", params)
	
	code = code .. "\nlocal " .. handler_code .. "\n"
	if actor and (self.Event == "StatusEffectRemoved" or self.Event == "StatusEffectAdded") then -- only call these when adding/removing the current effect
		code = code .. string.format("local _id = GetCharacterEffectId(self)\n")
		code = code .. string.format("if _id == id then %s end\n",handler_call)
	else
		code = code .. "local id = GetCharacterEffectId(self)\n\n"
		if actor then
			code = code .. 			
				"if id then\n" ..
					string.format("\tif IsKindOf(%s, \"StatusEffectObject\") and %s:HasStatusEffect(id) then\n", actor, actor) ..
						string.format("\t\t%s\n", handler_call) ..
					"\tend\n" ..
				"else\n" ..
					string.format("\t%s\n",handler_call) ..
				"end\n"
		else
			code = code ..			
				"if id then\n" ..
					"\tlocal objs = {}\n" ..
					"\tfor session_id, data in pairs(gv_UnitData) do\n" ..
						"\t\tlocal obj = g_Units[session_id] or data\n" ..
						"\t\tif obj:HasStatusEffect(id) then\n" ..
							"\t\t\tobjs[session_id] = obj\n" ..
						"\t\tend\n" ..
					"\tend\n" ..
					"\tfor _, obj in sorted_pairs(objs) do\n" ..
						string.format("\t\t%s\n", handler_call) ..
					"\tend\n" ..
				"else\n" ..
					string.format("\t%s\n", handler_call) ..
				"end\n"
		end
	end
	
	self.Handler = CompileFunc("Handler", params, code)
end

function Reaction:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Event" then
		self:__generateHandler()
		-- force reevaluation of the Handler's params when the event changes
		GedSetProperty(ged, self, "Handler", GameToGedValue(self.Handler, self:GetPropertyMetadata("Handler"), self))
	end
end

DefineClass.CharacterEffectReactionEffects = {
	__parents = { "Reaction" },
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

function CharacterEffectReactionEffects:__generateHandler()
	local msgdef = MsgDefs[self.Event] or empty_table
	local actor = msgdef.SingleActor and msgdef.Actor
	local code
	if actor then
		code = string.format("CE_ExecReactionEffects(self, \"%s\", %s)", self.Event, actor)
	else
		code = string.format("CE_ExecReactionEffects(self, \"%s\")", self.Event)
	end
	self.Handler = CompileFunc("Handler", self:GetParams(), code)
end

function CharacterEffectReactionEffects:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Event" then
		self:__generateHandler()
		-- force reevaluation of the Handler's params when the event changes
		GedSetProperty(ged, self, "Handler", GameToGedValue(self.Handler, self:GetPropertyMetadata("Handler"), self))
	end
end

DefineClass("MsgReactionEffects", "MsgReaction", "CharacterEffectReactionEffects")

DefineClass.UnitModifier = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "target_prop", name = "Property Name", editor = "combo", items = function() return ClassModifiablePropsNonTranslatableCombo(g_Classes.Unit) end, default = "" },
		{ id = "mod_add", name = "Add", editor = "number", default = 0,},
		{ id = "mod_mul", name = "Mul", editor = "number", scale = 100, default = 100 },
	},
	StoreAsTable = true,
	EditorView = Untranslated("Unit Modifier: (<u(target_prop)> + <mod_add>) * <FormatAsFloat(mod_mul, 100, 2)>"),
}

-- Remove marked StatusEffects on SatView Travel
function OnMsg.SquadStartedTravelling(squad)
	for _, id in ipairs(squad.units) do
		local unit = g_Units[id]
		if IsValid(unit) then
			for i = #unit.StatusEffects, 1, -1 do
				local effect = unit.StatusEffects[i]
				if effect.RemoveOnSatViewTravel then
					unit:RemoveStatusEffect(effect.class)
				end
			end
		end
		
		local unitData = gv_UnitData[id]
		for i = #unitData.StatusEffects, 1, -1 do
			local effect = unitData.StatusEffects[i]
			if effect.RemoveOnSatViewTravel then
				unitData:RemoveStatusEffect(effect.class)
			end
		end
	end
end

-- Remove marked StatusEffects on Campaign Time resume
function OnMsg.CampaignTimeAdvanced(time, ot)
	for _, unit in ipairs(g_Units) do
		if IsValid(unit) then
			for i = #unit.StatusEffects, 1, -1 do
				local effect = unit.StatusEffects[i]
				if effect.RemoveOnCampaignTimeAdvance then
					unit:RemoveStatusEffect(effect.class)
					
					local unitData = gv_UnitData[unit.session_id]
					unitData:RemoveStatusEffect(effect.class)
				end
			end
		end
	end
end