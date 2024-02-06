local user_location = "AppData/en-us.lua"
local default_location = "CommonAssets/__en-us.lua"
local location = default_location

if FirstLoad then
	SpellcheckDict = false
end

function LoadDictionary()
	if not Platform.developer then
		if not io.exists(user_location) then
			AsyncCopyFile(default_location, user_location)
		end
		location = user_location
	end
	dofile(location)
end

function WriteToDictionary(dict)
	local lines = {}
	lines[1] = "SpellcheckDict = {"
	for word, _ in sorted_pairs(dict) do
		lines[#lines + 1] = "\t[\""..word.."\"] = true,"
	end
	lines[#lines + 1] = "}"
	AsyncStringToFile(location, table.concat(lines, "\n"))
end

function WordInDictionary(word, lowercase_word)
	if not SpellcheckDict then
		return true
	end
	if word ~= nil and word ~= "" and not SpellcheckDict[word] and not SpellcheckDict[lowercase_word] and not tonumber(word) and not tonumber(string.sub(word,2)) then
		return false
	end
	return true
end