if Platform.cmdline then return end

if FirstLoad then
	debug_pass_draw = false
end
function OnMsg.DoneMap()
	debug_pass_draw = false
	rawset(_G, "g_APCostsShown", false)
end

DefineClass.DebugPassDraw =
{
	__parents = { "CObject" },
	entity = "Floor_Planks",
	flags = {
		efSelectable = false, efWalkable = false, efCollision = false, 
		efApplyToGrids = false, efShadow = false, efSunShadow = false,
		cfConstructible = false,
		cofComponentColorizationMaterial = true,
		cofComponentCollider = false,
	},
}

function DbgDrawPFLevelPass(on, offsetz)
	debug_pass_draw = debug_pass_draw or {}
	for i = #debug_pass_draw, 0, -1 do
		if IsValid(debug_pass_draw[i]) then DoneObject(debug_pass_draw[i]) end
		debug_pass_draw[i] = nil
	end
	if on == false then
		return
	end
	local tile_size = const.SlabSizeX
	local tile_z = const.SlabSizeZ
	local scale = const.PassTileSize * 100 / const.SlabSizeX
	local color1_central = RGB(120,180,130)
	local color1_intermediate = RGB(150,220,160)
	offsetz = offsetz or 5*guic

	local function func(x, y, z)
		local o = PlaceObject("DebugPassDraw")
		table.insert(debug_pass_draw, o)
		NetTempObject(o)
		o:SetScale(scale)
		local vx, vy, vz = WorldToVoxel(x, y, z)
		local _x, _y, _z = VoxelToWorld(vx, vy, vz)
		local inside_tile = abs(x - _x) < tile_size / 2 and abs(y - _y) < tile_size / 2
		if inside_tile then
			--o:SetColorizationMaterial(1, color1_central, 0, 0)
			o:SetColorModifier(color1_central)
		else
			--o:SetColorizationMaterial(1, color1_intermediate, 0, 0)
			o:SetColorModifier(color1_intermediate)
			o:SetAngle(90*60)
		end
		o:SetPos(x, y, z + offsetz)
	end
	local sizex, sizey = terrain.GetMapSize()
	terrain.ForEachPassCenter(func, box(0, 0, 0, sizex, sizey, 100000)) -- all map pflevels (without terrain)
	return #debug_pass_draw
end

function DbgDrawPassSlabs(on, show_terrain_pass, offsetz, bbox)
	local sizex, sizey = terrain.GetMapSize()
	bbox = bbox or box(0, 0, 0, sizex, sizey, 100000)

	debug_pass_draw = debug_pass_draw or {}
	local i, n = 1, #debug_pass_draw
	while i <= n do
		local obj = debug_pass_draw[i]
		if not IsValid(obj) or obj:GetPos():InBox(bbox) then
			if IsValid(obj) then DoneObject(obj) end
			debug_pass_draw[i] = debug_pass_draw[n]
			debug_pass_draw[n] = nil
			n = n - 1
		else
			i = i + 1
		end
	end
	if on == false then
		return
	end

	local floor = IsEditorActive() and XEditorFilters:GetFilter("HideFloor") or 0
	if floor == 0 then floor = 999 end

	local color = RGB(120, 180, 130)
	local colorWater = RGB(0, 0, 130)
	local scale = const.PassTileSize * 100 / const.SlabSizeX
	local scaleWater = scale * 60 / 100
	local ptGrow = point(const.SlabSizeX, const.SlabSizeY, const.SlabSizeZ * 2)
	offsetz = offsetz or 5*guic
	local hide_roofs = IsEditorActive() and not LocalStorage.FilteredCategories["Roofs"] or nil

	local function func(x, y, z)
		if not z and not show_terrain_pass then
			return
		end
		if not terrain.IsPassable(x, y, z, 0) then
			return
		end
		local pt = point(x, y, (z or terrain.GetHeight(x, y)) + offsetz)
		local volume = Extend(empty_box, pt):grow(ptGrow)
		local room = EnumVolumes(volume, "smallest")
		local bld_meta = VolumeBuildingsMeta[room and room.building or false]
		if bld_meta and bld_meta[floor] and pt:z() >= bld_meta[floor].box:minz() - 5 * guim / 10 then
			return -- don't add debug pass that would be hidden because of the floor editor filter
		end
		if hide_roofs then
			local slab, z = WalkableSlabByPoint(pt, true, bnot(const.gofSolidShadow))
			if GetPassSlab(x, y, z) then
				local threshold = IsKindOf(slab, "TerrainCollision") and 15 * guic or 7 * guic
				if abs(z - pt:z()) >= threshold then
					return
				end
			end
		end
		local o = PlaceObject("DebugPassDraw")
		table.insert(debug_pass_draw, o)
		NetTempObject(o)
		o:SetColorModifier(color)
		o:SetScale(scale)
		o:SetPos(pt)
		--if not z and SelectedObj:GetDist(x,y) < 2000 then
		--	z = nil
		--end
		local pass_type = terrain.GetPassType(point(x, y, z))
		if pass_type == pathfind_water_pass_type_idx then
			local o = PlaceObject("DebugPassDraw")
			table.insert(debug_pass_draw, o)
			NetTempObject(o)
			o:SetColorModifier(colorWater)
			o:SetScale(scaleWater)
			o:SetPos(pt:x(), pt:y(), pt:z() + offsetz)
		end
	end
	ForEachPassSlab(bbox, func)
	return #debug_pass_draw
end

function DbgDrawCombatNodes(combatPath, max_cost)
	DbgClearVectors()
	DbgClearTexts()
	local tile_size = const.SlabSizeX
	local ap_mul = const.Scale.AP
	local color = const.clrPaleBlue
	local offs = tile_size*25/100
	local offsz = 10*guic

	for pk_pos, ap in pairs(combatPath and combatPath.paths_ap or empty_table) do
		if not max_cost or ap <= max_cost then
			local x1, y1, z1 = point_unpack(pk_pos)
			z1 = (z1 or terrain.GetHeight(x1, y1)) + offsz
			local txt
			if ap % ap_mul == 0 then
				txt = string.format("%d", ap / ap_mul)
			else
				txt = string.format("%d.%.2d", ap / ap_mul, Max(1, (ap % ap_mul) * 100 / ap_mul))
			end
			local p = point(x1, y1, z1)
			DbgAddText(txt, p, color)
			local prev_pos = combatPath.paths_prev_pos[pk_pos]
			if prev_pos then
				local x2, y2, z2 = point_unpack(prev_pos)
				z2 = (z2 or terrain.GetHeight(x2, y2)) + offsz
				local dx = (x2 - x1) / tile_size
				local dy = (y2 - y1) / tile_size
				local p2 = point(x2, y2, z2)
				if dx == 0 or dy == 0 then
					p2 = p - SetLen(p - p2, tile_size)
				else
					for k = Min(abs(dx), abs(dy)), 2, -1 do
						if dx % k == 0 and dy % k == 0 then
							p2 = p + point(tile_size * dx / k, tile_size * dy / k, 0)
							break
						end
					end
				end
				local v = p - p2
				local len = v:Len()
				DbgAddVector(p - SetLen(v, len - offs), SetLen(v, len - 2*offs), color)
			end
		end
	end
end

function DbgDrawCombatPositions(unit, max_cost)
	if not IsValid(unit) then return end
	local combatPath = PlaceObject("CombatPath")
	combatPath:RebuildPaths(unit, max_cost or unit.ActionPoints)
	DbgDrawCombatNodes(combatPath)
	DoneObject(combatPath)
end

function DbgRecalcDrawCombatNodes(unit)
	if not rawget(_G, "g_APCostsShown") then
		return
	end
	if unit ~= SelectedObj then
		return
	end
	if IsValid(SelectedObj) then
		DbgDrawCombatNodes(GetCombatPath(SelectedObj))
	else
		DbgDrawCombatNodes(false)
	end
end
OnMsg.SelectedObjChange = DbgRecalcDrawCombatNodes
OnMsg.UnitAPChanged = DbgRecalcDrawCombatNodes
OnMsg.UnitMovementDone = DbgRecalcDrawCombatNodes

function OnMsg.UnitAPChanged(unit)
	if unit == SelectedObj then
		DbgRecalcDrawCombatNodes()
	end
end

local function DbgCollapsePointsInBox(b, steps)
	local pts = {}
	ForEachPassSlab(b, function(x, y, z)
		pts[#pts + 1] = stance_pos_pack(x, y, z, 0)
	end)
	local collapsed = CollapsePoints(pts, steps)
	for _, pt in ipairs(pts) do
		local x, y, z = stance_pos_unpack(pt)
		if table.find(collapsed, pt) then
			ShowMe(point(x,y,z))
		else
		end
	end
end

function DbgShowVisFieldCollapsedPositionsArroundCursor(steps, radius)
	ClearShowMe()
	DbgClear()
	steps = steps or 1
	local cursor = GetCursorPos()
	radius = radius or 10*guim
	local b = box(cursor:x() - radius, cursor:y() - radius, 0, cursor:x() + radius + const.SlabSizeX, cursor:y() + radius + const.SlabSizeX, MapSlabsBBox_MaxZ)
	--RebuildVisField(b)
	DbgCollapsePointsInBox(b, steps)
end