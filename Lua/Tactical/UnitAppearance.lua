MapVar("g_UnitCombatBadgesEnabled", true)

GroundOrientOffsets = {
	Human = {
		point(40,-40) * const.SlabSizeX / 100,
		point(40, 40) * const.SlabSizeX / 100,
		point(-100, 0) * const.SlabSizeX / 100,
	},
	Crocodile = {
		point(100,-40) * const.SlabSizeX / 100,
		point(100, 40) * const.SlabSizeX / 100,
		point(-100, 0) * const.SlabSizeX / 100,
	},
	OneTile = {
		point(40,-40) * const.SlabSizeX / 100,
		point(40, 40) * const.SlabSizeX / 100,
		point(-40, 0) * const.SlabSizeX / 100,
	},
}

AppearanceObjectAME.flags.gofUnitLighting = true

local AnimationStyleUnits = { "Male", "Female", "Crocodile", "Hyena", "Hen", "AmbientLifeMarker" }

WeaponVisualClasses = { "WeaponVisual", "GrenadeVisual" }

local GetAnimationStyleUnitEntities = {
	Male = "Male",
	Female = "Female",
	Crocodile = "Animal_Crocodile",
	Hyena = "Animal_Hyena",
	Hen = "Animal_Hen",
}

function GetAnimationStyleUnitEntity(set)
	return GetAnimationStyleUnitEntities[set]
end

function GetAnimationStyleUnits()
	return AnimationStyleUnits
end

function Unit:GetAnimationStyleUnit()
	return self.species == "Human" and self.gender or self.species
end

function Unit:ApplyAppearance(appearance, force)
	AppearanceObject.ApplyAppearance(self, appearance, force)
	self.gender = self:GetGender()
	if self.Headshot then
		self:SetHeadshot(true)
	end
	if self.target_dummy then
		self.target_dummy:ApplyAppearance(self.Appearance)
	end
end

local maxStainsAtDetailLevel = {
	["Very Low"] = 2,
	["Low"] = 2,
	["Medium"] = 3,
	["High"] = 5,
}

function Unit:UpdateGasMaskVisibility()
	if self:GetItemInSlot("Head", "GasMask") then
		AppearanceObject.EquipGasMask(self)
	else
		AppearanceObject.UnequipGasMask(self)
	end
end

function Unit:UpdateOutfit(appearance)
	appearance = appearance or self:ChooseAppearance()
	local appear_preset = appearance and AppearancePresets[appearance]
	if not appear_preset then
		appearance = self.spawner and self.spawner.Appearance or nil
	end
	
	self:StopAnimMomentHook()
	
	if appearance and appearance ~= self.Appearance then
		local anim = self:GetStateText()
		local phase = self:GetAnimPhase()
		self:ApplyAppearance(appearance)
		self:SetStateText(anim, const.eKeepComponentTargets)
		self:SetAnimPhase(1, phase)
	end

	self:FlushCombatCache()
	local weapons_set1 
	if IsSetpiecePlaying() and IsSetpieceActor(self) then
		weapons_set1 = self:GetEquippedWeapons("SetpieceWeapon")
	end
	if not weapons_set1 or #weapons_set1 == 0 then
		weapons_set1 = self:GetEquippedWeapons(self.current_weapon)
	end
	local weapons_set2 = self:GetEquippedWeapons(self.current_weapon == "Handheld A" and "Handheld B" or "Handheld A")
	local equipped_items
	if #weapons_set1 > 0 or #weapons_set2 > 0 then
		equipped_items = {
			weapons_set1[1] or false,
			weapons_set1[2] or false,
			weapons_set2[1] or false,
			weapons_set2[2] or false,
		}
	end
	self:ForEachAttach(WeaponVisualClasses, function(o, equipped_items)
		if o.weapon and not table.find(equipped_items, o.weapon) then
			DoneObject(o)
		end
	end, equipped_items)
	local item_scale = CheatEnabled("BigGuns") and 250 or 100
	for equip_index, item in ipairs(equipped_items) do
		local o = item and IsKindOfClasses(item, "Firearm", "MeleeWeapon", "HeavyWeapon") and item:GetVisualObj()
		if o then
			o.equip_index = equip_index
			o:SetScale(item_scale)
			if o ~= self.bombard_weapon then
				local parent = o:GetParent()
				if parent ~= self then
					self:Attach(o)
				end
			end
		end
	end
	self.anim_moment_fx_target = equipped_items and (equipped_items[1] and equipped_items[1].visual_obj or equipped_items[2] and equipped_items[2].visual_obj) or self:GetAttach("WeaponVisual")
	self:UpdateAttachedWeapons()

	self:UpdateGasMaskVisibility()
	Msg("OnUpdateItemsVisuals", self)

	self:SetHierarchyGameFlags(const.gofUnitLighting)
	self:StartAnimMomentHook()

	DeleteBadgesFromTargetOfPreset("CombatBadge", self)
	self.combat_badge = false
	self.ui_badge = false
	DeleteBadgesFromTargetOfPreset("NpcBadge", self)

	if not self:IsDead() and (GameState.entered_sector or IsCompetitiveGame() or g_TestExploration) and g_UnitCombatBadgesEnabled then
		local badge = CreateBadgeFromPreset("CombatBadge", self, self)
		self.combat_badge = badge
		self.ui_badge = badge.ui
		
		if self.ImportantNPC then
			CreateBadgeFromPreset("NpcBadge", { target = self, spot = self:GetInteractableBadgeSpot() or "Origin" }, self)
		end
	end

	self:UpdateModifiedAnim()
	self:UpdateMoveAnim()

	--local max_stains = maxStainsAtDetailLevel[EngineOptions.ObjectDetail] or 3	
	for i, stain in ipairs(self.stains) do
		--if i > max_stains then break end 
		stain:Apply(self)
	end
	if not IsRealTimeThread() and self:IsIdleCommand() and CurrentThread() ~= self.command_thread then
		--set command is a sync event and shouldn't be done in rtt
		--it happens during load session data due to cascade onsetwhatever calls
		if self.command ~= "Hang" and self.command ~= "Cower" then
			self:SetCommand("Idle")
		end
	end
end

function Unit:UpdatePreparedAttackAndOutfit()
	-- in case of using a prepared attack, check if it can still find its weapon, cancel otherwise
	self:FlushCombatCache() -- clear the cache so we don't get a weapon that is no longer equipped
	if self:HasPreparedAttack() then
		local params = g_Combat and self.combat_behavior_params or self.behavior_params or empty_table
		local action_id = params[1]
		local action = action_id and CombatActions[action_id]
		if not action or not action:GetAttackWeapons(self) then
			self:InterruptPreparedAttack()
			self:RemovePreparedAttackVisuals()
		end
	end
	
	self:UpdateOutfit()
end

function Unit:GetGender()
	local appearance = AppearancePresets[self.Appearance]
	if appearance and self.species == "Human" then
		if appearance.Body then
			if IsKindOf(g_Classes[appearance.Body], "CharacterBodyMale") then
				return "Male"
			end
		else
			if self:GetEntity() == "Male" then
				return "Male"
			end
		end
		return "Female"
	end
	return "N/A"
end

function Unit:SetState(anim, flags, crossfade, ...)
	AnimChangeHook.SetState(self, anim, flags or 0, not GameState.loading and crossfade or 0, ...)
end

function Unit:SetAnim(channel, anim, flags, crossfade, ...)
	AnimChangeHook.SetAnim(self, channel, anim, flags or 0, not GameState.loading and crossfade or 0, ...)
end

function Unit:RotateAnim(angle, anim)
	self:SetState(anim, const.eKeepComponentTargets, Presets.ConstDef.Animation.BlendTimeRotateOnSpot.value)
	self:SetIK("AimIK", false)
	local duration = self:TimeToAnimEnd()
	local start_angle = self:GetVisualOrientationAngle()
	local delta = AngleDiff(angle, start_angle)
	local step_angle = self:GetStepAngle()
	if delta * step_angle < 0 then
		if delta > 0 then
			delta = delta - 360 * 60
		else
			delta = delta + 360 * 60
		end
	end
	local steps = self.ground_orient and 20 or 2
	for i = 1, steps do
		local a = start_angle + i * delta / steps
		local t = duration * i / steps - duration * (i - 1) / steps
		self:SetOrientationAngle(a, t)
		Sleep(t)
	end
	if step_angle == 0 then
		local anim = self:ModifyWeaponAnim(self:GetIdleBaseAnim())
		self:SetState(anim, const.eKeepComponentTargets, -1)
		self:SetOrientationAngle(angle)
	end
end

function Unit:Rotate180(angle, anim)
	anim = self:ModifyWeaponAnim(anim)
	self:SetState(anim, const.eKeepComponentTargets, Presets.ConstDef.Animation.BlendTimeRotateOnSpot.value)
	self:SetIK("AimIK", false)
	local duration = self:TimeToAnimEnd()
	local start_angle = self:GetVisualOrientationAngle()
	local delta = AngleDiff(angle, start_angle)
	local step_angle = self:GetStepAngle()
	if delta * step_angle < 0 then
		if delta > 0 then
			delta = delta - 360 * 60
		else
			delta = delta + 360 * 60
		end
	end
	local steps = self.ground_orient and 20 or 2
	for i = 1, steps do
		local a = start_angle + i * delta / steps
		local t = duration * i / steps - duration * (i - 1) / steps
		self:SetOrientationAngle(a, t)
		Sleep(t)
	end
end

function Unit:AnimBlendingRotation(angle)
	local start_angle = self:GetVisualOrientationAngle()
	local angle_diff = AngleDiff(angle, start_angle)
	local abs_angle_diff = abs(angle_diff)
	if angle_diff == 0 then
		if self:TimeToAngleInterpolationEnd() > 0 then
			self:SetOrientationAngle(start_angle)
		end
	elseif abs_angle_diff < 15*60 then
		self:SetOrientationAngle(angle, 300)
		Sleep(300)
	else
		if abs_angle_diff > 150*60 then
			local anim = "turn_180"
			if IsValidAnim(self, anim) then
				self:Rotate180(angle, anim)
				return
			end
		end
		self:SetIK("AimIK", false)
		local anim1 = angle_diff < 0 and "turn_L_45" or "turn_R_45"
		local anim2 = angle_diff < 0 and "turn_L_135" or "turn_R_135"
		local destructor
		if abs_angle_diff <= 45*60 then
			self:SetAnim(1, anim1, const.eKeepComponentTargets, Presets.ConstDef.Animation.BlendTimeRotateOnSpot.value)
		elseif abs_angle_diff >= 135*60 then
			self:SetAnim(1, anim2, const.eKeepComponentTargets, Presets.ConstDef.Animation.BlendTimeRotateOnSpot.value)
		else
			destructor = true
			self:PushDestructor(function(self)
				self:ClearAnim(const.PathTurnAnimChnl)
			end)
			local weight2 = Clamp(abs_angle_diff - 45*60, 0, 90*60) * 100 / (90*60) -- 45 degrees -> 0, 135 degrees -> 100
			self:SetAnim(1, anim1, const.eKeepComponentTargets, -1, 1000, 100 - weight2)
			self:SetAnim(const.PathTurnAnimChnl, anim2, const.eKeepComponentTargets, -1, 1000, weight2)
		end
		local duration = self:TimeToMoment(1, "end") or self:TimeToAnimEnd()
		local steps = self.ground_orient and 20 or 2
		for i = 1, steps do
			local a = start_angle + i * angle_diff / steps
			local t = duration * i / steps - duration * (i - 1) / steps
			self:SetOrientationAngle(a, t)
			Sleep(t)
		end
		if destructor then
			self:PopAndCallDestructor()
		end
	end
end

function Unit:GetRotateAnim(angle_diff, base_idle)
	local prefix
	if not base_idle then
		base_idle = self:GetIdleBaseAnim(self.stance)
	end
	if string.ends_with(base_idle, "_Aim") then
		prefix = base_idle
	else
		prefix = string.match(base_idle, "(.*)_%a+$")
	end
	if not prefix then
		return
	end
	local take_cover_prefix = string.match(prefix, "(.*_)TakeCover")
	if take_cover_prefix then
		prefix = take_cover_prefix .. "Crouch"
	end
	local rotate_anim
	if abs(angle_diff) >= 150*60 then
		local anim = prefix .. "_Turn180"
		if IsValidAnim(self, anim) then
			rotate_anim = anim
		end
	end
	if not rotate_anim then
		local anim = prefix .. (angle_diff < 0 and "_TurnLeft" or "_TurnRight")
		if IsValidAnim(self, anim) then
			rotate_anim = anim
		end
	end
	if not rotate_anim then
		if string.ends_with(prefix, "_Aim") then
			local anim = string.sub(prefix, 1, -5) .. (angle_diff < 0 and "_TurnLeft" or "_TurnRight")
			if IsValidAnim(self, anim) then
				rotate_anim = anim
			end
		end
	end
	if rotate_anim then
		local anim_rotation_angle = self:GetStepAngle(rotate_anim)
		if anim_rotation_angle == 0 then
			StoreErrorSource(self, string.format("%s animation %s should have compansated rotation", self:GetEntity(), rotate_anim))
		end
	end
	return rotate_anim
end

function Unit:IdleRotation(angle, time)
	if GameState.loading then
		time = 0
	else
		time = time or 300
	end
	if time > 0 then
		local start_angle = self:GetVisualOrientationAngle()
		local angle_diff = AngleDiff(angle, start_angle)
		local steps = self.ground_orient and 20 or 2
		for i = 1, steps do
			local a = start_angle + i * angle_diff / steps
			local t = time * i / steps - time * (i - 1) / steps
			self:SetOrientationAngle(a, t)
			Sleep(t)
		end
	else
		self:SetOrientationAngle(angle)
	end
end

function Unit:AnimatedRotation(angle, base_idle)
	if GameState.loading then
		self:SetOrientationAngle(angle)
		return
	end
	local start_angle = self:GetVisualOrientationAngle()
	if angle == start_angle then
		return
	end
	local angle_diff = AngleDiff(angle, start_angle)
	if abs(angle_diff) < 45*60 then
		self:SetOrientationAngle(angle, 300)
		return
	end
	local move_style = GetAnimationStyle(self, self.cur_move_style)
	if move_style then
		local rotate_anim
		if abs(angle_diff) >= 30*60 then
			if angle_diff < 0 then
				rotate_anim = move_style.TurnOnSpot_Left
			else
				rotate_anim = move_style.TurnOnSpot_Right
			end
		end
		if rotate_anim and IsValidAnim(self, rotate_anim) then
			self:RotateAnim(angle, rotate_anim)
		else
			self:SetOrientationAngle(angle, 300)
		end
		return
	end
	if self.species ~= "Human" then
		self:AnimBlendingRotation(angle)
		return
	end
	if not base_idle then
		base_idle = self:GetIdleBaseAnim(self.stance)
	end
	local rotate_anim = self:GetRotateAnim(angle_diff, base_idle)
	if not rotate_anim then
		self:SetRandomAnim(base_idle, const.eKeepComponentTargets)
		self:IdleRotation(angle)
	elseif string.ends_with(rotate_anim, "180") then
		self:Rotate180(angle, rotate_anim)
	else
		self:RotateAnim(angle, rotate_anim)
	end
end

function Unit:PlayTransitionAnims(target_anim, angle)
	self:ReturnToCover()
	local cur_anim = self:GetStateText()
	if IsAnimVariant(cur_anim, target_anim) then
		return
	end
	if self.bombard_weapon then
		self:PreparedBombardEnd()
	end
	local cur_anim_style = GetAnimationStyle(self, self.cur_idle_style)
	if cur_anim_style and (cur_anim_style.End or "") ~= "" and not cur_anim_style:HasAnimation(target_anim) and cur_anim_style.Start ~= target_anim then
		self:SetState(cur_anim_style.End)
		Sleep(self:TimeToAnimEnd())
	end
	PlayTransitionAnims(self, target_anim, angle)
end

local WeaponAttachSpots = {
	Hand = { "Weaponr", "Weaponl" },
	Shoulder = { "Weaponrb", "Weaponlb" },
	Leg = { "Weaponrs", "Weaponls" },
	Mortar = { "Mortar", "Mortar" },
	LegKnife = { "Weaponrknife", "Weaponlknife" },
	ShoulderKnife = { "Weaponrbknife", "Weaponlbknife" },
}

BlockedSpotsVariants = {
	["Weaponrknife"] = "Weaponrs",
	["Weaponlknife"] = "Weaponls",
}

local HolsterAttachSpots = {
	Weaponrb = true,
	Weaponlb = true,
	Weaponrs = true,
	Weaponls = true,
	Weaponrknife = true,
	Weaponlknife = true,
	Weaponrbknife = true,
	Weaponlbknife = true,
}

local mkoffset = point(0,0,30*guic)
local WeaponAttachOffset =
{	-- spot - animation - offset
	Weaponr = {
		["mk_Standing_Aim_Forward"] = mkoffset,
		["mk_Standing_Aim_Down"] = mkoffset,
		["mk_Left_Aim_Start"] = mkoffset,
		["mk_Right_Aim_Start"] = mkoffset,
		["mk_Standing_Fire"] = mkoffset,
	},
}

local MortarDrawnAnims = {
	nw_Standing_MortarIdle = true,
	nw_Standing_MortarEnd = true,
	nw_Standing_MortarLoad = true,
	nw_Standing_MortarFire = true,
}

local function GetItemAttachSpot(unit, item, equip_index, holster, avatar)
	local slot
	if holster == nil then
		if equip_index ~= 1 and equip_index ~= 2 then
			holster = true
		else
			local anim = unit:GetStateText()
			if item.WeaponType == "Mortar" then
				if MortarDrawnAnims[anim] then
					return -- the mortar command will handle it
				end
				holster = true
			elseif (avatar or unit):HasStatusEffect("ManningEmplacement") then
				holster = true
			else
				local starts_with = string.starts_with
				if starts_with(anim, "nw_") then
					holster = true
				elseif starts_with(anim, "gr_") then
					holster = true
				elseif starts_with(anim, "civ_") then
					holster = true
				elseif starts_with(anim, "mk_") then
					if item.WeaponType ~= "MeleeWeapon" then
						holster = true
					end
				end
			end
		end
	end
	if holster then
		slot = item.HolsterSlot
		if not WeaponAttachSpots[slot] then
			slot = item.HandSlot == "OneHanded" and "Leg" or "Shoulder"
		end
		for i, component in pairs(item.components) do
			local visuals = (WeaponComponents[component] or empty_table).Visuals or empty_table
			local idx = table.find(visuals, "ApplyTo", item.class)
			if idx then
				local component_data = visuals[idx]
				local override_holster_slot = component_data.OverrideHolsterSlot
				if override_holster_slot == "Sholder" then
					slot = "Shoulder"
					break
				elseif override_holster_slot == "Leg" then
					slot = "Leg"
				end
			end
		end
	else
		slot = "Hand"
	end
	if slot == "Leg" then
		if IsKindOf(item, "MeleeWeapon") then
			slot = "LegKnife"
		end
	elseif slot == "Shoulder" then
		if IsKindOf(item, "MeleeWeapon") then
			slot = "ShoulderKnife"
		end
	end
	local spot = WeaponAttachSpots[slot][(equip_index == 2 or equip_index == 4) and 2 or 1]
	return spot
end

local function GetItemSpotAttachment(unit, spot, attach)
	local item = attach.weapon
	local attach_axis, attach_angle, attach_offset, attach_state
	if HolsterAttachSpots[spot] then
		if attach:HasSpot("Holster") then
			local offset = GetWeaponRelativeSpotPos(attach, "Holster")
			if offset then
				attach_offset = -offset
			end
			if IsKindOf(item, "RPG7") then
				attach_axis = axis_z
				attach_angle = 180*60
				attach_offset = RotateAxis(attach_offset, attach_axis, attach_angle)
			end
		end
	else
		local spot_offset_by_anim = WeaponAttachOffset[spot]
		local anim = unit:GetStateText()
		if spot_offset_by_anim then
			attach_offset = spot_offset_by_anim[anim]
		end
		if spot == "Weaponr" and IsKindOf(item, "MeleeWeapon") then
			if unit.gender == "Female" then
				if IsKindOf(item, "MacheteWeapon") then
					attach_axis = axis_x
					attach_angle = 180*60
				elseif anim == "mk_Standing_Aim_Forward"  then
					attach_axis = axis_x
					attach_angle = 90*60
					attach_offset = point(0*guic,-30*guic,0*guic)
				end
			end
		end
	end
	if attach_offset then
		attach_offset = MulDivRound(attach_offset, attach:GetScale(), 100)
	end
	if item and item.WeaponType == "Mortar" then
		attach_state = "packed"
	end
	return attach_axis or axis_x, attach_angle or 0, attach_offset, attach_state
end

local function AttachVisualItem(unit, spot, attach)
	local attach_axis, attach_angle, attach_offset, attach_state = GetItemSpotAttachment(unit, spot, attach)
	unit:Attach(attach, unit:GetSpotBeginIndex(spot))
	attach:SetAttachAxis(attach_axis or axis_x)
	attach:SetAttachAngle(attach_angle or 0)
	attach:SetAttachOffset(attach_offset or point30)
	if attach_state and attach:GetStateText() ~= attach_state then
		attach:SetState(attach_state)
	end
end

function GetAttackRelativePos(unit, anim, anim_phase, visual_weapon, weapon_attach_spot, attack_spot)
	anim_phase = anim_phase or unit:GetAnimMoment(anim, "hit") or 0
	local offset
	if visual_weapon then
		if not weapon_attach_spot then
			weapon_attach_spot = GetItemAttachSpot(unit, visual_weapon.weapon, visual_weapon.equip_index, false) or "Weaponr"
		end
		local spot_pos, spot_angle, spot_axis = unit:GetRelativeAttachSpotLoc(anim, anim_phase, unit, unit:GetSpotBeginIndex(weapon_attach_spot))
		local attach_axis, attach_angle, attach_offset = GetItemSpotAttachment(unit, weapon_attach_spot, visual_weapon)
		local weapon_axis, weapon_angle = ComposeRotation(attach_axis, attach_angle, spot_axis, spot_angle)
		local weapon_spot_offset = GetWeaponRelativeSpotPos(visual_weapon, attack_spot or "Muzzle")
		offset = spot_pos + (attach_offset or point30) + (weapon_spot_offset and RotateAxis(weapon_spot_offset, weapon_axis, weapon_angle) or point30)
	else
		if not attack_spot then
			attack_spot = unit.species == "Human" and "Weaponr" or "Head"
		end
		offset = unit:GetRelativeAttachSpotLoc(anim, anim_phase, unit, unit:GetSpotBeginIndex(attack_spot))
	end
	return offset
end

function GetAttackPos(unit, pos, axis, angle, aim_pos, anim, anim_phase, visual_weapon, weapon_attach_spot, attack_spot)
	local offset = GetAttackRelativePos(unit, anim, anim_phase, visual_weapon, weapon_attach_spot, attack_spot)
	if not pos:IsValidZ() then
		pos = pos:SetTerrainZ()
	end
	local spot_pos = pos + RotateAxis(offset, axis, angle)
	if aim_pos and aim_pos:IsValid() then
		local center = pos + RotateAxis(offset:SetX(0), axis, angle)
		spot_pos = center + SetLen(aim_pos - center, spot_pos:Dist(center))
	end
	return spot_pos
end

function OnMsg.CombatActionEnd(unit)
	unit.action_visual_weapon = false
end

function Unit:AttachActionWeapon(action)
	local visual_weapon
	if action and (action.id == "KnifeThrow" or string.starts_with(action.id, "ThrowGrenade")) then
		local attack_weapon = action:GetAttackWeapons(self)
		if attack_weapon then
			if attack_weapon.visual_obj and attack_weapon.visual_obj == self then
				visual_weapon = attack_weapon.visual_obj
			else
				for i, classname in ipairs(WeaponVisualClasses) do
					visual_weapon = self:GetAttach(classname, function(o, attack_weapon)
						return o.weapon == attack_weapon
					end, attack_weapon)
					if visual_weapon then
						break
					end
				end
				if not visual_weapon then
					if IsKindOf(attack_weapon, "Grenade") then
						visual_weapon = attack_weapon:GetVisualObj(self)
					elseif IsKindOfClasses(attack_weapon, "FirearmBase", "MeleeWeapon") or IsKindOf(attack_weapon, "UnarmedWeapon") then
						visual_weapon = attack_weapon:CreateVisualObj(self)
					end
				end
			end
		end
	end
	if visual_weapon then
		self.action_visual_weapon = visual_weapon
		visual_weapon.custom_equip = true
		if visual_weapon:GetParent() ~= self then
			visual_weapon:ClearHierarchyEnumFlags(const.efVisible)
			self:Attach(visual_weapon)
			self:UpdateAttachedWeapons()
		end
	elseif self.action_visual_weapon then
		self.action_visual_weapon = false
		self:UpdateAttachedWeapons()
	end
end

function AttachVisualItems(obj, attaches, crossfading, holster, avatar)
	if not attaches or #attaches == 0 then
		return
	end
	local hidden
	if IsKindOf(obj, "Unit") then
		local part_in_combat = g_Combat and obj.team and obj.team.side ~= "neutral"
		if not part_in_combat then
			if obj:GetCommandParam("weapon_anim_prefix") == "civ_" or obj:GetCommandParam("weapon_anim_prefix", "Idle") == "civ_" then
				hidden = true
			end
		end
		if obj.carry_flare then
			hidden = not obj.visible
		end
		-- make sure we're not hiding weapons setup by a setpiece
		for _, attach in ipairs(attaches) do
			if IsKindOfClasses(attach, WeaponVisualClasses) and attach.weapon and obj:GetItemSlot(attach.weapon) == "SetpieceWeapon" then
				hidden = false
				break
			end
		end
	end
	if hidden then
		for _, attach in ipairs(attaches) do
			attach:ClearHierarchyEnumFlags(const.efVisible)
		end
		return
	end
	local custom_equip = obj.action_visual_weapon
	if custom_equip or (IsKindOf(obj, "Unit") and obj.carry_flare) then
		holster = true
	end
	for i = #attaches, 1, -1 do
		local attach = attaches[i]
		if IsKindOfClasses(attach, WeaponVisualClasses) and attach.custom_equip and attach ~= custom_equip and (attach.equip_index or 5) > 4 then
			DoneObject(attach)
			table.remove(attaches, i)
		end
	end
	local wait_crossfade, grip_modify
	local spot_attach = {}
	table.sort(attaches, function(o1, o2) return o1.equip_index < o2.equip_index end)
	for _, attach in ipairs(attaches) do
		local item = attach.weapon
		local spot
		local cur_spot = attach:GetAttachSpotName()
		if attach == custom_equip then
			spot = WeaponAttachSpots["Hand"][1] or cur_spot
		elseif item then
			spot = GetItemAttachSpot(obj, item, attach.equip_index, holster, avatar) or cur_spot
		end
		if spot then
			if spot ~= cur_spot then
				if crossfading and not HolsterAttachSpots[spot] then
					wait_crossfade = true
				else
					AttachVisualItem(obj, spot, attach)
				end
			end
			spot_attach[spot] = attach -- prefer displaying the other set weapon attaches
			if item and item.class == "Gewehr98" and spot == "Weaponr" then
			--	grip_modify = true
			end
		end
	end
	local channel = const.AnimChannel_RightHandGrip
	if grip_modify then
		if GetStateName(obj:GetAnim(channel)) ~= "ar_RHand_AltGrip_Rifles" then
			obj:SetAnimMask(channel, "RightHand")
			obj:SetAnim(channel, "ar_RHand_AltGrip_Rifles")
			obj:SetAnimWeight(channel, 1000)
		end
	else
		obj:ClearAnim(channel)
	end

	-- update visibility
	local blocked_spots = (avatar or obj).blocked_spots
	local flare = IsKindOf(obj, "Unit") and obj.carry_flare and obj.visible
	for _, attach in ipairs(attaches) do
		local spot = attach:GetAttachSpotName()
		local is_blocked = blocked_spots and (blocked_spots[spot] or blocked_spots[BlockedSpotsVariants[spot]])
		if is_blocked or spot_attach[spot] ~= attach then
			if flare and IsKindOf(attach, "GrenadeVisual") and attach.fx_actor_class == "FlareStick" then
				attach:SetHierarchyEnumFlags(const.efVisible)
			else
				attach:ClearHierarchyEnumFlags(const.efVisible)
			end
		else
			attach:SetHierarchyEnumFlags(const.efVisible)
			attach:SetContourOuterOccludeRecursive(true)
		end
		local parts = attach.parts
		if parts then
			if parts.Bipod and parts.Bipod:HasState("folded") then
				local bipod_state = IsKindOf(obj, "Unit") and obj.stance == "Prone" and "idle" or "folded"
				if parts.Bipod:GetStateText() ~= bipod_state then
					parts.Bipod:SetState(bipod_state)
				end
			end
			if parts.Under and parts.Under:HasState("folded") then
				local bipod_state = IsKindOf(obj, "Unit") and obj.stance == "Prone" and "idle" or "folded"
				if parts.Under:GetStateText() ~= bipod_state then
					parts.Under:SetState(bipod_state)
				end
			end
			if parts.Barrel and parts.Barrel:HasState("folded") then
				local bipod_state = IsKindOf(obj, "Unit") and obj.stance == "Prone" and "idle" or "folded"
				if parts.Barrel:GetStateText() ~= bipod_state then
					parts.Barrel:SetState(bipod_state)
				end
			end
		end
	end
	return wait_crossfade
end

function Unit:UpdateAttachedWeapons(crossfade)
	DeleteThread(self.update_attached_weapons_thread)
	self.update_attached_weapons_thread = false
	local attaches = self:GetAttaches(WeaponVisualClasses)
	if not attaches then return end
	local wait_crossfade = AttachVisualItems(self, attaches, (crossfade ~= 0) and not IsPaused())
	if wait_crossfade then
		self.update_attached_weapons_thread = CreateGameTimeThread(function(self, delay)
			Sleep(delay)
			self.update_attached_weapons_thread = false
			if IsValid(self) then
				local attaches = self:GetAttaches(WeaponVisualClasses)
				AttachVisualItems(self, attaches)
			end
		end, self, crossfade and crossfade > 0 and crossfade or hr.ObjAnimDefaultCrossfadeTime)
		return
	end
	--[[
	-- vertical grip support was canceled
	local vertical_grip, grip_spot
	local weapon1 = attached_weapons and attached_weapons[1]
	if not holster_weapon and weapon1 and weapon1.weapon and #attached_weapons == 1 then
		grip_spot = weapon1.weapon:GetLHandGripSpot()
	end
	if grip_spot then
		local grip_obj = GetWeaponSpotObject(weapon1, grip_spot)
		local grip_spot_idx = grip_obj:GetSpotBeginIndex(grip_spot)
		local grip_spot_annotation = grip_obj:GetSpotAnnotation(grip_spot_idx)
		if grip_spot_annotation == "Vert" then
			vertical_grip = true
		end
	end
	local channel = const.AnimChannel_VerticalGrip
	if vertical_grip then
		self:SetAnimMask(1, "LeftHand", "inverse")
		self:SetAnimMask(channel, "LeftHand")
		self:SetAnim(channel, "ar_Standing_Idle_Grip")
		--self:SetAnimWeight(channel, 100)
		--self:SetAnimBlendComponents(channel, true, true, false)      -- channel, translation, orientation, scale
	else
		self:ClearAnim(channel)
		self:SetAnimMask(1, false)
	end]]
end

function Unit:AnimationChanged(channel, old_anim, flags, crossfade)
	if channel == 1 then
		self:UpdateAttachedWeapons(crossfade)
		self:UpdateWeaponGrip()
	end
	AnimMomentHook.AnimationChanged(self, channel, old_anim, flags, crossfade)
end

function Unit:GetWeaponAnimPrefix()
	if self.species ~= "Human" then
		return ""
	end
	if self.die_anim_prefix then
		return self.die_anim_prefix
	end
	local prefix = self:GetCommandParam("weapon_anim_prefix") or self:GetCommandParam("weapon_anim_prefix", "Idle")
	if prefix then 
		return prefix
	end
	if self.action_visual_weapon then 
		prefix = GetWeaponAnimPrefix(self.action_visual_weapon.weapon)
		return prefix
	end
	if self.infected then
		return "inf_"
	end
	local weapon, weapon2 = self:GetActiveWeapons()
	if not weapon and (not self.team or self.team.side == "neutral") then
		return "civ_"
	end
	return GetWeaponAnimPrefix(weapon, weapon2)
end

function Unit:GetWeaponAnimPrefixFallback()
	return ""
end

local human_one_slab_anims = { "DeathOnSpot", "DeathFall", "DeathWindow" }

function Unit:GetGroundOrientOffsets(anim)
	local offsets = GroundOrientOffsets[self.species]
	if anim and self.species == "Human" then
		for _, pattern in ipairs(human_one_slab_anims) do
			if string.match(anim, pattern) then
				offsets = GroundOrientOffsets["OneTile"]
			end
		end
	end
	return offsets or GroundOrientOffsets["OneTile"]
end

function Unit:UpdateGroundOrientParams()
	local offsets = self:GetGroundOrientOffsets(self:GetStateText())
	pf.SetGroundOrientOffsets(self, table.unpack(offsets))
end

-- return: footplant, ground_orient
function Unit:GetFootPlantPosProps(stance)
	if self.species == "Human" then
		if self:HasStatusEffect("ManningEmplacement") then
			return false, false
		end
		if (stance or self.stance) == "Prone" or self:IsDead() then
			return false, true
		end
		return true, false
	elseif self.species == "Crocodile" then
		return false, true
	elseif self.species == "Hyena" then
		return true, false
	end
	return false, false
end

function Unit:SetFootPlant(set, time, stance)
	local footplant, ground_orient
	if set and not config.IKDisabled then
		footplant, ground_orient = self:GetFootPlantPosProps(stance)
	end
	local label = "FootPlantIK"
	local ikCmp = self:GetAnimComponentIndexFromLabel(1, label)
	if ikCmp ~= 0 then
		if footplant then
			self:SetAnimComponentTarget(1, ikCmp, "IKFootPlant", 10*guic, 10*guic)
		else
			self:RemoveAnimComponentTarget(1, ikCmp)
		end
	end
	if ground_orient then
		if not self.ground_orient then
			self.ground_orient = true
			self:ChangePathFlags(const.pfmGroundOrient)
			self:SetGroundOrientation(self:GetOrientationAngle(), time or 300)
		end
	else
		if self.ground_orient then
			self.ground_orient = false
			self:ChangePathFlags(0, const.pfmGroundOrient)
			self:SetAxisAngle(axis_z, self:GetVisualOrientationAngle(), time or 300)
		else
			self:ChangePathFlags(0, const.pfmGroundOrient)
			self:SetAxis(axis_z)
		end
	end
end

MapVar("g_IKDebug", false)

MapVar("g_IKDebugThread", CreateRealTimeThread(function()
	while true do
		if g_IKDebug then
			DbgClearVectors()
			DbgClearTexts()
			for unit, target in pairs(g_IKDebug) do
				--DbgAddVector(target, point(0, 0, guim), const.clrWhite)
				DbgAddText("Target", target, const.clrWhite)
				local weapon = unit:GetActiveWeapons("Firearm")
				local spot_obj = weapon and GetWeaponSpotObject(weapon:GetVisualObj(), "Muzzle")
				local wpos = spot_obj and spot_obj:GetSpotVisualPos(spot_obj:GetSpotBeginIndex("Muzzle"))
				if wpos then
					DbgAddVector(wpos, target - wpos, const.clrWhite)
				end
				--local upos = unit:GetSpotLoc(unit:GetSpotBeginIndex("Weaponr"))
				local upos = weapon and GetWeaponSpotPos(weapon:GetVisualObj(), "Muzzle")
				if upos then
					DbgAddVector(upos, target - upos, const.clrGreen)
				end
			end
		end
		Sleep(100)
	end
end))

function Unit:GetIK(label)
	local ikCmp = self:GetAnimComponentIndexFromLabel(1, label)
	if ikCmp == 0 then
		return
	end
	local direction = self:GetAnimComponentTargetDirection(1, ikCmp)
	return direction
end

function Unit:UpdateWeaponGrip(anim)
	if not IsEditorActive() then
		anim = anim or self:GetStateText()
		if string.starts_with(anim, "ar_") or string.starts_with(anim, "arg_") then
			self:SetWeaponGrip(true)
			return
		end
	end
	self:SetWeaponGrip(false)
end

function Unit:SetWeaponGrip(set)
	local ikCmp = self:GetAnimComponentIndexFromLabel(1, "LHandWeaponGrip")
	if ikCmp == 0 then
		return
	end
	if set then
		if config.Force_Selection_WeaponGripIK and self == SelectedObj then
			-- keep it
		elseif config.IKDisabled or config.WeaponGripIKDisabled then
			set = false
		end
	end
	if set then
		local weapon, weapon2 = self:GetActiveWeapons()
		local weapon_obj = not weapon2 and weapon and weapon:GetVisualObj(self)
		if weapon_obj and weapon_obj:GetAttachSpotName() == "Weaponr" then
			local weapon = weapon_obj.weapon
			local spot = weapon and weapon:GetLHandGripSpot()
			if spot then
				local offset = GetWeaponRelativeSpotPos(weapon_obj, spot)
				if offset then
					local spot = weapon_obj:GetAttachSpot()
					self:SetAnimComponentTarget(1, ikCmp, "IKWeaponGrip", spot, offset)
					return
				end
			end
		end
	end
	self:RemoveAnimComponentTarget(1, ikCmp, true)
end

function Unit:CalcIKIntermediateTarget(ikCmp, target)
	local direction = self:GetAnimComponentTargetDirection(1, ikCmp)
	if direction then
		local face_angle = self:GetOrientationAngle()
		local target_angle = (IsValid(target) and self:AngleToObject(target) or self:AngleToPoint(target)) + self:GetAngle()
		local dir_angle = CalcOrientation(direction)
		local cur_angle = AngleDiff(dir_angle, face_angle)
		local new_angle = AngleDiff(target_angle, face_angle)
		if cur_angle * new_angle < 0 and abs(cur_angle - new_angle) > 90*60 then
			local pos = self:GetVisualPos()
			local target_pos = (IsValid(target) and target:GetVisualPos() or target)
			local new_target = pos + Rotate(target_pos - pos, cur_angle + (cur_angle < 0 and 90*60 or -90*60) - new_angle)
			return new_target
		end
	end
end

function Unit:SetIK(label, target, spot, initial_dir, time, overridePoseTime)
	if config.IKDisabled then
		target = false
	end
	if self.setik_thread then
		DeleteThread(self.setik_thread)
		self.setik_thread = false
	end
	local ikCmp = self:GetAnimComponentIndexFromLabel(1, label)	
	if ikCmp == 0 then
		if target then
			GameTestsErrorf("once", "Missing IK component %s for %s(%s) in state %s", tostring(label), self.unitdatadef_id, self:GetEntity(), self:GetStateText())
		end
	else
		local intermediate_target
		initial_dir = initial_dir or InvalidPos()
		overridePoseTime = overridePoseTime or 0
		time = -1000
		if IsPoint(target) then
			if not target:IsValidZ() then target = target:SetTerrainZ() end
			intermediate_target = time ~= 0 and self:CalcIKIntermediateTarget(ikCmp, target)
			if not intermediate_target then
				self:SetAnimComponentTarget(1, ikCmp, target, initial_dir, time, overridePoseTime)
			end
		elseif IsValid(target) then
			local spot_idx = target:GetSpotBeginIndex(spot or "Origin")
			local bone = target:GetSpotBone(spot_idx)
			if bone and bone ~= "" then
				intermediate_target = time ~= 0 and self:CalcIKIntermediateTarget(ikCmp, target)
				if not intermediate_target then
					self:SetAnimComponentTarget(1, ikCmp, target, bone, initial_dir, time, overridePoseTime)
				end
			else
				local pos = target:GetSpotLocPos(spot_idx)
				intermediate_target = time ~= 0 and self:CalcIKIntermediateTarget(ikCmp, pos)
				if not intermediate_target then
					self:SetAnimComponentTarget(1, ikCmp, pos, initial_dir, time, overridePoseTime)
				end
			end
		else
			assert(not target)
			self:RemoveAnimComponentTarget(1, ikCmp, true)
		end
		if intermediate_target then
			self:SetAnimComponentTarget(1, ikCmp, intermediate_target, initial_dir, time, overridePoseTime)
			self.setik_thread = CreateGameTimeThread(function(self, label, target, spot, initial_dir, time, overridePoseTime)
				Sleep(25)
				self.setik_thread = false
				self:SetIK(label, target, spot, initial_dir, time, overridePoseTime)
			end, self, label, target, spot, initial_dir, time, overridePoseTime)
		end
	end
	if g_IKDebug then
		g_IKDebug[self] = IsPoint(target) and target or IsValid(target) and target:GetSpotLocPos(target:GetSpotBeginIndex(spot or "Origin")) or nil
	end
end

function Unit:AimIdle()
	self.aim_rotate_last_angle = false
	self.aim_rotate_cooldown_time = false
	if not g_Combat then
		local x, y, z = GetPassSlabXYZ(self)
		if not x or not self:IsEqualPos(x, y, z) or not CanDestlock(self) then
			self:GotoSlab()
		end
	end
	while self.aim_action_id do
		local time = GameTime()
		local attack_args, attack_results = self:GetAimResults()
		self:AimTarget(attack_args, attack_results, false)
		Msg("AimIdleLoop")
		if time == GameTime() then
			Sleep(50)
		end
	end
	self:ForEachAttach("GrenadeVisual", DoneObject)
end

local aim_rotate_cooldown_times = {
	Standing = 250,
	Crouch = 500,
	Prone = 700,
}

function Unit:AimTarget(attack_args, attack_results, prepare_to_attack)
	if self:HasStatusEffect("ManningEmplacement") then
		if self:GetStateText() ~= "hmg_Crouch_Idle" then
			self:SetState("hmg_Crouch_Idle", const.eKeepComponentTargets, 0)
		end
		return
	end
	if not attack_args then
		return
	end
	local action_id = attack_args.action_id
	local action = CombatActions[action_id]
	local weapon = action and action:GetAttackWeapons(self)
	local prepared_attack = attack_args.opportunity_attack_type == "PinDown" or attack_args.opportunity_attack_type == "Overwatch"
	local lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group or "Torso")
	local lof_data = attack_args.lof and attack_args.lof[lof_idx or 1] or attack_args
	local aim_pos = lof_data.lof_pos2
	local trajectory = attack_results and attack_results.trajectory
	if trajectory and #trajectory > 1 then
		local p1 = trajectory[1].pos
		local p2 = trajectory[2].pos
		if p1 ~= p2 then
			aim_pos = p1 + SetLen(p2 - p1, 10*guim)
		end
	end
	aim_pos = aim_pos or attack_args.target
	if attack_args.OverwatchAction and lof_data.lof_pos1 then
		if self.ground_orient then
			local axis = self:GetAxis()
			local angle = self:GetAngle()
			local p1 = RotateAxis(lof_data.lof_pos1, axis, -angle)
			local p2 = RotateAxis(aim_pos, axis, -angle)
			aim_pos = RotateAxis(p2:SetZ(p1:z()), axis, angle)
		else
			aim_pos = aim_pos:SetZ(lof_data.lof_pos1:z())
		end
	end

	local rotate_to_target = prepare_to_attack or IsValid(attack_args.target) and IsKindOf(attack_args.target, "Unit")
	local aimIK = rotate_to_target and self:CanAimIK(weapon)
	local stance = rotate_to_target and attack_args.stance or self.stance
	local quick_play = GameState.loading or self:CanQuickPlayInCombat() 
	local idle_aiming

	if not rotate_to_target and self.stance == "Prone" and attack_args.stance ~= "Prone" then
		idle_aiming = true
	elseif not rotate_to_target and aimIK and abs(self:AngleToPoint(aim_pos)) > 50*60 then
		if self.last_idle_aiming_time then
			if GameTime() - self.last_idle_aiming_time > config.IdleAimingDelay then
				idle_aiming = true
			end
		else
			self.last_idle_aiming_time = GameTime()
		end
	else
		self.last_idle_aiming_time = false
	end

	local aim_anim
	if idle_aiming then
		local base_idle = self:GetIdleBaseAnim()
		if not IsAnimVariant(self:GetStateText(), base_idle) then
			if self.stance == "Prone" then
				-- first rotate
				local visual_stance = string.match(self:GetStateText(), "^%a+_(%a+)_")
				if visual_stance == "Standing" or visual_stance == "Crouch" then
					local angle = self:GetPosOrientation()
					if quick_play then
						self:SetOrientationAngle(angle)
					else
						self:AnimatedRotation(angle, self:GetIdleBaseAnim(visual_stance))
					end
				end
				self:SetFootPlant(true)
			end
			if not quick_play then
				PlayTransitionAnims(self, base_idle)
			end
			self:SetRandomAnim(base_idle)
		end
		self:SetIK("AimIK", false)
		aimIK = false
		aim_anim = self:GetStateText()
	else
		if (stance == "Standing" or stance == "Crouch") and self.stance == "Prone" then
			local cur_anim = self:GetStateText()
			if string.match(cur_anim, "%a+_(%a+).*") == "Prone" then
				self:SetFootPlant(true, nil, stance)
				if not quick_play then
					local base_idle = self:GetIdleBaseAnim(stance)
					local angle = lof_data.angle or CalcOrientation(lof_data.step_pos, aim_pos)
					PlayTransitionAnims(self, base_idle, angle)
				end
			end
		end
		self:AttachActionWeapon(action)
		aim_anim = self:GetAimAnim(action_id, stance)
	end

	if quick_play then
		if not self.return_pos and not IsCloser2D(self, lof_data.step_pos, const.SlabSizeX/2) and not attack_args.circular_overwatch then
			self.return_pos = GetPassSlab(self)
		end
		self:SetPos(lof_data.step_pos)
		self:SetOrientationAngle(lof_data.angle or CalcOrientation(lof_data.step_pos, aim_pos))
		if self:GetStateText() ~= aim_anim then
			self:SetState(aim_anim, const.eKeepComponentTargets, 0)
		end
		self:SetFootPlant(true)
		if aimIK then
			self:SetIK("AimIK", aim_pos, nil, nil, 0)
		else
			self:SetIK("AimIK", false)
		end
		return
	end

	self:SetIK("LookAtIK", false)
	self:SetFootPlant(true, nil, stance)

	if rotate_to_target then
		local prefix = string.match(aim_anim, "^(%a+_).*") or self:GetWeaponAnimPrefix()

		while true do
			-- enter step pos
			while not IsCloser2D(self, lof_data.step_pos, const.SlabSizeX/2) do
				local dummy_angle
				if lof_data.step_pos:Dist2D(self.return_pos or self) == 0 then
					dummy_angle = CalcOrientation(self.return_pos, aim_pos)
				else
					dummy_angle = CalcOrientation(self.return_pos or self, lof_data.step_pos)
				end
				if self:ReturnToCover(prefix) then
					-- some time passed, check if the lof_data.step_pos position has been changed
				else
					-- behind a cover. place the unit to the left or right of the cover.
					local angle = CalcOrientation(self, lof_data.step_pos)
					local rotate = abs(AngleDiff(angle, self:GetVisualOrientationAngle())) > 90*60
					self:SetIK("AimIK", false)
					if rotate then
						self:AnimatedRotation(angle, aim_anim)
					end
					if not rotate or self.command ~= "AimIdle" then
						local step_to_target = CalcOrientation(lof_data.step_pos, aim_pos)
						local cover_side = AngleDiff(step_to_target, angle) < 0 and "Left" or "Right"
						local anim = string.format("%s%s_Aim_Start", prefix, cover_side)
						if not self.return_pos and not attack_args.circular_overwatch then
							self.return_pos = GetPassSlab(self)
						end
						if IsValidAnim(self, anim) then
							anim = self:ModifyWeaponAnim(anim)
							self:SetPos(lof_data.step_pos, self:GetAnimDuration(anim))
							self:RotateAnim(step_to_target, anim)
						else
							local msg = string.format('Missing animation "%s" for "%s"', anim, self.unitdatadef_id)
							StoreErrorSource(self, msg)
							self:SetState(aim_anim, const.eKeepComponentTargets)
							self:SetAngle(step_to_target, 500)
							Sleep(500)
						end
					end
				end
				-- update aiming position (the cursor position could be changed)
				if self.command ~= "AimIdle" then
					if not IsCloser2D(self, lof_data.step_pos, const.SlabSizeX/2) then
						return
					end
					break
				end
				if not self.aim_action_id then
					return
				end
				attack_args, attack_results = self:GetAimResults()
				lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group or "Torso")
				lof_data = attack_args.lof and attack_args.lof[lof_idx or 1] or attack_args
				aim_pos = lof_data.lof_pos2 or attack_args.target
				if attack_results and attack_results.trajectory then
					local p1 = attack_results.trajectory[1].pos
					local p2 = attack_results.trajectory[2].pos
					aim_pos = p1 + SetLen(p2 - p1, 10*guim)
				end
			end
			
			if weapon then
				self:SetAimFX(weapon:GetVisualObj(self))
			end

			local angle = CalcOrientation(self, aim_pos)
			local start_angle = self:GetVisualOrientationAngle()
			local angle_diff = AngleDiff(angle, start_angle)
			if stance == "Prone" then
				if prepared_attack and not attack_args.circular_overwatch then
					angle = start_angle
				else
					if abs(angle_diff) <= 60*60 then
						angle = start_angle
					else
						angle = FindProneAngle(self, nil, angle, 60*60)
					end
				end
			end
			-- play transition animations to target anim
			local played_anims = PlayTransitionAnims(self, aim_anim, angle)
			if played_anims and self.command == "AimIdle" then
				break
			end
			if self.command ~= "AimIdle" then
				if not attack_args.opportunity_attack or abs(AngleDiff(angle, start_angle)) > 45*60 then
					self:AnimatedRotation(angle, aim_anim)
				end
				break
			end
			-- rotate left or right
			if abs(AngleDiff(angle, self:GetOrientationAngle())) < 1*60 then
				break
			end
			local max_deviation_angle = 45*60
			if abs(angle_diff) < max_deviation_angle and not (prepare_to_attack and prepared_attack) then
				self.aim_rotate_last_angle = false
				break
			end
			if not self.aim_rotate_last_angle or abs(AngleDiff(angle, self.aim_rotate_last_angle)) > max_deviation_angle then
				self.aim_rotate_last_angle = angle
				self.aim_rotate_cooldown_time = GameTime() + (aim_rotate_cooldown_times[stance] or 1000)
				break
			end
			if GameTime() - self.aim_rotate_cooldown_time < 0 then
				break
			end
			self.aim_rotate_last_angle = false
			self.aim_rotate_cooldown_time = false
			local rotate_anim = self:GetRotateAnim(angle_diff, aim_anim)
			if not IsValidAnim(self, rotate_anim) then
				self:IdleRotation(angle)
				break
			end
			self:SetIK("AimIK", false)
			rotate_anim = self:ModifyWeaponAnim(rotate_anim)
			if abs(angle_diff) > 150*60 then
				self:Rotate180(angle, rotate_anim)
			else
				self:SetState(rotate_anim, const.eKeepComponentTargets, Presets.ConstDef.Animation.BlendTimeRotateOnSpot.value)
				local anim_rotation_angle = self:GetStepAngle()
				local duration = self:TimeToAnimEnd()
				local rotation_deviation = 45*60
				local steps = 1 + duration / 20
				for i = 1, steps do
					local a = start_angle + i * angle_diff / steps
					local t = duration * i / steps - duration * (i - 1) / steps
					self:SetOrientationAngle(a, t)
					Sleep(t)
				end
			end
			self:SetState(aim_anim, const.eKeepComponentTargets)
			if aimIK then
				self:SetIK("AimIK", aim_pos)
			end
		end
	end

	local cur_anim = self:GetStateText()
	if cur_anim ~= aim_anim then
		self:SetState(aim_anim, const.eKeepComponentTargets)
	end
	if aimIK then
		if not self.aim_rotate_cooldown_time or GameTime() - self.aim_rotate_cooldown_time >= 0 then
			self:SetIK("AimIK", aim_pos)
		end
	else
		self:SetIK("AimIK", false)
	end
end

function Unit:SetAimFX(fx_target, delayed)
	if self.aim_fx_thread then
		DeleteThread(self.aim_fx_thread)
		self.aim_fx_thread = false
	end
	if self.aim_fx_target == (fx_target or false) then
		return
	end
	if delayed then
		self.aim_fx_thread = CreateGameTimeThread(function(self)
			Sleep(1)
			self.aim_fx_thread = false
			self:SetAimFX(fx_target)
		end, self, fx_target)
		return
	end
	if self.aim_fx_target then
		PlayFX("Aim", "end", self, self.aim_fx_target)
	end
	if fx_target then
		PlayFX("Aim", "start", self, fx_target)
	end
	self.aim_fx_target = fx_target
end

function Unit:CanAimIK(weapon)
	local weapon_type = weapon and weapon.WeaponType
	if not weapon_type then
		return false
	elseif weapon_type == "Grenade" then
		return false
	elseif weapon_type == "MeleeWeapon" then
		return false
	elseif weapon_type == "Mortar" then
		return false
	elseif weapon_type == "FlareGun" then
		return false
	elseif self:HasStatusEffect("ManningEmplacement") then
		return false
	end
	return true
end

function NetSyncEvents.Aim(unit, action_id, target)
	if not unit then return end
	local action = CombatActions[action_id]
	if action and action.DisableAimAnim then return end

	local changed = unit:SetAimTarget(action_id, target)
	if changed and unit.team and unit.team.control == "UI" then
		local playerId = unit:IsLocalPlayerControlled() and netUniqueId or GetOtherPlayerId()
		local targetId = IsKindOf(target, "Unit") and target.session_id
		SetCoOpPlayerAimingAtUnit(playerId, targetId)
	end
end

function OnMsg.RunCombatAction(action_id, unit)
	if unit and action_id ~= "Aim" and unit.aim_action_id then
		unit:SetAimTarget()
	end
end

local function playTurnOnFx(unit, weapon)
	local visual = weapon and weapon.visual_obj
	if not visual then return end
	
	for slot, component_id in sorted_pairs(weapon.components) do
		local component = WeaponComponents[component_id]
		if component and component.EnableAimFX then
			local fx_actor
			for _, descr in ipairs(component and component.Visuals) do
				if descr:Match(weapon.class) then
					fx_actor = visual.parts[descr.Slot]
					if fx_actor then
						break
					end
				end
			end
			fx_actor = fx_actor or visual
			PlayFX("TurnOn", "start", fx_actor)
			unit.weapon_light_fx = unit.weapon_light_fx or {}
			unit.weapon_light_fx[#unit.weapon_light_fx + 1] = fx_actor
		end
	end
end

function Unit:SetWeaponLightFx(enable)
	for _, fx_actor in ipairs(self.weapon_light_fx) do
		PlayFX("TurnOn", "end", fx_actor)
	end
	self.weapon_light_fx = false
	
	if enable and self.visible and not self:CanQuickPlayInCombat() then
		local weapon1, weapon2 = self:GetActiveWeapons()
		playTurnOnFx(self, weapon1)
		playTurnOnFx(self, weapon2)
	end	
end

function Unit:SetAimTarget(action_id, target)
	if action_id then
		local aim_target = target or false
		if IsPoint(aim_target) and not aim_target:IsValidZ() then
			aim_target = aim_target:SetTerrainZ(2*const.SlabSizeZ)
		end
		local aim_action_params = self.aim_action_params
		if not aim_action_params then
			aim_action_params = {}
			self.aim_action_params = aim_action_params
		end
		if self.aim_action_id == action_id and aim_action_params.target == aim_target then
			return false
		end

		if self.visible and self.aim_action_id ~= action_id then
			self:SetWeaponLightFx(true)
		end
		self.aim_action_id = action_id
		aim_action_params.target = aim_target 
		if self.command == "Idle" then
			self:SetCommand("Idle")
		end		
	elseif self.aim_action_id then
		self.aim_action_id = false
		self.aim_action_params = false
		self.aim_results = false
		self.aim_attack_args = false
	end
	return true
end

function Unit:GetActionResults(action_id, args)
	local action = CombatActions[action_id]
	if action then
		return action:GetActionResults(self, args)
	end
end

function Unit:GetAimResults()
	local action = CombatActions[self.aim_action_id]
	if not action then
		return
	elseif not self.aim_results then
		self.aim_results, self.aim_attack_args = action:GetActionResults(self, self.aim_action_params)
	end
	return self.aim_attack_args, self.aim_results
end

local NonStanceActionAnims = {
	["Idle"] = "idle",
	["Run"] = "walk",
	["Death"] = "death",
}

function Unit:UpdateModifiedAnim()
	local modify_animations_ar = false
	local weapon, weapon2 = self:GetActiveWeapons("Firearm")
	if weapon and not weapon2 then
		if weapon.ModifyRightHandGrip then
			modify_animations_ar = true
		else
			for i, component in pairs(weapon.components) do
				local visuals = (WeaponComponents[component] or empty_table).Visuals or empty_table
				local idx = table.find(visuals, "ApplyTo", weapon.class)
				if idx then
					local component_data = visuals[idx]
					if component_data.ModifyRightHandGrip then
						modify_animations_ar = true
						break
					end
				end
			end
		end
	end
	if self.modify_animations_ar ~= modify_animations_ar then
		self.modify_animations_ar = modify_animations_ar
		local anim = self:GetStateText()
		local new_anim = modify_animations_ar and self:ModifyWeaponAnim(anim) or GetUnmodifiedAnim(anim)
		if new_anim ~= anim then
			self:SetState(new_anim, const.eKeepPhase)
		end
	end
end

function Unit:ModifyWeaponAnim(anim)
	if self.modify_animations_ar then
		if string.starts_with(anim, "ar_") then
			local new_anim = "arg_" .. string.sub(anim, 4)
			if IsValidAnim(self, new_anim) then
				return new_anim
			end
		end
	end
	return anim
end

function GetUnmodifiedAnim(anim)
	if string.starts_with(anim, "arg_") then
		return "ar_" .. string.sub(anim, 5)
	end
	return anim
end

function Unit:GetUnmodifiedAnim()
	return GetUnmodifiedAnim(self:GetStateText())
end

function Unit:GetValidAnim(prefix, stance, action_full)
	local name = stance and stance ~= "" and string.format("%s_%s", stance, action_full) or action_full
	local base_anim = name
	if stance == "" then
		base_anim = NonStanceActionAnims[action_full] or base_anim
	end
	if prefix and prefix ~= "" then
		base_anim = prefix .. base_anim
	end
	local valid = self:HasState(base_anim) and not IsErrorState(self:GetEntity(), base_anim)
	if not valid and action_full == "WalkSlow" then
		return self:GetValidAnim(prefix, stance, "Walk")
	end
	return valid, base_anim, name
end

function IsAnimVariant(anim, base_anim)
	anim = GetUnmodifiedAnim(anim)
	return (anim == base_anim or string.starts_with(anim, base_anim) and tonumber(string.sub(anim, #base_anim + 1))) and true or false
end

function GetAnimVariants(entity, base_anim)
	if not HasState(entity, base_anim) or IsErrorState(entity, base_anim) then
		return {}
	end
	
	local format = string.match(base_anim, ".*%d$") and "%s_%d" or "%s%d"
	local anim_variants = {}
	local count = 0
	while true do
		count = count + 1
		local anim = (count == 1) and base_anim or string.format(format, base_anim, count)
		if not HasState(entity, anim) or IsErrorState(entity, anim) then
			break
		end
		table.insert(anim_variants, anim)
	end
	
	return anim_variants
end

local anim_variations_weight_cache = {}
local anim_variations_phases_chunk = 1000
local anim_variations_min_time_offset = 2000
local nearby_unique_anim_distance = 12*guim

local function GetRandomAnims(entity, base_anim)
	local t = anim_variations_weight_cache[entity]
	if not t then
		t = {}
		anim_variations_weight_cache[entity] = t
	end
	if not t[base_anim] then
		local anims = {}
		t[base_anim] = anims
		local total_chunks = 0
		local total_weight = 0
		local anim_variants = GetAnimVariants(entity, base_anim)
		for idx, anim in ipairs(anim_variants) do
			local anim_metadata = (Presets.AnimMetadata[entity] or empty_table)[anim] or empty_table
			local anim_weight = anim_metadata.VariationWeight or 100
			local max_random_phase = anim_metadata.RandomizePhase or -1
			if max_random_phase < 0 then
				max_random_phase = GetAnimDuration(entity, base_anim) * 70 / 100
			end
			local chunks_count = 1 + max_random_phase / anim_variations_phases_chunk
			total_weight = total_weight + anim_weight
			anims[idx] = {
				anim = anim,
				anim_weight = anim_weight,
				total_weight = total_weight,
				max_random_phase = max_random_phase,
				chunk_idx = total_chunks,
				chunks_count = chunks_count,
			}
			total_chunks = total_chunks + chunks_count
		end
		anims.total_weight = total_weight
		anims.total_chunks = total_chunks
	end
	return	t[base_anim]
end

function Unit:GetVariationsCount(base_anim)
	if not base_anim then
		return
	end
	local anims = GetRandomAnims(self:GetEntity(), base_anim)
	return #anims
end

function Unit:GetRandomAnim(base_anim)
	if not base_anim then
		return
	end
	local anims = GetRandomAnims(self:GetEntity(), base_anim)
	if #anims == 0 then
		StoreErrorSource(self, string.format("Invalid '%s' variation request", base_anim))
		return base_anim, 1, 1
	end
	local roll = self:Random(anims.total_weight)
	local idx = GetRandomItemByWeight(anims, roll, "total_weight")
	return anims[idx].anim, idx
end

function Unit:GetNearbyUniqueRandomAnim(base_anim)
	if not base_anim then
		return
	end
	local anims = GetRandomAnims(self:GetEntity(), base_anim)
	if anims.total_chunks == 1 then
		return anims[1].anim, 0, 1 -- animation, phase, variation index
	end

	local anims_locked_chunks = {}
	MapForEach(self, nearby_unique_anim_distance, "Unit", function(o, self, anims, anims_locked_chunks)
		if o == self then
			return
		end
		if o.gender ~= self.gender then
			return
		end
		local variation_idx = table.find(anims, "anim", o:GetUnmodifiedAnim())
		if not variation_idx then
			return
		end
		local min, max
		local entry = anims[variation_idx]
		if entry.max_random_phase == 0 then
			min, max = 1, 1 -- this animation is not supposed to be played more than once
		else
			local phase = o:GetAnimPhase()
			min = Max(0, phase - anim_variations_min_time_offset) / anim_variations_phases_chunk
			max = Min(entry.max_random_phase, phase + anim_variations_min_time_offset) / anim_variations_phases_chunk
			if min > max then
				return
			end
		end
		local chunk_idx = entry.chunk_idx
		local locked_count = 0
		for i = min, max do
			if not anims_locked_chunks[chunk_idx + i] then
				anims_locked_chunks[chunk_idx + i] = true
				locked_count = locked_count + 1
			end
		end
		if locked_count > 0 then
			NetUpdateHash("GetNearbyUniqueRandomAnim_locking_anim", o, chunk_idx, variation_idx, locked_count, o:GetUnmodifiedAnim(), o:GetAnimPhase())
			anims_locked_chunks[-variation_idx] = (anims_locked_chunks[-variation_idx] or 0) + locked_count
		end
	end, self, anims, anims_locked_chunks)

	-- try first not used animation
	local total_free_animations = 0
	for idx, entry in ipairs(anims) do
		if entry.chunks_count > 0 and not anims_locked_chunks[entry.chunk_idx] then
			total_free_animations = total_free_animations + 1
		end
	end
	NetUpdateHash("GetNearbyUniqueRandomAnim_total_free_animations", total_free_animations)
	if total_free_animations > 0 then
		local value = total_free_animations > 1 and self:Random(total_free_animations) or 0
		for idx, entry in ipairs(anims) do
			if entry.chunks_count > 0 and not anims_locked_chunks[entry.chunk_idx] then
				value = value - 1
			end
			if value < 0 then
				return entry.anim, 0, idx
			end
		end
		assert(false)
	end

	-- look for not used animation segment
	local total_weight = anims.total_weight
	for idx, entry in ipairs(anims) do
		local locked_chunks_count = anims_locked_chunks[-idx]
		if locked_chunks_count then
			local locked_weight = entry.anim_weight * locked_chunks_count / entry.chunks_count
			total_weight = total_weight - locked_weight
		end
	end
	if total_weight > 0 then
		local value = self:Random(total_weight)
		for idx, entry in ipairs(anims) do
			local weight = entry.anim_weight
			local locked_chunks_count = anims_locked_chunks[-idx]
			if locked_chunks_count then
				local locked_weight = weight * locked_chunks_count / entry.chunks_count
				weight = weight - locked_weight
			end
			if weight > 0 then
				value = value - weight
				if value < 0 then
					-- return the first free chunk
					if not locked_chunks_count then
						return entry.anim, 0, idx
					end
					for i = entry.chunk_idx, entry.chunk_idx + entry.chunks_count - 1 do
						if not anims_locked_chunks[i] then
							local phase = (i - entry.chunk_idx) * anim_variations_phases_chunk
							return entry.anim, phase, idx
						end
					end
					assert(false)
				end
			end
		end
		assert(false)
	end
	-- there is no free animations
	local anim, variation_idx = self:GetRandomAnim(base_anim)
	return anim, 0, variation_idx
end

function Unit:GetNearbyUniqueRandomAnimFromList(list)
	local anims = table.icopy(list)
	MapForEach(self, nearby_unique_anim_distance, "Unit", function(o, anims)
		if o == self then
			return
		end
		local idx = table.find(anims, o:GetUnmodifiedAnim())
		if idx then
			table.remove(anims, idx)
		end
	end, anims)
	if #anims > 0 then
		return anims[1 + self:Random(#anims)]
	end
	return list[1 + self:Random(#list)]
end	

local UniversalAnimActions = {
	Climb = true,
	Drop = true,
	JumpOverShort = true,
	JumpOverLong = true,
	JumpAcross1 = true,
	JumpAcross2 = true,
}

local ActionAnimationPrefixMap = {
	["Open_Door"] = {
		["inf_"] = "nw_",
	},
	["BreakWindow"] = {
		["civ_"] = "nw_",
		["inf_"] = "nw_",
	},
	["Downed"] = {
		["civ_"] = "nw_",
		["inf_"] = "nw_",
	},
	["Death"] = {
		["inf_"] = "civ_",
	},
}

function Unit:TryGetActionAnim(action, stance, action_suffix)
	local action_full
	if not g_Combat and action == "Idle" or action == "IdlePassive" then
		action_full = self:GetCommandParam("idle_action")
		stance = self:GetCommandParam("idle_stance") or stance
	end
	if not action_full then
		action_full = action_suffix and action .. action_suffix or action
	end

	local prefix
	if self.species == "Human" then
		if UniversalAnimActions[action] then
			prefix = "civ_"
		elseif self:HasStatusEffect("ManningEmplacement") and (action == "Idle" or action == "IdlePassive" or action == "Fire") then
			prefix = "hmg_"
			stance = "Crouch"
		elseif action == "Fire" then
			local weapon, weapon2 = self:GetActiveWeapons()
			prefix = weapon and GetWeaponAnimPrefix(weapon, weapon2) or "nw_"
			if prefix == "nw_" then
				stance = "Standing"
				action_full = "Attack_Down"
			end
		elseif self.infected then
			if action == "Idle" and stance == "Prone" then
				prefix = "nw_"
			else
				prefix = "inf_"
				if action ~= "Death" and action ~= "Downed" and (stance == "Prone" or stance == "Crouch") then
					stance = "Standing"
				end
			end
		else
			if action == "CombatBegin" then
				stance = "Standing"
			end
			prefix = self:GetWeaponAnimPrefix()
		end
		local action_prefix_map = ActionAnimationPrefixMap[action]
		if action_prefix_map and action_prefix_map[prefix] then
			prefix = action_prefix_map[prefix]
		end
	else
		stance = ""
		if action == "Idle" then
			if self.species == "Hyena" then
				action_full = "idle_Combat"
			end
		elseif action == "Climb" then
			action_full = action_suffix == 1 and "climb_1x" or "climb_2x"
		elseif action == "Drop" then
			action_full = action_suffix == 1 and "drop_1x" or "drop_2x"
		elseif action == "CombatBegin" then
			action_full = "combat_Begin"
		end
	end

	local valid, anim, name = self:GetValidAnim(prefix, stance, action_full)
	if valid then
		return anim
	end
	-- fallback
	if action == "Downed" then
		return "civ_DeathOnSpot_F"
	end
	local fallback_prefix = self:GetWeaponAnimPrefixFallback()
	if fallback_prefix ~= prefix then
		local fallback_anim = string.format("%s%s", fallback_prefix, name)
		if self:HasState(fallback_anim) and not IsErrorState(self:GetEntity(), fallback_anim)then
			return fallback_anim
		end
	end

	return false, anim
end

function Unit:GetActionBaseAnim(action, stance, action_suffix)
	local anim, name = self:TryGetActionAnim(action, stance, action_suffix)
	if not anim then
		local msg = string.format('Missing animation "%s" for "%s"', name, self.unitdatadef_id)
		StoreErrorSource(self, msg)
	end
	return anim
end

function Unit:GetActionRandomAnim(action, stance, action_suffix)
	local base_anim = self:GetActionBaseAnim(action, stance, action_suffix)
	local anim = self:GetNearbyUniqueRandomAnim(base_anim)
	return anim
end

function Unit:SetRandomAnim(base_anim, flags, crossfade, force)
	NetUpdateHash("Unit_SetRandomAnim sync_loading", GameState.sync_loading)
	if not force and IsAnimVariant(self:GetStateText(), base_anim) then
		return
	end
	local anim, phase = self:GetNearbyUniqueRandomAnim(base_anim)
	anim = self:ModifyWeaponAnim(anim)
	self:SetState(anim, flags or const.eKeepComponentTargets, crossfade or -1)
	if phase > 0 then
		self:SetAnimPhase(1, phase)
	end
end

function Unit:RandomizeAnimPhase()
	local duration = GetAnimDuration(self:GetEntity(), self:GetState())
	if duration > 1 then
		local phase = self:Random(duration - 1)
		self:SetAnimPhase(1, phase)
	end
end

function Unit:GetAttackAnim(action_id, stance)
	local attack_anim
	if self.species == "Human" then
		if action_id then
			if string.starts_with(action_id, "ThrowGrenade") then
				attack_anim = "gr_Standing_Attack"
			elseif string.match(action_id, "DoubleToss") then
				attack_anim = "gr_Standing_Attack"
			elseif action_id == "KnifeThrow" or action_id == "HundredKnives" then
				attack_anim = "mk_Standing_Fire"
			elseif action_id == "UnarmedAttack" then
				attack_anim = "nw_Standing_Attack_Down"
			elseif action_id == "Bombard" then
				attack_anim = "nw_Standing_MortarFire"
			elseif action_id == "FireFlare" then
				attack_anim = string.format("hg_%s_Flare_Fire", stance or self.stance)
			elseif action_id == "Charge" or action_id == "GloryHog" or action_id == "MeleeAttack" then
				attack_anim = IsKindOf(self:GetActiveWeapons(), "MacheteWeapon") and "mk_Standing_Machete_Attack_Forward"
					or "mk_Standing_Attack_Forward"
			elseif action_id == "Bandage" then
				return "nw_Bandaging_Idle"
			end
		end
		if not attack_anim then
			attack_anim = self:GetActionBaseAnim("Fire", stance)
		end
	else
		if self:HasState("attack") and not IsErrorState(self:GetEntity(), "attack") then
			attack_anim = "attack"
		end
	end
	attack_anim = self:ModifyWeaponAnim(attack_anim)
	return attack_anim
end

function Unit:GetAimAnim(action_id, stance)
	local aim_idle
	
	if self.species == "Human" then
		if action_id then
			if string.starts_with(action_id, "ThrowGrenade") then
				aim_idle = "gr_Standing_Aim"
			elseif string.match(action_id, "DoubleToss") then
				aim_idle = "gr_Standing_Aim"
			elseif action_id == "KnifeThrow" or action_id == "HundredKnives" then
				aim_idle = "mk_Standing_Aim_Forward"
				--aim_idle = "mk_Standing_Aim_Down"
			elseif action_id == "UnarmedAttack" then
				aim_idle = "nw_Standing_Aim_Forward"
			elseif action_id == "Bombard" then
				aim_idle = "nw_Standing_Idle"
			elseif action_id == "FireFlare" then
				aim_idle = string.format("hg_%s_Flare_Aim", stance or self.stance)
			end
		end
		if not aim_idle then
			local weapon, weapon2 = self:GetActiveWeapons()
			if IsKindOf(weapon, "MeleeWeapon") then
				aim_idle = "mk_Standing_Aim_Forward"
			elseif weapon then
				local attack_anim = self:GetActionBaseAnim("Fire", stance or self.stance)
				local prefix, stance = string.match(attack_anim or "", "(%a+)_(%a+).*")
				if prefix then
					local anim = string.format("%s_%s_Aim", prefix, stance)
					if IsValidAnim(self, anim) then
						aim_idle = anim
					end
				end
			end
			aim_idle = aim_idle or "nw_Standing_Aim_Forward"
		end
	else
		aim_idle = "idle"
	end
	if not IsValidAnim(self, aim_idle) then
		return
	end
	aim_idle = self:ModifyWeaponAnim(aim_idle)
	return aim_idle
end

function Unit:GetIdleStyle()
	local anim_style
	if self.species ~= "Human" then
		local aware = g_Combat and (self:IsAware() or self:HasStatusEffect("Surprised")) or self:HasStatusEffect("Suspicious")
		local cur_style = GetAnimationStyle(self, self.cur_idle_style)
		anim_style =
			aware and (cur_style and cur_style.VariationGroup == "CombatIdle" and cur_style
				or GetRandomAnimationStyle(self, "CombatIdle"))
			or cur_style and cur_style.VariationGroup == "Idle" and cur_style
			or GetRandomAnimationStyle(self, "Idle")
	else
		if self.carry_flare then
			anim_style = GetRandomAnimationStyle(self, "FlareIdle")
		end
	end
	return anim_style
end

function Unit:GetIdleBaseAnim(stance)
	local cur_style = GetAnimationStyle(self, self.cur_idle_style)
	local base_idle = cur_style and cur_style:GetMainAnim()
	if base_idle then
		if not IsValidAnim(self, base_idle) then
			local msg = string.format('GetIdleBaseAnim: Missing animation style "%s - %s" animation "%s". Gender: "%s". Entity: "%s". Appearance: %s', cur_style.group, cur_style.Name, base_idle or "", self.gender, self:GetEntity(), self.Appearance or "false")
			StoreErrorSource(self, msg)
		end
		return base_idle
	end
	stance = stance or self.stance
	local aware = g_Combat and (self:IsAware("pending") or self:HasStatusEffect("Surprised")) or self:HasStatusEffect("Suspicious")
	if aware and self.species == "Human" and self.team and self.team.side == "neutral" and not self.conflict_ignore and not self.infected then
		base_idle = "civ_Standing_Fear"
	end
	if not base_idle and not aware and self.species == "Human" then
		base_idle = self:TryGetActionAnim("IdlePassive", stance)
	end
	if not base_idle and self.species == "Human" and (stance == "Standing" or stance == "Crouch") and self:HasStatusEffect("Protected") then
		base_idle = self:TryGetActionAnim("TakeCover_Idle", false)
	end
	if not base_idle then
		base_idle = self:TryGetActionAnim("Idle", stance)
	end
	return base_idle or "idle"
end

function Unit:ShowActiveMeleeWeapon()
	local weapon1 = self:GetActiveWeapons()
	local wobj1 = IsKindOf(weapon1, "MeleeWeapon") and weapon1:GetVisualObj()
	if not wobj1 then
		return false
	end
	wobj1:SetEnumFlags(const.efVisible)
	return true
end

function Unit:HideActiveMeleeWeapon()
	local weapon1 = self:GetActiveWeapons()
	local wobj1 = IsKindOf(weapon1, "MeleeWeapon") and weapon1:GetVisualObj()
	if not wobj1 then
		return false
	end
	wobj1:ClearEnumFlags(const.efVisible)
	return true
end

local function lGetFallbackUnitAppearance(preset)
	if not preset then return "Soldier_Local_01" end
	if preset.gender == "Male" then
		return "Commando_Foreign_01"
	end
	return "Soldier_Local_01"
end

function GetAppearancesListTotalWeight(preset)
	local weighted_list = {total_weight = 0}
	for _, descr in ipairs(preset.AppearancesList) do
		if MatchGameState(descr.GameStates) then
			weighted_list.total_weight = weighted_list.total_weight + descr.Weight
			table.insert(weighted_list, {weight = weighted_list.total_weight, appearance = descr.Preset})
		end
	end
	
	return weighted_list
end

function GetWeightedAppearance(weighted_list, slot)
	local idx = GetRandomItemByWeight(weighted_list, slot, "weight")
	return weighted_list[idx].appearance
end

function ChooseUnitAppearance(merc_id, handle)
	local preset = UnitDataDefs[merc_id]
	if not preset or not preset.AppearancesList then
		return lGetFallbackUnitAppearance(preset)
	end
	
	local weighted_list = GetAppearancesListTotalWeight(preset)
	local slot = handle and (xxhash(handle) % weighted_list.total_weight) or InteractionRand(weighted_list.total_weight, "Appearance")
	local appearance = GetWeightedAppearance(weighted_list, slot)
	
	return appearance or lGetFallbackUnitAppearance(preset)
end

function Unit:ChooseAppearance()
	local forcedAppearance = false
	
	if self.spawner then
		local templates = self.spawner.UnitDataSpawnDefs or empty_table
		local data = table.find_value(templates, "UnitDataDefId", self.unitdatadef_id)
		forcedAppearance = data and data.ForcedAppearance
	end
	
	local unitData = gv_UnitData[self.session_id]
	if not forcedAppearance and unitData and unitData.ForcedAppearance then
		forcedAppearance = unitData.ForcedAppearance
	end

	if forcedAppearance then
		return forcedAppearance
	end

	return ChooseUnitAppearance(self.unitdatadef_id, self.handle)
end

function Unit:ExplosionFly(prev_hit_points)
	-- not flying anymore(too cartoon) - just play Pain
	self:PushDestructor(function(self)
		SetCombatActionState(self, false)
		self:InterruptPreparedAttack() -- force interrupt when the unit gets thrown off by an explosion
		self:RemoveStatusEffect("Protected") -- lose cover
		if ShouldDoDestructionPass() then
			WaitMsg("DestructionPassDone", 1000) --wait for destro if slabs beneath us get destroyed, so we can get a falldown point
		end
		
		--remove badge as the removal of it in unitdiestart is too late in this case
		if self:IsDead() then 
			DeleteBadgesFromTargetOfPreset("CombatBadge", self)
			DeleteBadgesFromTargetOfPreset("NpcBadge", self)
			if self:ShouldGetDowned() and (g_Combat or (not g_Combat and (prev_hit_points > 1))) then
				self.HitPoints = 1 -- make sure the unit is not considered dead and evicted from the UI
				self:SetCommand("GetDowned", false, "skip anim")
			elseif self.species == "Human" then
				self.on_die_hit_descr = self.on_die_hit_descr or {}
				self.on_die_hit_descr.death_explosion = true
				self:SetCommand("Die")
			else
				self:SetCommand("Die")
			end
		else
			self:Pain()
			-- the combat use the same GotoSlab (the unit should have already been interrupted)
			local pos = GetPassSlab(RotateRadius(guim/2, self:GetOrientationAngle(), self)) or GetPassSlab(self)
			if self:GetPos() ~= pos then
				self:SetCommand("GotoSlab", pos, nil, nil, nil, nil, nil, "interrupted")
			end
		end
	end)
	self:PopAndCallDestructor()
end

function Unit:AttachGrenade(grenade)
	local visual = PlaceObject("GrenadeVisual", {fx_actor_class = grenade.class})
	self:Attach(visual, self:GetSpotBeginIndex("Weaponr"))
	grenade:OnPrepareThrow(self, visual)
	return visual
end

function Unit:DetachGrenade(grenade)
	self:DestroyAttaches("GrenadeVisual")
	grenade:OnFinishThrow(self)
end

function GravityFall(obj, pos)
	obj:SetGravity()
	local fall_time = obj:GetGravityFallTime(pos)
	obj:SetPos(pos, fall_time)
	Sleep(fall_time)
	obj:SetGravity(0)
end

function Unit:FallDown(pos, cower)
	pos = ValidateZ(pos)
	local myPos = ValidateZ(self:GetPos())
	local height = myPos:z() - pos:z()
	if height > 0 then
		if self:HasPreparedAttack() then
			self:InterruptPreparedAttack()
		end
		self:LeaveEmplacement(true)
		if not self:IsDead() then
			local base_idle = self:GetIdleBaseAnim()
			if not IsAnimVariant(self:GetStateText(), base_idle) then
				local anim = self:GetNearbyUniqueRandomAnim(base_idle)
				self:SetState(anim)
			end
		end
		self:SetTargetDummyFromPos(pos)
		GravityFall(self, pos)
		local floors = DivCeil(height, 4 * const.SlabSizeZ)
		local damage = 1 + self:Random(floors * 10)
		local floating_text = T{443902454775, "<damage> (High Fall)", damage = damage}
		self:TakeDirectDamage(damage, floating_text)
		if not self:IsDead() then
			self:UninterruptableGoto(self:GetPos())
		end
	elseif pos ~= myPos then
		self:LeaveEmplacement()
		if not self:IsDead() then
			self:UpdateMoveAnim()
			self:UninterruptableGoto(pos, true)
		end
	end
	self:SetTargetDummyFromPos()
	if cower and not self:IsDead() then
		self:SetCommand("Cower", "find cower spot")
		self:SetCommandParamValue("Cower", "move_anim", "Run")
		self:UpdateMoveAnim()
	end
end

function Unit:PlayAwarenessAnim(followup_cmd)
	local setPiece = GetDialog("XSetpieceDlg")
	local triggerUnit = setPiece and setPiece.triggerUnits and setPiece.triggerUnits[1]
	local isTriggerUnit = triggerUnit and triggerUnit == self
	local idleAnim = false
	if self.stance == "Prone" then
		self:DoChangeStance("Standing")
	end
	local anims
	if setPiece and not isTriggerUnit then
		anims = { self:TryGetActionAnim("Idle", self.stance) }
		idleAnim = true
	elseif self.species == "Human" then
		local heavyWeaponUsage = IsKindOf(self:GetActiveWeapons(), "HeavyWeapon")
		local sniperUsage = IsKindOf(self:GetActiveWeapons(), "SniperRifle")
		local base_anim = self:GetActionBaseAnim("CombatBegin", self.stance)
		if base_anim then
			if self.infected then
				-- zombies do not have variatins of _CombatBegin
				anims = { base_anim }
			else
				if self.pending_awareness_role == "alerter" then
					if heavyWeaponUsage or sniperUsage then
						anims = { base_anim } -- variation 3 shoots and with snipers and heavy weapons we do not want that
					else
						anims = { base_anim .. 3 }
					end
				elseif self.pending_awareness_role == "alerted" then
					anims = { base_anim }
				elseif self.pending_awareness_role == "attacked" then
					anims = { base_anim .. 4 }
				elseif self.pending_awareness_role == "surprised" then
					anims = { base_anim .. 2 }
				end
			end
		end
	else
		if self.pending_awareness_role == "alerter" then
			anims = { "combat_Begin" }
		else
			anims = { "combat_Begin2" }
		end
	end
	if anims then
		if self.pending_awareness_role == "alerted" and not IsValid(self.alerted_by_enemy) then
			Sleep(self:Random(500)) -- randomize phase when multiple units playing
		end
		local anim = self:GetNearbyUniqueRandomAnimFromList(anims)
		anim = self:ModifyWeaponAnim(anim)
		self:SetState(anim, const.eKeepComponentTargets)
		if IsValid(self.alerted_by_enemy) then
			self:Face(self.alerted_by_enemy, 200)
		end
		local weapon = self:GetActiveWeapons()
		local fx_target = weapon and weapon:GetVisualObj() or false
		if fx_target and not idleAnim then
			PlayFX("AwarenessAnim", "start", self, fx_target)
			local index = 1
			while true do
				local t = self:TimeToMoment(1, "hit", index)
				if not t then break end
				Sleep(t)
				PlayFX("AwarenessAnim", "hit", self, fx_target)
				index = index + 1
			end
			Sleep(self:TimeToAnimEnd())
			PlayFX("AwarenessAnim", "end", self, fx_target)
		elseif not idleAnim then
			Sleep(self:TimeToAnimEnd())
		end
	end
	self.pending_awareness_role = nil
	if followup_cmd then
		self:SetCommand(followup_cmd)
	end
end

function Unit:BanterIdle(idle_style)
	self:PlayIdleStyle(idle_style)
end

-- setpiece stuff
function Unit:SetpieceIdle(set_idle)
	-- default command to put units into while playing setpiece and to store some behavior specific params for the setpiece
	Msg("OnSetpieceIdleStart", self)
	local wasInterruptable = self.interruptable
	if wasInterruptable then
		self:EndInterruptableMovement()
	end
	if set_idle then
		local base_idle = self:GetIdleBaseAnim()
		if not IsAnimVariant(self:GetStateText(), base_idle) then
			local anim = self:GetNearbyUniqueRandomAnim(base_idle)
			self:SetState(anim)
		end
	end
	
	repeat
		Sleep(100)
	until not IsSetpiecePlaying()
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
end

function Unit:SetpieceSetStance(anim_stance)
	if Presets.CombatStance.Default[anim_stance] then
		self.stance = anim_stance
	end
	local base_idle = self:GetIdleBaseAnim(anim_stance)
	if not IsAnimVariant(self:GetStateText(), base_idle) then
		local anim = self:GetNearbyUniqueRandomAnim(base_idle)
		self:SetState(anim)
	end
	self:SetCommand("SetpieceIdle")
end

function Unit:RestoreAiming(target_pt, lof_params)
	local weapon, weapon2 = self:GetActiveWeapons()
	if weapon then
		local attack_data = self:ResolveAttackParams(nil, target_pt, lof_params)
		local aim_idle = self:GetAimAnim(nil, attack_data.stance)
		self:SetState(aim_idle, const.eKeepComponentTargets)
		self:SetPos(attack_data.step_pos)
	else
		if self.return_pos then
			self:SetPos(self.return_pos)
			self.return_pos = false
		end
		self:SetRandomAnim(self:GetIdleBaseAnim())
	end
	self:Face(target_pt)
end

function Unit:SetpieceAimAt(target_pt)
	self:RestoreAiming(target_pt, {can_use_covers = false})
	Msg("SetpieceUnitAimed", self)
	self:SetCommand("SetpieceIdle")
end

function Unit:SetpieceGoto(pos, end_angle, stance, straight_line, animated_rotation, delay)
	self.goto_target = false
	if delay then
		Sleep(delay)
	end
	if (stance or "") ~= "" and stance ~= self.stance then
		self:DoChangeStance(stance)
	end
	-- initial animated face target
	if animated_rotation then
		local face_pos
		if straight_line then
			face_pos = pos
		else
			self:FindPath(pos)
			local pathlen = pf.GetPathPointCount(self)
			for i = pathlen, 1, -1 do
				local p = pf.GetPathPoint(self, i)
				if p and p:IsValid() and self:GetDist2D(p) > 0 then
					face_pos = p
					break
				end
			end
		end
		if face_pos then
			local angle = CalcOrientation(self, face_pos)
			if abs(AngleDiff(angle, self:GetOrientationAngle())) > 45*60 then
				self:AnimatedRotation(angle)
			end
		end
	end
	-- goto
	self:UninterruptableGoto(pos, straight_line)
	-- finish: face target
	if end_angle then
		if animated_rotation and abs(AngleDiff(end_angle, self:GetOrientationAngle())) > 45*60 then
			self:AnimatedRotation(end_angle)
		else
			self:SetOrientationAngle(end_angle, 100)
		end
	end
	self:SetCommand("SetpieceSetStance", self.stance)
end

function OnMsg.ClassesPreprocess(classdefs)
	classdefs.AppearanceObjectPart.flags.gofUnitLighting = true
end