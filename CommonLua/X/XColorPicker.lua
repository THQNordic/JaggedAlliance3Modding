DefineClass.ColorPalette = {
	__parents = {"Preset"},
	properties = {
		{id = "Group", editor = false, }
	},

	EditorMenubar = "Editors.Art",
	EditorMenubarName = "Color Palette",
}

local color_palette_rows = 6
local color_palette_columns = 8
local color_palette_total = color_palette_rows * color_palette_columns

function ColorPalette:ColorsPlainObj()
	local obj = {}
	for i = 1, color_palette_total do
		local p = "color" .. i
		obj[p] = self[p]
	end
	for i = 1, color_palette_total do
		local p = "text" .. i
		obj[p] = self[p]
	end
	return obj
end

for i = 1, color_palette_total do
	local category = "Row" .. ((i - 1) / color_palette_columns) + 1
	table.insert(ColorPalette.properties, {
		id = "color" .. i,
		name = "Color " .. i,
		editor = "color",
		default = RGBA(0, 0, 0, 255),
		category = category,
	})
	table.insert(ColorPalette.properties, {
		id = "text" .. i,
		name = "Text " .. i,
		editor = "text",
		translate = false,
		default = "",
		category = category,
	})
end

if FirstLoad then
	CurrentColorPalette = false
end

function OnMsg.ClassesBuilt()
	CurrentColorPalette = CurrentColorPalette or ColorPalette:new({})
end

function OnMsg.DataLoaded()
	CurrentColorPalette = Presets.ColorPalette and Presets.ColorPalette.Default and Presets.ColorPalette.Default[1] or CurrentColorPalette
end

function ColorPalette:OnPostSave()
	CurrentColorPalette = Presets.ColorPalette and Presets.ColorPalette.Default and Presets.ColorPalette.Default[1] or CurrentColorPalette
end

--------------------- Color Picker code --------------------

local function GetColorMode(component)
	if component == "HUE" or component == "SATURATION" or component == "BRIGHTNESS"then
		return "HSV"
	end
	if component == "RED" or component == "GREEN" or component == "BLUE" then
		return "RGB"
	end
end

local ComponentShaderFlags = {
	["RED"]        = const.modColorPickerRed,
	["GREEN"]      = const.modColorPickerGreen,
	["BLUE"]       = const.modColorPickerBlue,
	["SATURATION"] = const.modColorPickerSaturation,
	["BRIGHTNESS"] = const.modColorPickerBrightness,
	["HUE"]        = const.modColorPickerHue,
	["ALPHA"]      = const.modColorPickerAlpha,
}

local function IsColorSame(a, b)
	return a.RED == b.RED and a.BLUE == b.BLUE and a.GREEN == b.GREEN and a.ALPHA == b.ALPHA
		and a.HUE == b.HUE and a.SATURATION == b.SATURATION and a.BRIGHTNESS == b.BRIGHTNESS
end

local function RecalculateHSVComponentsOf(color)
	local h, s, v
	if color.RED == 0 and color.GREEN == 0 and color.BLUE == 0 then
		h, s, v = 0, 0, 0
	else
		h, s, v = UIL.RGBtoHSV(MulDivRound(color.RED, 255, 1000), MulDivRound(color.GREEN, 255, 1000), MulDivRound(color.BLUE, 255, 1000))
	end
	
	color.HUE = MulDivRound(h, 1000, 255)
	color.SATURATION = MulDivRound(s, 1000, 255)
	color.BRIGHTNESS = MulDivRound(v, 1000, 255)
end

local function RecalculateRGBComponentsOf(color)
	-- hue 255 should be interpreted as 0
	local hue = MulDivRound(color.HUE, 255, 1000)
	if hue == 255 then hue = 0 end
	
	local r, g, b = UIL.HSVtoRGB(hue, MulDivRound(color.SATURATION, 255, 1000), MulDivRound(color.BRIGHTNESS, 255, 1000))
	color.RED = MulDivRound(r, 1000, 255)
	color.GREEN = MulDivRound(g, 1000, 255)
	color.BLUE = MulDivRound(b, 1000, 255)
end

local function GetRGBAComponentsIn255Of(color)
	return MulDivRound(color.RED, 255, 1000), MulDivRound(color.GREEN, 255, 1000), MulDivRound(color.BLUE, 255, 1000), MulDivRound(color.ALPHA, 255 , 1000)
end

function ConvertColorFromText(value, prefer_dec)
	local r, g, b, a = value:match("^([^,]+),([^,]+),([^,]+),([^,]+)")
	if not r then
		a = 255
		r, g, b = value:match("^([^,]+),([^,]+),([^,]+)")
	end
	if not r then
		local hex = value:match("^%s*0[xX]([0-9a-fA-F]+)")
		if not hex then
			hex = value:match("^%s*#([0-9a-fA-F]+)")
		end
		if hex and #hex > 0 then
			local hex_value = tonumber(hex, 16)
			if hex_value then
				r, g, b, a = GetRGBA(hex_value)
				if a == 0 and #hex <= 6 then
					a = 255
				end
			end
		end
	end
	if not r then
		local hex_value = tonumber(value, prefer_dec and 10 or 16)
		if hex_value then
			r, g, b, a = GetRGBA(hex_value)
		end
	end
	
	r, g, b, a = tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 0
	r = Clamp(r, 0, 255)
	g = Clamp(g, 0, 255)
	b = Clamp(b, 0, 255)
	a = Clamp(a, 0, 255)
	return RGBA(r, g, b, a)
end

DefineClass.XColorPicker = {
	__parents = { "XControl", "XActionsHost" },
	
	properties = {
		{ category = "General", id = "AdditionalComponent", editor = "choice", default = "none", items = {"none", "alpha", "intensity"} },
		{ category = "General", id = "ShowColorPalette", editor = "bool", default = true },
	},
	
	LayoutMethod = "HList",
	Padding = box(5, 5, 5, 5),
	BorderWidth = 1,
	BorderColor = RGB(32, 32, 32),
	Background = 0,
	FocusedBackground = 0,
	
	MaxHeight = 350,
	
	selected_checkbox = false,
	strip_color_component = false,
	current_color = false, -- table
	OnColorChanged = false,
	RolloverMode = false,
}

function XColorPicker:UpdateCurrentlySelectedPaletteColor()
	if not rawget(self, "PaletteGrid") then return end
	local current_color = RGB(GetRGB(self:GetColor()))
	for i = 1, color_palette_total do
		local ctrl =  self["idButtonColor" .. i]
		if RGB(GetRGB(ctrl.Background)) == current_color then
			ctrl.BorderColor = RGB(167, 167, 167)
		else
			ctrl.BorderColor = RGB(0, 0, 0)
		end
	end
end

function XColorPicker:Init(rollover_color_picker_mode)
	local gedapp = rawget(_G, "g_GedApp")
	local scale = (gedapp and gedapp.color_picker_scale or 100) * 10
	self:SetScaleModifier(point(scale, scale))

	self.current_color = {
		RED = 0,
		GREEN = 0,
		BLUE = 0,
		HUE = 0,
		SATURATION = 0,
		BRIGHTNESS = 0,
		ALPHA = 1000,
	}
	
	XColorSquare:new({
		Id = "idColorSquare",
		MinWidth = 200,
		MinHeight = 200,
		Margins = box(2, 2, 2, 2),
		Background = RGB(255, 255, 255),
		OnColorChanged = function(square, color, double_click)
			self:SetColorInternal(color)
			if double_click then
				self:Close()
			end
		end,
	}, self)

	XColorStrip:new({
		Id = "idColorStrip",
		MinWidth = 300,
		MinHeight = 45,
		slider_orientation = "horizontal",
		OnColorChanged = function(stripe, color) self:UpdateComponent(self.strip_color_component, color[self.strip_color_component]) end
	}, self):SetDock("bottom")
	
	XColorStrip:new({
		Id = "idAlphaStrip",
		MinWidth = 45,
		MinHeight = 200,
		Margins = box(2, 2, 2, 2),
		OnColorChanged = function(stripe, color) self:UpdateComponent("ALPHA", color.ALPHA) end
	}, self):SetVisible(self.AdditionalComponent ~= "none")
	if self.AdditionalComponent == "none" then
		self.idAlphaStrip:SetDock("ignore")
	end
	
	XWindow:new({
		Id = "idRightPanel",
		LayoutMethod = "VList",
		MinWidth = 150,
		MinHeight = 200,
		BorderColor = RGB(0, 0, 0),
		BorderWidth = 0,
		Padding = box(2, 0, 2, 0),
		Pargins = box(2, 0, 0, 0),
	}, self)

	local color_palette = gedapp and gedapp.color_palette or CurrentColorPalette or false
	XWindow:new({
		Id = "PaletteGrid",
		LayoutMethod = "VList",
		BorderColor = RGB(0, 0, 0),
		BorderWidth = 0,
		Padding = box(2, 2, 2, 2),
	}, self.idRightPanel)
	for y = 1, color_palette_rows do
		local row = XWindow:new({
			LayoutMethod = "HList",
		}, self.PaletteGrid)
		for x = 1, color_palette_columns do
			local color_idx = (x + (y - 1) * color_palette_columns)
			local color = color_palette and color_palette["color" .. color_idx] or RGB(255,255,255)
			local text = color_palette and color_palette["text" .. color_idx] or ""
			XButton:new({
				Id = "idButtonColor" .. color_idx,
				Background = color,
				RolloverBackground = color,
				PressedBackground = color,
				MinWidth = 30,
				MinHeight = 20,
				BorderColor = RGB(0, 0, 0),
				RolloverBorderColor = RGB(32, 32, 32),
				PressedBorderColor = RGB(64, 64, 64),
				BorderWidth = 2,
				Margins = box(2, 2, 2, 2),
				OnPress = function()
					self:SetColor(color)
				end,
				RolloverTranslate = false,
				RolloverTemplate = "GedPropRollover",
				RolloverTitle = text,
				RolloverText = text,
			}, row)
		end
	end
	self:UpdateCurrentlySelectedPaletteColor()
	
	XWindow:new({
		Id = "idInputs",
		LayoutMethod = "HPanel",
		VAlign = "center",
		HAlign = "center",
		MinWidth = 300,
		MinHeight = 200,
		Padding = box(4, 2, 4, 2),
		Background = RGBA(0, 0, 0, 0),
	}, self.idRightPanel)

	local left_inputs = XWindow:new({
		Id = "left",
		LayoutMethod = "VList",
		MinWidth = 150,
	}, self.idInputs)
	local right_inputs = XWindow:new({
		Id = "right",
		LayoutMethod = "VList",
		MinWidth = 150,
	}, self.idInputs)

	local hue_checkbox = self:MakeComponent({
		idEdit = "idHue",
		ComponentId = "HUE",
		Name = "H",
		Suffix = "°",
		Max = 360,
		focus_order = point(0, 0),
		parent = left_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 360)) end,
	})
	
	self:MakeComponent({
		idEdit = "idSat",
		ComponentId = "SATURATION",
		Name = "S",
		Suffix = "%",
		Max = 100,
		focus_order = point(0, 1),
		parent = left_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 100)) end,
	})
	
	self:MakeComponent({
		idEdit = "idBri",
		ComponentId = "BRIGHTNESS",
		Name = "B",
		Suffix = "%",
		Max = 100,
		focus_order = point(0, 2),
		parent = left_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 100)) end,
	})

	self:MakeComponent({
		idEdit = "idRed",
		ComponentId = "RED",
		Name = "R",
		Max = 255,
		focus_order = point(0, 3),
		parent = right_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 255))  end,
		Selectable = true,
	})
	
	self:MakeComponent({
		idEdit = "idGreen",
		ComponentId = "GREEN",
		Name = "G",
		Max = 255,
		focus_order = point(0, 4),
		parent = right_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 255))  end,
	})
	
	self:MakeComponent({
		idEdit = "idBlue",
		ComponentId = "BLUE",
		Name = "B",
		Max = 255,
		focus_order = point(0, 5),
		parent = right_inputs,
		OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 255))  end,
	})
	
	if self.AdditionalComponent ~= "none" then
		self:MakeComponent({
			idEdit = "idAlpha",
			parent = right_inputs,
			ComponentId = "ALPHA",
			Name = self.AdditionalComponent == "alpha" and "A" or "I",
			Max = 255,
			VSpacing = 0,
			Selectable = false,
			focus_order = point(0, 6),
			OnValueEdited = function(component_id, number) self:UpdateComponent(component_id, MulDivRound(number, 1000, 255))  end,
		})
	end

	local bottom_left = XWindow:new({
	}, left_inputs)
	
	local hex_value = XEdit:new({
		Id = "idHexView",
		HAlign = "stretch",
		VAlign = "center",
	}, bottom_left)
	
	hex_value:SetText("0xFFFFFFFF")
	local function RefetchHexValue()
		local color_text = hex_value:GetText()
		local color = ConvertColorFromText(color_text)
		if color and color ~= self:GetColor() then
			self:SetColor(color)
		end
	end
	hex_value.OnKillFocus = function(self, ...)
		RefetchHexValue()
		return XEdit.OnKillFocus(self, ...)
	end
	hex_value.OnShortcut = function(self, shortcut, ...)
		if shortcut == "Enter" then
			RefetchHexValue()
			return "break"
		end
		return XEdit.OnShortcut(self, shortcut, ...)
	end

	hex_value:SetAutoSelectAll(true)

	if self.RolloverMode then
		local button = XTemplateSpawn("GedToolbarButton", bottom_left)
		button:SetDock("left")
		button:SetHAlign("left")
		button:SetVAlign("center")
		button:SetIcon("CommonAssets/UI/Ged/filter.tga")
		button:SetRolloverText("Pick color from game")
		button.OnPress = function(b)
			self.RolloverMode()
			self:Done()
		end
	end
	
	self:SetStripComponent("HUE", hue_checkbox)
	self:UpdateDisplayedComponents()
end

function XColorPicker:UpdateComponent(component_id, value)
	local new_color = table.copy(self.current_color)
	new_color[component_id] = value
	
	-- recalculate others fields that might have changed
	local colorMode = GetColorMode(component_id)
	if colorMode == "RGB" then
		RecalculateHSVComponentsOf(new_color)
	elseif colorMode == "HSV" then
		RecalculateRGBComponentsOf(new_color)
	end
	self:SetColorInternal(new_color)
end

function XColorPicker:SetColorInternal(color)
	if not IsColorSame(self.current_color, color) then
		self.current_color = color
		if self.OnColorChanged then
			self:OnColorChanged(RGBA(GetRGBAComponentsIn255Of(color)))
		end
		self:UpdateDisplayedComponents()
		self.idColorSquare:SetColor(color)
		self.idColorStrip:SetColor(color)
		self.idAlphaStrip:SetColor(color)

		self:UpdateCurrentlySelectedPaletteColor()
	end
end

function XColorPicker:GetColor()
	return RGBA(GetRGBAComponentsIn255Of(self.current_color))
end

function XColorPicker:SetColor(color)
	color = color or RGBA(0, 0, 0, 0)
	local r, g, b, a = GetRGBA(color)
	local new_color = {
		RED = MulDivRound(r, 1000, 255),
		GREEN = MulDivRound(g, 1000, 255),
		BLUE = MulDivRound(b, 1000, 255),
		ALPHA = MulDivRound(a, 1000, 255),
	}
	RecalculateHSVComponentsOf(new_color)
	self:SetColorInternal(new_color)
end

function XColorPicker:UpdateDisplayedComponents()
	local color = self.current_color
	self.idHue:SetText(tostring(MulDivRound(color.HUE, 360, 1000)))
	self.idSat:SetText(tostring(MulDivRound(color.SATURATION, 1, 10)))
	self.idBri:SetText(tostring(MulDivRound(color.BRIGHTNESS, 1, 10)))
	self.idRed:SetText(tostring(MulDivRound(color.RED, 255, 1000)))
	self.idGreen:SetText(tostring(MulDivRound(color.GREEN, 255, 1000)))
	self.idBlue:SetText(tostring(MulDivRound(color.BLUE, 255, 1000)))
	self.idHexView:SetText(string.format("0x%08X", self:GetColor()))
	if self.AdditionalComponent ~= "none" then
		self.idAlpha:SetText(tostring(MulDivRound(color.ALPHA, 255, 1000)))
	end
end

function XColorPicker:SetStripComponent(id, control)
	if self.selected_checkbox then
		self.selected_checkbox:SetCheck(false)
	end
	control:SetCheck(true)
	self.selected_checkbox = control
	
	self.strip_color_component = id
	self.idColorSquare:SetConstantColorComponent(id)
	self.idColorStrip:SetEditedColorComponent(id)
	self.idAlphaStrip:SetEditedColorComponent("ALPHA")
	
	self:UpdateDisplayedComponents()
end

function XColorPicker:MakeComponent(params)
	params.Min = params.Min or 0
	params.Max = params.Max or 255
	params.Selectable = params.Selectable ~= false

	local parent = XWindow:new({
		Margins = box(0, 0, 0, params.VSpacing or 10),
	}, params.parent)
	
	local check_box = XCheckButton:new({
		Dock = "left",
		VAlign = "center",
		OnChange = function(control, check)
			self:SetStripComponent(params.ComponentId, control)
		end,
	}, parent)
	
	if not params.Selectable then
		check_box:SetVisible(false)
	end

	XLabel:new({
		Dock = "left",
		VAlign = "center",
	}, parent):SetText(params.Name .. ":")
	
	XLabel:new({
		Dock = "right",
		VAlign = "center",
		MinWidth = 25,
	}, parent):SetText(params.Suffix or "")
	
	CreateNumberEditor(
		XWindow:new({
			Dock = "box",
			VAlign = "center",
		}, parent),
		params.idEdit,
		function(multiplier)
			local value = tonumber(self[params.idEdit]:GetText()) or 0
			params.OnValueEdited(params.ComponentId, Clamp(value + multiplier, params.Min, params.Max))
		end,
		function(multiplier)
			local value = tonumber(self[params.idEdit]:GetText()) or 0
			params.OnValueEdited(params.ComponentId, Clamp(value - multiplier, params.Min, params.Max))
		end
	)
	local edit_control = self[params.idEdit]
	edit_control:SetFocusOrder(params.focus_order or point(0, 0))
	edit_control.OnKillFocus = function(self)
		if self then
			local value = tonumber(edit_control:GetText()) or 0
			params.OnValueEdited(params.ComponentId, Clamp(value, params.Min, params.Max))
			XEdit.OnKillFocus(self)
		end
	end
	
	return check_box
end


---- Strip color picker

DefineClass.XColorStrip = {
	__parents = { "XControl" },
	
	Padding = box(2, 2, 2, 2),
	BorderWidth = 1,
	BorderColor = RGBA(32, 32, 32, 255),
	Background = RGBA(0, 0, 0, 0),
	
	slider_orientation = "vertical",
	slider_color = RGB(32, 32, 32),
	slider_size = point(10, 20),
	slider_image_right = "CommonAssets/UI/arrowright-40.tga",
	slider_image_left = "CommonAssets/UI/arrowleft-40.tga",
	slider_image_down = "CommonAssets/UI/arrowdown-40.tga",
	slider_image_up = "CommonAssets/UI/arrowup-40.tga",
	slider_image_srect = box(0, 0, 16, 40),
	slider_image_srect_horizontal = box(0, 0, 40, 16),
	strip_background_image = "CommonAssets/UI/checker-pattern-40.tga",
	gradient_modifier = false,
	strip_color_component = false,
	current_color = false, -- table
	OnColorChanged = false,
}

function XColorStrip:Init()
	self.current_color = {
		RED = 0,
		GREEN = 0,
		BLUE = 0,
		HUE = 0,
		SATURATION = 0,
		BRIGHTNESS = 0,
		ALPHA = 1000,
	}
	self.gradient_modifier = self:AddShaderModifier({
		modifier_type = const.modShader,
	})
end

function XColorStrip:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.desktop:SetMouseCapture(self)
		self:OnMousePos(pt)
		return "break"
	end
end

function XColorStrip:OnMouseButtonUp(pt, button)
	if button == "L" then
		self:OnMousePos(pt)
		self.desktop:SetMouseCapture()
		return "break"
	end
end

function XColorStrip:OnMousePos(pt)
	if self.desktop:GetMouseCapture() ~= self then return "break" end
	
	local content_box = self.content_box
	local percent
	if self.slider_orientation == "vertical" then
		percent = 1000 - Clamp(MulDivRound(pt:y() - content_box:miny(), 1000, content_box:sizey()), 0, 1000)
	else
		percent = 1000 - Clamp(MulDivRound(pt:x() - content_box:minx(), 1000, content_box:sizex()), 0, 1000)
	end

	local new_color = table.copy(self.current_color)
	new_color[self.strip_color_component] = percent
	if GetColorMode(self.strip_color_component) == "RGB" then
		RecalculateHSVComponentsOf(new_color)
	else
		RecalculateRGBComponentsOf(new_color)
	end

	self:SetColor(new_color)
	if self.OnColorChanged then
		self:OnColorChanged(new_color)
	end
	
	self:Invalidate()
	return "break"
end

function XColorStrip:SetColor(color)
	if not IsColorSame(self.current_color, color) then
		self.current_color = color
		self:UpdateGradientModifier()
	end
end

function XColorStrip:SetEditedColorComponent(component)
	if self.strip_color_component ~= component then
		self.strip_color_component = component
		self:UpdateGradientModifier()
	end
end

function XColorStrip:GetEditedColorComponent()
	return self.current_color[self.strip_color_component]
end

function XColorStrip:UpdateGradientModifier()
	self.gradient_modifier.shader_flags = const.modColorPickerStrip | ComponentShaderFlags[self.strip_color_component]
	local modifier = self.gradient_modifier
	local color = self.current_color
	if GetColorMode(self.strip_color_component) == "RGB" or self.strip_color_component == "ALPHA" then
		modifier[1] = color.RED
		modifier[2] = color.GREEN
		modifier[3] = color.BLUE
		modifier[4] = color.ALPHA
	elseif self.strip_color_component == "HUE" then
		modifier[1] = 1000
		modifier[2] = 1000
		modifier[3] = 1000
		modifier[4] = 1000
	else
		modifier[1] = color.HUE
		modifier[2] = color.SATURATION
		modifier[3] = color.BRIGHTNESS
		modifier[4] = color.ALPHA
	end
	self:Invalidate()
end

local PushClipRect = UIL.PushClipRect
local PopClipRect = UIL.PopClipRect

function XColorStrip:ArrowsSize()
	local arrows_size = point(ScaleXY(self.scale, self.slider_size:x(), self.slider_size:y()))
	if self.slider_orientation ~= "vertical" then
		arrows_size = point(arrows_size:y(), arrows_size:x())
	end
	return arrows_size
end

function XColorStrip:GetStripBox()
	local arrows_size = self:ArrowsSize()
	local content_box = self.content_box
	local strip_box
	if self.slider_orientation == "vertical" then
		strip_box = box(content_box:minx() + arrows_size:x(), content_box:miny(), content_box:maxx() - arrows_size:x(), content_box:maxy())
	else
		strip_box = box(content_box:minx(), content_box:miny() + arrows_size:y(), content_box:maxx(), content_box:maxy() - arrows_size:y())
	end
	return strip_box
end

-- DrawContent is called with modifiers enabled so the solid rect will actually be a gradient
function XColorStrip:DrawContent(clip_box)
	local strip_box = self:GetStripBox()
	if self.slider_orientation == "vertical" then
		UIL.DrawSolidRect(strip_box, RGBA(255, 255, 255, 255), RGBA(0, 0, 0, 0), point(1000, 1000), point(0, 0))
	else
		-- we use drawimagefit as it has all the properties we need, checker-pattern-40 is loaded anyway for the background.
		local w, h = UIL.MeasureImage("CommonAssets/UI/checker-pattern-40.tga")
		local center = strip_box:min() + strip_box:size() / 2
		local top_left = center - point(strip_box:sizey() / 2, strip_box:sizex() / 2)
		local rotated_box = sizebox(top_left:x(), top_left:y(), strip_box:sizey(), strip_box:sizex())
		UIL.DrawImageFit("CommonAssets/UI/checker-pattern-40.tga", rotated_box, rotated_box:sizex(), rotated_box:sizey(), box(0,0,w,h), RGB(255,255,255),
			0, --[[angle]] 90 * 60, --[[flips]] false, false)
	end
end

function XColorStrip:DrawBackground()
end

function XColorStrip:DrawWindow(clip_box)
	local content_box = self.content_box
	local arrows_size = self:ArrowsSize()
	
	-- draw the checkers background for alpha values
	local strip_box = self:GetStripBox()
	UIL.DrawFrame(self.strip_background_image, strip_box, 1, 1, 1, 1, box(0, 0, 0, 0), false, false, 350, 350, false, false)
	
	-- draw gradient
	XWindow.DrawWindow(self, clip_box)
	
	-- draw border
	local border_width, border_height = ScaleXY(self.scale, self.BorderWidth, self.BorderWidth)
	local border_box = GrowBox(strip_box, border_width)
	UIL.DrawBorderRect(border_box, border_width, border_height, self:CalcBorderColor(), RGBA(0, 0, 0, 0))

	-- draw the selection
	local weight = 1000 - Clamp(self:GetEditedColorComponent(), 0, 1000)
	if self.slider_orientation == "vertical" then
		local sliderY = content_box:miny() + MulDivRound(weight, content_box:sizey(), 1000)

		local left_arrow = sizebox(content_box:minx(), sliderY - arrows_size:y() / 2, arrows_size:x(), arrows_size:y())
		local right_arrow = sizebox(content_box:maxx() - arrows_size:x(), sliderY - arrows_size:y() / 2, arrows_size:x(), arrows_size:y())
		
		UIL.DrawImageFit(self.slider_image_right, left_arrow, arrows_size:x(), arrows_size:y(), self.slider_image_srect, self.slider_color, 0)
		UIL.DrawImageFit(self.slider_image_left, right_arrow, arrows_size:x(), arrows_size:y(), self.slider_image_srect, self.slider_color, 0)
	else
		local sliderX = content_box:minx() + MulDivRound(weight, content_box:sizex(), 1000)

		local up_arrow = sizebox(sliderX - arrows_size:x() / 2, content_box:miny(), arrows_size:x(), arrows_size:y())
		local down_arrow = sizebox(sliderX - arrows_size:x() / 2, content_box:maxy() - arrows_size:y(), arrows_size:x(), arrows_size:y())
		
		UIL.DrawImageFit(self.slider_image_down, up_arrow, arrows_size:x(), arrows_size:y(), self.slider_image_srect_horizontal, self.slider_color, 0)
		UIL.DrawImageFit(self.slider_image_up, down_arrow, arrows_size:x(), arrows_size:y(), self.slider_image_srect_horizontal, self.slider_color, 0)
	end
end


--- Square color picker

DefineClass.XColorSquare = {
	__parents = { "XControl" },
	
	Clip = "parent & self",
	Padding = box(2, 2, 2, 2),
	BorderWidth = 1,
	BorderColor = RGB(32, 32, 32),
	Background = RGB(255, 255, 255),
	
	slider_color = RGB(128, 128, 128),
	slider_size = point(20, 20),
	slider_image = "CommonAssets/UI/circle-20.tga",
	gradient_modifier = false,
	constant_color_component = false,
	edited_component_id1 = false,
	edited_component_id2 = false,
	current_color = false, -- table
	OnColorChanged = false,
}

function XColorSquare:Init()
	self.current_color = {
		RED = 0,
		GREEN = 0,
		BLUE = 0,
		HUE = 0,
		SATURATION = 0,
		BRIGHTNESS = 0,
		ALPHA = 1000,
	}
	self.gradient_modifier = self:AddShaderModifier({
		modifier_type = const.modShader,
	})
end

function XColorSquare:Measure(max_width, max_height)
	local size = Min(max_width, max_height)
	return size, size
end

function XColorSquare:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.desktop:SetMouseCapture(self)
		self:OnMousePos(pt)
		return "break"
	end
end

function XColorSquare:OnMouseButtonUp(pt, button)
	if button == "L" then
		self:OnMousePos(pt)
		self.desktop:SetMouseCapture()
		return "break"
	end
end

function XColorSquare:OnMousePos(pt)
	if self.desktop:GetMouseCapture() ~= self then return "break" end
	local content_box = self.content_box
		
	local percent_x = 1000 - Clamp((pt:x() - content_box:minx()) * 1000 / content_box:sizex(), 0, 1000)
	local percent_y = 1000 - Clamp((pt:y() - content_box:miny()) * 1000 / content_box:sizey(), 0, 1000)
		
	local new_color = table.copy(self.current_color)
	new_color[self.edited_component_id1] = percent_x
	new_color[self.edited_component_id2] = percent_y
	if GetColorMode(self.constant_color_component) == "RGB" then
		RecalculateHSVComponentsOf(new_color)
	else
		RecalculateRGBComponentsOf(new_color)
	end
	
	self:SetColor(new_color)
	if self.OnColorChanged then
		self:OnColorChanged(new_color)
	end
	
	return "break"
end

function XColorSquare:OnMouseButtonDoubleClick(pt, button)
	if self.OnColorChanged then
		self:OnColorChanged(self.current_color, true)
	end
	return "break"
end

function XColorSquare:SetColor(color)
	if not IsColorSame(self.current_color, color) then
		self.current_color = color
		self:UpdateGradientModifier()
	end
end

function XColorSquare:SetConstantColorComponent(component)
	if self.constant_color_component ~= component then
		self.constant_color_component = component
		if component == "RED" then
			self.edited_component_id1, self.edited_component_id2 = "GREEN", "BLUE"
		elseif component == "GREEN" then
			self.edited_component_id1, self.edited_component_id2 = "RED", "BLUE"
		elseif component == "BLUE" then
			self.edited_component_id1, self.edited_component_id2 = "RED", "GREEN"
		elseif component == "HUE" then
			self.edited_component_id1, self.edited_component_id2 = "SATURATION", "BRIGHTNESS"
		elseif component == "SATURATION" then
			self.edited_component_id1, self.edited_component_id2 = "HUE", "BRIGHTNESS"
		elseif component == "BRIGHTNESS" then
			self.edited_component_id1, self.edited_component_id2 = "HUE", "SATURATION"
		end
		self:UpdateGradientModifier()
	end
end

function XColorSquare:GetEditedColorComponents()
	return self.current_color[self.edited_component_id1], self.current_color[self.edited_component_id2]
end

function XColorSquare:UpdateGradientModifier()
	self.gradient_modifier.shader_flags = const.modColorPickerSquare | ComponentShaderFlags[self.constant_color_component]
	local modifier = self.gradient_modifier
	local color = self.current_color
	if GetColorMode(self.constant_color_component) == "RGB" then
		modifier[1] = color.RED
		modifier[2] = color.GREEN
		modifier[3] = color.BLUE
		modifier[4] = color.ALPHA
	else
		modifier[1] = color.HUE
		modifier[2] = color.SATURATION
		modifier[3] = color.BRIGHTNESS
		modifier[4] = color.ALPHA
	end
end

function XColorSquare:DrawBackground()
end

function XColorSquare:DrawContent(clip_rect)
	UIL.DrawSolidRect(self.content_box, RGBA(255, 255, 255, 255), RGBA(0, 0, 0, 0), point(1000, 1000), point(0, 0))
end

function XColorSquare:DrawWindow(clip_rect)
	-- draw the gradient
	XWindow.DrawWindow(self, clip_rect)
	
	local content_box = self.content_box
	
	-- draw border
	local border_width, border_height = ScaleXY(self.scale, self.BorderWidth, self.BorderWidth)
	local border_box = GrowBox(content_box, border_width)
	UIL.DrawBorderRect(border_box, border_width, border_height, self:CalcBorderColor(), RGBA(0, 0, 0, 0))
	
	-- draw the selection
	PushClipRect(content_box, true)
	local x, y = self:GetEditedColorComponents()
	local weight_x = 1000 - Clamp(x, 0, 1000)
	local weight_y = 1000 - Clamp(y, 0, 1000)
	
	local slider_pos = point(content_box:minx() + weight_x * content_box:sizex() / 1000, content_box:miny() + weight_y * content_box:sizey() / 1000)
	local slider_size = point(ScaleXY(self.scale, self.slider_size:x(), self.slider_size:y()))
	local slider_box = sizebox(slider_pos - slider_size / 2, slider_size)

	local circle_color = self.current_color.BRIGHTNESS < 500 and RGB(200, 200, 200) or RGB(32, 32, 32)
	UIL.DrawImageFit(self.slider_image, slider_box, slider_size:x(), slider_size:y(), box(0, 0, self.slider_size:x(), self.slider_size:y()), circle_color, 0)
	PopClipRect()
end