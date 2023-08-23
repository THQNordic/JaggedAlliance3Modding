if Platform.cmdline then return end

local merc_size1 = point(40 * guic, 80 * guic, 150 * guic)
local merc_size2 = point(80 * guic, 40 * guic, 150 * guic)

g_ZuluMapValidationBoxes = rawget(_G, "g_ZuluMapValidationBoxes") or {}
function OnMsg.ChangeMap()
	g_ZuluMapValidationBoxes = {}
end

local function ClearValidationBoxes(bbox)
	local old = g_ZuluMapValidationBoxes
	g_ZuluMapValidationBoxes = {}
	for _, obj in ipairs(old) do
		if not bbox or obj:GetPos():InBox(bbox) then
			obj:delete()
		else
			g_ZuluMapValidationBoxes[#g_ZuluMapValidationBoxes + 1] = obj
		end
	end
end

function ConstructPassability(bbox)
	-- construct a copy of the passability, considering tunnels and walkable slabs as passable
	local pass_tile = const.PassTileSize
	local pass_grid = editor.GetGrid("pass")
	-- TODO: Check errorneous results on Savannah Camp map
--[[	for x = bbox:minx(), bbox:maxx(), pass_tile do
		for y = bbox:miny(), bbox:maxy(), pass_tile do
			local slab = WalkableSlabByPoint(x, y, terrain.GetHeight(x, y))
			if slab then
				pass_grid:set(x / const.PassTileSize, y / const.PassTileSize, terrain.IsPassable(slab:GetPos()) and 1 or 0)
			end
		end
	end]]
	
	local half_tile = point(pass_tile / 2, pass_tile / 2)
	pf.ForEachTunnel(bbox, function(obj, x1, y1, z1, x2, y2, z2)
		x1 = x1 - pass_tile / 2
		y1 = y1 - pass_tile / 2
		x2 = x2 - pass_tile / 2
		y2 = y2 - pass_tile / 2
		if x1 == x2 then
			if y1 > y2 then y1, y2 = y2, y1 end
			for y = y1, y2, pass_tile do
				pass_grid:set(x1 / const.PassTileSize, y / const.PassTileSize, 1)
				--Visualize(point(x1, y) + half_tile)
			end
		elseif y1 == y2 then
			if x1 > x2 then x1, x2 = x2, x1 end
			for x = x1, x2, pass_tile do
				pass_grid:set(x / const.PassTileSize, y1 / const.PassTileSize, 1)
				--Visualize(point(x, y1) + half_tile)
			end
		elseif x1 + y1 == x2 + y2 then
			if x1 > x2 then x1, x2 = x2, x1 end
			for x = x1, x2, pass_tile do
				pass_grid:set(x / const.PassTileSize, (y1 - x + x1) / const.PassTileSize, 1)
				--Visualize(point(x, y1 - x + x1) + half_tile)
			end
		elseif x1 - y1 == x2 - y2 then
			if x1 > x2 then x1, x2 = x2, x1 end
			for x = x1, x2, pass_tile do
				pass_grid:set(x / const.PassTileSize, (y1 + x - x1) / const.PassTileSize, 1)
				--Visualize(point(x, y1 + x - x1) + half_tile)
			end
		end
	end)
	
	return pass_grid
end

local covers_ids = { false, false, false, false }
covers_ids[const.CoverLow] = true
covers_ids[const.CoverHigh] = true

function CheckPassInFrontOfCovers(bbox)
	bbox = bbox and bbox:grow(const.SlabSizeX) or sizebox(point20, terrain.GetMapSize())
	bbox = box(bbox:min():SetInvalidZ(), bbox:max():SetInvalidZ())
	
	local sizex, sizey = terrain.GetMapSize()
	sizex, sizey = sizex / const.PassTileSize, sizey / const.PassTileSize
	local grid = NewGrid(sizex, sizey, 1, 0)
	
	PauseInfiniteLoopDetection("CheckPassInFrontOfCovers")
	
	local pass_tile = const.PassTileSize
	local pass_grid = ConstructPassability(bbox)
	local is_passable = function(x, y)
		return pass_grid:get((x - pass_tile / 2) / pass_tile, (y - pass_tile / 2) / pass_tile) == 1
	end

	ForEachCover(bbox, -1, function(x, y, z, up, right, down, left)
		up = covers_ids[up]
		right = covers_ids[right]
		down = covers_ids[down]
		left = covers_ids[left]
		
		local function has_cover(xoffs, yoffs, dir)
			local u, r, d, l = GetCover(x + xoffs * const.SlabSizeX, y + yoffs * const.SlabSizeY, z)
			if not u then return end
			if dir == "up" then
				return covers_ids[u]
			elseif	dir == "right" then
				return covers_ids[r]
			elseif	dir == "down" then
				return covers_ids[d]
			elseif	dir == "left" then
				return covers_ids[l]
			end
		end
		
		local pass_tile = const.PassTileSize
		local xp, yp = x / pass_tile, y / pass_tile
		if up or down then
			grid:set(xp, yp, 1)
			if up then 
				local yoffs, dir = -1, "up"
				if not left then
					local l2, l1 = has_cover(-1, yoffs, "right"), has_cover(-1, 0, dir)
					if l2       then grid:set(xp - 2, yp, 1) end
					if l2 or l1 then grid:set(xp - 1, yp, 1) end
				end
				if not right then
					local r1, r2 = has_cover(1, 0, dir), has_cover(1, yoffs, "left")
					if r2 or r1 then grid:set(xp + 1, yp, 1) end
					if r2       then grid:set(xp + 2, yp, 1) end
				end
			end
			if down then 
				local yoffs, dir = 1, "down"
				if not left then
					local l2, l1 = has_cover(-1, yoffs, "right"), has_cover(-1, 0, dir)
					if l2       then grid:set(xp - 2, yp, 1) end
					if l2 or l1 then grid:set(xp - 1, yp, 1) end
				end
				if not right then
					local r1, r2 = has_cover(1, 0, dir), has_cover(1, yoffs, "left")
					if r2 or r1 then grid:set(xp + 1, yp, 1) end
					if r2       then grid:set(xp + 2, yp, 1) end
				end
			end
		end
		if right or left then
			grid:set(xp, yp, 1)
			if right then
				local xoffs, dir = 1, "right"
				if not up then
					local u2, u1 = has_cover(xoffs, -1, "down"), has_cover(0, -1, dir)
					if u2       then grid:set(xp, yp - 2, 1) end
					if u2 or u1 then grid:set(xp, yp - 1, 1) end
				end
				if not down then
					local d1, d2 = has_cover(0, 1, dir), has_cover(xoffs, 1, "up")
					if d2 or d1 then grid:set(xp, yp + 1, 1) end
					if d2       then grid:set(xp, yp + 2, 1) end
				end
			end
			if left then
				local xoffs, dir = -1, "left"
				local u2, u1 = has_cover(xoffs, -1, "down"), has_cover(0, -1, dir)
				if not up then
					if u2       then grid:set(xp, yp - 2, 1) end
					if u2 or u1 then grid:set(xp, yp - 1, 1) end
				end
				if not down then
					local d1, d2 = has_cover(0, 1, dir), has_cover(xoffs, 1, "up")
					if d2 or d1 then grid:set(xp, yp + 1, 1) end
					if d2       then grid:set(xp, yp + 2, 1) end
				end
			end
		end
	end)
	
	local pass_tile = const.PassTileSize
	local pass_size = point(pass_tile, pass_tile, 30 * guic)
	local mask_any = const.cmObstruction + const.cmPassability
	
	local shrink = 15 * guic
	local shrink_offs = point(shrink, shrink, 0)
	local shrink_size = pass_size - 2 * shrink_offs
	local function has_tall_obstacle(pos)
		local count = 0
		for i = 2, 5 do
			local bbox = sizebox(pos + shrink_offs + i * point(0, 0, 30 * guic), shrink_size)
			local collide = collision.Collide(bbox, point30, const.cqfSingleResult, 0, mask_any, empty_func) > 0
			count = count + (collide and 1 or 0)
		end
		return count >= 2
	end
	
	local function guess_intended_blockers(pos)
		local shrink = 12 * guic
		local shrink_offs = point(shrink, shrink, 0)
		local shrink_size = pass_size - 2 * shrink_offs
		local shrinked_box = sizebox(pos + shrink_offs + point(0, 0, 15 * guic), shrink_size)
		if collision.Collide(shrinked_box, point30, const.cqfSingleResult, 0, mask_any, empty_func) == 0 then
			return false
		end
	
		-- find colliding objects at least 15 cm above the ground level
		local objs = {}
		local bbox
		local collide_box = sizebox(pos + point(0, 0, 15 * guic), pass_size:SetZ(120 * guic))
		collision.Collide(collide_box, point30, 0, 0, mask_any, function(obj)
			local obj_box = obj:GetObjectBBox()
			bbox = bbox and Extend(bbox, obj_box) or obj_box
			objs[obj] = obj:GetApplyToGrids()
		end)
		
		if not bbox then return false end
		
		bbox = box(
			(bbox:minx() + pass_tile / 2) / pass_tile * pass_tile,
			(bbox:miny() + pass_tile / 2) / pass_tile * pass_tile,
			bbox:minz(),
			(bbox:maxx() + pass_tile / 2) / pass_tile * pass_tile,
			(bbox:maxy() + pass_tile / 2) / pass_tile * pass_tile,
			bbox:maxz()
		)
		
		-- does turning off ApplyToGrids only remove problematic tiles as per this logic?
		local old = g_dbgCoversShown
		g_dbgCoversShown = false
		
		-- remember old impassable
		local old_impass = {}
		for x = bbox:minx(), bbox:maxx(), pass_tile do
			for y = bbox:miny(), bbox:maxy(), pass_tile do
				if not terrain.IsPassable(x, y) then
					old_impass[x * 4000000 + y] = true
				end
			end
		end
		
		-- stop applying to grids
		SuspendPassEdits("guess_intended_blockers")
		for obj in pairs(objs) do
			obj:SetApplyToGrids(false)
		end
		ResumePassEdits("guess_intended_blockers")
		
		local ret = true
		for x = bbox:minx(), bbox:maxx(), pass_tile do
			for y = bbox:miny(), bbox:maxy(), pass_tile do
				local pos = point(x, y)
				if old_impass[x * 4000000 + y] and terrain.IsPassable(x, y) and grid:get(x / pass_tile, y / pass_tile) == 0 then
					ret = false
				end
			end
		end
		
		-- restore grids
		SuspendPassEdits("guess_intended_blockers")
		for obj, value in pairs(objs) do
			obj:SetApplyToGrids(value)
		end
		ResumePassEdits("guess_intended_blockers")
		
		g_dbgCoversShown = old
		return ret
	end
	
	local half_tile = point(pass_tile / 2, pass_tile / 2)
	for x = bbox:minx() / const.SlabSizeX, bbox:maxx() / const.SlabSizeX do
		for y = bbox:miny() / const.SlabSizeY, bbox:maxy() / const.SlabSizeY do
			if grid:get(x, y) == 1 then
				local pos = point(x * pass_tile, y * pass_tile)
				if not is_passable(pos:x(), pos:y()) then
					pos = pos - half_tile
					pos = pos:SetTerrainZ()
					if not has_tall_obstacle(pos) and (not XEditorSettings:GetGuessIntendedBlockers() or not guess_intended_blockers(pos)) then
						g_ZuluMapValidationBoxes[#g_ZuluMapValidationBoxes + 1] = PlaceBox(sizebox(pos, pass_size), RGB(255, 0, 0), false, true)
						for i = 2, 5 do
							local bbox = sizebox(pos + shrink_offs + i * point(0, 0, 30 * guic), shrink_size)
							g_ZuluMapValidationBoxes[#g_ZuluMapValidationBoxes + 1] = PlaceBox(bbox, RGB(255, 255, 0), false, true)
						end
					end
				end
			end
		end
	end
	
	ResumeInfiniteLoopDetection("CheckPassInFrontOfCovers")
	grid:free()
	pass_grid:free()
end

function ForEachMercPosition(bbox, callback, voxel_filter)
	local had_box = bbox
	bbox = bbox and bbox:grow(const.SlabSizeX) or sizebox(point20, terrain.GetMapSize())
	
	PauseInfiniteLoopDetection("CheckPartiallyPassableTiles")
	
	local pass_tile = const.PassTileSize
	local pass_grid = ConstructPassability(bbox)
	local is_passable = function(x, y)
		return pass_grid:get((x - pass_tile / 2) / pass_tile, (y - pass_tile / 2) / pass_tile) == 1
	end

	local offs = point(0, 0, 0 * guic)
	local check_free_space = function(x, y, merc_size)
		local x_step = (const.SlabSizeX - merc_size:x()) / 2
		local y_step = (const.SlabSizeY - merc_size:y()) / 2
		for xo = 0, x_step * 2, x_step do
			for yo = 0, y_step * 2, y_step do
				local pos = point(x + xo, y + yo)
				pos = pos:SetTerrainZ() + offs
				callback(sizebox(pos, merc_size))
			end
		end
	end
	
	voxel_filter = voxel_filter or function() return true end
	for x = bbox:minx(), bbox:maxx(), const.SlabSizeX do
		for y = bbox:miny(), bbox:maxy(), const.SlabSizeY do
			if voxel_filter(x, y, is_passable) then
				check_free_space(x, y, merc_size1)
				check_free_space(x, y, merc_size2)
			end
		end
	end
	
	ResumeInfiniteLoopDetection("CheckPartiallyPassableTiles")
	pass_grid:free()
end

function CheckPartiallyPassableTiles(bbox)
	local bush_size = 10*guim
	local bush_grow, bush_grow_z = -10*guic, 100*guic
	
	local box_size = point(const.SlabSizeX + 40 * guic, const.SlabSizeY + 40 * guic, 150 * guic)
	local offs = point(-20 * guic, -20 * guic, 30 * guic)
	local voxel_has_passable = function(x, y, is_passable)
		local s = const.PassTileSize
		return is_passable(x - s, y - s) or is_passable(x - s, y) or is_passable(x - s, y + s) or
		       is_passable(x    , y - s) or is_passable(x    , y) or is_passable(x    , y + s) or
		       is_passable(x + s, y - s) or is_passable(x + s, y) or is_passable(x + s, y + s)
	end
	
	local mask_any = const.cmObstruction + const.cmPassability
	ForEachMercPosition(bbox,
		function(merc_box)
			if collision.Collide(merc_box, point30, const.cqfSingleResult, 0, mask_any, empty_func) == 0 then
				if not XEditorSettings:GetIgnoreBushFilledAreas() or 
				   MapCount(merc_box:grow(bush_size), function(obj)
						local data = EntityData[obj:GetEntity()] or empty_table
						return data.editor_subcategory == "Bush" and
							obj:GetObjectBBox():grow(bush_grow, bush_grow, bush_grow_z):Intersect(merc_box) == const.irInside
				   end) == 0
				then
					g_ZuluMapValidationBoxes[#g_ZuluMapValidationBoxes + 1] = PlaceBox(merc_box, RGB(255, 255, 0), false, true)
				end
			end
		end,
		function(x, y, is_passable)
			local xv, yv = x + const.SlabSizeX / 2, y + const.SlabSizeY / 2
			return not is_passable(xv, yv) and voxel_has_passable(xv, yv, is_passable) and
			   not (XEditorSettings:GetIgnoreEmptySpaces() and
			   collision.Collide(sizebox(point(x, y):SetTerrainZ() + offs, box_size), point30, const.cqfSingleResult, 0, mask_any, empty_func) == 0)
		end
	)
end

function ValidateMap(bbox)
	ClearValidationBoxes(bbox)
	if g_dbgCoversShown then
		if XEditorSettings:GetDetectGaps() then
			CheckPartiallyPassableTiles(bbox)
		end
		if XEditorSettings:GetCoverPass() then
			CheckPassInFrontOfCovers(bbox)
		end
	end
end

function OnMsg.DbgCoversUpdated(bbox) CreateRealTimeThread(ValidateMap, bbox) end


----- Settings

table.iappend(XEditorSettings.properties, {
	{ category = "Voxel validation", id = "DetectGaps", name = "Detect gaps", editor = "bool", default = false },
	{ category = "Voxel validation", id = "IgnoreEmptySpaces", name = "Ignore empty spaces", editor = "bool", default = true,
		read_only = function(self) return not self:GetDetectGaps() end,
	},
	{ category = "Voxel validation", id = "IgnoreBushFilledAreas", name = "Ignore bush-filled areas", editor = "bool", default = true,
		read_only = function(self) return not self:GetDetectGaps() end,
	},
	{ category = "Voxel validation", id = "CoverPass", name = "Check cover passability", editor = "bool", default = false },
	{ category = "Voxel validation", id = "GuessIntendedBlockers", name = "Guess intended blockers", editor = "bool", default = false,
		read_only = function(self) return not self:GetCoverPass() end,
	},
})

function OnMsg.EditorSettingChanged(setting, value)
	if (setting == "DetectGaps" or setting == "CoverPass") and value and not g_dbgCoversShown then
		DbgDrawCovers()
		return
	end
	if XEditorSettings:GetPropertyMetadata(setting).category == "Passability validation" then
		ValidateMap()
	end
end


----- Auto-adjustment

g_DebugBoxes = rawget(_G, "g_DebugBoxes") or {}
function OnMsg.ChangeMap()
	g_DebugBoxes = {}
end

-- tries to move and/or rotate the object according to editor settings, trying to leave no gaps around it
function AdjustSelectionToVoxels(adjust_angle)
	for _, obj in ipairs(g_DebugBoxes) do
		obj:delete()
	end
	g_DebugBoxes = {}
	
	local PlaceBox = empty_func
	
	-- some variables
	local objs = editor.GetSel()
	local bbox = GetObjectsBBox(objs)
	local slab_size = const.SlabSizeX
	local pass_size = const.PassTileSize
	local vsize = point(slab_size, slab_size, 150 * guic)
	local psize = point(pass_size, pass_size, 150 * guic)
	local tolerance = 27
	local ptolerance = tolerance * point(guic, guic, guic)
	local voffs = (vsize - psize) / 2
	local mask_any = const.cmObstruction + const.cmPassability
	
	if bbox:IsEmpty() then return end
	if bbox:sizex() > 120 * guim or bbox:sizey() > 120 * guim then
		print("<color 255 0 0>Objects to adjust cover a too large area.</color>")
		return
	end
	
	-- gather all "passable" tiles around the objects that we should try to keep free
	local free_map = {} -- indexed by x * 4000000 + y
	local p = function(x, y) return x * 4000000 + y end
	
	-- add the contours of impassable voxels, we should keep those "passable"
	local valign = function(x) return x / slab_size * slab_size end
	for x = valign(bbox:minx()), valign(bbox:maxx()), slab_size do
		for y = valign(bbox:miny()), valign(bbox:maxy()), slab_size do
			local pos = point(x, y):SetTerrainZ()
			local vbox = sizebox(pos, vsize - 2 * voffs - ptolerance) + voffs + ptolerance / 2
			local collision = collision.Collide(vbox, point30, const.cqfSingleResult, 0, mask_any, empty_func) > 0
			if collision then
				local s, s2 = pass_size, pass_size * 2
				free_map[p(x + s2, y + s2)] = true
				free_map[p(x + s2, y + s )] = true
				free_map[p(x + s2, y     )] = true
				free_map[p(x + s2, y - s )] = true
				free_map[p(x + s2, y - s2)] = true
				free_map[p(x + s , y + s2)] = true
				free_map[p(x     , y + s2)] = true
				free_map[p(x - s , y + s2)] = true
				free_map[p(x + s , y - s2)] = true
				free_map[p(x     , y - s2)] = true
				free_map[p(x - s , y - s2)] = true
				free_map[p(x - s2, y + s2)] = true
				free_map[p(x - s2, y + s )] = true
				free_map[p(x - s2, y     )] = true
				free_map[p(x - s2, y - s )] = true
				free_map[p(x - s2, y - s2)] = true
			end
		end
	end

	-- subtract from those the inside ones
	local valign = function(x) return x / slab_size * slab_size end
	for x = valign(bbox:minx()), valign(bbox:maxx()), slab_size do
		for y = valign(bbox:miny()), valign(bbox:maxy()), slab_size do
			local pos = point(x, y):SetTerrainZ()
			local vbox = sizebox(pos, vsize - 2 * voffs - ptolerance) + voffs + ptolerance / 2
			local collision = collision.Collide(vbox, point30, const.cqfSingleResult, 0, mask_any, empty_func) > 0
			if collision then
				local s = pass_size
				free_map[p(x    , y + s)] = nil
				free_map[p(x    , y    )] = nil
				free_map[p(x    , y - s)] = nil
				free_map[p(x + s, y + s)] = nil
				free_map[p(x + s, y    )] = nil
				free_map[p(x + s, y - s)] = nil
				free_map[p(x - s, y + s)] = nil
				free_map[p(x - s, y    )] = nil
				free_map[p(x - s, y - s)] = nil
			end
		end
	end
	
	-- assign boxes in place of true, debug display
	for k in pairs(free_map) do
		local x, y = k / 4000000, k % 4000000
		local pos = point(x, y):SetTerrainZ()
		local p31 = point(guic, guic, guic)
		for t = 0, tolerance do
			local ptolerance = p31 * t
			local vbox = sizebox(pos, psize - ptolerance) + psize:SetZ(0) / 2 + ptolerance / 2
			if collision.Collide(vbox, point30, const.cqfSingleResult, 0, mask_any, empty_func) == 0 then
				g_DebugBoxes[#g_DebugBoxes + 1] = PlaceBox(vbox, RGB(0, 255, 255), false, true)
				free_map[k] = vbox
				break
			end
		end
		if free_map[k] == true then
			free_map[k] = nil
		end
	end
	
	--VisualizeClear()
	
	-- gather all gaps that we strive to be filled
	local gaps = {}
	local palign = function(x) return x / pass_size * pass_size end
	local count = 0
	local aligned_box = box(valign(bbox:minx()) - slab_size, valign(bbox:miny()) - slab_size, valign(bbox:maxx()) + 2 * slab_size, valign(bbox:maxy()) + 2 * slab_size)
	g_DebugBoxes[#g_DebugBoxes + 1] = PlaceBox(aligned_box, RGB(255, 0, 0), false, true)
	ForEachMercPosition(aligned_box,
		function(merc_box)
			local found
			for x = palign(merc_box:minx()) - pass_size, palign(merc_box:maxx()) + pass_size, pass_size do
				for y = palign(merc_box:miny()) - pass_size, palign(merc_box:maxy()) + pass_size, pass_size do
					local pass = free_map[(x - pass_size) * 4000000 + y - pass_size]
					if pass then
						found = true
						break
					end
				end
			end
			if found then
				--g_DebugBoxes[#g_DebugBoxes + 1] = PlaceBox(merc_box:grow(-30*guic), RGB(255, 0, 0), false, true)
				gaps[#gaps + 1] = merc_box
			end
		end,
		function(x, y, is_passable) 
			x, y = x / slab_size * slab_size, y / slab_size * slab_size
			local pos = point(x, y):SetTerrainZ()
			local vbox = sizebox(pos, vsize - 2 * voffs - ptolerance) + voffs + ptolerance / 2
			return collision.Collide(vbox, point30, const.cqfSingleResult, 0, mask_any, empty_func) > 0
		end
	)
	
	print("Number of gaps:", #gaps)
	print("Number of pass tiles:", #table.keys(free_map))
	
	-- start iterating & evaluating the best object position
	SuspendPassEdits("AdjustSelectionToVoxels")
	PauseInfiniteLoopDetection("AdjustSelectionToVoxels")
	XEditorUndo:BeginOp{ objects = objs, name = string.format("Adjusted %d objects to voxels", #objs) }
	
	local function GetOrgPositions(objs)
		local ret = {}
		for _, obj in ipairs(objs) do
			ret[#ret + 1] = { pos = obj:GetPos(), angle = obj:GetAngle(), axis = obj:GetAxis(), scale = obj:GetScale() }
		end
		ret.center = CenterOfMasses(objs)
		return ret
	end
	
	local function SetNewRelPos(objs, orgp, x, y, angle, scale)
		local offs = point(x, y, 0)
		for i, obj in ipairs(objs) do
			local data = orgp[i]
			local scale2 = MulDivRound(data.scale, scale, 100)
			local rotate_offs = RotateAxis(data.pos - orgp.center, axis_z, angle)
			if rotate_offs:Len() > 0 then
				obj:SetPos(orgp.center + SetLen(rotate_offs, MulDivRound(rotate_offs:Len(), scale2, 100)) + offs)
			else
				obj:SetPos(orgp.center + offs)
			end
			obj:SetAxisAngle(ComposeRotation(data.axis, data.angle, axis_z, angle))
			obj:SetScale(scale2)
		end
	end
	
	local function EvaluateScore(action, init_gaps, init_pass)
		local score = 0
		--local PlaceBox = _G["PlaceBox"]
		for idx, gap in ipairs(gaps) do
			--local shrink = 2
			local scores = { [0] = 16, [1] = 4, [2] = 1 }
			for shrink = 0, 2 do
				local b, key = gap:grow(-shrink * 9 * guic), idx * 3 + shrink
				local collision = collision.Collide(b, point30, const.cqfSingleResult, 0, mask_any, empty_func) > 0
				if action == "store" then
					init_gaps[key] = collision
				elseif action == "show" and init_gaps[key] ~= collision then
					local color = collision and RGB(0, 255, 0) or RGB(255, 0, 0)
					g_DebugBoxes[#g_DebugBoxes + 1] = PlaceBox(b:grow(3 *guic), color, false, false)
				end
				score = score + (collision and scores[shrink] or 0) -- closed gaps
			end
		end
		for key, b in pairs(free_map) do
			local collision = collision.Collide(b, point30, const.cqfSingleResult, 0, mask_any, empty_func) > 0
			if action == "store" then
				init_pass[key] = collision
			elseif action == "show" and init_pass[key] ~= collision then
				local color = (not collision) and RGB(0, 255, 0) or RGB(255, 0, 0)
				g_DebugBoxes[#g_DebugBoxes + 1] = PlaceBox(b:grow(3 *guic), color, false, false)
			end
			score = score + (collision and -900 or 0) -- tresspassed passability
		end
		return score
	end
	
	local init_gaps, init_pass = {}, {}
	local base_score = EvaluateScore("store", init_gaps, init_pass)
	
	local pos_step, pos_max = 15 * guic, 40 * guic -- 10 * guic, 50 * guic
	local ang_step, ang_max = 8 * 60, 16 * 60
	local scale_to_max = Min(MulDivRound(bbox:sizex() + pos_max, 100, bbox:sizex()), MulDivRound(bbox:sizey() + pos_max, 100, bbox:sizey())) - 100
	local scl_step, scl_max = scale_to_max / 5, scale_to_max
	local time = GetPreciseTicks()
	local orgp = GetOrgPositions(objs)
	local best = { x = 0, y = 0, angle = 0, scale = 100 }
	local best_score, best_dist = 0, 100 * guim
	for x = -pos_max, pos_max, pos_step do
		for y = -pos_max, pos_max, pos_step do
			local angle, scale = 0, 100
			--for angle = -ang_max, ang_max, ang_step do
				--for scale = 100, 100 + scl_max, scl_step do
					SetNewRelPos(objs, orgp, x, y, angle, scale)
					local score, dist = EvaluateScore(), x*x + y*y + angle * angle + scale * scale
					if score > best_score or score == best_score and dist < best_dist then
						best.x, best.y, best.angle, best.scale = x, y, angle, scale
						best_score, best_dist = score, dist
					end
				--end
			--end
		end
	end
	
	print("Best score/dist:", base_score - best_score, sqrt(best_dist) / guic, "cm")
	print("Time taken", GetPreciseTicks() - time, "ms")
	SetNewRelPos(objs, orgp, best.x, best.y, best.angle, best.scale)
	EvaluateScore("show", init_gaps, init_pass)
	
	XEditorUndo:EndOp(objs)
	ResumeInfiniteLoopDetection("AdjustSelectionToVoxels")
	ResumePassEdits("AdjustSelectionToVoxels")
end
