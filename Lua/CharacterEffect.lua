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

function GetCharacterEffectId(self)
	if IsKindOf(self, "CharacterEffect") then 
		return self.class 
	end
	if IsKindOf(self, "CharacterEffectCompositeDef") then 
		return self.id 
	end
end

-- CompositeDef code
DefineClass.CharacterEffectCompositeDef = {
	__parents = { "CompositeDef", "MsgActorReactionsPreset" },
	
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

function CharacterEffectCompositeDef:VerifyReaction(event, reaction_def, actor, ...)
	if not IsKindOf(actor, "StatusEffectObject") then
		return
	end
	
	local id = GetCharacterEffectId(self)
	if actor and (event == "StatusEffectAdded" or event == "StatusEffectRemoved") then
		local _id = select(2, ...)
		return id == _id
	end
	return actor:HasStatusEffect(id)
end

function CharacterEffectCompositeDef:GetReactionActors(event, reaction_def, ...)
	local objs = {}
	local id = GetCharacterEffectId(self)
	for session_id, data in pairs(gv_UnitData) do
		local obj = ZuluReactionResolveUnitActorObj(session_id, data)
		if obj:HasStatusEffect(id) then
			objs[#obj + 1] = obj
		end
	end
	table.sortby_field(objs, "session_id")
	return objs
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
-- end of CompositeDef code

DefineClass.StatusEffectObject = {
	__parents = { "PropertyObject", "InitDone" },
	
	properties = {
		{ id = "StatusEffects", editor = "nested_list", default = false, no_edit = true, },
		{ id = "StatusEffectImmunity", editor = "nested_list", default = false, no_edit = true, },
		{ id = "StatusEffectReceivedTime", editor = "nested_list", default = false, no_edit = true, },
	},
}

function StatusEffectObject:Init()
	self.StatusEffects = {}
	self.StatusEffectImmunity = {}
	self.StatusEffectReceivedTime = {}
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
		self.StatusEffectReceivedTime[id] = GameTime()
		self:AddReactions(effect, effect.unit_reactions)
		effect:OnAdded(self)
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
	self:CallReactions("OnStatusEffectAdded", id, stacks)
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
		self.StatusEffectReceivedTime[id] = nil
		self:UpdateStatusEffectIndex()
		for _, mod in ipairs(preset:GetProperty("Modifiers")) do
			self:RemoveModifier("StatusEffect:"..id, mod.target_prop)
		end
		self:RemoveReactions(effect)
		effect:OnRemoved(self)
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
		self.StatusEffectReceivedTime[id] = nil
		self:UpdateStatusEffectIndex()
		for _, mod in ipairs(preset:GetProperty("Modifiers")) do
			self:RemoveModifier("StatusEffect:"..id, mod.target_prop)
		end
		self:RemoveReactions(effect)
		effect:OnRemoved(self)
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
	self:CallReactions("OnStatusEffectRemoved", id, effect.stacks)
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
				if effect.RemoveOnCampaignTimeAdvance or effect.RemoveOnEndCombat then
					unit:RemoveStatusEffect(effect.class)
					
					local unitData = gv_UnitData[unit.session_id]
					unitData:RemoveStatusEffect(effect.class)
				end
			end
		end
	end
end

function OnMsg.ExplorationTick()
	for _, unit in ipairs(g_Units) do
		for _, effect in ripairs(unit.StatusEffects) do
			if effect.RemoveOnEndCombat and (GameTime() > (unit.StatusEffectReceivedTime[effect.class] or 0) + 5000) then
				unit:RemoveStatusEffect(effect.class)
			end
		end
	end
end