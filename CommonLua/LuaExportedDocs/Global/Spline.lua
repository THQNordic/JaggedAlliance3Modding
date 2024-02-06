--- Compute a min curvature spline specified by starting and ending point and direction.
-- Returns the control points of the resulting spline
-- @cstyle point[4] BS3_GetMinCurveSplineParams2D(point pos_start, point dir_start, point pos_end, point dir_end).
-- @param pos_start; start point.
-- @param dir_start; start direction.
-- @param pos_end; end point.
-- @param dir_end; end direction.
-- @return pt1,pt2,pt3,pt4
function BS3_GetMinCurveSpline2D(pos_start, dir_start, pos_end, dir_end)
end

--- Compute the minimum distance between two splines
-- Returns the distance found and the corresponding points from the two splines
-- @cstyle int, point, point, int BS3_GetSplineToSplineDist2D(point spline1[4], point spline2[4], int precision = guim/10).
-- @param spline1; first spline
-- @param spline2; second spline
-- @param precision; requested precision (min dist to be considered as 0)
-- @return dist, pt1, pt2
function BS3_GetSplineToSplineDist2D(spline1, spline2, precision)
end

--- Compute the minimum distance between a spline and a line
-- Returns the distance found and the corresponding points from the spline and the line
-- @cstyle int, point, point, int BS3_GetSplineToLineDist2D(point spline[4], point start_point, point end_point, int precision = guim/10).
-- @param spline; spline
-- @param start_point; line starting point
-- @param end_point; line ending point
-- @param precision; requested precision (min dist to be considered as 0)
-- @return dist, pt1, pt2
function BS3_GetSplineToLineDist2D(spline, start_point, end_point, precision)
end

--- Compute the minimum distance between a spline and a point
-- Returns the distance found and the corresponding point and coef from the spline
-- @cstyle int, point, int BS3_GetSplineToPointDist2D(point spline[4], point pos, int precision = guim/10).
-- @param spline; spline
-- @param pos; position
-- @param precision; requested precision (min dist to be considered as 0)
-- @return dist, pos, coef
function BS3_GetSplineToPointDist2D(spline, pos, precision)
end

--- Compute the minimum distance between a spline and a circle
-- Returns the distance found, the correspondings points and the coef from the spline
-- @cstyle int, point, point, int BS3_GetSplineToCircleDist2D(point spline[4], point center, int radius, int precision = guim/10).
-- @param spline; spline
-- @param center; circle center
-- @param radius; circle radius
-- @param precision; requested precision (min dist to be considered as 0)
-- @return dist, pos1, pos2, coef
function BS3_GetSplineToCircleDist2D(spline, center, radius, precision)
end

--- Estimate the spline length
-- @cstyle int BS3_GetSplineLength2D(point spline[4], int iterations = 20).
-- @param spline; spline
-- @param iterations; number of iterations
-- @return length
function BS3_GetSplineLength2D(spline, iterations)
end

--- Estimate if the spline length is shorter than a given length, and if so returns the new shorter length
-- @cstyle bool, int BS3_GetSplineLength2D(point spline[4], int length, int iterations = 20).
-- @param spline; the spline
-- @param length; the length to compare width
-- @param iterations; number of iterations
-- @return shorter_length; int
function BS3_IsSplineShorter2D(spline, length, iterations)
end

--- Check if the spline could be considered a line.
-- @cstyle bool BS3_IsSplineLinear2D(point spline[4], int max_angle = 1*60).
-- @param spline; spline
-- @param max_angle; max angle in minutes allowed so that the spline is stil considered linear
-- @return bool
function BS3_IsSplineLinear2D(spline, max_angle)
end