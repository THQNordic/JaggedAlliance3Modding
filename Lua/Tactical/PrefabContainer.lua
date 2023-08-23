DefineClass.PrefabContainer = {
	__parents = { "InitDone" },
	name = false,
	pos = false,
	angle = 0,
	objs = false
}

function PrefabContainer:Init()
	local err, objs = PlacePrefab(self.name, self.pos, self.angle, nil, {
		dont_clamp_objects = true,
		ignore_ground_offset = true
	})
	assert(not err, err)
	self.objs = objs
end

function PrefabContainer:Done()
	DoneObjects(self.objs)
	self.objs = false
end

function PrefabContainer:GetPos()
	return self.pos
end

function PrefabContainer:SetPos(pos)
	if pos == self.pos then
		return
	end
	local dp = pos - self.pos
	for i, o in ipairs(self.objs) do
		o:SetPos(o:GetPos() + dp)
	end
	self.pos = pos
end

function PrefabContainer:SetPosRelativeTo(pos, obj)
	local relativePos = obj:GetPos() - self.pos
	self:SetPos(pos - relativePos)
end

function PrefabContainer:GetAngle()
	return self.angle
end

function PrefabContainer:SetAngle(angle)
	if AngleDiff(angle, self.angle) == 0 then
		return
	end
	RotateObjectsAroundCenter(self.objs, angle - self.angle, self.pos)
	self.angle = angle
end

function PrefabContainer:GetObjectByType(class)
	for i, o in ipairs(self.objs) do
		if IsKindOf(o, class) then
			return o
		end
	end
	return false
end