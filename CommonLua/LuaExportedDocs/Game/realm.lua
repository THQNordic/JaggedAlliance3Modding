--- Pathfinding-related and map folder functions.
-- This file contains many pathfinder-related utility functions, e.g. functions for finding free positions near a specified map location.
-- Another batch of functions deals with checking and finding destination locks.
-- By definition, a position (with a radius) can be destination-locked if it's passable and there are no static units or other destination locks overlapping it.
-- Destination locks (special dummy objects with radius) are used by the pathfinder to guarantee that the destinations units are heading to will not be occupied by another unit before they reach these destinations.

--- Suspends passability updates (to reduce overhead when placing many objects in a row). Then call 'ResumePassEdits' to rebuild the passability grid.
-- @cstyle void SuspendPassEdits().
-- @return void.

function SuspendPassEdits()
end

--- Resumes passability updates and rebuild the passability for the map.
-- @cstyle void ResumePassEdits().
-- @return void.

function ResumePassEdits()
end

--- Returns whether passability updates are suspended.
-- @cstyle bool IsPassEditSuspended().
-- @return bool; true if the passability updates are suspended, false otherwise.

function IsPassEditSuspended()
end

--- Returns whether the specified point can be destlocked.
-- @cstyle bool CanDestlock(point pt, int radius).
-- @param pt point; the point to be checked.
-- @param radius int; radius for the destlock.
-- @return bool; true if the point can be destlocked, false otherwise.

function CanDestlock(pt, radius)
end

--- Finds a path from and places PathNode objects at the step specified.
-- @cstyle void AddPathTrace(object this, point src, point dst, int step).
-- @param src point; the source point.
-- @param dst point; the destination point.
-- @param step int; step interval at which to place a PathNode object along the path.
-- @return void.

function AddPathTrace(src, dst, step)
end

--- ATTENTION!!! This function works only in 2D, and returns only points in the same Z.
--- Finds a passable point nearby the specified point or nil if one can't be found.
-- @cstyle point GetPassablePointNearby(point/object/x,y pt, int pfClass, int nMaxDist, int nMinDist, func filter).
-- @param pt/object point; center to look around for passable point.
-- @param pfClass int; optional. pathfind class
-- @param nMaxDist int; optional. max radius to look up.
-- @param nMinDist int; optional. min radius to look up.
-- @param filter func; optional. function to filter the passable points.
-- @return point; a passable point arount pt or nil if no such point exists.

function GetPassablePointNearby(pt, pfClass, nMaxDist, nMinDist, filter)
end

--- ATTENTION!!! This function works only in 2D, and returns only points in the same Z.
--- Finds a destlockable point nearby the specified point or nil if one can't be found.
-- @cstyle point GetDestlockablePointNearby(point pt, int radius, bool checkPassability).
-- @param pt point; center to look around for destlockable point or object.
-- @param radius int; circle radius around the center to look for destlockable point.
-- @param checkPassability bool; indicates if the destlockable point should be passable (default false).
-- @param pfclass int; pathfinder class to use (optional, default object pathfinder class or 0)
-- @return point; a destlockable point in radius around pt or nil is no such point exists.

function GetDestlockablePointNearby(pt, radius, checkPassability, pfclass)
end

--- Return the bounding box of the map.
-- @cstyle box GetMapBox().
-- @return box.

function GetMapBox()
end
