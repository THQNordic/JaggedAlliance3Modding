DefineClass.CollectionAnimator = {
	__parents = { "Object", "EditorEntityObject", "EditorObject" },
	--entity = "WayPoint",
	editor_entity = "WayPoint",
	properties = {
		{ name = "Rotate Speed", id = "rotate_speed", category = "Animator", editor = "number", default = 0, scale = 100, help = "Revolutions per minute" },
		{ name = "Oscillate Offset", id = "oscillate_offset", category = "Animator", editor = "point", default = point30, scale = "m", help = "Map offset acceleration movement up and down (in meters)" },
		{ name = "Oscillate Cycle", id = "oscillate_cycle", category = "Animator", editor = "number", default = 0, help = "Full cycle time in milliseconds" },
		{ name = "Locked Orientation", id = "LockedOrientation", category = "Animator", editor = "bool", default = false },
	},
	animated_obj = false,
	rotation_thread = false,
	move_thread = false,
}

DefineClass.CollectionAnimatorObj = {
	__parents = { "Object", "ComponentAttach" },
	flags = { cofComponentInterpolation = true, efWalkable = false, efApplyToGrids = false, efCollision = false },
	properties = {
		-- exclude properties to not copy them
		{ id = "Pos" },
		{ id = "Angle" },
		{ id = "Axis" },
		{ id = "Walkable" },
		{ id = "ApplyToGrids" },
		{ id = "Collision" },
		{ id = "OnCollisionWithCamera" },
		{ id = "CollectionIndex" },
		{ id = "CollectionName" },
	},
}

function CollectionAnimator:GameInit()
	self:StartAnimate()
end

function CollectionAnimator:Done()
	self:StopAnimate()
end

function CollectionAnimator:StartAnimate()
	if self.animated_obj then
		return -- already started
	end
	if not self:AttachObjects() then
		return
	end
	-- rotation
	if not self.rotation_thread and self.rotate_speed ~= 0 then
		self.rotation_thread = CreateGameTimeThread(function()
			local obj = self.animated_obj
			obj:SetAxis(self:RotateAxis(0,0,4096))
			local a = 162*60*(self.rotate_speed < 0 and -1 or 1)
			local t = 27000 * 100 / abs(self.rotate_speed)
			while true do
				obj:SetAngle(obj:GetAngle() + a, t)
				Sleep(t)
			end
		end)
	end
	-- movement
	if not self.move_thread and self.oscillate_cycle >= 100 and self.oscillate_offset:Len() > 0 then
		self.move_thread = CreateGameTimeThread(function()
			local obj = self.animated_obj
			local pos = self:GetVisualPos()
			local vec = self.oscillate_offset
			local t = self.oscillate_cycle/4
			local acc = self:GetAccelerationAndStartSpeed(pos+vec, 0, t)
			while true do
				obj:SetAcceleration(acc)
				obj:SetPos(pos+vec, t)
				Sleep(t)
				obj:SetAcceleration(-acc)
				obj:SetPos(pos, t)
				Sleep(t)
				obj:SetAcceleration(acc)
				obj:SetPos(pos-vec, t)
				Sleep(t)
				obj:SetAcceleration(-acc)
				obj:SetPos(pos, t)
				Sleep(t)
			end
		end)
	end
end

function CollectionAnimator:StopAnimate()
	DeleteThread(self.rotation_thread)
	self.rotation_thread = nil
	DeleteThread(self.move_thread)
	self.move_thread = nil
	self:RestoreObjects()
end

function CollectionAnimator:AttachObjects()
	local col = self:GetCollection()
	if not col then
		return false
	end
	SuspendPassEdits("CollectionAnimator")
	local obj = PlaceObject("CollectionAnimatorObj")
	self.animated_obj = obj
	local pos = self:GetPos()
	local max_offset = 0
	MapForEach (col.Index, false, "map", "attached", false, function(o)
			if o == self then return end
			local o_pos, o_axis, o_angle = o:GetVisualPos(), o:GetAxis(), o:GetAngle()
			local o_offset = o_pos - pos
			--if o:IsKindOf("ComponentAttach") then
				o:DetachFromMap()
				o:SetAngle(0) -- fixes a problem when attaching
				obj:Attach(o)
			--else
			--	local clone = PlaceObject("CollectionAnimatorObj")
			--	clone:ChangeEntity(o:GetEntity())
			--	clone:CopyProperties(o)
			--end
			o:SetAttachAxis(o_axis)
			o:SetAttachAngle(o_angle)
			o:SetAttachOffset(o_offset)
			max_offset = Max(max_offset, o_offset:Len())
		end)
	if max_offset > 20*guim then
		obj:SetGameFlags(const.gofAlwaysRenderable)
	end
	if self.LockedOrientation then
		obj:SetHierarchyGameFlags(const.gofLockedOrientation)
	end
	obj:ClearHierarchyEnumFlags(const.efWalkable + const.efApplyToGrids + const.efCollision)
	obj:SetPos(pos)
	ResumePassEdits("CollectionAnimator")
	return true
end

function CollectionAnimator:RestoreObjects()
	local obj = self.animated_obj
	if not obj then
		return
	end
	SuspendPassEdits("CollectionAnimator")
	self.animated_obj = nil
	obj:SetPos(self:GetPos())
	obj:SetAxis(axis_z)
	obj:SetAngle(0)
	for i = obj:GetNumAttaches(), 1, -1 do
		local o = obj:GetAttach(i)
		local o_pos, o_axis, o_angle = o:GetAttachOffset(), o:GetAttachAxis(), o:GetAttachAngle()
		o:Detach()
		o:SetPos(o:GetPos() + o_pos)
		o:SetAxis(o_axis)
		o:SetAngle(o_angle)
		o:ClearGameFlags(const.gofLockedOrientation)
	end
	DoneObject(obj)
	ResumePassEdits("CollectionAnimator")
end

function CollectionAnimator:EditorEnter()
	self:StopAnimate()
end

function CollectionAnimator:EditorExit()
	self:StartAnimate()
end

function OnMsg.PreSaveMap()
	MapForEach("map", "CollectionAnimator", function(obj) obj:StopAnimate() end)
end

function OnMsg.PostSaveMap()
	MapForEach("map", "CollectionAnimator", function(obj) obj:StartAnimate() end)
end
