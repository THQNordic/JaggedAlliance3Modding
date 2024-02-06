--- Checks if a string begins with a given string
-- @cstyle bool string.starts_with(string str, string str_to_find, bool case_insensitive = false)
function string.starts_with(str, str_to_find, case_insensitive)
end

--- Checks if a string ends with a given string
-- @cstyle bool string.ends_with(string str, string str_to_find, bool case_insensitive = false)
function string.ends_with(str, str_to_find, case_insensitive)
end

--- Search a string into a string lowercase
-- Returns the starting index of the first occurence of the string, or nil
-- @cstyle int string.find_lower(string str, string str_to_cmp, int start_idx = 1)
function string.find_lower(str, str_to_find, start_idx)
end

--- Compares two strings lowercase
-- Returns zero if equal, negative if str1 < str2 or positive if str1 > str2
-- @cstyle int string.cmp_lower(string str1, string str2)
function string.cmp_lower(str1, str2)
end

--- Concatenates strings using a separator
-- Returns str1 .. sep .. str2 .. [sep ... ]
-- @cstyle int string.concat(string sep, string str1, string str2, ...)
function string.concat(sep, str1, str2, ...)
end