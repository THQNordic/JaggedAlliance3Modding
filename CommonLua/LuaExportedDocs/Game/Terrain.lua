--- Terrain functions.
-- Most functions dealing with terrain have something to do with the editor, which is written in Lua.
-- The functions you will generally use from here are the ones for getting terrain height, terrain surface height.
-- Also see the 'terrain.IsPointInBounds' function.
-- Each project can have different game units. The guim constant contains the number of game units in one meter.

--- Returns true if the point is in the terrain bounds.
-- @cstyle bool terrain.IsPointInBounds(point pos).
-- @param pos point; the point to be checked.
-- @return bool; true if the point is in terrain bounds, false otherwise.

function terrain.IsPointInBounds(pos, border)
end

--- Clamp a position with the map bounding box.
-- @cstyle int terrain.ClampPoint(point pos, int border = 0).
-- @param pos point; point to clamp.
-- @param border int; map border width (optional).
-- @return pos; the clamped position.

function terrain.ClampPoint(pos, border)
end

function terrain.ClampBox(box, border)
end

function terrain.ClampVector(ptFrom, ptTo)
end

function terrain.IsMapBox(box)
end

--- Returns true if the point is passable.
-- @cstyle bool terrain.IsPassable(point pos).
-- @param pos point; Map position to be checked for passability.
-- @return bool; true if the point is passable, false otherwise.

function terrain.IsPassable(pos)
end

--- Check passability in a radius around a point
-- @cstyle bool terrain.CirclePassable(point center, int radius, int pfclass).
-- @cstyle bool terrain.CirclePassable(object obj, int radius).
function terrain.CirclePassable(center, radius, pfclass) end
function terrain.CirclePassable(x, y, z, radius, pfclass) end
function terrain.CirclePassable(obj, radius) end


--- Check if a certain number of tiles are passable, starting from a given position
function terrain.AreaPassable(pos, area, pfclass, avoid_tunnels) end
function terrain.AreaPassable(x, y, z, area, pfclass, avoid_tunnels) end
function terrain.AreaPassable(obj, area, avoid_tunnels) end

--- Search a position with enough connected passable tiles, starting from a given position
function terrain.FindAreaPassable(pos, area, radius, pfclass, avoid_tunnels, destlock_radius, filter, ...) end
function terrain.FindAreaPassable(pos, obj, area, radius, avoid_tunnels, can_destlock, filter, ...) end
function terrain.FindAreaPassable(x, y, z, area, radius, pfclass, avoid_tunnels, destlock_radius, filter, ...) end
function terrain.FindAreaPassable(x, y, z, obj, area, radius, avoid_tunnels, can_destlock, filter, ...) end
function terrain.FindAreaPassable(obj, area, radius, avoid_tunnels, can_destlock, filter, ...) end

--- Returns whether the terrain at the given point is vertical.
-- @cstyle bool terrain.IsVerticalTerrain(point pt).
-- @param pt point; map position to be checked.
-- @return bool; true if the terrain point is vertical, false otherwise.

function terrain.IsVerticalTerrain(pt)
end

--- Returns the terrain type at the given map position.
-- @cstyle int terrain.GetTerrainType(point pt).
-- @param pt point.
-- @return int.

function terrain.GetTerrainType()
end

--- Sets the terrain type at the given map position.
-- @cstyle void terrain.SetTerrainType(point pt, int nType).
-- @param pt point.
-- @param type int.
-- @return void.

function terrain.SetTerrainType()
end

--- Returns the surface height (max from terrain height & water for now) at the specified position.
-- @cstyle int terrain.GetSurfaceHeight(point pos).
-- @param pos point; point for which to get the height.
-- @return int; the surface height.

function terrain.GetSurfaceHeight(pos)
end

--- Returns the height of the terrain in the specified position.
-- @cstyle int terrain.GetHeight(point pos).
-- @param pos point; point for which to get the height.
-- @return int; Return the height at the given point.

function terrain.GetHeight(pos)
end

function terrain.GetMinMaxHeight(box)
end

function terrain.FindPassable(pos, pfclass, radius, destlock_radius)
end
function terrain.FindPassable(x, y, z, pfclass, radius, destlock_radius)
end

function terrain.FindPassableZ(pos, pfclass, max_below, max_above)
end
function terrain.FindPassableZ(x, y, z, pfclass, max_below, max_above)
end

function terrain.FindReachable(start, mode, ...)
end

function terrain.FindPassableTile(pos, flags, ...)
end
function terrain.FindPassableTile(x, y, z, flags, ...)
end

--- Returns the normal to the terrain surface, with all components multiplied by 100.
-- @cstyle point terrain.GetSurfaceNormal(point pos).
-- @param pos point; Map position for which to get the surface normal.
-- @return point; The surface normal vector.

function terrain.GetSurfaceNormal(pos)
end

--- Returns the normal to the terrain, with all components multiplied by 100.
-- @cstyle point terrain.GetTerrainNormal(point pos).
-- @param pos point; Map position for which to get the terrain normal.
-- @return point; The terrain normal vector.

function terrain.GetTerrainNormal(pos)
end

--- Returns the size of the map (terrain) rectangle as two integers - sizex and sizey.
-- @cstyle int, int terrain.GetMapSize().
-- @return int, int; Returns the width, height.

function terrain.GetMapSize()
end

--- Returns the size of the grtass map recrangle as two integers - sizex and sizey.
-- @cstyle int, int terrain.GetGrassMapSize().
-- @return int, int; Returns the width, height.
function terrain.GetGrassMapSize()
end

--- Returns the map width/sizex.
-- @cstyle int terrain.GetMapWidth().
-- @return int.

function terrain.GetMapWidth()
end

--- Returns the map height/sizey.
-- @cstyle int terrain.GetMapHeight().
-- @return int.

function terrain.GetMapHeight()
end

--- Get the average height of the area determined by the circle(pos, radius). If no parameters are specified, works over the entire map.
-- @cstyle int terrain.GetAreaHeight(point pos, int radius).
-- @param pos point; center of the area.
-- @param radius int; radius of the area.
-- @return int; average height of the area.

function terrain.GetAreaHeight(pos, radius)
end

--- Sets the height of circle(center, innerRadius) to the specified and smoothly transforms the terrain between inner and outer circles (the terrain outside the outer circle preserves its height). Returns the changed box, empty box if nothing was changed.
-- @cstyle void terrain.SetHeightCircle(point center, int innerRadius, int outerRadius, int height).
-- @param center point; the circle center.
-- @param innerRadius int; the inner radius of the circle.
-- @param outerRadius int; the outer radius of the circle.
-- @param height int; the height to be set in the circle.
-- @return box.

function terrain.SetHeightCircle(center, innerRadius, outerRadius, height)
end

--- Smooths the terrain inside circle(center, radius) setting its height to the average height of the area.
-- @cstyle void terrain.SmoothHeightCircle(point center, int radius).
-- @param center int; the circle center.
-- @param radius int; radius of the circle.
-- @return void.

function terrain.SmoothHeightCircle(center, radius)
end

--- Calculates the height of the circular terrain(center, radius) and sets it to its average + heightdiff; Interpolates the terrain between inner and outer circles.
-- @cstyle void terrain.ChangeHeightCircle(point center, int innerRadius, int outerRadius, int heightdiff).
-- @param center point; out value: false.
-- @param innerRadius int; the inner radius of the circle.
-- @param outerRadius int; the outer radius of the circle.
-- @param heightdiff int; the height difference according to the average.
-- @return void.

function terrain.ChangeHeightCircle(center, innerRadius, outerRadius, heightdiff)
end

--- Sets the terrain texture inside the specified circle to type.
-- @cstyle void terrain.SetTypeCircle(point pos, int radius, int type).
-- @param pos point; center of the circle.
-- @param radius int; the circle radius.
-- @param type int; type of the texture to set.
-- @return void.

function terrain.SetTypeCircle(pos, radius, type)
end

--- Replaces the terrain texture inside the specified circle of type_old with to type_new.
-- @cstyle void terrain.SetTypeCircle(point pos, int radius, int type_old, int type_new).
-- @param pos point; center of the circle.
-- @param radius int; the circle radius.
-- @param type int; type of the texture to set.
-- @return void.

function terrain.ReplaceTypeCircle(pos, radius, type_old, type_new)
end

--- Returns the intersection of a segment with the terrain.
-- @cstyle point terrain.IntersectSegment(point pt1, point pt2).
-- @param pt1 point.
-- @param pt2 point.
-- @return point.

function terrain.IntersectSegment(pt1, pt2)
end

--- Returns the intersection of a ray with the terrain.
-- @cstyle point terrain.IntersectRay(point pt1, point pt2).
-- @param pt1 point.
-- @param pt2 point.
-- @return point.

function terrain.IntersectRay(pt1, pt2)
end

--- Scale the height of the terrain by a rational factor
-- @cstyle terrain.ScaleHeight(int mul, int div).
-- @param mul int; the numerator of the rational factor.
-- @param div int; the denominator of the rational factor.

function terrain.ScaleHeight(mul, div)
end

--- Remaps all the terrain indicies in the terrain data.
-- @cstyle void terrain.RemapType(map<int, int> remap).
-- @param remap; a map specifying remapping from terrain index to terrain index.
-- @return void.

function terrain.RemapType(remap)
end

--- Returns the current map heightfield as a grid. If the map is non-square and/or non-pow2, it is extended with 0.0f.
-- @cstyle grid GetHeightGrid().
-- @return heightfield grid; as grid.
function terrain.GetHeightGrid()
end

--- Returns the current map terrain type as a grid. If the map is non-square and/or non-pow2, it is extended with 0.0f.
-- @cstyle grid GetTerrainGrid().
-- @return terrain type grid; as grid.
function terrain.GetTypeGrid()
end
