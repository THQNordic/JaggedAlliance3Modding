DefineClass.XText = {
	__parents = { "XTranslateText" },
	
	-- text properties that affect the draw cache should have invalidate = "measure"
	properties = {
		{ category = "General", id = "Text", editor = "text", default = "", translate = function (obj) return obj:GetProperty("Translate") end, lines = 1, },
		{ category = "General", id = "WordWrap", editor = "bool", default = true, invalidate = "measure", },
		{ category = "General", id = "Shorten", editor = "bool", default = false, invalidate = "measure", },
		{ category = "General", id = "ShortenString", editor = "text", default = "...", translate = false, lines = 1, invalidate = "layout", trim_spaces = false },
		{ category = "General", id = "HideOnEmpty", editor = "bool", default = false, invalidate = "measure", },
		{ category = "Layout", id = "TextHAlign", editor = "choice", default = "left", items = { "left", "center", "right" }, invalidate = "measure", },
		{ category = "Layout", id = "TextVAlign", editor = "choice", default = "top", items = { "top", "center", "bottom" }, invalidate = true, },
		{ category = "Visual", id = "Angle", editor = "number", default = 0, invalidate = "measure",  min = 0, max = 360*60 - 1, scale = "deg"},
		{ category = "Visual", id = "ImageScale", editor = "number", default = 500, invalidate = "measure", },
		{ category = "Visual", id = "UnderlineOffset", editor = "number", default = 0 },

		{ category = "Debug", id = "draw_cache_text_width", read_only = true, editor = "number", },
		{ category = "Debug", id = "draw_cache_text_height", read_only = true, editor = "number", },
		{ category = "Debug", id = "text_width", read_only = true, editor = "number", },
		{ category = "Debug", id = "text_height", read_only = true, editor = "number", },
		{ category = "Debug", id = "DebugText", read_only = true, editor = "text", default = "", lines = 1, max_lines = 10 },
		{ category = "Debug", id = "DebugButtons", editor = "buttons", buttons = {{name = "Copy XText cloning code to clipboard", func = "CopyDebugText"}} },
	},
	
	Clip = "parent & self",
	Padding = box(2, 2, 2, 2),

	draw_cache = {},
	draw_cache_text_width = 0,
	draw_cache_text_height = 0,
	draw_cache_text_wrapped = false,
	draw_cache_text_shortened = false,
	force_update_draw_cache = false,
	invert_colors = false, -- used for Ged help rollovers in dark mode
	
	scaled_underline_offset = 0,
	text_width = 0,
	text_height = 0,
	hovered_hyperlink = false,
	touch = false,
}

function XText:GetDebugText()
	return self.text or ""
end

function XText:CopyDebugText()
	local width, height = self.box:sizexyz()
	local args = {
		MulDivRound(width, 1000, self.scale:x()),
		MulDivRound(height, 1000, self.scale:y()),
		self:GetDebugText(),
	}
	
	local props = {
		"WordWrap", "Shorten", "TextHAlign", "TextVAlign",
		"ImageScale", "TextStyle", "TextFont", "TextColor", "ShadowType", "ShadowSize", "ShadowColor", "RolloverTextColor", "DisabledTextColor"
	}
	for _, id in ipairs(props) do
		table.insert(args, id)
		table.insert(args, self:GetProperty(id))
	end
	
	args = table.map(args, function(v) return ValueToLuaCode(v) end)
	local func = "XTextDebug(" .. table.concat(args, ", ") .. ")"
	CopyToClipboard(func)
end

if Platform.developer then
	if FirstLoad then
		DebugXTextContainer = false
	end

	function XTextDebug(width, height, text, ...)
		if DebugXTextContainer then
			DebugXTextContainer:delete()
		end
		
		DebugXTextContainer = XWindow:new({
			Id = "XTextDebugContainer",
			Background = RGBA(0, 0, 0, 128),
		}, terminal.desktop)
		local ctrl = XText:new({
			HAlign = "center",
			VAlign = "center",
		}, DebugXTextContainer)
		
		local props = table.pack(...)
		for i = 1, #props, 2 do
			ctrl:SetProperty(props[i], props[i + 1])
		end
		ctrl:SetMinWidth(width)
		ctrl:SetMaxWidth(width)
		ctrl:SetMinHeight(height)
		ctrl:SetMaxHeight(height)
		ctrl:SetText(text)
		ctrl:SetRollover(false)
	end
	
	function OnMsg.DbgClear()
		if DebugXTextContainer then
			DebugXTextContainer:delete()
			DebugXTextContainer = false
		end
	end
end

function XText:InvalidateMeasure(...)
	self.force_update_draw_cache = true
	return XWindow.InvalidateMeasure(self, ...)
end

function XText:Measure(max_width, max_height)
	self.content_measure_width = max_width
	self.content_measure_height = max_height
	self:UpdateDrawCache(max_width, max_height, self.force_update_draw_cache)
	self.force_update_draw_cache = false
	return self.text_width, Clamp(self.text_height, self.font_height, max_height)
end

function XText:UpdateMeasure(max_width, max_height)
	if self.HideOnEmpty and self.text == "" then
		self:UpdateDrawCache(max_width, max_height, true)
		self.force_update_draw_cache = false
		if 0 ~= self.measure_width or 0 ~= self.measure_height then
			self.measure_width = 0
			self.measure_height = 0
			if self.parent then
				self.parent:InvalidateLayout()
			end
		end
		self.measure_update = false
		return
	end
	return XTranslateText.UpdateMeasure(self, max_width, max_height)
end

function XText:Layout(x, y, width, height)
	-- After Measure, at the time of Layout we might be allocated less space than requested (as returned by Measure), so:
	--  a) update the draw cache (as the text layout might need to change due to wordwrapping)
	--  b) if the new text layout requires more space, trigger a UI re-layout by calling InvalidateMeasure
	if width > 0 and height > 0 and self:UpdateDrawCache(width, height) then
		self:InvalidateMeasure()
		self.force_update_draw_cache = false -- prevent the subsequent call to Measure from force-updating the draw cache, that was just updated
	end
	return XTranslateText.Layout(self, x, y, width, height)
end

function XText:UpdateDrawCache(width, height, force)
	local old_text_width, old_text_height = self.text_width, self.text_height
	if force or
	   self.draw_cache_text_width ~= width and (self.draw_cache_text_wrapped or width < self.text_width) or
	   self.draw_cache_text_height ~= height and self.Shorten
	then
		self.draw_cache_text_width = width
		self.draw_cache_text_height = height
		
		if self.text == "" or width <= 0 then
			self.draw_cache, self.draw_cache_text_wrapped, self.text_width, self.text_height = empty_table, false, 0, 0
		else
			self.draw_cache, self.draw_cache_text_wrapped, self.text_width, self.text_height, self.draw_cache_text_shortened = XTextMakeDrawCache(self.text, {
				IsEnabled = self:GetEnabled(),
				EffectColor = self.ShadowColor,
				DisabledEffectColor = self.DisabledShadowColor,
				
				start_font_name = (self.TextFont and self.TextFont ~= "") and self.TextFont or self:GetTextStyle(),
				start_color = self.TextColor,
				invert_colors = self.invert_colors,
				max_width = width,
				max_height = height,
				scale = self.scale,
				default_image_scale = self.ImageScale,
				effect_type = self.ShadowType,
				effect_size = self.ShadowSize,
				effect_dir = self.ShadowDir,
				alignment = self.TextHAlign,
				
				word_wrap = self.WordWrap,
				shorten = self.Shorten,
				shorten_string = self.ShortenString,
			})
		end
		self:GetFontId() -- initialize self.font_height, self.font_baseline
	end
	local _, h = ScaleXY(self.scale, 0, self.UnderlineOffset)
	self.scaled_underline_offset = h
	return self.text_width > old_text_width or self.text_height > old_text_height
end

local function tab_resolve_x(draw_info, sizex)
	local x = draw_info.x
	if draw_info.control_wide_center then
		return x + sizex / 2
	end
	return x >= 0 and x or sizex + x + 1
end

local one = point(1, 1)
local target_box = box()

function XText:DrawContent(clip_box)
	local content_box = self.content_box
	local destx, desty = content_box:minxyz()
	local sizex, sizey = content_box:sizexyz()
	
	local effect_size = self.ShadowSize
	if self.TextVAlign == "center" then
		desty = desty + (sizey - self.text_height - effect_size) / 2
	elseif self.TextVAlign == "bottom" then
		desty = content_box:maxy() - self.text_height
	end
	
	local clip_y1, clip_y2 = clip_box:miny(), clip_box:maxy()
	
	local underline_start_x, underline_color
	local angle = self.Angle
	local hovered_hyperlink_id = self.hovered_hyperlink and self.hovered_hyperlink.hl_internalid or -1
	local StretchTextShadow = UIL.StretchTextShadow
	local StretchTextOutline = UIL.StretchTextOutline
	local StretchText = UIL.StretchText
	local DrawImage = UIL.DrawImage
	local PushModifier = UIL.PushModifier
	local ModifiersGetTop = UIL.ModifiersGetTop
	local ModifiersSetTop = UIL.ModifiersSetTop
	local DrawSolidRect = UIL.DrawSolidRect
	local UseClipBox = self.UseClipBox
	local irOutside = const.irOutside
	
	local default_color = self:CalcTextColor()
	for y, draw_list in pairs(self.draw_cache) do
		local list_n = #draw_list
		for n, draw_info in ipairs(draw_list) do
			local x = tab_resolve_x(draw_info, sizex)
			local h = draw_info.height
			local vdest = desty + y + draw_info.y_offset
			if not UseClipBox or vdest + h >= clip_y1 and vdest <= clip_y2 then
				if draw_info.text then
					target_box:InplaceSetSize(destx + x, vdest, draw_info.width, h)
					local hl_hovered = hovered_hyperlink_id == draw_info.hl_internalid
					local color = hl_hovered and draw_info.hl_hovercolor or draw_info.color or default_color
					local underline = draw_info.underline or hl_hovered and draw_info.hl_underline
					if not underline_start_x and underline then
						underline_start_x = target_box:minx()
						underline_color = draw_info.underline_color or color
					end
					
					local background_color = draw_info.background_color
					if background_color and GetAlpha(background_color) > 0 then
						local bg_box = box(target_box:minx() - 2, target_box:miny(), target_box:maxx(), target_box:maxy())
						DrawSolidRect(bg_box, background_color)
					end
					
					if not UseClipBox or target_box:Intersect2D(clip_box) ~= irOutside then
						local effect_size = draw_info.effect_size or effect_size
						local effect_type = draw_info.effect_type
						local effect_color = draw_info.effect_color or self.ShadowColor
						local effect_dir = draw_info.effect_dir or one
						local _, _, _, effect_alpha = GetRGBA(effect_color)
						if effect_alpha ~= 0 and effect_size > 0 then
							local off = effect_size
							if effect_type == "shadow" then
								StretchTextShadow(draw_info.text, target_box, draw_info.font, color, effect_color, off, effect_dir, angle)
							elseif effect_type == "extrude" then
								StretchTextShadow(draw_info.text, target_box, draw_info.font, color, effect_color, off, effect_dir, angle, true)
							elseif effect_type == "outline" then
								StretchTextOutline(draw_info.text, target_box, draw_info.font, color, effect_color, off, angle)
							elseif effect_type == "glow" then
								local glow_size = MulDivRound(off * 1000, self.scale:x(), 1000);
								UIL.StretchTextSDF(draw_info.text, target_box, draw_info.font,
									"base_color", color,
									"glow_color", effect_color,
									"glow_size", glow_size)
							else -- normal
								StretchText(draw_info.text, target_box, draw_info.font, color, angle)
							end
						else -- normal
							StretchText(draw_info.text, target_box, draw_info.font, color, angle)
						end
					end
					local underline_to_end = underline and n == list_n
					if underline_start_x and (not underline or underline_to_end) then
						local baseline = vdest + self.font_baseline + self.scaled_underline_offset
						local end_x = underline_to_end and target_box:maxx() or target_box:minx()
						DrawSolidRect(box(underline_start_x, baseline, end_x, baseline + 1), underline_color)
						underline_start_x = nil
					end
				elseif draw_info.horizontal_line then
					local margin = draw_info.margin
					local thickness = MulDivRound(draw_info.scale, draw_info.thickness, 1000)
					local midy = vdest + MulDivRound(draw_info.scale, draw_info.space_above, 1000)
					local ymin = midy - DivCeil(thickness, 2)
					local ymax = midy + thickness / 2
					local xmin = destx + margin
					local xmax = destx + sizex - margin
					DrawSolidRect(box(xmin, ymin, xmax, ymax), draw_info.color or default_color)
				else
					local mtop
					if draw_info.base_color_map then
						mtop = ModifiersGetTop()
						PushModifier{
							modifier_type = const.modShader,
							shader_flags = const.modIgnoreAlpha,
						}
					end
					
					target_box:InplaceSetSize(destx + x, vdest, draw_info.width, h)
					DrawImage(draw_info.image, target_box, draw_info.image_size_org, draw_info.image_color)
					
					if mtop then
						ModifiersSetTop(mtop)
					end
				end
			end
		end
	end
end

function XText:GetHyperLink(ptCheck)
	local content_box = self.content_box
	local basex, basey = content_box:minxyz()
	local sizex = content_box:sizex()
	for cache_y, draw_list in pairs(self.draw_cache) do
		for _, draw_info in ipairs(draw_list) do
			if draw_info.hl_function then
				local x = basex + tab_resolve_x(draw_info, sizex)
				local y = basey + cache_y
				if not ptCheck then
					return draw_info, box(
						x, y, 
						x + draw_info.width, y + draw_info.height )
				end
				
				local checkx = ptCheck:x() - x
				local checky = ptCheck:y() - y
				if checkx >= 0 and checkx <= draw_info.width and
					checky >= 0 and checky <= draw_info.height then
					return draw_info, box(
						x, y, 
						x + draw_info.width, y + draw_info.height )
				end
			end
		end
	end
	return false
end

function XText:HasHyperLinks()
	for y, draw_list in pairs(self.draw_cache) do
		for _, draw_info in ipairs(draw_list) do
			if draw_info.hl_function then
				return true
			end
		end
	end
	return false
end

function XText:OnHyperLink(hyperlink, argument, hyperlink_box, pos, button)
	local f, obj = ResolveFunc(self.context, hyperlink)
	if f then
		f(obj, argument)
	end
end

function XText:OnHyperLinkDoubleClick(hyperlink, argument, hyperlink_box, pos, button)
end

function XText:OnHyperLinkRollover(hyperlink, hyperlink_box, pos)
end

function XText:OnTouchBegan(id, pt, touch)
	self.touch = self:GetHyperLink(pt)
	if self.touch then
		return "break"
	end
end

function XText:OnTouchMoved(id, pt, touch)
	self:OnMousePos(pt)
	return "break"
end

function XText:OnTouchEnded(id, pt, touch)
	local h, link_box = self:GetHyperLink(pt)
	if h and h == self.touch then
		self:OnHyperLink(h.hl_function, h.hl_argument, link_box, pt, "L")
	end
	self.touch = false
	return "break"
end

function XText:OnTouchCancelled(id, pos, touch)
	self.touch = false
	return "break"
end

function XText:OnMouseButtonDown(pos, button)
	local h, link_box = self:GetHyperLink(pos)
	if h then
		self:OnHyperLink(h.hl_function, h.hl_argument, link_box, pos, button)
		return "break"
	end
end

function XText:OnMouseButtonDoubleClick(pos, button)
	local h, link_box = self:GetHyperLink(pos)
	if h then
		self:OnHyperLinkDoubleClick(h.hl_function, h.hl_argument, link_box, pos, button)
		return "break"
	end
end

function XText:OnMousePos(pos)
	if not pos then return end
	local h, link_box = self:GetHyperLink(pos)
	if self.hovered_hyperlink == h then
		return
	end
	self.hovered_hyperlink = h
	if h then
		self:OnHyperLinkRollover(h.hl_function, link_box, pos)
	else
		self:OnHyperLinkRollover(false, false, pos)
	end
	self:Invalidate()
end

function XText:OnMouseLeft(pt, ...)
	self:OnMousePos(pt)
	return XTranslateText.OnMouseLeft(self, pt, ...)
end

function XText:SetText(text)
	XTranslateText.SetText(self, text)
	self:OnMousePos(self.desktop and self.desktop.last_mouse_pos)
end

function Literal(text)
	if text == "" or IsT(text) then
		return text
	end
	return string.format("<literal %s>%s", #text, text)
end

function GetProjectConvertedFont(fontName)
	return fontName
end