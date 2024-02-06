_G.controller_host = "localhost"
_G.controller_port = 8171

if not rawget(_G, "outputSocket") then
	outputSocket = LuaSocket:new()
	outputThread = false
	outputBuffer = false
end

function dbgOutputClear(stop_update)
	outputSocket:send(TableToLuaCode{target="graphicsOutput", type = "new_screen", stop_update = stop_update})
end

function dbgResumeUpdate(stop_update)
	outputSocket:send(TableToLuaCode{target="graphicsOutput", type = "resume_update"})
end

function dbgDrawCircle(pt, radius, color, filter)
	outputSocket:send(TableToLuaCode{target="graphicsOutput", type = "circle", filter = filter, x = pt:x(), y = pt:y(), r = radius or 0, c = color or RGB(255, 255, 255)})
end

function dbgDrawSquare(pt, radius, color, filter)
	outputSocket:send(TableToLuaCode{target="graphicsOutput", type = "rect", filter = filter, x1 = pt:x()-radius/2, x2 = pt:x()+radius/2, y1 = pt:y()-radius/2, y2 = pt:y()+radius/2, c = color or RGB(255, 255, 255)})
end

function dbgDrawRect(pt, pt2, color, filter)
	outputSocket:send(TableToLuaCode{target="graphicsOutput", type = "rect", filter = filter, x = pt:x(), y = pt:y(), x1 = pt2:x(), y1 = pt2:y(), c = color or RGB(255, 255, 255)})
end

function dbgDrawArrow(pt1, pt2, color, filter)
	outputSocket:send(TableToLuaCode{target="graphicsOutput", type = "arrow", filter = filter, x1 = pt1:x(), y1 = pt1:y(), x2 = pt2:x(), y2 = pt2:y(), c = color or RGB(255, 255, 255)})
end

function dbgInfo(pt, color, filter, text, ...)
	outputSocket:send(TableToLuaCode{target="graphicsOutput", type = "infopt", filter = filter, x = pt:x(), y = pt:y(), text = string.format(text, ...), c = color or RGB(255, 255, 255)})
end

function dbgWeight(pt, weight, filter, name)
	outputSocket:send(TableToLuaCode{ target="graphicsOutput", type = "weight", filter = filter, name = name or "", x = pt:x(), y = pt:y(), w = weight })
end

function OnMsg.Start()
	local connected
	local retry = true
	local dir, filename, ext = SplitPath(GetExecName())
	local project_name = filename or "unknown"
	outputThread = CreateRealTimeThread(function()
		while true do
			controller_host = not Platform.pc and config.Haerald and config.Haerald.ip or "localhost"
			if outputSocket:isdisconnected() then -- no connection initialized
				outputSocket:connect(controller_host, controller_port+1)
				outputSocket:send(TableToLuaCode{target="output", text="Connected to " .. project_name .. "\n"})
				for i = 1, 20 do
					if outputSocket:isconnecting() then
						outputSocket:update()
					end
					if outputSocket:isconnected() then
						connected = true
						break
					end
					Sleep(50)
				end
			end
			if connected and not outputSocket:isconnected() then
				connected = false
				print("[Debugger] Connection lost, restart it with F11 (or all triggers on the gamepad)")
			end
			while not outputSocket:isdisconnected() do
				outputSocket:update()
				if outputBuffer then
					local text = table.concat(outputBuffer)
					if #text > 0 and not text:find_lower("[Debugger]") then
						outputSocket:send(TableToLuaCode{target="output", text = text})
						if rawget(_G, "g_LuaDebugger") then
							g_LuaDebugger:WriteOutput(text)
						end
					end
					outputBuffer = false
				end
				WaitWakeup(100)
			end
			outputSocket:close()
			Sleep(1000)
			-- do not retry on xbox, will not work
			if Platform.console and not Platform.switch then 
				break
			end
		end
	end)
end

function OnMsg.ConsoleLine(text, bNewLine)
	if #text == 0 or not outputSocket or not outputThread then
		return
	end
	outputBuffer = outputBuffer or {}
	if bNewLine then
		outputBuffer[#outputBuffer + 1] = " \n"
	end
	outputBuffer[#outputBuffer + 1] = text
	Wakeup(outputThread)
end

function OnMsg.DebuggerBreak()
	if not outputSocket then
		return
	end
	if not outputSocket:isconnected() then
		outputSocket:connect(controller_host, controller_port+1)
	end
	Wakeup(outputThread)
	outputSocket:flush()
end
