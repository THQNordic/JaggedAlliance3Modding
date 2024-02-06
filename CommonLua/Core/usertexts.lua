-- user_text_type: currently used for Steam only, see https://partner.steamgames.com/doc/api/steam_api#ETextFilteringContext
--		values are "unknown", "game_content", "chat", "name", defaulting to "unknown"
function CreateUserText(text, user_text_type)
	return setmetatable({
		text,
		_language = GetLanguage(),
		_steam_id = (Platform.steam and IsSteamAvailable()) and SteamGetUserId64() or nil,
		_user_text_type = user_text_type
	}, TMeta)
end

-- input is a list of UserText
-- has two outputs: 
-- 	an "error table" (or false)
--		numeric table (indexed by sequential integers), each entry is itself a table with keys "user_text" and "error"
-- 	a table mapping each input userText to a filteredUserText; 
-- 		the second output is a table because Steam's API works on a text by text basis, so it can fail on specific text instead of the full list/batch (these failures are not included in the returned list), so we need to associate each user text with its filtered result
-- 		if a UserText from the input does not appear in the output table, there was an error and a fallback must be used before the text is displayed (applied outside the function)
-- This is fallback implementation, to be overriden for each platform
function _DefaultInternalFilterUserTexts(unfilteredTs)
	local filteredTs = {}
	for _, T in ipairs(unfilteredTs) do
		filteredTs[T] = TDevModeGetEnglishText(T, "deep", "no_assert")
	end
	return false, filteredTs
end

_InternalFilterUserTexts = _DefaultInternalFilterUserTexts

-- table indexed by table.hash(T)
-- each value is itself a table with "filtered" as the result of platform specific filtering and "custom" as the custom filter/fallback value
if FirstLoad then
	FilteredTextsTable = {}
end

-- user texts are filtered using table.hash so that they are filtered by value instead of by reference
function AsyncFilterUserTexts(user_texts)
	-- preprocess to remove entries duplicate hash values or entries that were already translated
	local set = {}
	local unfiltered_list = {}
	for _,T in ipairs(user_texts) do
		local hash = table.hash(T)
		if not (FilteredTextsTable[hash] and FilteredTextsTable[hash].filtered) and not set[hash] and T ~= "" then
			set[hash] = true
			table.insert(unfiltered_list, T)
		end
	end
	
	if not unfiltered_list then return false end -- every text had a cached filter already
	
	local errors, filtered_list = _InternalFilterUserTexts(unfiltered_list)
	
	for T, filteredT in pairs(filtered_list) do 
		if not utf8.IsValidString(filteredT) then
			local rawText = TDevModeGetEnglishText(T, "deep", "no_assert")
			print(string.format("Filtered text is not a valid UTF-8 string! Using unfiltered text as fallback instead.\nUser Text: <%s>\nFilteredText: <%s>\nUnfilteredText: <%s>", 
				UserTextToLuaCode(T), 
				filteredT, 
				rawText)
			)
			SetCustomFilteredUserText(T, rawText)
		else
			local hash = table.hash(T)
			FilteredTextsTable[hash] = FilteredTextsTable[hash] or {}
			FilteredTextsTable[hash].filtered = filteredT
		end
	end
	
	return errors
end

function SetCustomFilteredUserText(T, custom_filter_text)
	assert(IsUserText(T))
	local hash = table.hash(T)
	FilteredTextsTable[hash] = FilteredTextsTable[hash] or {}
	FilteredTextsTable[hash].custom = custom_filter_text or TDevModeGetEnglishText(T, not "deep", "no_assert")
end

function SetCustomFilteredUserTexts(Ts, custom_filter_texts)
	assert(not custom_filter_texts or #Ts == #custom_filter_texts)
	for i, v in ipairs(Ts) do
		SetCustomFilteredUserText(v, custom_filter_texts and custom_filter_texts[i])
	end
end

function GetFilteredText(T)
	assert(IsUserText(T), "Trying to get filtered text of a T that is not a UserText.")
	local cache_entry = FilteredTextsTable[table.hash(T)]
	return cache_entry and (cache_entry.filtered or cache_entry.custom)
end
