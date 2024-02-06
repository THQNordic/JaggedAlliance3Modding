--local err, folders = AsyncListFiles(path.assets.exporter, "*", "recursive,relative,folders")

g_AllInteractableIconsCached = false
function AllInteractableIcons()
	if not g_AllInteractableIconsCached then
		local err, files = AsyncListFiles("UI/Hud/", "iw*")
		if not err then
			files = table.map(files, function(f)
				local path, file, ext = SplitPath(f) 
				return path .. file 
			end)
			g_AllInteractableIconsCached = files
		else
			g_AllInteractableIconsCached = {}
		end
	end
	return g_AllInteractableIconsCached
end

--[[@@@
@class CustomInteractable
CustomInteractable is a special type of Interactable object (doesn't have too much in common with Interactables, but provides similar functions).
These objects can be interacted with in only one way - a "custom interaction" that they define through conditions and effects.
Meaning - instead of inheriting from this class, conditions and effects should be assigned, to define it's interaction.
When placed in the world, this object is invisible (can be seen only in editor mode).
It should be made visible in the game through other dummy objects, by putting them all in a collection.
]]
DefineClass.CustomInteractable = {
	__parents = { "EditorVisibleObject", "Interactable", "BoobyTrappable", "Object", "GridMarker" },
	properties = {
		{ category = "Interactable", id = "DisplayName", name = "Display Name", editor = "text", translate = true, default = "" },
		{ category = "Interactable", id = "ActionPoints", name = "Action Points", editor = "number", scale = "AP", default = const["Action Point Costs"].CustomInteractableInteractionCost },
		{ category = "Interactable", id = "InteractionLoadingBar", name = "Interaction Loading Bar", editor = "bool", default = true },
		--{ category = "Interactable", id = "Icon", name = "Icon", editor = "text", default = "UI/Icons/Hud/interact" },
		{ category = "Interactable", id = "Visuals", name = "Visuals", editor = "choice", default = "UI/Hud/iw_examine", items = AllInteractableIcons },
		{ category = "Interactable", id = "highlight", name = "Highlight", editor = "bool", default = true },
		{ category = "Interactable", id = "special_highlight", name = "Special Highlight", editor = "bool", default = true},
		
		{ category = "Interactable", id = "EnabledConditions", name = "Enable conditions", editor = "nested_list", base_class = "Condition", default = false },
		{ category = "Interactable", id = "ConditionalSequentialEffects", name = "Execute Effects Sequentially", editor = "bool", default = true, help = "Whether effects should wait for each other when executing in order."},
		{ category = "Interactable", id = "ConditionalEffects", name = "Effects", editor = "nested_list", base_class = "Effect", all_descendants = true, default = false },
		{ category = "Interactable", id = "MultiSelectBehavior", name = "MultiSelectBehavior", editor = "choice", items = { "all", "nearest" }, default = "all" },
		{ category = "Grid Marker", id = "Type", name = "Type", editor = "dropdownlist", items = PresetGroupCombo("GridMarkerType", "Default"), default = "CustomInteractable", no_edit = true },
		{ category = "Marker", id = "AreaHeight", name = "Area Height", editor = "number", default = 0, help = "Defining a voxel-aligned rectangle with North-South and East-West axes"},
		{ category = "Marker", id = "AreaWidth",  name = "Area Width", editor = "number", default = 0, help = "Defining a voxel-aligned rectangle with North-South and East-West axes"},
	},
	
	entity = "WayPoint",
	EditorIcon = "CommonAssets/UI/Icons/about info information service",
	range_in_tiles = 3
}

--[[@@@
Returns if the custom interaction is available for execution, depending on the assigned conditions.
@function string CustomInteractable@GetUIState(Unit unit, ...)
@param - Unit[] unit - The units that want to interact with this object.
@result - string availability - Possible values "enabled", "disabled", "hidden".
]]
function CustomInteractable:GetUIState(unit, ...)
	if self.EnabledConditions then
		return self:IsMarkerEnabled({ target_units = unit, interactable = self, no_log = true }) and "enabled" or "disabled"
	end
	return "enabled"
end

--[[@@@
Performs the action itself by executing all effects and then consumes the required action points.
@function void CustomInteractable@Execute(Unit unit, ...)
@param - Unit[] unit - The units that want to interact with this object.
]]
function CustomInteractable:Execute(units, ...)
	if #units > 1 then
		MultiTargetExecute(self.MultiSelectBehavior, units, function(unit, self, ...)
			self:Execute({unit}, ...)
		end, self, ...)
		return
	end
	
	local unit = units[1]
	if self:TriggerTrap(unit) then
		return
	end
	if not self.ConditionalEffects then return end
	
	if self.ConditionalSequentialEffects then
		local endEvent = ExecuteSequentialEffects(self.ConditionalEffects, "CustomInteractable", { unit.handle }, self.handle)
		CreateRealTimeThread(function()
			WaitMsg(endEvent)
			Msg("CustomInteractableEffectsDone", self)
		end)
	else
		ExecuteEffectList(self.ConditionalEffects, unit, { target_units = {unit}, interactable = self })
		Msg("CustomInteractableEffectsDone", self)
	end
end

function CustomInteractable:GetInteractionCombatAction(unit)
	local trapAction, icon = BoobyTrappable.GetInteractionCombatAction(self, unit)
	if trapAction then return trapAction, icon end
	return Presets.CombatAction.Interactions.Interact_CustomInteractable
end

local lconversionTable = {
	["IwExamine"] = "UI/Hud/iw_examine",
	["IwLoot"] = "UI/Hud/iw_loot",
	["IwOpenDoor"] = "UI/Hud/iw_open_door",
	["IwSpeak"] = "UI/Hud/iw_speak",
}

function CustomInteractable:GetInteractionVisuals()
	local trapAction, boobyTrapIcon = BoobyTrappable.GetInteractionCombatAction(self, Selection and Selection[1])
	if trapAction and boobyTrapIcon then return boobyTrapIcon end

	local legacyIcon = lconversionTable[self.Visuals]
	if legacyIcon then return legacyIcon end
	
	return self.Visuals
end

function CustomInteractable:GetHighlightColor()
	if BoobyTrappable.GetHighlightColor(self) == 2 then return 2 end
	return self.special_highlight and 4 or 3
end

function CustomInteractable:RunDiscoverability()
	return BoobyTrappable.RunDiscoverability(self) and SpawnedByEnabledMarker(self)
end

function CustomInteractable:GetError()
	if self.DisplayName == "" then
		return string.format("CustomInteractable '%s' requires DisplayName", self.ID)
	end
end

DefineClass.ExamineMarker = {
	__parents = {"CustomInteractable"},
	properties = {
		{ category = "Interactable", id = "DisplayName", name = "Display Name", editor = "text", translate = true, default = T(923956407215, "Examine"), no_edit = true },
		{ category = "Interactable", id = "special_highlight", name = "Special Highlight", editor = "bool", default = false},
	},
	range_in_tiles = const.ExamineMarkerInteractionDistance,
	InteractionLoadingBar = false
}

function GetUnitStatsCombo()
	local items = {}
	local props = UnitPropertiesStats:GetProperties()
	for _, prop in ipairs(props) do
		if prop.category == "Stats" then
			items[#items + 1] = prop.id
		end
	end
	return items
end

DefineClass.RangeGrantMarker = {
	__parents = {"CustomInteractable"},

	properties = {
		{ category = "Grant", id = "SkillRequired", name = "Skill Required", editor = "combo", items = GetUnitStatsCombo, default = "" },
		{ category = "Grant", id = "Difficulty", name = "Difficulty", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "Easy" },
		{ category = "Grant", id = "RandomDifficulty", name = "Randomized Difficulty", editor = "bool", default = true, },
	},

	range_in_tiles = const.HerbMarkerInteractionDistance,
	floating_text_activated = T(898871916829, "Success"),
	combat_log_text_activated = T(148934830580, "(Success) Found"),
	grant_item_class = "Meds",
	grant_item_min = 1,
	grant_item_max = 5,
	
	additional_difficulty = 0,
	activated = false,
	granted = false,
}

function RangeGrantMarker:GameInit()
	if self.RandomDifficulty and self.SkillRequired ~= "" then
		self.additional_difficulty = InteractionRand(20, self.SkillRequired) - 10
	end
end

function RangeGrantMarker:GetDynamicData(data)
	if self.RandomDifficulty then
		data.additional_difficulty = self.additional_difficulty
	end
	data.activated = self.activated or nil
	data.granted = self.granted or nil
end

function RangeGrantMarker:SetDynamicData(data)
	self.additional_difficulty = data.additional_difficulty or 0
	self.activated = data.activated or false
	self.granted = data.granted or false
end

function RangeGrantMarker:GetInteractionPos(unit)
	local interaction_pos = CustomInteractable.GetInteractionPos(self, unit)
	if type(interaction_pos) == "table" then
		if not self.activated or self.granted then
			return
		end
	end
	return interaction_pos
end

function RangeGrantMarker:Activate(unit)
	NetUpdateHash("RangeMarkerActivated", unit.session_id)
	self.activated = true
	Msg("GrantMarkerDiscovered", unit, self)
	CreateFloatingText(self:GetPos(), self.floating_text_activated)
	CombatLog("important", T{self.combat_log_text_activated, unit})
	
	self.discovered = true
	if not g_Combat then
		PlayVoiceResponse(unit, "InteractableFound")
	end
end

function RangeGrantMarker:RunDiscoverability(unit)
	if self.activated then -- Check for base class only if the range grant marker has been found (activated)
		local baseClassRun = CustomInteractable.RunDiscoverability(self)
		if not baseClassRun then return false end
	end

	local visual = ResolveInteractableVisualObjects(self, nil, nil, "findFirst")
	if not visual then return false end -- No visuals, or destroyed visuals
	return true
end

function RangeGrantMarker:Grant(unit)
	self.granted = true
	local grant_amount = self.grant_item_min + InteractionRand(self.grant_item_max - self.grant_item_min, "Loot")
	grant_amount = grant_amount + (self:GetItemGainModifier() / 2)
	local left_amount = AddItemToSquadBag(unit.Squad, self.grant_item_class, grant_amount)	
	if left_amount then
		unit:AddToInventory(self.grant_item_class, left_amount)
	end
	return grant_amount
end

function RangeGrantMarker:GetItemGainModifier()
	return const.DifficultyToItemModifier[self.Difficulty]
end

function RangeGrantMarker:GrantFloatingText(unit, amount)
	if amount then
		CombatLog("short", T{959250382531, "Gathered <Amount> <Item>", {Amount = amount, Item = InventoryItemDefs[self.grant_item_class].DisplayName}})
		if unit then
			CreateFloatingText(unit:GetVisualPos(), T{959250382531, "Gathered <Amount> <Item>", Amount = amount, Item = InventoryItemDefs[self.grant_item_class].DisplayName}, nil, nil, 500)
		end
	end
end

function RangeGrantMarker:GetUIState(units, ...)
	if not self.activated or self.granted then return "disabled" end
	return CustomInteractable.GetUIState(self, units, ...)
end

function RangeGrantMarker:CheckDiscovered(unit)
	if self.activated then
		CustomInteractable.CheckDiscovered(self, unit)
		return
	end
	if self.granted or DifficultyToNumber(self.Difficulty) < 0 then return end
	if self.activated then return end

	local difficulty = DifficultyToNumber(self.Difficulty) + self.additional_difficulty
	local result = SkillCheck(unit, self.SkillRequired, difficulty, true)
	if result == "success" then
		self:Activate(unit)
	end
end

function RangeGrantMarker:Execute(units, ...)
	CustomInteractable.Execute(self, units, ...)
	
	local unit = units[1]
	local amount = self:Grant(unit)
	self:GrantFloatingText(unit, amount)
end

function RangeGrantMarker:GetTrapDisplayName()
	return T(726087963038, "Trap")
end

DefineClass.HerbMarker = {
	__parents = { "RangeGrantMarker" },

	properties = {
		{ category = "Grant", id = "SkillRequired", name = "Skill Required", editor = "combo", items = GetUnitStatsCombo, default = "Wisdom", read_only = true },
		{ category = "Interactable", id = "special_highlight", name = "Special Highlight", editor = "bool", default = false},
		{ category = "Interactable", id = "Visuals", name = "Visuals", editor = "choice", default = "UI/Hud/iw_loot", items = AllInteractableIcons },
		{ category = "Grid Marker", id = "Groups",  name = "Groups", editor = "string_list", items = function() return GridMarkerGroupsCombo() end, default = {"Herb"}, arbitrary_value = true, },
		{ category = "Grant", id = "Difficulty", name = "Difficulty", editor = "combo", items = const.DifficultyPresetsWisdomMarkersNew, arbitrary_value = false, default = "Easy" },
	},

	floating_text_activated = T(250845372777, "<em>Wisdom</em>: Herbs found"),
	combat_log_text_activated = T(565308531076, "<Nick> found <em>Herbs</em> in the area"),
	grant_item_class = "Meds",
	grant_item_min = 2,
	grant_item_max = 5,
	DisplayName = T(363687811545, "Gather Herbs"),
}

DefineClass.SalvageMarker = {
	__parents = { "RangeGrantMarker" },

	properties = {
		{ category = "Grant", id = "SkillRequired", name = "Skill Required", editor = "combo", items = GetUnitStatsCombo, default = "Mechanical", read_only = true },
		{ category = "Interactable", id = "special_highlight", name = "Special Highlight", editor = "bool", default = false},
		{ category = "Interactable", id = "Visuals", name = "Visuals", editor = "choice", default = "UI/Hud/iw_loot", items = AllInteractableIcons },
		{ category = "Grid Marker", id = "Groups",  name = "Groups", editor = "string_list", items = function() return GridMarkerGroupsCombo() end, default = {"Salvage"}, arbitrary_value = true, },
	},

	floating_text_activated = T(938112938808, "<em>Mechanical</em>: Salvage found"),
	combat_log_text_activated = T(909344877136, "<Nick> found salvageable <em>Parts</em> in the area"),
	grant_item_class = "Parts",
	grant_item_min = 2,
	grant_item_max = 5,
	DisplayName = T(579260739215, "Salvage Parts"),
}

function SalvageMarker:GrantFloatingText(unit, amount)
	if unit and amount then
		CreateFloatingText(unit:GetVisualPos(), T{178669996888, "Salvaged <Amount> parts", Amount = amount}, nil, nil, 500)
	end
end

DefineClass.HackMarker = {
	__parents = { "RangeGrantMarker" },

	properties = {
		{ category = "Grant", id = "SkillRequired", name = "Skill Required", editor = "combo", items = GetUnitStatsCombo, default = "Mechanical", read_only = true },
		{ category = "Grant", id = "Difficulty", name = "Difficulty", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "Medium" },
		{ category = "Grant", id = "MoneyWeight", name = "Money Weight", editor = "number", default = 7000, min = 0},
		{ category = "Grant", id = "IntelWeight", name = "Intel Weight", editor = "number", default = 3000, min = 0},
		{ category = "Grant", id = "MoneyAmount", name = "Money to Grant", editor = "number", default = 250},
		{ category = "Interactable", id = "Visuals", name = "Visuals", editor = "choice", default = "UI/Hud/iw_hack", items = AllInteractableIcons },
		{ category = "Grid Marker", id = "Groups",  name = "Groups", editor = "string_list", items = function() return GridMarkerGroupsCombo() end, default = {"Hack"}, arbitrary_value = true, },
	},
	
	floating_text_activated = T(526938056924, "<em>Mechanical</em>: Hackable device found"),
	combat_log_text_activated = T(968826403710, "<Nick> found a <em>Hackable device</em> in the area"),
	grantedItem = "",
	grantedAmount = false,
	DisplayName = T(825733718854, "Hack"),
}

function HackMarker:Execute(units, ...)
	RangeGrantMarker.Execute(self, units, ...)
end

function HackMarker:Grant(unit)
	local intelSectors = GetSectorsAvailableForIntel(2)
	local weightTable = {{self.MoneyWeight, "Money"}}
	if next(intelSectors) then
		weightTable[#weightTable + 1] = {self.IntelWeight, "Intel"}
	end
	self.grantedItem = #weightTable > 1 and GetWeightedRandom(weightTable, unit:Random()) or "Money"
	
	if self.grantedItem == "Money" then
		local moneyRandomModifier = 1 + unit:Random(4)
		local amount = self.MoneyAmount * (moneyRandomModifier + self:GetItemGainModifier())
		amount = unit:CallReactions_Modify("OnCalcHackMoneyGained", amount)
		AddMoney(amount, "deposit")
		self.grantedAmount = amount
	else
		DiscoverIntelForRandomSector(2)
		unit:CallReactions("OnHackIntelDsicovered")
	end
	self.granted = true
end

function HackMarker:GrantFloatingText(unit)
	if not unit then return end
	
	if self.grantedItem == "Money" then
		if not self.grantedAmount then return end
		CreateFloatingText(unit:GetVisualPos(), T{596293026247, "Gained <money(Amount)>", Amount = self.grantedAmount}, nil, nil, 500)
	elseif self.grantedItem == "Intel" then
		CreateFloatingText(unit:GetVisualPos(), T(993640719450, "Gained Intel"), nil, nil, 500)
	end
end

function HackMarker:CheckDiscovered(unit)
	if self.activated then
		CustomInteractable.CheckDiscovered(self, unit)
		return
	end
	if self.granted or DifficultyToNumber(self.Difficulty) < 0 then return end
	if self.activated then return end

	local difficulty = DifficultyToNumber(self.Difficulty) + self.additional_difficulty
	if HasPerk(unit, "MrFixit") then
		difficulty = difficulty - CharacterEffectDefs.MrFixit:ResolveValue("mrfixit_bonus")
	end
	
	local result = SkillCheck(unit, self.SkillRequired, difficulty, true)
	if result == "success" then
		self:Activate(unit)
	end
end