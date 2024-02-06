----- Lua-defined saved in maps
--
-- To add a new grid that a part of the map data, call DefineMapGrid:
--  * the grid will be saved in the map folder if 'save_in_map' is true (otherwise, it gets recreated when the map changes)
--  * the OnMapGridChanged message is invoked when the grid is changed via the Map Editor

if FirstLoad then
	MapGridDefs = {}
end

function DefineMapGrid(name, bits, tile_size, patch_size, save_in_map)
	assert(type(bits) == "number" and type(tile_size) == "number" and tile_size >= 50*guic) -- just a reasonable tile size limit, feel free to lower
	MapGridDefs[name] = {
		bits = bits,
		tile_size = tile_size,
		patch_size = patch_size,
		save_in_map = save_in_map,
	}
end

function DefineMapHexGrid(name, bits, patch_size, save_in_map)
	assert(const.HexWidth)
	MapGridDefs[name] = {
		bits = bits,
		tile_size = const.HexWidth,
		patch_size = patch_size,
		save_in_map = save_in_map,
		hex_grid = true,
	}
end


----- Utilities

function MapGridTileSize(name)
	return MapGridDefs[name] and MapGridDefs[name].tile_size
end

function MapGridSize(name, mapdata)
	-- can't use GetMapBox, the realm might not have been created yet
	mapdata = mapdata or _G.mapdata
	local map_size = point(mapdata.Width - 1, mapdata.Height - 1) * const.HeightTileSize
	
	local data = MapGridDefs[name]
	local tile_size = data.tile_size
	if data.hex_grid then
		local tile_x = tile_size
		local tile_y = MulDivRound(tile_size, const.HexGridVerticalSpacing, const.HexWidth)
		local width  = (map_size:x() + tile_x - 1) / tile_x
		local height = (map_size:y() + tile_y - 1) / tile_y
		return point(width, height)
	end
	return map_size / tile_size
end

function MapGridWorldToStorageBox(name, bbox)
	if not bbox then
		return sizebox(point20, MapGridSize(name))
	end
	
	local data = MapGridDefs[name]
	if data.hex_grid then
		return HexWorldToStore(bbox)
	end
	return bbox / data.tile_size
end


---- Grid saving/loading with map

function OnMsg.MapFolderMounted(map, mapdata)
	for name, data in pairs(MapGridDefs) do
		if rawget(_G, name) then
			_G[name]:free()
		end
		
		local grid
		local filename = string.format("Maps/%s/%s", map, name:lower():gsub("grid", ".grid"))
		if data.save_in_map and io.exists(filename) then
			grid = GridReadFile(filename)
		else
			local width, height = MapGridSize(name, mapdata):xy()
			if data.patch_size then
				grid = NewHierarchicalGrid(width, height, data.patch_size, data.bits)
			else
				grid = NewGrid(width, height, data.bits)
			end
		end
		rawset(_G, name, grid)
	end
end

function OnMsg.SaveMap(folder)
	for name, data in pairs(MapGridDefs) do
		local filename = string.format("%s/%s", folder, name:lower():gsub("grid", ".grid"))
		if data.save_in_map and not _G[name]:equals(0) then
			GridWriteFile(_G[name], filename)
			SVNAddFile(filename)
		else
			SVNDeleteFile(filename)
		end
	end
end


----- Engine function overrides

if Platform.editor then

local old_GetGridNames = editor.GetGridNames
function editor.GetGridNames()
	local grids = old_GetGridNames()
	for name in sorted_pairs(MapGridDefs) do
		table.insert_unique(grids, name)
	end
	return grids
end

local old_GetGrid = editor.GetGrid
function editor.GetGrid(name, bbox, source_grid, mask_grid, mask_grid_tile_size)
	local data = MapGridDefs[name]
	if data then
		local bxgrid = MapGridWorldToStorageBox(name, bbox)
		local new_grid = _G[name]:new_instance(bxgrid:sizex(), bxgrid:sizey())
		new_grid:copyrect(_G[name], bxgrid, point20)
		return new_grid
	end
	return old_GetGrid(name, bbox, source_grid, mask_grid, mask_grid_tile_size)
end

local old_SetGrid = editor.SetGrid
function editor.SetGrid(name, source_grid, bbox, mask_grid, mask_grid_tile_size)
	local data = MapGridDefs[name]
	if data then
		local bxgrid = MapGridWorldToStorageBox(name, bbox)
		_G[name]:copyrect(source_grid, bxgrid - bxgrid:min(), bxgrid:min())
		DbgInvalidateTerrainOverlay(bbox)
		Msg("OnMapGridChanged", name, bbox)
		return
	end
	old_SetGrid(name, source_grid, bbox, mask_grid, mask_grid_tile_size)
end

local old_GetGridDifferenceBoxes = editor.GetGridDifferenceBoxes
function editor.GetGridDifferenceBoxes(name, grid1, grid2, bbox)
	local data = MapGridDefs[name]
	return old_GetGridDifferenceBoxes(name, grid1, grid2, bbox or empty_box, data and data.tile_size or 0)
end

end -- Platform.editor
