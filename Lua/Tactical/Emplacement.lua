DefineClass.MachineGunEmplacement = {
	__parents = { "Interactable", "Object", "GameDynamicDataObject", "EditorObject", "VoxelSnappingObj", "StripComponentAttachProperties", },	
	properties = {
		{ category = "Emplacement", id = "weapon_template", name = "Weapon Template", editor = "preset_id", default = "BrowningM2HMG", 
			preset_class = "InventoryItemCompositeDef", preset_filter = function (preset, obj) return preset.object_class == "MachineGun" end, },
		{ category = "Emplacement", id = "ammo_template", name = "Ammo Template", editor = "preset_id", default = false, 
			preset_class = "InventoryItemCompositeDef", preset_filter = function (preset, obj)
				local wt = InventoryItemDefs[obj.weapon_template]
				return wt and preset.object_class == "Ammo" and preset.Caliber == wt.Caliber
			end, 
			no_edit = function(self) return not InventoryItemDefs[self.weapon_template] end },
		{ category = "Emplacement", id = "target_dist", name = "Target Distance", editor = "number", scale = "m", min = 3*guim, max = 20*guim, default = 10*guim, slider = true },
		
		{ category = "Usage", id = "appeal_per_target", name = "Appeal Per Target", editor = "number", default = 1000, help = "Base Appeal score per target in threatened area." },
		{ category = "Usage", id = "appeal_optimal_dist", name = "Appeal Optimal Distance", editor = "number", scale = "m", default = 15*guim, min = 0, help = "Distance at which targets in threatened area score their base Appeal Per Target points." },
		{ category = "Usage", id = "appeal_per_meter", name = "Appeal/m", editor = "number", scale = "%", default = -10, help = "Appeal modifier applied additively for each meter difference from Appeal Optimal Distance value." },
		{ category = "Usage", id = "appeal_decay", name = "Appeal Decay", editor = "number", scale = "%", default = 30, min = 0, help = "Appeal lost at the start of new turn before reevaluating potential targets.", },
		{ category = "Usage", id = "appeal_use_threshold", name = "Use Threshold", editor = "number", default = 150, help = "Appeal score above which the AI will seek to use this Emplacement." },		
		{ category = "Usage", id = "exploration_manned", name = "Manned in Exploration", editor = "bool", default = false },
		{ category = "Usage", id = "personnel_search_dist", name = "Personnel Search Distance", editor = "number", scale = "m", default = 10*guim, min = 0, no_edit = function(self) return not self.exploration_manned end, help = "Units closer than this distance can be assigned to this Emplacement." },
		{ category = "Usage", id = "start_combat_appeal", name = "Start Combat Appeal", editor = "number", default = 1000, no_edit = function(self) return not self.exploration_manned end, help = "Initial Appeal score in combat if the Emplacement is already manned." },
	},
	entity = "WayPoint",
	
	area_visual = false,
	interaction_visuals = false,
	manned_by = false,
	appeal = false, -- appeal score by team
	weapon = false,
	updating = false,
	exploration_personnel_chosen = false,
	exploration_update_thread = false,
}

function MachineGunEmplacement:GameInit()
	if IsEditorActive() then
		self:EditorEnter()
	else
		self:EditorExit()
	end
	self.exploration_update_thread = CreateGameTimeThread(function()
		while IsValid(self) do
			self:ExplorationUpdateTick()
			Sleep(1000)
		end
		self.exploration_update_thread = nil
	end)
end

function MachineGunEmplacement:Done()
	if self.area_visual then
		DoneObject(self.area_visual)
		self.area_visual = nil
	end
	
	if self.weapon then
		DoneObject(self.weapon)
		self.weapon = nil
	end
	for _, obj in ipairs(self.interaction_visuals) do
		DoneObject(obj)
	end
	self.interaction_visuals = nil
	if IsValidThread(self.exploration_update_thread) then
		DeleteThread(self.exploration_update_thread)
		self.exploration_update_thread = nil
	end
end

function MachineGunEmplacement:Destroy()
	if IsValid(self.manned_by) and not self.manned_by:IsDead() then
		self.manned_by:LeaveEmplacement(true)
	end
	return Object.Destroy(self)
end

function MachineGunEmplacement:SetPos(...)
	Interactable.SetPos(self, ...)
	self:Update()
end

function MachineGunEmplacement:SetAngle(...)
	Interactable.SetAngle(self, ...)
	self:Update()
end

function MachineGunEmplacement:SetProperty(name, value)
	PropertyObject.SetProperty(self, name, value)
	if name == "weapon_template" or name == "target_dist" and not self.updating then
		self:Update()
	end
end

function MachineGunEmplacement:OnPropertyChanged(prop_id)
	if prop_id == "weapon_template" or prop_id == "target_dist" and not self.updating then
		self:Update()		
	end
end

function MachineGunEmplacement:EditorEnter()
	self:ChangeEntity(self.entity)
	self:Update()
end

function MachineGunEmplacement:EditorExit()
	self:ChangeEntity("")
	self:Update()
end

function MachineGunEmplacement:SetCollision(value)
	CObject.SetCollision(self, value)
	local weapon_visual = self.weapon and self.weapon:GetVisualObj()
	if weapon_visual then
		weapon_visual:SetCollision(value)
	end
end

function MachineGunEmplacement:Update()
	local weapon = self.weapon
	local ammo = weapon and weapon.ammo
	local need_update

	self.updating = true

	if weapon then
		need_update = weapon.class ~= self.weapon_template 
		if ammo then 
			need_update = need_update or (ammo.class ~= self.class)
		else
			need_update = need_update or not not InventoryItemDefs[self.class]
		end
	else
		need_update = not not InventoryItemDefs[self.weapon_template]
	end
	if need_update then
		if weapon then
			DoneObject(weapon)
			self.weapon = nil
			weapon = nil
		end
		
		if InventoryItemDefs[self.weapon_template] then
			weapon = PlaceInventoryItem(self.weapon_template)
			self.weapon = weapon
			
			local ammo_template = self.ammo_template
			if not ammo_template then
				local ammo = GetAmmosWithCaliber(weapon.Caliber, "sort")[1]
				ammo_template = ammo and ammo.id
			end
			
			if InventoryItemDefs[ammo_template] then
				local ammo = PlaceInventoryItem(ammo_template)
				ammo.Amount = weapon.MagazineSize
				weapon:Reload(ammo, "suspend fx")
				DoneObject(ammo)
			end
		end
		
		if weapon then
			-- custom prop meta for target_dist
			local min_aim_range = weapon:GetOverwatchConeParam("MinRange") * const.SlabSizeX
			local max_aim_range = weapon:GetOverwatchConeParam("MaxRange") * const.SlabSizeX
			
			self.properties = table.copy(g_Classes[self.class].properties)
			local idx = table.find(self.properties, "id", "target_dist")
			if idx then
				self.properties[idx] = { category = "Emplacement", id = "target_dist", name = "Target Distance", editor = "number", scale = "m", min = min_aim_range, max = max_aim_range, default = min_aim_range, slider = max_aim_range > min_aim_range, read_only = min_aim_range == max_aim_range }
				self:SetProperty("target_dist", min_aim_range)
			end
		else
			-- default prop meta for target_dist
			self.properties = nil
			local meta = self:GetPropertyMetadata("target_dist")
			self:SetProperty("target_dist", meta.default)
		end
	end
	
	local pos = self:GetPos()
	local angle = self:GetAngle()
	
	local visual = weapon and weapon:GetVisualObj()
	if visual then
		self:Attach(visual)
		visual:SetCollision(self:GetCollision())
	end
	
	for _, obj in ipairs(self.interaction_visuals) do
		DoneObject(obj)
	end
	self.interaction_visuals = nil
	
	if weapon and IsEditorActive() then
		-- create overwatch area
		local cone_angle = weapon.OverwatchAngle
		local min_aim_range = weapon:GetOverwatchConeParam("MinRange") * const.SlabSizeX
		local max_aim_range = weapon:GetOverwatchConeParam("MaxRange") * const.SlabSizeX
		local distance = Clamp(self.target_dist, min_aim_range, max_aim_range)
		self.target_dist = distance
		local target = pos + Rotate(point(distance, 0, 0), angle)
		local step_positions, step_objs = GetStepPositionsInArea(pos, distance, 0, cone_angle, angle, "force2d")
		step_objs = empty_table
		self.area_visual = CreateAOETilesSector(step_positions, step_objs, empty_table, self.area_visual, pos, target, 1*guim, distance, cone_angle, "Overwatch_WeaponEditor")
		
		-- interaction pos
		self.interaction_visuals = {}
		local valid = self:GetValidInteractionPositions()
		for _, pos in ipairs(valid) do
			local obj = AppearanceObject:new()
			obj:SetPos(point_unpack(pos))
			obj:ApplyAppearance("Soldier_Local_01")
			obj:SetHierarchyGameFlags(const.gofWhiteColored)
			self.interaction_visuals[#self.interaction_visuals + 1] = obj
		end
		
		if self.area_visual then
			self.area_visual:SetColorModifier((not valid or #valid == 0) and RGB(255, 0, 0) or RGB(128, 128, 128))
		end
	else
		if self.area_visual then
			DoneObject(self.area_visual)
			self.area_visual = nil
		end
	end
	ObjModified(self)
	self.updating = false
end

function MachineGunEmplacement:GetEnemyUnitsInArea(attacker)
	local weapon = self.weapon
	local units = {}

	if not weapon or not self:IsValidPos() then
		return units
	end

	local pos = self:GetPos()
	local angle = self:GetAngle()
	local target = pos + Rotate(point(self.target_dist, 0, 0), angle)

	local aoe_params = {
		cone_angle = weapon.OverwatchAngle,
		min_range = weapon:GetOverwatchConeParam("MinRange"),
		max_range = weapon:GetOverwatchConeParam("MaxRange"),
		weapon = weapon,
		attacker = attacker,
		step_pos = pos,
		target_pos = target,
		used_ammo = 1,
		damage_mod = 100,
		attribute_bonus = 0,
		dont_destroy_covers = true,
		prediction = true,
	}
	local aoe = GetAreaAttackResults(aoe_params)
	for i, aoeHit in ipairs(aoe) do
		if IsKindOf(aoeHit.obj, "Unit") and attacker:IsOnEnemySide(aoeHit.obj) then
			table.insert_unique(units, aoeHit.obj)
		end
	end
	return units
end

function MachineGunEmplacement:GetDynamicData(data)
	if IsValid(self.manned_by) then
		data.manned_by = self.manned_by.handle
	end
	data.condition = self.weapon and self.weapon.Condition or nil
end

function MachineGunEmplacement:SetDynamicData(data)
	if data.manned_by then
		self.manned_by = HandleToObject[data.manned_by]
	end
	self:Update() -- create the weapon before restoring its condition
	if self.weapon and data.condition then
		self.weapon.Condition = data.condition
	end
end

function MachineGunEmplacement:GetTitle()
	return T(163835576952, "Machine Gun")
end

function MachineGunEmplacement:GetInteractionCombatAction(unit)
	if self.manned_by then return end
	return Presets.CombatAction.Interactions.Interact_ManEmplacement
end

function MachineGunEmplacement:GetOperatePos()
	local visual = self.weapon and self.weapon:GetVisualObj()
	local spot = visual and visual:GetSpotBeginIndex("Unit")
	local pos = visual and visual:GetSpotPos(spot)
	return pos
end

function MachineGunEmplacement:GetInteractionPos(unit)
	if not IsValid(self) then return false end
	local operate_pos = self:GetOperatePos()
	local passx, passy, passz = SnapToPassSlabXYZ(operate_pos or self)
	if unit:IsEqualPos(passx, passy, passz) then
		return point(passx, passy, passz)
	end
	local pos = unit:GetClosestMeleeRangePos(self, operate_pos, nil, "interaction")
	return pos
end

function MachineGunEmplacement:EndInteraction(unit)
	unit:EnterEmplacement(self, false)
	unit:RecalcUIActions(true)
	unit:UpdateOutfit()
	local dist = Min(self.target_dist, CombatActions.Overwatch:GetMaxAimRange(unit, self.weapon) * const.SlabSizeX)
	local target = RotateRadius(dist, self:GetAngle(), self)
	unit:QueueCommand("MGTarget", "MGSetup", 0, {target = target})
end

function MachineGunEmplacement:GetValidInteractionPositions()
	return GetMeleeRangePositions(nil, self, nil, true)
end

function MachineGunEmplacement:GetError()
	local errors = {}
	local ammo = InventoryItemDefs[self.ammo_template]
	local weapon = InventoryItemDefs[self.weapon_template]
	if not ammo or ammo.caliber ~= weapon.caliber then
		local default_ammo
		ForEachPreset("InventoryItemCompositeDef", function(obj)
			if obj.object_class == "Ammo" and obj.Caliber == weapon.Caliber then
				default_ammo = obj.id
				return "break"
			end
		end)
	
		if default_ammo then
			self.ammo_template = default_ammo
			errors[#errors+1] = "Missing or incorrect ammo set for MG Emplacement, replaced with " .. default_ammo
		else
			errors[#errors+1] = "Missing or incorrect ammo set for MG Emplacement, compatible ammo not found"
		end
	end	
	if #(self:GetValidInteractionPositions() or "") == 0 then
		errors[#errors+1] = "MG Emplacement has no valid interaction positions"
	end
	if next(errors) then
		return table.concat(errors, "\n")
	end
end

function OnMsg.UnitDied(unit)
	MapForEach("map", "MachineGunEmplacement", function(obj)
		if obj.manned_by == unit then
			obj.manned_by = false
		end
	end)
end

function OnMsg.DeploymentModeSet()
	-- On deployment unman all machine guns
	for i, u in ipairs(g_Units) do
		if u:HasStatusEffect("ManningEmplacement") then
			u:RemoveStatusEffect("ManningEmplacement")
		end
	end
end

function OnMsg.EnterSector()
	-- Clear manning emplacements leftover from other sectors or from deleted machine guns etc.
	for i, u in ipairs(g_Units) do
		if not u:HasStatusEffect("ManningEmplacement") then goto continue end
			
		local emplacementSector = u:GetEffectValue("hmg_sector")
		if emplacementSector and emplacementSector ~= gv_CurrentSectorId then
			u:RemoveStatusEffect("ManningEmplacement")
			goto continue
		end
			
		local emplacementHandle = u:GetEffectValue("hmg_emplacement")
		local emplacementObj = HandleToObject[emplacementHandle]
		if not emplacementObj then
			u:RemoveStatusEffect("ManningEmplacement")
			goto continue
		end
		
		::continue::
	end

	-- On enter sector check for emplacements that are no longer manned.
	MapForEach("map", "MachineGunEmplacement", function(obj)
		local manned = obj.manned_by
		if not IsValid(manned) or (manned and not manned:HasStatusEffect("ManningEmplacement")) then
			obj.manned_by = false
		end
	end)
end

function OnMsg.CombatStarting()
	MapForEach("map", "MachineGunEmplacement", function(obj)
		obj.appeal = {}
		if IsValid(obj.manned_by) and obj.manned_by.team and obj.manned_by.team.player_enemy then
			obj.appeal[obj.manned_by.team.side] = 1000
			g_Combat:AssignEmplacement(obj, obj.manned_by)
		end
	end) 
end

function MachineGunEmplacement:ExplorationUpdateTick()
	if IsValid(self.exploration_personnel_chosen) then
		if self.exploration_personnel_chosen.command == "InteractWith" then return end
		self.exploration_personnel_chosen = false
	end
	if not self.exploration_manned or IsValid(self.manned_by) then return end
	
	-- look for eligible (enemy) units in the given radius
	local gunner, mindist
	for _, unit in ipairs(g_Units) do
		if unit.team and unit.team.player_enemy then
			local dist = self:GetDist(unit)
			if dist <= self.personnel_search_dist and (not gunner or dist < mindist) then
				gunner, mindist = unit, dist
			end
		end
	end
	if gunner then
		-- tell the unit to interact with the emplacement and mark them somehow so we don't find another on the next tick
		local action = self:GetInteractionCombatAction(gunner)
		if action and gunner:CanInteractWith(self) then
			if AIStartCombatAction(action.id, gunner, 0, {target = self}) then
				self.exploration_personnel_chosen = gunner
			end
		end
	end
end