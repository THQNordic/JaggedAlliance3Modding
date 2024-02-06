--- Miscellaneous functions : math, console, graphics, translation and etc.

--- Prints the given text to the console
-- @cstyle void ConsolePrint(string text).
-- @param text string; the text to print.

function ConsolePrint(text)
end

--- Shows the given text in the the development environment (does not appear in the console log)
-- @cstyle void OutputDebugString(string text).
-- @param text string; the text to print.

function OutputDebugString(text)
end

--- Asynchronous random, mainly for use in async scripts.
-- @cstyle int AsyncRand().
-- @cstyle int AsyncRand(int max).
-- @cstyle int AsyncRand(int min, int max).
-- @cstyle int AsyncRand(array arr).
-- @return int/value rand; any random, random in the interval[0, max - 1], random in the interval [min, max], OR a random element from arr.

function AsyncRand(...)
end

--- Asynchronous random, mainly for use in async scripts.
-- @cstyle int BraidRandom(int seed).
-- @cstyle int BraidRandom(int seed, int max).
-- @cstyle int BraidRandom(int seed, int min, int max).
-- @cstyle int BraidRandom(int seed, array arr).
-- @return int/value rand; any random, random in the interval[0, max - 1], random in the interval [min, max], OR a random element from arr.
-- @return int seed; a new seed.

function BraidRandom(seed, ...)
end

--- Returns the result from the xxhash algorithm performed over its arguments
-- @cstyle int xxhash(type arg1, ...).
-- @param arg<i> can be any simple type or a userdata
-- @return int

function xxhash(arg1, arg2, arg3, ...)
end

--- Same as xxhash but accepts all parameter types. Tables, functions and threads are converted to memory addresses. Thus results will be different between game sessions.
-- @return int

function xxhash_session(arg1, arg2, arg3, ...)
end

--- Returns the absolute value of the given number.
-- @cstyle int abs(int nValue).
-- @param nValue int; the number for which to calculate the absolute value.
-- @return int; the absolute value of nValue.

function abs(nValue)
end

--- Returns the square root of the given number.
-- @cstyle int sqrt(int nValue).
-- @param nValue int; the number for which to calculate the square root.
-- @return int; the square root of nValue rounded to nearest integer smaller then the real square root.

function sqrt(nValue)
end

-- Translates a value from a linear set to a value in an exponential set with a matching start and end points, and a given exponent for t
-- @cstyle int LinearToExponential(uint value, uint exponent, uint min, uint max).
-- @param value uint; (min <= value <= max) The exponential value to be tranformed.
-- @param exponent uint; (exponent > 0) The exponent of t in the interpolation formula.
-- @param min uint; (min < max) The minimum value of both sets (start).
-- @param max uint; (max > min) The maximum value of both sets (end).
-- @return uint;

function LinearToExponential(value, exponent, min, max)
end

-- Reverses the translation done by LinearToExponential().
-- @cstyle int ExponentialToLinear(uint value, uint exponent, uint min, uint max).
-- @param value uint; (min <= value <= max) The exponential value to be tranformed.
-- @param exponent uint; (exponent > 0) The exponent of t in the interpolation formula.
-- @param min uint; (min < max) The minimum value of both sets (start).
-- @param max uint; (max > min) The maximum value of both sets (end).
-- @return uint;

function ExponentialToLinear(value, exponent, min, max)
end

--- Returns angle given normalized from -180*60 to 180*60.
-- @cstyle int AngleNormalize(int angle).
-- @param angle int; angle to normalize in minutes.
-- @return int.

function AngleNormalize(angle)
end

--- Returns the arcsine of the value given divided by 4096.
-- @cstyle int sin(int nValue).
-- @param nValue int; the value is between -4096 and 4096, and represents the interval -1..1.
-- @return int; Returns the arcsine in minutes. Safe to use in synched code, does not use floats.

function asin(nValue)
end

--- Returns the sine of the given angle.
-- @cstyle int sin(int nAngle).
-- @param nAngle the angle in minutes for which to calculate the sine.
-- @return int; Returns the sine of angle multiplied by 4096. Safe to use in synched code, does not use floats.

function sin(nAngle)
end

--- Returns the cosine of the given angle.
-- @cstyle int cos(int nAngle).
-- @param nAngle int; the angle in minutes for which to calculate the cosine.
-- @return int; Returns the cosine of angle multiplied by 4096. Safe to use in synched code, does not use floats.

function cos(nAngle)
end

--- Returns the angle corresponding to the given tangent
-- @cstyle int atan(int y, int x).
-- @param y int; can be the y coordinate, the tangent value scaled by 4096 or a point.
-- @param x int; the x coordinate, optional
-- @return int; Returns the angle multiplied by 4096. Safe to use in synched code, does not use floats.

function atan(mul, div)
end

--- Rounds a number according to the provided granularity.
-- @cstyle int round(int number, int granularity).
-- @param number int; the number to round.
-- @param number granularity; the granularity to use.
-- @return int; The rounded number.

function round(number, granularity)
end

--- Tests if a ray intersects a sphere.
-- @cstyle bool TestRaySphere(point rayOrg, point rayDir, point sphereCenter, int sphereRadius).
-- @param rayOrg point; origin of the ray.
-- @param rayDir point; direction of the ray.
-- @param sphereCenter point; center of the sphere.
-- @param sphereRadius int; radius of the sphere.
-- @return bool; true if the ray intersects the sphere, false otherwise.

function TestRaySphere(rayOrg, rayDir, sphereCenter, sphereRadius)
end

--- Checks and returns the result if a ray intersects an axis aligned bounding box.
-- @cstyle bool RayIntersectsSphere(point rayOrg, point rayDir, box b).
-- @param rayOrg point; origin of the ray.
-- @param rayDir point; destination(not direction) of the ray.
-- @param b box.
-- @return point/nil; Returns the intersection point if the ray intersects the box, nil otherwise.

function RayIntersectsAABB(rayOrg, rayDest, b)
end

--- Checks and returns the result if a segment intersects an axis aligned bounding box.
-- @cstyle bool, point SegmentIntersectsAABB(point pt1, point pt2, box b).
-- @param pt1 point; first vertex of the segment.
-- @param pt2 point; second vertex of the segment.
-- @param b box.
-- @return bool, point; Returns true, intersection if the ray intersects the box, false otherwise.

function SegmentIntersectsAABB(pt1, pt2, b)
end

--- Checks and returns the result if a ray intersects a sphere.
-- @cstyle bool RayIntersectsSphere(point rayOrg, point rayDir, point sphereCenter, int sphereRadius).
-- @param rayOrg point; origin of the ray.
-- @param rayDir point; direction of the ray.
-- @param sphereCenter point; center of the sphere.
-- @param sphereRadius int; radius of the sphere.
-- @return bool, point; Returns true, intersection if the ray intersects the sphere, false otherwise.

function RayIntersectsSphere(rayOrg, rayDir, sphereCenter, sphereRadius)
end

--- Checks and returns the result if a segment intersects a sphere.
-- @cstyle bool, point SegmentIntersectsSphere(point pt1, point pt2, point sphereCenter, int sphereRadius).
-- @param pt1 point; first vertex of the segment.
-- @param pt2 point; second vertex of the segment.
-- @param sphereCenter point; center of the sphere.
-- @param sphereRadius int; radius of the sphere.
-- @return bool, point; Returns true, intersection if the ray intersects the sphere, false otherwise.

function SegmentIntersectsSphere(pt1, pt2, sphereCenter, sphereRadius)
end

--- Tests if a sphere intersects another sphere.
-- @cstyle bool SphereTestSphere(point ptCenter1, int nRadius1, point ptCenter2, int nRadius2).
-- @param ptCenter1 point; center of the first sphere.
-- @param nRadius1 int; radius of the first sphere.
-- @param ptCenter2 point; center of the second sphere.
-- @param nRadius2 int; radius of the second sphere.
-- @return bool; true if the spheres intersect, false otherwise.

function SphereTestSphere(ptCenter11, nRadius1, ptCenter2, nRadius2)
end

--- Tests if a axis aligned bounding box intersects sphere.
-- @cstyle bool SphereTestSphere(box b, point ptCenter1, int nRadius1).
-- @param b box.
-- @param ptCenter1 point; center of the sphere.
-- @param nRadius1 int; radius of the sphere.
-- @return bool; true if the sphere intersect the box, false otherwise.

function AABBTestSphere(b, ptCenter1, nRadius1)
end

--- Tests if a axis aligned bounding box intersects another axis aligned bounding box.
-- @cstyle bool AABBTestAABB(box b1, box b2).
-- @param box b1.
-- @param box b2.
-- @return bool; true if the boxes intersect, false otherwise.

function AABBTestAABB(b, ptCenter1, nRadius1)
end

--- Performs a Hermite spline interpolation from position p1 with tangent m1 to position p2 and tangent m2.
-- @cstyle point/int HermiteSpline(point/int p1, point/int m1, point/int p2, point/int m2, int t, int scale = 65536).
-- @param p1 point/int; start control point.
-- @param m1 point/int; tangent at the start control point.
-- @param p2 point/int; end control point.
-- @param m2 point/int; tangent at the end control point.
-- @param t int; weighting factor between [0,scale].
-- @param scale int; factor scale, 65536 by default.
-- @return point/int; the interpolated point between control points according to t.

function HermiteSpline(p1, m1, p2, m2, t, scale)
end

--- Performs a Catmull-Rom spline interpolation using the 4 control points.
-- @cstyle point CatmullRomSpline(point p1, point p2, point p3, point p4, int t, int scale = 65536).
-- @param point p1; start control point.
-- @param point p2; second control point.
-- @param point p3; third control point.
-- @param point p4; fourth control point.
-- @param int t; weighting factor between [0,scale].
-- @param scale int; factor scale, 65536 by default.
-- @return point; the interpolated point between control points according to t.

function CatmullRomSpline(p1, p2, p3, p4, t, scale)
end

--- Returns bitwise AND of its arguments.
-- @cstyle int band(int n1, int n2, ...).
-- @param n1 int;
-- @return int; bitwise AND of the arguments.

function band(n1, n2, ...)
end

--- Returns bitwise OR of its arguments.
-- @cstyle int bor(int n1, int n2, ...).
-- @param n1 int;
-- @return int; bitwise OR of the arguments.

function bor(n1, n2, ...)
end

--- Returns bitwise XOR of its arguments.
-- @cstyle int bxor(int n1, int n2, ...).
-- @param n1 int;
-- @return int; bitwise XOR of the arguments.

function bxor(n1, n2, ...)
end

--- Returns bitwise NOT of its argument.
-- @cstyle int bnot(int n).
-- @param n int;
-- @return int; bitwise NOT of the argument.

function bnot(n)
end

--- Returns (flags & ~mask) | (value & mask).
-- @cstyle int maskset(int flags, int mask, int value).
-- @param flags int;
-- @param mask int;
-- @param value int;
-- @return int;

function maskset(flags, mask, value)
end

--- Logical left or right shift (not arithmetic). For right shift use negative count.
-- @cstyle unsigned int shift(unsigned int value, int count).
-- @param value unsigned int;
-- @param count int;
-- @return unsigned int; Returns (count > 0 ? (value << count) : (value >> -count)).

function shift(value, shift)
end

--- Returns whether any bits present in mask are present in flags. (bitwise and)
-- @cstyle bool IsFlagSet(int flags, int mask).
-- @param flags int;
-- @param mask int; the bits(s) to be tested.
-- @return bool; true if any of the bit(s) are set in the flags.
-- @see SetFlag.

function IsFlagSet(flags, mask)
end

--- Returns the less of the integers.
-- @cstyle int Min(int i1, int i2).
-- @param i1 int; the first number.
-- @param i2 int; the second number.
-- @return int; the smaller of i1 and i2.

function Min(i1, i2)
end

--- Returns the greater of the integers.
-- @cstyle int Max(int i1, int i2).
-- @param i1 int; the first number.
-- @param i2 int; the second number.
-- @return int; the bigger from i1 and i2.

function Max(i1, i2)
end

--- Returns the min & max of all provided parameters
function MinMax(i1, i2, ...)
end

--- Get the red, green and blue components from a RGB color variable.
-- @cstyle int, int, int GetRGB(int argb).
-- @param argb int; a RGB color variable.
-- @return int, int, int; red, green, blue triple of the RGB component.

function GetRGB(argb)
end

--- Get the red, green, blue and alpha components from a RGBA color variable.
-- @cstyle int, int, int, int GetRGBA(int argb).
-- @param argb a RGBA color variable.
-- @return int, int, int, int; red, green, blue, aplha four of the RGBA component.

function GetRGBA(argb)
end

--- Set the red component of a RGB color variable.
-- @cstyle int SetR(int argb, int r).
-- @param argb int; RGB color variable for which to set the red component.
-- @param r int; value of the red component.
-- @return int; RGB color variable with the new red component.

function SetR(argb, r)
end

--- Set the green component of a RGB color variable.
-- @cstyle int SetG(int argb, int g).
-- @param argb int; RGB color variable for which to set the green component.
-- @param g int; value of the green component.
-- @return int; RGB color variable with the new green component.

function SetG(argb, g)
end

--- Set the blue component of a RGB color variable.
-- @cstyle int SetB(int argb, int b).
-- @param argb int; RGB color variable for which to set the blue component.
-- @param b int; value of the blue component.
-- @return int; RGB color variable with the new blue component.

function SetB(argb, b)
end

--- Set the alpha component of a RGBA color variable.
-- @cstyle int SetA(int argb, int a).
-- @param argb int; RGBA color variable for which to set the alpha component.
-- @param a int; value of the alpha component.
-- @return int; RGBA color variable with the new alpha component.

function SetA(argb, b)
end

--- Combines r, g and b color channels into a single number used wherever an int rgb parameter is needed.
-- @cstyle int RGB(int r, int g, int b).
-- @param r int; intensity of the red component.
-- @param g int; intensity of the green component.
-- @param b int; intensity of the blue component.
-- @return int; RGB color variable with the corresponding components set.

function RGB(r, g, b)
end

--- Combines r, g, b and a color channels into a single number used wherever an int rgba parameter is needed.
-- @cstyle int RGBA(int r, int g, int b, int a).
-- @param r int; intensity of the red component.
-- @param g int; intensity of the green component.
-- @param b int; intensity of the blue component.
-- @param a int; intensity of the alpha component.
-- @return int; RGBA color variable with the corresponding components set.

function RGBA(r, g, b, a)
end

--- Interpolates linearly rgb0 to rgb1 as p goes from 0 to q.
-- @cstyle int InterpolateRGB(int rgb0, int rgb1, int p, int q).
-- @param rgb0 int; the starting RGB color variable.
-- @param rgb1 int; the final RGB color variable.
-- @param p int; the numerator.
-- @param q int; the divisor.
-- @return int; RGB color variable which is rgb0 + (p / q) * (rgb1 - rgb0).

function InterpolateRGB(rgb0, rgb1, p, q)
end

--- Compose a random opaque color with the given luminosity and maximum saturation level.
-- @cstyle int RandColor(int hue_seed = AsyncRand(), int lum_seed = AsyncRand())
-- @param hue_seed int. The random seed for hue (random number by default)
-- @param lum_seed int. The random seed for luminosity (random number by default)
-- @return int; RGB color.

function RandColor(hue_seed, lum_seed)
end

--- Get the color distance between two colors.
-- @cstyle int ColorDiff(int col1, int col2)
-- @return int; color dist.

function ColorDist(col1, col2)
end

--- Gets the current language used in the 
-- @cstyle string GetLanguage().
-- @return sting; the language currently used by the 

function GetLanguage()
end

--- Returns the current system tick count.
-- @cstyle int GetClock().
-- @return int.

function GetClock()
end

--- Returns v * m / d calculated with 64 bit integers. Truncates the result similar to plain division. Works on a point or a box as well.
-- @cstyle int/point MulDivTrunc(int/point/box v, int m, int d).
-- @param v int/point/box.
-- @param m int.
-- @param d int.
-- @return int.

function MulDivTrunc(v, m, d)
end

--- Returns v * m / d ROUNDED to the nearest integer, calculated with 64 bit integers as the C function MulDiv. Works on a point or a box as well.
-- @cstyle int/point MulDivRound(int/point/box v, int m, int d).
-- @param v int/point/box.
-- @param m int.
-- @param d int.
-- @return int.

function MulDivRound(v, m, d)
end

--- Returns m / d ROUNDED to the nearest integer
-- @cstyle int DivRound(int m, int d).
-- @param m int.
-- @param d int.
-- @return int.

function DivRound(m, d)
end

-- @cstyle bool IsPowerOf2(int v).
function IsPowerOf2(v)
end

--- Checks if the file creation date is older than specified days.
-- @cstyle bool FileAgeOlderThanDays(string filename, int days).
-- @param filename; string with the file to be checked.
-- @param days; specifies the period in days to check.
-- @return bool; false if the file was created before given days, true otherwise or if error occured during checking.

function FileAgeOlderThanDays(filename, days)
end

--- Check presence of internet connection.
-- @cstyle bool IsThereInternetConnection().
-- @return bool; true if internet connection exists, false otherwise.

function IsThereInternetConnection()
end

--- Ends antialiased and/or motion blurred screenshot
-- @cstyle void EndAAMotionBlurScreenshot(string filename, int samples)
-- @param filename; the target filename to save the screenshot
-- @param samples; the total number of samples added for this screenshot
function EndAAMotionBlurScreenshot(filename, samples)
end

--- Check the class of an object
-- @cstyle bool IsKindOf(table object, string class).
-- @return bool;
function IsKindOf(object, class)
end

--- Returns the first object from a given class in a list
-- @cstyle object FindFirstIsKindOf(table objects, string class).
-- @return object;
function FindFirstIsKindOf(objects, class)
end

function ConvertToOSPath(game_path)
end

function PlaneFromPoints(pt1, pt2, pt3, local_space)
end

--- Returns a value computed after following a list of instructions
-- @cstyle any compute(any initial_value, any instruction, ...).
-- @param initial_value; the initial value to start from. Returned if no instruction is given.
-- @param instruction; depending on the type of instruction:
--   type string, number, boolean: return compute(value[instruction], ...)
--   type table: return compute(instruction[value], ...)
--   type function: return instruction(value, ...)
--   any other type: return value
-- @return any;
function compute(value, instruction, ...)
--[[
	if type(instruction) == "string" or type(instruction) == "number" or type(instruction) == "boolean" then
		if type(value) == "table" then
			return compute(value[instruction], ...)
		end
		return
	elseif type(instruction) == "function" then
		return instruction(value, ...)
	elseif type(instruction) == "table" then
		return compute(instruction[value], ...)
	end
	return value
]]
end

--- Pseudo-random permutation generator based on prime number addition. Can generate only a small set of all permutations.
-- Usage: for _, n in permute(size, seed) do ... end
-- The value of n is in the range (1 .. size) in a random permutation (each value will be returned exacly once) order.
-- The value of _ is for internal use.
-- @cstyle void permute(int size, int/string/nil seed).
-- @param size - permutes the integers in the range (1 .. size)
-- @param int seed - initial seed, which defines the permutation order
-- @param string seed - InteractionRand(nil, seed) is used to get the seed
-- @param nil seed - AsyncRand() is used to get the seed
function permute(size, seed)
end
