DefineClass.ComponentLight = {
	__parents = { "CObject" },
	flags = { cfLight = true, cofComponentLight = true, }
}

for name, func in pairs(ComponentLightFunctions) do
	ComponentLight[name] = func
end

local lightmodel_lights = {"A", "B", "C", "D"}
DefineClass.Light = {
	__parents = { "Object", "InvisibleObject", "ComponentAttach", "ComponentLight" },
	flags = { cfConstructible = false, gofRealTimeAnim = true, efShadow = false, efSunShadow = false,
		gofDetailClass0 = true, gofDetailClass1 = true,	-- to match 'Eye Candy' default of DetailClass
	}, -- ATTN: cfEditorCallback added below when Platform.editor

	-- Properties, editable in the editor's property window (Ctrl+O)
	properties = {
		{ id = "DetailClass", name = "Detail Class", editor = "dropdownlist",
			items = {"Default", "Essential", "Optional", "Eye Candy"}, default = "Eye Candy",
		},
		{ category = "Visuals", id = "Color", editor = "color", autoattach_prop = true, dont_save = function(obj)
				if not IsValid(obj) then return false end
				if obj:GetLightmodelColorIndexNumber() ~= 0 then return true end
				return false
			end,
			read_only = function(obj)
				if not IsValid(obj) then return false end
				if obj:GetLightmodelColorIndexNumber() ~= 0 then return true end
				return false
			end,
		},
		{ category = "Visuals", id = "LightmodelColorIndex", editor = "set", items = lightmodel_lights, max_items_in_set = 1, default = {}, autoattach_prop = true,},
		{ category = "Visuals", id = "OriginalColor", editor = "color", default = RGB(255, 255, 255), no_edit = true, dont_save = true },
		{ category = "Visuals", id = "Intensity", editor = "number", min = 0, max = 255, slider = true, autoattach_prop = true, },
		{ category = "Visuals", id = "Exterior", editor = "bool", autoattach_prop = true, },
		{ category = "Visuals", id = "Interior", editor = "bool", autoattach_prop = true, }, 
		{ category = "Visuals", id = "InteriorAndExteriorWhenHasShadowmap", editor = "bool", autoattach_prop = true, }, 
		{ category = "Visuals", id = "Volume", helper = "volume", editor = "object", default = false, base_class = "Volume" }, 
		{ category = "Visuals", id = "ConstantIntensity", editor = "number", default = 0, autoattach_prop = true, slider = true, max = 127, min = -128 }, 
		{ category = "Visuals", id = "AttenuationShape", editor = "number", default = 0, autoattach_prop = true, slider = true, max = 255, min = 0 }, 
		{ category = "Visuals", id = "CastShadows", editor = "bool", autoattach_prop = true },
		{ category = "Visuals", id = "DetailedShadows", editor = "bool", autoattach_prop = true },
		{ id = "ColorModifier", editor = false },
		{ id = "Occludes",   editor = false },
		{ id = "Walkable",   editor = false },
		{ id = "ApplyToGrids",   editor = false },
		{ id = "Collision",   editor = false },
		{ id = "Color1",   editor = false },
		{ id = "ParentSIModulation", editor = "number", default = 100, min = 0, max = 255, slider = true, autoattach_prop = true, no_edit = function(o)
			return IsKindOf(o, "CObject")
		end, help = "To be used by the AutoAttach system."},
	},

	Color = RGB(255,255,255),
	Intensity = 100,
	Interior = true,
	Exterior = true,
	InteriorAndExteriorWhenHasShadowmap = true,
	CastShadows = false,
	DetailedShadows = false,

	Init = function(self)
		self:SetColor(self.Color)
		self:SetIntensity(self.Intensity)
		self:SetInterior(self.Interior)
		self:SetExterior(self.Exterior)
		self:SetInteriorAndExteriorWhenHasShadowmap(self.InteriorAndExteriorWhenHasShadowmap)
		self:SetConstantIntensity(0)
		self:SetAttenuationShape(0)
		self:SetLightmodelColorIndex(empty_table)
		self:SetCastShadows(self.CastShadows)
		self:SetDetailedShadows(self.DetailedShadows)
	end,

	GetCastShadows = function(self) return self:GetLightFlags(const.elfCastShadows) end,
	SetCastShadows = function(self, value)
		self.CastShadows = value
		if value then
			self:SetLightFlags(const.elfCastShadows)
		else
			self:ClearLightFlags(const.elfCastShadows)
		end
	end,
	
	GetDetailedShadows = function(self) return self:GetLightFlags(const.elfDetailedShadows) end,
	SetDetailedShadows = function(self, value)
		self.DetailedShadows = value
		if value then
			self:SetLightFlags(const.elfDetailedShadows)
		else
			self:ClearLightFlags(const.elfDetailedShadows)
		end
	end,
	
	GetColor = function(self)
		local index = self:GetLightmodelColorIndexNumber()
		if index ~= 0 then return GetSceneParamColor("LightColor" .. index) end 
		return self:GetColor0()
	end,
	SetColor = function(self, rgb) self:SetColor0(rgb) self:SetColor1(rgb) end,
	GetColor0 = function(self) return self:GetColorAtIndex(0) end,
	GetColor1 = function(self) return self:GetColorAtIndex(1) end,
	SetColor0 = function(self, rgb) self:SetColorAtIndex(0, rgb) self:SetColorModifier(rgb or 0) end,
	SetColor1 = function(self, rgb) self:SetColorAtIndex(1, rgb) end,
	
	GetExterior = function(self)
		return self:GetLightFlags(const.elfExterior)
	end,
	
	SetExterior = function(self, value)
		self.Exterior = value
		if value then
			self:SetLightFlags(const.elfExterior)
		else
			self:ClearLightFlags(const.elfExterior)
		end
	end,
	
	GetInterior = function(self)
		return self:GetLightFlags(const.elfInterior)
	end,
	
	SetInterior = function(self, value)
		self.Interior = value
		if value then
			self:SetLightFlags(const.elfInterior)
		else
			self:ClearLightFlags(const.elfInterior)
		end
	end,

	GetInteriorAndExteriorWhenHasShadowmap = function(self)
		return self:GetLightFlags(const.elfInteriorAndExteriorWhenHasShadowmap)
	end,

	SetInteriorAndExteriorWhenHasShadowmap = function(self, value)
		self.InteriorAndExteriorWhenHasShadowmap = value
		if value then
			self:SetLightFlags(const.elfInteriorAndExteriorWhenHasShadowmap)
		else
			self:ClearLightFlags(const.elfInteriorAndExteriorWhenHasShadowmap)
		end
	end,

	SetLightmodelColorIndex = function(self, val)
		local index = 0
		local activated_key = false
		for key, value in pairs(val or empty_table) do
			if value then activated_key = key end
		end
		if activated_key then
			index = table.find(lightmodel_lights, activated_key)
		end
		assert(index >= 0 and index <= 4)

		-- maskset(old, const.elfColorIndexMask, index << const.elfColorIndexShift)
		self:ClearLightFlags(const.elfColorIndexMask)
		self:SetLightFlags(index << const.elfColorIndexShift) 
	end,

	GetLightmodelColorIndex = function(self)
		local index = self:GetLightmodelColorIndexNumber()
		if index == 0 then return {} end
		return { [lightmodel_lights[index]] = true }
	end,

	SetIntensity = function(self, value) self:SetIntensityAtIndex(0, value) self:SetIntensityAtIndex(1, value) end,
	SetIntensity0 = function(self, value) self:SetIntensityAtIndex(0, value) end,
	SetIntensity1 = function(self, value) self:SetIntensityAtIndex(1, value) end,
	GetIntensity0 = function(self, value) return self:GetIntensityAtIndex(0) end,
	GetIntensity1 = function(self, value) return self:GetIntensityAtIndex(1) end,
	GetIntensity = function(self, value) return self:GetIntensityAtIndex(0), self:GetIntensityAtIndex(1) end,
	
	GetAlwaysRenderable = function(self) return self:GetGameFlags(const.gofAlwaysRenderable) end,
	SetAlwaysRenderable = function(self, value) 
		if value == true then
			self:SetGameFlags(const.gofAlwaysRenderable)
		else
			self:ClearGameFlags(const.gofAlwaysRenderable)
		end
	end,
	
	SetBehavior = function(self, b)
		if b == "flicker" then
			self:SetLightFlags(const.elfFlicker)
		else
			self:ClearLightFlags(const.elfFlicker)
		end
	end,

	CurrTime = function(self)
		if self:GetGameFlags( const.gofRealTimeAnim ) > 0 then
			return RealTime()
		end
		return GameTime()
	end,

	Fade = function(self, color, intensity, time)
		self:SetBehavior("fade")
		self:SetTimes(self:CurrTime(), self:CurrTime() + time)
		self:SetColor0(self:GetColor1())
		self:SetColor1(color)
		self:SetIntensity0(self:GetIntensity1())
		self:SetIntensity1(intensity)
	end,

	Flicker = function(self, color, intensity, period, phase)
		self:SetBehavior("flicker")
		phase = self:CurrTime() - (phase or AsyncRand(period))
		self:SetTimes(phase, phase + period * 300)
		self:SetColor(color)
		self:SetIntensity0(0)
		self:SetIntensity1(intensity)
	end,

	Steady = function(self, color, intensity)
		self:SetColor(color)
		self:SetBehavior("fade")
		self:SetTimes(-1,-1)
		self:SetIntensity(intensity)
	end,

	SetParentSIModulation = function(self, value)
		local parent = self:GetParent()
		if parent then
			parent:SetSIModulation(value)
		end
	end,
	GetParentSIModulation = function(self)
		local parent = self:GetParent()
		if parent then
			return parent:GetSIModulation()
		end
		return 100
	end,

	SetVolume = function(self, volume_obj)
		self:SetTargetVolumeId(volume_obj and volume_obj.handle or 0)
	end,
	
	GetVolume = function(self)
		local handle = self:GetTargetVolumeId()
		if not handle or handle == 0 then return false end
		return HandleToObject[handle]
	end,
	
	SetContourOuterID = empty_func,
}

function Light:OnEditorSetProperty(prop_id)
	if prop_id == "DetailClass" then
		self:DestroyRenderObj()
	end
end

const.ShadowDirsComboItems = {
	[LastSetBit(const.eLightDirX) + 1] = { name = "+X" },
	[LastSetBit(const.eLightDirNegX) + 1] = { name = "-X" },
	[LastSetBit(const.eLightDirY) + 1] = { name = "+Y" },
	[LastSetBit(const.eLightDirNegY) + 1] = { name = "-Y" },
	[LastSetBit(const.eLightDirZ) + 1] = { name = "+Z" },
	[LastSetBit(const.eLightDirNegZ) + 1] = { name = "-Z" },
}
local shadowDirsDefault = 0

DefineClass.PointLight = {
	__parents = { "Light" },
	entity = "PointLight", -- needed by the editor

	properties = {
		{ category = "Visuals", id = "SourceRadius", name = "Source Radius (cm)", editor = "number", min = guic, max=20*guim, default = 10*guic, scale = guic, slider = true,
			helper = "sradius", color = RGB(200, 200, 0), autoattach_prop = true, },
		{ category = "Visuals", id = "AttenuationRadius", name = "Attenuation Radius", editor = "number", min = 0*guim, max=500*guim, default = 10*guim, scale = "m", slider = true,
			helper = "sradius", color = RGB(255, 0, 0), autoattach_prop = true, },
		{ category = "Visuals", id = "ShadowDirs", name = "Shadow Dirs (To disable)", editor = "flags", items = const.ShadowDirsComboItems, default = shadowDirsDefault, size = 6,
			autoattach_prop = true, },
	},
	
	ShadowDirsDefault = shadowDirsDefault,
	SourceRadius = 1*guic,
	AttenuationRadius = 10*guim,
	
	Init = function(self)
		self:SetSourceRadius(self.SourceRadius)
		self:SetAttenuationRadius(self.AttenuationRadius)
		self:SetLightType(const.eLightTypePoint)
		self:SetShadowDirs(shadowDirsDefault)
	end,
}

DefineClass.LightFlicker = {
	__parents = {"InitDone"},
	entity = "PointLight", -- needed by the editor
	properties = {
		{ id = "Color",       editor = false },
		{ id = "Intensity",   editor = false },
		{ category = "Visuals", id = "Color0",      editor = "color",  default = RGB(255,255,255), autoattach_prop = true, },
		{ category = "Visuals", id = "Intensity0",  editor = "number", default = 0, min = 0, max = 255, slider = true, autoattach_prop = true, },
		{ category = "Visuals", id = "Color1",      editor = "color",  default = RGB(255,255,255), autoattach_prop = true, },
		{ category = "Visuals", id = "Intensity1",  editor = "number", default = 100, min = 0, max = 255, slider = true, autoattach_prop = true, },
		{ category = "Visuals", id = "Period",      editor = "number", default = 500, min = 0, max = 100000, scale = 1000, slider = true, autoattach_prop = true, },
	},
	
	-- defaults
	Period = 40000,
}

function LightFlicker:Init()
	self:SetBehavior("flicker")
	self:SetColor(self.Color)
	self:SetIntensity0(0)
	self:SetIntensity1(self.Intensity)
	self:SetPeriod(self.Period)
end

function LightFlicker:GetPeriod()
	local t0,t1 = self:GetTimes()
	return t1 - t0
end
	
function LightFlicker:SetPeriod(period)
	period = Max(period, 1)
	local phase = AsyncRand(period)
	local time = self:CurrTime()
	if self:CurrTime() < phase then
		self:SetTimes(0, period)
	else
		self:SetTimes(time - phase, time - phase + period)
	end
end

DefineClass.PointLightFlicker = {
	__parents = { "PointLight", "LightFlicker" },
}

DefineClass.SpotLightFlicker = {
	__parents = { "SpotLight", "LightFlicker" },
}

DefineClass.MaskedLight = {
	__parents = { "Light" },
	properties = {
		{ category = "Visuals", id = "Mask",       editor = "browse", folder = "Textures/Misc/LightMasks", help = "Specifies the texture that is going to be applied to modify the light appearance" },
		{ category = "Visuals", id = "AnimX",      editor = "number", min = 1, max = 16, help = "How many cuts on the X axis are specified in the mask texture. The animation is traversed left to right." },
		{ category = "Visuals", id = "AnimY",      editor = "number", min = 1, max = 16, help = "How many cuts on the Y axis are specified in the mask texture. The animation is traversed top to bottom." },
		{ category = "Visuals", id = "AnimPeriod", editor = "number", min = 0, max = 256, scale = 10, help = "The period of the animation. If zero is specified, the animation is not applied." },
		{ category = "Visuals", id = "ScaleMask",  editor = "bool", default = false, },
	},

	-- defaults
	Mask = "Textures/Misc/LightMasks/angle-attn.tga",
	ScaleMask = false,
	AnimX = 1,
	AnimY = 1,
	AnimPeriod = 256,

	Init = function(self)
		self:SetMask(self.Mask)
		self:SetScaleMask(self.ScaleMask)
		self:SetAnimX(self.AnimX)
		self:SetAnimY(self.AnimY)
		self:SetAnimPeriod(self.AnimPeriod)
	end,

	GetScaleMask = function(self) return self:GetLightFlags(const.elfScaleMask) end,
	SetScaleMask = function(self, scale)
		if scale then
			self:SetLightFlags(const.elfScaleMask)
		else
			self:ClearLightFlags(const.elfScaleMask)
		end
	end,

	GetAnim = function(self, nshift)
		local flags = self:GetAnimParams()
		local anim_size = band(shift(flags, -nshift), const.elAnimMask) + 1
		return anim_size
	end,

	SetAnim = function(self, nshift, num)
		local flags = self:GetAnimParams()
		local new_data = maskset(flags, shift(const.elAnimMask, nshift), shift(num-1, nshift))
		self:SetAnimParams(new_data)
	end,
		
	GetAnimX = function(self) return self:GetAnim(const.elAnimXShift) end,
	SetAnimX = function(self, num) self:SetAnim(const.elAnimXShift, num) end,
	
	GetAnimY = function(self) return self:GetAnim(const.elAnimYShift) end,
	SetAnimY = function(self, num) self:SetAnim(const.elAnimYShift, num) end,

	GetMask = _GetCustomString,
	SetMask = _SetCustomString,
	
	GetAnimPeriod = function(self)
		return shift(band(self:GetAnimParams(), const.elAnimPeriodMask), -const.elAnimPeriodShift)
	end,
	SetAnimPeriod = function(self, period)
		local params = self:GetAnimParams()
		local new_params = maskset(params, const.elAnimPeriodMask, shift(period, const.elAnimPeriodShift))
		self:SetAnimParams(new_params )
	end,
}

DefineClass.BoxLight = {
	__parents = { "MaskedLight" },
	entity = "PointLight", -- needed by the editor

	properties = {
		{ category = "Visuals", id = "BoxWidth",   editor = "number", min = guim/10, max = 50*guim, slider = true, helper = "box3" },
		{ category = "Visuals", id = "BoxHeight",  editor = "number", min = guim/10, max = 50*guim, slider = true, helper = "box3" },
		{ category = "Visuals", id = "BoxDepth",   editor = "number", min = guim/10, max = 50*guim, slider = true, helper = "box3" },
	},
	
	-- defaults
	BoxWidth = 5 * guim,
	BoxHeight = 5 * guim,
	BoxDepth = 5 * guim,
	
	Init = function(self)
		self:SetBoxWidth(self.BoxWidth)
		self:SetBoxHeight(self.BoxHeight)
		self:SetBoxDepth(self.BoxDepth)
		self:SetLightType(const.eLightTypeBox)
	end,
}

DefineClass.SpotLight = {
	__parents = { "PointLight", "MaskedLight" },
	entity = "PointLight", -- needed by the editor

	properties = {
		{ category = "Visuals", id = "ConeInnerAngle",  editor = "number", min = 5, max = (180 - 5), default = 45, slider = true, helper = "spotlighthelper", autoattach_prop = true, },
		{ category = "Visuals", id = "ConeOuterAngle",  editor = "number", min = 5, max = (180 - 5), default = 90, slider = true, helper = "spotlighthelper", autoattach_prop = true, },		
	},

	-- defaults
	ConeInnerAngle = 45,
	ConeOuterAngle = 90,
	
	target_helper = false,
	
	Init = function(self)
		self:SetConeInnerAngle(self.ConeInnerAngle)
		self:SetConeOuterAngle(self.ConeOuterAngle)
		self:SetLightType(const.eLightTypeSpot)
	end,
	
	GetConeInnerAngle = function(self) return self:GetInnerAngle() end,	
	GetConeOuterAngle = function(self) return self:GetOuterAngle() end,
}

if Platform.developer then
	function SpotLight:SetConeInnerAngle(v)
		self:SetInnerAngle(v)
		if (v > self:GetOuterAngle()) then
			self:SetOuterAngle(v)
		end
	end
	function SpotLight:SetConeOuterAngle(v)
		self:SetOuterAngle(v)
		if (v < self:GetInnerAngle()) then
			self:SetInnerAngle(v)
		end
	end
else
	function SpotLight:SetConeInnerAngle(v) self:SetInnerAngle(v) end
	function SpotLight:SetConeOuterAngle(v) self:SetOuterAngle(v) end
end

function SpotLight:OnEditorSetProperty(...)
	Light.OnEditorSetProperty(self, ...)
	PropertyHelpers_UpdateAllHelpers(self)
end

function SpotLight:ConfigureTargetHelper()
	if not self.target_helper or not IsValid(self.target_helper) then 
		self.target_helper = PlaceObject("SpotHelper") 
		self.target_helper.obj = self
	end
	
	local axis = self:GetOrientation()
	local pos = self:GetVisualPos()
	local o, closest, normal = IntersectSegmentWithClosestObj(pos, pos - axis * guim)
	if closest and normal and o ~= self.target_helper then
		self.target_helper:SetPos(closest)
	else
		local newPos = terrain.IntersectRay(pos, pos + axis)
		if newPos then
			self.target_helper:SetPos(newPos:SetZ(const.InvalidZ))
		end
	end
end

function OnMsg.EditorSelectionChanged(objs)
	local isSpotLight = false
	for _, obj in ipairs(objs) do
		if obj.class == "SpotLight" then
			isSpotLight = true
			obj:ConfigureTargetHelper()
		elseif obj.class == "SpotHelper" then
			isSpotLight = true
		end
	end
	if not isSpotLight then
		MapForEach(true, "SpotHelper", function(spot_helper)
			DoneObject(spot_helper)
		end)
	end
end

function OnMsg.EditorCallback(id, objects, ...)
	if id == "EditorCallbackMove" or id == "EditorCallbackRotate" or id == "EditorCallbackPlace" then
		for _, obj in ipairs(objects) do
			if obj.class == "SpotLight" then
				obj:ConfigureTargetHelper()
			end
		end
		if id == "EditorCallbackMove" then
			for _, obj in ipairs(objects) do
				if obj.class == "SpotHelper" and obj.obj.class == "SpotLight" then
					obj.obj:SetOrientation(Normalize(obj.obj:GetVisualPos() - obj:GetVisualPos()), 0)
				end
			end
		end
	elseif id == "EditorCallbackDelete" then
		for _, obj in ipairs(objects) do
			if obj.class == "SpotLight" then
				DoneObject(obj.target_helper)
				obj.target_helper = false
			end
		end
	end
end

if Platform.developer and false then
	function OnMsg.NewMapLoaded()
		-- check if used lightmaps are available
		local masks = {}
		MapForEach("map", "Light", function(light) 	if light:HasMember("GetMask") then masks[light:GetMask()] = true end end)
		for mask, _ in pairs(masks) do
			local id = ResourceManager.GetResourceID(mask)
			if id == const.InvalidResourceID then
				printf("once", "Light mask texture '%s' is not present", mask)
			end
		end
	end
end

function PointLight:ConfigureInvisibleObjectHelper(helper)
	if not helper then return end
	local important = self:GetDetailClass() == "Essential"
	helper:SetScale(important and 100 or 60)
	if important then
		helper:SetColorModifier(self:GetCastShadows() and RGB(100, 10, 10) or RGB(20, 80, 100))
	else
		helper:SetColorModifier(self:GetCastShadows() and RGB(100, 30, 30) or RGB(40, 80, 100))
	end
end

DefineClass.AttachLightPropertyObject = {
	__parents = {"PropertyObject"},
	
	properties = {
		{category = "Lights", id = "AttachLight", name = "Attach Light", editor = "bool", default = true},
	},
}

local detail_class_weight = {["Essential"] = 1, ["Optional"] = 2, ["Eye Candy"] = 3}

function GetLights(filter)
	if GetMap() == "" then return end
	
	local lights = MapGet("map", "Light", const.efVisible, filter) or empty_table
	table.sort(lights, function(light1, light2)
		local weight1 = detail_class_weight[light1:GetDetailClass()] or 4
		local weight2 = detail_class_weight[light2:GetDetailClass()] or 4
		if weight1 == weight2 then
			return light1.handle < light2.handle
		else
			return weight1 < weight2
		end
	end)
	
	return lights
end
