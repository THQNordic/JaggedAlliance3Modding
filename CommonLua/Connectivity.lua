if not const.ConnectivitySupported then
	return
end

OnMsg.PostNewMapLoaded = ConnectivityResume
OnMsg.PostLoadGame = ConnectivityResume

if Platform.asserts then

function TestConnectivity(unit, target, count)
	count = count or 1
	unit = unit or SelectedObj
	target = target or terrain.FindPassable(GetCursorPos())
	DbgClear()
	if not IsKindOf(unit, "Movable") then return end
	target = target or MapFindNearest(unit, "map", unit.class, function(obj) return obj ~= unit end)
	if not target then return end
	ConnectivityClear() -- test the uncached connectivity speed, as the cached one is practically zero.
	local stA = GetPreciseTicks(1000000)
	local pathA = ConnectivityCheck(unit, target) or false
	local timeA = GetPreciseTicks(1000000) - stA
	local stB = GetPreciseTicks(1000000)
	local pfclass, range, min_range, path_owner, restrict_area_radius, restrict_area
	local path_flags = const.pfmImpassableSource
	local pathB = pf.HasPosPath(unit, target, pfclass, range, min_range, path_owner, restrict_area_radius, restrict_area, path_flags) or false
	local timeB = GetPreciseTicks(1000000) - stB
	DbgAddSegment(unit, target)
	print("1 | path:", pathA, "| time:", timeA / 1000.0, "| ConnectivityCheck")
	print("2 | path:", pathB, "| time:", timeB / 1000.0, "| pf.HasPosPath")
	print("Linear dist 2D:", unit:GetDist2D(target))
end

function TestConnectivityShowPatch(pos)
	hr.DbgAutoClearLimit = Max(20000, hr.DbgAutoClearLimit)
	hr.DbgAutoClearLimitTexts = Max(10000, hr.DbgAutoClearLimitTexts)
	pos = pos or SelectedObj or GetCursorPos()
	local pfclass = 0
	if IsKindOf(pos, "Movable") then
		pfclass = pos:GetPfClass()
	end
	pos = terrain.FindPassable(pos)
	print(ValueToStr(ConnectivityPatchInfo(ConnectivityGameToPatch(pos), pfclass)))
end

function TestConnectivityRecalcPatch(pos)
	pos = pos or SelectedObj or GetCursorPos()
	local grid = 0
	if IsKindOf(pos, "Movable") then
		grid = table.get(pos:GetPfClassData(), "pass_grid") or 0
	end
	pos = terrain.FindPassable(pos)
	ConnectivityRecalcPatch(ConnectivityGameToPatch(pos, grid))
end

function TestConnectivityPerformance(pos)
	pos = terrain.FindPassable(pos or SelectedObj or GetCursorPos())
	local minx, miny, maxx, maxy = GetPlayBox(guim):xyxy()
	local seed = 0
	local count = 100000
	local x, y
	local target = point()
	SuspendThreadDebugHook(1)
	local st = GetPreciseTicks(1000000)
	for i=1,count do
		x, seed = BraidRandom(seed, minx, maxx - 1)
		y, seed = BraidRandom(seed, miny, maxy - 1)
		if terrain.IsPassable(x, y) then
			target:InplaceSet(x, y)
			ConnectivityClear()
			ConnectivityCheck(pos, target)
		end
	end
	print("Avg Time:", (GetPreciseTicks(1000000) - st) / (1000.0 * count))
	print("Stats:", ConnectivityStats())
	ResumeThreadDebugHook(1)
end

end -- Platform.asserts