if FirstLoad then
	s_ShowGossipMatch = false
	dbg_color = false
	dbg_objects = false
end

function DbgClearColors()
	for obj in pairs(dbg_color or empty_table) do
		if IsValid(obj) then
			ClearColorModifierReason(obj, "DbgColor")
		end
	end
	dbg_color = false
end

function DbgSetColor(obj, color, skip_attaches)
	if not IsValid(obj) then return end
	if not color then
		if dbg_color then dbg_color[obj] = nil end
		ClearColorModifierReason(obj, "DbgColor", nil, skip_attaches)
	else
		dbg_color = table.create_set(dbg_color, obj, true)
		SetColorModifierReason(obj, "DbgColor", color, 1000, nil, skip_attaches)
	end
end

function DbgClearObjs()
	DoneObjects(dbg_objects)
	dbg_objects = false
end

function DbgAddObj(obj)
	dbg_objects = table.create_add_unique(dbg_objects, obj)
end

function OnMsg.SaveGameStart()
	-- avoid saving temp changes
	DbgClearColors()
	DbgClearObjs()
end

if FirstLoad then
	DbgClearLast = false
end

function DbgClear(once)
	if once then
		local time = RealTime()
		if DbgClearLast == time then
			return
		end
		DbgClearLast = time
	end
	DbgClearVectors()
	DbgClearTexts()
	DbgClearColors()
	DbgClearObjs()
	Msg("DbgClear")
end
OnMsg.ChangeMap = DbgClear

function ShowGossip(gossip_match)
	s_ShowGossipMatch = gossip_match or false
	
	NetGossip = function(...)
		local params = table.pack(...)
		for idx, param in ipairs(params) do
			if type(param) == "string" and not utf8.IsValidString(param) then
				params[idx] = UnicodeEscapeCharactersToUtf8(param)
			end
		end
		if not s_ShowGossipMatch or string.match(s_ShowGossipMatch, params[1]) then
			print(table.unpack(params)) 
		end
	end
	
	netAllowGossip = true
end

function TracePos(o, color)
	local origSetPos = o.SetPos
	g_PosTraced[o] = color or RGB(255, 255, 255)
	o.SetPos = function(self, pos, ...)
		origSetPos(self, pos, ...)
		dbgDrawPosHistory(pos)
	end
end

function DrawRadiuses(o)
	CreateGameTimeThread(function()
		while IsValid(o) do
			MapForEach( o:GetPos(), 50 * guim, nil, const.efDestlock,
				function(obj)
					if not rawget(obj, "__radius_circle") then
						local circle = CreateCircleMesh(pf.GetDestlockRadius(obj), RGB(0, 255, 255))
						obj:SetEnumFlags(const.efVisible)
						obj:Attach(circle)
						rawset(obj, "__radius_circle", circle)
					end
				end )
			MapForEach(o:GetPos(), 50 * guim, "Unit",
				function(obj)
					if obj:GetEnumFlags(const.efResting) ~= 0 then
						if not rawget(obj, "__radius_circle") then
							local circle = CreateCircleMesh(pf.GetDestlockRadius(obj), RGB(0, 255, 0))
							obj:Attach(circle)
							rawset(obj, "__radius_circle", circle)
						end
					else
						if rawget(obj, "__radius_circle") then
							DoneObject(obj.__radius_circle)
							obj.__radius_circle = nil
						end
					end
				end)
			
			Sleep(100)
		end
	end)
end

g_PosTraced = rawget(_G, "g_PosTraced") or {}
function TraceCollisionOverstep(o, method)
	method = method or "GetCollisionRadius"
	local origSetPos = o.SetPos
	o.SetPos = function(self, pos, ...)
		local bad = {}
		MapForEach( pos, 5*guim, "Unit", 
				function(o)
					if o ~= self and not o:IsDead() and o:GetVisualDist2D(self) < self[method](self) + o[method](self) - 10 * guic then
						table.insert(bad, o)
					end
				end)
		if #bad > 0 then
			self:Trace("Overlaping", bad, GetStack(1))
			self:SetColorModifier(RGB(255, 0, 0))
			CreateGameTimeThread(function()
				Sleep(1000)
				if IsValid(self) then
					self:SetColorModifier(RGB(128, 128, 128))
				end
			end)
		end
		origSetPos(self, pos, ...)
	end
end

function dbgDrawPosHistory(pos)
	dbgOutputClear()
	for o, color in pairs(g_PosTraced) do
		local r, g, b = GetRGB(color)
		dbgDrawCircle(o:GetPos(), o:GetCollisionRadius(), RGB(r/2, g/2, b/2))
		dbgDrawArrow(o:GetVisualPos(), o:GetPos(), color)
		dbgInfo(o:GetPos(), RGB(255, 255, 255), false, o.class .. " " .. o:GetStateText())
	end
end

CameraDebugSegments = {}
CameraDebugPoints = {}

function dbgDrawCameraCollision()
	for i = 1, #CameraDebugPoints do
		DbgAddVector(CameraDebugSegments[i*2], CameraDebugSegments[i*2+1]-CameraDebugSegments[i*2], RGB(0, 255, 0))
		DbgAddVector(CameraDebugSegments[i*2], CameraDebugPoints[i]-CameraDebugSegments[i*2], RGB(0, 255, 0))
	end
end

function ShowRect(box, color, angle)
	CreateRealTimeThread(function()
		local rc = Polyline:new()
		local points = pstr("")
		points:AppendVertex(point(box:minx(), box:maxy(), 20 * guic), color)
		points:AppendVertex(point(box:maxx(), box:maxy(), 20 * guic))
		points:AppendVertex(point(box:maxx(), box:miny(), 20 * guic))
		points:AppendVertex(point(box:minx(), box:miny(), 20 * guic))
		points:AppendVertex(point(box:minx(), box:maxy(), 20 * guic))
		rc:SetMeshFlags(const.mfTerrainDistorted)
		rc:SetMesh(points)
		rc:SetPos(box:Center():SetTerrainZ())
		if angle then
			rc:SetAngle(angle)
		end
		
		Sleep(1000)
		rc:delete()
	end)
end


function ShowObj(obj)
	CreateRealTimeThread(function()
		local cm = obj:GetColorModifier()
		obj:SetColorModifier(blue)
		Sleep(1000)
		obj:SetColorModifier(cm)
	end)
end

if FirstLoad then
	showme_markers = {}
end

function ShowMe(o, color, time)
	if o == nil then
		return ClearShowMe()
	end
	if type(o) == "table" and #o == 2 then
		if IsPoint(o[1]) and terrain.IsPointInBounds(o[1]) and 
			IsPoint(o[2]) and terrain.IsPointInBounds(o[2]) then
			local m = Vector:new()
			m:Set(o[1], o[2], color)
			showme_markers[m] = "vector"
			o = m
		end
	elseif IsPoint(o) then
		if terrain.IsPointInBounds(o) then
			local m = CreateSphereMesh(50 * guic, color or RGB(0, 255, 0))
			m:SetPos(o)
			showme_markers[m] = "point"
			if not time then
				ViewPos(o)
			end
			o = m
		end
	elseif IsValid(o) then
		showme_markers[o] = showme_markers[o] or o:GetColorModifier()
		o:SetColorModifier(color or RGB(0, 255, 0))
		local pos = o:GetVisualPos()
		if not time and terrain.IsPointInBounds(pos) then
			ViewPos(pos)
		end
	else
		if not showme_markers[o] then
			AddTrackerText(false, o)
		end
	end
	if time then
		CreateGameTimeThread(function(o, time)
			Sleep(time)
			local v = showme_markers[o]
			if IsValid(o) then
				if v == "point" or v == "vector" then
					DoneObject(o)
				else
					o:SetColorModifier(v)
				end
			end
			if ClearTextTrackers then
				ClearTextTrackers(o)
			end
		end, o, time)
	end
end

function ClearShowMe()
	for k, v in pairs(showme_markers) do
		if IsValid(k) then
			if v == "point" then
				DoneObject(k)
			else
				k:SetColorModifier(v)
			end
		end
	end
	if ClearTextTrackers then
		ClearTextTrackers()
	end
	showme_markers = {}
end

function ShowCircle(pt, r, color)
	local c = CreateCircleMesh(r, color or RGB(255, 255, 255))
	c:SetPos(pt:SetTerrainZ(10*guic))
	CreateGameTimeThread(function()
		Sleep(7000)
		if IsValid(c) then
			c:delete()
		end
	end)
end

function DbgShowClassHierarchy(class, filter, unique_only)
	local html = "<!DOCTYPE html><html><head><meta http-equiv='refresh' content = '0; url = %s' /></head></html>"
	local url = "http://magjac.com/graphviz-visual-editor/?dot="
	local dot = {'strict digraph { rankdir=TB'}
	local node_style = '[shape="polygon" style="filled" fillcolor="#1f77b4" fontcolor="#ffffff"]'
	local edge_style = '[fillcolor="#a6cee3" color="#1f78b4"]'
	local ignored_node_style = '[shape="polygon" style="filled" fillcolor="#7d91a0" fontcolor="#ffffff"]'
	if type(filter) == "string" then
		local member = filter
		filter = function(cls) return rawget(cls, member) ~= nil end
	end
	local queue, seen, inherited = {class}, {}, {}
	while next(queue) do
		local curr = table.remove(queue, #queue)
		if not seen[curr] then
			local curr_cls = g_Classes[curr]
			local ignored = filter and not filter(curr_cls)
			local curr_style = ignored and ignored_node_style or node_style
			table.insert(dot, string.format('"%s" %s', curr, curr_style))
			local parents = curr_cls.__parents
			for i, parent in ipairs(parents) do
				if not unique_only or not inherited[parent] then
					inherited[parent] = true
					table.insert(dot, string.format('"%s" -> "%s" %s', curr, parent, edge_style))
					table.insert(queue, parent)
				end
			end
		end
	end
	table.insert(dot, "}")
	url = url .. EncodeURL(table.concat(dot, "\n"))
	html = string.format(html, url)
	local path = ConvertToOSPath("TmpData/ClassGraph.html")
	AsyncStringToFile(path, html)
	OpenUrl(path)
end
