if Platform.cmdline then return end

if FirstLoad then
	g_DebugWindDraw = false
	g_DebugWindTexts = false
	g_DebugWindTiles = false
end

function OnMsg.NewMapLoaded()
	g_DebugWindDraw = false
	g_DebugWindTexts = false
	g_DebugWindTiles = false
end

function DbgDrawWind(show, show_texts, show_tiles_around_cursor)
	g_DebugWindDraw = not not show
	g_DebugWindTexts = not not show_texts
	g_DebugWindTiles = not not show_tiles_around_cursor
	DbgClearVectors()
	DbgClearTexts()
	if not show then
		return
	end
	
	local width, height = terrain.GetMapSize()
	local wind_tile_size = const.WindTileSize
	local wind_half_tile_size = wind_tile_size / 2
	local end_x = width / wind_tile_size * wind_tile_size
	local end_y = height / wind_tile_size * wind_tile_size
	local cursor = show_tiles_around_cursor and GetTerrainCursor()
	for j = 0, end_y, wind_tile_size do
		for i = 0, end_x, wind_tile_size do
			local pos = point(i + wind_half_tile_size, j + wind_half_tile_size)
			pos = pos:SetZ(terrain.GetHeight(pos) + 5 * guim)
			local dir = terrain.GetWindDirection(pos):SetZ(0)
			if dir:Len2D2() > 0 then
				local strength = dir:Len2D()
				local color = GetWindColorCode(strength, const.WindMaxStrength)
				DbgAddVector(pos - dir / 2, dir, color)
				if show_texts then
					DbgAddText(strength, pos, color)
				end
				if show_tiles_around_cursor then
					local pt1 = point(i, j)
					local pt2 = point(i + wind_tile_size - 1, j + wind_tile_size - 1)
					local center = (pt1 + pt2) / 2
					if center:Dist2D(cursor) < 30 * guim then
						local z = terrain.GetHeight(center) + 4 * guim
						local tile_box = box(pt1:SetZ(z), pt2:SetZ(z))
						DbgAddBox(tile_box, color)
					end
				end
			end
		end
	end
end

function OnMsg.WindMarkersApplied()
	if g_DebugWindDraw then
		DbgDrawWind(g_DebugWindDraw, g_DebugWindTexts, g_DebugWindTiles)
	end
end
