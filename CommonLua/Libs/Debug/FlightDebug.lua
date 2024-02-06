if not const.FlightTile then
	return
end

local default_inspect = {
	--show_energy_map = true,
	--show_flight_map = true,
	--inspect_map = true,
	--show_points = true,
	--inspect_spline = true,
	--linelist = true,
	show_splines = true,
	spline_color = cyan,
	spline_color_alt = blue,
}
--]]

function FlightDbgToggleMap(obj, obstacles)
	local mesh = obj.dbg_flight_map_mesh
	if mesh then
		DoneObject(obj.dbg_flight_map_mesh)
		obj.dbg_flight_map_mesh = nil
		return
	end
	mesh = Mesh:new()
	obj.dbg_flight_map_mesh = mesh
	local flight_map, energy_map = FlightCreateGrids(mapdata.PassBorder)
	FlightMarkObstacle(flight_map, obj)
	for _, obstacle in ipairs(obstacles) do
		FlightMarkObstacle(flight_map, obstacle)
	end
	local collected_tiles = {}
	local GetHeight = terrain.GetHeight
	GridForeach(flight_map, function(v, x, y)
		local x, y, z = FlightToGame(x, y, v)
		if z and z > GetHeight(x, y) then
			local mark_color = 0x3300ffff
			table.insert(collected_tiles, { x, y, z, mark_color })
		end
	end, 1)
	if #collected_tiles ~= 0 then
		table.sort(collected_tiles, function(lhs, rhs) return lhs[3] < rhs[3] end)
		local v_pstr = pstr("", 1024*1024)
		local mark_tile = const.FlightTile - 200
		for _,tile in ipairs(collected_tiles) do
			local x, y, z, c = tile[1], tile[2], tile[3], tile[4]
			AppendTileVertices(v_pstr, x, y, z, mark_tile, c)
		end
		mesh:SetMesh(v_pstr)
		mesh:SetVisible(true)
		mesh:SetDepthTest(true)
		mesh:SetShader(ProceduralMeshShaders.default_mesh)
		mesh:SetMeshFlags(const.mfWorldSpace)
		obj:Attach(mesh)
	end
	flight_map:free()
	energy_map:free()
end

function FlightObstacle:AsyncCheatFlight()
	FlightDbgToggleMap(self)
end

DbgFlightToggleFlightMap = empty_func

if not Platform.developer and not Platform.debug then
	return
end

local getters = {
	FlightSimMaxSpeedXY = function(self)
		local a = self:GetProperty("FlightSimAttract")
		local cf = self:GetProperty("FlightSimFrictionXY")
		return cf > 0 and 100 * a / cf or max_int
	end,
	FlightSimMaxSpeedUp = function(self)
		local a = self:GetProperty("FlightSimMaxLift")
		local cf = self:GetProperty("FlightSimFrictionZ")
		return cf > 0 and 100 * a / cf or max_int
	end,
	FlightSimMaxSpeedDown = function(self)
		local a = self:GetProperty("FlightSimMaxWeight")
		local cf = self:GetProperty("FlightSimFrictionZ")
		return cf > 0 and 100 * a / cf or max_int
	end,
	FlightPathIntervalMinStep = function(self)
		return 1000 * self:GetProperty("FlightPathStepMin") / self:GetProperty("FlightSpeedMin")
	end,
	FlightPathIntervalMaxStep = function(self)
		return 1000 * self:GetProperty("FlightPathStepMax") / self:GetProperty("FlightSpeedMax")
	end,
	FlightAchievableSpeed = function(self)
		local a = self:GetProperty("FlightAccelMax")
		local cf = self:GetProperty("FlightFriction")
		return cf > 0 and 100 * a / cf or max_int
	end,
}
function getter(self, prop)
	local func = getters[prop]
	if func then
		return func(self)
	end
end
local props =  {
	{ category = "Flight Path", id = "FlightSimMaxSpeedXY",   name = "Max Speed XY",           editor = "number", default = 0, scale = guim, getter = getter, read_only = true, dont_save = true, template = true, developer = true },
	{ category = "Flight Path", id = "FlightSimMaxSpeedUp",   name = "Max Speed Up",           editor = "number", default = 0, scale = guim, getter = getter, read_only = true, dont_save = true, template = true, developer = true },
	{ category = "Flight Path", id = "FlightSimMaxSpeedDown", name = "Max Speed Down",         editor = "number", default = 0, scale = guim, getter = getter, read_only = true, dont_save = true, template = true, developer = true },
	{ category = "Flight",      id = "FlightAchievableSpeed", name = "Achievable Speed (m/s)", editor = "number", default = 0, scale = guim, getter = getter, read_only = true, dont_save = true, template = true, developer = true },
	{ category = "Flight",      id = "FlightPathIntervalMinStep", name = "Path Interval Min Step (ms)", editor = "number", default = 0, getter = getter, read_only = true, dont_save = true, template = true, developer = true },
	{ category = "Flight",      id = "FlightPathIntervalMaxStep", name = "Path Interval Max Step (ms)", editor = "number", default = 0, getter = getter, read_only = true, dont_save = true, template = true, developer = true },
}
for _, prop in ipairs(props) do
	FlyingObj["Get" .. prop.id] = getters[prop.id]
end
table.iappend(FlyingObj.properties, props)
local setter = function(self, value, prop_id, prop_meta)
	self[prop_id] = value
	if SelectedObj and IsKindOf(SelectedObj, "FlyingObj") then
		SelectedObj[prop_id] = value
		SelectedObj:RecalcFlightPath()
	end
end
for _, prop_meta in ipairs(FlyingObj.properties) do
	if prop_meta.sim and not prop_meta.read_only and not prop_meta.setter then
		prop_meta.setter = setter
	end
end

function FlyingObj:OnEditorSetProperty(prop_id, old_value, ged)
	local prop_meta = self:GetPropertyMetadata(prop_id) or empty_table
	if prop_meta.sim then
		self:RecalcFlightPath()
	end
end

----

if const.FlightDebugPath then

table.insert(FlyingObj.properties, {
	category = "Flight Path", id = "FlightDebugIter", name = "Debug Iteration",
	editor = "number", default = 0, min = -1, max = PropGetter("flight_path_iters"), step = 1, slider = true,
	dont_save = true, buttons = {{"Recalc", "FlightDbgRecalcAction"}, {"Prev", "FlightDbgPrevAction"}, {"Next", "FlightDbgNextAction"}} })
	
FlyingObj.flight_debug_iter = 0
	
local function RecalcFlightPath(obj, step)
	step = step or 0
	DbgClear()
	obj:SetFlightDebugIter(obj:GetFlightDebugIter() + step)
end
function FlightDbgRecalcAction(_, obj)
	RecalcFlightPath(obj)
	FlightDbgShow{ show_energy_map = true }
	ObjModifiedDelayed(obj)
end
function FlightDbgNextAction(_, obj)
	RecalcFlightPath(obj, 1)
end
function FlightDbgPrevAction(_, obj)
	RecalcFlightPath(obj, -1)
end

function FlyingObj:SetFlightDebugIter(iter)
	iter = iter and Clamp(iter, -1, self.flight_path_iters) or 0
	self.flight_debug_iter = iter ~= 0 and iter or nil
	table.change(config, "RecalcFlightPath", {
		DebugFlightDisabled = true
	})
	self:FindFlightPath(self.flight_target, self.flight_target_range, self.flight_path_flags, self.flight_debug_iter)
	table.restore(config, "RecalcFlightPath")
end

function FlyingObj:GetFlightDebugIter()
	return self.flight_debug_iter
end

end -- const.FlightDebugPath
----

MapVar("DbgFlightObjs", false)

function FlightDbgAdd(obj)
	DbgFlightObjs = table.create_add(DbgFlightObjs, obj)
end

function FlightDbgClear(delayed)
	local objs = DbgFlightObjs
	if not objs then return end
	DbgFlightObjs = false
	local function DeleteAll(objs)
		for _, obj in ipairs(objs) do
			if IsValid(obj) then
				DoneObject(obj)
			elseif IsValidThread(obj) then
				DeleteThread(obj)
			end
		end
	end
	if delayed then
		CreateRealTimeThread(DeleteAll, objs)
	else
		DeleteAll(objs)
	end
end

function OnMsg.DbgClear() FlightDbgClear() end
function OnMsg.LoadGame() FlightDbgClear() end

local function AppendTileVerticesLinelist(v_pstr, x, y, z, mark_tile, mark_color, offset_z, get_height)
	offset_z = offset_z or 0
	z = z or InvalidZ
	local d = mark_tile / 2
	local tile_box = box(x - d, y - d, x + d, y + d)
	local pts = { tile_box:ToPoints2D() }
	pts[#pts + 1] = pts[1]
	get_height = get_height or terrain.GetHeight
	local AppendVertex = v_pstr.AppendVertex
	for i=1,4 do
		local x1, y1 = pts[i]:xy()
		local x2, y2 = pts[i+1]:xy()
		local z1 = (z == InvalidZ and get_height(x1, y1) or z) + offset_z
		local z2 = (z == InvalidZ and get_height(x2, y2) or z) + offset_z
		AppendVertex(v_pstr, x1, y1, z1, mark_color)
		AppendVertex(v_pstr, x2, y2, z2, mark_color)
	end
end

function FlightAvgSplineLen(splines)
	local n = #(splines or "")
	if n == 0 then return 0 end
	local pt0 = splines[1][1]
	local pt1 = splines[n][4]
	local dist = pt0:Dist(pt1)
	return dist / n
end

MapVar("FlightDbgObj", false)
MapVar("FlightDbgSaveTime", 0)

function FlightDbgSelectObj(obj)
	obj = obj or FlightDbgObj
	FlightDbgObj = obj
	SelectObj(obj) ViewObjectRTS(obj)
end

function FlightDbgBreak(obj, err)
	if err and config.DebugFlight then
		FlightDbgSelectObj(obj)
		obj:SetFlightFlag(const.ffpDebug, true)
		if CanYield() and FlightDbgSaveTime ~= GameTime() then
			FlightDbgSaveTime = GameTime()
			CreateRealTimeThread(QuickSaveGame, "FlightFindPath") Sleep(1)
			SetGameSpeed("pause") InterruptAdvance()
		end
	end
end

function FlightDbgResults(obj)
	if config.DebugFlightDisabled then return end
	obj = obj or FlightFrom
	if not IsValid(obj) then
		return
	end
	local splines = obj.flight_path
	local status = obj.flight_path_status
	local target = obj.flight_target or FlightTo
	local path_errors = FlightGetErrors(status)
	local dest_error = obj:GetAdjustFlightTarget() and not obj:CanFlyTo(target)
	local err = path_errors or dest_error
	local should_debug = err or config.DebugFlight and (table.find(Selection, obj) or IsValid(obj) and obj:GetFlightFlag(const.ffpDebug))
	if not should_debug then
		return
	end
	FlightDbgShow{ splines = splines }
	ObjModifiedDelayed(obj)
	if err then
		if dest_error then
			StoreErrorSource(obj, "Flying to a forbidden flight destination:", ValueToStr(target))
		end
		local path_error = path_errors and table.concat(path_errors, "', '")
		if path_error then
			StoreErrorSource(obj, string.format("Errors '%s' when trying to reach %s", path_error, ValueToStr(target)))
		end
		DbgAddSegment(obj, target, red) DbgAddCircle(target, guim/2, red) DbgAddVector(target, guim, red)
		for i, spline in ipairs(splines) do
			DbgAddSpline(spline, (i % 2 == 0) and cyan or blue)
		end
	end
	FlightDbgBreak(obj, err)
end

function FlightDbgMark(ptFrom, ptTo)
	local idx = FlightMarkIdx + 1
	FlightMarkIdx = idx
	local pt0, pt1 = ResolveVisualPos(ptFrom), ResolveVisualPos(ptTo)
	local x0, y0 = GameToFlight(pt0)
	local x1, y1 = GameToFlight(pt1)
	local inside_from, inside_to = FlightArea:Point2DInside(x0, y0), FlightArea:Point2DInside(x1, y1)
	local valid_from, valid_to = FlightMap:get(x0, y0) ~= const.FlightInvalid, FlightMap:get(x1, y1) ~= const.FlightInvalid
	local inside = inside_from and inside_to
	local valid = valid_from and valid_to
	local color = not inside and blue or not valid and red or green
	DbgClear(true)
	DbgAddText(idx, pt0:AddZ(5*guim))
	DbgAddVector(pt0, pt1 - pt0, yellow)
	DbgAddSegment(pt0:SetInvalidZ(), pt1:SetInvalidZ(), 0xff888888)
	DbgAddSegment(pt1, pt1:SetInvalidZ())
	DbgAddSegment(pt0, pt0:SetInvalidZ())
	DbgAddBox(boxdiag(pt0, pt1):grow(FlightMarkBorder):SetInvalidZ(), color)
	if not inside or not valid then
		SetGameSpeed("pause")
		ViewPos(pt0)
		print("Invalid flight mark", FlightMarkIdx, marked, ValueToStr(ptFrom))
		assert(false, "Invalid flight mark!")
	end
end

function FlightDbgShowPaths()
	MapForEach("map", "FlyingObj", function(obj)
		if #(obj.flight_path or "") > 0 then
			_FlightDbgShow{
				splines = obj.flight_path,
				spline_color = RandColor(obj.handle),
				spline_color_alt = false,
				show_flight_map = false,
			}
		end
	end)
end

function FlightDbgShow(params)
	return DelayedCall(0, _FlightDbgShow, params)
end

function _FlightDbgShow(params)
	FlightDbgClear()
	params = params or {}
	table.append(params, default_inspect)
	if not next(params) then return end
	
	local energy_map = FlightEnergyMin and FlightEnergy
	local flight_map = FlightMap
	local flight_area = FlightArea
	local path_from = FlightFrom
	local path_to = FlightTo
	local energy_min = FlightEnergyMin
		
	local splines, points, raw_points = params.splines, params.points, params.raw_points
	local z_offset = const.FlightScale / 2
	local v_pstr
	local max_energy = const.FlightMaxEnergy
	local FlightToGame = FlightToGame
	local GetHeight = terrain.GetSurfaceHeight
	local function FlightDbgAddSegment(ptA, ptB, color)
		FlightDbgAdd(PlacePolyLine({ptA, ptB}, color, false))
	end
	local function FlightDbgAddCircle(pt, radius, color)
		FlightDbgAdd(PlaceCircle(pt, radius, color, false))
	end
	energy_min = energy_min and ResolvePoint(FlightToGame(energy_min))
	if energy_min and params.show_energy_map then
		FlightDbgAddSegment(energy_min, energy_min:AddZ(10*guim), 0xffff0000)
	end
	local path_obj = IsValid(path_from) and path_from
	path_from = path_from and ResolvePoint(path_from)
	path_to = path_to and ResolvePoint(path_to)
	local collected_tiles = {}
	if flight_area and energy_map and params.show_energy_map then
		local pts = {}
		local mine, maxe = max_energy, 0
		GridForeach(energy_map, flight_area, function(e, x, y)
			mine, maxe = Min(mine, e), Max(maxe, e)
			pts[#pts + 1] = point(x, y, e)
		end, 0, max_energy - 1)
		for _, pt in ipairs(pts) do
			local x, y, e = pt:xyz()
			local z
			if flight_map then
				z = flight_map:get(x, y)
				x, y, z = FlightToGame(x, y, z)
			else
				x, y = FlightToGame(x, y)
			end
			z = z or GetHeight(x, y)
			local mark_color = e == 0 and cyan or InterpolateRGB(red, green, e - mine, maxe - mine)
			table.insert(collected_tiles, { x, y, z, mark_color })
		end

	elseif flight_area and flight_map and params.show_flight_map then
		GridForeach(flight_map, flight_area, function(v, x, y)
			local x, y, z = FlightToGame(x, y, v)
			local mark_color = z and 0x3300ffff or 0x33ffff00
			z = z or GetHeight(x, y)
			table.insert(collected_tiles, { x, y, z, mark_color })
		end, 0, const.FlightInvalid - 1)
	end
	if #collected_tiles ~= 0 then
		table.sort(collected_tiles, function(lhs, rhs) return lhs[3] < rhs[3] end)
		
		local v_pstr = pstr("", 1024*1024)
		local __AppendTileVertices
		local mark_tile
		if params.linelist then
			__AppendTileVertices = AppendTileVerticesLinelist
			mark_tile = const.FlightTile
		else
			__AppendTileVertices = AppendTileVertices
			mark_tile = const.FlightTile - 200
		end
		for _,tile in ipairs(collected_tiles) do
			local x, y, z, c = tile[1], tile[2], tile[3], tile[4]
			if z == GetHeight(x, y) then
				z = nil
			end
			__AppendTileVertices(v_pstr, x, y, z, mark_tile, c, z_offset, GetHeight)
		end
		
		local mesh = Mesh:new()
		mesh:SetMesh(v_pstr)
		mesh:SetVisible(true)
		mesh:SetDepthTest(true)
		mesh:SetShader(params.linelist and ProceduralMeshShaders.mesh_linelist or ProceduralMeshShaders.default_mesh)
		mesh:SetMeshFlags(const.mfWorldSpace)
		mesh:SetPos(GetTerrainCursor())
		FlightDbgAdd(mesh)
	end
	
	if params.inspect_map then
		FlightDbgAdd(CreateRealTimeThread(function()
			local emax = const.FlightMaxEnergy
			local escale = const.FlightEnergyScale
			while true do
				DbgClear()
				local pt0 = GetTerrainCursor()
				local x, y = pt0:xy()
				local fx, fy = GameToFlight(x, y)
				local inside = not flight_area or flight_area:Point2DInside(fx, fy)
				local z, e
				if inside then
					local pt1 = pt0
					if flight_map then
						z = FlightGetHeight(flight_map, flight_area, x, y)
						pt1 = point(x, y, z + z_offset)
					end
					if pt0 ~= pt1 then
						DbgAddSegment(pt0, pt1, blue)
					end

					if energy_map then
						e = energy_map:get(fx, fy)
						if e == emax then
							e = nil
						elseif e > 0 then
							--[[
							local f = point20
							for dy=-1,1 do
								for dx = -1,1 do
									if dx ~= 0 or dy ~= 0 then
										local ei = energy_map:get(fx + dx, fy + dy)
										if ei ~= 0 and ei ~= emax then
											local de = (e - ei) * escale
											local v
											if de > 0 then
												v = SetLen(point(dx, dy), de)
											else
												v = SetLen(point(-dx, -dy), -de)
											end
											f = f + v
											DbgAddVector(pt1, v)
										end
									end
								end
							end
							DbgAddVector(pt1, f, yellow)
							--]]
						end
					end
				end
				DbgAddText(string.format("z %s, e %s", tostring(z), tostring(e)), pt0)
				Sleep(50)
			end
		end))
	elseif splines and params.show_splines and params.inspect_spline then
		FlightDbgAdd(CreateRealTimeThread(function()
			while true do
				local pt = GetTerrainCursor()
				local spline
				local min_dist2 = max_int
				for _, spline_i in ipairs(splines) do
					local pt0, pt1 = spline_i[1], spline_i[4]
					local dist2 = DistSegmentToPt2D2(pt0, pt1, pt)
					if dist2 < min_dist2 then
						min_dist2 = dist2
						spline = spline_i
					end
				end
				DbgClear() DbgSetVectorZTest(false)
				if spline then
					local pt0, pt1 = spline[1], spline[4]
					local dist2, x, y, z = DistSegmentToPt2D2(pt0, pt1, pt)
					local k = pt0:Dist(x, y, z)
					local max_k = pt0:Dist(pt1)
					local x, y, z, dx, dy, dz, ddx, ddy, ddz = BS3_GetSplinePosDirCurve(spline, k, max_k)
					local pt_p = point(x, y, z)
					local pt_v = point(dx, dy, dz)
					local pt_a = point(ddx, ddy, ddz)
					local v = pt_v:Len()
					local a = pt_a:Len()
					
					local v2D = pt_v:Len2D()
					local c = v2D > 0 and Cross2D(pt_v, pt_a) / v2D or 0
					local pt_c = c > 0 and SetLen(point(-dy, dx, 0), c) or c < 0 and SetLen(point(dy, -dx, 0), -c) or point30
					local t = atan(c, v2D) / 60
					DbgAddSegment(pt_p, pt)
					DbgAddSegment(pt_p, pt_p:SetTerrainZ(), 0xff666666)
					DbgAddSegment(pt, pt_p:SetTerrainZ(), 0xff666666)
					DbgAddVector(pt_p, pt_v, green)
					DbgAddVector(pt_p, pt_a, red)
					DbgAddVector(pt_p, pt_c, yellow)
					DbgAddText(string.format("v %d, a %d, c %d, t %d", v, a, c, t), pt_p )
				end
				Sleep(50)
			end
		end))
	end
	if raw_points and #raw_points > 1 then
		FlightDbgAdd(PlacePolyLine(raw_points, white, false))
	end
	if points and #points > 1 and params.show_points then
		--local dist = points[1]:Dist2D(points[#points])
		--printf("Points per meter %.3f", 1.0 * guim * #points / dist)
		if path_from then
			FlightDbgAddSegment(path_from, path_from:AddZ(10*guim), 0xff00ff00)
		end
		if path_to then
			FlightDbgAddSegment(path_to, path_to:AddZ(10*guim), 0xffffff00)
		end
		FlightDbgAdd(PlacePolyLine(points, green, false))
		local ptA, ptB
		for i=2,#points-1 do
			local pt = points[i]
			if not flight_map then
				local z = GetHeight(pt)
				FlightDbgAddSegment(pt, pt:SetZ(z), 0xff666666)
			else
				local z = FlightGetHeight(flight_map, flight_area, pt)
				FlightDbgAddSegment(pt, pt:SetZ(z), 0xff666666)
				if path_obj then
					local z_min = z + path_obj.FlightSimHeightMin
					local z_max = z + path_obj.FlightSimHeightMax
					local ptA1, ptB1 = pt:SetZ(z_max), pt:SetZ(z_min)
					if ptA then
						FlightDbgAddSegment(ptA, ptA1, 0xff666600)
						FlightDbgAddSegment(ptB, ptB1, 0xff666600)
					end
					ptA, ptB = ptA1, ptB1
				end
			end
		end
		if path_obj then
			FlightDbgAddCircle(points[#points], path_obj.FlightSimDecelDist, 0xff666666)
		end
	end
	if splines and params.show_splines and #splines > 0 then
		local spline_color = params.spline_color or cyan
		local spline_color_alt = params.spline_color_alt or spline_color
		for i, spline in ipairs(splines) do
			FlightDbgAdd(PlaceSpline(spline, i % 2 == 0 and spline_color or spline_color_alt, false, guim/2))
			--FlightDbgAdd(PlacePolyLine(spline, red, false))
		end
	end
end

function OnMsg.SelectedObjChange(obj, prev)
	FlightDbgClear()
	if obj and #(obj.flight_path or "") > 0 and config.DebugFlight and obj:IsKindOf("FlyingObj") then
		FlightDbgShow{ splines = obj.flight_path, show_flight_map = false }
	end
end

function FlightDbgTestPerformance(unit, pos, count)
	unit = unit or SelectedObj
	pos = pos or unit.flight_target or terrain.FindPassable(GetCursorPos())
	count = count or 1000
	local st = GetPreciseTicks(1000000)
	table.change(config, "FlightDbgTestPerformance", {
		DebugFlightDisabled = true
	})
	FlightDbgClear()
	for i=1,count do
		FlightPassVersion = false
		unit:FindFlightPath(pos)
	end
	table.restore(config, "FlightDbgTestPerformance")
	print("Avg Time:", (GetPreciseTicks(1000000) - st) / (1000.0 * count), "Dist:", unit:GetVisualDist2D(pos))
end

if FirstLoad then
	DbgFlightMapThread = false
end

function DbgFlightMarkAround(pos, radius)
	pos = pos or GetTerrainCursor()
	radius = radius or 64*guim
	FlightTimestamp = false
	FlightMarkBetween(pos, pos, 0, 0, radius)
	FlightDbgClear(true)
	_FlightDbgShow{ show_flight_map = true }
end

function DbgFlightToggleFlightMap(radius)
	local running = IsValidThread(DbgFlightMapThread)
	DeleteThread(DbgFlightMapThread)
	FlightDbgClear(true)
	if running and not radius then return end
	DbgFlightMapThread = CreateMapRealTimeThread(function()
		radius = radius or 64*guim
		local last_pos
		while true do
			local dt = 10
			local pos = GetTerrainCursor():SetInvalidZ()
			if last_pos ~= pos then
				last_pos = pos
				local st = GetPreciseTicks()
				DbgFlightMarkAround(pos, radius)
				dt = dt + (GetPreciseTicks() - st)
			end
			if WaitMsg("DbgClear", dt) then
				FlightDbgClear()
				break
			end
		end
	end)
end
