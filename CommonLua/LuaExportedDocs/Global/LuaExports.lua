--- Miscelanous functions : cursor, movies, maps and etc.

--- Crashes the 
-- @cstyle void Crash().
-- @return void.

function Crash()
end


--- Return the number of rendered frames so far.
-- @cstyle int GetFrameNo().
-- @return int.

function GetFrameNo()
end

--- Reset the memory stats allocator's statistics tables.
-- @cstyle void ResetMemStats().
-- @return void.

function ResetMemStats()
end

--- Reset profile system and if non-empty file name is given dump there the current data.
-- @cstyle void ResetProfile(string file_name).
-- @param file_name string.
-- @return void.

function ResetProfile(file_name)
end

--- Sets UI mouse cursor to the one supplied; if filename is empty the application cursor is used.
-- If the UI and the application cursor are both set the UI cursor is used.
-- @cstyle void SetUIMouseCursor(string filename).
-- @param filename string.
-- @return void.

function SetUIMouseCursor(filename)
end

--- Sets application mouse cursor to the one supplied.
-- If the UI and the application cursor are both set the UI cursor is used.
-- @cstyle void SetAppMouseCursor(string filename).
-- @param filename string.
-- @return void.

function SetAppMouseCursor(filename)
end

--- Hides the mouse cursor.
-- @cstyle void HideMouseCursor().
-- @return void.

function HideMouseCursor()
end

--- Shows the mouse cursor.
-- @cstyle void ShowMouseCursor().
-- @return void.

function ShowMouseCursor()
end

--- Checks if the mouse cursor is hidden.
-- @cstyle bool IsMouseCursorHidden().
-- @return true if the mouse cursor is hidden, false otherwise.

function IsMouseCursorHidden()
end

--- Returns the current mouse cursor.
-- @cstyle string GetMouseCursor().
-- @return void.

function GetMouseCursor()
end

--- Returns the current map.
-- @cstyle string GetMap().
-- @return string.

function GetMap()
end

--- Opens open-file browse dialog and let the user choose file and returns it.
-- @cstyle string OpenBrowseDialog(string initail_dir, string file_type, bool exists = true, bool multiple = false, initial_file = false).
-- @param initail_dir string; The directory the browse dialog starts browising.
-- @param file_type string; The file type the browse dialog searches for.
-- @param exists boolean; if true the user can choose only existing files, otherwise can enter new name in the editor text box; can be omitted, default value is true.
-- @return string.

function OpenBrowseDialog(initail_dir, file_type, exists, multiple, initial_file)
end

--- Returns the executable path.
-- @cstyle string GetExecDirectory().
-- @return string.

function GetExecDirectory()
end

--- Returns the current directory.
-- @cstyle string GetCWD().
-- @return string.

function GetCWD()
end

--- Copies a string into the clipboard, the limit is optional, the default is 1024 (-1 for unlimited number of chars)
-- @cstyle void CopyToClipboard(string clip, int limit).
-- @param clip string.
-- @return void.

function CopyToClipboard(clip)
end

--- Returns the string in the clipboard, the limit is optional, the default is 1024 (-1 for unlimited number of chars)
-- @cstyle string GetFromClipboard(int limit).
-- @return string.

function GetFromClipboard()
end

--- Returns all surfaces of the given type intersectning the specified box.
-- @cstyle table GetSurfaces(Box box, int type).
-- @param box box.
-- @param type int.
-- @return table; the table is integer indexed and the format is [i] = { v1, v2, v3 }, where v1, v2, v3 are points, vertices of the 

function GetSurfaces(box, type)
end

--- Opens given address.
-- @cstyle void OpenAddress(string address).
-- @param address string; the address to open.

function OpenAddress(name)
end

--- Returns the length in letters of the given utf8 encoded string.
-- @cstyle int len(string utf8).
-- @param utf8 string; a utf8 encoded string.
-- @return int.

function len(utf8)
end

--- Returns byte offset after advancing a utf8 string with "letters" characters, starting at position pointer
-- @cstyle string Advance(utf8, pointer, letters).
-- @return int

function Advance(utf8, pointer, letters)
end

--- Returns byte offset after retreating a utf8 string with "letters" characters, starting at position pointer
-- @cstyle string Retreat(utf8, pointer, letters).
-- @return int

function Retreat(utf8, pointer, letters)
end

--- This function work for the following camera model :.
-- The camera look at point is offset on z axis from the point we wish to observe(observe point).
-- The pitch is the angle between the camera eye and the camera look at.
-- Given pitch, desired distance from eye to observe point and the distance from the look at point to the observe point,.
-- the function returns the 2d (x and y axis only) and z distances between the eye and the look at point.
-- @cstyle int, int GetCameraLH(int pitch, int dist, int dist_to_ground).
-- @param pitch int; angle between the camera look at direction and x, y plane.
-- @param dist int; distance from the eye to.
-- @return int, int; returns the 2d distance and the z distance.

function GetCameraLH(pitch, dist, dist_to_ground)
end

--- Intersects segment with cylinder; the base of the cylinder is parallel to the (x, y) plane and the height is parallel to the z axis.
-- @cstyle bool, point, point IntersectSegmentCylinder(point pt1, point pt2, point center, int radius, int height).
-- @param pt1 point; the segment starting point.
-- @param pt2 point; the segment ending point.
-- @param center point; the center of the base.
-- @param radius integer; radius of the base.
-- @param height integer; the height of the cylinder.
-- @return bool, point, point; returns true with the intersection points or false if no intersection exist.

function IntersectSegmentCylinder(pt1, pt2, center, radius, height)
end

--- Intersects line with cone;
-- @cstyle bool, point, point IntersectSegmentCylinder(point pt1, point pt2, point vertex, point height, int angle).
-- @param pt1 point; first point that the line passes through.
-- @param pt2 point; second point that the line passes throgh.
-- @param vertex point; vertex of the cone.
-- @param dir point; a point along with vertex defining axis of the cone.
-- #param height integer; height of the cone - if missing cone is infinite.
-- @param angle integer; angle of the cone in minutes.
-- @return point, point; returns 1 or 2 intersection points(they can be "-infinity" or "infinity" if ray inside cone and cone is infinite) or false if no intersection exist.

function IntersectLineCone(pt1, pt2, vertex, dir, angle, height)
end

--- Intersects ray with cone;
-- @cstyle bool, point, point IntersectSegmentCylinder(point pt1, point pt2, point vertex, point height, int angle).
-- @param pt1 point; the origin of the ray.
-- @param pt2 point; a point defining the direction of the ray.
-- @param vertex point; vertex of the cone.
-- @param dir point; a point along with vertex defining axis of the cone.
-- #param height integer; height of the cone - if missing cone is infinite.
-- @param angle integer; angle of the cone in minutes.
-- @return point, point; returns 1 or 2 intersection points(they secod one can be "infinity" if ray inside cone and cone is infinite) or false if no intersection exist.

function IntersectRayCone(pt1, pt2, vertex, dir, angle, height)
end

--- Intersects segment with cone;
-- @cstyle bool, point, point IntersectSegmentCylinder(point pt1, point pt2, point vertex, point height, int angle).
-- @param pt1 point; the segment starting point.
-- @param pt2 point; the segment ending point.
-- @param vertex point; vertex of the cone.
-- @param dir point; a point along with vertex defining axis of the cone.
-- #param height integer; height of the cone - if missing cone is infinite.
-- @param angle integer; angle of the cone in minutes.
-- @return point, point; returns 1 or 2 intersection points or false if no intersection exist.

function IntersectSegmentCone(pt1, pt2, vertex, dir, angle, height)
end

--- Return the distance between segment and point in 2d space.
-- @cstyle int, closestX, closestY, closestZ DistSegmentToPt(point pt1, point pt2, point pt, offset).
-- @param pt1 point; the segment starting point.
-- @param pt2 point; the segment ending point.
-- @param pt point.
-- @return int; distance in game units.

function DistSegmentToPt2D2(pt1, pt2, pt)
end

--- Return the intersection between two given lines in 2d space.
-- @cstyle point IntersectLineWithLine2D(point pt1, point pt2, point pt3, point pt4).
-- @param pt1 point; the first line starting point.
-- @param pt2 point; the first line ending point.
-- @param pt3 point; the second line starting point.
-- @param pt4 point; the second line ending point.
-- @return point; the intersection point if one exist or false if no intersection.

function IntersectLineWithLine2D(pt1, pt2, pt3, pt4)
end

--- Return the intersection between two given segment in 2d space.
-- @cstyle point IntersectSegmentWithSegment2D(point pt1, point pt2, point pt3, point pt4).
-- @param pt1 point; the first segment starting point.
-- @param pt2 point; the first segment ending point.
-- @param pt3 point; the second segment starting point.
-- @param pt4 point; the second segment ending point.
-- @return point; the intersection point if one exist or false if no intersection.

function IntersectSegmentWithSegment2D(pt1, pt2, pt3, pt4)
end

--- Return the intersection between given ray and segment in 2d space.
-- @cstyle point IntersectRayWithSegment2D(point origin, point dir, point pt1, point pt2).
-- @param origin point; the ray origin.
-- @param dir point; the ray direction.
-- @param pt1 point; the segment starting point.
-- @param pt2 point; the segment ending point.
-- @return point; the intersection point if one exist or false if no intersection.

function IntersectRayWithSegment2D(origin, dir, pt1, pt2)
end

--- Return the intersection between line with circle in 2d space.
-- @cstyle point, point IntersectLineWithCircle2D(point pt1, point pt2, point center, int radius).
-- @param pt1 point; the first line starting point.
-- @param pt2 point; the first line ending point.
-- @param center point; the center of the circle.
-- @param radius int; the radius of the circle.
-- @return point; the intersection point(s) if one exist or false if no intersection.

function IntersectLineWithCircle2D(pt1, pt2, center, radius)
end

--- Return the intersection between line with circle in 2d space.
-- @cstyle point, point IntersectSegmentWithCircle2D(point pt1, point pt2, point center, int radius).
-- @param pt1 point; the first segment starting point.
-- @param pt2 point; the first segment ending point.
-- @param center point; the center of the circle.
-- @param radius int; the radius of the circle.
-- @return point; the intersection point(s) if one exist or false if no intersection.

function IntersectSegmentWithCircle2D(pt1, pt2, center, radius)
end

--- Return the first intersected object between two points.
-- @cstyle object, point, point IntersectSegmentWithCircle2D(point pt1, point pt2[[, point offset = point(0, 0, 0)], int enum_flags_all = 0, string class = "", int enum_flags_ignore = 0, int game_flags_ignore = 0, int game_flags_any = 0, int offset_z = 0, int surf_flags = EntitySurfaces.Collision | EntitySurfaces.Walk, bool exact = true]).
-- @param pt1 point; the first segment starting point.
-- @param pt2 point; the first segment ending point.
-- @param enum_flags_all int; the object should have all of these enum flags (optional).
-- @param class string; the object's class (optional).
-- @param int enum_radius; map enum radius (optional, max object's radius by default).
-- @param enum_flags_ignore int; the object should NOT have any of these enum flags (optional).
-- @param game_flags_ignore int; the object should NOT have any of these game flags (optional).
-- @param game_flags_all int; the object should have all of these game flags (optional).
-- @param offset_z int; segment offset usefull as the object's origin is usually at the mesh bottom, which is an edge case (optional).
-- @param surf_flags int; the object should have surfaces with these flags (optional).
-- @param exact bool; specify intersection tests with higher precision (takes more time)
-- @param filter function; optional object filter
-- @return object; the intersected object.
-- @return point; the intersection point.
-- @return point; the intersection normal.

function IntersectSegmentWithClosestObj(pt1, pt2, class, enum_radius, enum_flags_all, game_flags_all, enum_flags_ignore, game_flags_ignore, surf_flags, exact, offset_z, filter, ...)
end

--- Checks for intersections between a polygon and a circle in 2d space.
-- @cstyle bool, point* IntersectPolyWithCircle2D(point *poly, point center, int radius).
-- @return bool; is there any intersection.
-- @return point*; table with the intersection points.

function IntersectPolyWithCircle2D(poly, center, radius)
end

--- Checks for intersections between two polygons in 2d space.
-- @cstyle bool IntersectPolyWithPoly2D(point *poly1, point *poly2).
-- @return bool; is there any intersection.

function IntersectPolyWithPoly2D(poly1, poly2)
end

--- Checks for intersections between a polygon and a spline in 2d space.
-- @cstyle bool IntersectPolyWithSpline2D(point *poly, point *spline, int width, int precision = 0.5).
-- @param poly point*; table with the polygon points.
-- @param spline point; table with the spline points.
-- @param width int; the width of the spline (should be greater of 0).
-- @param precision int; precision for the iterative check (0.5 by default).
-- @return bool; is there any intersection.

function IntersectPolyWithSpline2D(poly, spline, width, precision)
end

--- Return a part of the given segment that is inside the given box; at least one point must be inside the box, otherwise it will return the original segment.
-- @cstyle point, point BoundSegmentInBox(point pt1, point pt2, box box).
-- @param pt1 point; the first segment starting point.
-- @param pt2 point; the first segment ending point.
-- @param box box.
-- @return point, point.

function BoundSegmentInBox(pt1, pt2, box)
end

--- Writes a screenshot to the file.
-- @cstyle void WriteScreenshot(string file).
-- @param file string; target file.
-- @return void.

function WriteScreenshot(file)
end

--- Quits the application.
-- @cstyle void quit().
-- @return void.
function quit()
end

--- Checks if quit() function is in process.
-- @cstyle bool IsQuitInProcess().
-- @return bool.
function IsQuitInProcess()
end

--- Returns the currently logged user in utf8 string.
-- @cstyle string GetUsername().
-- @return string the username.
function GetUsername()
end

--- Returns memory information about a table - memory used, size of array part, size of hash part
-- @cstyle int, int, int gettablesizes(table).
-- @return int, int, int - total memory, entries in array part, entries in hash part.

function gettablesizes(table)
end

--- LuaVar functions
 
--- Returns the value of an engine exported variable (LuaVar).
-- @cstyle value-type GetEngineVar(string name).
-- @param name; The name of the LuaVar.

function GetEngineVar(prefix, name)
end

--- Sets the value of an engine exported variable (LuaVar).
-- @cstyle void SetEngineVar(string name, value-type value).

function SetEngineVar(prefix, name, value)
end

--- Returns a table with fields that correspond to engine exported variables (LuaVars) starting with certain prefix.
-- @cstyle table EnumEngineVars(string prefix).
-- @param prefix - a prefix used to match engine exported vars (LuaVars) to table fields - a field matches when <engine var> == <prefix><field>.

function EnumEngineVars(prefix)
end

--- Get current time and store it.
-- @cstyle void SetPerformanceTimeMarker().
function SetPerformanceTimeMarker()
end

--- Add the time between calling SetPerformanceTimeMarker and this function to specified id.
-- @cstyle void PerformanceTimeAdd(int id1, int id2).
-- @param id1: the id.
-- @param id2: extra id on wich this time differens to be added (optional).
function PerformanceTimeAdd(id1, id2)
end

--- Get the sum of all times for given id in ms.
-- @cstyle int  GetPerformanceTime(int id).
-- @param id1: the id.
function GetPerformanceTime(id)
end

--- Get min and max times for given id in ms.
-- @cstyle int, int  GetPerformanceTime(int id).
-- @param id1: the id.
function GetPerformanceTimesMinMax(id)
end

--- Set time data to zero for all id-s.
-- @cstyle void ResetPerformanceTimes().
function ResetPerformanceTimes()
end

--- Cancels the rendering of an upsampled screenshot and discards any accumulated data.
-- @cstyle void CancelUpsampledScreenshot().
function CancelUpsampledScreenshot()
end

--- Draws scaled text, which drops shadow with given properties.
-- @cstyle void StretchTextShadow(string text, box rc, [string/unsigned font], [int color], int shadow_color, int shadow_size, point shadow_dir).
-- @param text: text to draw.
-- @param rc: rectangle in which to draw the text.
-- @param font: font to use for drawing, optional (use last set font if skipped).
-- @param color: color to use for drawing, optional (use las set color if skipped).
-- @param shadow_color: color to use for dropped shadow.
-- @param shadow_size: size of the dropped shadow, in pixels.
-- @param shadow_dir: direction vector of the dropped shadow.
function StretchTextShadow(text, rc, font, color, shadow_color, shadow_size, shadow_dir)
end

--- Draws scaled outlined text.
-- @cstyle void StretchTextOutline(string text, box rc, [string/unsigned font], [int color], int outline_color, int outline_size).
-- @param text: text to draw.
-- @param rc: rectangle in which to draw the text.
-- @param font: font to use for drawing, optional (use last set font if skipped).
-- @param color: color to use for drawing, optional (use las set color if skipped).
-- @param outline_color: color to use for drawing outline.
-- @param outline_size: size of the outline, in pixels.
function StretchTextOutline(text, rc, font, color, outline_color, outline_size)
end

--- Returns the fullscreen mode.
-- @cstyle int FullscreenMode().
-- @return int; the fullscreen mode (0 = windowed; 1 = borderless; 2 = exclusive).

function FullscreenMode()
end

--- Creates font face with string description and returns ID for this face (if ID was passed, just returns it).
-- @cstyle unsigned GetFont(char *font_description).
-- @param font_description: string description in following format "<font name>, <font size>, [<flags>]".
-- @return ID.
function GetFontID(font_description)
end

--- Returns font description for font face with given ID.
-- @cstyle char *GetFontDescription(unsigned font_id).
-- @param font_id: ID of the font (returned by GetFontID()).
-- @return string.
function GetFontDescription(font_id)
end

--- Calculates path distances from given point to multiple destinations
-- @cstyle table GetMultiPathDistances(point origin, table destinations, [int pfClass])
-- @param origin: the starting point
-- @param destinations: a table, containing the destination points
-- @param pfClass: pathfinder class to use (optional, default 0)
-- @return table; the 
function GetMultiPathDistances(origin, destinations, pfClass)
end

--- Forces the terrain debug (passability) draw texture to be recreated.
-- @cstyle void UpdateTerrainDebugDraw()
function UpdateTerrainDebugDraw()
end

--- Returns object current path as a list of target points.
-- @cstyle table, bool obj:GetPath()
-- return table: list of target points, bool: path delayed or not
function GetPath()
end

--- Returns safe sceen area rectangle
-- @cstyle rect GetSafeArea()
function GetSafeArea()
end

--- Returns a string dump of the map objects' properties.
-- Used for saving maps.
-- @cstyle string __DumpObjPropsForSave()
function __DumpObjPropsForSave()
end

--- Returns the first argument clamped to the range specified by the 2nd and the 3rd argument.
-- @cstyle int Clamp(int x, int a, int b)
-- @param x; input argument which will be clamped.
-- @param a; lower clamp range.
-- @param b; upper clamp range.
-- @return int; x clamped in the [a,b] range.
function Clamp()
end

--- Returns render statistics for the last and/or current frame. Since Lua runs concurrently with the renderer, and there is no synchronization for this function, some of the three numbers might come from the current frame and some - from the previous.
-- @cstyle int, int, int GetRenderStatistics()
-- @return int dips, int tris, int vtx; number of drawcalls, Ktriangles, and Kvertices rendered in the frame.
function GetRenderStatistics()
end

--- Reports memory fragmentation info in the debugger output
-- @cstyle void dbgMemoryAllocationTest()
-- @return void.
function dbgMemoryAllocationTest()
end

--- Transforms a game point to a screen point of the current game camera.
-- If the point is behind the camera it's flipped first. The point is converted to screen space. The result point may lie outside window boundaries, i.e. negative coordinates and such one greater then Width, Height.
-- @cstyle bool,point GameToCamera(point pt)
-- @param pt; game point to transform.
-- @return bool, point; first return value tells whether the point was in front of the camera. The second return value is the point in screen space.
-- @see GameToCamera.
-- @see ScreenToGame.
function GameToScreen(pt)
end

--- Transforms a 2D screen point of the current game camera to a game point.
-- The 2D point Z coordinate is considered to be camera's 0.
-- @cstyle bool/point GameToCamera(point pt)
-- @param pt; game point to transform.
-- @param precision; fixed-point multiplier (optional)
-- @return point; the transformed game point.
-- @see GameToCamera.
function ScreenToGame(pt, precision)
end

--- Transforms a game point to a screen point of the given camera.
-- The function first checks if the point is behind the camera and returns false, otherwise it's converted to screen space. The result point may lie outside window boundaries, i.e. negative coordinates and such one greater then Width, Height.
-- @cstyle bool/point GameToCamera(point pt, point camPos, point camLookAt)
-- @param pt; game point to transform.
-- @param camPos; position of the camera.
-- @param camLookAt; point at which the camera is looking.
-- @return bool/point; if the point is behind the camera NearZ returns false, otherwise a point in screen space is returned.
-- @see GameToScreen.
function GameToCamera(pt, camPos, camLookAt)
end

--- Returns z and the topmost walkable object at specified point.
-- @cstyle GameObject GetWalkableObject(point pt)
-- @param pt; the query point
-- @return GameObject/nil - the topmost walkable object at this point, and z
function GetWalkableObject(pt)
end

--- Returns z and the topmost walkable object at specified point.
-- @param pt; the query point
-- @return z; the topmost walkable object at this point, if any, otherwise nil
function GetWalkableZ(pt)
end

--- Same as pcall, but asserts pop instead of being printed out; the called function cannot Sleep.
-- @cstyle bool procall(f, arg1, ...).
-- @param f; the function to call.
-- @return bool, res1, res2, ...
function procall(f, arg1, ...)
end

--- Same as pcall, but asserts pop instead of being printed out; the called function can Sleep.
-- @cstyle bool sprocall(f, arg1, ...).
-- @param f; the function to call.
-- @return bool, res1, res2, ...
function sprocall(f, arg1, ...)
end

--- Print in the C debugger output window.
-- @cstyle void DebugPrint(string text)
-- @param text; the text to be printed.
-- @return void.

function DebugPrint(text)
end

--- Returns a table with all the textures used for the given terrain layer.
-- @cstyle table GetTerrainTextureFiles(int layer)
-- @param layer; the numeric layer id.
-- @return table; a table containing all textures related to the layer (diffuse, normal, specular).
function GetTerrainTextureFiles(layer)
end

--- Sets a SSAO post-processing parameter to specified value
-- @cstyle void SetPostProcSSAOParam(int param, int value)
-- @param param; the id of the parameter to set (0-3)
-- @param value; the value to set
-- @return void
function SetPostProcSSAOParam(param, value)
end

--- Returns the current value of the specified SSAO post-processing parameter
-- @cstyle int GetPostProcSSAOParam(int param)
-- @param param; the id of the parameter to set (0-3)
-- @return int; the current value of the specified parameter
function GetPostProcSSAOParam(param)
end

--- Returns the current time represented in a specified precision
-- @cstyle int GetPreciseTicks(int param = 1000)
-- @param precision; the required precision; default value is 1000 (ms)
-- @return int; the current time
function GetPreciseTicks(precision)
end

--- Returns the current Lua allocations count
-- @cstyle int GetAllocationsCount()
-- @return int;
function GetAllocationsCount()
end

--- Clears all the debug vectors
-- @cstyle void DbgClearVectors()
function DbgClearVectors()
end

--- Clears all the debug texts
-- @cstyle void DbgClearTexts()
function DbgClearTexts()
end

--- Draw a debug vector
-- @cstyle void DbgAddVector(point origin, point vector, int color = RGB(255, 255, 255))
function DbgAddVector(origin, vector, color)
end

--- Draw a debug line conecting two points
-- @cstyle void DbgAddSegment(point pt1, point pt2, int color = RGB(255, 255, 255))
function DbgAddSegment(pt1, pt2, color)
end

--- Draw a debug spline
-- @cstyle void DbgAddSpline(point spline[4], int color = RGB(255, 255, 255) [, int point_count])
function DbgAddSpline(spline, color, point_count)
end

--- Draw a debug polygon
-- @cstyle void DbgAddPoly(point poly[], int color = RGB(255, 255, 255), bool dont_close = false)
function DbgAddPoly(poly, color, dont_close)
end

--- Draw a debug terrain rectangle
-- @cstyle void DbgAddTerrainRect(box rect, int color = RGB(255, 255, 255))
function DbgAddTerrainRect(rect, color)
end

--- Set a default offset when drawing debug vectors
-- @cstyle void DbgSetVectorOffset(int [or point] offset)
-- @param offset; point or only Z coordinate
function DbgSetVectorOffset(offset)
end

--- Enable/disable dbg vectors ztest
function DbgSetVectorZTest(enable)
end

--- Draw a debug circle
-- @cstyle void DbgAddCircle(point center, int radius, int color = RGB(255, 255, 255), int point_count = -1)
function DbgAddCircle(center, radius, color, point_count)
end

--- Draw a debug box
-- @cstyle void DbgAddBox(box box, int color = RGB(255, 255, 255))
function DbgAddBox(box, color)
end

--- Draw a solid triangle
-- @cstyle void DbgAddTriangle(point pt1, point pt2, point pt3, int color = RGB(255, 255, 255))
function DbgAddTriangle(pt1, pt2, pt3, color)
end

--- Draw a text
-- @cstyle void DbgAddText(string text, point pos, int color = RGB(255, 255, 255), string font_face = const.SystemFont, int back_color = RBGA(0, 0, 0, 0))
function DbgAddText(text, pos, color, font_face, back_color)
end

-------------------------------------------------------------------------------------------------------------------------------------------
--- Unregister a certificate. The function will fail if a certificate with the same name isn't registered.
-- @cstyle string CertDelete(string certificate_name).
-- @param certificate_name; name of the certificate.
-- @return string; error message.
function CertDelete(certificate_name)
end

--- Read certificate data from a file. The function will fail if the file doesn't contain a certificate with the same name.
-- @cstyle string, string CertRead(string certificate_name, string certificate_file).
-- @param certificate_name; name of the certificate. MUST MATCH THE REAL NAME IN THE ENCRYPTED DATA!
-- @param certificate_file; name of the file containing the certificate.
-- @return string, string; error message and encrypted certificate data.
-- @see CertRegister.
function CertRead(certificate_name, certificate_file)
end

--- Register a certificate from encrypted data. The function will fail if a certificate with the same name is already registered.
-- @cstyle string CertRegister(string certificate_name, string certificate_data).
-- @param certificate_name; name of the certificate. MUST MATCH THE REAL NAME IN THE ENCRYPTED DATA!
-- @param certificate_data; encrypted data containing the certificate obtained via CertRead.
-- @return string; error message.
-- @see CertRead.
function CertRegister(certificate_name, certificate_data)
end
-------------------------------------------------------------------------------------------------------------------------------------------

--- Encodes a given URL and returns it. Compatible with the RFC 3986 standart
function EncodeURL(url)
end

--- Decodes a given URL and returns it. Compatible with the RFC 3986 standart
function DecodeURL(url)
end

--- Splits a file path into dir, name and extension (e.g. SplitPath("C:/dir/file.txt") --> "C:/dir/", "file", ".txt"
function SplitPath(file_path)
end

----

function Lerp(from, to, time, interval)
end