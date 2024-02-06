DefineClass.ConsoleLog = {
	__parents = { "XWindow" },
	IdNode = true,
	Dock = "box",
	ZOrder = 2000000,
	background_thread = false,
}

function ConsoleLog:Init()
	local text = XText:new({
		Id = "idText",
		Dock = "bottom",
		Translate = false,
		TextVAlign = "bottom",
	}, self)
	text:SetTextStyle("ConsoleLog")
	self:UpdateMargins()
end

function ConsoleLog:UpdateMargins()
	self.idText.Margins = box(10, 0, 10, 40 + VirtualKeyboardHeight())
end

function ConsoleLog:SetText(text)
	self.idText:SetText(text)
end

function ConsoleLog:ClearText()
	self.idText:SetText("") 
end

function ConsoleLog:AddLogText(text, bNewLine)
	local old_text = self.idText:GetText()
	local new_text
	if text and old_text ~= "" then
		new_text = old_text
	else
		new_text = ""
	end
	
	if bNewLine then
		new_text = new_text .. "\n<reset>" .. text
	else
		new_text = new_text .. text
	end
	
	if self.content_box:sizey() > 0 then
		local new_lines = {}
		local i = 1
		while true do
			local start_idx, end_idx = string.find (new_text, "\n", i , true)
			if not start_idx then
				break
			end
			i = end_idx+1
			table.insert(new_lines, i)
		end
		
		local self_height = self.content_box:sizey() - self.idText.Margins:maxy()
		local maxlines = (self_height / self.idText:GetFontHeight()) - 1
		if #new_lines > maxlines then
			new_text = string.sub(new_text, new_lines[#new_lines-maxlines])
		end
	end
	
	self:SetText(new_text)
end

function ConsoleLog:MouseInWindow(pt)
	return false
end

function ConsoleLog:ShowBackground(visible, immediate)
	if config.ConsoleDim ~= 0 then
		DeleteThread(self.background_thread)
		if visible or immediate then
			self:SetBackground(RGBA(0, 0, 0, visible and 96 or 0))
		else
			self.background_thread = CreateRealTimeThread(function()
				Sleep(3000)
				local r, g, b, a = GetRGBA(self:GetBackground())
				while a > 0 do
					a = Max(0, a - 5)
					self:SetBackground(RGBA(0, 0, 0, a))
					Sleep(20)
				end
			end)
		end
	end
end

-- Global functions
dlgConsoleLog = rawget(_G, "dlgConsoleLog") or false
function ShowConsoleLog(visible)
	if visible and not dlgConsoleLog then
		dlgConsoleLog = ConsoleLog:new({}, GetDevUIViewport())
	end
	if dlgConsoleLog then
		dlgConsoleLog:SetVisible(visible)
	end
end

function DestroyConsoleLog()
	if dlgConsoleLog then
		dlgConsoleLog:delete()
		dlgConsoleLog = false
	end
end

function ShowConsoleLogBackground(visible, immediate)
	if dlgConsoleLog then
		dlgConsoleLog:ShowBackground(visible, immediate)
	end
end

function ConsoleLogResize()
	if dlgConsoleLog then
		dlgConsoleLog:UpdateMargins()
	end
end

function AddConsoleLog(text, bNewLine)
	if Loading then
		CreateRealTimeThread(function(text, bNewLine)
			AddConsoleLog(text, bNewLine)
		end, text, bNewLine)
		return
	end
	Msg("ConsoleLine", text, bNewLine)
	if dlgConsoleLog then
		dlgConsoleLog:AddLogText(text, bNewLine)
	end
end

--- Clears the console text log.
-- @cstyle void cls().
-- @return none.

function cls() -- Clear console log
	if dlgConsoleLog then 
		dlgConsoleLog:ClearText()
	end	
end