local UIL = UIL

DefineClass.XImage = {
	__parents = { "XControl" },
	
	properties = {
		{ category = "Image", id = "Image", editor = "ui_image", default = "", },
		{ category = "Image", id = "ImageFit", name = "Fit", editor = "choice", default = "none", items = {"none", "width", "height", "smallest", "largest", "stretch", "stretch-x", "stretch-y", "scale-down"}, invalidate = "measure", },
		{ category = "Image", id = "Rows", editor = "number", default = 1, },
		{ category = "Image", id = "Columns", editor = "number", default = 1, },
		{ category = "Image", id = "Row", editor = "number", default = 1, },
		{ category = "Image", id = "Column", editor = "number", default = 1, },
		{ category = "Image", id = "ImageRect", name = "Custom rect", editor = "rect", default = box(0, 0, 0, 0), help = "Overrides the columns/rows and allows defining a custom rect from the image", },
		{ category = "Image", id = "ImageScale", name = "Scale", editor = "point2d", default = point(1000, 1000), help = "Used when the image is not resized (ImageFit equals 'none')", invalidate = true, lock_ratio = true, },
		{ category = "Image", id = "ImageColor", name = "Image color", editor = "color", default = RGB(255, 255, 255), invalidate = true, },
		{ category = "Image", id = "DisabledImageColor", name = "Disabled image color", editor = "color", default = RGBA(255, 255, 255, 160), invalidate = true, },
		{ category = "Image", id = "Desaturation", editor = "number", default = 0, min = 0, max = 255, slider = true, invalidate = true, },
		{ category = "Image", id = "DisabledDesaturation", editor = "number", default = 255, min = 0, max = 255, slider = true, invalidate = true, },
		{ category = "Image", id = "Angle",  editor = "number", default = 0, min = 0, max = 360*60 - 1, slider = true, scale = "deg", invalidate = true, },
		{ category = "Image", id = "AdditiveMode", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "FlipX", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "FlipY", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "EffectPixels", editor = "number", default = 0, invalidate = true, min = 0, max = 32, slider = true, },
		{ category = "Image", id = "EffectColor", editor = "color", default = RGB(255, 255, 255), invalidate = true },
		{ category = "Image", id = "EffectType", editor = "choice", default = "none", items = {"none", "glow", "outline" }, invalidate = true },
		{ category = "Image", id = "BaseColorMap", editor = "bool", default = false, help = "Use to display the base color map of a material in the UI", invalidate = true, },

		{ category = "Image", id = "FrameEdgeColor", editor = "color", default = RGBA(0,0,0,0), invalidate = true, },
		{ category = "Image", id = "FrameLeft", editor = "number", default = 0, invalidate = true, },
		{ category = "Image", id = "FrameTop", editor = "number", default = 0, invalidate = true, },
		{ category = "Image", id = "FrameRight", editor = "number", default = 0, invalidate = true, },
		{ category = "Image", id = "FrameBottom", editor = "number", default = 0, invalidate = true, },

		{ category = "Animation", id = "Animate", editor = "bool", default = false, invalidate = true, },
		{ category = "Animation", id = "FPS", editor = "number", default = 10, invalidate = true, },
		{ category = "Animation", id = "AnimFlags", name = "Flags", editor = "set", default = set("looping"), items = { "looping", "ping-pong", "inverse", "back to start" }, },
		{ category = "Animation", id = "AnimDuration", name = "Duration", editor = "number", default = 0 },
	},

	HandleMouse = false,
	animation = false, -- cached animation transition table
	src_rect = false,
	image_id = const.InvalidResourceID,
	image_obj = false,
}

function XImage:Init()
	self:UpdateModifiers()
	self:SetImage(self.Image, true)
end

function XImage:Done()
	if self.image_obj ~= false then
		self.image_obj:ReleaseRef()
		self.image_obj = false
	end
end

function XImage:SetImage(image, force)	
	if self.Image == (image or "") and not force then return end	
	self.Image = image or nil
	
	self:DeleteThread("LoadImage")
	if (self.Image or "") == "" then
		return
	end
	
	if self.image_obj ~= false then
		self.image_obj:ReleaseRef()
		self.image_obj = false
	end
	
	self.image_id = ResourceManager.GetResourceID(self.Image)
	if self.image_id == const.InvalidResourceID then
		printf("once", "Could not load image %s!", self.Image or "")
		return
	end
	
	self.image_obj = ResourceManager.GetResource(self.image_id)
	if self.image_obj then
		local old_rect = self.src_rect
		self.src_rect = false
		if self:CalcSrcRect() ~= old_rect then
			self:InvalidateMeasure()
		end
		self:Invalidate()
	else
		self:CreateThread("LoadImage", function(self)
			self.image_obj = AsyncGetResource(self.image_id)
			local old_rect = self.src_rect
			self.src_rect = false
			if self:CalcSrcRect() ~= old_rect then
				self:InvalidateMeasure()
			end
			self:Invalidate()
		end, self)
	end
end

function XImage:SetRows(rows)
	if self.Rows == rows then return end
	self.Rows = rows
	self.src_rect = false
	self:InvalidateMeasure()
	self:Invalidate()
end

function XImage:SetColumns(columns)
	if self.Columns == columns then return end
	self.Columns = columns
	self.src_rect = false
	self:InvalidateMeasure()
	self:Invalidate()
end

function XImage:SetRow(row)
	if self.Row == row then return end
	self.Row = row
	self.src_rect = false
	self:Invalidate()
end

function XImage:SetColumn(column)
	if self.Column == column then return end
	self.Column = column
	self.src_rect = false
	self:Invalidate()
end

local anim_flags_set = {
	["looping"] = const.intfLooping,
	["ping-pong"] = const.intfPingPong,
	["inverse"] = const.intfInverse,
	["back to start"] = const.intfBackToStart,
}

function AnimFlagsSetToInt(st)
	local flags = 0
	for k,v in pairs(anim_flags_set) do
		if st[k] then
			flags = flags | v
		end
	end
	return flags
end

function XImage:SetAnimate(b)
	if self.Animate == b then return end
	self.Animate = b
	if b then
		self.animation = {
			modifier_type = const.modInterpolation,
			type     = const.intAnimate,
			start    = GetPreciseTicks(), 
			fps      = self.FPS, -- if nonzero, this will set duration based on the number of frames
			columns  = self.Columns, 
			rows     = self.Rows,
			flags    = AnimFlagsSetToInt(self.AnimFlags),
			duration = 1000,
			easing   = "Linear",
		}
	else
		self.animation = false
	end
	self:Invalidate()
end

function XImage:SetAnimFlags(f)
	if self.AnimFlags == f then return end
	self.AnimFlags = f
	if self.animation then
		self.animation.flags = AnimFlagsSetToInt(f)
	end
	self:Invalidate()
end

function XImage:SetFPS(fps)
	if self.FPS == fps then return end
	self.FPS = fps
	if self.animation then
		self.animation.fps = self.FPS
		if self.FPS > 0 then
			self.animation.duration = 1000 -- will be ignored anyway, set to preserve existing behavior
		end
	end
	self:Invalidate()
end

function XImage:SetAnimDuration(duration)
	if self.AnimDuration == duration then return end
	self.AnimDuration = duration
	if self.animation then
		self.animation.duration = self.AnimDuration
		if self.AnimDuration > 0 then
			self.animation.fps = 0 -- if FPS is nonzero, Duration is ignored and calculated from FPS and number of frames in animation
		end
	end
	self:Invalidate()
end

function XImage:SetImageRect(rect)
	if self.ImageRect == rect then return end
	self.ImageRect = rect
	self.src_rect = false
	self:Invalidate()
end

function XImage:CalcSrcRect()
	local rect = self.src_rect
	if not rect then
		rect = self.ImageRect
		if rect:IsEmpty() then
			if self.image_id ~= const.InvalidResourceID then
				local w, h = ResourceManager.GetMetadataTextureSizeXY(self.image_id)
				w = w / self.Columns
				h = h / self.Rows
				local column = Clamp(self.Column, 1, self.Columns) - 1
				local row = Clamp(self.Row, 1, self.Rows) - 1
				rect = sizebox(w * column, h * row, w, h)
			else
				rect = box(0, 0, 0, 0)
			end
		end
		self.src_rect = rect
	end
	return rect
end

function XImage:CalcDesaturation()
	return self:GetEnabled() and self.Desaturation or self.DisabledDesaturation
end

local function FitImage(max_width, max_height, width, height, fit)
	if width == 0 or height == 0 then return 0, 0 end
	if fit == "smallest" or fit == "largest" then
		local image_is_wider = width * max_height >= max_width * height
		fit = image_is_wider == (fit == "smallest") and "width" or "height"
	end
	if fit == "width" then
		return max_width, MulDivRound(height, max_width, width)
	elseif fit == "height" then
		return MulDivRound(width, max_height, height), max_height
	elseif fit == "stretch" then
		return max_width, max_height
	elseif fit == "stretch-x" then
		return max_width, height
	elseif fit == "stretch-y" then
		return width, max_height
	elseif fit == "scale-down" then
		local scale = Min(1000, Min(MulDivRound(max_width, 1000, width), MulDivRound(max_height, 1000, height)))
		return MulDivRound(width, scale, 1000), MulDivRound(height, scale, 1000)
	else -- fit == "none"
		return width, height
	end
end

function XImage:Measure(preferred_width, preferred_height)
	if self.ImageFit == "stretch" then
		return XControl.Measure(self, preferred_width, preferred_height)
	end
	local image_width, image_height = ScaleXY(self.scale, ScaleXY(self.ImageScale, self:CalcSrcRect():sizexyz()))
	if self.Angle == 90*60 or self.Angle == 270*60 then
		image_width, image_height = image_height, image_width
	end
	image_width, image_height = FitImage(preferred_width, preferred_height, image_width, image_height, self.ImageFit)
	local width, height = XControl.Measure(self, preferred_width, preferred_height)
	local fit = self.ImageFit
	if fit ~= "stretch" and fit ~= "stretch-x" then
		width = Max(image_width, width)
	end
	if fit ~= "stretch" and fit ~= "stretch-y" then
		height = Max(image_height, height)
	end
	return width, height
end

function XImage:UpdateModifiers()
	self:RemoveModifiers(const.modShader)
	if self.BaseColorMap then
		self:AddShaderModifier({
			modifier_type = const.modShader,
			shader_flags = const.modIgnoreAlpha,
		})
	end
end

function XImage:SetBaseColorMap(value)
	if self.BaseColorMap ~= value then
		self.BaseColorMap = value
		self:UpdateModifiers()
		self:Invalidate()
	end
end

function XImage:DrawContent()
	if self.Image == "" then return end
	if self.AdditiveMode then
		UIL.SetBlendMode("blendAdditive")
	end
	local src = self:CalcSrcRect()
	local width, height = ScaleXY(self.scale, ScaleXY(self.ImageScale, src:sizexyz()))
	local b = self.content_box
	width, height = FitImage(b:sizex(), b:sizey(), width, height, self.ImageFit)
	local color = self:GetEnabled() and self.ImageColor or self.DisabledImageColor
	if self.Animate then
		local old_top = UIL.PushModifier(self.animation)
		UIL.DrawXImage(self.Image,
			b, width, height, box(0, 0, src:maxx() * self.Columns, src:maxy() * self.Rows),
			color, color, color, color,
			self:CalcDesaturation(), self.Angle, self.FlipX, self.FlipY,
			self.EffectType, self.EffectPixels, self.EffectColor, self.UseClipBox,
			self.FrameEdgeColor, self.FrameLeft, self.FrameTop, self.FrameRight, self.FrameBottom)
		UIL.ModifiersSetTop(old_top)
	else
		UIL.DrawXImage(self.Image,
			b, width, height, src,
			color, color, color, color,
			self:CalcDesaturation(), self.Angle, self.FlipX, self.FlipY,
			self.EffectType, self.EffectPixels, self.EffectColor, self.UseClipBox,
			self.FrameEdgeColor, self.FrameLeft, self.FrameTop, self.FrameRight, self.FrameBottom)
	end
	if self.AdditiveMode then
		UIL.SetBlendMode("blendNormal")
	end
end

----- XEmbedIcon

DefineClass.XEmbedIcon = {
	__parents = { "XWindow" },
	properties = {
		{ category = "Icon", id = "Icon", editor = "ui_image", default = "", },
		{ category = "Icon", id = "IconDock", editor = "choice", default = false, items = {false, "left", "right", "top", "bottom", "box", "ignore"}, invalidate = "layout", },
		{ category = "Icon", id = "IconRows", editor = "number", default = 1, },
		{ category = "Icon", id = "IconRow", editor = "number", default = 1, },
		{ category = "Icon", id = "IconColumns", editor = "number", default = 1, },
		{ category = "Icon", id = "IconColumn", editor = "number", default = 1, },
		{ category = "Icon", id = "IconScale", name = "Icon scale", editor = "point2d", default = point(1000, 1000), help = "Used when the image is not resized (ImageFit equals 'none')", lock_ratio = true, },
		{ category = "Icon", id = "IconColor", name = "Icon color", editor = "color", default = RGB(255, 255, 255), },
		{ category = "Icon", id = "DisabledIconColor", name = "Disabled icon color", editor = "color", default = RGBA(255, 255, 255, 128), },
		{ category = "Icon", id = "IconDesaturation", name = "Icon desaturation", editor = "number", default = 0, min = 0, max = 255, slider = true, },
		{ category = "Icon", id = "IconDisabledDesaturation", name = "Disabled icon desaturation", editor = "number", default = 255, min = 0, max = 255, slider = true, },
		{ category = "Icon", id = "IconFlipX", editor = "bool", default = false, invalidate = true, },
		{ category = "Icon", id = "IconFlipY", editor = "bool", default = false, invalidate = true, },
	},
}

function XEmbedIcon:Init(parent, context)
	local icon = XImage:new({
		Id = "idIcon", 
		HAlign = "center", 
		VAlign = "center", 
	}, self, context)
	self:SetIcon(self.Icon)
	icon:SetRows(self.IconRows)
	icon:SetRow(self.IconRow)
	icon:SetColumns(self.IconColumns)
	icon:SetColumn(self.IconColumn)
	icon:SetImageScale(self.IconScale)
	icon:SetImageColor(self.IconColor)
	icon:SetDisabledImageColor(self.DisabledIconColor)
	icon:SetDisabledDesaturation(self.IconDisabledDesaturation)
	icon:SetDesaturation(self.IconDesaturation)
	icon:SetImageFit("scale-down")
end

LinkPropertyToChild(XEmbedIcon, "Icon", "idIcon", "Image")
LinkPropertyToChild(XEmbedIcon, "IconDock", "idIcon", "Dock")
LinkPropertyToChild(XEmbedIcon, "IconRows", "idIcon", "Rows")
LinkPropertyToChild(XEmbedIcon, "IconRow", "idIcon", "Row")
LinkPropertyToChild(XEmbedIcon, "IconColumns", "idIcon", "Columns")
LinkPropertyToChild(XEmbedIcon, "IconColumn", "idIcon", "Column")
LinkPropertyToChild(XEmbedIcon, "IconScale", "idIcon", "ImageScale")
LinkPropertyToChild(XEmbedIcon, "IconColor", "idIcon", "ImageColor")
LinkPropertyToChild(XEmbedIcon, "DisabledIconColor", "idIcon", "DisabledImageColor")
LinkPropertyToChild(XEmbedIcon, "IconDesaturation", "idIcon", "Desaturation")
LinkPropertyToChild(XEmbedIcon, "IconDisabledDesaturation", "idIcon", "DisabledDesaturation")
LinkPropertyToChild(XEmbedIcon, "IconFlipX", "idIcon", "FlipX")
LinkPropertyToChild(XEmbedIcon, "IconFlipY", "idIcon", "FlipY")

function XEmbedIcon:SetIcon(icon)
	if self.idIcon:GetImage() == icon then return end
	self.idIcon:SetImage(icon)
	self.Icon = icon
	self.idIcon:SetDock(icon == "" and "ignore" or self.IconDock)
	self.idIcon:SetVisible(icon ~= "")
end


----- Image reloading helper

function FindXImagesAndReload(path, ximage_list)
	if not CanYield() then
		CreateRealTimeThread(FindXImagesAndReload, path)
		return
	end

	ximage_list = ximage_list or GetChildrenOfKind(terminal.desktop, "XImage")
	local compare_path = NormalizeGamePath(ConvertToOSPath(path) or path)
	local dir, name = SplitPath(compare_path)
	local list = table.map(ximage_list, function(v) return v:GetImage() end)
	local images = table.filter(ximage_list, function(idx, ximage)
		local image_path = ximage:GetImage()
		local image_os_path = NormalizeGamePath(ConvertToOSPath(image_path) or image_path)
		local imagedir, imagename, __ = SplitPath(image_os_path)
		return dir == imagedir and name == imagename
	end)

	for _, ximage in pairs(images) do
		ximage:SetImage("")
	end
	UIL.UnloadImage(path)
	UIL.Invalidate()
	while not UIL.IsImageUnloaded(path) do
		WaitMsg("OnRender")
	end
	UIL.RequestImage(path)
	UIL.Invalidate()
	for _, ximage in pairs(images) do
		ximage:SetImage(path)
	end
end

function EnableUIBlur(value)
	hr.UILBlurTextureScale = value and 500 or 0
end

DefineClass.XBlurRect = {
	__parents = { "XWindow" },

	properties = {
		{ category = "Blur", id = "TintColor", name = "Tint Color", editor = "color", default = RGB(180, 180, 180), },
		{ category = "Blur", id = "BlurRadius", name = "Blur Radius", editor = "number", default = 150, min = 10, max = 300, slider = true, },
		{ category = "Blur", id = "Mask", name = "Blur Mask", editor = "ui_image", default = "", image_preview_size = 100, },
		{ category = "Blur", id = "FrameLeft", editor = "number", default = 0, invalidate = true, },
		{ category = "Blur", id = "FrameTop", editor = "number", default = 0, invalidate = true, },
		{ category = "Blur", id = "FrameRight", editor = "number", default = 0, invalidate = true, },
		{ category = "Blur", id = "FrameBottom", editor = "number", default = 0, invalidate = true, },
		{ category = "Blur", id = "Desaturation", editor = "number", default = 0, min = 0, max = 255, slider = true, invalidate = true, },
	},

	image_id = const.InvalidResourceID,
	image_obj = false,
	cached_image_rect = box(0, 0, 1, 1),
}


function XBlurRect:Init()
	self:SetMask(self.Mask, true)
end

function XBlurRect:Done()
	if self.image_obj ~= false then
		self.image_obj:ReleaseRef()
		self.image_obj = false
	end
end

function XBlurRect:SetMask(image, force)	
	if self.Mask == (image or "") and not force then return end	
	self.Mask = image or nil
	
	self:DeleteThread("LoadImage")
	if (self.Mask or "") == "" then
		return
	end
	
	if self.image_obj ~= false then
		self.image_obj:ReleaseRef()
		self.image_obj = false
	end
	
	self.image_id = ResourceManager.GetResourceID(self.Mask)
	if self.image_id == const.InvalidResourceID then
		printf("once", "Could not load image %s!", self.Mask or "")
		return
	end
	
	self.image_obj = ResourceManager.GetResource(self.image_id)
	if self.image_obj then
		self.cached_image_rect = box(0, 0, self.image_obj:GetWidth(), self.image_obj:GetHeight())
		self:Invalidate()
	else
		self:CreateThread("LoadImage", function(self)
			self.image_obj = AsyncGetResource(self.image_id)
			if self.image_obj then
				self.cached_image_rect = box(0, 0, self.image_obj:GetWidth(), self.image_obj:GetHeight())
				self:Invalidate()
			end
		end, self)
	end
end


function XBlurRect:DrawBackground()
	local desaturation = UIL.GetDesaturation()
	UIL.SetDesaturation(self.Desaturation)
	if hr.UILBlurTextureScale > 0 then
		UIL.DrawBackBufferRect(self.content_box, self.cached_image_rect, MulDivRound(self.BlurRadius, self.scale:x(), 1000), self.TintColor, self.Mask or "",
			self.scale, self.FrameLeft, self.FrameTop, self.FrameRight, self.FrameBottom)
	else
		local new_color = MulDivRound(point(GetRGB(self.TintColor)), 80, 100)
		self.Background = RGBA(0, 0, 0, Min(new_color:xyz()))
		XWindow.DrawBackground(self)
	end
	UIL.SetDesaturation(desaturation)
end

function TestXEdgeFadingImage()
	local parent = XWindow:new({
	}, terminal.desktop)
	XImage:new({ Image = "UI/SplashScreen", HAlign = "center", VAlign = "center", }, parent)
end