--- Box functions.

--- Returns a 3D box constrained by the specified values; if minz and maxz omitted a 2D box(rect) is returned.
-- @cstyle box box(int minx, int miny, int minz, int maxx, int maxy, int maxz).
-- @param minx integer X coordinate of the lower left corner of the box.
-- @param miny integer Y coordinate of the lower left corner of the box.
-- @param minz integer Z coordinate of the lower left corner of the box; can be omitted together with maxz.
-- @param maxx integer X coordinate of the upper right corner of the box.
-- @param maxy integer Y coordinate of the upper right corner of the box.
-- @param maxz integer Z coordinate of the upper right corner of the box; can be omitted together with minz.
-- @return box.

function box(minx, miny, minz, maxx, maxy, maxz)
end

--- Returns a 3D box given the one of the box diagonals; if z1 and z2 omitted then a 2d box is returned; accepts also points as parameters.
-- @cstyle box box(int x1, int y1, int z1, int x2, int y2, int z2).
-- @cstyle box box(int x1, int y1, int x2, int y2).
-- @cstyle box box(point p1, point p2).
-- @return box.

function boxdiag(x1, y1, z1, x2, y2, z2)
end

--- Creates a box box described by origin and size vectors (points).
-- @cstyle box sizebox(point min, point size).
-- @cstyle box sizebox(point min, int width, int height).
-- @cstyle box sizebox(int left, int top, point size).
-- @param min point lower left corner of the box.
-- @param size point size vector of the box.
-- @return box.

function sizebox(...)
end

--- Rerurns the min point of the box.
-- @cstyle point box::min(box b).
-- @return point.

function box:min()
end

--- Returns the max point of the box.
-- @cstyle poin box::max(box b).
-- @return point.

function box:max()
end

--- Returns X coordinate of the min point of the box.
-- @cstyle int box::minx(box b).
-- @return int.

function box:minx()
end

--- Returns Y coordinate of the min point of the box.
-- @cstyle int box::miny(box b).
-- @return int.

function box:miny()
end

--- Returns Z coordinate of the min point of the box.
-- @cstyle int box::minz(box b).
-- @return int or nil(if the box is 2D).

function box:minz()
end

--- Returns X, Y, Z coordinate of the min point of the box.
-- @return int, int, int or nil(if the box is 2D).

function box:minxyz()
end

--- Returns X coordinate of the max point of the box.
-- @cstyle int box::maxx(box b).
-- @return int.

function box:maxx()
end

--- Returns Y coordinate of the max point of the box.
-- @cstyle int box::maxy(box b).
-- @return int.

function box:maxy()
end

--- Returns Z coordinate of the max point of the box.
-- @cstyle int box::maxz(box b).
-- @return int or nil(if the box is 2D).

function box:maxz()
end

--- Returns X, Y, Z coordinate of the max point of the box.
-- @return int, int, int or nil(if the box is 2D).

function box:maxxyz()
end

--- Returns the X size of the box.
-- @cstyle int box::sizex(box b).
-- @return int.

function box:sizex()
end

--- Returns the Y size of the box.
-- @cstyle int box::sizey(box b).
-- @return int.

function box:sizey()
end

--- Returns the Z size of the box.
-- @cstyle int box::sizez(box b).
-- @return int or nil(if the box is 2D).

function box:sizez()
end

--- Returns the X, Y, Z size of the box.
-- @return int, int, int or nil(if the box is 2D).

function box:sizexyz()
end

--- Returns the min x, min y, max x and max y of the box.
-- @return int, int, int, int.

function box:xyxy()
end

--- Returns the min x, min y, minz, max x, max y and max z of the box.
-- @return int, int, int, int, int, int.

function box:xyzxyz()
end

--- Returns the size of the box as a vector (point).
-- @cstyle int box::size(box b).
-- @return point.

function box:size()
end

--- Shows if the box points has valid Z coordinates.
-- @cstyle bool box::IsValidZ(box b).
-- @return bool.

function box:IsValidZ()
end

--- Shows if the min point coordinates of the box are less than or equal to its max point coordinates.
-- @cstyle bool box::IsValid(box b).
-- @return bool

function box:IsValid()
end

--- Returns the geometric center of the box as a point.
-- @cstyle point box::Center(box b).
-- @return point.

function box:Center()
end

--- Checks if a point is inside a box
-- @cstyle bool box::PointInside(point pt).
-- @cstyle bool box::PointInside(int x, int y, int z).
-- @cstyle bool box::PointInside(bool any, point pt1, point pt2, point p3, ...).
-- @cstyle bool box::PointInside(bool any, table pts).
-- @return bool.

function box:PointInside(pt, ...)
end

--- Checks if a point is inside a box (2D variant)
-- @cstyle bool box::Point2DInside(point pt).
-- @cstyle bool box::Point2DInside(int x, int y).
-- @cstyle bool box::Point2DInside(bool any, point pt1, point pt2, point p3, ...).
-- @cstyle bool box::Point2DInside(bool any, table pts).
-- @return bool.

function box:Point2DInside(pt, ...)
end

--- Computes the distance to another box or to a point
-- @cstyle int box::Dist(box b).
-- @cstyle int box::Dist(point p).
-- @return int.

function box:Dist(b)
end

--- Computes the 2D distance to another box or to a point
-- @cstyle int box::Dist2D(box b).
-- @cstyle int box::Dist2D(point p).
-- @return int.

function box:Dist2D(b)
end

--- Returns a box, created by moving given box with specified offset.
-- @cstyle point box::Offset(box b, point offset).
-- @param offset point.
-- @return box.

function Offset(box, offset)
end

--- Returns a box, created by scaling its boundaries by given promile.
-- If the box is with invalid Z, the z coordinate would be omitted.
-- A point can be provided as parameter which combines all three values.
-- If only one value is given the all three coordinates are scaled by the given value.
-- If scalex and scaley are only given scalez defaults 1000(don't scale).
-- @cstyle point box::Scale(box b, int scalex, int scaley, int scalez).
-- @param scalex int.
-- @param scaley int.
-- @param scalez int.
-- @return box.

function ScaleBox(box, scalex, scaley, scalez)
end

--- Returns a box, created by resizing given box to specified size.
-- @cstyle point box::Resize(box b, point size).
-- @param size point.
-- @return box.

function Resize(box, size)
end

--- Returns a box, created by moving given box to specified point.
-- @cstyle point box::Resize(box b, point pos).
-- @param pos point.
-- @return box.

function MoveTo(box, pos)
end

--- Returns the minimal box containing b1 and b2.
-- @cstyle box AddRects(box b1, box b2).
-- @param b1 box.
-- @param b2 box.
-- @return box.

function AddRects(b1, b2)
end

--- Returns a box obtained from intersection of the given boxes.
-- @cstyle box IntersectRects(box b1, box b2).
-- @param b1 box.
-- @param b2 box.
-- @return box.

function IntersectRects(b1, b2)
end

--- Returns the given param is box.
-- @cstyle bool IsBox(param).
-- @param box any.
-- @return bool.

function IsBox(param)
end

--- Extends a given box by other boxes or points.
-- Accepts any number of both points and boxes.
-- Gracefully returns if there is no input.
-- @cstyle box Extend(box b1, box b2, ...).
-- @cstyle box Extend(box b1, point p1, ...).
-- @return box.

function Extend(b1, b2, ...)
end

--- Returns a transformed box by rotation, translation and scaling.
-- @cstyle box Transform(box, angle, offset, axis, scale)
-- @param box box; box to be transformed
-- @param angle int; rotation angle.
-- @param offset point/object; translation offset.
-- @param axis point; rotation axis.
-- @param scale int; scaling percents.
-- @return box; the transformed box.

function Transform(box, angle, offset, axis, scale)
end

function TransformXYZ(box, angle, offset, axis, scale)
end