local lDefaultState = "closed"

DefineClass.ToolItem = {
	__parents = { "InventoryItem", "BobbyRayShopOtherProperties" },
	properties = {
		{ category = "Misc", id = "skillCheckPenalty", name = "Skill Check Penalty", editor = "number", default = 0, template = true,
			help = "A penalty to the skill checks of actions this tool is used in. Negative numbers will boost skill checks." },
	},
}

DefineClass("CrowbarBase", "ToolItem")
DefineClass("LockpickBase", "ToolItem")
DefineClass("WirecutterBase", "ToolItem")

local lBaseConditionLoss = 5
local lAddedRandomConditionLossMin = 0
local lAddedRandomConditionLossMax = 11

DefineClass.Lockpickable = {
	__parents = {"PropertyObject", "Interactable", "EditorObject", "EditorTextObject"},
	properties = {
		category = "Lockpickable",
		{ id = "lockpickState", name = "Lockpick State(Run-Time)", editor = "combo", default = "closed", items = { lDefaultState, "open", "locked", "blocked" }, read_only = true, dont_save = true },
		{ id = "lockpickStateMap", name = "Lockpick State(Map)", editor = "combo", default = "closed", items = { lDefaultState, "open", "locked", "blocked" }, read_only = function(self) return self:IsBlockedDueToRoom() end },
		{ id = "lockpickDifficulty", name = "Lockpick Difficulty", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "Easy", read_only = function(self) return self:IsBlockedDueToRoom() end },
		{ id = "baseBreakDifficulty", name = "Base Break Difficulty", editor = "number", default = 0, read_only = true, help = "The base difficulty inferred from the material type.", dont_save = true },
		{ id = "breakDifficulty", name = "Additional Break Difficulty", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "None" },
		{ id = "randomDifficulty", name = "Randomize Difficulty", editor = "bool", default = true, },
		{ id = "StateText"}
	},
	
	additionalDifficulty = 0,
	done = false,
	is_broken = false,
	discovered_lock = false,
	runtime_lockpick_state = false,
	editor_text_class = "TextEditor",
	editor_text_color = const.clrBlue,
}

function Lockpickable:GameInit()
	if self.randomDifficulty then
		self.additionalDifficulty = InteractionRand(20, "Lockpick") / 2
	end
	self:SetLockpickState(self.lockpickStateMap)
	self:UpdateObjProperties()
end

function Lockpickable:UpdateObjProperties()
	if self:HasMember("GetMaterialTypePreset") then
		local material = self:GetMaterialTypePreset()
		self.baseBreakDifficulty = material.breakdown_defense
	end
end

function Lockpickable:EditorEnter()
	self:UpdateObjProperties()
	self.runtime_lockpick_state = self.lockpickState		-- save so it can be restored upon exiting editor
	if self.lockpickState ~= self.lockpickStateMap then
		self:SetLockpickState(self.lockpickStateMap)
	end
end

function Lockpickable:EditorExit()
	self:UpdateObjProperties()
	if self.runtime_lockpick_state and self.runtime_lockpick_state ~= self.lockpickState then
		self:SetLockpickState(self.runtime_lockpick_state)
	end
	self.runtime_lockpick_state = false
end

function Lockpickable:OnEditorSetProperty(prop_id)
	if prop_id == "lockpickStateMap" then
		self.runtime_lockpick_state = false	-- no reseting on exiting editor if map-saved state is changed
		self:SetLockpickState(self.lockpickStateMap)
	end
end

function Lockpickable:GetDynamicData(data)
	if self.lockpickState ~= lDefaultState then data.lockpickState = self.lockpickState end
	if self.randomDifficulty then data.additionalDifficulty = self.additionalDifficulty end
	if self.is_broken then
		data.is_broken = true
	end
	if self.discovered_lock then
		data.discovered_lock = true
	end
end

function Lockpickable:SetDynamicData(data)
	if data.lockpickState then
		self.lockpickState = data.lockpickState
	elseif data.status then -- old name
		self.lockpickState = data.status
	else
		self.lockpickState = lDefaultState
	end
	self.is_broken = data.is_broken or false
	self.discovered_lock = data.discovered_lock or false
	self.additionalDifficulty = data.additionalDifficulty or 0
	self:LockpickStateChanged(self.lockpickState)
end

function IsBlockingLockpickState(state)
	return state == "locked" or state == "blocked" or state == "cuttable"
end

function Lockpickable:CannotOpen()
	return IsBlockingLockpickState(self.lockpickState)
end

function Lockpickable:GetlockpickDifficulty()
	return self.lockpickDifficulty
end

function FirstToUpper(str) --from stack overflow
	return (str:gsub("^%l", string.upper))
end

function Lockpickable:PlayLockpickableFX(fx_type, moment)
	local self_pos = self:GetVisualPos()
	local objs = rawget(self, "objects")
	local fx_obj = objs and objs[1] or self
	local fx_target = GetObjMaterial(self_pos, fx_obj)
	--local actor = fx_obj
	local actor = "Door"  --make chests/boxes/n such use lockpick hooks with door actor, requested by xaerial
	
	if fx_type == "cannot_open" then
		local action
		if self:GetlockpickDifficulty() == "Impossible" then
			action = "FailedToOpenImpossible"
		elseif self.is_broken then
			action = "FailedToOpenBroken"
		elseif self.lockpickState == "blocked" or self.lockpickState == "locked" or self.lockpickState == "cuttable" then
			action = string.format("FailedToOpen%s", FirstToUpper(self.lockpickState))
		end
		
		if not action then return end
		PlayFX(action, "start", actor, fx_target, self_pos)
	else
		PlayFX(FirstToUpper(fx_type), moment or "start", actor, fx_target, self_pos)
	end
end

function Lockpickable:PlayCannotOpenFX(unit)
	self:PlayLockpickableFX("cannot_open")
	local banterId = false
	if DifficultyToNumber(self:GetlockpickDifficulty()) == -1 then
		banterId = "DoorImpossible"
	elseif self.lockpickState == "locked" or self.lockpickState == "cuttable" then
		banterId = "DoorLocked"
		if unit.team.side == "player1" or unit.team.side == "player2" then
			PlayVoiceResponse(unit, "DoorLocked")
		end
	else
		banterId = "DoorBlocked"
	end
	PlayBanter(banterId, {unit})
	self.discovered_lock = true
end

function Lockpickable:GetInteractionCombatAction(unit)
	if not self.discovered_lock then return false end

	if self:CannotOpen() and DifficultyToNumber(self:GetlockpickDifficulty()) == -1 then
		return CombatActions.LockImpossible
	end

	if self.lockpickState == "locked" then
		if not unit then
			return CombatActions.NoToolsLocked
		end
		local hasLockpick = GetUnitLockpick(unit)
		if hasLockpick then
			return CombatActions.Lockpick
		elseif GetUnitCrowbar(unit) then
			return CombatActions.Break
		end
	
		return CombatActions.NoToolsLocked
	elseif self.lockpickState == "blocked" then
		return (not unit or not GetUnitCrowbar(unit)) and CombatActions.NoToolsBlocked or CombatActions.Break
	end
end

function Lockpickable:IsBlockedDueToRoom()
	return false
end

function Lockpickable:SetlockpickState(val)
	if self:IsBlockedDueToRoom() and val ~= "blocked" then
		return
	end
	return self:SetLockpickState(val)
end

function Lockpickable:SetLockpickState(val)
	self.lockpickState = val	
	self:LockpickStateChanged(val)
end

function Lockpickable:LockpickStateChanged(lockpickState)
	-- nop
end

function Lockpickable:EditorGetText()
	if not self.is_destroyed and self.lockpickState == "locked" then
		return string.format("Locked(%s Difficulty)", self.lockpickDifficulty)
	end
end

LockpickableActionIds = {
	"Interact_DoorOpen",
	"Interact_WindowBreak",
	"LockImpossible",
	"NoToolsBlocked",
	"NoToolsLocked",
	"Lockpick",
	"Break",
	"Cut"
}

-- Get the tool with the lowest condition
local l_get_unit_quick_slot_item

local function lGetUnitQuickSlotItem(unit, item_id)
	l_get_unit_quick_slot_item = nil
	
	local filter = function(o)
		if o.Condition > 0 and (not l_get_unit_quick_slot_item or o.Condition < l_get_unit_quick_slot_item.Condition) then
			l_get_unit_quick_slot_item = o
		end
	end
	
	unit:ForEachItemInSlot("Handheld A", item_id, filter)
	unit:ForEachItemInSlot("Handheld B", item_id, filter)
	unit:ForEachItemInSlot("Inventory", item_id, filter)
	
	return l_get_unit_quick_slot_item
end

function GetUnitLockpick(unit)
	local tool = lGetUnitQuickSlotItem(unit, "LockpickBase")
	return tool and not tool:IsCondition("Broken") and tool
end

function GetUnitCrowbar(unit)
	local tool = lGetUnitQuickSlotItem(unit, "CrowbarBase")
	return tool and not tool:IsCondition("Broken") and tool
end

function GetUnitWirecutter(unit)
	local tool = lGetUnitQuickSlotItem(unit, "WirecutterBase")
	return tool and not tool:IsCondition("Broken") and tool
end

function Lockpickable:InteractLockpick(unit)
	local tool = GetUnitLockpick(unit)
	assert(tool and self:CanUseAction("Lockpick"))
	local result = false
	local difference = 0
	
	CombatLog("debug", "Lockpick Check")
	if DifficultyToNumber(self:GetlockpickDifficulty()) < 0 then
		result = "fail"
	else
		local difficulty = tool.skillCheckPenalty
		difficulty = difficulty + DifficultyToNumber(self:GetlockpickDifficulty()) + self.additionalDifficulty
		
		if HasPerk(unit, "MrFixit") then
			difficulty = difficulty - CharacterEffectDefs.MrFixit:ResolveValue("mrfixit_bonus")
			CombatLog("debug", " After perk " .. difficulty)
		end
		
		result, difference = SkillCheck(unit, "Mechanical", difficulty)
	end
	
	local banterId = false
	local fx_result = "fail"
	if result == "success" then
		self:SetLockpickState("closed")
		fx_result = "success"
		banterId = "LockPickSuccess"
	elseif difference > 20 then
		self:SetLockpickState("blocked")
		self.is_broken = true
		fx_result = "break"
		banterId = "LockPickFailBlocked"
	else
		banterId = "LockPickFail"
	end
	PlayBanter(banterId, {unit})
	self:PlayLockpickableFX("Lockpick", fx_result)
	
	local conditionDamage = lBaseConditionLoss + lAddedRandomConditionLossMin + InteractionRand(lAddedRandomConditionLossMax, "Lockpick")
	unit:ItemModifyCondition(tool, -conditionDamage)
	CombatLog("debug", T{Untranslated("<DisplayName> condition decreased by <dmg>."), SubContext(tool, { dmg = conditionDamage })})

	return result
end

function Lockpickable:InteractBreak(unit)
	local tool = GetUnitCrowbar(unit)
	assert(tool and self:CanUseAction("Break"))
	local result = false
	local difference = 0
	
	CombatLog("debug", "Break Check")
	local difficulty = self.baseBreakDifficulty + DifficultyToNumber(self.breakDifficulty)
	if DifficultyToNumber(self:GetlockpickDifficulty()) < 0 or difficulty < 0 then
		result = "fail"
	else
		difficulty = difficulty + tool.skillCheckPenalty
		difficulty = difficulty + self.additionalDifficulty
		result, difference = SkillCheck(unit, "Strength", difficulty)
	end

	local banterId = false
	if result == "success" then
		self:SetLockpickState("closed")
		banterId = "LockBreakSuccess"
		Msg("LockpickableBrokeOpen", self)
	else
		banterId = "LockBreakFail"
	end
	PlayBanter(banterId, {unit})
	self:PlayLockpickableFX("BreakLock", result)
	
	local conditionDamage = lBaseConditionLoss + lAddedRandomConditionLossMin + InteractionRand(lAddedRandomConditionLossMax, "Lockpick")
	unit:ItemModifyCondition(tool, -conditionDamage)
	CombatLog("debug", T{Untranslated("<DisplayName> condition decreased by <dmg>."), SubContext(tool, { dmg = conditionDamage })})
	
	return result
end

function Lockpickable:InteractCut(unit)
	local tool = GetUnitWirecutter(unit)
	assert(tool and self:CanUseAction("Cut"))

	local anim = unit:GetActionRandomAnim("Open_Door")
	unit:SetState(anim)
	local time_to_hit = unit:TimeToMoment(1, "hit") or 0
	PlayFX("Interact", "start", unit, self)
	if time_to_hit > 0 then
		Sleep(time_to_hit)
	end
	
	-- todo: cut roll? failure state? banters?
	self:PlayLockpickableFX("Cut", "success")
	self:SetLockpickState("cut")
	
	local conditionDamage = lBaseConditionLoss + lAddedRandomConditionLossMin + InteractionRand(lAddedRandomConditionLossMax, "Lockpick")
	unit:ItemModifyCondition(tool, -conditionDamage)
	CombatLog("debug", T{Untranslated("<DisplayName> condition decreased by <dmg>."), SubContext(tool, { dmg = conditionDamage })})
end

function Lockpickable:CanUseAction(action_id)
	local state = self.lockpickState
	if action_id == "Cut" then
		return state == "cuttable"
	elseif action_id == "Break" then
		return state == "cuttable" or state == "locked" or state == "blocked" and DifficultyToNumber(self:GetlockpickDifficulty()) ~= -1
	elseif action_id == "Lockpick" then
		return state == "cuttable" or state == "locked" and DifficultyToNumber(self:GetlockpickDifficulty()) ~= -1
	end
end

DefineClass.CuttableFence = {
	flags = { efApplyToGrids = true, },
	__parents = {"Lockpickable", "CombatObject"},
	properties = {
		category = "Lockpickable",
		{ id = "lockpickState", name = "Lockpick State(Run-Time)", editor = "combo", default = "cuttable", items = {"cuttable", "cut"}, read_only = true, dont_save = true  },
		{ id = "lockpickStateMap", name = "Lockpick State(Map)", editor = "combo", default = "cuttable", items = {"cuttable", "cut"}, read_only = function(self) return self:IsBlockedDueToRoom() end },
		{ id = "decorative", name = "Decorative", editor = "bool", default = false, help = "whether the fence is purely decorative and uncuttable" },
	},
	width = 1,
	range_in_tiles = 1,
	highlight_collection = false
}

function CuttableFence:GameInit()
	self:SetEnumFlags(const.efSelectable)
end

function CuttableFence:LockpickStateChanged(state)
	if state ~= "cut" and state ~= "cuttable" then return end

	SuspendPassEdits("Fence")
	if state == "cut" then
		self:ClearEnumFlags(const.efApplyToGrids)
		self:ClearEnumFlags(const.efCollision)
	else
		self:SetEnumFlags(const.efApplyToGrids)
		
		-- If hidden by a show-hide collection marker we dont want to give collision to an invisible object
		-- but rather override the show-hide collection marker's restore property so that the fence gains
		-- collision once it is set visible. We dont need to handle that above as you cant cut invisible fences.
		if self:GetVisible() then
			self:SetEnumFlags(const.efCollision)
		else
			local root_collection = self:GetRootCollection()
			local collection_idx = root_collection and root_collection.Index or 0
			if collection_idx and collection_idx ~= 0 then
				local marker = MapGetFirst("map", "collection", collection_idx, "ShowHideCollectionMarker")
				if marker then -- confidently assume only one marker
					if not marker.restore_enumflags then marker.restore_enumflags = {} end
					marker.restore_enumflags[self] = const.efCollision
				end
			end
		end
	end
	ResumePassEdits("Fence")

	self:SetState(state == "cut" and "cut" or "idle")
end

function CuttableFence:GetInteractableBadgeSpot()
	return self:GetBSphere()
end

function CuttableFence:HighlightIntensely(visible, reason)
	if visible and reason ~= "cursor" then return end
	Interactable.HighlightIntensely(self, visible, reason)
end

function CuttableFence:GetInteractionCombatAction()
	if self.decorative then return false end

	local interactTiles = self:GetInteractionPos()
	if not interactTiles or #interactTiles ~= 2 then return false end
	return self:CanUseAction("Cut") and CombatActions.Cut
end

function CuttableFence:GetSide(angle)
	angle = angle or self:GetAngle()
	if angle >= 350 * 60 or (angle >= 0 and angle <= 10 * 60) then
		return "E"
	elseif angle >= 80*60 and angle <= 100 * 60 then
		return "S"
	elseif angle >= 170*60 and angle <= 190 * 60 then
		return "W"
	elseif angle >= 260 * 60 and angle <= 280 * 60 then
		return "N"
	end
	return "N" -- fallback for weird angles, probably shouldn't be supported, but doesn't look that bad.
end

local function lEvaluateCuttablePath(from, to)
--[[	DebugDrawVoxelBBox(from)
	DebugDrawVoxelBBox(to)]]

	-- Check if passable
	local slabFromX, slabFromY, slabFromZ = GetPassSlabXYZ(from)
	local slabToX, slabToY, slabToZ = GetPassSlabXYZ(to)
	if not slabFromX or not slabToX then
		return
	end

	-- Check if a drop/climb
	local x1, y1, z1 = FindFallDownPos(from)
	local x2, y2, z2 = FindFallDownPos(to)
	local fromZ = x1 and (z1 or terrain.GetHeight(x1, y1)) or terrain.GetHeight(from)
	local toZ = x2 and (z2 or terrain.GetHeight(x2, y2)) or terrain.GetHeight(to)
	local zDiff = abs(fromZ - toZ)
	if zDiff > const.SlabSizeZ / 2 then
--[[		DbgAddVector(slabFrom, zDiff, const.clrGreen)
		DbgAddVector(slabTo, zDiff, const.clrGreen)]]
		return
	end

	return { point(slabFromX, slabFromY, slabFromZ), point(slabToX, slabToY, slabToZ) }
end

function CuttableFence:GetInteractionPos()
	if not self.interact_positions then
		self.interact_positions = empty_table
		local side = self:GetSide()
		if not side then
			return
		end
		local center, width = self:GetBSphere()
		if self:IsValidZ() then
			if center:IsValidZ() and center:z() < terrain.GetHeight(center) then
				return
			end
			-- Check if pointing upward
			local p = RotateAxis(axis_z, self:GetAxis(), self:GetAngle())
			local dotUp = Dot(p, axis_z, 4096)
			if abs(dotUp - 4096) > 200 then
				return
			end
			center = center:SetZ(select(3, self:GetPosXYZ()))
		else
			center = center:SetInvalidZ()
		end

		local borderFuzzyCheck = 300 -- Fences are usually not snapped, so the check cant be exact
		local interactableTiles = {}
		if side == "N" or side == "S" then
			local onVoxelBorder = center:y() % const.SlabSizeY
			onVoxelBorder = onVoxelBorder == 0 or onVoxelBorder > const.SlabSizeY - borderFuzzyCheck or onVoxelBorder < borderFuzzyCheck
			
			local offsetAmount
			-- If the fence is placed on a voxel boundary (or near one) then interaction voxels are the two
			-- voxels it borders, otherwise they are the two neighbouring voxels.
			if onVoxelBorder then
				offsetAmount = const.SlabSizeY / 2
			else
				offsetAmount = const.SlabSizeY
			end
			local from = center:SetY(center:y() + offsetAmount)
			local to = center:SetY(center:y() - offsetAmount)
			local t = lEvaluateCuttablePath(from, to)
			if t then
				self.interact_positions = t
			end
		elseif side == "W" or side == "E" then
			local onVoxelBorder = center:x() % const.SlabSizeX
			onVoxelBorder = onVoxelBorder == 0 or onVoxelBorder > const.SlabSizeX - borderFuzzyCheck or onVoxelBorder < borderFuzzyCheck
			
			local offsetAmount
			if onVoxelBorder then
				offsetAmount = const.SlabSizeX / 2
			else
				offsetAmount = const.SlabSizeX
			end
			local from = center:SetX(center:x() + offsetAmount)
			local to = center:SetX(center:x() - offsetAmount)
			local t = lEvaluateCuttablePath(from, to)
			if t then
				self.interact_positions = t
			end
		end
	end
	if #self.interact_positions > 0 then
		return self.interact_positions
	end
end

function CuttableFence:CanUseAction(action_id)
	return action_id == "Cut" and self.lockpickState ~= "cut"
end

function ChooseClosestFence(target)
	local targetPos = target:GetVisualPos()
	local closest
	MapForEach(targetPos, const.SlabSizeX * 3, "Lockpickable", function(o)
		if o:GetInteractionCombatAction() and o:CanUseAction("Cut") then
			local center = o:GetBSphere()
			if GetZDifference(targetPos, o:GetVisualPos()) < const.SlabSizeZ and (not closest or IsCloser(targetPos, center, closest)) then
				closest = o
			end
		end
	end)
	return closest
end