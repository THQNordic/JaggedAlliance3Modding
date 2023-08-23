if FirstLoad then
	SkinDecalEditor = false
	SkinDecalEditorMode = false
	SkinDecals = false
end

SkinDecalAttachAxis = {
	["+X"] = point( 4096, 0, 0),
	["-X"] = point(-4096, 0, 0),
	["+Y"] = point(0,  4096, 0),
	["-Y"] = point(0, -4096, 0),
	["+Z"] = point(0, 0,  4096),
	["-Z"] = point(0, 0, -4096),
}

function EntitySpotsCombo(obj)
	local spots_data = IsKindOf(obj, "Object") and GetEntitySpots(obj:GetEntity())
	local spots = { "" }
	for spot, _ in sorted_pairs(spots_data) do
		spots[#spots + 1] = spot
	end
	return spots
end

DefineClass("SkinDecal", "Decal")

-- this class is only for the Skin Decal Editor purposes
DefineClass.BaseObjectSDE = {
	__parents = { "Object", "SkinDecalData" },

	properties = {
		{ category = "Stains", id = "DecType", editor = "dropdownlist", items = PresetsCombo("SkinDecalType", "Default", ""), default = "", read_only = function(self) return self.edit_mode end },
		{ category = "Stains", id = "Spot", editor = "dropdownlist", items = function() return EntitySpotsCombo end, default = "", read_only = function(self) return self.edit_mode end },
		{ category = "Stains", id = "stains_buttons", editor = "buttons", default = false, dont_save = true, read_only = true, 
			no_edit = function(self) return self.edit_mode or self.DecType == "" or self.Spot == "" end,
			buttons = {
				{name = "Add Stain", func = function(self, ...)
					Unit.AddStain(self, self.DecType, self.Spot)
				end},
				{name = "Remove All", func = function(self, ...)
					Unit.ClearStainsFromSpots(self)
				end, no_edit = function(self) return not self.stains end,},
				{name = "Remove Type", func = function(self, ...)
					Unit.ClearStains(self, self.DecType)
				end},
				{name = "Clear Spot", func = function(self, ...)
					Unit.ClearStainsFromSpots(self, self.Spot)
				end},
			},
		},
		{ category = "Stains", id = "edit_buttons", editor = "buttons", default = false, dont_save = true, read_only = true, 
			no_edit = function(self) return self.DecType == "" or self.Spot == "" end,
			buttons = {
				{name = "Toggle Edit", func = function(self, ...)
					self:ToggleEditMode()
				end},
			},
		},
		{ category = "Appearance", id = "DecEntity", name = "Decal Entity", 
			editor = "choice", default = "", items = function (self) return ClassDescendantsCombo("SkinDecal") end, 
			no_edit = function(self) return not self.edit_mode end },
		{ category = "Appearance", id = "DecOffsetX", name = "Offset X (red axis)", 
			editor = "number", default = 0, scale = "cm", slider = true, min = -500, max = 500, 
			no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "DecOffsetY", name = "Offset Y (green axis)", 
			editor = "number", default = 0, scale = "cm", slider = true, min = -500, max = 500, 
			no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "DecOffsetZ", name = "Offset Z (blue axis)", 
			editor = "number", default = 0, scale = "cm", slider = true, min = -500, max = 500, 
			no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "InvertFacing", name = "Invert Facing (along red axis)", 
			editor = "bool", default = false, no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "DecAttachAxis", name = "Rotation Axis", 
			editor = "choice", default = "+X", items = function (self) return table.keys(SkinDecalAttachAxis, "sorted") end, 
			no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "DecAttachAngleRange", name = "Rotation Range", 
			editor = "range", default = range(0, 360), 
			slider = true, min = 0, max = 360, no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "DecScale", name = "Scale", 
			editor = "number", default = 100, slider = true, min = 1, max = 500, 
			no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "ClrMod", name = "Color Modifier", 
			editor = "color", default = RGB(100, 100, 100), no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "ShowSpot", editor = "bool", default = false , no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "ShowDecalBBox", editor = "bool", default = false , no_edit = function(self) return not self.edit_mode end},
		{ category = "Appearance", id = "appearance_buttons", editor = "buttons", default = false, dont_save = true, read_only = true, 
			no_edit = function(self) return not self.edit_mode end,
			buttons = {
				{name = "Reapply", func = function(self, ...)
					if self.curr_stain then
						self.curr_stain.Rotation = -1
						self.curr_stain.initialized = false
					end
					self:UpdateCurrStain()					
				end},
				{name = "Save", func = function(self, ...)
					self:TransferToPreset()
				end},
				{name = "Revert", func = function(self, ...)
					self:RevertChanges()
				end},
			},
		},
				
		{ id = "DontHideWithRoom" },
	},

	Frame = 0,
	anim_thread = false,
	anim_duration = 0,
	loop_anim = true,
	preview_speed = 100,
	stains = false,
	edit_mode = false,
	curr_stain = false, -- stain being edited
	suspend_update = false,
}

function BaseObjectSDE:Done()
	self:OnEditorClose()
end

function BaseObjectSDE:ToggleEditMode()
	self.edit_mode = not self.edit_mode
	
	if self.edit_mode then
		-- find or create the edited stain
		for _, stain in ipairs(self.stains) do
			if stain.DecType == self.DecType and stain.Spot == self.Spot then
				self.curr_stain = stain
				break
			end
		end
		
		self.curr_stain = self.curr_stain or Unit.AddStain(self, self.DecType, self.Spot)		
		assert(self.curr_stain, "no stain was found or created, something is wrong")
		self:UpdateEditVisuals()
		self.suspend_update = true
		CopyUnitStainProperties(self.curr_stain, self)
		self.suspend_update = false
	else
		self:UpdateEditVisuals()
		self.curr_stain = false
	end
	
	ObjModified(self)
end

function BaseObjectSDE:UpdateCurrStain()
	if not self.curr_stain or self.suspend_update then return end
	
	if self.curr_stain.decal then
		DoneObject(self.curr_stain.decal)		
	end
	
	CopyUnitStainProperties(self, self.curr_stain)
	
	self.curr_stain:Apply(self)
	self:UpdateEditVisuals()
end

function BaseObjectSDE:RevertChanges()
	table.remove_value(self.stains, self.curr_stain)
	DoneObject(self.curr_stain)
	self.curr_stain = Unit.AddStain(self, self.DecType, self.Spot)
	self.suspend_update = true
	CopyUnitStainProperties(self.curr_stain, self)
	self.suspend_update = false
	ObjModified(self)
end

function BaseObjectSDE:UpdateEditVisuals()
	self:HideSpots()
	if self.edit_mode and self.ShowSpot then
		self:ShowSpots(self.Spot)
	end
	if self.curr_stain and self.curr_stain.decal then
		self.curr_stain.decal:ForEachAttach("Mesh", DoneObject)
		if self.edit_mode and self.ShowDecalBBox then
			local bbox = GetEntityBBox(self.curr_stain.DecEntity)
			local mesh = PlaceBox(bbox, const.clrWhite, nil, false)
			mesh:ClearMeshFlags(const.mfWorldSpace)
			self.curr_stain.decal:Attach(mesh)
		end
	end
end

function BaseObjectSDE:SetShowSpot(value)
	self.ShowSpot = value
	self:UpdateEditVisuals()
end
function BaseObjectSDE:SetShowDecalBBox(value)
	self.ShowDecalBBox = value
	self:UpdateEditVisuals()
end
function BaseObjectSDE:SetDecEntity(value)
	self.DecEntity = value
	self:UpdateCurrStain()
end
function BaseObjectSDE:SetDecOffsetX(value)
	self.DecOffsetX = value
	self:UpdateCurrStain()
end
function BaseObjectSDE:SetDecOffsetY(value)
	self.DecOffsetY = value
	self:UpdateCurrStain()
end
function BaseObjectSDE:SetDecOffsetZ(value)
	self.DecOffsetZ = value
	self:UpdateCurrStain()
end
function BaseObjectSDE:SetInvertFacing(value)
	self.InvertFacing = value
	self:UpdateCurrStain()
end
function BaseObjectSDE:SetDecAttachAxis(value)
	self.DecAttachAxis = value
	self:UpdateCurrStain()
end
function BaseObjectSDE:SetDecAttachAngleRange(value)
	self.DecAttachAngleRange = value
	if self.curr_stain then
		self.curr_stain.Rotation = -1
	end
	self:UpdateCurrStain()
end
function BaseObjectSDE:SetDecScale(value)
	self.DecScale = value
	self:UpdateCurrStain()
end
function BaseObjectSDE:SetClrMod(value)
	self.ClrMod = value
	self:UpdateCurrStain()
end

function BaseObjectSDE:OnEditorClose()
	DeleteThread(self.anim_thread)
end

function BaseObjectSDE:UpdateAnimRevision(anim)
	local anim_rev = EntitySpec:GetAnimRevision(self:GetEntity(), anim)
	if anim_rev then
		self:SetProperty("AnimRevision", anim_rev)
	end
end

function BaseObjectSDE:Setanim(anim)
	local old_frame, old_abs_duration = self.Frame, self:GetAbsoluteTime(self.anim_duration)
	local timeline = GetDialog("AnimMetadataEditorTimeline")
	if timeline then
		timeline:CreateMomentControls()
	end
	self:UpdateAnimRevision(anim)
	if self.anim_speed == 0 then
		if old_abs_duration == 0 then
			self:SetFrame(old_frame)
		else
			local new_abs_duration = self:GetAbsoluteTime(self.anim_duration)
			self:SetFrame(MulDivTrunc(new_abs_duration, old_frame, old_abs_duration))
		end
	end
	AnimationMomentsEditorBindObjects(self)
end

function BaseObjectSDE:GetInheritedEntity(anim)
	return GetAnimEntity(self:GetEntity(), GetStateIdx(anim or self:GetProperty("anim")))
end

function BaseObjectSDE:GetEntityAnimSpeed(anim)
	anim = anim or self:GetProperty("anim")

	local entity = self:GetInheritedEntity()
	local state_speed = entity and GetStateSpeedModifier(entity, GetStateIdx(anim)) or const.AnimSpeedScale
	return state_speed
end

function BaseObjectSDE:GetModifiedTime(absolute_time)
	return MulDivTrunc(absolute_time, const.AnimSpeedScale, self:GetEntityAnimSpeed())
end

function BaseObjectSDE:GetAbsoluteTime(modified_time)
	return MulDivTrunc(modified_time, self:GetEntityAnimSpeed(), const.AnimSpeedScale)
end

function BaseObjectSDE:SetFrame(frame, delayed_moments_binding)
	self.Frame = frame
	self.anim_speed = 0
	self:SetAnimHighLevel()
	UpdateTimeline()
	if delayed_moments_binding then
		DelayedBindMoments(self)
	end
end

function BaseObjectSDE:GetFrame()
	if self.anim_speed == 0 then
		return self:GetModifiedTime(self.Frame) 
	else
		return self.anim_duration - self:TimeToAnimEnd()
	end
end

function BaseObjectSDE:SetAnimLowLevel(resume)
	local anim = self:GetProperty("anim")
	local time, duration = self:SetAnimChannel(1, anim, self.animFlags, self.animCrossfade, self.animWeight, self.animBlendTime, resume)
	if self.anim2 ~= "" then
		local time2, duration2 = self:SetAnimChannel(2, self.anim2, self.anim2Flags, self.anim2Crossfade, 100 - self.animWeight, self.anim2BlendTime, resume)
		time = Max(time, time2)
		duration = Max(duration, duration2)
	end
	
	return time, duration
end

function BaseObjectSDE:AnimAdjustPos()
end

function BaseObjectSDE:SetAnimHighLevel(resume)
	local time, duration = self:SetAnimLowLevel(resume)
	time = Max(time, 1)
	self.anim_duration = duration
	UpdateTimelineDuration(duration)
	local dlg = GetDialog("AnimMetadataEditorTimeline")
	if dlg then
		dlg.idAnimationName:SetText(self.anim)
	end
	if IsValidThread(self.anim_thread) then
		DeleteThread(self.anim_thread)
		self.anim_thread = nil
	end
	self.anim_thread = CreateRealTimeThread(function()
		local moments = self:GetAnimMoments()
		while IsValid(self) and IsValidEntity(self:GetEntity()) do
			self:AnimAdjustPos(time)
			local dt, moment_index = 0, 1
			local moment, time_to_moment, moment_descr = self:TimeToNextMoment(1, moment_index)
			while IsValid(self) and dt < time do
				Sleep(1)
				UpdateTimeline()
				dt = dt + 1
				if time_to_moment then
					time_to_moment = time_to_moment - 1
					if time_to_moment <= 0 then
						PlayFX(moment_descr.FX, moment, moment_descr.Actor or self)
						moment_index = moment_index + 1
						moment, time_to_moment, moment_descr = self:TimeToNextMoment(1, moment_index)
					end
				end
			end
			if not IsValid(self) then return end
			if not self.loop_anim then
				-- if not looped anim - freeze at the last frame
				if self.anim_speed > 0 then
					self.Frame = self.anim_duration - 1
					self.anim_speed = 0
					self:SetAnimLowLevel()
				end
				while IsValid(self) and not self.loop_anim do
					Sleep(20)
				end
				if not IsValid(self) then return end
			end
			time, self.anim_duration = self:SetAnimLowLevel()
			time = Max(time, 1)
			UpdateTimelineDuration(self.anim_duration)
		end
	end)
end

function BaseObjectSDE:GetAnimPreset()
	local anim = self:GetProperty("anim")
	local entity = self:GetInheritedEntity(anim)
	local preset_group = Presets.AnimMetadata[entity] or empty_table
	return preset_group[anim] or empty_table
end

function BaseObjectSDE:GetAnimMoments()
	local preset_anim = self:GetAnimPreset()
	
	return preset_anim.Moments or empty_table
end

function BaseObjectSDE:GetStepCompensation()
	return self.DisableCompensation and point30 or self:GetStepVector()
end

function BaseObjectSDE:OnAnimChanged(anim, old_anim)
end

function BaseObjectSDE:ChangeAnim(anim, old_anim)
	if self.anim_speed == 0 then
		local old_duration = Max(GetAnimDuration(self:GetEntity(), old_anim), 1)
		if not self.loop_anim and self.Frame == old_duration - 1 then
			self.anim_speed = 1000
			self:Setanim(anim)
		else
			self:SetFrame(self.anim_duration * self.Frame / old_duration)
		end
	end	
	self:OnAnimChanged(anim, old_anim)
end

function BaseObjectSDE:TransferToPreset()
	local base_entity = GetAnimEntity(self:GetEntity(), self:GetState())
	local id = UnitStainPresetName(base_entity, self.DecType, self.Spot)
	
	local preset_group = Presets.SkinDecalMetadata.Default	
	local preset = preset_group and preset_group[id]
	if not preset then 
		preset = SkinDecalMetadata:new{id = id}
		preset:Register()
	end
	CopyUnitStainProperties(self, preset)	
	preset:Save(true)
	ObjModified(preset)
		
	return preset
end

function BaseObjectSDE:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "anim" then
		local anim = self:GetProperty("anim")
		self:ChangeAnim(anim, old_value)
		LocalStorage.AME_LastAnim = anim
		SaveLocalStorage()
	elseif prop_id == "Appearance" then
		LocalStorage.AME_LastAppearance = self:GetProperty("Appearance")
		SaveLocalStorage()
	end
end

-- this class is only for the Skin Decal Editor purposes
DefineClass.AppearanceObjectSDE = {
	__parents = { "AppearanceObject", "StripObjectProperties", "BaseObjectSDE" },
	flags = { gofRealTimeAnim = true },
	
	properties = {
		{ category = "Animation", id = "Appearance", name = "Entity/Appearance", editor = "dropdownlist",
		  items = AllAppearancesComboItems, default = GetAllAnimatedEntities()[1],
		  read_only = function(self) return self.edit_mode end,
		  buttons = {{name = "Edit", func = function(self, root, prop_id, ged)
				local appearance = self.Appearance
				local preset = AppearancePresets[appearance] or EntitySpecPresets[appearance]
				if preset then
					preset:OpenEditor()
				end
		  end}},
		},
		{ category = "Animation", id = "anim", name = "Animation", editor = "dropdownlist", items = ValidAnimationsCombo, default = "idle",
			read_only = function(self) return self.edit_mode end,
		},

		{ id = "animWeight" },
		{ id = "animBlendTime" },
		{ id = "anim2" },
		{ id = "anim2BlendTime" },
		
		{ id = "DetailClass" },
	},
	
	init_pos = false,
}

function AppearanceObjectSDE:Setanim(anim)
	if anim:sub(-1, -1) == "*" then return end
	
	anim = IsValidAnim(self, anim) and anim or "idle"
	AppearanceObject.Setanim(self, anim)
	BaseObjectAME.Setanim(self, anim)
end

function AppearanceObjectSDE:SetAnimHighLevel(...)
	return BaseObjectAME.SetAnimHighLevel(self, ...)
end

function AppearanceObjectSDE:SetAnimLowLevel(...)
	return BaseObjectAME.SetAnimLowLevel(self, ...)
end

function AppearanceObjectSDE:GetAnimMoments(...)
	return BaseObjectAME.GetAnimMoments(self, ...)
end

function AppearanceObjectSDE:ApplyAppearance(appearance)
	appearance = appearance or LocalStorage.AME_LastAppearance or self.Appearance
	
	local preset_appearance = AppearancePresets[appearance]
	if preset_appearance then
		local copy =  preset_appearance:Clone("Appearance")
		copy.id = preset_appearance.id
		AppearanceObject.ApplyAppearance(self, copy)
	else
		appearance = IsValidEntity(appearance) and appearance or GetAllAnimatedEntities()[1]
		local entity_appearance = Appearance:new{id = appearance, Body = appearance}
		AppearanceObject.ApplyAppearance(self, entity_appearance)
	end
	--self:SetSpot(self.Spot)
	ObjModified(self)
end

function AppearanceObjectSDE:AnimAdjustPos(time)
	if self.anim_speed > 0 then
		local step = self:GetStepCompensation()
		self:SetPos(self.init_pos)
		local pos = terrain.ClampPoint(self.init_pos + step)
		self:SetPos(pos, time)
	else
		local frame_step = self:GetStepVector(self:GetAnim(), self:GetAngle(), 0, self.Frame)
		self:SetPos(self.init_pos + frame_step)
	end
end

function AppearanceObjectSDE:SetAnimChannel(channel, anim, anim_flags, crossfade, weight, blend_time, resume)
	AppearanceObject.SetAnimChannel(self, channel, anim, anim_flags, crossfade, weight, blend_time)
	
	local frame = self.Frame
	if resume then
		self:SetAnimPhase(channel, frame)
		for _, part_name in ipairs(self.animated_parts) do
			local part = self.parts[part_name]
			if part then
				if resume then
					part:SetAnimPhase(channel, frame)
				end
			end
		end
		self.Frame = 0
	end
	
	if self.anim_speed == 0 then
		self:SetAnimPhase(channel, frame)
		for _, part_name in ipairs(self.animated_parts) do
			local part = self.parts[part_name]
			if part then
				part:SetAnimPhase(channel, frame)
			end
		end
	end
	
	local duration = GetAnimDuration(self:GetEntity(), self:GetAnim(channel))
	
	return duration - (resume and frame or 0), duration
end

function AppearanceObjectSDE:GetSize()
	local bbox = self:GetEntityBBox()
	if self.parts then
		for _, part_name in ipairs(self.attached_parts) do
			local part = self.parts[part_name]
			if part then
				local part_bbox = part:GetEntityBBox()
				bbox = Extend(bbox, part_bbox:min())
				bbox = Extend(bbox, part_bbox:max())
			end
		end
	end
	return bbox
end

function AppearanceObjectSDE:OnEditorSetProperty(prop_id, old_value, ged)
	BaseObjectAME.OnEditorSetProperty(self, prop_id, old_value, ged)
	if prop_id == "Appearance" then
		self:ApplyAppearance()
	else
		AppearanceObject.OnEditorSetProperty(self, prop_id, old_value, ged)
	end
end

function AppearanceObjectSDE:OnEditorOpen(editor)
	BaseObjectAME.OnEditorOpen(self, editor)
	GedOpCharacterCamThreeQuarters(editor, self)
	local last_anim = LocalStorage.AME_LastAnim
	self:SetProperty("anim", last_anim and IsValidAnim(self, last_anim) and last_anim or "idle")
end

function AppearanceObjectSDE:OnEditorClose()
	BaseObjectAME.OnEditorClose(self)
	if cameraMax.IsActive() then
		cameraTac.Activate(1)
	end
end

----

DefineClass.SelectionObjectSDE = {
	__parents = { "BaseObjectSDE", "StripObjectProperties" },
	
	properties = {
		{ id = "animWeight" },
		{ id = "animBlendTime" },
		{ id = "anim2" },
		{ id = "anim2BlendTime" },
	},
	obj = false,
	animFlags  = 0,
	animCrossfade = 0,
	anim2Flags = 0,
	anim2Crossfade = 0,
	anim_speed = 1000,
}

function SelectionObjectSDE:Getanim()
	return IsValid(self.obj) and self.obj:GetStateText() or ""
end

function SelectionObjectSDE:GetStepVector(...)
	return IsValid(self.obj) and self.obj:GetStepVector(...) or point30
end

function SelectionObjectSDE:GetLooping()
	return IsValid(self.obj) and self.obj:IsAnimLooping() or false
end

function SelectionObjectSDE:GetAnimDuration()
	return IsValid(self.obj) and self.obj:GetAnimDuration() or point30
end

function SelectionObjectSDE:Setanim(anim)
	if IsValid(self.obj) then
		self.obj:SetStateText(anim)
		BaseObjectAME.Setanim(self, anim)
	end
end

function SelectionObjectSDE:GetEntity()
	return IsValid(self.obj) and self.obj:GetEntity() or ""
end

function SelectionObjectSDE:OnEditorOpen(editor)
	BaseObjectAME.OnEditorOpen(self, editor)
	self:UpdateSelectedObj()
end

function SelectionObjectSDE:SetSelectedObj(obj)
	local prev_obj = self.obj
	if IsValid(prev_obj) then
		prev_obj:ClearGameFlags(const.gofRealTimeAnim)
		self:Detach()
	end
	self.obj = obj
	if obj then
		obj:Attach(self)
		obj:SetGameFlags(const.gofRealTimeAnim)
	end
end

function SelectionObjectSDE:UpdateSelectedObj()
	local obj = self.obj
	if not IsValid(obj) then
		return
	end
	local anim = obj:GetStateText()
	BaseObjectAME.Setanim(self, anim)
	self.Frame = obj:GetAnimPhase(1)
end

function SelectionObjectSDE:OnEditorClose()
	BaseObjectAME.OnEditorClose(self)
	self:SetSelectedObj(false)
end

function SelectionObjectSDE:SetAnimChannel(channel, anim, anim_flags, crossfade, weight, blend_time, resume)
	local obj = self.obj
	if not IsValid(obj) then
		return 0, 0
	end
	
	obj:SetAnim(channel, anim, anim_flags, crossfade)
	obj:SetAnimWeight(channel, 100)
	obj:SetAnimWeight(channel, weight, blend_time)
	obj:SetAnimSpeed(channel, self.anim_speed)
	
	local frame = self.Frame
	if resume then
		obj:SetAnimPhase(channel, frame)
		self.Frame = 0
	end
	if self.anim_speed == 0 then
		obj:SetAnimPhase(channel, frame)
	end
	
	local duration = GetAnimDuration(obj:GetEntity(), obj:GetAnim(channel))
	return duration - (resume and frame or 0), duration
end

function SelectionObjectSDE:GetSize()
	return IsValid(self.obj) and ObjectHierarchyBBox(self.obj) or box()
end

function SelectionObjectSDE:GetAnimPhase(...)
	return IsValid(self.obj) and self.obj:GetAnimPhase(...) or 0
end

function SelectionObjectSDE:GetStatesTextTable(...)
	return IsValid(self.obj) and self.obj:GetStatesTextTable(...) or {}
end

function SelectionObjectSDE:TimeToAnimEnd(...)
	return IsValid(self.obj) and self.obj:TimeToAnimEnd(...) or 0
end

----

function GetSkinDecalEditorObject()
	return SkinDecalEditor and SkinDecalEditor.bound_objects["root"]
end

function OpenSkinDecalEditor(target, animation)
	local mode = IsValid(target) and "selection" or "appearance"
	
	if mode == "appearance" and animation then
		target = AppearanceLocateByAnimation(animation, target)
		if not target then return end
	end
	
	CreateRealTimeThread(function()
		SkinDecalEditorMode = mode
		local obj
		if mode == "appearance" then
			local pos, dir = camera.GetEye(), camera.GetDirection()
			local pos = terrain.IntersectRay(pos, pos + dir) or pos:SetTerrainZ()
			obj = AppearanceObjectSDE:new{init_pos = pos}
			obj:ApplyAppearance(target)
			obj:SetPos(pos)
			obj:SetGameFlags(const.gofRealTimeAnim)
		else
			obj = SelectionObjectSDE:new()
			obj:SetSelectedObj(target)
		end
		if not SkinDecalEditor then
			SkinDecalEditor = OpenGedApp("SkinDecalEditor", obj, { PresetClass = "SkinDecalMetadata" }) or false			
		else
			local old = GetSkinDecalEditorObject()
			SkinDecalEditor:BindObj("root", obj)
			DoneObject(old)
		end
		SkinDecalEditor:BindObj("SkinDecals", Presets.SkinDecalMetadata)

		obj:OnEditorOpen(SkinDecalEditor)
		if mode == "appearance" or animation then
			obj:Setanim(animation or "idle")
		end
	end)
	return true
end

function GedOpOpenSkinDecalEditor(socket, character)
	OpenSkinDecalEditor(character.Appearance)
end

function CloseSkinDecalEditor()
	if SkinDecalEditor then
		SkinDecalEditor:Send("rfnApp", "Exit")
	end
end

function OnMsg.GedClosing(ged_id)
	if SkinDecalEditor and SkinDecalEditor.ged_id == ged_id then
		local character = GetSkinDecalEditorObject()
		if IsValid(character) then
			DoneObject(character)
		end
		SkinDecalEditorMode = false
		SkinDecalEditor = false
	end	
end

local function EditorSelectionChanged()
	if SkinDecalEditor and SkinDecalEditorMode == "selection" then
		local sel_obj = editor.GetSel()[1]
		local character = GetSkinDecalEditorObject()
		if not IsValid(sel_obj) or not character then
			CloseSkinDecalEditor()
		else
			character:SetSelectedObj(sel_obj)
			character:UpdateSelectedObj()
		end
	end
end

function OnMsg.EditorSelectionChanged(objects)
	if SkinDecalEditor and SkinDecalEditorMode == "selection" then
		DelayedCall(0, EditorSelectionChanged)
	end
end

OnMsg.ChangeMapDone = CloseSkinDecalEditor

function ReloadSkinDecals()
	SkinDecals = {}
	ForEachPreset("SkinDecalMetadata", function(preset, group)
		local by_entity = SkinDecals[preset.group] or {}
		SkinDecals[preset.group] = by_entity
		local by_type = by_entity[preset.DecType] or {}
		by_entity[preset.DecType] = by_type
		by_type[preset.Spot] = preset
	end)
end
OnMsg.DataLoaded = ReloadSkinDecals