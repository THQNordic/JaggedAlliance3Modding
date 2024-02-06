local function WipeDeleted()
	local to_delete = {}
	ForEachPreset("AnimMetadata", function(preset)
		local entity, anim = preset.group, preset.id
		if not (IsValidEntity(entity) and HasState(entity, anim)) then
			to_delete[#to_delete + 1] = preset
		end
	end)
	for _, preset in ipairs(to_delete) do
		preset:delete()
	end
end

DefineClass.AnimMoment = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Type", name = "Type", editor = "choice", default = "Moment", items = ActionMomentNamesCombo },
		{ id = "Time", name = "Time (ms)", editor = "number", default = 0 },
		{ id = "FX", name = "FX", editor = "choice", default = false, items = ActionFXClassCombo },
		{ id = "Actor", name = "Actor", editor = "choice", default = false, items = ActorFXClassCombo },
		{ id = "AnimRevision", name = "Animation Revision", editor = "number", default = 0, read_only = true },
		{ id = "Reconfirm", editor = "buttons", default = false,
			no_edit = function(obj) return not (obj:GetWarning() or obj:GetError()) end,
			buttons = { { name = "Reconfirm", func = function(self, root, prop_id, ged)
				self.AnimRevision = GetAnimationMomentsEditorObject().AnimRevision
				ObjModified(self)
				ObjModified(ged:ResolveObj("AnimationMetadata"))
				ObjModified(ged:ResolveObj("Animations"))
			end,
		} } },
	},
}

function AnimMoment:GetEditorView()
	if GetParentTableOfKind(self, "AnimMetadata").SpeedModifier ~= 100 then
		local character = GetAnimationMomentsEditorObject()
		return T{Untranslated("<Type> at <Time>ms(mod <ModTime>ms)"),
			Type = self.Type, Time = self.Time, ModTime = character:GetModifiedTime(self.Time)}
	else
		return Untranslated("<Type> at <Time>ms", self)
	end
end

function AnimMoment:GetError()
	local parent = GetParentTableOfKind(self, "AnimMetadata")
--	local anim_revision = EntitySpec:GetAnimRevision(parent.group, parent.id)
--	if anim_revision and self.AnimRevision < anim_revision thenbash
--		return string.format("The animation changed in revision %d, but the moment was set back in revision %d.\nReadjust or click the button below to reconfirm.", anim_revision, self.AnimRevision)
--	end
	
	if self.Time > GetAnimDuration(parent.group, parent.id) then
		return "Action moment's time is beyond the animation duration."
	end
end

function AnimMoment:OnAfterEditorNew()
	local parent = GetParentTableOfKind(self, "AnimMetadata")
	self.AnimRevision = EntitySpec:GetAnimRevision(parent.group, parent.id)
end

function GetAllAnimatedEntities(exclude)
	local entities = GetAllEntities()
	local animated_entities = {}
	for entity in pairs(entities) do
		if CObject.IsAnimated(entity) then
			table.insert(animated_entities, entity)
		end
	end
	table.remove_value(animated_entities, "ErrorAnimatedMesh")
	if exclude then
		animated_entities = table.subtraction(animated_entities, ClassLeafDescendantsList(exclude))
	end
	table.sort(animated_entities)

	return animated_entities
end

function AllAppearancesComboItems()
	local list = PresetsCombo("AppearancePreset")()
	table.insert(list, 1, "Appearance Presets:")
	table.insert(list, 2, "------------------")
	
	table.insert(list, "")
	table.insert(list, "Animated Entities:")
	table.insert(list, "------------------")
	
	table.iappend(list, GetAllAnimatedEntities("CharacterEntity"))
	
	return list
end

MapVar("s_DelayedBindMomentsThread", false)

function DelayedBindMoments(obj)
	DeleteThread(s_DelayedBindMomentsThread)
	s_DelayedBindMomentsThread = CreateMapRealTimeThread(function()
		Sleep(500)
		AnimationMomentsEditorBindObjects(obj)
		s_DelayedBindMomentsThread = false
	end)
end

-- this class is only for the Anim Metadata Editor purposes
DefineClass.BaseObjectAME = {
	__parents = { "Object" },

	properties = {
		{ category = "Animation", id = "AnimRevision", name = "Animation Revision", editor = "number", default = 0, read_only = true },
		{ category = "Animation", id = "SpeedModifier", name = "Speed Modifier", editor = "number" , slider = true , min = 10, max = 1000, default = 100},
		{ category = "Animation", id = "StepModifier", name = "Step Modifier", editor = "number" , slider = true , min = 10, max = 1000, default = 100},
		{ category = "Animation", id = "StepDelta", name = "Step Delta", editor = "point" , default = point30, read_only = true},
		{ category = "Animation", id = "DisableCompensation", name = "Disable Compensation", editor = "bool" , default = false, dont_save = true},
		{ category = "Animation", id = "VariationWeight", name = "Variation Weight", editor = "number" , default = 100},
		{ category = "Animation", id = "button1", editor = "buttons" , default = false, dont_save = true, read_only = true, sort_order = 2,
		  buttons = {
			{
				name = "Save", func = function(self, root, prop_id, ged)
					local preset = self:TransferToPreset()
					if preset then
						preset:Save("user request")
					end
				end,
				is_hidden = function(self, prop_meta) return self:GetAnimPreset() == empty_table end,
			}, {
				name = "New", func = function(self, root, prop_id, ged)
					if self:GetAnimPreset() ~= empty_table then
						return
					end
					WipeDeleted()
					local character = GetAnimationMomentsEditorObject()
					local _, _, preset = GetOrCreateAnimMetadata(character)
					preset:Save()
					AnimationMomentsEditorBindObjects(character)
					ged:SetSelection("Animations", PresetGetPath(preset))
				end,
				is_hidden = function(self, prop_meta) return self:GetAnimPreset() ~= empty_table end,
			}, {
				name = "Delete", func = function(self, root, prop_id, ged)
					local character = GetAnimationMomentsEditorObject()
					local _, _, preset = GetOrCreateAnimMetadata(character)
					preset:delete()
					WipeDeleted()
					AnimationMomentsEditorBindObjects(character)
					ObjModified(Presets.AnimMetadata)
				end,
				is_hidden = function(self, prop_meta) return self:GetAnimPreset() == empty_table end,
			}, {
				name = "Reconfirm", func = function(self, root, prop_id, ged)
					SuspendObjModified("ReconfirmMoments")
					local character = GetAnimationMomentsEditorObject()
					local _, _, preset = GetOrCreateAnimMetadata(character)
					preset:ReconfirmMoments(root, prop_id, ged)
					ResumeObjModified("ReconfirmMoments")
				end,
				is_hidden = function(self, prop_meta) return self:GetAnimPreset() == empty_table end,
			}, {
				name = "Reconfirm All", func = function(self, root, prop_id, ged)
					SuspendObjModified("ReconfirmMoments")
					local character = GetAnimationMomentsEditorObject()
					local entity = character:GetInheritedEntity()
					for _, preset in ipairs(Presets.AnimMetadata[entity]) do
						local anim = preset.id
						local revision = EntitySpec:GetAnimRevision(entity, anim)
						for _, moment in ipairs(preset.Moments or empty_table) do
							if moment.AnimRevision ~= revision then
								moment.AnimRevision = revision
								ObjModified(moment)
							end
						end
						ObjModified(preset)
						ObjModified(ged:ResolveObj("Animations"))
					end
					ResumeObjModified("ReconfirmMoments")
				end
			}, {
				name = "Wipe Out Deleted", func = function(self, root, prop_id, ged)
					SuspendObjModified("ReconfirmMoments")
					WipeDeleted()
					AnimMetadata:SaveAll("save all", "user request")
					ResumeObjModified("ReconfirmMoments")
				end},
			},
		},
		{ category = "FX", id = "FXInherits", name = "FX Inherits", editor = "string_list" , 
			default = empty_table, items = function(self)
				return ValidAnimationsCombo(self)
			end,
		},
	},

	Frame = 0,
	anim_thread = false,
	anim_duration = 0,
	loop_anim = true,
	preview_speed = 100,
}

function BaseObjectAME:Done()
	self:OnEditorClose()
end

function BaseObjectAME:OnEditorOpen(editor)
end

function BaseObjectAME:OnEditorClose()
	DeleteThread(self.anim_thread)
	--self:RevertPreviewSpeed(nil, "from preset")
	--AnimMetadataEditorTimelineSelectedControl = false
end

function BaseObjectAME:UpdateAnimRevision(anim)
	local anim_rev = EntitySpec:GetAnimRevision(self:GetEntity(), anim)
	if anim_rev then
		self:SetProperty("AnimRevision", anim_rev)
	end
end

function BaseObjectAME:Setanim(anim)
	local old_frame, old_duration = self.Frame, self.anim_duration
	local timeline = GetDialog("AnimMetadataEditorTimeline")
	if timeline then
		timeline:CreateMomentControls()
	end
	self:UpdateAnimRevision(anim)
	if self.anim_speed == 0 then
		if old_duration == 0 then
			self:SetFrame(old_frame)
		else
			self:SetFrame(MulDivTrunc(self.anim_duration, old_frame, old_duration))
		end
	end
	AnimationMomentsEditorBindObjects(self)
end

function BaseObjectAME:GetInheritedEntity(anim)
	return GetAnimEntity(self:GetEntity(), GetStateIdx(anim or self:GetProperty("anim")))
end

function BaseObjectAME:GetEntityAnimSpeed(anim)
	anim = anim or self:GetProperty("anim")

	local entity = self:GetInheritedEntity()
	local state_speed = entity and GetStateSpeedModifier(entity, GetStateIdx(anim)) or const.AnimSpeedScale
	return state_speed
end

function BaseObjectAME:GetModifiedTime(absolute_time)
	return MulDivTrunc(absolute_time, const.AnimSpeedScale, self:GetEntityAnimSpeed())
end

function BaseObjectAME:GetAbsoluteTime(modified_time)
	return MulDivTrunc(modified_time, self:GetEntityAnimSpeed(), const.AnimSpeedScale)
end

function BaseObjectAME:SetFrame(frame, delayed_moments_binding)
	self.Frame = frame
	self.anim_speed = 0
	self:SetAnimHighLevel()
	UpdateTimeline()
	if delayed_moments_binding then
		DelayedBindMoments(self)
	end
end

function BaseObjectAME:GetFrame()
	if self.anim_speed == 0 then
		return self.Frame
	else
		return self.anim_duration - self:TimeToAnimEnd()
	end
end

function BaseObjectAME:SetAnimLowLevel(resume)
	local anim = self:GetProperty("anim")
	local time, duration = self:SetAnimChannel(1, anim, self.animFlags, self.animCrossfade, self.animWeight, self.animBlendTime, resume)
	if self.anim2 ~= "" then
		local time2, duration2 = self:SetAnimChannel(2, self.anim2, self.anim2Flags, self.anim2Crossfade, 100 - self.animWeight, self.anim2BlendTime, resume)
		time = Max(time, time2)
		duration = Max(duration, duration2)
	end
	
	return time, duration
end

function BaseObjectAME:AnimAdjustPos()
end

function BaseObjectAME:SetAnimHighLevel(resume)
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
		local metadata = self:GetAnimPreset()
		while IsValid(self) and IsValidEntity(self:GetEntity()) do
			self:AnimAdjustPos(time)
			local dt, last_moment_time = 0, 0
			local anim_obj = rawget(self, "obj") or self
			local moment, time_to_moment = anim_obj:TimeToNextMoment(1, 1)
			while IsValid(self) and dt < time do
				Sleep(1)
				UpdateTimeline()
				dt = dt + 1
				if time_to_moment and self:GetAnimPhase(1) > last_moment_time + time_to_moment then
					local action, actor, target = GetProperty(metadata, "Action"), GetProperty(metadata, "Actor"), GetProperty(metadata, "Target")
					anim_obj.fx_actor_class = actor
					PlayFX(action or FXAnimToAction(metadata.id), moment, anim_obj, target)
					moment, time_to_moment = anim_obj:TimeToNextMoment(1, 1)
					last_moment_time = self:GetAnimPhase(1)
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

function BaseObjectAME:GetAnimPreset()
	local anim = self:GetProperty("anim")
	local entity = self:GetInheritedEntity(anim)
	local preset_group = Presets.AnimMetadata[entity] or empty_table
	return preset_group[anim] or empty_table
end

function BaseObjectAME:GetAnimMoments()
	local preset_anim = self:GetAnimPreset()
	
	return preset_anim.Moments or empty_table
end

function BaseObjectAME:UpdateAnimMetadataSelection()
	local anim = self:GetProperty("anim")
	local inherited_entity = self:GetInheritedEntity(anim)
	local group = Presets.AnimMetadata or {}
	local group_idx = table.find(group, group[inherited_entity])
	local item_idx = group_idx and table.find(group[group_idx], "id", anim)
	if group_idx and item_idx then
		AnimationMomentsEditor:SetSelection("Animations", {group_idx, item_idx})
	end
end

function BaseObjectAME:SetPreviewSpeed(speed)
	self.preview_speed = speed
	local anim = self:GetProperty("anim")
	local modifier = MulDivTrunc(self.SpeedModifier * self.preview_speed, const.AnimSpeedScale, 100 * 100)
	SetStateSpeedModifier(self:GetEntity(), GetStateIdx(anim), modifier)
	self:SetAnimHighLevel()
end

function BaseObjectAME:RevertPreviewSpeed(anim, from_preset)
	anim = anim or self:GetProperty("anim")
	
	local entity = self:GetInheritedEntity()
	local old_anim_speed_modifier
	if from_preset then
		local preset = self:GetAnimPreset()
		old_anim_speed_modifier = MulDivTrunc(1000, preset.SpeedModifier or 100, 100)
	else
		old_anim_speed_modifier = GetStateSpeedModifier(entity, GetStateIdx(anim))
		old_anim_speed_modifier = MulDivTrunc(old_anim_speed_modifier, 100, self.preview_speed)
	end
	SetStateSpeedModifier(entity, GetStateIdx(anim), old_anim_speed_modifier)
end

function BaseObjectAME:ApplyPreviewSpeed(anim)
	local anim1 = self:GetProperty("anim")
	anim = anim or anim1
	
	local entity = self:GetInheritedEntity()
	local state_speed = GetStateSpeedModifier(entity, GetStateIdx(anim))
	self.SpeedModifier = MulDivTrunc(state_speed, 100, const.AnimSpeedScale)
	self.StepModifier = GetStateStepModifier(entity, GetStateIdx(anim1))
	self:SetPreviewSpeed(self.preview_speed)
end

function BaseObjectAME:GetStepCompensation()
	return self.DisableCompensation and point30 or self:GetStepVector()
end

function BaseObjectAME:OnAnimChanged(anim, old_anim)
	self:RevertPreviewSpeed(old_anim)
	self:ApplyPreviewSpeed(anim)
	self:SetProperty("StepDelta", self:GetStepVector())
	local preset = self:GetAnimPreset()
	self:SetProperty("FXInherits", preset.FXInherits)
end

function BaseObjectAME:ChangeAnim(anim, old_anim)
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
	self:UpdateAnimMetadataSelection()
end

function BaseObjectAME:TransferToPreset()
	local preset = self:GetAnimPreset()
	if preset == empty_table then
		if not IsRealTimeThread() then
			CreateRealTimeThread(function()
				WaitMessage(terminal.desktop,
					T(313839116468, "No Anim Metata"),
					T(857146618172, "Use 'New Animation Metadata' button first"),
					T(1000136, "OK")
				)
			end)
		end
		return
	end
	WipeDeleted()
	
	local character = GetAnimationMomentsEditorObject()
	preset.SpeedModifier = character.SpeedModifier
	preset.StepModifier = character.StepModifier
	preset.VariationWeight = character.VariationWeight
	preset.FXInherits = character.FXInherits
	ObjModified(preset)
	
	return preset
end

function BaseObjectAME:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "anim" then
		local anim = self:GetProperty("anim")
		self:ChangeAnim(anim, old_value)
		LocalStorage.AME_LastAnim = anim
		SaveLocalStorage()
	elseif prop_id == "Appearance" then
		LocalStorage.AME_LastAppearance = self:GetProperty("Appearance")
		SaveLocalStorage()
	elseif prop_id == "SpeedModifier" then
		self:TransferToPreset()
		self:SetPreviewSpeed(self.preview_speed)
	elseif prop_id == "StepModifier" then
		self:TransferToPreset()
		SetStateStepModifier(self:GetEntity(), GetStateIdx(self:GetProperty("anim")), self.StepModifier)
	elseif prop_id == "Time" or prop_id == "Type" or prop_id == "VariationWeight" then
		local character = GetAnimationMomentsEditorObject()
		self.AnimRevision = character.AnimRevision
		AnimationMomentsEditorBindObjects(character)
	end
end

function FormatTimeline(frame, precision)
	local character = GetAnimationMomentsEditorObject()
	local absolute_frame = MulDivTrunc(frame, character.preview_speed, 100)
	precision = precision or 1
	if precision == 1 then
		return string.format("%.1fs", absolute_frame / 1000.0)
	elseif precision == 2 then
		return string.format("%.2fs", absolute_frame / 1000.0)
	else
		return string.format("%.3fs", absolute_frame / 1000.0)
	end
end

function UpdateTimeline()
	local timeline = GetDialog("AnimMetadataEditorTimeline")
	if timeline then
		timeline:Invalidate()
	end
end

function UpdateTimelineDuration(time)
	local timeline = GetDialog("AnimMetadataEditorTimeline")
	if timeline then
		timeline.idDuration:SetText(FormatTimeline(time, 3))
	end
end

----

-- this class is only for the Anim Metadata Editor purposes
DefineClass.AppearanceObjectAME = {
	__parents = { "AppearanceObject", "StripObjectProperties", "BaseObjectAME" },
	flags = { gofRealTimeAnim = true, },
	
	properties = {
		{ category = "Animation", id = "Appearance", name = "Entity/Appearance", editor = "dropdownlist",
		  items = AllAppearancesComboItems, default = GetAllAnimatedEntities()[1],
		  buttons = {{name = "Edit", func = function(self, root, prop_id, ged)
				local appearance = self.Appearance
				local preset = AppearancePresets[appearance] or EntitySpecPresets[appearance]
				if preset then
					preset:OpenEditor()
				end
		  end}},
		},
		{ id = "DetailClass" },
	},
	
	init_pos = false,
}

function AppearanceObjectAME:Setanim(anim)
	if anim:sub(-1, -1) == "*" then return end
	
	anim = IsValidAnim(self, anim) and anim or "idle"
	AppearanceObject.Setanim(self, anim)
	BaseObjectAME.Setanim(self, anim)
end

function AppearanceObjectAME:SetAnimHighLevel(...)
	return BaseObjectAME.SetAnimHighLevel(self, ...)
end

function AppearanceObjectAME:SetAnimLowLevel(...)
	return BaseObjectAME.SetAnimLowLevel(self, ...)
end

function AppearanceObjectAME:GetAnimMoments(...)
	return BaseObjectAME.GetAnimMoments(self, ...)
end

function AppearanceObjectAME:ApplyAppearance(appearance)
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
end

function AppearanceObjectAME:AnimAdjustPos(time)
	if self.anim_speed > 0 then
		local step = self:GetStepCompensation()
		self:SetPos(self.init_pos)
		local pos = terrain.ClampPoint(self.init_pos + step)
		self:SetPos(pos, time)
	else
		local frame_step = self:GetStepVector(self:GetAnim(), self:GetAngle(), 0, self:GetAbsoluteTime(self.Frame))
		self:SetPos(self.init_pos + frame_step)
	end
end

function AppearanceObjectAME:SetAnimChannel(channel, anim, anim_flags, crossfade, weight, blend_time, resume)
	AppearanceObject.SetAnimChannel(self, channel, anim, anim_flags, crossfade, weight, blend_time)
	
	local frame = self.Frame
	if resume or self.anim_speed == 0 then
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

function AppearanceObjectAME:GetSize()
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

function AppearanceObjectAME:OnEditorSetProperty(prop_id, old_value, ged)
	BaseObjectAME.OnEditorSetProperty(self, prop_id, old_value, ged)
	if prop_id == "Appearance" then
		self:RevertPreviewSpeed()
		self:ApplyAppearance()
		self:ApplyPreviewSpeed()
	else
		AppearanceObject.OnEditorSetProperty(self, prop_id, old_value, ged)
	end
end

function AppearanceObjectAME:OnAnimMetadataSelect(obj)
	local entity, anim = obj.group, obj.id
	if obj.group ~= self:GetInheritedEntity(anim) then
		self:ApplyAppearance(entity)
	end
	local old_anim = self:GetProperty("anim")
	self:SetProperty("anim", anim)
	self:OnAnimChanged(anim, old_anim)
end

if FirstLoad then
	AnimationMetadataEditorsStoredCamera = false
end

function AppearanceObjectAME:OnEditorOpen(editor)
	AnimationMetadataEditorsStoredCamera = {GetCamera()}
	BaseObjectAME.OnEditorOpen(self, editor)
	GedOpCharacterCamThreeQuarters(editor, self)
	local last_anim = LocalStorage.AME_LastAnim
	self:SetProperty("anim", last_anim and IsValidAnim(self, last_anim) and last_anim or "idle")
end

function AppearanceObjectAME:OnEditorClose()
	BaseObjectAME.OnEditorClose(self)
	SetCamera(unpack_params(AnimationMetadataEditorsStoredCamera))
end

function GetOrCreateAnimMetadata(obj)
	local entity = obj:GetInheritedEntity()
	local anim = obj:GetProperty("anim")
	
	local group = Presets.AnimMetadata[entity]
	local preset = group and group[anim]
	if not preset then
		preset = AnimMetadata:new{ group = entity, id = anim }
		preset:OnEditorNew(Presets.AnimMetadata, AnimationMomentsEditor)
	end
	return entity, anim, preset, group
end

----

DefineClass.SelectionObjectAME = {
	__parents = { "BaseObjectAME", "StripObjectProperties" },
	
	properties = {
		{ category = "Animation", id = "InheritedEntity", name = "Anim Entity", editor = "text", default = "", read_only = true },
		{ category = "Animation", id = "anim", name = "Animation", editor = "dropdownlist", items = ValidAnimationsCombo, default = "idle" },
		{ category = "Animation", id = "animWeight", name = "Animation Weight", editor = "number", slider = true, min = 0, max = 100, default = 100, help = "100 means only Animation is played, 0 means only Animation 2 is played, 50 means both animations are blended equally" },
		{ category = "Animation", id = "animBlendTime", name = "Animation Blend Time", editor = "number", min = 0, default = 0 },
		{ category = "Animation", id = "anim2", name = "Animation 2", editor = "dropdownlist", items = function(character) local list = character:GetStatesTextTable() table.insert(list, 1, "") return list end, default = "" },
		{ category = "Animation", id = "anim2BlendTime", name = "Animation 2 Blend Time", editor = "number", min = 0, default = 0 },
		{ category = "Animation", id = "AnimDuration", name = "Anim Duration", editor = "number", default = 0, read_only = true },
		{ category = "Animation", id = "StepVector", name = "Step Vector", editor = "point", default = point30, read_only = true },
		{ category = "Animation", id = "StepAngle", name = "Step Angle (deg)", editor = "number", default = 0, scale = 60, read_only = true },
		{ category = "Animation", id = "Looping", name = "Looping", editor = "bool", default = false, read_only = true },
		{ category = "Animation", id = "Compensate", name = "Compensate", editor = "text", default = "None", read_only = true },
	},
	obj = false,
	animFlags = 0,
	animCrossfade = 0,
	anim2Flags = 0,
	anim2Crossfade = 0,
	anim_speed = 1000,
}

function SelectionObjectAME:Getanim()
	return IsValid(self.obj) and self.obj:GetStateText() or ""
end

function SelectionObjectAME:GetStepVector(...)
	return IsValid(self.obj) and self.obj:GetStepVector(...) or point30
end

function SelectionObjectAME:GetStepAngle(...)
	return IsValid(self.obj) and self.obj:GetStepAngle(...) or 0
end

function SelectionObjectAME:GetLooping()
	return IsValid(self.obj) and self.obj:IsAnimLooping() or false
end

function SelectionObjectAME:GetCompensate()
	return IsValid(self.obj) and self.obj:GetAnimCompensate() or "None"
end

function SelectionObjectAME:GetAnimDuration()
	return IsValid(self.obj) and self.obj:GetAnimDuration() or point30
end

function SelectionObjectAME:Setanim(anim)
	if IsValid(self.obj) then
		self.obj:SetStateText(anim)
		BaseObjectAME.Setanim(self, anim)
	end
end

function SelectionObjectAME:GetEntity()
	return IsValid(self.obj) and self.obj:GetEntity() or ""
end

function SelectionObjectAME:OnEditorOpen(editor)
	BaseObjectAME.OnEditorOpen(self, editor)
	self:UpdateSelectedObj()
end

function SelectionObjectAME:SetSelectedObj(obj)
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

function SelectionObjectAME:UpdateSelectedObj()
	local obj = self.obj
	if not IsValid(obj) then
		return
	end
	local anim = obj:GetStateText()
	BaseObjectAME.Setanim(self, anim)
	self.Frame = obj:GetAnimPhase(1)
	self:ApplyPreviewSpeed(anim)
end

function SelectionObjectAME:OnEditorClose()
	BaseObjectAME.OnEditorClose(self)
	self.obj.fx_actor_class = nil
	self:SetSelectedObj(false)
end

function SelectionObjectAME:SetAnimChannel(channel, anim, anim_flags, crossfade, weight, blend_time, resume)
	local obj = self.obj
	if not IsValid(obj) then
		return 0, 0
	end
	
	obj:SetAnim(channel, anim, anim_flags, crossfade)
	obj:SetAnimWeight(channel, 100)
	obj:SetAnimWeight(channel, weight, blend_time)
	obj:SetAnimSpeed(channel, self.anim_speed)
	
	local frame = self.Frame
	if resume or self.anim_speed == 0 then
		obj:SetAnimPhase(channel, frame)
	end
	
	local duration = GetAnimDuration(obj:GetEntity(), obj:GetAnim(channel))
	return duration - (resume and frame or 0), duration
end

function SelectionObjectAME:GetSize()
	return IsValid(self.obj) and ObjectHierarchyBBox(self.obj) or box()
end

function SelectionObjectAME:GetAnimPhase(...)
	return IsValid(self.obj) and self.obj:GetAnimPhase(...) or 0
end

function SelectionObjectAME:GetStatesTextTable(...)
	return IsValid(self.obj) and self.obj:GetStatesTextTable(...) or {}
end

function SelectionObjectAME:TimeToAnimEnd(...)
	return IsValid(self.obj) and self.obj:TimeToAnimEnd(...) or 0
end

function SelectionObjectAME:OnAnimMetadataSelect(anim_meta)
	local obj = self.obj
	if not IsValid(obj) then
		return
	end
	local anim = anim_meta.id
	if not self.obj:HasState(anim) then
		return
	end
	local old_anim = self:GetProperty("anim")
	self:SetProperty("anim", anim)
	self:OnAnimChanged(anim, old_anim)
end

----

function GedOpCharacterCamThreeQuarters(socket, character)
	CreateRealTimeThread(function()
		local old_update_inactive = hr.MaxCameraUpdateInactive
		hr.MaxCameraUpdateInactive = true

		local center, radius = character:GetBSphere()
		cameraMax.Activate(1)
		cameraMax.SetCamera(center + character:GetFaceDir(radius), center)
		local size = character:GetSize()
		local height = size:sizez()
		local desired_height = UIL.GetScreenSize():y() * 3 / 4
		local lo, hi = 20, 100
		while hi - lo > 1 do
			local scale = (lo + hi) / 2
			cameraMax.SetCameraViewAt(center, radius * scale / 10)
			WaitNextFrame()
			local _, feet_height = GameToScreen(character:GetPos())
			local _, head_height = GameToScreen(character:GetPos() + point(0, 0, height))
			local screen_height = feet_height:y() - head_height:y()
			if screen_height < desired_height then
				hi = scale
			else
				lo = scale
			end
		end
		
		hr.MaxCameraUpdateInactive = old_update_inactive
	end)
end

function GedOpCharacterCamClosest(socket, character)
	local center, radius = character:GetBSphere()
	cameraMax.Activate(1)
	cameraMax.SetCamera(center + character:GetFaceDir(radius), center)
	cameraTac.Activate(1)
	cameraTac.SetCamera(center - character:GetFaceDir(radius), center)
	cameraTac.Normalize()
	cameraTac.SetLookAtAngle(hr.CameraTacLookAtAngle)
	cameraTac.SetFloor(0)
end

function GedOpAnimMetadataEditorPlay(socket, character)
	character.anim_speed = 1000
	if not character.loop_anim and character.Frame == character.anim_duration - 1 then
		character.Frame = 0
	end
	character:SetAnimHighLevel("resume")
	local control = GetDialog("AnimMetadataEditorTimeline"):ResolveId("idMoment-NewMoment")
	if control then
		control:delete()
	end
end

function GedOpAnimMetadataEditorStop(socket, character)
	character.Frame = character:GetAnimPhase(1)
	character.anim_speed = 0
	character:SetAnimHighLevel()
	GetDialog("AnimMetadataEditorTimeline"):CreateNewMomentControl()
end

function GedOpAnimationMomentsEditorToggleLoop(socket, character)
	character.loop_anim = not character.loop_anim
	if character.loop_anim and character.Frame == character.anim_duration - 1 then
		character.anim_speed = 1000
		character:Setanim(character.anim or character:Getanim())
	end
end

function GedOpAnimationMomentsEditorToggleSpeed(socket, speed)
	local character = GetAnimationMomentsEditorObject()
	character:SetPreviewSpeed(speed)
	GedObjectModified(character)
end

function GedOpOpenAppearanceEditor(socket, character)
	OpenAppearanceEditor(character.Appearance)
end

function GedOpSaveAnimMetadata()
	WipeDeleted()
	AnimMetadata:SaveAll("save all", "user request")
end

if FirstLoad then
	AnimationMomentsEditor = false
	AnimationMomentsEditorMode = false
	AnimMetadataEditorTimelineDragging = false        -- indicates dragging over the timeline bar
	AnimMetadataEditorTimelineSelectedControl = false -- selected/dragged moment control
end

function GetAnimationMomentsEditorObject()
	return AnimationMomentsEditor and AnimationMomentsEditor.bound_objects["root"]
end

function AnimationMomentsEditorBindObjects(character)
	if not AnimationMomentsEditor then return end
	
	local anim = character:GetProperty("anim")
	local entity = character:GetInheritedEntity(anim)
	
	AnimationMomentsEditor:BindObj("Animations", Presets.AnimMetadata)
	if AnimationMomentsEditorMode == "selection" then
		AnimationMomentsEditor:rfnBindFilterObj("Animations|tree", "AnimationsFilter",
			GedFilter:new{ FilterObject = function(self, obj) return obj.group == entity end })
	end
	
	local group = Presets.AnimMetadata[entity] or empty_table
	local preset = group[anim]
	if not preset then return end
	AnimationMomentsEditor:BindObj("AnimationMetadata", preset)
	
	GedObjectModified(character)
	GedObjectModified(Presets.AnimMetadata)
	GedObjectModified(preset)
	if preset.Moments then
		GedObjectModified(preset.Moments)
		for _, moment in ipairs(preset.Moments) do
			GedObjectModified(moment)
		end
	end
end

function AppearanceHasAnimation(appearance, animation)
	return appearance and appearance.Body and table.find(GetStates(appearance.Body), animation)
end

function AppearanceLocateByAnimation(animation, default)
	local appearance = default or LocalStorage.AME_LastAppearance
	if not AppearanceHasAnimation(AppearancePresets[appearance], animation) then
		local found
		ForEachPreset("AppearancePreset", function(preset)
			if AppearanceHasAnimation(preset, animation) then
				appearance = preset.id
				found = true
				return "break"
			end
		end)
		if not found then
			return
		end
	end
	return appearance
end

function OpenAnimationMomentsEditor(target, animation)
	local mode = IsValid(target) and "selection" or "appearance"
	
	if mode == "appearance" and animation then
		target = AppearanceLocateByAnimation(animation, target)
		if not target then return end
	end
	
	PopulateParentTableCache(Presets.AnimMetadata)
	
	CreateRealTimeThread(function()
		AnimationMomentsEditorMode = mode
		local obj
		if mode == "appearance" then
			local pos, dir = camera.GetEye(), camera.GetDirection()
			local pos = terrain.IntersectRay(pos, pos + dir) or pos:SetTerrainZ()
			obj = AppearanceObjectAME:new{init_pos = pos}
			obj:ApplyAppearance(target)
			obj:SetPos(pos)
			obj:SetGameFlags(const.gofRealTimeAnim)
		else
			obj = SelectionObjectAME:new()
			obj:SetSelectedObj(target)
		end
		if not AnimationMomentsEditor then
			AnimationMomentsEditor = OpenGedApp("AnimMetadataEditor", obj, { PresetClass = "AnimMetadata", WarningsUpdateRoot = "Animations" }) or false
			OpenDialog("AnimMetadataEditorTimeline", GetDevUIViewport())
		else
			local old = GetAnimationMomentsEditorObject()
			AnimationMomentsEditor:BindObj("root", obj)
			DoneObject(old)
		end
		obj:OnEditorOpen(AnimationMomentsEditor)
		if mode == "appearance" or animation then
			obj:Setanim(animation or "idle")
		end
		obj:UpdateAnimMetadataSelection()
		InitializeWarningsForGedEditor(AnimationMomentsEditor, "initial")
	end)
	return true
end

function CloseAnimationMomentsEditor(wait)
	if AnimationMomentsEditor then
		AnimationMomentsEditor:Send("rfnApp", "Exit")
	end
	if wait then
		while AnimationMomentsEditor do
			Sleep(10)
		end
	end
end

function OnMsg.GedClosing(ged_id)
	if AnimationMomentsEditor and AnimationMomentsEditor.ged_id == ged_id then
		CloseDialog("AnimMetadataEditorTimeline")
		local character = GetAnimationMomentsEditorObject()
		if IsValid(character) then
			DoneObject(character)
		end
		AnimationMomentsEditorMode = false
		AnimationMomentsEditor = false
	end	
end

function OnMsg.GedOnEditorSelect(obj, selected, ged_editor)
	if selected and ged_editor == AnimationMomentsEditor then
		if IsKindOf(obj, "AnimMetadata") then
			SuspendObjModified("GedOnEditorSelect")
			local character = GetAnimationMomentsEditorObject()
			character:OnAnimMetadataSelect(obj)
			GedObjectModified(character)
			ResumeObjModified("GedOnEditorSelect")
		end
	end
end


local function EditorSelectionChanged()
	if AnimationMomentsEditor and AnimationMomentsEditorMode == "selection" then
		local sel_obj = editor.GetSel()[1]
		local character = GetAnimationMomentsEditorObject()
		if not IsValid(sel_obj) or not character then
			CloseAnimationMomentsEditor()
		else
			character:SetSelectedObj(sel_obj)
			character:UpdateSelectedObj()
		end
	end
end

function OnMsg.EditorSelectionChanged(objects)
	if AnimationMomentsEditor and AnimationMomentsEditorMode == "selection" then
		DelayedCall(0, EditorSelectionChanged)
	end
end


function OnMsg.ChangingMap(map, mapdata, handler_fns)
	table.insert(handler_fns, CloseAnimationMomentsEditor)
end