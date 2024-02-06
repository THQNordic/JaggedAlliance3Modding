--- Misc functions - entities, particles, debug, engine settings.

--- Return the object under the mouse cursor.
-- @cstyle void tco().
-- @return object.

function tco()
end

--- Removes all game objects from the current map.
-- @cstyle void ClearObjects().
-- @return void.

function ClearObjects()
end

--- Returns whether an entity with the specified name exists and can be loaded.
-- @cstyle bool IsValidEntity(string entity).
-- @param entity string.
-- @return boolean.

function IsValidEntity(entity)
end

--- Returns a table containing all states of the specified entity.
-- @cstyle string GetStates(string entity|object).
-- @param entity string or object.
-- @return table(string).

function GetStates(entity)
end

--- Returns the name of the state associated with the specified integer.
-- @cstyle string GetStateName(int state).
-- @param state int.
-- @return string.

function GetStateName(state)
end

--- Returns the formatted (esSomething) name of the state associated with the specified integer.
-- @cstyle string GetStateNameFormat(int state).
-- @param state int.
-- @return string.

function GetStateNameFormat(state)
end

--- Returns the index of the state with the given name.
-- @cstyle int GetStateIdx(string state).
-- @param state string.
-- @return int.

function GetStateIdx(state)
end

--- Reloads particle system descriptions; changes parameters of currently running particle systems.
-- @cstyle void ParticlesReload().
-- @return void.

function ParticlesReload()
end

--- Places a particle system of type filename in point pt.
-- @cstyle void ParticlePlace(string filename, point pt).
-- @param filename string.
-- @param pt point.
-- @return void.

function ParticlePlace(filename, pt)
end

--- Performs subpixel shifting of the rendered image, in the x and y directions. One whole pixel is 1000.
-- @cstyle void SetCameraOffset(int x, int y).
-- @param x int.
-- @param y int.
-- @return void.

function SetCameraOffset(x, y)
end

--- Returns the point on the terrain where the mouse cursor points currently. Only works when RTS camera is active.
-- @cstyle point GetTerrainCursor().
-- @return point.

function GetTerrainCursor()
end

--- Returns the closest selectable object to the specified screen position or to the current position of the terrain cursor.
-- Only works when RTS camera is active.
-- @cstyle object GetTerrainCursorObjSel(point screen_pos = nil).
-- @return object.

function GetTerrainCursorObjSel(screen_pos)
end

--- Returns the closest object to the specified screen position or to the current position of the terrain cursor.
-- The objects which are tested are from the specified list.
-- Only works when RTS camera is active.
-- @cstyle object GetTerrainCursorObjSel(point screen_pos, objlist objects_to_test, bool test_walkables).
-- @return object.

function GetCursorObjSel(screen_pos, objects_to_test, test_walkables)
end

--- Returns the closest object to the specified screen position or to the current position of the terrain cursor.
-- Only works when RTS camera is active.
-- @cstyle object GetTerrainCursorObj(point screen_pos = nil).
-- @return object.

function GetTerrainCursorObj(screen_pos)
end

--- Returns the map file path.
-- @cstyle string GetMapPath().
-- @return string.

function GetMapPath()
end

--- Returns a table with all existing entities.
-- @cstyle table GetAllEntities().
-- @return table; Integer indexed table with all entities.

function GetAllEntities()
end

--- Returns the the maximum (bounding) surface box of all surface rects in all entities.
-- @cstyle box GetEntityMaxSurfacesBox().
-- @return box.

function GetEntityMaxSurfacesBox()
end

--- Returns the the maximum (bounding) surface radius of all surface rects in all entities.
-- @cstyle box GetEntityMaxSurfacesRadius().
-- @return int.

function GetEntityMaxSurfacesRadius()
end

--- Returns the the maximum radius of all objects on the map (cached).
-- @cstyle box GetMapMaxObjRadius().
-- @return int.

function GetMapMaxObjRadius()
end

--- Return the entity animation speed modifier as a percent.
-- Affects both animation duration and action moment!.
-- @cstyle int GetStateSpeedModifier(string entity, int state).
-- @param entity string.
-- @param state int.
-- @return int.

function GetStateSpeedModifier(entity, state)
end

--- Set new animation speed modifier, as percents of original animation duration.
-- Animation duration and action moment times are affected by that modifier!.
-- @cstyle void SetStateSpeedModifier(entity, state, int modifier).
-- @param modifier int; new speed modifier.
-- @return void.

function SetStateSpeedModifier(modifier)
end

--- Changes the specified postprocess parameter smoothly over the given time.
-- @cstyle void SetPostProcessingParam(int param, int value, int time = 0).
-- @param param integer; the parameter to change (currently valid are indexes 0-3).
-- @param value integer; the new value.
-- @param time integer; if omitted defaults to 0.
-- @return void.

function SetPostProcessingParam(param, value, time)
end

--- Returns the current value of the specifcied post-processing parameter.
-- @cstyle int GetPostProcessingParam(int param).
-- @param param integer; the parameter index (currently valid are indexes 0-3).
function GetPostProcessingParam(param)
end

--- Sets the value of given post-processing predicate.
-- @cstyle void SetPostProcPredicate(string name, int value)
-- @param name string; the name of the predicate to set.
-- @param value int; the value to set (0 - disabled, 1 - enabled)
-- @return void
function SetPostProcPredicate(name, value)
end

--- Return a suitable random spot in circle area where an object from the given class can be placed.
-- The spot will be passable and on the terrain, and it will be far enough from all objects in ol.
-- @cstyle point GetSummonPt(objlist ol, point ptCenter, int nAreaRadius, string pchClass, int nRadius, int nTries).
-- @param ol objlist; list with obstacle objects to consider.
-- @param ptCenter point; the center of the area.
-- @param nAreaRadius integer; the radius of the area.
-- @param pchClass string; the class of the object to place.
-- @param nRadius integer; the radius of the object to place.
-- @param nTries integer; number of random spot to try before the function gives up.
-- @return point; Can be nil if no spot was found.
function GetSummonPt(ol, ptCenter, nAreaRadius, pchClass, nRadius, nTries)
end

--- Returns the application id, as used to create folders under Application Data and registry entries
-- @cstyle string GetAppName()
-- @return appname string; the application name
function GetAppName()
end

--- Returns all state moments for specific entity/state.
-- It is supposed to be used only when quering moments embeded in the entity XML itself, otherwise AnimMoments is the easier way to access that data.
-- @cstyle vector<momemt> GetStateMoments(entity/object, state).
-- @param entity; entity in the game or game object.
-- @param state; state in that entity.
-- @return table; a vector containng all the moments for that entity/state in the form {type = string, time = int}.
function GetStateMoments(entity, state)
end

--- Returns a convex polygon containing the provided array of points.
-- @cstyle vector<point> ConvexHull2D(point* points, int border = 0).
-- @param points; array with points or game objects.
-- @param border; the border with which to offset to obtained convex polygon.
-- @return table; a vector containng the points of the convex polygon
function ConvexHull2D(points, border)
end

--- Gets the bbox formed by the requested surfaces.
-- @cstyle box, int GetEntitySurfacesBBox(string entity, int request_surfaces = -1, int fallback_surfaces = 0, int state_idx = 0)
-- @param request_surfaces int; the requested surfaces (e.g. EntitySurfaces.Selection + EntitySurfaces.Build). By default (-1) all surfaces are requested.
-- @param fallback_surfaces int; fallback case if the requested surfaces are missing. By default (0) no falllback will be matched.
-- @param state_idx int; the entity state, 0 by default (Idle).
-- @return box; the resulting bounding box
-- @return int; the matched surface flags
function GetEntitySurfacesBBox(entity, request_surfaces, fallback_surfaces, state_idx)
end

--- Creates a new empty table and pushes it onto the stack. Parameter narr is a hint for how many elements the table will have as a sequence; parameter nrec is a hint for how many other elements the table will have.
function createtable(narr, nrec)
end

