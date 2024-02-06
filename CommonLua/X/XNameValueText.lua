DefineClass.XNameValueText = {
	__parents = { "XContextControl" },
	
	properties = {
		{ category = "Layout", id = "Multiline", editor = "choice", default = "both", items = { false, "left", "right", "both" }, invalidate = "measure", },
		{ category = "Layout", id = "Shorten", editor = "choice", default = "both", items = { false, "left", "right", "both" }, invalidate = "measure", },
		{ category = "Layout", id = "MinLeft", editor = "number", default = 0, invalidate = "measure",  min = 0, max = 1000},
		{ category = "Layout", id = "MinRight", editor = "number", default = 0, invalidate = "measure",  min = 0, max = 1000},
		{ category = "Layout", id = "MaxLeft", editor = "number", default = 1000, invalidate = "measure",  min = 50, max = 1000},
		{ category = "Layout", id = "MaxRight", editor = "number", default = 1000, invalidate = "measure",  min = 50, max = 1000},
		{ category = "Layout", id = "NameText", editor = "text", translate = true, default = false, invalidate = "measure"},
		{ category = "Layout", id = "ValueText", editor = "text", translate = true, default = false, invalidate = "measure"},
		{ category = "Font", id = "TextStyle", editor = "preset_id", default = "GedDefault", invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
		{ category = "Font", id = "TextStyleRight", editor = "preset_id", default = "", invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
	},
	IdNode = true,
}

function XNameValueText:UpdateLayout()
	local max_width = self.content_measure_width
	local scale_x = self.scale:x()
	
	local leftText = self.idLeftText
	local rightText = self.idRightText
	local leftTextWidth = leftText.text_width
	local rightTextWidth = rightText.text_width
		
	local left_padding_x1, left_padding_y1, left_padding_x2, left_padding_y2 = ScaleXY(leftText.scale, leftText.Padding:xyxy())
	local right_padding_x1, right_padding_y1, right_padding_x2, right_padding_y2 = ScaleXY(rightText.scale, rightText.Padding:xyxy())
	local left_border_x, left_border_y = ScaleXY(leftText.scale, leftText.BorderWidth, leftText.BorderWidth)
	local right_border_x, right_border_y = ScaleXY(rightText.scale, rightText.BorderWidth, rightText.BorderWidth)
	local left_margins_x1, left_margins_y1, left_margins_x2, left_margins_y2 = leftText:GetEffectiveMargins()
	local right_margins_x1, right_margins_y1, right_margins_x2, right_margins_y2 = rightText:GetEffectiveMargins()
		
	leftTextWidth = leftTextWidth + left_padding_x1 + left_padding_x2 + 2 * left_border_x + left_margins_x1 + left_margins_x2
	rightTextWidth = rightTextWidth + right_padding_x1 + right_padding_x2 + 2 * right_border_x + right_margins_x1 + right_margins_x2
	
	if leftTextWidth + rightTextWidth > max_width then
		if self.Multiline == "left" then
			-- SetMaxWidt/ SetMinWidth take not scaled values, but we have the scaled values now => scale down
			local rightTextWidth_scaled_down = MulDivRound(rightTextWidth, 1000, scale_x)
			rightText:SetMaxWidth(rightTextWidth_scaled_down)
			rightText:SetMinWidth(rightTextWidth_scaled_down)
			leftText:SetMaxWidth(MulDivRound(max_width - rightTextWidth, 1000, scale_x))
		elseif self.Multiline == "right" then
			local leftTextWidth_scaled_down = MulDivRound(leftTextWidth, 1000, scale_x)
			leftText:SetMaxWidth(leftTextWidth_scaled_down)
			leftText:SetMinWidth(leftTextWidth_scaled_down)
			rightText:SetMaxWidth(MulDivRound(max_width - leftTextWidth, 1000, scale_x))
		else
			--max width for one side should not exceed the min widht of the other side, so there is always enough space for both text fields
			local maxWidthLeft =  self.MaxLeft
			local maxWidthRight = self.MaxRight
			if max_width > self.MinLeft then
				maxWidthRight = Min(max_width - self.MinLeft, maxWidthRight)
			end
			if max_width > self.MinRight then
				maxWidthLeft = Min(max_width - self.MinRight, maxWidthLeft)
			end
			leftText:SetMaxWidth(maxWidthLeft)
			rightText:SetMaxWidth(maxWidthRight)
		end
	end
	XWindow.UpdateLayout(self)
end

function XNameValueText:Open(...)
	local leftText = XText:new({
		Id = "idLeftText",
		Dock = "left",
		VAlign = "center",
		Translate = true,
		WordWrap = self.Multiline and self.Multiline ~= "right" and true or false,
		Shorten = self.Shorten and self.Shorten ~= "right" and true or false,
		MinWidth = self.MinLeft,
		MaxWidth = self.MaxLeft,
		TextStyle = self.TextStyle,
		UseClipBox = self.UseClipBox,
		Clip = self.Clip,
	}, self, nil, nil)
	
	local rightText = XText:new({
		Id = "idRightText",
		Dock = "right",
		VAlign = "center",
		TextHAlign = "right",
		Translate = true,
		WordWrap = self.Multiline and self.Multiline ~= "left" and true or false,
		Shorten = self.Shorten and self.Shorten ~= "left" and true or false,
		MinWidth = self.MinRight,
		MaxWidth = self.MaxRight,
		TextStyle = (self.TextStyleRight or "") ~= "" and self.TextStyleRight or self.TextStyle,
		UseClipBox = self.UseClipBox,
		Clip = self.Clip,
	}, self, nil, nil)
	
	leftText:SetContext(self.context)
	rightText:SetContext(self.context)
	leftText:SetText(self.NameText)
	rightText:SetText(self.ValueText)
	XContextControl.Open(self, ...)
end

function XNameValueText:SetNameText(text)
	self.NameText = text
	leftText:SetText(self.NameText)
end

function XNameValueText:SetValueText(text)
	self.ValueText = text
	rightText:SetText(self.ValueText)
end
LinkPropertyToChild(XNameValueText, "NameText", "idLeftText", "Text")
LinkPropertyToChild(XNameValueText, "ValueText", "idRightText", "Text")