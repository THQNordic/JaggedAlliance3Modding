--- Entity and Game Object functions. 

--- Returns if the given param is a valid object, non yet destroyed by calling DoneObject.
-- @cstyle bool IsValid(object obj).
-- @param obj object.
-- @return type bool.

function IsValid(obj)
end

--- Returns index of a random spot of the speciifed type for the current or default state of the object (-1 if the object does not exists).
-- @cstyle int GetRandomSpot(string entity, int state, int typeID).
-- @param entity string.
-- @param state int.
-- @param typeID int.
-- @return int.

function GetRandomSpot(entity, state, typeID)
end

--- Returns the position of the spot in the given entity, relative to the entity center.
-- @cstyle point GetEntitySpotPos(string entity, int idx).
-- @param entity string entity name.
-- @param idx int the index of the spot.
-- @return point.

function GetEntitySpotPos(entity, idx)
end

--- Returns the angle(in minutes) of the spot in the given entity, relative to the entity center.
-- @cstyle int GetSpotAngle(string entity/object, int idx).
-- @param entity string entity name or object.
-- @param idx int the index of the spot.
-- @return int.

function GetEntitySpotAngle(entity, idx)
end

--- Returns the scale of the spot in the given entity
-- @cstyle int GetSpotScale(string entity, int idx) or object::GetSpotScale(, int idx).
-- @param entity string entity name or object.
-- @param idx int the index of the spot.
-- @return int.

function GetEntitySpotScale(entity, idx)
end

--- Returns the typeid of the given spot index.
-- @cstyle int GetSpotsType(string entity|object, int idx).
-- @param entity string.
-- @param idx int.
-- @return int returns the spot typeid.

function GetSpotsType(pchEnt, idx)
end

--- Returns true if the entity has this state.
-- @cstyle bool HasState(string entity, int state).
-- @param entity string; Entity name to be checked.
-- @param state int; State of the entity to be checked.
-- @return bool.

function HasState(entity, state)
end

-- Returns the step vector of the animation in state stateID of the given entity.
-- @cstyle point GetEntityStepVector(object self, [int stateID]).
-- @param entity string; name of the entity.
-- @param state int.
-- @return point.

function GetEntityStepVector(entity, state)
end

--- Places and inits object with some basic properties.

function PlaceAndInit(class, pos, angle, scale, axis)
end

--- Places and inits object with some basic properties, not using points to prevent unnecessary allocations.

function PlaceAndInit2(class, posx, posy, posz, angle, scale, axisx, axisy, axisz, state, groupID)
end

--- Groups specified objects together. NOTE: This calls Ungroup(list) first.
-- @cstyle void Group(objlist list).
-- @param list objlist.
-- @return void.

function Group(list)	
end

--- For all objects in list ungroups the WHOLE group the object is member of.
-- @cstyle void Ungroup(objlist list).
-- @param list objlist.
-- @return void.

function Ungroup(list)
end

--- Returns the topmost parent (the object itself, if not attached).
-- @cstyle object GetTopmostParent(object obj, string classname = false).
-- @param obj object.
-- @return type object.
function GetTopmostParent(obj, classname)
end

--- Creates a clone of an object copying all his properties to the clone
-- @cstyle object object:Clone(object self [, string classname]).
-- @param classname string; optional new class
-- @return object; Returns the clone created.
function object:Clone(classname)
end

--- Changes the class of an object. The new class should be compatible with the previous one (i.e. having the same class flags)
-- @cstyle object object:ChangeClass(object self, string classname).
-- @param classname string; the new class
function object:ChangeClass(classname)
end

--- Returns whether the object has an entity
-- @cstyle bool object::HasEntity(object self).
-- @return bool.
function object:HasEntity()
end

--- Returns the destlock of the specified object if any.
-- @cstyle object object::GetDestlock(object self).
-- @return object.

function object:GetDestlock()
end

--- If the given unit is moving, return his destination, otherwise returns his current position.
-- @cstyle point object::GetDestination(object self).
-- @return point.

function object:GetDestination()
end

--- For moving objects returns the vector difference between the starting and ending position of self object, but with length set to the distance traveled per second.
-- @cstyle point object::GetVelocityVector(object self, int delta = 0, extrapolate = false).
-- @return point.
function object:GetVelocityVector(delta, extrapolate)
end

--- For moving objects returns the length of the velocity vector.
-- @cstyle point object::GetVelocity(object self).
-- @return point.
function object:GetVelocity()
end

--- Returns the step length of the animation in state stateID.
-- @cstyle int object::GetStepLength(object this, int stateID).
-- @param stateID int; state for which to return the step length; if omitted the current state is used.
-- @return int.

function object:GetStepLength(stateID)
end

--- Returns the step vector of the animation in state stateID with the specified direction.
-- @cstyle int object::GetStepVector(object this, [int stateID], [int direction], [int phase], [int duration], [int step_mod]).
-- @param stateID int; state for which to return the step length; if omitted uses the current state.
-- @param direction int; angle in minutes at which the step vector is oriented;if omitted uses the current direction .
-- @param phase int; animation phase
-- @param duration int; duration in animation phases
-- @param step_mod int; percentage step modifier
-- @return int.
function object:GetStepVector(stateID, direction, phase, duration, step_mod)
end

--- Detaches the object from the map without destroying it (example - units entering buildings).
-- @cstyle void object::DetachFromMap(object this).
-- @return void.

function object:DetachFromMap()
end

--- Sets the entity of object this to newEntity.
-- @cstyle void object::ChangeEntity(object this, string newEntity).
-- @param newEntity string; name of the new entity to set.
-- @return void.

function object:ChangeEntity(newEntity)
end

--- Sets the color modifier for an object.
-- A per-component modifier to the final lit color of the object; RGB(100, 100, 100) means no modification.
-- @cstyle void object::SetColorModifier(object this, int colorModifier).
-- @param colorModifier int; the Color modifier.
-- @return void.

function object:SetColorModifier(colorModifier)
end

--- Returns the color modifier for an object.
-- A per-component modifier to the final lit color of the object; RGB(100, 100, 100) means no modification.
-- @cstyle int object::GetColorModifier(object this).
-- @return int.

function object:GetColorModifier()
end

--- Set new animation speed modifier, as promiles of original animation duration.
-- Animation duration and action moment times are affected by that modifier!.
-- @cstyle void object::SetAnimSpeedModifier(object this, int modifier).
-- @param modifier integer; speed modifier.
-- @return void.

function object:SetAnimSpeedModifier(modifier)
end

--- Return the current animation speed modifier as a promile.
-- Affects both animation duration and action moment!.
-- @cstyle int object::GetAnimSpeedModifier(object this).
-- @return int.

function object:GetAnimSpeedModifier()
end

--- Returns the last frame mark for the object. Frame marks advance for each frame drawn(main, shadows, reflection, etc.)
-- @cstyle int object::GetLastFrame(object this).
-- @return type.

function object:GetFrameMark()
end

--- Runs a pathfinder from the objects' current position to dst, follows the path and moves the object where it would be along the path at the specified time.
-- NOTE: It shouldn't be called on object executing a command.
-- @cstyle int object::GotoFastForward(object self, point dst, int time).
-- @param dst point; Destination of the object.
-- @param time int; Time for the object to go toward the destination.
-- @return int; Retruns the status of the operation, i.e. InProgress, Failed and so on.

function object:GotoFastForward(dst, time)
end

--- Attaches game object to another game object at spot of the parent game object.
-- @cstyle void object::Attach(object this, object child, int spot).
-- @param child object object to attach.
-- @param spot int spot at which to attach child object.
-- @return void.

function object:Attach(child, spot)
end

--- Detaches game object from its parent (its position remains where it is).
-- @cstyle void object::Detach(object this).
-- @return void.

function object:Detach()
end

--- Returns the number of current attached objects to our object.
-- @cstyle int object::GetNumAttaches(object this).
-- @return int.

function object:GetNumAttaches()
end

--- Get object(s) attached to a given object.
-- @cstyle object object::GetAttach(object this, int idx).
-- @cstyle object object::GetAttach(object this, string class, function filter).
-- @param idx int index of the attached object to get.
-- @param class string class of attached objects to get. Returns all matching attaches as tuple.
-- @param filter function to test if an attach is a match.
-- @return object.

function object:GetAttach(idx)
end

--- Get the spot index at which our object is attached to its parent.
-- @cstyle int object::GetAttachSpot(object this).
-- @return int.

function object:GetAttachSpot()
end

--- Get the parent object (if any).
-- @cstyle object object::GetParent(object this).
-- @return object or nil; nil means no parent.

function object:GetParent()
end

--- Returns the index of the first spot from the given type for the given or default state of the object (-1 if the object does not exist).
-- @cstyle int object::GetSpotBeginIndex(object this, int state, int typeID) or GetSpotBeginIndex(entity, int state, int typeID).
-- @param state int; This parameter is optional.
-- @param typeID int.
-- @return int.

function object:GetSpotBeginIndex(state, typeID)
end

--- Returns the index of the last spot from the given type for the given or default state of the object (-1 if the object does not exist).
-- @cstyle int object::GetSpotEndIndex(object this, int state, int typeID) or GetSpotEndIndex(entity, int state, int typeID).
-- @param state int; This parameter is optional.
-- @param typeID int.
-- @return int.

function object:GetSpotEndIndex(state, typeID)
end

--- Returns the index of the first and the last spot from the given type for the given or default state of the object (-1 if the object does not exist).
-- @cstyle int object::GetSpotRange(object this, int state, int typeID) or GetSpotRange(entity, int state, int typeID).
-- @param state int; This parameter is optional.
-- @param typeID int.
-- @return int.

function object:GetSpotRange(state, typeID)
end

--- Returns the index of the nearest to pt spot of the specified type for the current or default state of the object (-1 if the object does not exists).
-- @cstyle int object::GetNearestSpot(object this, int state, int typeID, point pt).
-- @param state int Optional parameter.
-- @param typeID int.
-- @param pt point.
-- @return int.

function object:GetNearestSpot(state, typeID, pt)
end

--- Returns index of a random spot of the speciifed type for the current or default state of the object (-1 if the object does not exists).
-- @cstyle int object::GetRandomSpot(object this, int state, int typeID).
-- @param state int; Optional paramater.
-- @param typeID int.
-- @return int.

function object:GetRandomSpot(state, typeID)
end

--- Returns the position of a random spot of the speciifed type for the current or default state of the object; if the spot doesn't exist returns nil.
-- @cstyle point object::GetRandomSpotPos(object this, int state, int typeID).
-- @param state int; Optional paramater.
-- @param typeID int.
-- @return point or nil.

function object:GetRandomSpotPos(state, typeID)
end

--- Returns whether the object has a specific spot type.
-- @cstyle bool object::HasSpot(object this, int state, int typeID) or HasSpot(string entity, int stateID, int typeID).
-- @param state int; Optional parameter when the first one is a game object.
-- @param typeID int.
-- @return bool.

function object:HasSpot(state, typeID)
end

--- Returns the position of the spot with the specified spotID.
-- @cstyle point object::GetSpotPos(object this, int spotID).
-- @param spotID int.
-- @return point or nil.

function object:GetSpotPos(spotID)
end

--- If the self object has a render object returns the VISUAL position of the spot with the specified spotID; otherwise it acts as GetSpotPos
-- @cstyle point object::GetSpotVisualPos(object self, int spotID).
-- @param spotID int.
-- @return point or nil.

function object:GetSpotVisualPos(spotID)
end

--- Returns the rotation (angle + axis) of the spot with the specified spotID (0 if the object or the spot does not exist).
-- @cstyle int, point object::GetSpotAxisAngle(object this, int spotID).
-- @param spotID int.
-- @return point, int.

function object:GetSpotAxisAngle(spotID)
end

--- Returns the spot annotation - a string with no predefined meaning, that can carry extra information related to certain spots.
-- @cstyle string object::GetSpotAnnotation(object this, int spotID).
-- @param spotID int.
-- @return string.

function object:GetSpotAnnotation(spotID)
end

--- Returns the height of the object (-1 if the object does not exists).
-- @cstyle int object::GetHeight(object this).
-- @return int.

function object:GetHeight()
end

--- Returns the radius of the bounding sphere of the current state of the object.
-- @cstyle int object::GetRadius(object this).
-- @return int.

function object:GetRadius()
end

--- Returns the bounding sphere of the current state of the object.
-- @cstyle point, int object::GetBSphere(object this).
-- @return point, int; center and radius of the object.

function object:GetBSphere()
end

--- Returns the bounding box of the current state of the object with mirroring applied, but without applying object's position, scale and orientation.
-- @cstyle box object::GetEntityBBox(object this).
-- @return box; The bounding box of the object's current state.

function object:GetEntityBBox()
end

--- Returns the name of the spot at index spotID.
-- @cstyle string object::GetSpotName(object this, int spotID) or string GetSpotName(string entity, int spotID)..
-- @param entity string or object instance.
-- @param spotID int.
-- @return string.

function object:GetSpotName(spotID)
end

--- Gets all GameObject flags of the object, ORed together ANDed the mask specified. 
-- @cstyle int object::GetGameFlags(object this, int mask = ~0).
-- @param mask int; Default mask = ~0.
-- @return int.

function object:GetGameFlags(object, mask)
end

--- Clears to 0 the specified GameObject game flags of the object.
-- @cstyle void object::ClearGameFlags(object this, int flags).
-- @param flags int; Specifies the flags to be cleared.
-- @return void.

function object:ClearGameFlags(flags)
end

--- Clears to 0 the specified GameObject game flags of the object and its attaches.
-- @cstyle void object::ClearHierarchyGameFlags(object this, int flags).
-- @param flags int; Specifies the flags to be cleared.
-- @return void.

function object:ClearHierarchyGameFlags(flags)
end

--- Sets to 1 the specified GameObject game flags of the object.
-- @cstyle void object::SetGameFlags(object this, int flags).
-- @param flags int; specifies the flags to be set.
-- @return void.

function object:SetGameFlags(flags)
end

--- Sets to 1 the specified GameObject game flags of the object and its attaches.
-- @cstyle void object::SetHierarchyFlags(object this, int flags).
-- @param flags int; specifies the flags to be set.
-- @return void.

function object:SetHierarchyGameFlags(flags)
end

--- Gets all MapObject flags of the object, ORed together ANDed the mask specified. 
-- @cstyle int object::GetEnumFlags(object this, int mask = ~0).
-- @param mask int; Default mask = ~0.
-- @return int.

function object:GetEnumFlags(mask)
end

--- Clears to 0 the specified MapObject flags of the object.
-- @cstyle void object::ClearEnumFlags(object this, int flags).
-- @param flags int; Specifies the flags to be cleared.
-- @return void.

function object:ClearEnumFlags(flags)
end

--- Clears to 0 the specified MapObject flags of the object and its attaches.
-- @cstyle void object::ClearHierarchyEnumFlags(object this, int flags).
-- @param flags int; Specifies the flags to be cleared.
-- @return void.

function object:ClearHierarchyEnumFlags(flags)
end

--- Sets to 1 the specified MapObject flags of the object.
-- @cstyle void object::SetEnumFlags(object this, int flags).
-- @param flags int; specifies the flags to be set.
-- @return void.

function object:SetEnumFlags(flags)
end

--- Gets all class flags of the object, ORed together ANDed the mask specified. 
-- @cstyle int object::GetClassFlags(object this, int mask = ~0).
-- @param mask int; Default mask = ~0.
-- @return int.

function object:GetClassFlags(mask)
end

--- Sets to 1 the specified MapObject flags of the object its attaches.
-- @cstyle void object::SetHierarchyEnumFlags(object this, int flags).
-- @param flags int; specifies the flags to be set.
-- @return void.

function object:SetHierarchyEnumFlags(flags)
end

--- Returns the interpolated position of the object, including a valid Z taken from the terrain.
-- @cstyle point object::GetVisualPos(object this, int time_offset, bool bExtrapolate).
-- @return point; the position of the object.

function object:GetVisualPos(time_offset, bExtrapolate)
end

function object:GetVisualPosXYZ(time_offset, bExtrapolate)
end

--- Returns the interpolated position of the object, including a valid Z taken from the terrain multiplied by factor.
-- @cstyle point object::GetVisualPosPrecise(object this, int factor).
-- @return point; the position of the object.

function object:GetVisualPosPrecise()
end

--- Returns the position of the object as point if it exists. Else returns point with invalid coordinates (-MAX_INT).
-- @cstyle point object::GetPos(object self).
-- @return point; The posiotion of the object.

function object:GetPos()
end

function object:HasFov(map_pos, fov_arc_angle, pos_offset_z, use_velocity_vector)
end

function object:GetRollPitchYaw()
end
function object:SetRollPitchYaw(roll, pitch, yaw)
end

--- Check if the object has a position on the map.
-- @cstyle bool object::IsValidPos().
-- @return bool;

function object:IsValidPos()
end

--- Converts a world position to local space.
-- @cstyle point object::GetLocalPoint(point world_pos).
-- @return point; the position in local space.

function object:GetLocalPoint(world_pos) end
function object:GetLocalPoint(x, y, z) end
function object:GetLocalPointXYZ(world_pos) end
function object:GetLocalPointXYZ(x, y, z) end

--- Converts a local position to world space.
-- @cstyle point object::GetRelativePoint(point local_pos).
-- @return point; the position in world space.

function object:GetRelativePoint(local_pos) end
function object:GetRelativePoint(x, y, z) end
function object:GetRelativePointXYZ(local_pos) end
function object:GetRelativePointXYZ(x, y, z) end

--- Returns the angle(in minutes) of the spot in the given object and its axis.
-- @cstyle int, point object:GetSpotAngle(int idx).
-- @param idx int the index of the spot.
-- @return int, point.

function object:GetSpotAngle(idx)
end

--- Returns the scale of the spot in the.
-- @cstyle int object:GetSpotScale(int idx) or object::GetSpotScale(, int idx).
-- @param idx int the index of the spot.
-- @return int.

function object:GetSpotScale(idx)
end

--- Returns the interpolated position of the object, without the Z value
-- @cstyle point object::GetVisualPos2D(object this).
-- @return point; the position of the object.

function object:GetVisualPos2D()
end

--- Returns the sound position and distance relative to the closest listener
-- @cstyle point, int object::GetSoundPosAndDist(object this).
-- @return point; the sound position.
-- @return int; the sound dist.

function object:GetSoundPosAndDist()
end

--- Set gravity acceleration for this object
-- @cstyle void object::SetGravity(int accel).
-- @param accel int.
-- @return void.

function object:SetGravity(accel)
end

--- Compute free fall time
-- @cstyle int object:GetGravityFallTime(int fall_height, int start_speed_z, int accel).
-- @param fall_height int
-- @param start_speed_z int; optional
-- @param accel int; optional
-- @return int.

function object:GetGravityFallTime(fall_height, start_speed_z, accel)
end

--- Compute such a travel time that the object would reach the specified z level
-- @cstyle int object::GetGravityHeightTime(point target, int height, int accel).
-- @param target point
-- @param height int; height to reach above the start/end positions
-- @param accel int; optional.
-- @return void.

function object:GetGravityHeightTime(target, height, accel)
end

--- Compute travel time for a given starting angle
-- @cstyle int object::GetGravityAngleTime(Point target, int angle, int accel).
-- @param target point
-- @param angle int; angle in minutes
-- @param accel int; optional.
-- @return void.

function object:GetGravityAngleTime(target, angle, accel)
end

--- Set linear acceleration for this object
-- @cstyle void object::SetAcceleration(int accel).
-- @param accel int.
-- @return void.
function object:SetAcceleration(accel)
end

--- Compute the acceleration and time needed to reach the target destination with the desired final velocity
-- @cstyle int object::GetAccelerationAndTime(Point destination, int final_speed, int starting_speed = object.GetVelocity()).
-- @param destination point
-- @param final_speed int; final speed when reaching the destination
-- @param starting_speed int; optional. The current speed when starting the interpolation.
-- @return int, int.

function object:GetAccelerationAndTime(destination, final_speed, starting_speed)
end

--- Compute the acceleration and starting speed needed to reach the target destination with the desired final velocity within given time period.
-- @cstyle int object::GetAccelerationAndStartSpeed(Point destination, int final_speed, int time).
-- @param destination point
-- @param final_speed int; final speed when reaching the destination
-- @param time int; movement time.
-- @return int, int.

function object:GetAccelerationAndStartSpeed(destination, final_speed, time)
end

--- Compute the acceleration and final speed needed to reach the target destination with the desired starting velocity within given time period.
-- @cstyle int object::GetAccelerationAndStartSpeed(Point destination, int final_speed, int time).
-- @param destination point
-- @param starting_speed int; starting speed
-- @param time int; movement time.
-- @return int, int.

function object:GetAccelerationAndFinalSpeed(destination, starting_speed, time)
end

function object:GetFinalSpeedAndTime(destination, acceleration, starting_speed)
end

function object:GetFinalPosAndTime(final_speed, acceleration)
end

--- Activates arc movement
-- @cstyle void object::SetCurvature(bool set)
function object:SetCurvature(set)
end

--- Checks if arc movement is active
-- @cstyle bool object::GetCurvature()
function object:GetCurvature()
end

--- Computes arc movement time
-- @cstyle int object::GetCurvatureTime(point pos, int angle [, point axis, int speed])
-- @param pos point; target point.
-- @param angle int; target angle.
-- @param axis point; optional axis. If not provided, the object's current axis is used.
-- @param speed int; optional speed. If not provided, the object's current speed is used.
-- @return int.
function object:GetCurvatureTime(pos, angle, axis, speed)
end

--- Changes postion of the object to pos smoothly for the specified time.
-- @cstyle void object::SetPos(object this, point pos, int time).
-- @param pos point; the new position of the object; must be in the map rectangle.
-- @param time int.
-- @return void.

function object:SetPos(pos, time)
end

--- Changes postion of the object to the current position of the given spot of the target object smoothly for the specified time.
-- @cstyle point object::SetLocationToObjSpot(object this, object target_obj, int spotidx, int time = 0).
-- @param target_obj object; specifies the target object.
-- @param spotidx int; specifies the spot of the target object.
-- @param time int; if time is nil the default value is 0 i.e set the new position right away.
-- @return void.

function object:SetLocationToObjSpot(this, target_obj, spotidx, time)
end

--- Changes postion of the object to the current position of a random spot of given type of the target object smoothly for the specified time.
-- @cstyle point object::SetLocationToRandomObjSpot(object this, object target_obj, int spot_type, int time = 0).
-- @param target_obj object specifies the target object.
-- @param spot_type int specifies the spot type.
-- @param time if time is nil the default value is 0, or set the new position right away.
-- @return void.

function object:SetLocationToRandomObjSpot(this, target_obj, spot_type, time)
end

--- Changes postion of the object to the current position of a random spot of given type in specified state of the target object smoothly for the specified time.
-- @cstyle point object::SetLocationToRandomObjSpot(object this, object target_obj, int spotidx, int time = 0).
-- @param target_obj object specifies the target object.
-- @param state int specifies the state.
-- @param spot_type int specifies the spot type.
-- @param time if time is nil the default value is 0, or set the new position right away.
-- @return void.

function object:SetLocationToRandomObjStateSpot(this, target_obj, state, spot_type, time)
end

--- Returns the angle of the object at which it is rotated around its rotation axis.
-- @cstyle int object::GetAngle(object this).
-- @return int in minutes.

function object:GetAngle()
end

--- Smoothly turns the object to the given angle around the rotation axis for the specified time.
-- @cstyle void object::SetAngle(object this, int angle, int time).
-- @param angle int; the angle in minutes.
-- @param time int; the time in ms for which the angle should be changed.
-- @return void.

function object:SetAngle(angle, time)
end

--- Returns the interpolated angle of the object in arcseconds.
-- @cstyle int object::GetVisualAngle(object this).
-- @return int; in minutes.

function object:GetVisualAngle()
end

--- Smoothly turns the object this to face point pt for the specified time.
-- @cstyle void object::Face(object this, point target, int time).
-- @cstyle void object::Face(object this, object target, int time).
-- @cstyle void object::Face(object this, object target, int time, spot, point offset).
-- @param target point/object; The point or object to face.
-- @param spot/offset; offset is relative to spot coordinate systemn 
-- @param time int; The time in 1/1000 sec for which the full turn should be performed.
-- @return void.

function object:Face(pt, time)
end

--- Returns the rotation axis of the object.
-- @cstyle point object::GetAxis(object this).
-- @return point; The axis vector of the given object.

function object:GetAxis()
end

--- Returns the intepolated rotation axis of the object.
-- @cstyle point object::GetVisualAxis(object this).
-- @return point; The exact axis vector of the given object.

function object:GetVisualAxis()
end


function object:GetVisualAxisXYZ()
end

--- Smoothly changes the object rotation axis over the specified time.
-- @cstyle void object::SetAxis(object this, point axis, int time).
-- @param axis point; that is the axis vector.
-- @param time int; the time in 1/1000 sec for which the angle should be changed.
-- @return void.

function object:SetAxis(axis, time)
end

--- Smoothly turns the object to the given axis and angle for the specified time. This method ensures proper interpolation avoiding discontinuities.
-- @cstyle void object::SetAxisAngle(object this, point axis, int angle, int time).
-- @param axis point; that is the axis vector.
-- @param angle int; the angle in minutes.
-- @param time int; the rotation time in ms.
-- @return void.

function object:SetAxisAngle(axis, angle, time)
end

function object:SetPosAxisAngle(pos, axis, angle, time)
end

--- Inverts the object's rotation axis.
-- @cstyle void object::InvertAxis().
-- @return void.

function object:InvertAxis()
end

--- Sets the direction (a 3D vector) the object's top is facing with an optional angle of rotation around the direction axis. If the 'time' property is specified, the object will reach the orientation specified in 'time' ms.
-- @cstyle void object::SetOrientation(point direction, int angle = 0, int time = 0).
-- @param direction point.
-- @param angle int; in minutes.
-- @param time int; in ms.

function object:SetOrientation(dir, angle, time)
end

--- Returns the direction the object's top is facing and the angle it's rotated around this axis.
-- @cstyle point, int object::GetOrientation().
-- @param time point, int.

function object:GetOrientation()
end

--- Rotates the object around the given axis and angle taking into account current object's orientation.
-- @cstyle void object::Rotate(object this, point axis, int angle, int time).
-- @param axis point; that is the axis vector.
-- @param angle int; the angle in minutes.
-- @param time int; the time in 1/1000 sec for which the angle should be changed.
-- @return point.

function object:Rotate(this, axis, angle, time)
end

--- Returns the object's visual face direction.
-- @cstyle int object::GetFaceDir(object self, int len).
-- @param len int; The desired length of the result vector.
-- @return point.

function object:GetFaceDir(len)
end

--- Returns angle to add to the current orientation angle of self object, so that the self object would face the other object.
-- @cstyle int object::AngleToObject(object self, object other).
-- @param other object.
-- @return int; angle from -180*60 to 180*60 (minutes).

function object:AngleToObject(other)
end

--- Returns angle to add to the current orientation angle of self object, so that the self object would face the point specified.
-- @cstyle int object::AngleToObject(object self, point pt).
-- @param pt point.
-- @return int; angle from -180*60 to 180*60 (minutes).

function object:AngleToPoint(point)
end

--- Returns the vector difference between the positions of self and other objects.
-- @cstyle int object::VectorTo2D(object self, object other).
-- @param other object.
-- @return int.

function object:VectorTo2D(other)
end

--- Returns the distance from self to the given object.
-- @cstyle int object::GetDist2D(object self, object other).
-- @param other object.
-- @return int.
function object:GetDist2D(other)
end

--- Returns a predicted position of the object after a time interval elapses.
-- The function uses the interpolation data from the last call to the object's 'SetPos' to return
-- a predicted position if no other call to 'SetPos' is made in the meantime. Have in mind that
-- this prediction has some problems with attached object if the extrapolate flag is true.
-- @cstyle point object::PredictPos(object self, int time, bool extrapolate).
-- @param time int - how many milliseconds ahead to predict; negative values will return former object positions.
-- @param extrapolate bool - whether to extrapolate beyond the time of the last 'SetPos'.
-- @return point.

function object:PredictPos(time, extrapolate)
end

--- Returns the visual(EXACT) distance from self to the given object.
-- @cstyle int object::GetVisualDist2D(object self, object other).
-- @param other object.
-- @return int.

function object:GetVisualDist2D(other)
end

--- Returns the distance from self to the given object.
-- @cstyle int object::GetDist(object self, object other).
-- @param other object.
-- @return int.

function object:GetDist(other)
end

--- Returns the visual(EXACT) distance from self to the given object.
-- @cstyle int object::GetVisualDist(object self, object other).
-- @param other object.
-- @return int.
function object:GetVisualDist(other)
end


--- Returns integer identifying the player whose is this object. Returns -1 if the object does not exist.
-- @cstyle int object::GetPlayer(object this).
-- @return int.

function object:GetPlayer()
end

--- Changes the player whose is this object to specified player.
-- @cstyle void object::SetPlayer(object this, int player).
-- @param player int; player number.
-- @return void.

function object:SetPlayer(player)
end

--- Set state nState to the object.
-- @cstyle int object::SetState(object this, int nState, int nFlags, int tCrossfade, int nSpeed, bool bChangeOnly).
-- @param nState int.
-- @param nFlags int; optional anim flags
-- @param tCrossfade int; optional custom crossfade time
-- @param nSpeed int; optional custom anim speed
-- @param bChangeOnly bool; optional skip the anim set if already the same
-- @return int; duration of the animation.

function object:SetState(nState, nFlags, tCrossfade, nSpeed, bChangeOnly)
end

--- Set state nState to the object and sleep the calling thread for a number of animation cycles or time.
-- @cstyle int object::PlayState(object this, int nState, int count).
-- @param nState int.
-- @param count int; if positive it's the number of animation loops to sleep; otherwise it specifies the amount of time to sleep.

function object:PlayState(nState, count)
end

--- Returns the current state of the object (-1 on invalid object).
-- @cstyle int object::GetState(object this).
-- @return int.

function object:GetState()
end

--- Freezes the object in a single frame of the specified animation; the frame is speficied by the time from animation start.
-- @cstyle void object::SetStaticFrame(object this, int nState, int nTime).
-- @param nState int.
-- @param nTime int.
-- @return void.

function object:SetStaticFrame(nState, time)
end

--- Returns true if the object's entity has this state.
-- @cstyle bool object::HasState(object this, int state).
-- @param state state of the obejct's entity to be checked.
-- @return bool.

function object:HasState(state)
end


--- Returns the scale of the object (-1 if the object does not exist).
-- @cstyle int object::GetScale(object this).
-- @return int.

function object:GetScale()
end

--- Sets the specified scale to the object if it exists.
-- @cstyle void object::SetScale(object this, int scale).
-- @param scale int.
-- @return void.

function object:SetScale(scale)
end

--- Return the final scaling of an object, that take into account parent object scale and spot's scale to which the object is attached.
-- @cstyle int object::GetWorldScale(object this).
-- @return int.

function object:GetWorldScale()
end

--- Returns the duration of the animation assigned with the specified state (returns -1 if the object does not exist);apply speed modifiers when used with object parameter.
-- @cstyle int object::GetAnimDuration(object this, int state) or GetAnimDuration(entity, int state).
-- @param state int; If parameter is ommited the funtion return the animation duration of the current state.
-- @return int.

function object:GetAnimDuration(state)
end

--- Returns how much time has passed since current animation started (time from last call to SetState).
-- @cstyle int object::TimeFromAnimStart(object this).
-- @return int.

function object:TimeFromAnimStart()
end

--- Returns remaining time to the end of currently played animation of the object. Modified by animation speed modifier!.
-- @cstyle int object::TimeToAnimEnd(object this).
-- @return int.

function object:TimeToAnimEnd()
end

--- Returns remaining time to the end of currently interpolated position change.
-- @cstyle int object::TimeToPosInterpolationEnd(object this).
-- @return int.

function object:TimeToPosInterpolationEnd()
end

--- Returns remaining time to the end of currently interpolated angle change.
-- @cstyle int object::TimeToAngleInterpolationEnd(object this).
-- @return int.

function object:TimeToAngleInterpolationEnd()
end

--- Returns remaining time to the end of currently interpolated angle change.
-- @cstyle int object::TimeToAxisInterpolationEnd(object this).
-- @return int.

function object:TimeToAxisInterpolationEnd()
end

--- Returns the max remaining time to the end of currently interpolated pos, angle and axis changes.
-- @cstyle int object::TimeToInterpolationEnd(object this).
-- @return int.

function object:TimeToInterpolationEnd()
end

--- Stops the pos, angle and axis interpolations.
-- @cstyle void object::StopInterpolation(object this).
-- @return void.

function object:StopInterpolation()
end

--- Returns whether an object is in a group.
-- @cstyle bool object::IsGrouped(object this).
-- @return bool.
-- @see Group.
-- @see Ungroup.

function object:IsGrouped()
end

--- Changes object's sound.
-- @cstyle void object::SetSound(string sound[, string type], int volume = -1, int fade_time = 0, bool looping).
-- @param sound string; either a sound file or a sound bank.
-- @param type string; sound type. used if sound is a file name. if sound is a sound bank it has to be omitted.
-- @param volume int; specifying the volume of the sound between 0 and 1000 (default is used the sound bank volume).
-- @param fade_time int; the cross-fade time if changing the sound state.
-- @param looping bool; specifies if the sound should be looping. (Use the sound bank flag by default)
-- @param loud_distance int; specifies if the distance whithin which the sound is played at max volume
-- @return bool; true if the operation is successful;

function object:SetSound(sound, __type, volume, fade_time, looping, loud_distance)
end

--- Changes object's sound state to silent. Breaks the current object sound, if playing.
-- @cstyle void object::StopSound(object this, int fade_time = 0).
-- @return void.

function object:StopSound(fade_time)
end

--- Changes object's sound volume.
-- @cstyle void object::SetSoundVolume(int volume, int time = 0).
-- @param volume int; volume between 0 and 1000.
-- @param time int; interpolation time, 0 by default.
-- @return void.

function object:SetSoundVolume(volume, time)
end

--- Returns the color modifier of an object.
-- @cstyle int object::GetColorModifier().
-- @return int; As argb.

function object:GetColorModifier()
end

--- Sets the color modifier of an object.
-- @cstyle void object::SetColorModifier(int argb).
-- @param argb int as argb.
-- @return void.

function object:SetColorModifier(argb)
end

--- Returns the opacity the object is rendered with.
-- @cstyle int object::GetOpacity(object this).
-- @return int; Returns the opacitiy of the object - 0 for invisible to 100 for visible intransparent.
function object:GetOpacity()
end

--- Set object's rendering opacity.
-- @cstyle void object::SetOpacity(object this, int val, int time, bool recursive).
-- @param val int; 0 for invisible to 100 for visible intransparent.
-- @return void.

function object:SetOpacity(val, time, recursive)
end

--- Specifies a new texture for the objetct's model; DEBUG PURPOSES ONLY!.
-- @cstyle void object::SetDebugTexture(string texture_file).
-- @param texture_file string; the path to the new texture.
-- @return void.
function object:SetDebugTexture(texture_file)
end

--- Destroys the render object of the self object.
-- @cstyle void object::DestroyRenderObj(object self).
-- @return void.

function object:DestroyRenderObj()
end

--- Return the number of triangles in the given object's model; use these only for diagnostic, because they precache object geometry.
-- @cstyle int object::GetNumTris(object self).
-- @return int.
function object:GetNumTris()
end

--- Return the number of vertices in the given object's model; use these only for diagnostic, because they precache object geometry.
-- @cstyle int object::GetNumVertices(object self).
-- @return int.
function object:GetNumVertices()
end

--- Returns the name of the self particle object.
-- @cstyle string object::GetParticlesName(object self).
-- @return string.
function object:GetParticlesName()
end

--- Gets the current self illumination modulation.
-- @cstyle int object::GetSIModulation().
-- @return int; 0 for no self illumination; 100 for max self illumination.

function GetSIModulation()
end

--- Sets the current self illumination modulation.
-- @cstyle void object::SetSIModulation(int modulation).
-- @param modulation int; 0 for no self illumination; 100 for max self illumination.
-- @return void.

function SetSIModulation(modulation)
end

--- Finds the nearest object from the given object list to the given point.
-- @cstyle object FindNearestObject(objlist ol, point pt[, function filter]).
-- @param ol; the object list to search in.
-- @param pt; the point or object to which distance is measured; if the point is with invalid Z the measured distances are 2D, otherwise they are 3D.
-- @param filter; optional object filter.
-- @return object or false (if the object list is empty).

function FindNearestObject(objlist, pt, filter)
end

-- Returns a table with all valid states for current object.
-- @cstyle table EnumValidStates() or EnumValidStates(entity)
function EnumValidStates()
end

function object:GetAnim(channel)
end

--- Returns a table with all anim info.
-- @cstyle table object::GetAnimDebug( int channel ).
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @return table; The channel animation info.
function object:GetAnimDebug(channel)
end

--- Set new animation to an object's animation channel.
-- @cstyle void object::SetAnim( int channel, int anim, int flags = 0, int crossfade = -1, int speed = 1000, int weight = 100, int phase = 0 ).
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @param anim int; the animation (state) to set.
-- @param flags int; the animation flags, see geObject.h for details.
-- @param crossfade int; the animation crossfade time, see geObject.h for details.
-- @param speed int; the animation speed, normal speed is 1000, can be ignored via the flags.
-- @param weight int; the animation weight, relative to the other animation weights. weight = 0 will hide the animation.
-- @param phase int; the animation phase.
-- @return void.

function object:SetAnim(channel,anim,flags,crossfade,speed,weight,phase)
end

--- Returns the animation flags of object's animation channel.
-- @cstyle int object::GetAnimFlags( int channel = 0 ).
-- @param channel int; the index of the channel, 1 <=  channel <= 8
-- @return int; The channel animation flags.

function object:GetAnimFlags(channel)
end

--- Return the current animation speed for an object's channel
-- @cstyle int object::GetAnimSpeed( int channel = 0 ).
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @return int; Current animation speed in promiles.

function object:GetAnimSpeed(channel)
end

--- Set the new object's animation channel speed.
-- @cstyle void object::SetAnimSpeed( int channel, int speed, int time = 0 ).
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @param speed int; the new speed to set in promiles, speed >= 0.
-- @param time int; the time we want the animation to reach the given speed, relative to the current time, so time=0 means right now.
-- @return void.

function object:SetAnimSpeed(channel,speed,time)
end

--- Return the animation weight of object's animation channel.
-- @cstyle int object::GetAnimWeight( int channel = 0 ).
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @return int; Current animation weight.

function object:GetAnimWeight(channel)
end

--- Set the new object's animation channel weight.
-- @cstyle void object::SetAnimWeight( int channel, int weight, int time = 0 ).
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @param weight int; the new weight to set, weight >= 0.
-- @param time int; the time we want the animation to reach the given weight, relative to the current time, so time=0 means right now.
-- @return void.

function object:SetAnimWeight(channel,weight,time,easing)
end

--- Return the animation start time of object's animation channel.
-- @cstyle int object::GetAnimStartTime( int channel ).
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @return int; Animation start time.

function object:GetAnimStartTime(channel)
end

--- Set the object's animation channel animation start time.
-- @cstyle void object::SetAnimStartTime( int channel, int time ).
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @param time int; the new animation start time, absolute.
-- @return void.

function object:SetAnimStartTime(channel,time)
end

--- Returns the object's animation channel current animation phase (offset from the beginning, 0 <= phase <= duration), which can be zero only for non-looping animations.
-- @cstyle int object::GetAnimPhase( int channel = 0 ).
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @return int; animation phase.

function object:GetAnimPhase(channel)
end

--- Set the object's animation channel new phase.
-- @cstyle void object::SetAnimPhase( int channel, int phase ).
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @return void.

function object:SetAnimPhase(channel,phase)
end

--- Clears the animation channel of an object. Works only for 2 <= channel <= 8.
-- @cstyle void object::ClearAnim( int channel ).
-- @param channel int; the index of the channel, 2 <= channel <= 8.
-- @return void.

function object:ClearAnim(channel)
end

--- Returns if an animation is used in any animation channel of an object.
-- @cstyle bool object::HasAnim( int anim ).
-- @param anim int; the animation (state) to check for.
-- @return bool; animation is used.

function object:HasAnim(anim)
end

--- Returns if an animation is used in any animation channel of an object and in what channel exactly.
-- @cstyle int object::FindAnimChannel( int anim ).
-- @param anim int; the animation (state) to check for.
-- @return int; the first animation channel who uses the animation, 0 if not present.

function object:FindAnimChannel(anim)
end

--- Returns if the base state (channel=1) is static (not animated).
-- @cstyle bool object::IsStaticAnim() or IsStaticAnim(entity).
-- @return bool; true if the state is not-animated, false otherwise.

function object:IsStaticAnim()
end

--- Returns if an object's animation channel animation is looping or not.
-- @cstyle bool object::IsAnimLooping( int channel = 0 ).
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @return bool; true if the animation is looping, false otherwise.

function object:IsAnimLooping(channel)
end

--- Returns the index of the animation component of the current animation of channel with the specified label
-- @cstyle int object::GetAnimComponentIndexFromLabel(int channel)
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @param label string; the label of the desired animation component, specified in the AnimComponentDef
-- @ return int; a positive index if the animation component exists, 0 otherwise

function object:GetAnimComponentIndexFromLabel(channel, label)
end

--- Sets the runtime parameters for the animation component running on channel
-- @cstyle void object::SetAnimComponentTarget(int channel, int animComponentIndex, params...)
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @param animComponentIndex int; the index of the animation component, 1 <= index <= 3
-- @param params ...; number and type of parameters depends on the animation component type. can be gameObject and spotName, position or other special values
-- @ return void; 

function object:SetAnimComponentTarget(channel, animComponentIndex, params)
end

--- Removes the targets of an animation component(s) running on a channel
-- @cstyle int object::RemoveAnimComponentTarget(int channel)
-- @cstyle int object::RemoveAnimComponentTarget(int channel, int animComponentIndex)
-- @param channel int; the index of the channel, 1 <= channel <= 8.
-- @param animComponentIndex int; the index of the animation component, 1 <= index <= 3. if missing, removes the targets of all components
-- @ return void;

function object:RemoveAnimComponentTarget(channel, animComponentIndex)
end

--- Return whether an error occured while loading this state; precaches the state if it isn't loaded (slow!).
-- @cstyle bool IsErrorState( entity, anim ) or  bool object::IsErrorState( entity, anim ).
-- @param entity string; the entity name.
-- @param anim int; the animation (state).
-- @return bool; is this an "error" state (rotating cube).

function IsErrorState(entity, anim)
end

--- Return if the animation (state) is looping or not.
-- @cstyle bool IsEntityAnimLooping( entity, anim ).
-- @param entity string; the entity name.
-- @param anim int; the animation (state).
-- @return bool; Is animation looped or not.

function IsEntityAnimLooping(entity, anim)
end

--- Returns the number of valid states for current object.
--@cstyle int obj:GetNumStates() or int GetNumStates(entity).
function GetNumStates()
end

--- Returns the state of the Mirrored flag for current object.
-- @cstyle bool GetMirrored()
-- @return bool, true if Mirrored is set
function GetMirrored()
end

--- Tests if a vertical ray through given point is intersecting the current object or not.
-- @cstyle bool IsPointOverObject()
-- @return bool; true if there is intersection point.
function IsPointOverObject()
end

--- Sets an indexed userdata value for current object.
-- @cstyle void SetCustomData(int index, value)
-- @param index int; the index of the userdata value
-- @param value uint32 or pstr; the value to set
function SetCustomData(index, value)
end

--- Gets an indexed userdata value from current object.
-- @cstyle uint32 GetCustomData(int index)
-- @param index int; the index of the userdata value
-- @return int; the specified userdata value
function GetCustomData(index)
end

--- Gets the bbox formed by the requested surfaces of the coresponding object.
-- @cstyle box, int GameObject::GetSurfacesBBox(int request_surfaces = -1, int fallback_surfaces = 0)
-- @param request_surfaces int; the requested surfaces (e.g. EntitySurfaces.Selection + EntitySurfaces.Build). By default (-1) all surfaces are requested.
-- @param fallback_surfaces int; fallback case if the requested surfaces are missing. By default (0) no falllback will be matched.
-- @return box; the resulting bounding box
-- @return int; the matched surface flags
function object:GetSurfacesBBox(request_surfaces, fallback_surfaces)
end


--- Return a list with attached objects.
-- @cstyle GameObject* GameObject::GetAttaches(string *classes = null)
-- @param classes table; List of attach classes. This parameter is optional.
function object:GetAttaches(classes)
end

--- Destroy attached objects and return their count.
-- @cstyle int GameObject::DestroyAttaches(string *classes = null, function filter = null)
-- @param classes table; List of class names or single class name. This parameter is optional.
-- @param exec function; Callback function. First parameter if class is omitted. This parameter is optional. Accepts variable number of parameters.
function object:DestroyAttaches(classes, filter, ...)
end

--- Count attached objects.
-- @cstyle int GameObject::CountAttaches(string *classes = null, function filter = null)
-- @param classes table; List of class names or single class name. This parameter is optional.
-- @param exec function; optional callback function. First parameter if class is omitted. This parameter is optional. Accepts variable number of parameters.
function object:CountAttaches(classes, filter, ...)
end

--- Call a lua callback function for each attach and return the number of callbacks.
-- @cstyle int GameObject::ForEachAttach(string *classes, function exec)
-- @param classes table; List of class names or single class name. This parameter is optional.
-- @param exec function; Callback function. First parameter if class is omitted. The loop is terminated if true equivalent value is returned. Accepts variable number of parameters.
function object:ForEachAttach(classes, exec, ...)
end

--- Check if the object has a valid Z coordinate.
-- @cstyle bool GameObject::IsValidZ()
function object:IsValidZ()
end

--- Check if the object has the same position.
-- @cstyle bool object::IsEqualPos(point).
-- @return bool;
function object:IsEqualPos(pos)
end

--- Check if the object has the same 2D position.
-- @cstyle bool object::IsEqualPos2D(point).
-- @return bool;
function object:IsEqualPos2D(pos)
end

--- Check if the object has the same visual position.
-- @cstyle bool object::IsEqualVisualPos(point).
-- @return bool;
function object:IsEqualVisualPos(pos)
end

--- Check if the object has the same visual 2D position.
-- @cstyle bool object::IsEqualVisualPos2D(point).
-- @return bool;
function object:IsEqualVisualPos2D(pos)
end

--- Computes an average point from N points or objects.
-- @cstyle point AveragePoint(point pt1, object pt2, ...)
-- @cstyle point AveragePoint(table pts [, int count])
-- @return point;
function AveragePoint(pt1, pt2, ...)
end

--- Computes an average 2D point from N points or objects.
-- @cstyle point AveragePoint2D(point pt1, object pt2, ...)
-- @cstyle point AveragePoint2D(table pts [, int count])
-- @return point;
function AveragePoint2D(pt1, pt2, ...)
end

-- @cstyle int object::GetPfClass().
function object:GetPfClass()
end
