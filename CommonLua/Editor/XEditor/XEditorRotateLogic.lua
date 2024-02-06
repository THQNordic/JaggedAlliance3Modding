DefineClass.XEditorRotateLogic = {
	__parents = { "PropertyObject" },
	init_rotate_center = false,
	init_rotate_data = false,
	init_angle = false,
	last_angle = false,
}

-- with Slabs in the selection, rotate around a half-grid aligned point
-- to ensure Slab positions are aligned after the rotation
function XEditorRotateLogic:GetRotateCenter(center, has_slabs)
	local snap = has_slabs and const.SlabSizeX or 1
	return point(center:x() / snap * snap, center:y() / snap * snap, center:z())
end

function XEditorRotateLogic:GetRotateAngle()
	assert(false, "Please implement GetRotateAngle in the subclass.")
end

function XEditorRotateLogic:InitRotation(objs, center, initial_angle)
	assert(not self.init_rotate_data)
	local has_slabs = HasAlignedObjs(objs)
	self.init_rotate_center = self:GetRotateCenter(center or CenterOfMasses(objs), has_slabs)
	self.init_angle = initial_angle or self:GetRotateAngle()
	self.last_angle = 0
	self.init_rotate_data = {}
	for i, obj in ipairs(objs) do
		if obj:IsValidPos() then
			self.init_rotate_data[i] = {
				axis = obj:GetVisualAxis(),
				angle = obj:GetVisualAngle(),
				offset = obj:GetVisualPos() - self.init_rotate_center,
				valid_z = obj:IsValidZ(),
				last_angle = 0,
			}
		end
	end
end

function XEditorRotateLogic:Rotate(objs, group_rotation, center, axis, angle)
	if not self.init_rotate_data then
		self:InitRotation(objs, center)
	end
	
	axis = axis or axis_z
	angle = angle or self:GetRotateAngle()
	
	local has_slabs = HasAlignedObjs(objs)
	local center = self.init_rotate_center
	local angle = XEditorSettings:AngleSnap(angle - self.init_angle, has_slabs)
	for i, obj in ipairs(objs) do
		if obj:HasMember("EditorRotate") then
			obj:EditorRotate(group_rotation and center or obj:GetPos(), axis, angle, self.last_angle)
		elseif obj:IsValidPos() then
			local data = self.init_rotate_data[i]
			local newPos = obj:GetPos()
			if group_rotation then
				newPos = center + RotateAxis(data.offset, axis, angle)
				if not data.valid_z then
					newPos = newPos:SetInvalidZ()
				end
			end
			XEditorSetPosAxisAngle(obj, newPos, ComposeRotation(data.axis, data.angle, axis, angle))
		end
	end
	Msg("EditorCallback", "EditorCallbackRotate", objs)
	self.last_angle = angle
end

function XEditorRotateLogic:CleanupRotation()
	self.init_rotate_data = nil
	self.init_rotate_center = nil
	self.init_angle = nil
	self.last_angle = nil
end
