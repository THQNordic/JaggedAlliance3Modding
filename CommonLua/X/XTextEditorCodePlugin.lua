local MeasureText = UIL.MeasureText
local MeasureToCharStart = UIL.MeasureToCharStart
local StretchText = UIL.StretchText
local DrawSolidRect = UIL.DrawSolidRect

DefineClass.XCodeEditorPlugin = {
	__parents = { "XTextEditorPlugin" },
	SelectionColor = RGB(78, 140, 187),
	KeywordColor = RGB(75, 105, 198),
	CommentColor = RGB(0, 128, 0),
	QuoteColor = RGB(190, 150, 150),
	NumberColor = RGB(255, 141, 141),
	ErrorColor = RGB(255, 0, 0),
	SingleInstance = false,
	
	highlighted_text = false,
	highlight_positions = {},
	error_line = false,
	error_text = false,
	error_needs_drawn = false, -- runtime state while drawing
	dim_text = false,
	color_string = false,
	comment_out = false,
	comment_close_string = false,
}

function XCodeEditorPlugin:SetError(line, text)
	self.error_line = line
	self.error_text = text
end

function XCodeEditorPlugin:VerticalSpaceAfterLine(edit, line)
	if self.error_line and line == Min(self.error_line, #edit.lines) then
		return edit.font_height
	end
end

function XCodeEditorPlugin:OnBeginDraw(edit)
	self.color_string = false
	self.comment_out = false
	self.comment_close_string = false
	self.error_needs_drawn = self.error_line ~= false
end

function XCodeEditorPlugin:OnDrawText(edit, line_idx, text, target_box, font, text_color)
	if self.error_line and line_idx == Min(self.error_line, #edit.lines) then
		local width, height = MeasureText(self.error_text, font)
		local pt = target_box:min() + point(0, edit:GetFontHeight())
		if pt:y() + height <= edit.content_box:maxy() then
			StretchText(self.error_text, sizebox(pt + point(5, 0), point(width, height)), font, self.ErrorColor)
			local sx = target_box:sizex()
			DrawSolidRect(sizebox(pt, point(sx, 1)), self.ErrorColor)
			DrawSolidRect(sizebox(pt + point(     0, -3), point(1, 3)), self.ErrorColor)
			DrawSolidRect(sizebox(pt + point(sx - 1, -3), point(1, 3)), self.ErrorColor)
			
			self.error_needs_drawn = false
		end
	end
end

function XCodeEditorPlugin:OnEndDraw(edit)
	-- the error is outside of the viewport
	if self.error_needs_drawn then
		local win_box = edit.box
		local height = edit:GetFontHeight()
		local start_idx = edit:LineIdxFromScreenY(win_box:miny())
		
		local target_box
		local padding_x1, padding_y1, padding_x2, padding_y2 = ScaleXY(edit.scale, edit.Padding:xyxy())
		local size = point(win_box:sizex() + padding_x1 + padding_x2, height)
		if self.error_line < start_idx then
			target_box = sizebox(win_box:min() - point(padding_x1, padding_y1), size + point(0, padding_y1))
		else
			target_box = sizebox(point(win_box:minx() - padding_x1, win_box:maxy() - height), size + point(0, padding_y2))
		end
		
		-- force fit the box with the error message in the UI viewport
		local win = edit
		while win do
			target_box = FitBoxInBox(target_box, win.box)
			win = win.parent
		end
		local color = GetDarkModeSetting() and const.clrWhite or const.clrBlack
		DrawSolidRect(target_box, InterpolateRGB(edit.Background, color, 1, 10))
		
		-- draw error
		local font = edit:GetFontId()
		local width, height = MeasureText(self.error_text, font)
		StretchText(self.error_text, sizebox(target_box:min() + point(5, 0), point(width, height)), font, self.ErrorColor)
		
		self.error_needs_drawn = false
	end
end

function XCodeEditorPlugin:ModColor(color)
	if self.dim_text then
		local r, g, b = GetRGB(color)
		local apply_modifier = GetDarkModeSetting() and 
			function(v) return v * 75 / 100 end or
			function(v) return v + (255 - v) * 40 / 100 end
		return RGB(apply_modifier(r), apply_modifier(g), apply_modifier(b))
	end
	return color
end

function XCodeEditorPlugin:SetDimText(dim)
	self.dim_text = dim
end

local var_or_func_pattern = "([%a%d_]*)([^%a%d_]*)"
local lua_keywords = {
	["goto"] = true,
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}

function XCodeEditorPlugin:PreProcessCharacter(other, character, comment_position, current, num_bytes)
	if not self.comment_out then
		if character == '"' then
			if not self.color_string then self.color_string = '"'
			elseif self.color_string == '"' then self.color_string = false end
		elseif character == "'" then
			if not self.color_string then self.color_string = "'"
			elseif self.color_string == "'" then self.color_string = false end
		end
		if comment_position and num_bytes == comment_position then
			local pos = comment_position + 2
			if other:sub(pos, pos) == "[" then
				pos = pos + 1
				local gap = ""
				while other:sub(pos, pos) == "=" do
					gap = gap .. "="
					pos = pos + 1
				end
				if other:sub(pos, pos) == "[" then
					self.comment_close_string = string.format("]%s]", gap)
				end
			end
			self.comment_out = true
		end
	end
end

function XCodeEditorPlugin:PostProcessCharacter(other, character, comment_position, current, num_bytes)
	local comment_close = self.comment_close_string
	if character == "]" and comment_close and current >= #comment_close and other:sub(current - #comment_close + 1):starts_with(comment_close) then
		comment_position = other:find_lower("--", current)
		self.comment_close_string = false
		self.comment_out = false
	end
end

function XCodeEditorPlugin:OnDrawLineOutsideView(edit, line_idx, text, above_view)
	if above_view then
		for word, other in text:gmatch(var_or_func_pattern) do
			if other and other ~= " " then
				local comment_position = other:find_lower("--")
				local current, num_bytes = 1, 0
				local character = utf8.sub(other, current, current)
				while #character > 0 do
					num_bytes = num_bytes + #character
					self:PreProcessCharacter(other, character, comment_position, current, num_bytes)
					self:PostProcessCharacter(other, character, comment_position, current, num_bytes)
					current = current + 1
					character = utf8.sub(other, current, current)
				end
			end
		end
	end
end

function XCodeEditorPlugin:OnBeforeDrawText(edit, line_idx, text, target_box, font, text_color)
	for idx, pos in ipairs(self.highlight_positions[line_idx]) do
		local x1 = MeasureToCharStart(text, font, pos + 1)
		local x2 = MeasureToCharStart(text, font, pos + utf8.len(self.highlighted_text) + 1)	
		DrawSolidRect(box(target_box:minx() + x1, target_box:miny(), target_box:minx() + x2, target_box:maxy()), self.SelectionColor)
	end
	
	if not self.comment_close_string then
		self.comment_out = false
	end
	
	local pos = 0
	local text_start = target_box:minx()
	for word, other in text:gmatch(var_or_func_pattern) do
		local len_word = utf8.len(word)
		local len_other = utf8.len(other)
		local x1 = MeasureToCharStart(text, font, pos + 1)
		local x2 = MeasureToCharStart(text, font, pos + len_word + 1)
		local word_box = box(text_start + x1, target_box:miny(), text_start + x2, target_box:maxy())
		local new_text_color
		if not self.comment_out and not self.color_string then
			if other and other:starts_with('(') and word ~= "function" then
				new_text_color = RGB(160, 170, 150)
			elseif tonumber(word) ~= nil then
				new_text_color = self.NumberColor
			else
				new_text_color = lua_keywords[word] and self.KeywordColor or text_color
			end
		end
		StretchText(word, word_box, font, self:ModColor(self.comment_out and self.CommentColor or self.color_string and self.QuoteColor or new_text_color))
		
		if other and other ~= " " then
			local comment_position = other:find_lower("--")
			local current, num_bytes = 1, 0
			local character = utf8.sub(other, current, current)
			while #character > 0 do
				num_bytes = num_bytes + #character
				self:PreProcessCharacter(other, character, comment_position, current, num_bytes)
				
				local x3 = MeasureToCharStart(text, font, pos + len_word + current)
				local other_box = box(text_start + x3, target_box:miny(), text_start + x3, target_box:maxy())
				if character == "." and tonumber(word) ~= nil then 
					StretchText(character, other_box, font, self:ModColor(self.NumberColor))
				else
					StretchText(character, other_box, font, self:ModColor(self.comment_out and self.CommentColor or self.color_string and self.QuoteColor or (character == '"' or character == "'") and self.QuoteColor or text_color))
				end
				
				self:PostProcessCharacter(other, character, comment_position, current, num_bytes)
				current = current + 1
				character = utf8.sub(other, current, current)
			end
		end
		pos = pos + len_word + len_other
	end
	return true
end

function XCodeEditorPlugin:OnWordSelection(edit, word_to_mark)
	self.highlighted_text = word_to_mark
	self.highlight_positions = {}
	for idx, line in ipairs(edit.lines) do
		self.highlight_positions[idx] = {}
		local pos = 0
		for word, other in line:gmatch(var_or_func_pattern) do
			local len = utf8.len(word)
			if word == word_to_mark then
				local current_pos = #(self.highlight_positions[idx] or empty_table)
				self.highlight_positions[idx][current_pos + 1] = pos
			end
			pos = pos + len + utf8.len(other)
		end
	end
end

function XCodeEditorPlugin:OnSelectHighlight(edit, search_text, ignore_case)
	self.highlighted_text = search_text
	self.highlight_positions = {}
	for idx, line in ipairs(edit.lines) do
		self.highlight_positions[idx] = {}
		local pos, len = 1, utf8.len(line)
		local text = ignore_case and line:lower() or line
		local end_pos
		while pos <= len do
			pos, end_pos = string.find(text, search_text, pos, true)
			if not pos then break end
			
			local current_pos = #(self.highlight_positions[idx] or empty_table)
			self.highlight_positions[idx][current_pos + 1] = pos - 1
			pos = end_pos + 1
		end
	end
end

function XCodeEditorPlugin:ClearHighlights()
	self.highlight_positions = {}
	self.highlighted_text = false
end

XCodeEditorPlugin.OnTextChanged = XCodeEditorPlugin.ClearHighlights
XCodeEditorPlugin.OnKillFocus   = XCodeEditorPlugin.ClearHighlights

function XCodeEditorPlugin:OnShortcut(edit, shortcut, source, ...)
	local start_line, start_char, end_line, end_char = edit:GetSelectionSortedBounds()
	if start_line and end_line then
		if shortcut == "Tab" and edit.AllowTabs then
			edit:SetCursor(start_line, 0, false)
			if end_char == 0 then
				end_line = end_line - 1
			end
			edit:SetCursor(end_line, utf8.len(edit.lines[end_line]), "select", "include last endline")
			local new_text = ""
			for i = start_line, end_line do
				new_text = new_text.."\t"..edit.lines[i]
			end
			edit:EditOperation(new_text, nil, nil, "keep_selection")
			return "break"
		elseif shortcut == "Shift-Tab" then
			edit:SetCursor(start_line, 0, false)
			if end_char == 0 then
				end_line = end_line - 1
			end
			edit:SetCursor(end_line, utf8.len(edit.lines[end_line]), "select", "include last endline")
			local new_text = ""
			local has_changes = false
			for i = start_line, end_line do
				if string.sub(edit.lines[i], 1, 1) == "\t" then
					new_text = new_text..string.sub(edit.lines[i], 2, edit.lines[i].length)
					has_changes = true
				else
					new_text = new_text..edit.lines[i]
				end
			end
			if has_changes then
				edit:EditOperation(new_text, nil, nil, "keep_selection")
				return "break"
			end
		end
	end
	
	if shortcut == "Ctrl-F" and edit.Multiline then
		self:ActivateSearch(edit)
		return "break"
	elseif shortcut == "Ctrl-L" then
		local line = edit.cursor_line
		edit:SetCursor(line, 0)
		edit:SetCursor(line, utf8.len(edit.lines[line]), "select", "include last endline")
		edit:EditOperation()
		return "break"
	elseif shortcut == "Ctrl-Shift-Up" then
		local line1, char1, line2, char2 = edit:GetSelectionSortedBounds()
		local line = line1 or edit.cursor_line
		if line > 1 then
			if line1 then -- move selection
				if char2 ~= 0 then line2 = line2 + 1 end
				edit:ExchangeLines(line1 - 1, line1, line2, line1)
				edit:SetCursor(line1 - 1, 0)
				edit:SetCursor(line2 - 1, 0, "select")
			else -- move current line
				edit:ExchangeLines(line - 1, line, line + 1, line)
			end
		end
		return "break"
	elseif shortcut == "Ctrl-Shift-Down" then
		local line1, char1, line2, char2 = edit:GetSelectionSortedBounds()
		local line = line2 or edit.cursor_line
		if line < #edit.lines or char2 == 0 then
			if line2 then -- move selection
				if char2 ~= 0 then line2 = line2 + 1 end
				edit:ExchangeLines(line1, line2, line2 + 1, line1)
				edit:SetCursor(line1 + 1, 0)
				edit:SetCursor(line2 + 1, 0, "select")
			else -- move current line
				edit:ExchangeLines(line, line + 1, line + 2, line)
			end
		end
		return "break"
	elseif shortcut == "Escape" then
		self:ClearHighlights()
		edit:ClearSelection()
		return "break"
	end
end

function XCodeEditorPlugin:ActivateSearch(edit)
	local search_box = XEdit:new({
		Margins = box(5, 5, 5, 5),
		MinWidth = 150,
		MaxWidth = 150,
		HAlign = "right",
		VAlign = "top",
		BorderWidth = 1,
		AutoSelectAll = true,
		
		-- close with Escape and Enter
		OnKbdChar = function(self, char, ...)
			if char == "\r" then
				self:SetFocus(false)
				return "break"
			end
			return XEdit.OnKbdChar(self, char, ...)
		end,
		OnShortcut = function(self, shortcut, ...)
			if shortcut == "Escape" then
				self:SetFocus(false)
				return "break"
			end
			return XEdit.OnShortcut(self, shortcut, ...)
		end,
		OnKillFocus = function(self)
			if self.window_state ~= "destroying" then
				self:Close()
			end
		end,
		
		-- search and highlight
		OnTextChanged = function(search_box)
			local text = search_box:GetText()
			if text ~= "" then
				edit:SelectFirstOccurence(text, "ignore_case")
			else
				self:ClearHighlights()
			end
		end,
		
		-- hack(s) to leave the search box in the top-right corner regardless of scroll
		parent_offset = false,
		OnLayoutComplete = function(self)
			self.parent_offset = self.box:min() + point(edit.OffsetX, edit.OffsetY) - edit.box:min()
			self:SetBox()
		end,
		SetBox = function(self, ...)
			if self.parent_offset then
				local x, y = (edit.box:min() + self.parent_offset):xy()
				local w, h = self.box:sizexyz()
				XEdit.SetBox(self, x, y, w, h)
			else
				XEdit.SetBox(self, ...)
			end
		end,
		SetLayoutSpace = function(self, ...)
			self.parent_offset = false
			return XEdit.SetLayoutSpace(self, ...)
		end
	}, edit)
	
	local text = edit:GetSelectedText()
	local idx = text.find(text, "[\r\n]")
	if idx then
		text = text:sub(1, idx - 1)
	end
	search_box:Open()
	search_box:SetText(text)
	search_box:SetFocus(true)
	Msg("XWindowRecreated", search_box) -- dark mode stuff
end
