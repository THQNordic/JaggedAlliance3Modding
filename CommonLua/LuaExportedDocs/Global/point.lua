--- Point functions.

--- Returns a point with the specified coordinates, accepts 2 or 3 parameters.
-- @cstyle point point(int x, int y, int z).
-- @param x integer X-coordinate of the point.
-- @param y integer Y-coordinate of the point.
-- @param z integer (optional) Z-coordinate of the point.
-- @return point.

function point(x, y, z)
end

--- Returns the X coordinate of the point.
-- @cstyle int point::x(point p).
-- @return int.

function point:x()
end

--- Returns the Y coordinate of the point.
-- @cstyle int point::y(point p).
-- @return int.

function point:y()
end

--- Returns the Z coordinate of the point.
-- @cstyle int point::z(point p).
-- @return int.

function point:z()
end

--- Shows if the point has a valid Z coordinate.
-- @cstyle bool point::IsValidZ(point p).
-- @return bool.

function point:IsValidZ()
end

--- Shows if the point is valid.
-- @cstyle bool point::IsValid(point p).
-- @return bool.

function point:IsValid()
end

--- Returns the given point with x-cooridnate changed to x.
-- @cstyle point point:SetX(point self, int x).
-- @return point.

function point:SetX()
end

--- Returns the given point with y-cooridnate changed to y.
-- @cstyle point point:SetY(point self, int y).
-- @return point.

function point:SetY()
end

--- Returns the given point with z-cooridnate changed to z.
-- @cstyle point point:SetZ(point self, int z).
-- @return point.

function point:SetZ()
end

--- Returns the given point with z-cooridnate changed to invalid value; the returned point is considered 2D.
-- @cstyle point point:SetInvalidZ(point self).
-- @return point.

function point:SetInvalidZ()
end

--- Returns a point, created by resizing the given vector by given promile.
-- If the point is with invalid Z, the z coordinate would be omitted.
-- A point can be provided as parameter which combines all three values.
-- If only one value is given as parameter all three coordinates are scaled by the given value.
-- If scalex and scaley are only given scalez defaults 1000(don't scale).
-- @cstyle point box::Scale(box b, int scalex, int scaley, int scalez).
-- @param pt point.
-- @param scalex int.
-- @param scaley int.
-- @param scalez int.
-- @return box.

function ScalePoint(pt, scalex, scaley, scalez)
end

--- Returns the given point shortened by delta_len.
-- @cstyle point point:Shorten(point self, int delta_len).
-- @param pt point.
-- @param delta_len int.
-- @return point.

function Shorten(pt, delta_len)
end

--- Returns the given point lengthened by delta_len.
-- @cstyle point point:Lengthen(point self, int delta_len).
-- @param pt point.
-- @param delta_len int.
-- @return point.

function Lengthen(pt, delta_len)
end

--- Returns the given point with len set to the given value.
-- @cstyle point point:SetLen(point self, int new_len).
-- @param pt point.
-- @param new_len int.
-- @return point.

function SetLen(pt, new_len)
end

--- Returns a point in the same direction with a length no more than the limit.
-- Made for optimization and readability - doesn't make an allocation if the point remains the same.
-- @cstyle point point:LimitLen(point self, int limit).
-- @param pt point.
-- @param limit int.
-- @return point.

function LimitLen(pt, limit)
end

--- Returns the point rotated around the given axis.
-- @cstyle point RotateAxis(point self, point axis, int angle, point center = point30).
-- @param axis point.
-- @param angle int; rotation angle.
-- @param center point; rotation center (optional).
-- @return point.

function RotateAxis(pt, axis, angle, center)
end

--- Returns the point rotated around the Z axis.
-- @cstyle point RotateRadius(int radius, int angle, point center = point30, bool return_xyz = false, bool bSync = false).
-- @param radius int; radius length.
-- @param angle int; rotation angle.
-- @param center point; rotation center (could be Z value only).
-- @param return_xyz bool; return x, y and z, not a point.
-- @param bSync bool; Use integer arithmetic only.
-- @return point or int, int.

function RotateRadius(radius, angle, center, return_xyz)
end

--- Returns the point rotated around x, y and z axis.
-- @cstyle point RotateXYZ(point self, int x, int y, int z).
-- @param x int.
-- @param y int.
-- @param z int.
-- @return point.

function RotateXYZ(x, y, z)
end

--- Returns cross product of the two given points.
-- @cstyle point Cross(point pt1, point pt2).
-- @param pt1 point.
-- @param pt2 point.
-- @return point.

function Cross(pt1, pt2)
end

--- Returns the Z coordinate of the 2D cross product of the two given points.
-- @cstyle int Cross2D(point pt1, point pt2).
-- @param pt1 point.
-- @param pt2 point.
-- @return int.

function Cross2D(pt1, pt2)
end

--- Returns dot product of the two given points.
-- @cstyle int Dot(point pt1, point pt2).
-- @param pt1 point.
-- @param pt2 point.
-- @return int.

function Dot(pt1, pt2)
end

--- Returns dot product of the two given points in 2D.
-- @cstyle int Dot(point pt1, point pt2).
-- @param pt1 point.
-- @param pt2 point.
-- @return int.

function Dot2D(pt1, pt2)
end
	
--- Returns the axis/angle couple to use for rotating point pt1 to pt2.
-- @cstyle point, int GetAxisAngle(point pt1, point pt2).
-- @param pt1 point.
-- @param pt2 point.
-- @return point, int; axis/angle to use for rotating pt1 to pt2.

function GetAxisAngle(pt1, pt2)
end

--- Returns the length of the radius vector determined by this point.
-- @cstyle int point::Len(point p).
-- @return int.

function point:Len()
end

--- Returns the 2D length of the radius vector determined by this point.
-- @cstyle int point::Len2D(point p).
-- @return int.

function point:Len2D()
end

--- Returns the square length of the radius vector determined by this point.
-- @cstyle int point::Len2(point p).
-- @return int.

function point:Len2()
end

--- Returns the square length of the radius vector determined by this 2D point(ignores Z).
-- @cstyle int point::Len2D2(point p).
-- @return int.

function point:Len2D2()
end

--- Returns the euclidian distance between the current and specified points.
-- @cstyle int point::Dist(point p1, point p2).
-- @param p2 point target point to calculate distance to.
-- @return int.

function point:Dist(p2)
end

--- Returns the squared euclidian distance between the current and specified points.
-- @cstyle int point::Dist2(point p1, point p2).
-- @param p2 point target point to calculate distance to.
-- @return int.

function point:Dist2(p2)
end

--- Returns the euclidian distance between the current and specified 2D points(ignores Z).
-- @cstyle int point::Dist2D(point p1, point p2).
-- @param p2; point target point to calculate distance to.
-- @return int.

function point:Dist2D(p2)
end

--- Returns the squared euclidian distance between the current and specified 2D points(ignores Z).
-- @cstyle int point::Dist2D2(point p1, point p2).
-- @param p2; point target point to calculate distance to.
-- @return int.

function point:Dist2D2(p2)
end

--- Shows if the point is inside the box (including the borders).
-- @cstyle bool point::InBox(point p, box b).
-- @param b box.
-- @return bool.

function point:InBox(b)
end

--- Same as InBox but in 2D.
-- @cstyle bool point::InBox2D(point p, box b).
-- @param b box.
-- @return bool.

function point:InBox2D(b)
end

--- Check if two points are equal in 2D
-- @cstyle bool point::Equal2D(point p1, point p2).
-- @param p2; point target point to check.
-- @return bool.

function point:Equal2D(p2)
end

--- Shows if the point is inside the horizontally oriented hexagone (including the borders).
-- @cstyle bool point::InHHex(point p, box b).
-- @param b box.
-- @return bool.

function point:InHHex(b)
end

--- Shows if the point is inside the vertically oriented hexagone (including the borders).
-- @cstyle bool point::InVHex(point p, box b).
-- @param b box.
-- @return bool.

function point:InVHex(b)
end

--- Shows if the point is inside the inscribed ellpise.
-- @cstyle bool point::InEllipse(point p, box b).
-- @param b box.
-- @return bool.

function point:InEllipse(b)
end

--- Rotates the given point along Z-axis.
-- @cstyle point Rotate(point pt, int angle).
-- @param pt point target point to rotate.
-- @param angle int angle to rotate point (0-360).
-- @return point.

function Rotate(pt, angle)
end

--- Calculate the orientation between two points.
-- @cstyle int CalcOrientation(point/object p1, point/object p2).
-- @param p1 point.
-- @param p2 point.
-- @return int.

function CalcOrientation(p1, p2)
end

--- Check if the given parameter is a point
-- @cstyle bool IsPoint(point pt).
-- @param pt point.
-- @return bool.

function IsPoint(pt)
end

--- Returns what the application assumes is invalid position.
-- @cstyle point InvalidPos().
-- @return point; a point which game assumes is the invalid positon.

function InvalidPos()
end

--- Returns true if 'pt' is closer to 'pt1' than to 'pt2'.
-- @cstyle bool IsCloser(point pt, point pt1, point pt2).
-- @param pt; point to check. 
-- @param pt1; first point.
-- @param pt2; second point.
-- @return bool; |pt - pt1| < |pt - pt2|

function IsCloser(pt, pt1, pt2)
end

--- Returns true if 'pt' is closer to 'pt1' than the given dist.
-- @cstyle bool IsCloser(point pt, point pt1, int dist).
-- @param pt; point to check. 
-- @param pt1; first point.
-- @param dist; distance to compare width.
-- @return bool; |pt - pt1| < dist

function IsCloser(pt, pt1, dist)
end

--- Returns true if 'pt' is closer to 'pt1' than to 'pt2' in 2D.
-- @cstyle bool IsCloser2D(point pt, point pt1, point pt2).
-- @param pt; point to check. 
-- @param pt1; first point.
-- @param pt2; second point.
-- @return bool;

function IsCloser2D(pt, pt1, pt2)
end

--- Returns true if 'pt' is closer to 'pt1' than the given dist in 2D.
-- @cstyle bool IsCloser2D(point pt, point pt1, int dist).
-- @param pt; point to check. 
-- @param pt1; first point.
-- @param dist; distance to compare width.
-- @return bool;

function IsCloser2D(pt, pt1, dist)
end

--- Returns true if the length of 'pt1' is smaller than the length of 'pt2'
-- @cstyle bool IsSmaller(point pt1, point pt2).
-- @param pt1; first point.
-- @param pt2; second point.
-- @return bool; |pt1| < |pt2|

function IsSmaller(pt1, pt2)
end

--- Returns true if the 2D length of 'pt1' is smaller than the 2D length of 'pt2'
-- @cstyle bool IsSmaller2D(point pt1, point pt2).
-- @param pt1; first point.
-- @param pt2; second point.
-- @return bool;

function IsSmaller2D(pt1, pt2)
end

function Normalize(pt)
end

--- Returns a transformed point by rotation, translation and scaling.
-- @cstyle point Transform(pt, angle, offset, axis, scale, inverse)
-- @cstyle point Transform(x, y, z, angle, offset, axis, scale, inverse)
-- @param pt point/object; point to be transformed.
-- @param angle int; rotation angle.
-- @param offset point/object; translation offset.
-- @param axis point; rotation axis.
-- @param scale int; scaling percents.
-- @param inverse bool; perform the inverse transformation.
-- @return point; the transformed point.

function Transform(pt, angle, offset, axis, scale, inv)
end
function Transform(x, y, z, angle, offset, axis, scale, inv)
end
function TransformXYZ(pt, angle, offset, axis, scale, inv)
end
function TransformXYZ(x, y, z, angle, offset, axis, scale, inv)
end

----

function ResolvePos(pt_or_obj_or_x, y, z)
end
function ResolveVisualPos(pt_or_obj_or_x, y, z)
end
function ResolvePosXYZ(pt_or_obj_or_x, y, z)
end
function ResolveVisualPosXYZ(pt_or_obj_or_x, y, z)
end

----

function ClampPoint(pos, box, border)
end

