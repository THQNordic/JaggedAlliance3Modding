if Platform.cmdline then return end

MapVar("g_debug_pointers_list", false)

if FirstLoad then
	g_TrackerTexts = {}
	g_TrackerTextsThread = false
end

function OnMsg.PostDoneMap()
	g_TrackerTextsThread = false
end

function StartUpdateTrackerObjs()
	if IsValidThread(g_TrackerTextsThread) then
		Wakeup(g_TrackerTextsThread)
		return
	end
	g_TrackerTextsThread = CreateMapRealTimeThread(function()
		local clean_up_time = RealTime()
		local thread = CurrentThread()
		while g_TrackerTextsThread == thread do
			PauseInfiniteLoopDetection("UpdateTrackerObjs")
			local sleep = UpdateTrackerObjs(clean_up_time)
			ResumeInfiniteLoopDetection("UpdateTrackerObjs")
			WaitWakeup(sleep)
		end
	end)
end

OnMsg.NewMap = StartUpdateTrackerObjs
OnMsg.PersistPostLoad = StartUpdateTrackerObjs

local function GetDebugPointers()
	local ptrs = g_debug_pointers_list or {}
	g_debug_pointers_list = ptrs
	return ptrs
end

local function AddTrackerDbgText(t)
	table.insert(g_TrackerTexts, t)
	StartUpdateTrackerObjs()
end

DefineClass.PointerWhite = {
	__parents = { "Object" },
	entity = "ArrowUnits",
}

DefineClass.Pointer = {
	__parents = { "Object" },
	entity = "ArrowUnits",
	flags = { gofRealTimeAnim = true },
}

function Pointer:Init()
	NetTempObject(self)
	self:SetAxis(axis_y)
	self:SetAngle(180)
	self.thread = CreateMapRealTimeThread(function(self)
		local move, delta, sleep = 2500, 120, 15
		local x, y, z = self:GetVisualPosXYZ()
		while true do
			for i = 0, move, delta do
				self:SetPos(x, y, z + i, sleep)
				Sleep(sleep)
			end
			for i = move, 0, -delta do
				self:SetPos(x, y, z + i, sleep)
				Sleep(sleep)
			end
		end
	end, self)
	local dbg_ptrs = GetDebugPointers()
	dbg_ptrs[#dbg_ptrs + 1] = self
end

function Pointer:Done()
	DeleteThread(self.thread)
	GetDebugPointers():Remove(self)
end

DefineClass.RealTimePoint = {
	__parents = {"Mesh", "InitDone"},
	time_used = -60000,
	depth_test = false,
	vector = false,
}

function RealTimePoint:Init()
	NetTempObject(self)
	local dbg_ptrs = GetDebugPointers()
	dbg_ptrs[#dbg_ptrs + 1] = self
	self:SetShader(ProceduralMeshShaders.mesh_linelist)
	self:SetDepthTest(false)
	self:SetMesh(CreateSphereVertices(guim / 2))
end

function RealTimePoint:Done()
	table.remove_value(GetDebugPointers(), self)
	if IsValid(self.vector) then
		self.vector:delete()
	end
end

function RealTimePoint:SetUp(pt, ptOrigin, color)
	if not pt:IsValidZ() then
		pt = pt:SetTerrainZ(10)
		color = RGB(0, 255, 0)
	end
	self:SetMesh(CreateSphereVertices(guim / 2, RGB(255, 255, 255)))
	Mesh.SetPos(self, pt)
	self.vector = self.vector or Vector:new()
	self.vector:Set(ptOrigin, pt, RGB(0, 255, 0))
end


function RealTimePoint:SetPos(pt, ...)
	local color
	if not pt:IsValidZ() then
		pt = pt:SetTerrainZ(10)
		color = RGB(0, 255, 0)
	else
		color = RGB(255, 255, 255) 
	end
	Mesh.SetPos(self, pt, ...)
	self:SetMesh(CreateSphereVertices(guim / 2, color))
	
	if self.vector then
		self.vector:Set(self.vector:GetA(), pt, RGB(0, 255, 0))
	end
end

function RealTimePoint:DetachFromMap()
	Mesh.DetachFromMap(self)
	if IsValid(self.vector) then
		self.vector:delete()
		self.vector = false
	end
end


DefineClass.RealTimeText = {
	__parents = {"Text", "InitDone"},
	time_used = -60000,
}

function RealTimeText:Init()
	NetTempObject(self)
	local dbg_ptrs = GetDebugPointers()
	dbg_ptrs[#dbg_ptrs + 1] = self
	self:SetTextStyle("EditorTextBold")
end

function RealTimeText:Done()
	table.remove_entry(GetDebugPointers(), self)
end

function AddTrackerText(root, expression)
	if not IsValid(root) then
		local arrow = string.find(expression, "->")
		if arrow then
			local f
			root = string.sub(expression, 1, arrow-1)
			local class_name = string.trim_spaces(root)
			if g_Classes[class_name] then
				root = function () return MapGet("map", class_name) or empty_table end
			else
				local r, err = load("return " .. root)
				if err then
					printf("Error while evaluating %s\n%s", string.trim(root, 24, "..."), err)
					return
				end
				root = r
			end
			local e = string.sub(expression, arrow+2)
			if string.find(e, "return") then
				local r, err = load("return function(o) " .. e .. " end" )
				if err then
					printf("Error while evaluating %s\n%s", string.trim(e, 24, "..."), err)
					return
				end
				f = r()
			else
				local r, err = load("return function(o) return " .. e .. " end" )
				if err then
					printf("Error while evaluating %s\n%s", string.trim(e, 24, "..."), err)
					return
				end
				f = r()
			end
			AddTrackerDbgText { id = expression, root = root, to_eval = f }
		else
			local init = 1
			while true do
				local i = string.find(expression, "[:.]", init)
				if i then
					init = i + 1
					root = string.sub(expression, 1, i-1)
				else
					printf("Not a valid expression to track")
					return
				end
				
				local class_name = string.trim_spaces(root)
				if g_Classes[class_name] then
					root = function () return MapGet("map", class_name) or empty_table end
					break
				else
					local r, err = load("return " .. root)
					if not err then
						root = r
						break
					end
				end
			end
			if not root then
				printf("Can't deduce the root object from %s\n", string.trim(expression, 24, "..."))
				return
			end
			local object_expression = string.sub(expression, init-1)
			local r, err = load("return function(o) return o" .. object_expression .. " end")
			if not err then
				AddTrackerDbgText{ id = expression, root = root, to_eval = r() }
				return
			end
		end
	else
		local r, err = load("return function(o) return "     .. expression .. " end")
		if r then
			AddTrackerDbgText{ id = expression, root = root, to_eval = r() }
			return
		else
			printf("Error while evaluating %s\n%s", string.trim(expression, 24, "..."), err)
			return
		end
	end
end

function ShowPoint(o, pt, label, time)
	AddTrackerDbgText{
		id = pt,
		root = o,
		to_eval = function()
			return pt, label
		end,
		expire_time = GameTime() + (time or 2000),
	}
end

function UpdateTrackerObjs(clean_up_time)
	local texts = g_TrackerTexts
	local now = RealTime()
	local objs_text = {}

	local live_pts = MapFilter(GetDebugPointers(), "map", "RealTimePoint")
	local pointers_alive = false
	for i = #texts, 1, -1  do
		local t = texts[i]
		if t.expire_time and t.expire_time - GameTime() < 0 then
			table.remove(texts, i)
		end
		
		local ok, root
		if type(t.root) ~= "function" then
			root = t.root
		else
			ok, root = pcall(t.root)
		end
		if IsValid(root) or type(root) == "table" and IsValid(root[1]) then
			if IsValid(root) then
				root = {root}
			end
			for j = 1, #root do
				local r = root[j]
				local labels = {}
				local ok, v, text = pcall(t.to_eval, r) 
				if ok then
					if type(v) == "table" or IsPoint(v) or IsValid(v) then
						local function UnpackExaminedObj(v, resolve_tables)
							if IsPoint(v) then
								return v:IsValid() and {v} or {}
							elseif IsValid(v) then
								if v:IsValidPos() then
									return {v:GetVisualPos()}, RGBA(96, 96, 255, 64)
								else
									return {}
								end
							elseif type(v) == "table" and IsValid(v[1]) then
								local pts = {}
								for _, o in ipairs(v) do
									if o:IsValidPos() then
										pts[#pts+1] = o:GetVisualPos()
									end
								end
								return pts, RGBA(96, 96, 255, 64)
							elseif resolve_tables and type(v) == "table" then
								local pts = {}
								if #v > 0 then
									for i = 1, #v do
										local o = v[i]
										local elements = UnpackExaminedObj(o)
										for j = 1, #elements do
											table.insert(pts, elements[j])
										end
									end
								else
									for o, t in pairs(v) do
										local elements = UnpackExaminedObj(o)
										for j = 1, #elements do
											table.insert(pts, elements[j])
											labels[elements[j]] = tostring(t)
										end
									end
								end
								return pts, RGBA(255, 96, 96, 64)
							end
							return {}
						end
						local pts, color = UnpackExaminedObj(v, true)
						
						pointers_alive = true
						text = text and tostring(text)
						
						for i = 1, #pts do
							local pointer
							if #live_pts > 0 then
								pointer = table.remove(live_pts)
							else
								pointer = RealTimePoint:new()
							end
							pointer:SetUp(pts[i], r:GetVisualPos(), color)
							pointer.time_used = now
							local text = text or labels[pts[i]]
							if text then
								objs_text[pointer] = objs_text[pointer] or {}
								table.insert(objs_text[pointer], string.trim(tostring(text), 30, "..."))
							end
						end
					else
						objs_text[r] = objs_text[r] or {}
						table.insert(objs_text[r], string.trim(tostring(v), 30, "..."))
					end
				end
			end
		end
	end

	local live_texts = MapFilter(GetDebugPointers(), "map", "RealTimeText")
	for o, t in pairs(objs_text) do
		if IsValid(o) and o:IsValidPos() then
			local text
			if #live_texts > 0 then
				text = table.remove(live_texts)
			else
					text = RealTimeText:new()
				end
				text:SetText(table.concat(t, "\n"))
				text:SetPos(o:GetVisualPos())
				text.time_used = now
			end
		end

	if now - clean_up_time > 30000 then
		for i = #live_texts, 1, -1 do
			if now - live_texts[i].time_used > 30000 then
				DoneObject(live_texts[i])
				table.remove(live_texts, i)
			end
		end
		for i = #live_pts, 1, -1 do
			if now - live_pts[i].time_used > 30000 then
				DoneObject(live_pts[i])
				table.remove(live_pts, i)
			end
		end
	end
	if #texts > 0 or pointers_alive then
		for i = 1, #live_texts do
			live_texts[i]:DetachFromMap()
		end
		for i = 1, #live_pts do
			live_pts[i]:DetachFromMap()
		end
		return 50        --  live and positioned texts/pts - fast update
	end
	DoneObjects(live_texts)
	DoneObjects(live_pts)
end

function ClearTextTrackers(expression)
	if expression then
		table.remove_value(g_TrackerTexts, "id", expression)
	else
		g_TrackerTexts = {}
	end
end

function HasTextTrackers(expression)
	return table.find(g_TrackerTexts, "id", expression) and true or false
end

function ToggleTextTrackers(expression, description)
	if HasTextTrackers(expression) then
		ClearTextTrackers(expression)
		if (description or "") ~= "" then
			printf("Show %s: OFF", description)
		end
	else
		AddTrackerText(false, expression)
		if (description or "") ~= "" then
			printf("Show %s: ON", description)
		end
	end
end
