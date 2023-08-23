DefineClass.FloatingDummy = {
	__parents = {"Object", "InvisibleObject", "ComponentAnim", },
}

function FloatingDummy:GameInit()
	self:SetAnimPhase(1, self:Random(self:GetAnimDuration()))
end

DefineClass.FloatingDummyCollision = {
	__parents = {"Object" },
	flags = { efWalkable = false, efCollision = false, efApplyToGrids = false	},
	clone_of = false,
}

local floating_dummy_attach_clear_enum_flags = const.efWalkable + const.efCollision + const.efApplyToGrids

function AttachObjectToFloatingDummy(obj, dummy, parent)
	local o = PlaceObject("FloatingDummyCollision")
	NetTempObject(o)
	o.clone_of = obj
	TargetDummies[obj] = o
	o:ChangeEntity(obj:GetEntity())
	local enum_flags = obj:GetEnumFlags(floating_dummy_attach_clear_enum_flags)
	if enum_flags ~= 0 then
		o:SetEnumFlags(enum_flags)
		obj:ClearEnumFlags(enum_flags)
	end
	o:SetState(obj:GetState())
	o:SetMirrored(obj:GetMirrored())
	o:SetScale(obj:GetScale())
	o:SetOpacity(0)
	if parent then
		parent:Attach(o, obj:GetAttachSpot())
		o:SetAttachAxis(obj:GetAttachAxis())
		o:SetAttachAngle(obj:GetAttachAngle())
		o:SetAttachOffset(obj:GetAttachOffset())
	else
		local obj_axis = obj:GetAxis()
		local obj_angle = obj:GetAngle()
		local obj_pos = obj:GetPos()
		if not obj_pos:IsValidZ() then obj_pos = obj_pos:SetTerrainZ() end

		o:SetAxis(obj_axis)
		o:SetAngle(obj_angle)
		o:SetPos(obj:GetPosXYZ())

		local attach_spot = dummy:GetSpotBeginIndex("Spot")
		local spot_pos, spot_angle, spot_axis = dummy:GetSpotLoc(attach_spot, dummy:GetState(), 0)
		if not spot_pos:IsValidZ() then spot_pos = spot_pos:SetTerrainZ() end
		local attach_offset = RotateAxis(obj_pos - spot_pos, spot_axis, -spot_angle)
		local attach_axis, attach_angle = ComposeRotation(obj_axis, obj_angle, spot_axis, -spot_angle)
		dummy:Attach(obj, attach_spot)
		obj:SetAttachAxis(attach_axis)
		obj:SetAttachAngle(attach_angle)
		obj:SetAttachOffset(attach_offset)
		local phase = InteractionRand(obj:GetAnimDuration(), "FloatingDummy")
		obj:SetAnimPhase(1, phase)
	end
	obj:ForEachAttach(AttachObjectToFloatingDummy, dummy, o)
end

function AttachObjectsToFloatingDummies()
	if IsEditorActive() then return end
	local collection = {}
	MapForEach("map", "FloatingDummy", function(dummy, collection)
		local col_index = dummy:GetCollectionIndex()
		if col_index ~= 0 then
			collection[col_index] = dummy
		end
	end, collection)
	if not next(collection) then
		return
	end
	SuspendPassEdits("AttachObjectsToFloatingDummies")
	MapForEach("map", "CObject", function(obj, collection)
		local dummy = collection[obj:GetCollectionIndex()]
		if not dummy or obj == dummy or obj:GetParent() then
			return
		end
		AttachObjectToFloatingDummy(obj, dummy)
	end, collection)
	ResumePassEdits("AttachObjectsToFloatingDummies")
end

local function RestoreFloatingDummyAttachFlags(o)
	local obj = o.clone_of
	if IsValid(obj) then
		obj:SetEnumFlags(o:GetEnumFlags(floating_dummy_attach_clear_enum_flags))
		obj:ClearHierarchyGameFlags(const.gofSolidShadow)
	end
	o:ForEachAttach(RestoreFloatingDummyAttachFlags)
end

function RestoreFloatingDummyAttach(o)
	local obj = o.clone_of
	if IsValid(obj) then
		if IsKindOf(obj:GetParent(), "FloatingDummy") then
			obj:Detach()
			obj:SetPos(o:GetPosXYZ())
			obj:SetAxis(o:GetAxis())
			obj:SetAngle(o:GetAngle())
		end
		RestoreFloatingDummyAttachFlags(o)
	end
	DoneObject(o)
	TargetDummies[obj] = nil
end

function DetachObjectsFromFloatingDummies()
	SuspendPassEdits("DetachObjectsFromFloatingDummies")
	MapForEach("map", "FloatingDummyCollision", RestoreFloatingDummyAttach)
	ResumePassEdits("DetachObjectsFromFloatingDummies")
end

OnMsg.NewMapLoaded = AttachObjectsToFloatingDummies
OnMsg.GameEnteringEditor = DetachObjectsFromFloatingDummies -- called before GameEnterEditor, allowing XEditorFilters to catch these objects
OnMsg.GameExitEditor = AttachObjectsToFloatingDummies
