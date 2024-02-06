--- UIL functions.

--- Draws a line between the two points using the specified or the default color.
-- @cstyle bool UIL.DrawLine(point pt1, point pt2, int color).
-- @param pt1 point; one end of the line segment.
-- @param pt2 point; the other end of the line segment.
-- @param color int; optional, color to use for drawing; default color will be used if not specified.
-- @return bool; true if the key is pressed; false otherwise.

function UIL.DrawLine(pt1, pt2, color)
end

--- Draws the specified texture in the specified screen rectangle with specified color modifier. The 
-- @cstyle void UIL.DrawTexture(int id, box rc, int color).
-- @param id; the id of the texture (see ResourceManager.GetResourceID).
-- @param rc; the screen rectangle to draw at.
-- @param color; (optional) color modifier to use for drawing.
-- @return void.
function UIL.DrawTexture(id, rc, color)
end

--- Push a modifier on the modifiers stack (to be called only during UIL redraw). Any draw 
-- primitive is affected by all modifiers that are on the stack at the time it is issued.
-- Parameter table for interpolations can have the following values:
-- - number type - interpolation type (const.intRect, const.intRotate, etc.)
-- - number start, duration - start time and duration (>= 0)
-- - number flags - a combination of flags, see values starting with const.intf (const.intfInverse, const.intfLooping, etc.)
-- - number easing - see values in const.Easing
-- - box originalRect, targetRect - define offset and scale (if type is const.intRect)
-- - point center; number startAngle, endAngle - rotation center and start/end angle in arc-minutes (360*60) (if type is const.intRotate); note that rotations do not stack - only the topmost is applied
-- - number startValue, endValue - start/end alpha, color or desaturation (if type is const.intAlpha, const.intColor or const.intDesaturation)
-- Parameter table for shader modifier can have the following values:
-- - string shader_pass - additional shader pass
-- - number param1,param2,param3,param4  - parmas for shader
-- @cstyle int UIL.PushModifier(table params).
-- @param params; table with modifier parameters.
-- @return int; if successful id of the previous topmost modifier or nil.
function UIL.PushModifier(params)
end

--- Returns the index of the interpolation on the stack top. 
-- @cstyle void UIL.ModifiersGetTop().
-- @return int; the index of the modifier at the stack top.
function UIL.ModifiersGetTop()
end

--- Pop all modifiers from the stack until the one with the provided index. The index used should be returned by PushModifier() or ModifiersGetTop().
-- @cstyle void UIL.InterpolationSetTop(int index).
-- @param index; interpolation index to remain on the stack top.
-- @return void.
function UIL.ModifiersSetTop(index)
end