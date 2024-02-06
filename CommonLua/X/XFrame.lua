DefineClass.XFrame = {
	__parents = { "XControl" },
	
	properties = {
		{ category = "Image", id = "Image", name = "Frame image", editor = "ui_image", default = "", invalidate = true, },
		{ category = "Image", id = "ImageScale", name = "Frame scale", editor = "point2d", default = point(1000, 1000), invalidate = true, lock_ratio = true, },
		{ category = "Image", id = "FrameBox", name = "Frame box", editor = "padding", default = box(0, 0, 0, 0), invalidate = true, },
		{ category = "Image", id = "Rows", editor = "number", default = 1, invalidate = true, },
		{ category = "Image", id = "Columns", editor = "number", default = 1, invalidate = true, },
		{ category = "Image", id = "Row", editor = "number", default = 1, invalidate = true, },
		{ category = "Image", id = "Column", editor = "number", default = 1, invalidate = true, },
		{ category = "Image", id = "TileFrame", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "SqueezeX", editor = "bool", default = true, invalidate = true, },
		{ category = "Image", id = "SqueezeY", editor = "bool", default = true, invalidate = true, },
		{ category = "Image", id = "TransparentCenter", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "FlipX", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "FlipY", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "Desaturation", editor = "number", default = 0, min = 0, max = 255, slider = true, invalidate = true, },
	},
	Background = RGB(255, 255, 255),
	FocusedBackground = RGB(255, 255, 255),
	HandleMouse = false,
	image_id = const.InvalidResourceID,
	image_obj = false,
}

function XFrame:Init()
	self:SetImage(self.Image, true)
end

function XFrame:Done()
	if self.image_obj ~= false then
		self.image_obj:ReleaseRef()
		self.image_obj = false
	end
end

local InvalidResourceID = const.InvalidResourceID
function XFrame:SetImage(image, force)
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
	if self.image_id == InvalidResourceID then
		printf("once", "Could not load image %s!", self.Image or "")
		return
	end
	
	self.image_obj = ResourceManager.GetResource(self.image_id)
	if self.image_obj then
		self:InvalidateMeasure()
		self:Invalidate()
	else
		self:CreateThread("LoadImage", function(self)
			self.image_obj = AsyncGetResource(self.image_id)
			self:InvalidateMeasure()
			self:Invalidate()
		end, self)
	end
end

function XFrame:Measure(preferred_width, preferred_height)
	local width, height = XControl.Measure(self, preferred_width, preferred_height)
	if self.image_id ~= InvalidResourceID and (not self.SqueezeX or not self.SqueezeY) then
		local image_width, image_height = ResourceManager.GetMetadataTextureSizeXY(self.image_id)
		image_width, image_height = ScaleXY(self.scale, ScaleXY(self.ImageScale, (image_width or 0) / self.Columns, (image_height or 0) / self.Rows))
		if not self.SqueezeX then
			width = Max(image_width, width)
		end
		if not self.SqueezeY then
			height = Max(image_height, height)
		end
	end
	return width, height
end

local UIL = UIL
local rgbWhite = RGB(255, 255, 255)
function XFrame:DrawBackground()
	if self.image_id ~= InvalidResourceID then
		local color = self:CalcBackground()
		if GetAlpha(color) == 0 then return end
		local desaturation = UIL.GetDesaturation()
		UIL.SetDesaturation(self.Desaturation)
		UIL.SetColor(color)
		local scaleX, scaleY = ScaleXY(self.scale, self.ImageScale:xy())
		UIL.DrawFrame(self.image_id, self.box, self.Rows, self.Columns, self:GetRow(), self:GetColumn(),
			self.FrameBox, not self.TileFrame, self.TransparentCenter, scaleX, scaleY, self.FlipX, self.FlipY)
		UIL.SetColor(rgbWhite)
		UIL.SetDesaturation(desaturation)
	else
		XControl.DrawBackground(self)
	end
end


----- XFrameProgress

local PushClipRect = UIL.PushClipRect
local PopClipRect = UIL.PopClipRect

DefineClass.XFrameProgress = {
	__parents = { "XFrame", "XProgress" },
	properties = {
		{ category = "Image", id = "ProgressImage", name = "Progress frame image", editor = "ui_image", default = "", invalidate = true, },
		{ category = "Image", id = "ProgressFrameBox", name = "Progress frame box", editor = "padding", default = box(0, 0, 0, 0), invalidate = true, },
		{ category = "Image", id = "ProgressTileFrame", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "SeparatorImage", name = "Separator Image", editor = "ui_image", default = "", invalidate = true, },
		{ category = "Image", id = "SeparatorOffset", name = "Separator Offset", editor = "number", default = 0, invalidate = true, },
	},
	SqueezeY = false,
	separator_x = 0,
	separator_y = 0,
	TimeProgressInt = false,
}

function XFrameProgress:Init(parent, context)
	local progress = XFrame:new({
		Id = "idProgress",
		HAlign = self.ProgressClip and "stretch" or "left",
		VAlign = "center",
		SqueezeY = false,
		DrawBackground = function(self)
			local clip = self.parent.ProgressClip and not self.TimeProgressInt
			if clip then
				local parent = self.parent
				local progress, max_progress = parent.Progress, Max(1, parent.MaxProgress)
				local min = ScaleXY(self.scale, parent.MinProgressSize)
				local min_x, min_y = self.content_box:minxyz()
				local width, height = self.content_box:sizexyz()
				if parent.Horizontal then
					local clip_width = (max_progress == 0) and min or min + (width - min) * progress / max_progress
					PushClipRect(min_x, min_y, min_x + clip_width, min_y + height, true)
				else
					local clip_height = (max_progress == 0) and min or min + (height - min) * progress / max_progress
					PushClipRect(min_x, min_y + height - clip_height, min_x + width, min_y + height, true)
				end
			end
			XFrame.DrawBackground(self)
			if clip then
				PopClipRect()
			end
		end,
		DrawContent = function(self)
			local parent = self.parent
			local image = parent.SeparatorImage
			if image ~= "" then
				local separator_x, separator_y = parent.separator_x, parent.separator_y
				local b = self.box
				local scale_x, scale_y = self.scale:xy()
				local offset = parent.SeparatorOffset * scale_x / 1000
				local rect
				local progressRatio = MulDivRound(parent.Progress, 1000, parent.MaxProgress)
				if parent.Horizontal then
					local w = MulDivRound(b:sizex(), progressRatio, 1000)
					b = sizebox(b:minx(), b:miny(), w, b:sizey())
					local right_spill = offset - ((parent.measure_width - self.measure_width) * scale_x / 1000)
					right_spill = Max(right_spill, 0)
					rect = box(Max(b:minx(), b:maxx() - separator_x - offset) + offset, b:miny(), Max(b:minx() + offset, b:maxx() - right_spill), b:maxy())
				else
					local h = MulDivRound(b:sizey(), progressRatio, 1000)
					b = sizebox(b:minx(), b:miny(), b:sizex(), h)
					local up_spill = offset - (b:miny() * scale_y / 1000)
					up_spill = Max(up_spill, 0)
					rect = box(b:minx(), Min(b:maxy() - offset, b:miny() + up_spill), b:maxx(), Min(b:maxy(), b:miny() + separator_y + offset) - offset)
				end
				UIL.DrawImage(image, rect, box(0, 0, separator_x, separator_y))
			end
		end,
	}, self, context)
	progress:SetImage(self.ProgressImage)
	progress:SetFrameBox(self.ProgressFrameBox)
	progress:SetTileFrame(self.ProgressTileFrame)
end

LinkPropertyToChild(XFrameProgress, "ProgressImage", "idProgress", "Image")
LinkPropertyToChild(XFrameProgress, "ProgressFrameBox", "idProgress", "FrameBox")
LinkPropertyToChild(XFrameProgress, "ProgressTileFrame", "idProgress", "TileFrame")

function XFrameProgress:SetHorizontal(h)
	self.Horizontal = h
	local progress = self.idProgress
	if self.ProgressClip then
		progress:SetHAlign(h and "stretch" or "center")
		progress:SetVAlign(h and "center" or "stretch")
	else
		progress:SetHAlign(h and "left" or "center")
		progress:SetVAlign(h and "center" or "bottom")
	end
	progress:SetSqueezeY(not h)
	progress:SetSqueezeX(h)
	self:SetSqueezeY(not h)
	self:SetSqueezeX(h)
	self:InvalidateMeasure()
end

function XFrameProgress:SetSeparatorImage(image)
	image = image or false
	if self.SeparatorImage ~= image then
		self.SeparatorImage = image
		self.separator_x, self.separator_y = UIL.MeasureImage(image)
		self:Invalidate()
	end
end

function XFrameProgress:OnPropUpdate(context, prop_meta, value)
	if not self.TimeProgressInt then
		XProgress.OnPropUpdate(self, context, prop_meta, value)
	end
end

function XFrameProgress:SetTimeProgress(start_time, end_time, bGameTime)
	local prev = self.TimeProgressInt
	if prev and prev.start == start_time and prev.duration + prev.start == end_time and
		not bGameTime == not IsFlagSet(prev.flags or 0, const.intfGameTime) then
		-- setting the same time progress
		return
	end
	self.idProgress:RemoveModifier(prev)
	self.TimeProgressInt = nil
	if start_time and end_time then
		self.TimeProgressInt = {
			id = "TimeProgressBar",
			type = const.intRect,
			OnLayoutComplete = IntRectTopLeftRelative,
			OnWindowMove = IntRectTopLeftRelative,
			targetRect = sizebox(0, 0, 0, 100),
			originalRect = sizebox(0, 0, 100, 100),
			duration = end_time - start_time,
			start = start_time,
			interpolate_clip = self.UseClipBox and const.interpolateClipOnly or true,
			flags = const.intfInverse + (bGameTime and const.intfGameTime or 0),
		}
		self.idProgress:AddInterpolation(self.TimeProgressInt)
		self:SetMaxProgress(100)
		self:SetProgress(100)
	end
end