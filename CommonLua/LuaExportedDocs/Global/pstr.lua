--- pstr.
-- pstr are string kept outside the Lua memoty.

--- Creates a pstr.
-- @cstyle pstr pstr(string str = "", int capacity = 0).
-- @param str string Initial value of the string, empty by default.
-- @param capacity integer Allocated memory, taken into account only if bigger than the size of the string.
-- @return pstr.

function pstr(str, capacity)
end

--- Check if the given value is a pstr.
-- @cstyle bool IsPStr(pstr value).
-- @return true if value is a pstr.

function IsPStr(value)
end

--- Return stats for the current pstr usage. Only functional in debug mode.
-- @cstyle table GetPStrStats().
-- @return table with statistics.

function GetPStrStats()
end

--- Free all resources allocated from a given pstr.
-- @cstyle void pstr::free(pstr self).

function pstr:free()
end

--- Returns the size of the pstr (same as # operator).
-- @cstyle int pstr::size(pstr self).
-- @return integer.

function pstr:size()
end

--- Compares a pstr with another string (same as == operator).
-- @cstyle boolean pstr::equals(pstr self, string value).
-- @return boolean.

function pstr:equals(value)
end

--- Append any number of arguments to the current pstr (same as .. operator, but inplace).
-- @cstyle pstr pstr::append(pstr self, ...).
-- @return pstr, the pstr itself.

function pstr:append(...)
end

--- Append a the same string several times.
-- @cstyle pstr pstr::appendr(pstr self, string str, int count).
-- @param str string: Text to repeat.
-- @param count int: Number of repetitions.
-- @return pstr, the pstr itself.

function pstr:appendr(str, count)
end

--- Append a formated string to the current pstr (same as printf).
-- @cstyle pstr pstr::appendf(pstr self, string fmt, ...).
-- @return pstr, the pstr itself.

function pstr:appendf(fmt, ...)
end

--- Append value to lua code
-- @cstyle pstr pstr::appendv(pstr self, T value, string indent).
-- @return pstr, the pstr itself.

function pstr:appendv(value, indent)
end

--- Append a table to lua code
-- @cstyle pstr pstr::appendt(pstr self, table tbl, string indent, bool as_array).
-- @return pstr, the pstr itself.

function pstr:appendt(tbl, indent, as_array)
end

--- Append string to lua code
-- @cstyle pstr pstr::appends(pstr self, string str, bool quote).
-- @param str string Quoted string to append.
-- @param quote bool, Use single quote (may be set to "auto" to auto-match).
-- @return pstr, the pstr itself.

function pstr:appends(value, str, quote)
end

--- Convert a pstr to a string (same as tostring() operator)
-- @cstyle string pstr::str(pstr self).
-- @return string.

function pstr:str()
end

--- Clear the contents of a pstr.
-- @cstyle void pstr::clear(pstr self).

function pstr:clear()
end

--- Return a substring
-- @cstyle string pstr::sub(pstr self, int from = 1, int to = -1).
-- @param from integer Starting index, 1 by default.
-- @param to integer Ending index, -1 by default, which marks the end of the string.
-- @return string.

function pstr:sub(from, to)
end

--- Return N integer values with the byte representation of the containing chars
-- @cstyle string pstr::byte(pstr self, int from, int to = from).
-- @param from integer Starting index.
-- @param to integer Ending index, Same as 'from' by default.
-- @return integer.

function pstr:byte(from, to)
end

--- Reserve the requested number of bytes
-- @cstyle pstr pstr::reserve(pstr self, int size).
-- @return bool.

function pstr:reserve(size)
end
