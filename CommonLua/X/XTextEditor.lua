if FirstLoad then
	XTextEditorPluginCache = {}
end

DefineClass.XTextEditor = {
	__parents = { "XScrollArea", "XEditableText" },
	
	properties = {
		{ category = "General", id = "Multiline", editor = "bool", default = true },
		{ category = "General", id = "Password", editor = "bool", default = false, help = "Display the entire text as * characters.", },
		{ category = "General", id = "ShowLastPswdLetter", editor = "bool", default = false, help = "When Password is set, show the last entered character.",
			no_edit = function(self) return not self.Password end,
		},
		
		{ category = "General", id = "ConsoleKeyboardTitle", editor = "text", default = "", translate = true, help = "Title for the virtual keyboard.", },
		{ category = "General", id = "ConsoleKeyboardDescription", editor = "text", default = "", translate = true, help = "Description for the virtual keyboard.", },
		
		{ category = "General", id = "WordWrap", editor = "bool", default = true },
		{ category = "General", id = "AllowTabs", editor = "bool", default = false, },
		{ category = "General", id = "AllowPaste", editor = "bool", default = true, },
		{ category = "General", id = "AllowEscape", editor = "bool", default = true, },
		{ category = "General", id = "MinVisibleLines", editor = "number", default = 1 },
		{ category = "General", id = "MaxVisibleLines", editor = "number", default = 8 },
		{ category = "General", id = "MaxLines", editor = "number", default = 10000 },
		{ category = "General", id = "MaxLen", editor = "number", default = 65536, },
		{ category = "General", id = "AutoSelectAll", editor = "bool", default = false, },
		{ category = "General", id = "Filter", editor = "text", default = ".", help = "Lua string pattern for allowed characters."},
		{ category = "General", id = "NegFilter", editor = "text", default = "", help = "Lua string pattern for forbidden characters."},
		{ category = "General", id = "NewLine", editor = "text", default = Platform.pc and "\r\n" or "\n", },
		{ category = "General", id = "Ime", editor = "bool", default = true, help = "Activate IME support for CKJ languages when the control receives focus."},
		{ category = "General", id = "Plugins", editor = "string_list", default = empty_table, items = function(self) return TextEditorPluginsCombo(rawget(self, "Multiline")) end, },
		
		{ category = "Layout", id = "TextHAlign", editor = "choice", default = "left", items = {"left", "center", "right"}, },
		
		{ category = "Visual", id = "Hint", editor = "text", translate = function(self) return self.Translate end, default = "" },
		{ category = "Visual", id = "HintColor", editor = "color", default = RGBA(0, 0, 0, 128) },
		{ category = "Visual", id = "HintVAlign", editor = "choice", default = "center", items = {"top", "center", "bottom"}, },
		{ category = "Visual", id = "SelectionBackground", editor = "color", default = RGB(38, 146, 227), },
		{ category = "Visual", id = "SelectionColor", editor = "color", default = RGB(255, 255, 255), },
	},
	
	Clip = "parent & self",
	Padding = box(2, 1, 2, 1),
	BorderWidth = 1,
	Background = RGB(240, 240, 240),
	FocusedBackground = RGB(255, 255, 255),
	BorderColor = RGB(128, 128, 128),
	DisabledBorderColor = RGBA(128, 128, 128, 128),
	TextColor = RGB(0, 0, 0),
	IdNode = false,
	
	lines = false, -- keeps the lines of text word-wrapped; newlines are internally kept as '\n' to make the code simpler
	need_reflow = false,
	len = 0,
	newline_count = 0,
	
	-- plugins
	plugins = false,
	plugin_methods = false,
	
	-- cursor
	cursor_line = 1,
	cursor_char = 0,
	cursor_virtual_x = -1, -- used for Up/Down/Pageup/Pagedown cursor navigation
	show_cursor = false,
	stop_blink = false,
	cursor_blink_time = 400,
	blink_cursor_thread = false,
	touch = false,
	
	-- selection
	selection_start_line = false,
	selection_start_char = false,
	
	-- undo & redo
	undo_data = 0,
	max_undo_data = 65536,
	undo_stack = false,
	redo_stack = false,
	
	ime_korean_composition = false,
	vkPass = {
		const.vkEnd,
		const.vkHome,
		const.vkLeft,
		const.vkRight,
		const.vkInsert,
		const.vkDelete,
		const.vkBackspace,
		const.vkEnter,
	},
}


----- helpers

local word_chars = "[_%w\127-\255]" -- count any utf8 extented character as a word character
local nonword_chars = "[^_%w\127-\255]"
local word_pattern = word_chars .. "*" .. nonword_chars .. "*"
local strict_word_pattern = word_chars .. "*"

local function IsControlPressed()
	return terminal.IsKeyPressed(const.vkControl) or (Platform.osx and terminal.IsKeyPressed(const.vkLwin))
end

local function IsShiftPressed()
	return terminal.IsKeyPressed(const.vkShift)
end

local function IsAltPressed()
	return terminal.IsKeyPressed(const.vkAlt)
end

local function TrimTextToWidth(text, font, width)
	local a, b = 0, utf8.len(text) - (text:ends_with("\n") and 1 or 0)
	local MeasureText = UIL.MeasureText
	while a ~= b do
		local mid = (a + b + 1) / 2
		local partial_width = MeasureText(utf8.sub(text, 1, mid), font)
		if partial_width <= width then -- it fits
			a = mid
		else
			b = mid - 1
		end
	end
	text = utf8.sub(text, 1, a)
	return text, MeasureText(text, font)
end

local function ApplyCharFilters(text, filter, allowed)
	if filter and filter ~= "" then
		text = text:gsub(filter, "")
	end
	if not allowed or allowed == "." then
		return text
	end
	
	local result = {}
	for part in text:gmatch(allowed .. "*") do
		table.insert(result, part)
	end
	return table.concat(result)
end

local function NormalizeNewLines(text)
	local newlines = 0
	text = text:gsub("([^\r\n]*)(\r?\n?)", function(text, newline)
		if #newline ~= 0 then
			newlines = newlines + 1
			return text .. "\n"
		end
		return text
	end)
	return text, newlines
end

local function CountNewLines(text)
	local count = 0
	for _ in text:gmatch("\n") do
		count = count + 1
	end
	return count
end


----- general methods

function XTextEditor:Init()
	self.lines = { "" }
	self:SetTextHAlign(self.TextHAlign)
	self:SetPlugins(empty_table)
end

function XTextEditor:AlignHDest(dest, free_space)
	if self.TextHAlign == "right" then
		return dest + Max(0, free_space)
	elseif self.TextHAlign == "center" then
		return dest + Max(0, free_space / 2)
	else
		return dest
	end
end

function XTextEditor:SetTranslatedText(text, force_reflow)
	if not self.Multiline then
		text = text:gsub("\n", " "):gsub("\r", "")
	end
	if text == self:GetTranslatedText() and not force_reflow then return end
	
	XEditableText.SetTranslatedText(self, text, false)
	
	local text, newlines = NormalizeNewLines(ApplyCharFilters(self.text, self.NegFilter, self.Filter))
	self.len = utf8.len(text)
	self.newline_count = newlines
	self.lines = { text }
	self.cursor_line = 1
	self.cursor_char = 0
	self.cursor_virtual_x = -1
	self.undo_data = 0
	self.undo_stack = false
	self.redo_stack = false
	self:ReflowTextLine(1, true, text)
	self:ClearSelection()
	self:ScrollTo(0, 0)
	self:InvalidateMeasure()
	self:InvalidateLayout()
	self:OnTextChanged()
	self:InvokePlugins("OnTextChanged")
end

function XTextEditor:GetTranslatedText()
	self:GetText() -- puts the text from the internal representation into the .text member
	return XEditableText.GetTranslatedText(self)
end

function XTextEditor:GetText()
	local text = table.concat(self:GetTextLines())
	if self.NewLine ~= "\n" then
		text = text:gsub("\n", self.NewLine)
	end
	self.text = text
	return XEditableText.GetText(self)
end

function XTextEditor:GetTextLines()
	return self.lines or {}
end


----- plugins

function XTextEditor:SetPlugins(plugins)
	self.plugins = nil
	self.plugin_methods = nil
	if config.DefaultTextEditPlugins then
		plugins = table.copy(plugins or empty_table)
		table.iappend(plugins, config.DefaultTextEditPlugins)
	end
	for _, id in ipairs(plugins or empty_table) do
		local class = _G[id]
		if class.SingleInstance then
			local instance = XTextEditorPluginCache[id]
			if not instance then
				instance = class:new()
				XTextEditorPluginCache[id] = class
			end
			self:AddPlugin(instance)
		else
			self:AddPlugin(class:new({}, self))
		end
	end
end

function XTextEditor:FindPluginOfKind(class)
	for _, plugin in ipairs(self.plugins) do
		if IsKindOf(plugin, class) then
			return plugin
		end
	end
end

function XTextEditor:AddPlugin(plugin)
	local plugins = self.plugins or {}
	plugins[#plugins + 1] = plugin
	self.plugins = plugins
	
	-- cache plugin methods present for this control
	local plugin_methods = self.plugin_methods or {}
	for key, value in pairs(XTextEditorPlugin) do
		if type(value) == "function" and plugin[key] ~= value then
			plugin_methods[key] = true
		end
	end
	self.plugin_methods = plugin_methods
end

function XTextEditor:HasPluginMethod(method)
	local plugin_methods = self.plugin_methods or empty_table
	return plugin_methods[method]
end

function XTextEditor:InvokePlugins(method, ...)
	local plugin_methods = self.plugin_methods or empty_table
	if not plugin_methods[method] then return end
	
	for _, plugin in ipairs(self.plugins) do
		if plugin:HasMember(method) then
			local ret = plugin[method](plugin, self, ...)
			if ret then
				return ret
			end
		end
	end
end


----- editing, undo & redo

function XTextEditor:DeleteText(line, char, to_line, to_char)
	assert(char >= 0 and to_char >= 0 and char <= utf8.len(self.lines[line]) and to_char <= utf8.len(self.lines[to_line]))
	
	if line == to_line then
		local old_text = self.lines[line]
		local new_text = utf8.sub(old_text, 1, char) .. utf8.sub(old_text, to_char + 1)
		self.lines[line] = new_text
		self:ReflowTextLine(line, false, utf8.sub(old_text, char + 1, to_char))
	else
		-- delete the text
		local new_text = utf8.sub(self.lines[line], 1, char) .. utf8.sub(self.lines[to_line], to_char + 1)
		for i = to_line, line + 1, -1 do
			table.remove(self.lines, i)
		end
		
		-- reflow resulting line
		self.lines[line] = new_text
		self:ReflowTextLine(line, true, new_text)
	end
end

function XTextEditor:InsertText(charidx, line, char, text)
	local old_text = self.lines[line]
	assert(char >= 0 and char <= utf8.len(old_text))
	if old_text:ends_with("\n") and char == utf8.len(old_text) and line < #self.lines then
		line, char = line + 1, 0
		old_text = self.lines[line]
	end
	
	self.lines[line] = utf8.sub(old_text, 1, char) .. text .. utf8.sub(old_text, char + 1)
	self:ReflowTextLine(line, true, text)
	return charidx + utf8.len(text)
end

local function undo_data_size(undo_op)
	return 4 * 80 + (undo_op.insert_text and #undo_op.insert_text or 0)
end

-- replaces the selection by 'insert_text', handles cursor and pushing undo ops
-- handles each and every edit operation
function XTextEditor:EditOperation(insert_text, op_type, setcursor_charidx, keep_selection)
	if not self.enabled then return end
	
	local changes_made = false
	local old_lines = #self.lines
	
	-- delete selected text
	local charidx
	local deleted_text = nil
	local line1, char1 = self.cursor_line, self.cursor_char
	local line2, char2
	local undo_cursor_charidx = self:GetCursorCharIdx(line1, char1)
	if self:HasSelection() then
		line1, char1, line2, char2 = self:GetSelectionSortedBounds()
		deleted_text = self:GetSelectedTextInternal()
		self:DeleteText(line1, char1, line2, char2)
		
		charidx = self:GetCursorCharIdx(line1, char1)
		if line1 > #self.lines then -- we've deleted the entire line the cursor was on
			assert(line1 > 1)
			line1, char1 = line1 - 1, #self.lines[line1 - 1]
		end
		self.len = self.len - utf8.len(deleted_text)
		self.newline_count = self.newline_count - CountNewLines(deleted_text)
		self:ClearSelection()
		changes_made = true
	end
	
	-- insert insert_text (if the control's limits are not exceeded)
	local charidx = charidx or self:GetCursorCharIdx()
	local charidx_to = charidx
	if insert_text then
		if not self:GetMultiline() then
			insert_text = insert_text:gsub("[\r\n]+", "")
		end
		local text, newlines = NormalizeNewLines(ApplyCharFilters(insert_text, self.NegFilter, self.Filter))
		local len = self.len + utf8.len(text)
		local newline_count = self.newline_count + newlines
		if (self.MaxLen < 0 or len <= self.MaxLen) and (self.MaxLines < 0 or newline_count < self.MaxLines) then
			charidx_to = self:InsertText(charidx, line1, char1, text)
			self.len = len
			self.newline_count = newline_count
		end
		changes_made = true
	end
	
	if not changes_made then return end
	
	-- update cursor position; invalidate
	self:SetCursor(self:CursorFromCharIdx(setcursor_charidx or charidx_to))
	self:InvalidateMeasure()
	self:InvalidateLayout()
	self:Invalidate()
	self:OnTextChanged()
	self:InvokePlugins("OnTextChanged")
	if keep_selection then
		assert(not setcursor_charidx) -- this case is yet unused and thus not handled
		line2, char2 = self.cursor_line, self.cursor_char
		self:SetCursor(line1, char1, false)
		self:SetCursor(line2, char2, true)
	end
	
	-- can we merge this undo operation into the previous one?
	local prev_op = self.undo_stack and self.undo_stack[#self.undo_stack]
	if prev_op and op_type ~= "undo" and op_type ~= "paste" and op_type ~= "cut" then
		if not prev_op.insert_text and not deleted_text and prev_op.charidx_to == charidx then
			-- merge insertions
			prev_op.charidx_to = charidx_to
			return
		elseif prev_op.insert_text and deleted_text and prev_op.charidx == prev_op.charidx_to and charidx == charidx_to then
			-- merge deletions
			if prev_op.charidx == charidx then
				prev_op.insert_text = prev_op.insert_text .. deleted_text
				self.undo_data = self.undo_data + #deleted_text
				return
			elseif charidx + utf8.len(deleted_text) == prev_op.charidx then
				prev_op.charidx = charidx
				prev_op.charidx_to = charidx_to
				prev_op.insert_text = deleted_text .. prev_op.insert_text
				self.undo_data = self.undo_data + #deleted_text
				return
			end
		end
	end
	
	-- insert undo operation; use char indexes so undo/redo can work properly after a resize
	local undo_op = { charidx = charidx, charidx_to = charidx_to, insert_text = deleted_text, cursor_charidx = undo_cursor_charidx }
	if op_type == "undo" then
		return undo_op
	end
	self.redo_stack = false
	self.undo_stack = self.undo_stack or {}
	table.insert(self.undo_stack, undo_op)
	
	-- cleanup least recent undo operations if we exceed 'max_undo_data'
	self.undo_data = self.undo_data + undo_data_size(undo_op)
	while self.undo_data > self.max_undo_data do
		undo_op = table.remove(self.undo_stack, 1)
		self.undo_data = self.undo_data - undo_data_size(undo_op)
	end
end

function XTextEditor:Undo()
	if self.undo_stack and #self.undo_stack > 0 then
		local undo_op = table.remove(self.undo_stack)
		self.undo_data = self.undo_data - undo_data_size(undo_op)
		
		undo_op = self:ExecuteUndoRedoOp(undo_op)
		self.redo_stack = self.redo_stack or {}
		table.insert(self.redo_stack, undo_op)
	end
end

function XTextEditor:Redo()
	if self.redo_stack and #self.redo_stack > 0 then
		local undo_op = self:ExecuteUndoRedoOp(table.remove(self.redo_stack))
		table.insert(self.undo_stack, undo_op)
	end
end

function XTextEditor:ExecuteUndoRedoOp(undo_op)
	self.selection_start_line, self.selection_start_char = self:CursorFromCharIdx(undo_op.charidx)
	local cursor_line, cursor_char = self:CursorFromCharIdx(undo_op.charidx_to)
	self:SetCursor(cursor_line, cursor_char, true)
	return self:EditOperation(undo_op.insert_text, "undo", undo_op.undo_cursor_charidx)
end

function XTextEditor:ExchangeLines(line1, line2, line3, cursor_anchor_line)
	local text1 = self:GetSelectedTextInternal(line1, 0, line2, 0)
	local text2 = self:GetSelectedTextInternal(line2, 0, line3, 0)
	if not text2:ends_with("\n") then
		text1, text2 = text1:sub(0, -2), text2.."\n"
	end
	local cursor_offs = self:GetCursorCharIdx() - self:GetCursorCharIdx(cursor_anchor_line, 0)
	local cursor_idx = cursor_offs + self:GetCursorCharIdx(line1, 0) + (cursor_anchor_line == line1 and utf8.len(text2) or 0)
	self:SetCursor(line1, 0)
	self:SetCursor(line3, 0, "select")
	self:EditOperation(text2..text1, false, cursor_idx)
end

function XTextEditor:ShouldProcessChar(ch)
    return
		(ch ~= "" and string.byte(ch) >= 32 or ch == "\r" or ch == "\n") and
		(not IsControlPressed() == not IsAltPressed()) and -- CTRL + ALT == AltGR. AltGR is used for sending special chars.
		(not self.Filter or string.find(ch, self.Filter)) and
		(not string.find(self.NegFilter, ch, 1, true)) and
		(not self.AllowTabs or ch ~= "\t") and
		(self:GetMultiline() or (ch ~= "\r" and ch ~= "\n"))
end

function XTextEditor:ProcessChar(ch)
	if self:ShouldProcessChar(ch) then
		-- auto-indent when Enter is pressed
		if ch == "\r" or ch == "\n" then
			local last_nonempty_line
			for i = self.cursor_line, 1, -1 do
				if self.lines[i]:find("%S") then
					last_nonempty_line = self.lines[i]
					break
				end
			end
			ch = last_nonempty_line and "\n" .. last_nonempty_line:match("\t*") or "\n"
		end
		self:EditOperation(ch)
		return true
	end
	return false
end

function XTextEditor:OnShortcut(shortcut, source, ...)
	if self:InvokePlugins("OnShortcut", shortcut, source, ...) then
		return "break"
	end
	
	-- Edit commands
	if shortcut == "Escape" and self.AllowEscape and self:HasSelection() then
		self:ClearSelection()
		return "break"
	elseif shortcut == "Tab" and self.AllowTabs then
		self:EditOperation("\t")
		return "break"
	elseif shortcut == "Ctrl-Insert" and not self.Password then
		CopyToClipboard(self:GetSelectedText())
		return "break"
	elseif shortcut == "Shift-Insert" then
		self:EditOperation(GetFromClipboard(Max(self.MaxLen, 65536)), "paste")
		return "break"
	elseif shortcut == "Shift-Delete" and not self.Password then
		CopyToClipboard(self:GetSelectedText())
		self:EditOperation(nil, "cut") -- deletes the selection
		return "break"
	elseif shortcut == "Delete" then
		if not self:HasSelection() then
			self.selection_start_line, self.selection_start_char = self:NextCursorPos("to_next_char")
		end
		self:EditOperation() -- deletes the selection
		return "break"
	elseif shortcut == "Backspace" then
		if not self:HasSelection() then
			self.selection_start_line, self.selection_start_char = self:PrevCursorPos("to_next_char")
		end
		self:EditOperation() -- deletes the selection
		return "break"
	elseif shortcut == "Ctrl-Delete" then
		self:ClearSelection()
		local line, char = self:NextWordForward(self.cursor_line, self.cursor_char)
		self:SetCursor(line, char, true)
		if self:HasSelection() then
			self:ReverseSelectionBounds() -- so that the cursor returns before the word after undo
			self:EditOperation() -- deletes the selection
		end
		return "break"
	elseif shortcut == "Ctrl-Backspace" then
		self:ClearSelection()
		local line, char = self:NextWordBack(self.cursor_line, self.cursor_char)
		self:SetCursor(line, char, true)
		if self:HasSelection() then
			self:ReverseSelectionBounds() -- so that the cursor returns after the word after undo
			self:EditOperation() -- deletes the selection
		end
		return "break"
	elseif shortcut == "Ctrl-A" then
		self:SelectAll()
		return "break"
	elseif shortcut == "Ctrl-C" and not self.Password then
		if self:HasSelection() then
			CopyToClipboard(self:GetSelectedText())
		else
			CopyToClipboard(self.lines[self.cursor_line])
		end
		return "break"
	elseif shortcut == "Ctrl-X" and not self.Password then
		if not self:HasSelection() then
			self.selection_start_line = self.cursor_line
			self.selection_start_char = 0
			self.cursor_char = utf8.len(self.lines[self.cursor_line])
		end
		CopyToClipboard(self:GetSelectedText())
		self:EditOperation(nil, "cut") -- deletes the selection
		return "break"
	elseif shortcut == "Ctrl-V" then
		if self.AllowPaste then
			self:EditOperation(GetFromClipboard(Max(self.MaxLen, 65536)), "paste")
		end
		return "break"
	elseif shortcut == "Ctrl-Z" then
		self:Undo()
		return "break"
	elseif shortcut == "Ctrl-Y" then
		self:Redo()
		return "break"
	end
	
	-- Cursor navigation
	local consume_key = false
	local line = self.cursor_line
	local char = self.cursor_char
	shortcut = string.gsub(shortcut, "Shift%-", "") -- ignore shift
	
	-- left, right, home, end, ctrl + (left, right, home, end)
	if shortcut == "Left" then
		line, char = self:PrevCursorPos(IsShiftPressed() and "to_next_char")
		consume_key = true
	elseif shortcut == "Right" then
		line, char = self:NextCursorPos(IsShiftPressed() and "to_next_char")
		consume_key = true
	elseif shortcut == "Home" then
		local white_space = self.lines[line]:find("[^%s]")
		local first_word = white_space and white_space - 1 or 0
		if char == first_word then
			char = 0
		else
			char = first_word
		end
		consume_key = true
	elseif shortcut == "End" then
		local line_text = self.lines[line]
		char = utf8.len(line_text) - (self:ShouldIgnoreLastLineChar(line, line_text) and 1 or 0)
		consume_key = true
	elseif shortcut == "Ctrl-Left" then
		line, char = self:NextWordBack(line, char)
		consume_key = true
	elseif shortcut == "Ctrl-Right" then
		line, char = self:NextWordForward(line, char)
		consume_key = true
	elseif shortcut == "Ctrl-Home" then
		line, char = 1, 0
		consume_key = true
	elseif shortcut == "Ctrl-End" then
		line = #self.lines
		local line_text = self.lines[line]
		char = utf8.len(line_text) - (self:ShouldIgnoreLastLineChar(line, line_text) and 1 or 0)
		consume_key = true
	end
	
	if consume_key then
		self:SetCursor(line, char, IsShiftPressed())
		return "break"
	end
	
	-- up, down, pageup, pagedown
	if self:GetMultiline() then
		local v_offset = 0
		if shortcut == "Up" then
			v_offset = -self.font_height
			v_offset = v_offset - (self:InvokePlugins("VerticalSpaceAfterLine", self.cursor_line - 1) or 0)
		elseif shortcut == "Down" then
			v_offset = self.font_height
		elseif shortcut == "Pageup" then
			v_offset = -self.content_box:sizey()
		elseif shortcut == "Pagedown" then
			v_offset = self.content_box:sizey()
		end
		
		if v_offset ~= 0 then
			local x, y = self:GetCursorXY()
			if self.cursor_virtual_x then
				x = self.cursor_virtual_x
			else
				self.cursor_virtual_x = x
			end
			
			local out_of_bounds
			line, char, out_of_bounds = self:CursorFromPoint(x, y + v_offset)
			self:SetCursor(line, char, IsShiftPressed())
			if not out_of_bounds then
				self.cursor_virtual_x = x -- SetCursor resets this member, keep it intact
			end
			return "break"
		end
	end
end


----- word/line-wrapping

function XTextEditor:TrimLineForWordWrap(width, line)
	local newline
	local line_width = 0
	local line_length = 0
	local line_text = self.lines[line]
	local font = self:GetFontId()
	for word in line_text:gmatch(word_pattern) do
		local orig_length = #word
		local length = orig_length
		local to_newline = word:match("([^\n]*)\n")
		if to_newline then
			word = to_newline
			length = #to_newline + 1
			newline = true
		end
		
		local word_width = self:MeasureTextForDisplay(word) or 0
		if line_width + word_width > width then
			if line_width == 0 then -- force-wrap any words longer than our width
				word, word_width = TrimTextToWidth(word, font, width - line_width)
				length = #word
			else
				word_width = 0
				length = 0
			end
		end
		
		line_width = line_width + word_width
		line_length = line_length + length
		if newline or length ~= orig_length then
			break
		end
	end
	
	-- push characters that lines shouldn't end with to the next line (quotes, brackets, etc.)
	local text = line_text:sub(1, line_length)
	if #text ~= 1 and #line_text ~= line_length and not text:ends_with("\n") then
		local cant_start, cant_end = utf8.GetLineBreakInfo(text)
		if cant_end or text:ends_with('"') or text:ends_with("'") then
			text = text:sub(1, -2)
			line_width = self:MeasureTextForDisplay(text) or 0
			line_length = line_length - 1
		end
	end
	
	self.lines[line] = text
	return line_text:sub(line_length + 1) -- returns remaining text
end

-- performs/updates word-wrapping (or splits into lines if WordWrap is false)
function XTextEditor:ReflowTextLine(line, inserting_text, text_diff, width)
	width = (width or self.content_box:sizex()) - 1 -- reserve 1 pixel for cursor
	if width <= 0 then
		assert(#self.lines == 1) -- we expect to be here only when initially setting the text at control creation time
		self.need_reflow = true
		return
	end
	self.need_reflow = nil
	
	local lines = self.lines
	local newline_inserted = inserting_text and text_diff:find("\n")
	if not self.WordWrap then
		if newline_inserted then
			local text = table.remove(lines, line)
			local trailing_newline = false
			for line_text, newline in string.gmatch(text, "([^\n]*)(\n?)") do
				if line_text ~= "" or newline ~= "" then
					table.insert(lines, line, line_text .. (newline ~= "" and "\n" or ""))
					line = line + 1
					trailing_newline = #newline ~= 0
				end
			end
			if trailing_newline then
				table.insert(lines, line, "")
			end
		end
		
		-- editing the text might have removed the trailing newline => merge with next line
		if line < #lines and not lines[line]:ends_with("\n") then
			local new_text = lines[line] .. lines[line + 1]
			lines[line] = new_text
			table.remove(lines, line + 1)
		end
		return
	end

	-- word-wrapping case; prevent excessive text splitting by capping up the width
	width = Max(width, 5 * self.font_height)
	
	-- optimization in case of deleting only a part of a single line
	local text = lines[line]
	if not inserting_text then
		local text_width = self:MeasureTextForDisplay(text)
		
		-- no need to get text from the next line into the current?
		if line == #lines or lines[line]:ends_with("\n") then
			return
		end
		
		-- a forcefully wordwrapped word need to always be reflowed
		local next_line_text = lines[line + 1]
		local long_word = text:sub(-1, -1):match(word_chars)
		if not long_word then
			-- if we can't fit the first word of the next line, there's nothing to do
			local first_word = next_line_text:match(word_pattern)
			if not first_word or #first_word == 0 or self:MeasureTextForDisplay(first_word) > width - text_width then
				return
			end
		end
	end
	
	-- form entire text to be reflowed
	local prev_line_text = line ~= 1 and lines[line - 1]
	if prev_line_text and not prev_line_text:ends_with("\n") then
		line = line - 1
		text = prev_line_text
	end
	local i = line + 1
	while i <= #self.lines and (not text:ends_with("\n") or text:sub(-1, -1):match(word_chars)) do
		text = text .. self.lines[i]
		table.remove(self.lines, i)
	end
	self.lines[line] = text
		
	-- rewrap text
	local remaining_text = self:TrimLineForWordWrap(width, line)
	while #remaining_text > 0 do
		line = line + 1
		if line > #lines or remaining_text:ends_with("\n") then
			table.insert(lines, line, remaining_text)
		else
			lines[line] = remaining_text .. lines[line]
		end
		remaining_text = self:TrimLineForWordWrap(width, line)
	end
	if line == #lines and lines[line]:ends_with("\n") then
		lines[line + 1] = ""
	end
end


----- focus & cursor

function XTextEditor:OnSetFocus(old_focus)
	if not hr.ImeCompositionStarted then
		self:CreateCursorBlinkThread()
	end

	-- select all only on focus transfers and not on inactive->active transitions
	if self.AutoSelectAll and (old_focus and not self.desktop.inactive) then
		self:SelectAll()
	end
	
	ShowVirtualKeyboard(true)
	if self.Ime then
		ShowIme()
	end
	self:ImeUpdatePos()
	
	self:InvokePlugins("OnSetFocus", self, old_focus)
end

function XTextEditor:OnKillFocus()
	ShowVirtualKeyboard(false)
	self:DestroyCursorBlinkThread()
	self:ClearSelection()
	if not self:GetMultiline() then
		self:ScrollTo(0, 0)
	end
	if self.Ime then
		HideIme()
	end
	self:InvokePlugins("OnKillFocus", self)
	self:Invalidate()
end

function XTextEditor:ImeUpdatePos()
	if IsImeEnabled() and self:IsFocused() then
		local x, y = self:GetCursorXY()
		SetImePosition(x, y, self:GetFontId())
	end
end

function XTextEditor:CreateCursorBlinkThread()
	if not self.blink_cursor_thread then
		self.blink_cursor_thread = CreateRealTimeThread(function()
			while true do
				self.show_cursor = self.stop_blink or not self.show_cursor
				self.stop_blink = false
				self:Invalidate()
				Sleep(self.cursor_blink_time)
			end
		end)
	end
end

function XTextEditor:DestroyCursorBlinkThread()
	DeleteThread(self.blink_cursor_thread)
	self.blink_cursor_thread = false
	self.show_cursor = false
	self.stop_blink = false
end

function XTextEditor:LineIdxFromScreenY(y)
	y = y - self.content_box:miny() + self.OffsetY
	if not self:HasPluginMethod("VerticalSpaceAfterLine") then
		local line = y / self.font_height
		return line + 1, line * self.font_height
	end
	
	local line, cy = 1, 0
	local line_height = self.font_height
	repeat
		cy = cy + (self:InvokePlugins("VerticalSpaceAfterLine", line - 1) or 0)
		if cy + line_height > y then
			return line, cy
		end
		line = line + 1
		cy = cy + line_height
	until line > #self.lines
	return line, cy
end

function XTextEditor:ShouldIgnoreLastLineChar(line, text)
	text = text or self.lines[line]
	return text:ends_with("\n") or line ~= #self.lines and text:ends_with(" ")
end

function XTextEditor:CursorFromPoint(x, y)
	local font = self:GetFontId()
	local line = self:LineIdxFromScreenY(y)
	if line < 1 then
		return 1, 0, true
	elseif line > #self.lines then
		line = #self.lines
		local line_text = self.lines[line]
		return line, utf8.len(line_text), true
	end
	
	local text_pos_x = x - self.content_box:minx() + self.OffsetX
	text_pos_x = text_pos_x - self:AlignHDest(0, self.content_box:sizex() - self:MeasureTextForDisplay(self.lines[line]))
	
	local text, length = self:GetDisplayText(line)
	if self:ShouldIgnoreLastLineChar(line, text) then
		text, length = text:sub(1, -2), length - 1
	end
	local text_to_cursor = TrimTextToWidth(text, font, text_pos_x)
	local char = utf8.len(text_to_cursor)
	if char ~= length then
		local x1 = UIL.MeasureToCharStart(text, font, char + 1)
		local x2 = UIL.MeasureToCharStart(text, font, char + 2)
		char = text_pos_x > (x1 + x2) / 2 and char + 1 or char
	end
	return line, char
end

local pw = string.rep("*", 32)

local function ensure_stars_count(len)
	if len > #pw then
		pw = string.rep(pw, len / #pw + 1)
	end
end

function XTextEditor:MeasureTextForDisplay(text, up_to_start_of)
	if self.Password then
		up_to_start_of = up_to_start_of or utf8.len(text) + 1
		ensure_stars_count(up_to_start_of)
		text = pw
	end
	if not up_to_start_of then
		return UIL.MeasureText(text, self:GetFontId())
	end
	return UIL.MeasureToCharStart(text, self:GetFontId(), up_to_start_of)
end

function XTextEditor:GetDisplayText(line)
	local text = self.lines[line]
	local len = text and utf8.len(text)
	if self.Password then
		local bShowLastPswdLetter = len >= 1 and self.ShowLastPswdLetter
		local stars = bShowLastPswdLetter and len - 1 or len
		ensure_stars_count(stars)
		return bShowLastPswdLetter and utf8.sub(pw, 1, stars).. utf8.sub(text, len, len) or utf8.sub(pw, 1, stars), len
	end
	return text, len
end

function XTextEditor:GetCursorXY()
	local line = self.cursor_line
	local text = self.lines[line]
	local cursor_x = self:MeasureTextForDisplay(text, self.cursor_char + 1)
	cursor_x = self:AlignHDest(cursor_x, self.content_box:sizex() - self:MeasureTextForDisplay(text))
	
	local line_height = self.font_height
	local cursor_y = (line - 1) * line_height
	if self:HasPluginMethod("VerticalSpaceAfterLine") then
		for i = 0, line - 1 do
			cursor_y = cursor_y + (self:InvokePlugins("VerticalSpaceAfterLine", i) or 0)
		end
	end
	return self.content_box:minx() - self.OffsetX + cursor_x, self.content_box:miny() - self.OffsetY + cursor_y
end

function XTextEditor:SetCursor(line, char, selecting, include_last_endline)
	if not selecting then
		self:ClearSelection()
	end
	
	if line == #self.lines + 1 and char == 0 then
		line = line - 1
		char = utf8.len(self.lines[line])
	end
	local line_text = self.lines[line]
	if not line_text then
		return
	end
	
	if char == utf8.len(line_text) and self:ShouldIgnoreLastLineChar(line, line_text) and not include_last_endline then
		line, char = line + 1, 0 -- go to the following line if we are at the end of a trailing \n or space
	end
	
	if self.cursor_line == line and self.cursor_char == char then
		return
	end
	
	if selecting and not self:HasSelection() then
		self:StartSelecting()
	end
	self.cursor_line = line
	self.cursor_char = char
	self.cursor_virtual_x = false
	self.stop_blink = true
	
	if not self:GetThread("CursorAndIMEUpdate") then
		self:CreateThread("CursorAndIMEUpdate", function()
			if self.window_state ~= "destroying" then
				if self:IsFocused() then
					self:ScrollCursorIntoView()
				end
				self:ImeUpdatePos()
				self:Invalidate()
			end
		end)
	end
end

function XTextEditor:GetCursorCharIdx(line, char)
	line = line or self.cursor_line
	
	local idx = 0
	local lines = self.lines
	for i = 1, line - 1 do
		idx = idx + utf8.len(lines[i])
	end
	return idx + (char or self.cursor_char)
end

function XTextEditor:CursorFromCharIdx(idx)
	local line = 1
	local lines = self.lines
	local line_len = utf8.len(lines[line])
	while idx > line_len and line < #lines do
		idx = idx - line_len
		line = line + 1
		line_len = utf8.len(lines[line])
	end
	idx = Min(idx, line_len)
	return line, idx
end

function XTextEditor:PrevCursorPos(to_next_char)
	local line, char = self.cursor_line, self.cursor_char
	if char > 0 then
		return line, char - 1
	elseif self.cursor_line > 1 then
		local line_text = self.lines[line - 1]
		local skip_last = to_next_char or self:ShouldIgnoreLastLineChar(line - 1, line_text)
		return line - 1, utf8.len(line_text) - (skip_last and 1 or 0)
	else
		return line, char
	end
end

function XTextEditor:NextCursorPos(to_next_char)
	local line, char = self.cursor_line, self.cursor_char
	local ignore_last_char = self:ShouldIgnoreLastLineChar(line)
	if char < utf8.len(self.lines[line]) - (ignore_last_char and 1 or 0) then
		return line, char + 1
	elseif line < #self.lines then
		return line + 1, (not ignore_last_char and to_next_char) and 1 or 0
	else
		return line, char
	end
end

function XTextEditor:NextWordBack(line, char)
	if char == 0 and line > 1 then
		line = line - 1
		char = utf8.len(self.lines[line])
	end
	
	local pos, prev_pos = 0, 0
	for word in self.lines[line]:gmatch(word_pattern) do
		prev_pos = pos
		pos = pos + utf8.len(word)
		if pos >= char then
			char = prev_pos
			break
		end
	end
	return line, char
end

function XTextEditor:NextWordForward(line, char)
	local pos = 0
	for word in self.lines[line]:gmatch(word_pattern) do
		pos = pos + utf8.len(word)
		if pos > char then
			char = pos
			break
		end
	end
	
	if char == utf8.len(self.lines[line]) and line < #self.lines then
		line = line + 1
		char = 0
	end
	return line, char
end

function XTextEditor:ScrollCursorIntoView()
	local x, y = self:GetCursorXY()
	local height = self.font_height
	if self.cursor_line == #self.lines then
		height = height + (self:InvokePlugins("VerticalSpaceAfterLine", #self.lines) or 0)
	end
	self:ScrollIntoView(box(x, y, x + 1, y + height))
end


----- measure & draw

function XTextEditor:GetMaxLineWidth()
	local result = 0
	for _, text in ipairs(self.lines) do
		result = Max(result, self:MeasureTextForDisplay(text))
	end
	return result
end

function XTextEditor:Measure(preferred_width, preferred_height)
	XControl.Measure(self, preferred_width, preferred_height) -- skip XScrollArea.Measure
	if self.need_reflow then
		self:ReflowTextLine(1, true, self.lines[1], preferred_width)
	end
	
	local width = self:GetMaxLineWidth()
	local line_count = #(self.lines or "")
	self.scroll_range_x = width
	self.scroll_range_y = line_count * self:GetFontHeight()
	local extra_height = 0
	if self:HasPluginMethod("VerticalSpaceAfterLine") then
		for i = 0, line_count do
			extra_height = extra_height + (self:InvokePlugins("VerticalSpaceAfterLine", i) or 0)
		end
	end
	self.scroll_range_y = self.scroll_range_y + extra_height
	local h = self:GetFontHeight()
	return width, Clamp(line_count * h + extra_height, self.MinVisibleLines * h, self.MaxVisibleLines * h)
end

local StretchText = UIL.StretchText
local MeasureText = UIL.MeasureText
local MeasureToCharStart = UIL.MeasureToCharStart
local DrawSolidRect = UIL.DrawSolidRect

function XTextEditor:DrawCursor(color)
	if self.show_cursor and terminal.desktop.keyboard_focus == self and not hr.ImeCompositionStarted then
		local x, y = self:GetCursorXY()
		DrawSolidRect(sizebox(x, y, 1, self.font_height), color or self:CalcTextColor())
	end
end

function XTextEditor:DrawWindow(...)
	self:InvokePlugins("OnBeginDraw")
	XScrollArea.DrawWindow(self, ...)
	self:InvokePlugins("OnEndDraw")
end

function XTextEditor:DrawContent(clip_box)
	local destx = self.content_box:minx() - self.OffsetX
	local desty = self.content_box:miny() - self.OffsetY
	local sizex = self.content_box:sizex()
	local font = self:GetFontId()
	local text_color = self:CalcTextColor()
	local lines = self.lines or {}
	local line_height = self.font_height
	
	local hint = self.Hint
	if hint ~= "" and (not lines[1] or lines[1] == "") then
		if self.Translate then
			hint = _InternalTranslate(hint, self.context)
		end
		local hint_width = MeasureText(hint, font)
		local hint_height = self:GetFontHeight()
		local align_y = 0
		if self.HintVAlign == "center" then
			align_y = (self.content_box:sizey() - hint_height) / 2
		elseif self.HintVAlign == "bottom" then
			align_y = self.content_box:sizey() - hint_height
		end
		local hint_desty = desty + align_y
		local target_box = sizebox(self:AlignHDest(destx, sizex - hint_width), hint_desty, hint_width, line_height)
		StretchText(hint, target_box, font, self.HintColor)
		self:DrawCursor(text_color)
		return
	end
	
	-- get first line that is fully in the view
	local start_idx, start_y = self:LineIdxFromScreenY(self.content_box:miny()) -- start_y is the start of line start_idx in local coords
	if start_y > self.OffsetY then -- go back one line if needed
		start_idx = start_idx - 1
		start_y = start_y - line_height - (self:InvokePlugins("VerticalSpaceAfterLine", start_idx) or 0)
	end
	desty = desty + start_y
	
	if start_idx <= #lines then
		-- are we starting to draw from within the selection?
		local color = text_color
		local in_selection = false
		local sstart_line, sstart_char, send_line, send_char = self:GetSelectionSortedBounds()
		if self.ime_korean_composition then
			send_line = sstart_line
			send_char = sstart_char
		elseif sstart_line and send_line >= start_idx and
			(sstart_line < start_idx or sstart_line == start_idx and sstart_char == 0)
		then
			color = self.SelectionColor
			in_selection = true
		end
		
		-- let plugins process text before the first draw line
		if self:HasPluginMethod("OnDrawLineOutsideView") then
			for i = 1, start_idx - 1 do
				self:InvokePlugins("OnDrawLineOutsideView", i, self:GetDisplayText(i), "above_view")
			end
		end
		
		-- start drawing line by line
		-- draw entire unselected text first, and selection above it
		local end_idx = Min(#lines, start_idx + self.content_box:sizey() / line_height + 1)
		for i = start_idx, end_idx do
			local text = self:GetDisplayText(i)
			local ends_with_new_line = text:ends_with("\n")
			if ends_with_new_line then
				text = text:sub(1, -2)
			end
			local width = self:MeasureTextForDisplay(text)
			
			-- draw entire unselected text first
			local orig_text, orig_target
			local target_box = sizebox(self:AlignHDest(destx, sizex - width), desty, width, line_height)
			if not self:InvokePlugins("OnBeforeDrawText", i, text, target_box, font, text_color) then
				StretchText(text, target_box, font, text_color)
			end
			if not (in_selection and send_line ~= i) then
				self:InvokePlugins("OnAfterDrawText", i, text, target_box, font, text_color)
				orig_text, orig_target = text, target_box
			end
			 
			-- draw the selection marquee and selected text second (above unselected text)
			if in_selection or sstart_line == i or send_line == i then
				local start_x = in_selection and 0 or MeasureToCharStart(text, font, sstart_char + 1)
				local end_x = send_line == i and MeasureToCharStart(text, font, send_char + 1) or width
				if send_line ~= i and ends_with_new_line then
					end_x = end_x + self.font_height / 4 -- mark EOL character in selection
				end
				local target_box = sizebox(destx + self:AlignHDest(start_x, sizex - width), desty, end_x - start_x, line_height)
				DrawSolidRect(target_box, self.SelectionBackground)
				
				local start_char = in_selection and 1 or sstart_char + 1
				text = send_line == i and utf8.sub(text, start_char, send_char) or utf8.sub(text, start_char)
				width = self:MeasureTextForDisplay(text)
				target_box = Resize(target_box, width, target_box:sizey())
				StretchText(text, target_box, font, self.SelectionColor)
				if in_selection and send_line ~= i then
					self:InvokePlugins("OnDrawText", i, text, target_box, font, text_color)
				end
				
				in_selection = send_line ~= i
			end
			
			if orig_text then
				self:InvokePlugins("OnDrawText", i, orig_text, orig_target, font, text_color)
			end
			
			desty = desty + line_height + (self:InvokePlugins("VerticalSpaceAfterLine", i) or 0)
		end
		
		-- let plugins process text before the first draw line
		if self:HasPluginMethod("OnDrawLineOutsideView") then
			for i = end_idx + 1, #lines do
				self:InvokePlugins("OnDrawLineOutsideView", i, self:GetDisplayText(i), not "above_view")
			end
		end
	end
	
	self:DrawCursor(text_color)
end

function XTextEditor:SetBox(x, y, width, height)
	if not self.lines then
		XScrollArea.SetBox(self, x, y, width, height)
		return
	end
	
	local need_reflow = self.WordWrap and width ~= self.box:sizex()
	local size_changed = width ~= self.box:sizex() or height ~= self.box:sizey()
	XScrollArea.SetBox(self, x, y, width, height)
	if need_reflow then
		local cursor_idx = self:GetCursorCharIdx()
		self:SetTranslatedText(table.concat(self:GetTextLines()), "force_reflow")
		self:SetCursor(self:CursorFromCharIdx(cursor_idx))
	elseif size_changed and self:IsFocused() then
		self:ScrollCursorIntoView()
	end
end


----- selection

function XTextEditor:StartSelecting()
	self.selection_start_line = self.cursor_line
	self.selection_start_char = self.cursor_char
end

function XTextEditor:ClearSelection()
	if self.selection_start_line == false and self.selection_start_char == false then return end 
	self.selection_start_line = false
	self.selection_start_char = false
	self:Invalidate()
end

function XTextEditor:HasSelection()
	return
		self.selection_start_line and
		(self.selection_start_line ~= self.cursor_line or self.selection_start_char ~= self.cursor_char)
end

function XTextEditor:ReverseSelectionBounds()
	self.selection_start_line, self.selection_start_char, self.cursor_line, self.cursor_char = 
	self.cursor_line, self.cursor_char, self.selection_start_line, self.selection_start_char
end

function XTextEditor:GetSelectionSortedBounds()
	if not self:HasSelection() then
		return
	end
	
	local selection_backwards =
		self.selection_start_line < self.cursor_line or 
		self.selection_start_line == self.cursor_line and self.selection_start_char < self.cursor_char
	if selection_backwards then
		return self.selection_start_line, self.selection_start_char, self.cursor_line, self.cursor_char
	else
		return self.cursor_line, self.cursor_char, self.selection_start_line, self.selection_start_char
	end
end

function XTextEditor:GetSelectedTextInternal(sstart_line, sstart_char, send_line, send_char)
	if not sstart_line then
		sstart_line, sstart_char, send_line, send_char = self:GetSelectionSortedBounds()
	end
	if not sstart_line then
		return ""
	elseif sstart_line == send_line then
		return utf8.sub(self.lines[sstart_line], sstart_char + 1, send_char)
	else
		return
			utf8.sub(self.lines[sstart_line], sstart_char + 1) ..
			table.concat(self.lines, "", sstart_line + 1, send_line - 1) ..
			(send_line > #self.lines and "" or utf8.sub(self.lines[send_line], 1, send_char))
	end
end

function XTextEditor:GetSelectedText()
	local text = self:GetSelectedTextInternal()
	if self.NewLine ~= "\n" then
		text = text:gsub("\n", self.NewLine)
	end
	return text
end

function XTextEditor:SelectAll()
	self:SetCursor(1, 0, false)
	self:SetCursor(#self.lines, utf8.len(self.lines[#self.lines]), true)
end

function XTextEditor:SelectFirstOccurence(text, ignore_case)
	if text == "" then return end
	if ignore_case then
		text = text:lower()
	end
	for line, line_text in ipairs(self.lines) do
		line_text = ignore_case and line_text:lower() or line_text
		local char = string.find(line_text, text, 1, true)
		if char then
			self:ClearSelection()
			self:SetCursor(line, char - 1, false)
			self:SetCursor(line, char - 1 + utf8.len(text), true)
			self:ScrollCursorIntoView()
			self:InvokePlugins("OnSelectHighlight", text, ignore_case)
			return true
		end
	end
end

function XTextEditor:SelectWordUnderCursor()
	local pos = 0
	local line_text = self.lines[self.cursor_line]
	for word in line_text:gmatch(word_pattern) do
		local len = utf8.len(word)
		if pos + len > self.cursor_char then
			word = word:match(strict_word_pattern)
			self:ClearSelection()
			self:SetCursor(self.cursor_line, pos, false)
			self:SetCursor(self.cursor_line, pos + utf8.len(word), true)
			self:InvokePlugins("OnWordSelection", word)
			return true
		end
		pos = pos + len
	end
end

function XTextEditor:GetWordUnderCursor(pt)
	local pos = 0
	local line, char = self:CursorFromPoint(pt:x(), pt:y())
	local line_text = self.lines[line]
	for word in line_text:gmatch(word_pattern) do
		local len = utf8.len(word)
		if pos + len > char then
			word = word:match(strict_word_pattern)
			return word
		end
		pos = pos + len
	end
end


----- messages

function XTextEditor:OnMouseButtonDown(pt, button)
	if button == "L" then
		if self.desktop:GetKeyboardFocus() ~= self and self.AutoSelectAll then
			self:SetFocus()
		else
			local line, char = self:CursorFromPoint(pt:x(), pt:y())
			self:SetCursor(line, char, IsShiftPressed())
			self:SetFocus()
			if not self.touch then
				self.desktop:SetMouseCapture(self)
			end
		end
		return "break"
	end
	if button == "R" and self:InvokePlugins("OnRightButtonDown", pt) then
		return "break"
	end
end

function XTextEditor:OnMousePos(pt)
	if self.desktop:GetMouseCapture() == self or self.touch then
		local line, char = self:CursorFromPoint(pt:x(), pt:y())
		self:SetCursor(line, char, true)
		return "break"
	end
end

function XTextEditor:OnMouseButtonUp(pt, button)
	if button == "L" then
		self.desktop:SetMouseCapture()
		return "break"
	end
end

function XTextEditor:OnMouseButtonDoubleClick(pt, button)
	if button == "L" then
		if not self:SelectWordUnderCursor() then
			local line_text = self.lines[self.cursor_line]
			self:ClearSelection()
			self:SetCursor(self.cursor_line, 0, false)
			self:SetCursor(self.cursor_line, utf8.len(line_text), true)
		end
		return "break"
	end
end

function XTextEditor:OnTouchBegan(id, pt, touch)
	self.touch = true
	self:OnMouseButtonDown(pt, "L")
	return "capture"
end

function XTextEditor:OnTouchMoved(id, pt, touch)
	if touch.capture == self then
		self:OnMousePos(pt)
		return "break"
	end
end

function XTextEditor:OnTouchEnded()
	self.touch = false
	return "break"
end

function XTextEditor:OnTouchCancelled()
	self.touch = false
	return "break"
end

function XTextEditor:OnKbdKeyUp(virtual_key)
	if self:ShouldConsumeVk(virtual_key) then
		return "break"
	end
end

function XTextEditor:OnKbdKeyDown(virtual_key)
	if self:InvokePlugins("OnKbdKeyDown", virtual_key) then
		return "break"
	end
	if self:ShouldConsumeVk(virtual_key) then
		return "break"
	end
end

function XTextEditor:ShouldConsumeVk(virtual_key)
	-- if we catch Ctrl/Alt/Shift we will break shortcuts.
	-- vkPass are single key shortcuts accepted by the control. We need to pass them as well.
	return self.vkConsume[virtual_key]
			and not IsControlPressed()
			and not IsAltPressed()
			and not table.find(self.vkPass, virtual_key)
end

function XTextEditor:OnKbdChar(char, virtual_key)
	if self:ProcessChar(char) then
		return "break"
	end
end

function XTextEditor:OnKbdIMEStartComposition(char, virtual_key, repeated, time, lang) --char, vkey, repeat, time, lang
	self:DestroyCursorBlinkThread()
	self:Invalidate()
	self:ImeUpdatePos()
	
	if lang == "ko" then
		self.ime_korean_composition = true
	end
	return "break"
end

function XTextEditor:OnKbdIMEEndComposition(...) --char, vkey, repeat, time, lang
	self:CreateCursorBlinkThread()
	self.ime_korean_composition = false
	return "break"
end

function XTextEditor:OnKbdIMEUpdateComposition(...)
	if not self.ime_korean_composition then
		return "break"
	end

	-- replace the IME composition text with the new one, keep it selected
	local charidx = self:GetCursorCharIdx()
	
	local comp = terminal.GetWindowsImeCompositionString()
	self:EditOperation(comp, "undo")
	local line, char = self:CursorFromCharIdx(charidx)
	self:SetCursor(line, char, true)
end

-- Build table with virtual keys, whose messages must be consumed
-- the numbers below are various OEM virtual key codes that correspond to characters, see http://cherrytree.at/misc/vk.htm
XTextEditor.vkConsume = {
	[186] = true, [187] = true, [188] = true, [189] = true, [190] = true,
	[191] = true, [192] = true, [219] = true, [220] = true, [221] = true, [222] = true,
	[226] = true
}
local function AddConsumeConst(string)
    if rawget(const, string) then
	    XTextEditor.vkConsume[const[string]] = true
    end
end

for i = string.byte("A"), string.byte("Z") do
	AddConsumeConst("vk"..string.char(i))
end
for i = string.byte("0"), string.byte("9") do
	AddConsumeConst("vk"..string.char(i))
	AddConsumeConst("vkNumpad"..string.char(i))
end
AddConsumeConst("vkBackspace")
AddConsumeConst("vkSpace")
AddConsumeConst("vkMinus")
AddConsumeConst("vkPlus")
AddConsumeConst("vkOpensq")
AddConsumeConst("vkClosesq") 
AddConsumeConst("vkSemicolon")
AddConsumeConst("vkTilde")
AddConsumeConst("vkQuote")
AddConsumeConst("vkComma")
AddConsumeConst("vkDot")
AddConsumeConst("vkSlash")
AddConsumeConst("vkBackslash")
AddConsumeConst("vkLeft")
AddConsumeConst("vkRight")
AddConsumeConst("vkDelete")
AddConsumeConst("vkHome")
AddConsumeConst("vkEnd")
AddConsumeConst("vkEnter")
AddConsumeConst("vkMultiply")
AddConsumeConst("vkAdd")
AddConsumeConst("vkSubtract")
AddConsumeConst("vkDivide")
AddConsumeConst("vkSeparator")
AddConsumeConst("vkDecimal")
AddConsumeConst("vkProcesskey") -- c++ will send us one such key down event on IME composition done

function HasControllerTextInput()
	return Platform.console or (Platform.steam and IsSteamInBigPictureMode()) or Platform.steamdeck
end

function XTextEditor:OpenControllerTextInput()
	-- if not HasControllerTextInput() then CreateMessageBox(nil, T("(design)Error opening Virtual Keyboard"), T("(design)A virtual keyboard is not set up for this platform.\nPlease use a mouse and keyboard and try again.")) end
	if not self:IsThreadRunning("keyboard") then
		self:CreateThread("keyboard", function()
			local current_text = self:GetTranslatedText()
			local text, err = WaitControllerTextInput(self:GetPassword() and "" or current_text, self.ConsoleKeyboardTitle, 
									self.ConsoleKeyboardDescription, Clamp(self:GetMaxLen(), 0, 256), self:GetPassword())
			if not err and self.window_state ~= "destroying" then
				text = text:trim_spaces()
				if text ~= current_text then
					self:OnControllerTextInput(text)
				end
			end
		end)
	end
end

function XTextEditor:OnControllerTextInput(text)
	self:SetText(self.UserText and CreateUserText(text, self.UserTextType) or (self.Translate and T(text)) or text)
end

if FirstLoad then
	ActiveVirtualKeyboard = {}
end

-- Accepts T{} notation texts for title and description, returns plaintext
function WaitControllerTextInput(default, title, description, max_length, password)
	if not HasControllerTextInput() then return default end -- trivial stub for PC
	assert(default == "" or not IsT(default), "Use a plaintext default value")
	assert(IsT(title) and IsT(description), "Description and title must be T")
	local err, shown, text =  AsyncOpWait(nil, ActiveVirtualKeyboard, "AsyncShowVirtualKeyboard", default, _InternalTranslate(title), _InternalTranslate(description), max_length, password or false)
	text = err and default or text or ""
	return text, err, shown
end


----- XTextEditorPlugin

DefineClass.XTextEditorPlugin = {
	__parents = { "InitDone" },
	
	OnTextChanged          = function(self, edit) end,
	OnBeginDraw            = function(self, edit) end,
	OnEndDraw              = function(self, edit) end,
	OnSetFocus             = function(self, edit, old_focus) end,
	OnKillFocus            = function(self, edit) end,
	OnDrawLineOutsideView  = function(self, edit, line_idx, text) end, -- use to parse/process text that is outside the view and is thus not drawn
	OnDrawText             = function(self, edit, line_idx, text, target_box, font, text_color) end,
	OnBeforeDrawText       = function(self, edit, line_idx, text, target_box, font, text_color) end,
	OnAfterDrawText        = function(self, edit, line_idx, text, target_box, font, text_color) end,
	OnWordSelection        = function(self, edit, word) end,
	OnSelectHighlight      = function(self, edit, highlighted_text, ignore_case) end,
	OnRightButtonDown      = function(self, edit, pt) end,
	OnShortcut             = function(self, edit, shortcut, source, ...) end,
	OnKbdKeyDown           = function(self, edit, virtual_key) end,
	VerticalSpaceAfterLine = function(self, edit, line) end,
	
	MultiLineOnly = false, -- functional only for XMultiLineEdit controls
	SingleInstance = true, -- a single instance of the plugin will be used (for all text editors)
}

function TextEditorPluginsCombo(multiline)
	local items = { "" }
	ClassDescendantsList("XTextEditorPlugin", function(name, class)
		if not (class.MultiLineOnly and not multiline) then
			items[#items + 1] = name
		end
	end)
	return items
end


----- XEdit, XNumberEdit & XMultiLineEdit (the actual edit controls)

DefineClass.XEdit = {
	__parents = { "XTextEditor" },
	
	properties = {
		{ category = "General", id = "Multiline", editor = false, default = false },
	
		{ category = "General", id = "WordWrap", editor = false },
		{ category = "General", id = "MinVisibleLines", editor = false },
		{ category = "General", id = "MaxVisibleLines", editor = false },
		{ category = "General", id = "MaxLines", editor = false },
		
		{ category = "Visual",  id = "HintVAlign", editor = false },
	},
	
	Multiline = false,
	WordWrap = false,
	MinVisibleLines = 1,
	MaxVisibleLines = 1,
	MaxLen = 1024,
	MaxLines = 1,
	HintVAlign = "center"
}

DefineClass.XNumberEdit = {
	__parents = { "XEdit" },
	
	properties = {
		{ category = "General", id = "Password", editor = false },
		{ category = "General", id = "Translate", editor = false , default = false },
		{ category = "General", id = "IsInRange", editor = "bool", default = false },
		{ category = "General", id = "MinValue", editor = "number", default = 0 },
		{ category = "General", id = "MaxValue", editor = "number", default = 100 },
	},
	Filter = "[/%*%+%(%)%%%-%.,0-9 ]",
}

function XNumberEdit:SetRange(min, max)
	self.MaxValue = tonumber(max)
	self.MinValue = tonumber(min)
end

function XNumberEdit:SetNumber(text)
	self:SetTranslatedText(text)
end 

function XNumberEdit:SetTranslatedText(text)
	XTextEditor.SetTranslatedText(self, tostring(text))
end
	
local expr_env = LuaValueEnv()
function XNumberEdit:GetNumber()
	local text = self:GetText()
	return tonumber(text) or tonumber(dostring("return " .. text, expr_env) or "")
end

function XNumberEdit:OnTextChanged()
	local number = self:GetNumber()
	if number and self.IsInRange and (number < self.MinValue or number > self.MaxValue) then
		number = Clamp(number, self.MinValue, self.MaxValue)
		self:SetTranslatedText(number)
	end
end

DefineClass.XMultiLineEdit = {
	__parents = { "XTextEditor" },
	
	properties = {
		{ category = "General", id = "Multiline", editor = false },
		{ category = "General", id = "Password", editor = false },
	},
	Multiline = true,
	AllowTabs = true,
	Password = false,
	vkPass = {
		const.vkEnd,
		const.vkHome,
		const.vkLeft,
		const.vkRight,
		const.vkInsert,
		const.vkDelete,
		const.vkBackspace,
		const.vkUp,
		const.vkDown,
		const.vkPageup,
		const.vkPagedown,
	},
}
