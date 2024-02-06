local function not_attached(obj)
	return not obj:GetParent()
end

--[[@@@
@class ComponentAttach
Objects inheriting this class can attach other objects or be attached to other objects
--]]

DefineClass.ComponentAttach = {
	__parents = { "CObject" },
	flags = { cofComponentAttach = true },
	properties = {
		{ category = "Child", id = "AttachOffset",   name = "Attached Offset",  editor = "point",  default = point30, no_edit = not_attached, dont_save = true },
		{ category = "Child", id = "AttachAxis",     name = "Attached Axis",    editor = "point",  default = axis_z,  no_edit = not_attached, dont_save = true },
		{ category = "Child", id = "AttachAngle",    name = "Attached Angle",   editor = "number", default = 0,       no_edit = not_attached, dont_save = true, min = -180*60, max = 180*60, slider = true, scale = "deg" },
		{ category = "Child", id = "AttachSpotName", name = "Attached At",      editor = "text",   default = "",      no_edit = not_attached, dont_save = true, read_only = true },
		{ category = "Child", id = "Parent",         name = "Attached To",      editor = "object", default = false,   no_edit = not_attached, dont_save = true, read_only = true },
		{ category = "Child", id = "TopmostParent",  name = "Topmost Parent",   editor = "object", default = false,   no_edit = not_attached, dont_save = true, read_only = true },
		{ category = "Child", id = "AngleLocal",     name = "Local Angle",      editor = "number", default = 0,       no_edit = not_attached, dont_save = true, min = -180*60, max = 180*60, slider = true, scale = "deg" },
		{ category = "Child", id = "AxisLocal",      name = "Local Axis",       editor = "point",  default = axis_z,  no_edit = not_attached, dont_save = true },
	},
}

ComponentAttach.SetAngleLocal = CObject.SetAngle
ComponentAttach.SetAxisLocal = CObject.SetAxis

DefineClass.StripComponentAttachProperties = {
	__parents = { "ComponentAttach" },
	properties = {
		{ id = "AttachOffset",   },
		{ id = "AttachAxis",     },
		{ id = "AttachAngle",    },
		{ id = "AttachSpotName", },
		{ id = "Parent",         },
	},
}

function ComponentAttach:GetAttachSpotName()
	local parent = self:GetParent()
	return parent and parent:GetSpotName(self:GetAttachSpot())
end

DefineClass.ComponentCustomData = {
	__parents = { "CObject" },
	flags = { cofComponentCustomData = true },
	-- when inheriting ComponentCustomData from multiple parents you have to:
	-- 1. review if its use is not conflicting
	-- 2. add member CustomDataType = "<class-name>" to suppress the class system error
	
	GetCustomData = _GetCustomData,
	SetCustomData = _SetCustomData,
	GetCustomString = _GetCustomString,
	SetCustomString = _SetCustomString,
}

if Platform.developer then
function OnMsg.ClassesPreprocess(classdefs)
	for name, class in pairs(classdefs) do
		if table.find(class.__parents, "ComponentCustomData") then
			if not class.CustomDataType then
				class.CustomDataType = name
			end
		end
	end
end
end

function SpecialOrientationItems()
	local SpecialOrientationNames = { "soTerrain", "soTerrainLarge", "soFacing", "soFacingY", "soFacingVertical", "soVelocity", "soZOffset", "soTerrainPitch", "soTerrainPitchLarge" }
	table.sort(SpecialOrientationNames)
	local items = {}
	for i, name in ipairs(SpecialOrientationNames) do
		items[i] = { text = name, value = const[name] }
	end
	table.insert(items, 1, { text = "", value = const.soNone })
	return items
end

DefineClass.ComponentExtraTransform = {
	__parents = { "CObject" },
	flags = { cofComponentExtraTransform = true },
	properties = {
		{ id = "SpecialOrientation", name = "Special Orientation", editor = "choice", default = const.soNone, items = SpecialOrientationItems },
	},
}

DefineClass.ComponentInterpolation = {
	__parents = { "CObject" },
	flags = { cofComponentInterpolation = true },
}

DefineClass.ComponentCurvature = {
	__parents = { "CObject" },
	flags = { cofComponentCurvature = true },
}

DefineClass.ComponentAnim = {
	__parents = { "CObject" },
	flags = { cofComponentAnim = true },
}

DefineClass.ComponentSound = {
	__parents = { "CObject" },
	flags = { cofComponentSound = true },
	properties = {
		{ category = "Sound", id = "SoundBank",     name = "Bank",     editor = "preset_id",  default = "", preset_class = "SoundPreset", dont_save = true },
		{ category = "Sound", id = "SoundType",     name = "Type",     editor = "preset_id",  default = "", preset_class = "SoundTypePreset", dont_save = true, read_only = true },
		{ category = "Sound", id = "Sound",         name = "Sample",   editor = "text",       default = "", dont_save = true, read_only = true },
		{ category = "Sound", id = "SoundDuration", name = "Duration", editor = "number",     default = -1, dont_save = true, read_only = true },
		{ category = "Sound", id = "SoundHandle",   name = "Handle",   editor = "number",     default = -1, dont_save = true, read_only = true },
	},
}

function ComponentSound:GetSoundBank()
	local sname, sbank, stype, shandle, sduration, stime = self:GetSound()
	return sbank or ""
end
function ComponentSound:GetSoundType()
	local sname, sbank, stype, shandle, sduration, stime = self:GetSound()
	return stype or ""
end
function ComponentSound:GetSoundHandle()
	local sname, sbank, stype, shandle, sduration, stime = self:GetSound()
	return shandle or -1
end
function ComponentSound:GetSoundDuration()
	local sname, sbank, stype, shandle, sduration, stime = self:GetSound()
	return sduration or -1
end