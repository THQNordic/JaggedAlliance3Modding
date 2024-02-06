if Platform.cmdline then return end

if FirstLoad then
	path_waypoints = false
	debug_pass_vectors = false
end
function OnMsg.DoneMap()
	path_waypoints = false
	debug_pass_vectors = false
end

function DrawWayPointReset()
	if path_waypoints and #path_waypoints > 0 then
		for i = 1, #path_waypoints do
			DoneObject(path_waypoints[i])
		end
	end
	path_waypoints = {}
end

function DrawWayPointPath(pt_or_obj, pt_end, anim_time)
	DrawWayPointReset()
	if not pt_or_obj then
		pf.DbgDrawFindPath()
		return
	end
	local function DiagDistEx(p1, p2)
		local x1, y1 = p1:xy()
		local x2, y2 = p2:xy()
		local x = abs(x1 - x2)
		local y = abs(y1 - y2)
		if x > y then
			return y * 1448 / 1024 + x - y
		else
			return x * 1448 / 1024 + y - x
		end
	end

	local v = pf.DbgDrawFindPath(pt_or_obj, pt_end or GetTerrainCursor():SetInvalidZ(), anim_time or 5000)
	if not v then return "no path" end
	local len = #v
	local path_len = 0
	for i = 1, len do
		local o = PlaceObject("WayPoint")
		path_waypoints[i] = o
		local pos = v[len+1-i]
		o:SetPos(pos)
		o:SetAngle(i) -- !WayPoint:GetAngle() shows index
		--if i > 1 then path_len = path_len + o:GetDist2D(path_waypoints[i-1]) end
		--local heuristics = path_len * 4 + DiagDistEx(pos, pt_end) * 8
		--o:SetAngle(heuristics / 1000)
	end
end

-- Usage
--!SelectedObj -> DrawPath(o)
--!WayPoint:GetAngle()
function DrawPath(obj)
	local path = IsValid(obj) and obj:GetComponentFlags(const.cofComponentPath) ~= 0 and obj:GetPath() or empty_table
	path_waypoints = path_waypoints or {}
	local index = 1
	for i = 1, #path do
		local pos = path[i]
		if pos:IsValid() then
			local o = path_waypoints[index]
			if not IsValid(o) then
				o = PlaceObject("WayPoint")
				NetTempObject(o)
				path_waypoints[index] = o
				o:SetScale(40)
			end
			o:SetPos(pos)
			o:SetAngle(index) -- !WayPoint:GetAngle() shows index
			index = index + 1
		end
	end
	for i = #path_waypoints, index, -1 do
		DoneObject(path_waypoints[i])
		path_waypoints[i] = nil
	end
	return ""
end

function DbgDrawPath(path, color, offset)
	if IsValid(path) then
		local pt1 = path:GetPos()
		local pt0 = path:GetVisualPos()
		if not pt1:z() then pt0 = pt0:SetInvalidZ() end
		local pts = {pt0}
		if pt1 ~= pt0 then
			pts[#pts + 1] = pt1
		end
		for i=path:GetPathPointCount(),1,-1 do
			local pt = path:GetPathPoint(i)
			if IsValidPos(pt) and pts[#pts] ~= pt then
				pts[#pts + 1] = pt
			end
		end
		path = pts
	end
	if #(path or "") < 2 then
		return
	end
	offset = offset or 5*guic
	color = color or white
	local pos0 = ValidateZ(path[1], offset)
	for i = 2, #path do
		local pos1 = ValidateZ(path[i], offset)
		DbgAddSegment(pos1, pos0, color)
		pos0 = pos1
	end
end

function DbgSetTerrainBoxHeight(h, clip)
	clip = clip or box(0, 0, terrain.GetMapSize())
	local htile = const.HeightTileSize
	local minx = clip:minx() / htile * htile
	local maxx = clip:maxx() / htile * htile
	local miny = clip:miny() / htile * htile
	local maxy = clip:maxy() / htile * htile
	local f = terrain.SetHeight
	for y = miny, maxy, htile do
		for x = minx, maxx, htile do
			f(x, y, h)
		end
	end
end

function DbgSnapTerrainToSlab(clip)
	clip = clip or box(0, 0, terrain.GetMapSize())
	local htile = const.HeightTileSize
	local minx = clip:minx() / htile * htile
	local maxx = clip:maxx() / htile * htile
	local miny = clip:miny() / htile * htile
	local maxy = clip:maxy() / htile * htile
	local GetHeight = terrain.GetHeight
	local SetHeight = terrain.SetHeight
	local snapz = (const.SlabSizeZ or guim) / 2
	local offsetz = -1
	for y = miny, maxy, htile do
		for x = minx, maxx, htile do
			SetHeight(x, y, (GetHeight(x, y) + snapz/2) / snapz * snapz + offsetz)
		end
	end
end

function DbgRamp(pos, ptSize, angle2D, anglez)
	local htile = const.HeightTileSize
	local ztile = const.SlabSizeZ or guim
	local x, y, z = pos:xyz()
	x = (x + htile/2) / htile * htile
	y = (y + htile/2) / htile * htile
	z = (z + ztile/2) / ztile * ztile

	local dx1, dy1 = Rotate(point(ptSize:x(), 0), angle2D * 60):xy()
	dx1 = (dx1 + htile/2) / htile * htile
	dy1 = (dy1 + htile/2) / htile * htile

	local dx2, dy2 = Rotate(point(0, ptSize:y()), angle2D * 60):xy()
	dx2 = (dx2 + htile/2) / htile * htile
	dy2 = (dy2 + htile/2) / htile * htile

	local sz, cz = sincos(anglez*60)
	local dz = ptSize:y() * sz / cz
	dz = (dz + ztile/2) / ztile * ztile

	local poly = {
		point(x, y, z),
		point(x + dx1, y + dy1, z),
		point(x + dx1 + dx2, y + dy1 + dy2, z + dz),
		point(x + dx2, y + dy2, z + dz),
	}
	local spans = DbgGetPolySpans(poly)
	DbgSetTerraceHeightSpans(spans)
end

function DbgGetPolySpans(poly)
	if type(poly) ~= "table" or #poly == 0 then
		return
	end
	local xtile = const.HeightTileSize
	local ztile = const.SlabSizeZ or guim
	local offsz = -5*guic
	local spans = {}
	local miny, maxy
	local p1, p2
	local function f(p)
		local x, y = p:xy()
		local x1, y1, z1 = p1:xyz()
		local x2, y2, z2 = p2:xyz()
		local dz = 0
		if abs(x2 - x1) < abs(y2 - y1) then
			dz = ((z2 - z1) * (y - y1) + (y2 - y1) / 2) / (y2 - y1)
		elseif x2 ~= x1 then
			dz = ((z2 - z1) * (x - x1) + (x2 - x1) / 2) / (x2 - x1)
		end
		local pt = point(x * xtile, y * xtile, z1 + dz)
		local span = spans[y * xtile]
		if span then
			if pt:x() < span[1]:x() then
				span[1] = pt
			elseif pt:x() > span[2]:x() then
				span[2] = pt
			end
		else
			span = { pt, pt }
			spans[y * xtile] = span
		end
		if not miny or miny > y then miny = y end
		if not maxy or maxy < y then maxy = y end
	end

	for i = 1, #poly do
		local x1, y1, z1 = poly[i]:xyz()
		local x2, y2, z2 = poly[i == #poly and 1 or i + 1]:xyz()
		p1 = point((x1 + xtile/2) / xtile, (y1 + xtile/2) / xtile, z1)
		p2 = point((x2 + xtile/2) / xtile, (y2 + xtile/2) / xtile, z2)
		f(p1)
		if p1:x() ~= p2:x() or p1:y() ~= p2:y() then
			RasterizeLine(p1, p2, f)
		end
	end
	return spans
end

function DbgSetTerraceHeightSpans(spans)
	local SetHeight = terrain.SetHeight
	for y, span in pairs(spans) do
		for i = 1, #span, 2 do
			local x1, y1, z1 = span[i]:xyz()
			local x2, y2, z2 = span[i+1]:xyz()
			if x1 == x2 then
				SetHeight(x1, y, z1)
			else
				for x = x1, x2 do
					local z = z1 + ((z2 - z1) * (x - x1) + (x2 - x1) / 2) / (x2 - x1)
					SetHeight(x, y, z)
				end
			end
		end
	end
end

function DbgSetAnimPhase(unit, phase, anim)
	if anim and unit:GetStateText() ~= anim then
		unit:SetStateText(anim)
	end
	local v0 = unit:GetStepVector(anim, unit:GetAngle(), 0, unit:GetAnimPhase(1))
	local v1 = unit:GetStepVector(anim, unit:GetAngle(), 0, phase)
	unit:SetPos(unit:GetPos() + (v1 - v0))
	unit:SetAnimPhase(1, phase)
	unit:SetAnimSpeed(1, 0)
end

function ToggleDrawTunnels()
	DbgDrawTunnels(not debug_pass_vectors)
end

function DbgDrawTunnels(show)
	local count = 0
	if show ~= false then
		debug_pass_vectors = debug_pass_vectors or {}
		local zoffset = (const.SlabSizeZ or guim) / 2
		local invalid_z = const.InvalidZ
		local function f(obj, x1, y1, z1, x2, y2, z2, weight, tunnel_type, flags, param)
			if z1 == invalid_z then
				z1 = terrain.GetHeight(x1, y1)
			end
			if z2 == invalid_z then
				z2 = terrain.GetHeight(x2, y2)
			end
			count = count + 1
			local vector = debug_pass_vectors[count]
			if not IsValid(vector) then
				vector = Vector:new()
				debug_pass_vectors[count] = vector
				vector:SetDepthTest(true)
			end
			local v1 = point(x1, y1, z1 + zoffset + obj.dbg_tunnel_zoffset)
			local v2 = point(x2, y2, z2 + zoffset + obj.dbg_tunnel_zoffset)
			vector:Set(v1, v2, obj.dbg_tunnel_color)
		end
		pf.ForEachTunnel("map", f)
	end
	for i = #(debug_pass_vectors or empty_table), count + 1, -1 do
		DoneObject(debug_pass_vectors[i])
		debug_pass_vectors[i] = nil
	end
	if show == false then
		debug_pass_vectors = false
	end
end

function OnMsg.OnPassabilityChanged(clip)
	CreateMapRealTimeThread(function()
		if debug_pass_vectors then
			DbgDrawTunnels(true)
		end
	end)
end

function FollowForcedPath(unit, path)
	pf.SetForcedPath(unit, path)
	unit:Goto(path[#path], "sl")
end

function turn_test(angle, dist, unit, on_start, on_end)
	DbgClear()
	DbgSetVectorZTest(false)
	unit = unit or SelectedObj
	unit = GetTopmostParent(unit)
	angle = angle or -90 * 60
	dist = dist or Max(2*unit:GetStepLength(), 4*unit:GetRadius())
	if not unit then
		return
	end
	unit:SetCommand(function(self, angle, on_start, on_end)
		table.change(config, "turn_test", { DebugObjMovement = true })
		if on_start then on_start(self) end
		local p0 = self:GetPos()
		local step = self:GetRelativePoint(dist, 0, 0) - self:GetVisualPos()
		local ps = p0 + SetLen(step, 10)
		local pts = {ps, p0 + step / 2}
		local n = (360*60) / abs(angle)
		if n * abs(angle) == 360*60 then
			n = n - 1
		end
		for i=1,n do
			step = Rotate(step, angle)
			pts[#pts + 1] = pts[#pts] + step
		end
		pts[#pts + 1] = p0
		DbgAddPoly(pts)
		self:SetPos(ps)
		FollowForcedPath(self, pts)
		if on_end then on_end(self) end
		table.restore(config, "turn_test")
	end, angle, on_start, on_end)
end

function OnMsg.SelectedObjChange(obj, prev)
	if config.DebugObjMovement then
		if IsValid(prev) and pf.GetDebugEnabled(prev) then
			pf.SetDebugEnabled(prev, false)
			rawset(prev, "auto_show_path", nil)
		end
		if IsValid(obj) then
			pf.SetDebugEnabled(obj, true)
			if pf.GetDebugEnabled(obj) then
				rawset(obj, "auto_show_path", false)
				DbgClearVectors()
				local path = pf.GetPath(obj)
				if path then
					DbgSetVectorZTest(false)
					DbgAddPoly(path, white, true);
					for i = 1,#path do
						DbgAddVector(path[i], const.PassTileSize, 0xff888888)
					end
					local dest, maxr, minr = pf.GetPathDest(obj)
					for _, pt in ipairs(dest) do
						DbgAddVector(pt, guim, 0xff0088ff)
						if maxr > 0 then
							DbgAddCircle(pt, maxr, 0xff88ff00)
						end
						if minr > 0 then
							DbgAddCircle(pt, minr, 0xffff8800)
						end
					end
				end
			end
		end
	end
end

--[[ Uncomment to keep track of the Step function
__step_infos = false
__step_info_time = 0
local CALLS, TIME, MAX, CLASS = 1, 2, 3, 4
function PrintStepInfo()
	local elapsed = Max(1, GameTime() - __step_info_time)
	print("Step ELAPSED", elapsed)
	table.sort(__step_infos, function(a, b)
		if a[TIME] ~= b[TIME] then
			return a[TIME] > b[TIME]
		end
		if a[MAX] ~= b[MAX] then
			return a[MAX] > b[MAX]
		end
		if a[CALLS] ~= b[CALLS] then
			return a[CALLS] < b[CALLS]
		end
		return a[CLASS] < b[CLASS]
	end)
	for _, info in ipairs(__step_infos) do
		printf("TIME %4d | CALLS %4d | LOAD %5.2f | AVGT %5.2f | MAXT %4d, CLASS %s", info[TIME], info[CALLS], info[TIME] * 100.0 / elapsed, info[TIME] * 1.0 / info[CALLS], info[MAX], info[CLASS])
	end
	__step_infos = {}
	__step_info_time = GameTime()
end
local dbg_step = function(self, ...)
	local st = GetPreciseTicks()
	local status, new_path, res3 = pf.Step(self, ...)
	if new_path then
		if not __step_infos then
			__step_infos = {}
			__step_info_time = GameTime()
		end
		local step_info = __step_infos[self.class]
		local dt = GetPreciseTicks() - st
		if not step_info then
			step_info = {1, dt, dt, self.class}
			__step_infos[self.class] = step_info
			__step_infos[#__step_infos + 1] = step_info
		else
			step_info[CALLS] = step_info[CALLS] + 1
			step_info[TIME] = step_info[TIME] + dt
			step_info[MAX] = Max(step_info[MAX], dt)
			local elapsed = Max(1, GameTime() - __step_info_time)
			local current_load = step_info[TIME] * 100 / elapsed
			if dt > 0 and (current_load > 0 or dt > MulDivRound(3, step_info[TIME], step_info[CALLS])) then
				local color = RandColor(xxhash(self.class))
				if not self:CheckPassable(...) then
					local pos = self:ResolveGotoTarget(...)
					DbgAddCircle(pos, 600, color)
					DbgAddVector(pos, 100*guim, color)
					--StoreErrorSource(self, "Goto impassable: " .. tostring(pos))
				end
				--DbgAddVector(self, 10 * guim * current_load, color)
				DbgDrawPath(self, color)
				DbgAddText(dt, self, color, nil, black)
			end
		end
	end
	assert(res3 == nil)
	return status, new_path
end
function OnMsg.ClassesPreprocess(classdefs)
	for name, def in next, classdefs do
		if def.Step == pf.Step then
			def.Step = dbg_step
		end
	end
end
--]]

----

MapVar("DbgDrawPathObjs", false)

function DbgTogglePaths()
	DbgDrawPaths(not DbgDrawPathObjs)
end

local function DbgMarkPathObj(obj, time)
	local info = DbgDrawPathObjs[obj]
	if not info then
		info = { hashes = {} }
		DbgDrawPathObjs[obj] = info
	end
	info.time = time or GameTime()
end

local function DbgSetPathObj(parent, name, dbg_obj, attach)
	local info = DbgDrawPathObjs[parent]
	if not info then
		return
	end
	local prev_dbg_obj = info[name]
	info[name] = dbg_obj
	if dbg_obj and attach then
		dbg_obj:SetScale(10000/parent:GetScale())
		parent:Attach(dbg_obj)
	end
	DoneObjects(prev_dbg_obj)
	if IsValid(prev_dbg_obj) then
		DoneObject(prev_dbg_obj)
	end
end

local function DbgUpdatePathObj(obj, name, hash)
	local prev_hash = table.get(DbgDrawPathObjs, obj, "hashes", name)
	if prev_hash == hash then return end
	table.set(DbgDrawPathObjs, obj, "hashes", name, hash)
	return true
end

function DbgDrawPaths(draw)
	if not draw then
		for obj, info in pairs(DbgDrawPathObjs) do
			for name, dbg_obj in pairs(info) do
				if type(dbg_obj) == "table" then
					DoneObjects(dbg_obj)
					if IsValid(dbg_obj) then
						DoneObject(dbg_obj)
					end
				end
			end
		end
		DbgDrawPathObjs = false
		return
	end
	print("Cyan: destlock, Green: resting, Yellow: collision, White: path, Pink: flight")
	DbgDrawPathObjs = {}
	CreateGameTimeThread(function(paths)
		while DbgDrawPathObjs == paths do
			local time = GameTime()
			MapForEach("map", nil, const.efDestlock, function(obj)
				DbgMarkPathObj(obj, time)
				local pos = obj:GetPos()
				local hash = xxhash(pos)
				if DbgUpdatePathObj(obj, "destlock", hash) then
					local circle = PlaceCircle(ValidateZ(pos), pf.GetDestlockRadius(obj), cyan, false)
					DbgSetPathObj(obj, "destlock", circle)
				end
				if DbgUpdatePathObj(obj, "path", hash) then
					local vector = PlaceVector(ValidateZ(pos), 2*guim, cyan, false)
					DbgSetPathObj(obj, "path", vector)
				end
			end)
			MapForEach("map", nil, const.efUnit, function(obj)
				if obj:GetComponentFlags(const.cofComponentPath) == 0 or not IsValidPos(obj) then
					return
				end
				DbgMarkPathObj(obj, time)

				local resting = obj:GetEnumFlags(const.efResting) ~= 0
				local destlock_radius = pf.GetDestlockRadius(obj)
				local collision_radius = pf.GetCollisionRadius(obj)
				local scale = obj:GetScale()
				local resting_hash = xxhash(resting, destlock_radius, collision_radius, scale)
				if DbgUpdatePathObj(obj, "resting", resting_hash) then
					local collision_circle, destlock_circle
					if resting then
						destlock_circle = CreateCircleMesh(destlock_radius, green)
					else
						collision_circle = CreateCircleMesh(collision_radius, yellow)
					end
					DbgSetPathObj(obj, "collision", collision_circle, true)
					DbgSetPathObj(obj, "destlock", destlock_circle, true)
				end
				
				local flight_path = obj.flying and obj.flight_path or empty_table
				local path = pf.GetPath(obj) or empty_table
				local path_hash = obj:GetPathHash()
				if DbgUpdatePathObj(obj, "path", path_hash) then
					local destlock = obj:GetDestlock()
					local path_line, path_spline, path_steps
					if #flight_path > 0 then
						path_spline = PlaceSplines(obj.flight_path, 0xff00ff, false, obj.flight_spline_idx)
					else
						local path = pf.GetPath(obj) or ""
						if #path > 0 then
							for i=2,#path do
								local pt = path[i]
								if IsValidPos(pt) then
									pt = ValidateZ(pt)
									path_steps = table.create_add(path_steps, PlacePolyLine({pt:AddZ(-100), pt:AddZ(100)}, yellow, false))
								end
							end
							path[#path + 1] = obj:GetVisualPos()
							path_line = PlacePolyLine(path, white, false)
						elseif IsValidPos(destlock) then
							path_line = PlacePolyLine({obj:GetVisualPos(), destlock:GetVisualPos()}, white, false)
						end
					end
					DbgSetPathObj(obj, "path_steps", path_steps)
					DbgSetPathObj(obj, "path", path_line)
					DbgSetPathObj(obj, "spline_path", path_spline)
				end
			end)
			for obj, info in pairs(DbgDrawPathObjs) do
				if info.time ~= time then
					for name, mesh in pairs(info) do
						if IsValid(mesh) then
							DoneObject(mesh)
						end
					end
					DbgDrawPathObjs[obj] = nil
				end
			end
			Sleep(100)
		end
	end, DbgDrawPathObjs)
end

-- requires config.DbgObjCallback = true
function OnMsg.DbgObjCallback(method, obj, ...)
	print("DbgObjCallback:", obj.class, method, ...)
end
