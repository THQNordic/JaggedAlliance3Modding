--- Terminal functions.

--- Returns if the given key is pressed.
-- @cstyle bool terminal.IsKeyPressed(int key).
-- @param key int; virtual key code; the codes are exported to const table.
-- @return bool; true if the key is pressed; false otherwise.

function terminal.IsKeyPressed(key)
end

--- Returns if the left, right and middle mouse buttons are currently pressed.
-- @cstyle bool, bool, bool terminal.IsLRMMouseButtonPressed().
-- @return bool, bool, bool.

function terminal.IsLRMMouseButtonPressed()
end

--- Returns the current position of the mouse.
-- @cstyle point terminal.GetMousePos().
-- @return point.

function terminal.GetMousePos()
end

--- Sets the text of the current window
-- @param text string; New value.
-- @return bool; success?
function terminal.SetOSWindowTitle(text)
end