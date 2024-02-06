--- X-Box controller functions.
 
--- Returns the number of max supported controllers.
-- @cstyle int XInput.MaxControllers().
-- @return int; Returns the number of the supported controllers.

function XInput.MaxControllers()
end

--- Checks if the controller is connected.
-- @cstyle bool XInput.IsControllerConnected(controllerId).
-- @param controllerId int; ID of the controller to be checked.
-- @return bool; true if the controlledId is connected, false otherwise.

function XInput.IsControllerConnected(controllerId)
end

--- Set the rumble motors to work at the given speed.
-- @cstyle void XInput.SetRumble(int controllerId, int leftSpeed, int rightSpeed).
-- @param controllerId int; ID of the controller for which to set the rumble motors.
-- @param leftSpeed int; the speed for the left motor ranging from 0 to 65535, i.e. 0% - 100%.
-- @param rightSpeed int; the speed for the right motor ranging from 0 to 65535, i.e. 0% - 100%.
-- @return void.

function XInput.SetRumble(controllerId, leftSpeed, rightSpeed)
end

--- Gets the state of controller as last and current state. Last state represents the accumulated events since the last update: : for buttons, they are 1 if the button was pressed during the interval; for triggers, the max value is held, and for thumbs, the point with the largest distance from the origin. Its packetId holds the id of the packet when it was last called.
-- The table fields that are populated are packetId, Left, Right, Up, Down, A, B, X, Y, LeftThumbClick, RightThumbClick, LeftTrigger, RightTrigger, LeftThumb, RightThumb, TouchPadClick (PS4 only).
-- Values for the buttons not currently pressed will be set to nil, not false.
-- @cstyle table, table XInput.GetState(controllerId).
-- @param controllerId int; ID of the controller for which to get the state.
-- @return table, table; two tables - last and current with the format described above.

function XInput.__GetState(controllerId)
end
