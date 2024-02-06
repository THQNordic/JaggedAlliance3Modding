--- Quaternion functions.

--- Returns a quaternion with the specified axis and angle
-- @cstyle quaternion quaternion(point axis, int angle).
-- @param axis point
-- @param angle integer
-- @return quaternion.

function quaternion(axis, angle)
end

--- Returns a normalized quaternion
-- @cstyle quaternion quaternion:Norm(quaternion q).
-- @return quaternion.

function quaternion:Norm()
end

--- Returns an inverse quaternion
-- @cstyle quaternion quaternion:Inv(quaternion q).
-- @return quaternion.

function quaternion:Inv()
end

--- Returns the axis and angle composing the quaternion
-- @cstyle point, int quaternion:GetAxisAngle(quaternion q).
-- @return point, int.

function quaternion:GetAxisAngle()
end

--- Check if the given parameter is a quaternion
-- @cstyle bool IsQuaternion(quaternion q).
-- @param q quaternion.
-- @return bool.

function IsQuaternion(q)
end
