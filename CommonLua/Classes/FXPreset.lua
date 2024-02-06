local function ActionFXTypesCombo()
	local list_back = { "Inherit Action", "Inherit Moment", "Inherit Actor", "FX Remove" }
	local added = { [""] = true, ["any"] = true }
	for i = 1, #list_back do
		added[list_back[i]] = true
	end
	local list = {}
	ClassDescendantsList("ActionFX", function(name, class)
		if not added[class.fx_type] then
			list[#list+1] = class.fx_type
			added[class.fx_type] = true
		end
	end)
	table.sort(list, CmpLower)
	table.insert(list, 1, "any")
	for i = 1, #list_back do
		list[#list+1] = list_back[i]
	end
	return list
end

local fx_class_list = false
function OnMsg.ClassesBuilt()
	fx_class_list = {}
	ClassDescendantsList("ActionFX", function(name, class)
		if class.fx_type ~= "" and not class:IsKindOf("ModItem") then
			fx_class_list[#fx_class_list+1] = class
		end
	end)
	ClassDescendantsList("ActionFXInherit", function(name, class)
		if class.fx_type ~= "" then
			fx_class_list[#fx_class_list+1] = class
		end
	end)
	table.sort(fx_class_list, function(c1, c2) return c1.fx_type < c2.fx_type end)
end

local function GetInheritActionFX(action)
	local fxlist = FXLists.ActionFXInherit_Action or {}
	if action == "any" then
		return table.copy(fxlist)
	end
	local rules = (FXInheritRules_Actions or RebuildFXInheritActionRules())[action]
	if not rules then return end
	local inherit = { [action] = true}
	for i = 1, #rules do
		inherit[rules[i]] = true
	end
	local list = {}
	for i = 1, #fxlist do
		local fx = fxlist[i]
		if inherit[fx.Action] then
			list[#list+1] = fx
		end
	end
	return list
end

local function GetInheritMomentFX(moment)
	local fxlist = FXLists.ActionFXInherit_Moment or {}
	if moment == "any" then
		return table.copy(fxlist)
	end
	local rules = (FXInheritRules_Moments or RebuildFXInheritMomentRules())[moment]
	if not rules then return end
	local inherit = { [moment] = true}
	for i = 1, #rules do
		inherit[rules[i]] = true
	end
	local list = {}
	for i = 1, #fxlist do
		local fx = fxlist[i]
		if inherit[fx.Moment] then
			list[#list+1] = fx
		end
	end
	return list
end

local function GetInheritActorFX(actor)
	local fxlist = FXLists.ActionFXInherit_Actor or {}
	if actor == "any" then
		return table.copy(fxlist)
	end
	local rules = (FXInheritRules_Actors or RebuildFXInheritActorRules())[actor]
	if not rules then return end
	local inherit = { [actor] = true}
	for i = 1, #rules do
		inherit[rules[i]] = true
	end
	local list = {}
	for i = 1, #fxlist do
		local fx = fxlist[i]
		if inherit[fx.Actor] then
			list[#list+1] = fx
		end
	end
	return list
end

if FirstLoad then
	DuplicatedFX = {}
end

local function MatchActionFX(actionFXClass, actionFXMoment, actorFXClass, targetFXClass, source, game_states, fx_type, match_type, detail_level, save_in, duplicates)
	local list = {}
	local remove_ids
	local inherit_actions = actionFXClass  and (FXInheritRules_Actions or RebuildFXInheritActionRules())[actionFXClass]
	local inherit_moments = actionFXMoment and (FXInheritRules_Moments or RebuildFXInheritMomentRules())[actionFXMoment]
	local inherit_actors  = actorFXClass   and (FXInheritRules_Actors  or RebuildFXInheritActorRules() )[actorFXClass]
	local inherit_targets = targetFXClass  and (FXInheritRules_Actors  or RebuildFXInheritActorRules() )[targetFXClass]
	detail_level = detail_level or 0
	
	local i, action
	if actionFXClass == "any" then
		action = next(FXRules)
	else
		i, action = 0, actionFXClass
	end
	local duplicated = DuplicatedFX
	while action do
		local rules1 = FXRules[action]
		if rules1 then
			local i, moment
			if actionFXMoment == "any" then
				moment = next(rules1)
			else
				i, moment = 0, actionFXMoment
			end
			while moment do
				local rules2 = rules1[moment]
				if rules2 then
					local i, actor
					if actorFXClass == "any" then
						actor = next(rules2)
					else
						i, actor = 0, actorFXClass
					end
					while actor do
						local rules3 = actor and rules2[actor]
						if rules3 then
							local i, target
							if targetFXClass == "any" then
								target = next(rules3)
							else
								i, target = 0, targetFXClass
							end
							while target do
								local rules4 = target and rules3[target]
								if rules4 then
									for i = 1, #rules4 do
										local fx = rules4[i]
										local match = not IsKindOf(fx, "ActionFX") or fx:GameStatesMatched(game_states)
										match = match and (not fx_type or fx_type == "any" or fx_type == fx.fx_type)
										match = match and (detail_level == 0 or detail_level == fx.DetailLevel)
										match = match and (not save_in or save_in == fx.save_in)
										match = match and (not duplicates or duplicated[fx])
										match = match and (source == "any" or fx.Source == source)
										if match then
											list[fx] = true
										end
									end
								end
								if targetFXClass == "any" then
									target = next(rules3, target)
								else
									if target == "any" or match_type == "Exact" then break end
									i = i + 1
									target = inherit_targets and inherit_targets[i] or match_type ~= "NoAny" and "any"
								end
							end
						end
						if actorFXClass == "any" then
							actor = next(rules2, actor)
						else
							if actor == "any" or match_type == "Exact" then break end
							i = i + 1
							actor = inherit_actors and inherit_actors[i] or match_type ~= "NoAny" and "any"
						end
					end
				end
				if actionFXMoment == "any" then
					moment = next(rules1, moment)
				else
					if moment == "any" or match_type == "Exact" then break end
					i = i + 1
					moment = inherit_moments and inherit_moments[i] or match_type ~= "NoAny" and "any"
				end
			end
		end
		if actionFXClass == "any" then
			action = next(FXRules, action)
		else
			if action == "any" or match_type == "Exact" then break end
			i = i + 1
			action = inherit_actions and inherit_actions[i] or match_type ~= "NoAny" and "any"
		end
	end
	return list
end

local function GetFXListForEditor(filter)
	filter = filter or ActionFXFilter -- to get defaults
	filter:ResetDebugFX()
	if filter.Type == "Inherit Action" then
		return GetInheritActionFX(filter.Action) or {}
	elseif filter.Type == "Inherit Moment" then
		return GetInheritMomentFX(filter.Moment) or {}
	elseif filter.Type == "Inherit Actor" then
		return GetInheritActorFX(filter.Actor) or {}
	else
		return MatchActionFX(
			filter.Action, filter.Moment, filter.Actor, filter.Target, filter.Source,
			filter.GameStatesFilters, filter.Type, filter.MatchType,
			filter.DetailLevel, filter.SaveIn, filter.Duplicates)
	end
end

if FirstLoad or ReloadForDlc then
	FXLists = {}
end

DefineClass.FXPreset = {
	__parents = { "Preset", "InitDone"},
	properties = {
		{ id = "Id", editor = false, no_edit = true, },
	},

	-- Preset
	PresetClass = "FXPreset",
	id = "",
	EditorView = Untranslated("<DescribeForEditor>"),
	GedEditor = "GedFXEditor",
	EditorMenubarName = "FX Editor",
	EditorShortcut = "Ctrl-Alt-F",
	EditorMenubar = "Editors.Art",
	EditorIcon = "CommonAssets/UI/Icons/atom electron molecule nuclear science.png",
	FilterClass = "ActionFXFilter",
}

function FXPreset:Init()
	local list = FXLists[self.class]
	if not list then
		list = {}
		FXLists[self.class] = list
	end
	list[#list+1] = self
end

function FXPreset:Done()
	table.remove_value(FXLists and FXLists[self.class], self)
end

function FXPreset:GetError()
	if self.Source == "UI" and self.GameTime then 
		return "UI FXs should not be GameTime"
	end
end

function FXPreset:GetPresetStatusText()
	local ged = FindPresetEditor("FXPreset")
	if not ged then return end
	
	local sel = ged:ResolveObj("SelectedPreset")
	if IsKindOf(sel, "GedMultiSelectAdapter") then
		local count_by_type = {}
		for _, fx in ipairs(sel.__objects) do
			local fx_type = fx.fx_type
			count_by_type[fx_type] = (count_by_type[fx_type] or 0) + 1
		end
		local t = {}
		for _, fx_type in ipairs(ActionFXTypesCombo()) do
			local count = count_by_type[fx_type]
			if count then
				t[#t + 1] = string.format("%d %s%s", count, fx_type, (count == 1 or fx_type:ends_with("s")) and "" or "s")
			end
		end
		return table.concat(t, ", ") .. " selected"
	end
	return ""
end

function FXPreset:SortPresets()
	local presets = Presets[self.PresetClass or self.class] or empty_table
	table.sort(presets, function(a, b) return a[1].group < b[1].group end)

	local keys = {}
	for _, group in ipairs(presets) do
		for _, preset in ipairs(group) do
			keys[preset] = preset:DescribeForEditor()
		end
	end

	for _, group in ipairs(presets) do
		table.stable_sort(group, function(a, b) 
			return keys[a] < keys[b]
		end)
	end

	ObjModified(presets)
end

function FXPreset:GetSavePath()
	local folder = self:GetSaveFolder()
	if not folder then return end

	return string.format("%s/%s/%s.lua", folder, self.PresetClass, self.class)
end

function FXPreset:SaveAll(...)
	local used_handles = {}
	ForEachPresetExtended(FXPreset, function(fx)
		while used_handles[fx.id] do
			fx.id = fx:GenerateUniquePresetId()
		end
		used_handles[fx.id] = true
	end)
	return Preset.SaveAll(self, ...)
end

function FXPreset:GenerateUniquePresetId()
	return random_encode64(48)
end

function FXPreset:OnEditorNew()
	if self:IsKindOf("ActionFX") then
		self:AddInRules()
	elseif self.class == "ActionFXInherit_Action" then
		RebuildFXInheritActionRules()
	elseif self.class == "ActionFXInherit_Moment" then
		RebuildFXInheritMomentRules()
	elseif self.class == "ActionFXInherit_Actor" then
		RebuildFXInheritActorRules()
	end
end

function FXPreset:OnDataReloaded()
	RebuildFXRules()
end

local function format_match(action, moment, actor, target)
	return string.format("%s-%s-%s-%s", action, moment, actor, target)
end

function FXPreset:DescribeForEditor()
	local str_desc = ""
	local str_info = ""
	local class = IsKindOf(self, "ModItem") and self.ModdedPresetClass or self.class
	
	if class == "ActionFXParticles" then
		str_desc = string.format("%s", self.Particles)
	elseif class == "ActionFXUIParticles" then
		str_desc = string.format("%s", self.Particles)
	elseif class == "ActionFXObject" or class == "ActionFXDecal" then
		str_desc = string.format("%s", self.Object)
		str_info = string.format("%s", self.Animation)
	elseif class == "ActionFXSound" then
		str_desc = string.format("%s", self.Sound) .. (self.DistantSound ~= "" and " "..self.DistantSound or "")
	elseif class == "ActionFXLight" then
		local r, g, b, a = GetRGBA(self.Color)
		str_desc = string.format("<color %d %d %d>%d %d %d %s</color>", r, g, b, r, g, b, a ~= 255 and tostring(a) or "")
		str_info = string.format("%d", self.Intensity)
	elseif class == "ActionFXRadialBlur" then
		str_desc = string.format("Strength %s", self.Strength)
		str_info = string.format("Duration %s", self.Duration)
	elseif class == "ActionFXControllerRumble" then
		str_desc = string.format("%s", self.Power)
		str_info = string.format("Duration %s", self.Duration)
	elseif class == "ActionFXCameraShake" then
		str_desc = string.format("%s", self.Preset)
	elseif class == "ActionFXInherit_Action" then
		local str_match = string.format("Inherit Action: %s -> %s", self.Action, self.Inherit)
		return string.format("<color blue>%s</color>", str_match)
	elseif class == "ActionFXInherit_Moment" then
		local str_match = string.format("Inherit Moment: %s -> %s", self.Moment, self.Inherit)
		return string.format("<color blue>%s</color>", str_match)
	elseif class == "ActionFXInherit_Actor" then
		local str_match = string.format("Inherit Actor: %s -> %s", self.Actor, self.Inherit)
		return string.format("<color blue>%s</color>", str_match)
	end
	if self.Source ~= "" and self.Spot ~= "" then
		local space = str_info ~= "" and " " or ""
		str_info = str_info .. space .. string.format("%s.%s", self.Source, self.Spot)
	end
	
	if self.Solo then
		str_info = string.format("%s (Solo)", str_info)
	end
	
	local str_match = format_match(self.Action, self.Moment, self.Actor, self.Target)
	local clr_match = self.Disabled and "255 0 0" or "75 105 198"
	local str_preset = self.Comment ~= "" and (" <color 0 128 0>" .. self.Comment .. "</color>") or ""
	if self.save_in ~= "" and self.save_in ~= "none" then
		str_preset = str_preset .. " <color 128 128 128> - " .. self.save_in .. "</color>"
	end
	
	local fx_type = IsKindOf(self, "ModItem") and "" or string.format("<color 128 128 128>%s</color> ", self.fx_type)
	str_desc = str_desc ~= "" and str_desc.." " or ""
	if fx_type == "" and str_desc == "" and str_info == "" and (self.FxId or "") == "" then
		return string.format("<color %s>%s</color>%s", clr_match, str_match, str_preset)
	end
	return string.format("<color %s>%s</color>%s\n%s%s<color 128 128 128>%s</color> <color 0 128 0>%s</color>", clr_match, str_match, str_preset, fx_type, str_desc, str_info, self.FxId or "")
end
 
function FXPreset:delete()
	Preset.delete(self)
	InitDone.delete(self)
end

function FXPreset:EditorContext()
	local context = Preset.EditorContext(self)
	table.remove_value(context.Classes, self.PresetClass)
	table.remove_value(context.Classes, "ActionFX")
	table.remove_value(context.Classes, "ActionFXInherit")
	return context
end

-- for ValidatePresetDataIntegrity
function FXPreset:GetIdentification()
	return self:DescribeForEditor():strip_tags()
end

DefineClass.ActionFXFilter = {
	__parents = { "GedFilter" },

	properties = {
		{ id = "DebugFX", category = "Match", default = false, editor = "bool", },
		{ id = "Duplicates", category = "Match", default = false, editor = "bool", help = "Works only after using the tool 'Check duplicates'!" },
		{ id = "Action", category = "Match", default = "any", editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end },
		{ id = "Moment", category = "Match", default = "any", editor = "combo", items = function(fx) return ActionMomentFXCombo(fx) end },
		{ id = "Actor", category = "Match", default = "any", editor = "combo", items = function(fx) return ActorFXClassCombo(fx) end },
		{ id = "Target", category = "Match", default = "any", editor = "combo", items = function(fx) return TargetFXClassCombo(fx) end },
		{ id = "Source", category = "Match", default = "any", editor = "choice", items = { "UI", "Actor", "ActorParent", "ActorOwner", "Target", "ActionPos", "Camera" } },
		{ id = "SaveIn", name = "Save in", category = "Match", editor = "choice", default = false, items = function(fx)
			local locs = GetDefaultSaveLocations()
			table.insert(locs, 1, { text = "All", value = false })
			return locs
		end, },
		
		{ id = "GameStatesFilter", name="Game State", category = "Match", editor = "set", default = set(), three_state = true, 
			items = function() return GetGameStateFilter() end
		},
		{ id = "DetailLevel", category = "Match", default = 0, editor = "combo", items = function()
			local levels = table.copy(ActionFXDetailLevelCombo())
			table.insert(levels, 1, {value = 0, text = "any"})
			return levels
		end },
		{ id = "Type", category = "Match", editor = "choice", items = ActionFXTypesCombo, default = "any", buttons = {{name = "Create New", func = "CreateNew"}}},
		{ id = "MatchType", category = "Match", default = "Exact", editor = "choice", items = { "All", "Exact", "NoAny" }, },
		{ id = "ResetButton", category = "Match", editor = "buttons",  buttons = {{name = "Reset filter", func = "ResetAction"} }, default = false },
		
		{ id = "FxCounter", category = "Match", editor = "number", default = 0, read_only = true, },
	},

	fx_counter = false,
	last_lists = false,
}

function ActionFXFilter:TryReset(ged, op, to_view)
	if op == GedOpPresetDelete then
		return
	end
	if to_view and #to_view == 2 and type(to_view[1]) == "table" then
		-- check if the new item is hidden and only then reset the filter
		local obj = ged:ResolveObj("root", table.unpack(to_view[1]))
		local matched_fxs = GetFXListForEditor(self)
		if not matched_fxs[obj] then
			return GedFilter.TryReset(self, ged, op, to_view)
		end
	else
		return GedFilter.TryReset(self, ged, op, to_view)
	end
end

function ActionFXFilter:ResetAction(root, prop_id, ged)
	if self:TryReset(ged) then
		self:ResetTarget(ged)
	end
end

function ActionFXFilter:CreateNew(root, prop_id, ged)
	if self.Type == "any" then
		print("Please specify the fx TYPE first")
		return
	end
	
	local idx = table.find(fx_class_list, "fx_type", self.Type)
	if idx then
		local old_value = self.Type
		ged:Op(nil, "GedOpNewPreset", "root", { false, fx_class_list[idx].class })
		self.Type = old_value
		ObjModified(self)
	end
end 

function ActionFXFilter:GetFxCounter()
	if not self.fx_counter then
		local counter = 0
		for _, group in ipairs(Presets.FXPreset) do
			counter = counter + #group
		end
		self.fx_counter = counter
	end
	return self.fx_counter
end

function ActionFXFilter:FilterObject(obj)
	if obj:IsKindOf("ActionFXInherit") then
		return
			obj:IsKindOf("ActionFXInherit_Action") and (self.Action == "any" or obj.Action == self.Action or obj.Inherit == self.Action) or
			obj:IsKindOf("ActionFXInherit_Moment") and (self.Moment == "any" or obj.Moment == self.Moment or obj.Inherit == self.Moment) or
			obj:IsKindOf("ActionFXInherit_Actor")  and (self.Actor  == "any" or obj.Actor  == self.Actor  or obj.Inherit == self.Actor )
	end
	if self.last_lists then
		return self.last_lists[obj]
	end
	return true
end

function ActionFXFilter:ResetDebugFX()
	if self.DebugFX then
		DebugFX       = self.Actor  ~= "any" and self.Actor  or true
		DebugFXAction = self.Action ~= "any" and self.Action or false
		DebugFXMoment = self.Moment ~= "any" and self.Moment or false
		DebugFXTarget = self.Target ~= "any" and self.Target or false
	else
		DebugFX       = false
		DebugFXAction = false
		DebugFXMoment = false
		DebugFXTarget = false
	end
end

function ActionFXFilter:PrepareForFiltering()
	self.last_lists = GetFXListForEditor(self)
end

function ActionFXFilter:DoneFiltering(count)
	if self.fx_counter ~= count then
		self.fx_counter = count
		ObjModified(self)
	end
end

function OnMsg.GedClosing(ged_id)
	local ged = GedConnections[ged_id]
	if ged.app_template == "GedFXEditor" then
		local filter = ged:FindFilter("root")
		filter.DebugFX = false
		filter:ResetDebugFX()
	end
end

function GedOpFxUseAsFilter(ged, root, sel)
	local preset = root[sel[1]][sel[2]]
	if preset then
		local filter = ged:FindFilter("root")
		filter.Action = preset.Action
		filter.Moment = preset.Moment
		filter.Actor = preset.Actor
		filter.Target = preset.Target
		filter.SaveIn = preset.SaveIn
		filter:ResetTarget(ged)
	end
end

function CheckForDuplicateFX()
	local count = 0
	local type_to_props = {}
	local ignore_classes = {
		ActionFXBehavior = true,
	}
	local ignore_props = {
		id = true,
	}
	local duplicated = {}
	DuplicatedFX = duplicated
	for action_id, actions in pairs(FXRules) do
		for moment_id, moments in pairs(actions) do
			for actor_id, actors in pairs(moments) do
				for target_id, targets in pairs(actors) do
					local str_to_fx = {}
					for _, fx in ipairs(targets) do
						local class = fx.class
						if not ignore_classes[class] then
							local str = pstr(class, 1024)
							local props = type_to_props[class]
							if not props then
								props = {}
								type_to_props[class] = props
								for _, prop in ipairs(g_Classes[class]:GetProperties()) do
									local id = prop.id
									if not ignore_props[id] then
										props[#props + 1] = id
									end
								end
							end
							for _, id in ipairs(props) do
								str:append("\n")
								ValueToLuaCode(fx:GetProperty(id), "", str)
							end
							local key = tostring(str)
							local prev_fx = str_to_fx[key]
							if prev_fx then
								GameTestsError("Duplicate FX:", fx.fx_type, action_id, moment_id, actor_id, target_id)
								count = count + 1
								duplicated[prev_fx] = true
								duplicated[fx] = true
							else
								str_to_fx[key] = fx
							end
						end
					end
				end
			end
		end
	end
	GameTestsPrintf("%d duplicated FX found!", count)
	return count
end

function GameTests.TestActionFX()
	CheckForDuplicateFX()
end

function GedOpFxCheckDuplicates(ged, root, sel)
	CheckForDuplicateFX()
end