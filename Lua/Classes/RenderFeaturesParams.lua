if FirstLoad then -- hopefully noone changes those before us, so we can fetch them safely
	ThreePointLightingDefaults = {}
	ThreePointLightingDefaults.KeyLightAngle = hr.KeyLightAngle
	ThreePointLightingDefaults.KeyLightDirX = hr.KeyLightDirX
	ThreePointLightingDefaults.KeyLightDirY = hr.KeyLightDirY
	ThreePointLightingDefaults.KeyLightDirZ = hr.KeyLightDirZ
	ThreePointLightingDefaults.KeyLightColor = hr.KeyLightColor
	ThreePointLightingDefaults.KeyLightIntensity = hr.KeyLightIntensity
	ThreePointLightingDefaults.FillLightAngle = hr.FillLightAngle
	ThreePointLightingDefaults.FillLightDirX = hr.FillLightDirX
	ThreePointLightingDefaults.FillLightDirY = hr.FillLightDirY
	ThreePointLightingDefaults.FillLightDirZ = hr.FillLightDirZ
	ThreePointLightingDefaults.FillLightColor = hr.FillLightColor
	ThreePointLightingDefaults.FillLightIntensity = hr.FillLightIntensity
	ThreePointLightingDefaults.BackLightAngle = hr.BackLightAngle
	ThreePointLightingDefaults.BackLightDirX = hr.BackLightDirX
	ThreePointLightingDefaults.BackLightDirY = hr.BackLightDirY
	ThreePointLightingDefaults.BackLightDirZ = hr.BackLightDirZ
	ThreePointLightingDefaults.BackLightColor = hr.BackLightColor
	ThreePointLightingDefaults.BackLightIntensity = hr.BackLightIntensity
	ThreePointLightingDefaults.TPLCameraAngle = hr.TPLCameraAngle
	ThreePointLightingDefaults.TPLCameraDirX = hr.TPLCameraDirX
	ThreePointLightingDefaults.TPLCameraDirY = hr.TPLCameraDirY
	ThreePointLightingDefaults.TPLCameraDirZ = hr.TPLCameraDirZ
end

DefineClass.ThreePointLighting = {
	__parents = {"PersistedRenderVars"},
	group = "ThreePointLightingRenderVars",
	StoreAsTable = false,
	PresetClass = "ThreePointLighting",
	EditorMenubarName = "ThreePointLighting",

	properties = {
		{ hr = true, name = "Angle",			id = "KeyLightAngle",		category = "Key Light",		editor = "number",	default = ThreePointLightingDefaults.KeyLightAngle,	read_only = true },
		{ hr = true, name = "Direction X", 	id = "KeyLightDirX", 		category = "Key Light", 	editor = "number", 	default = ThreePointLightingDefaults.KeyLightDirX, 	read_only = true },
		{ hr = true, name = "Direction Y", 	id = "KeyLightDirY", 		category = "Key Light", 	editor = "number", 	default = ThreePointLightingDefaults.KeyLightDirY, 	read_only = true },
		{ hr = true, name = "Direction Z", 	id = "KeyLightDirZ", 		category = "Key Light", 	editor = "number", 	default = ThreePointLightingDefaults.KeyLightDirZ,		read_only = true },
		{ hr = true, name = "Color", 			id = "KeyLightColor",		category = "Key Light",		editor = "color",	default = ThreePointLightingDefaults.KeyLightColor, 	alpha = false },	
		{ hr = true, name = "Intensity",		id = "KeyLightIntensity",	category = "Key Light", 	editor = "number", 	default = ThreePointLightingDefaults.KeyLightIntensity, slider = true, min = 0, max = 255, scale = 255 },

		{ hr = true, name = "Angle",			id = "FillLightAngle",		category = "Fill Light",	editor = "number",	default = ThreePointLightingDefaults.FillLightAngle,	read_only = true },
		{ hr = true, name = "Direction X",	id = "FillLightDirX", 		category = "Fill Light", 	editor = "number", 	default = ThreePointLightingDefaults.FillLightDirX,	read_only = true },
		{ hr = true, name = "Direction Y",	id = "FillLightDirY",		category = "Fill Light", 	editor = "number", 	default = ThreePointLightingDefaults.FillLightDirY,	read_only = true },
		{ hr = true, name = "Direction Z",	id = "FillLightDirZ", 		category = "Fill Light", 	editor = "number", 	default = ThreePointLightingDefaults.FillLightDirZ,	read_only = true },
		{ hr = true, name = "Color", 			id = "FillLightColor",		category = "Fill Light",	editor = "color",	default = ThreePointLightingDefaults.FillLightColor, 	alpha = false },	
		{ hr = true, name = "Intensity",		id = "FillLightIntensity",	category = "Fill Light",	editor = "number", 	default = ThreePointLightingDefaults.FillLightIntensity, slider = true, min = 0, max = 255, scale = 255 },
		
		{ hr = true, name = "Angle",			id = "BackLightAngle",		category = "Back Light",	editor = "number",	default = ThreePointLightingDefaults.BackLightAngle,	read_only = true },
		{ hr = true, name = "Direction X",	id = "BackLightDirX", 		category = "Back Light", 	editor = "number", 	default = ThreePointLightingDefaults.BackLightDirX,	read_only = true },
		{ hr = true, name = "Direction Y",	id = "BackLightDirY", 		category = "Back Light", 	editor = "number", 	default = ThreePointLightingDefaults.BackLightDirY,	read_only = true },
		{ hr = true, name = "Direction Z",	id = "BackLightDirZ", 		category = "Back Light", 	editor = "number", 	default = ThreePointLightingDefaults.BackLightDirZ,	read_only = true },
		{ hr = true, name = "Color", 			id = "BackLightColor",		category = "Back Light",	editor = "color",	default = ThreePointLightingDefaults.BackLightColor, 	alpha = false },	
		{ hr = true, name = "Intensity",		id = "BackLightIntensity",	category = "Back Light",	editor = "number", 	default = ThreePointLightingDefaults.BackLightIntensity, slider = true, min = 0, max = 255, scale = 255 },
	
		{				name = "View Type", 	id = "ViewType", 			category = "Camera", 		editor = "choice",	default = 2, items = { { text = "Disable", value = 0 }, { text = "Camera", value = 1 }, { text = "Reference", value = 2 } }, dont_save = true },
		{ hr = true, name = "Angle",			id = "TPLCameraAngle",		category = "Camera",		editor = "number",	default = ThreePointLightingDefaults.TPLCameraAngle,	read_only = true },
		{ hr = true, name = "Direction X",	id = "TPLCameraDirX",		category = "Camera",		editor = "number",	default = ThreePointLightingDefaults.TPLCameraDirX, 	read_only = true },
		{ hr = true, name = "Direction Y",	id = "TPLCameraDirY",		category = "Camera",		editor = "number",	default = ThreePointLightingDefaults.TPLCameraDirY, 	read_only = true },
		{ hr = true, name = "Direction Z",	id = "TPLCameraDirZ",		category = "Camera",		editor = "number",	default = ThreePointLightingDefaults.TPLCameraDirZ, 	read_only = true },
	},
	
	KeyLight = false,
	FillLight = false,
	BackLight = false,
	Camera = false,
	Model1 = false,
	Model2 = false,
}

DefineClass.TPLControlObj = {
	__parents = { "EditorVisibleObject", "EditorCallbackObject", "Object" },
	entity = "PointLight",
	Name = ""
}

if FirstLoad then
	g_TPLEditor = false
	g_LastViewType = 2
end

function TPLControlObj:Init()
	if IsEditorActive() then
		self:EditorEnter()
	else
		self:EditorExit()
	end
	self:SetScale(40)
	self:SetAxis(
		g_TPLEditor:GetProperty(self.Name .. "DirX"),
		g_TPLEditor:GetProperty(self.Name .. "DirY"),
		g_TPLEditor:GetProperty(self.Name .. "DirZ")
	)
	self:SetAngle(
		g_TPLEditor:GetProperty(self.Name .. "Angle")
	)
end

function TPLControlObj:EditorCallbackRotate()
	g_TPLEditor:SetProperty(self.Name .. "DirX", self:GetAxis():x())
	g_TPLEditor:SetProperty(self.Name .. "DirY", self:GetAxis():y())
	g_TPLEditor:SetProperty(self.Name .. "DirZ", self:GetAxis():z())
	g_TPLEditor:SetProperty(self.Name .. "Angle", self:GetAngle())
	g_TPLEditor:Apply()
	ObjModified(g_TPLEditor)
end

function OnMsg.AfterLightmodelChange(_, lightmodel, _, prev_lightmodel)
	if g_TPLEditor then
		g_TPLEditor:Apply()
	end
end

function ThreePointLighting:OnEditorSelect(selected)
	if selected then
		g_TPLEditor = self
		self:Apply()
		
		self.ViewType = g_LastViewType
		table.change(hr, "ThreePointLighting", {
			EnableThreePointLighting = self.ViewType
		})
		
		local central_pos = GetTerrainCursorXY(UIL.GetScreenSize()/2)
		self.KeyLight = PlaceObject("TPLControlObj", { Name = "KeyLight" })
		self.KeyLight:SetPos(central_pos + point(-2, -2, 1) * guim)
		local key_light_text = Text:new{ editor_ignore = true }
		key_light_text:SetText("Key Light")
		self.KeyLight:Attach(key_light_text)
		
		self.FillLight = PlaceObject("TPLControlObj", { Name = "FillLight" })
		self.FillLight:SetPos(central_pos + point(2, -2, 1) * guim)
		local fill_light_text = Text:new{ editor_ignore = true }
		fill_light_text:SetText("Fill Light")
		self.FillLight:Attach(fill_light_text)
		
		self.BackLight = PlaceObject("TPLControlObj", { Name = "BackLight" })
		self.BackLight:SetPos(central_pos + point(0, 8, 1) * guim)
		local back_light_text = Text:new{ editor_ignore = true }
		back_light_text:SetText("Back Light")
		self.BackLight:Attach(back_light_text)
		
		self.Camera = PlaceObject("TPLControlObj", { Name = "TPLCamera" })
		self.Camera:ChangeEntity("Camera")
		self.Camera:SetPos(central_pos + point(0, -2, 1) * guim)
		local camera_text = Text:new{ editor_ignore = true }
		camera_text:SetText("Camera")
		self.Camera:Attach(camera_text)
		
		local setup_model = function(model)
			model:SetAngle(-90 * 60)
			model:SetHierarchyGameFlags(const.gofUnitLighting)
		end
		
		self.Model1 = PlaceObject("AppearanceObject")
		self.Model1:ApplyAppearance("Barry")
		self.Model1:SetPos(central_pos + point(1, 0) * guim)
		self.Model1:SetAngle(-90 * 60)
		setup_model(self.Model1)
		self.Model2 = PlaceObject("AppearanceObject")
		self.Model2:ApplyAppearance("Buns")
		self.Model2:SetPos(central_pos + point(-1, 0) * guim)
		setup_model(self.Model2)
	else
		g_TPLEditor = false
		g_LastViewType = self.ViewType
		table.restore(hr, "ThreePointLighting")
		DoneObject(self.Camera)
		DoneObject(self.KeyLight)
		DoneObject(self.FillLight)
		DoneObject(self.BackLight)
		DoneObject(self.Model1)
		DoneObject(self.Model2)
		if LastSetLightmodel then
			SetLightmodel(1, LastSetLightmodel[1], 0)
		end
	end
end

function ThreePointLighting:SetViewType(value)
	self.ViewType = value	
	table.restore(hr, "ThreePointLighting")
	table.change(hr, "ThreePointLighting", {
		EnableThreePointLighting = value
	})
end