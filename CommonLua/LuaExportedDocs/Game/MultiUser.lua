--- MultiUser support functions.
 
--- Returns the number of users.
-- @cstyle int MultiUser.GetCount().
-- @return int; Returns the number of users.

function MultiUser.GetCount()
end

--- Sets the active user.
-- @cstyle bool MultiUser.SetActive(index).
-- @param index int; index of the user to be set as active.
-- @return void.

function MultiUser.SetActive(index)
end

--- Returns info for the active user.
-- @cstyle void MultiUser.GetActive().
-- @return table; example: { uid = "7075076655715131254", name = 'John', country = "India", comment = "very powerful", folder = "AppData/Users/1" }.

function MultiUser.GetActive()
end

--- Returns info for specific user.
-- @cstyle void MultiUser.GetUser(int index).
-- @param index int; index of the user to get.
-- @return table; example: { uid = "7075076655715131254", name = 'John', country = "India", comment = "very powerful", folder = "AppData/Users/1" }.

function MultiUser.GetUser(index)
end

--- Registers a new user to system and sets it as active.
-- @cstyle void MultiUser.AddNewUser().
-- @return void.
-- @see MultiUser.GetActive.
-- @see MultiUser.SetActive.

function MultiUser.AddNewUser()
end

--- Deletes the specified user.
-- @cstyle void MultiUser.AddNewUser().
-- @param index int; index of the user to delete.
-- @return void.

function MultiUser.DeleteUser()
end
