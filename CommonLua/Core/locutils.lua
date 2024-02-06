if FirstLoad then
	g_LipSyncData = {}
end

function GetVoiceFilename(T, seed)
	if not T then return end
	local id = TGetID(T)
	if not id then return end
	
	if g_VoiceVariations then
		local all_vars = g_VoiceVariations[id] or g_VoiceVariations[tostring(id)]
		if all_vars and #all_vars > 0 then
			local var = 1 + (seed and BraidRandom(seed, #all_vars) or AsyncRand(#all_vars))
			return all_vars[var]
		end
	end
	
	local not_robot_voice = "CurrentLanguage/Voices/"..id

	-- if not (Platform.developer and Platform.pc and config.RunUnpacked) then 
	if not config.VoicesTTS or not GetAccountStorageOptionValue("VoicesTTS") then 
		return not_robot_voice
	end
	
	if GetSoundDuration(not_robot_voice) then
		return not_robot_voice
	end
	
	local robo_voice = "CurrentLanguage/VoicesTTS/"..id
	if io.exists(robo_voice .. ".opus") then
		return robo_voice
	end
end

-- choose the sound by the translation id of the given text
function VoiceSampleByText(T, actor, pathName)
	local id = TGetID(T)
	if not id then
		return false
	end

	local sample
	if actor == "male" then
		sample = pathName or "CurrentLanguage/Voices/Male/" .. id
	elseif actor == "female" then
		sample = pathName or "CurrentLanguage/Voices/Female/" .. id
	elseif actor and actor ~= "" and actor ~= "narrator" then
		sample = string.concat(pathName or "CurrentLanguage/Voices/", not pathName and actor or "", "/", id)
	else
		sample = pathName or "CurrentLanguage/Voices/" .. id
	end
	-- so we can play robo_voices in conversations 
	if not io.exists(sample .. ".opus") then
		sample = GetVoiceFilename(T)
	end
	
	return sample
end

function VoicedContextFromField(field, annotation, voiced_prop, annotation_prop)
	return function(obj, prop_meta, parent)
		if type(field) == "table" then
			for i = 1, #field do
				if obj[field[i]] and obj[field[i]] ~= "" then
					field = field[i]
					break
				end
			end
		end
		local extra_annotation = annotation_prop and obj[annotation_prop]
		if IsT(extra_annotation) then
			extra_annotation = _InternalTranslate(extra_annotation)
		end
		if (not voiced_prop or obj[voiced_prop]) and obj[field] then
			if annotation and extra_annotation then
				return string.format("%s %s voice:%s", annotation, extra_annotation, obj[field])
			elseif annotation or extra_annotation then
				return string.format("%s voice:%s", annotation or extra_annotation, obj[field])
			else
				return string.format("voice:%s", obj[field])
			end
		else
			return annotation and extra_annotation and (annotation .. " " .. extra_annotation) or annotation or extra_annotation or ""
		end
	end
end

function GenerateLocalizationIDs(obj)
	if not obj then return end
	
	if PropObjHasMember(obj, "GetProperties") then
		local props = obj:GetProperties()
		for i = 1, #props do
			local prop = props[i]
			local id = prop.id
			if prop.translate then
				local value = obj:GetProperty(id)
				if IsT(value) and not obj:IsDefaultPropertyValue(id, prop, value) then
					assert(not THasArgs(value))
					obj:SetProperty(id, T{RandomLocId(), TDevModeGetEnglishText(value)})
				end
			end
			
			local editor = prop.editor
			if editor == "T_list" and not obj:IsDefaultPropertyValue(id, prop, value) then
				local tlist = obj:GetProperty(id)
				for idx, text in ipairs(tlist) do
					tlist[idx] = T{RandomLocId(), TDevModeGetEnglishText(text)}
				end
			elseif editor == "nested_obj" then
				GenerateLocalizationIDs(obj:GetProperty(id))
			elseif editor == "nested_list" then
				for _, subobj in ipairs(obj:GetProperty(id)) do
					GenerateLocalizationIDs(subobj)
				end
			end
		end
	end
	for i = 1, #obj do
		GenerateLocalizationIDs(obj[i], true)
	end
	return obj
end

g_TestUIPlatform = false -- win32 uI
-- g_TestUIPlatform = "ps4" -- to test ps4 UI interface
-- g_TestUIPlatform = "ps5" -- to test ps5 UI interface
-- g_TestUIPlatform = "xbox" -- to test xbox UI interface
-- g_TestUIPlatform = "xbox_one" -- to test xbox one UI interface
-- g_TestUIPlatform = "xbox_series" -- to test xbox series UI interface
-- g_TestUIPlatform = "switch" -- to test Switch UI interface

--- button images remap for PlayStation
const.XboxToPlayStationButtons = {
	ButtonA = const.PlayStationEnterBtnCircle and "Circle" or "Cross",
	ButtonB = const.PlayStationEnterBtnCircle and "Cross" or "Circle",
	ButtonY = "Triangle",
	ButtonX = "Square",
	LT      = "L2",
	RT      = "R2",
	LS      = "L",
	RS      = "R",
	LSPress = "L3",
	RSPress = "R3",
	LB      = "L1",
	RB      = "R1",
	Start   = "Options",
	Back    = "TouchPad",
}

const.ShortenedButtonNames = {
	LeftTrigger = "LT",
	RightTrigger = "RT",
	LeftShoulder = "LB",
	RightShoulder = "RB",
	RightThumbClick = "RSPress",
	LeftThumbClick = "LSPress",
}

local TagToImageName = {
	["ButtonA"]   = "ButtonA",
	["ButtonB"]   = "ButtonB",
	["ButtonX"]   = "ButtonX",
	["ButtonY"]   = "ButtonY",
	["DPad"]      = "DPad",
	["DPadUp"]    = "DPadUp",
	["DPadDown"]  = "DPadDown",
	["DPadLeft"]  = "DPadLeft",
	["DPadRight"] = "DPadRight",
	["DPadUpDown"] = "DPad_Up_Down",
	["DPadLeftRight"] = "DPad_Left_Right",
	["LT"]        = "LT",
	["RT"]        = "RT",
	["LeftTrigger"] = "LT",
	["RightTrigger"] = "RT",
	["LS"]        = "LS",
	["RS"]        = "RS",
	["LSPress"]   = "LSPress",
	["RSPress"]   = "RSPress",
	["LB"]        = "LB",
	["RB"]        = "RB",
	["Start"]     = "Start",
	["Back"]      = "Back",
	["lsupdown"]  = "ls_up_down",
	["lsright"]   = "lsright",
	["lsleft"]    = "lsleft",
	["lsup"]      = "lsup",
	["lsdown"]    = "lsdown",
	["rsupdown"]  = "rs_up_down",
	["rsright"]   = "rsright",
	["rsleft"]    = "rsleft",
	["rsup"]      = "rsup",
	["rsdown"]    = "rsdown",
	["RightThumbUp"]    = "rsup",
	["RightThumbDown"]    = "rsdown",
	["Controller"] = "Controller",
}


-- these get auto-replaced in translated text, e.g. <A> is the same as <image UI/Xbox/A.tga>
function RecreateButtonsTagLookupTable()
	for tag, img in pairs(TagToImageName) do
		const.TagLookupTable[tag] = GetPlatformSpecificImageTag(img)
	end
end

if Platform.pc then
	function UpdateActiveControllerType()
		if not rawget(_G, "XInput") or not IsXInputControllerConnected() or not ActiveController then return end
	
		local previous = g_PCActiveControllerType
		g_PCActiveControllerType = XInput.GetControllerType(ActiveController) or false
		if g_PCActiveControllerType ~= previous then
			RecreateButtonsTagLookupTable()
			Msg("OnControllerTypeChanged", g_PCActiveControllerType)
		end
	end
	
	OnMsg.XInputInitialized = UpdateActiveControllerType
	OnMsg.ActiveControllerUpdated = UpdateActiveControllerType
	
	if FirstLoad then
		g_PCActiveControllerType = false
	end
	function GetPCActiveControllerType()
		return g_PCActiveControllerType
	end
else
	function GetPCActiveControllerType()
	end
end

function ShouldShowPS4Images()
	return Platform.ps4 or g_TestUIPlatform == "ps4" or (not g_TestUIPlatform and GetPCActiveControllerType() == "ps4")
end

function ShouldShowPS5Images()
	return Platform.ps5 or g_TestUIPlatform == "ps5" or (not g_TestUIPlatform and GetPCActiveControllerType() == "ps5")
end

function GetPlatformSpecificImageName(btn, platform)
	btn = const.ShortenedButtonNames[btn] or btn
	local path = "UI/DesktopGamepad/"
	local ext = ".tga"
	local btnimg = btn
	if platform == "ps4" then
		path = "UI/PS4/" 
		btnimg = (const.XboxToPlayStationButtons[btn] or btn)
	elseif platform == "ps5" then
		path = "UI/PS5/" 
		btnimg = (const.XboxToPlayStationButtons[btn] or btn)
	elseif platform == "xbox_one" then
		path = "UI/XboxOne/" 
	elseif platform == "xbox_series" then
		path = "UI/XboxSeries/" 
	elseif platform == "switch" then
		path = "UI/Switch/"
	else -- win32
	end	
	return path..btnimg..ext
end

function ReportButtonImageResources(resIds)
	local function AddResourcesForPlatform(platform, dlc)
		dlc = dlc or platform
		for _, btn in pairs(TagToImageName) do
			local name = GetPlatformSpecificImageName(btn, platform)
			local resId = ResourceManager.GetResourceID(name)
			if ResourceManager.GetResourceIDAsString(resId) ~= "" then
				resIds[resId] = dlc
			end
		end
	end
	
	AddResourcesForPlatform("win32")
	AddResourcesForPlatform("ps4")
	AddResourcesForPlatform("ps5")
	AddResourcesForPlatform("xbox_one", "xbox")
	AddResourcesForPlatform("switch")
end

function GetPlatformSpecificImagePath(btn)
	btn = const.ShortenedButtonNames[btn] or btn
	local path = "UI/DesktopGamepad/"
	local ext = ".tga"
	local btnimg = btn
	if ShouldShowPS4Images() then
		path = "UI/PS4/" 
		btnimg = (const.XboxToPlayStationButtons[btn] or btn)
	elseif ShouldShowPS5Images() then
		path = "UI/PS5/" 
		btnimg = (const.XboxToPlayStationButtons[btn] or btn)
	elseif Platform.xbox_one then
		path = "UI/XboxOne/" 
	elseif Platform.xbox_series then
		path = "UI/XboxSeries/" 
	elseif Platform.switch or g_TestUIPlatform=="switch" or GetPCActiveControllerType() == "switch" then
		path = "UI/Switch/"
	else -- win32
	end	
	return path..btnimg..ext, 500
end

function GetPlatformSpecificImageTag(btn, scale)
	btn = const.ShortenedButtonNames[btn] or btn
	local path = "UI/DesktopGamepad/"
	local btnimg = btn
	if ShouldShowPS4Images() then
		path = "UI/PS4/" 
		btnimg = (const.XboxToPlayStationButtons[btn] or btn)
	elseif ShouldShowPS5Images() then
		path = "UI/PS5/" 
		btnimg = (const.XboxToPlayStationButtons[btn] or btn)
	elseif Platform.xbox_one then
		path = "UI/XboxOne/"
	elseif Platform.xbox_series then
		path = "UI/XboxSeries/"
	elseif Platform.switch or g_TestUIPlatform=="switch" or GetPCActiveControllerType() == "switch" then 
		path = "UI/Switch/"
	else -- win32
	end	
	if scale then
		return string.format("<image %s%s.tga %d>", path, btnimg, tonumber(scale) or 1000)
	else
		return string.format("<image %s%s.tga>", path, btnimg)
	end
end

OnMsg.XInputInitialized = RecreateButtonsTagLookupTable

RecreateButtonsTagLookupTable()

-- lookup tags with Untranslated()
const.TagLookupTable["tm"]         = Untranslated("™") -- ( tm TM trademark trade mark ) symbol
const.TagLookupTable["copyright"]  = Untranslated("©") -- ( copyright (c) (C) copy right ) symbol
const.TagLookupTable["registered"] = Untranslated("®") -- ( registered (r) (R) ) symbol
const.TagLookupTable["nbsp"] = Untranslated(" ") -- ( non-breaking space nonbreaking space non breaking space ) symbol

local replace_map = {
	["`"] = "'",
	["‘"] = "'",
	["’"] = "'",
	["“"] = "\"",
	["”"] = "\"",
	["–"] = "-",
	["—"] = "-",
	["−"] = "-",
	["…"] = "...",
}

function ReplaceNonStandardCharacters(s)
	for k, v in pairs(replace_map) do
		s = s:gsub(k, v)
	end
	return s
end

changed = {}

function FixupPresetTs()
	local count = 0
	local validation_start = GetPreciseTicks()
	PauseInfiniteLoopDetection("FixupPresetTs")

	local eval = prop_eval
	local dirty = {}
	for class_name, presets in pairs(Presets) do
		for _, group in ipairs(presets) do
			for _, preset in ipairs(group) do
				preset:ForEachSubObject(function(obj)
					for _, prop in ipairs(obj:GetProperties()) do
						if prop.editor == "text" and eval(prop.translate, obj, prop) then
							local t = obj:GetProperty(prop.id)
							if t and t ~= "" then
								local id, text = TGetID(t) or RandomLocId(), TDevModeGetEnglishText(t)
								local new_text = ReplaceNonStandardCharacters(text)
								if text ~= new_text then
									obj:SetProperty(prop.id, T(id, new_text))
									table.insert(changed, preset.class .. " " .. new_text)
									dirty[class_name] = true
									count = count + 1
								end
							end
						end
					end
				end)
			end
		end
	end
	
	for class_name in pairs(dirty) do
		_G[class_name]:SaveAll("force save all")
	end
	
	ResumeInfiniteLoopDetection("FixupPresetTs")
	CreateMessageBox(
		nil,
		Untranslated("Fixup Ts"),
		Untranslated(string.format("Changed a total of %d texts for %d ms", count, GetPreciseTicks() - validation_start))
	)
end

local diacritics_map = {
    ["À"] = "A",
    ["Á"] = "A",
    ["Â"] = "A",
    ["Ã"] = "A",
    ["Ä"] = "A",
    ["Å"] = "A",
    ["Æ"] = "AE",
    ["Ç"] = "C",
    ["È"] = "E",
    ["É"] = "E",
    ["Ê"] = "E",
    ["Ë"] = "E",
    ["Ì"] = "I",
    ["Í"] = "I",
    ["Î"] = "I",
    ["Ï"] = "I",
    ["Ð"] = "D",
    ["Ñ"] = "N",
    ["Ò"] = "O",
    ["Ó"] = "O",
    ["Ô"] = "O",
    ["Õ"] = "O",
    ["Ö"] = "O",
    ["Ø"] = "O",
    ["Ù"] = "U",
    ["Ú"] = "U",
    ["Û"] = "U",
    ["Ü"] = "U",
    ["Ý"] = "Y",
    ["Þ"] = "P",
    ["ß"] = "s",
    ["à"] = "a",
    ["á"] = "a",
    ["â"] = "a",
    ["ã"] = "a",
    ["ä"] = "a",
    ["å"] = "a",
    ["æ"] = "ae",
    ["ç"] = "c",
    ["è"] = "e",
    ["é"] = "e",
    ["ê"] = "e",
    ["ë"] = "e",
    ["ì"] = "i",
    ["í"] = "i",
    ["î"] = "i",
    ["ï"] = "i",
    ["ð"] = "eth",
    ["ñ"] = "n",
    ["ò"] = "o",
    ["ó"] = "o",
    ["ô"] = "o",
    ["õ"] = "o",
    ["ö"] = "o",
    ["ø"] = "o",
    ["ù"] = "u",
    ["ú"] = "u",
    ["û"] = "u",
    ["ü"] = "u",
    ["ý"] = "y",
    ["þ"] = "p",
    ["ÿ"] = "y",
}

function RemoveDiacritics(s)
	return s:gsub("[%z\1-\127\194-\244][\128-\191]*", diacritics_map)
end

-------------------- Tokenization -------------------------
tag_processors = {}

DefineClass.XTextToken = {
	__parents = { "PropertyObject" },

	text = false,
	type = false,
	args = false,
}
 
-- Text -> Tokens
function XTextTokenize(input_text, token_func, stream)
	if not token_func then
		stream = stream or {}
		token_func = function (stream, ttype, args, text)
			if text == "" then
				return
			end
			local next_token = XTextToken:new({
				type = ttype,
				text = text,
				args = args,
			})
			table.insert(stream, next_token)
		end
	end
	
	if type(input_text) ~= "string" or not utf8.IsValidString(input_text) then
		token_func(stream, "text", false, "Not a valid UTF-8 string:" .. string.gsub(input_text, "[^a-zA-Z0-9\n <%>-%:%(%)\\/]", "." ))
		return stream
	end

	local byte_idx = 1
	local input_text_bytes_len = #input_text
	local tags_on = true
	while byte_idx <= input_text_bytes_len do
		local start_byte_idx, end_byte_idx = string.find(input_text, "</?[^%s=>][^>]*>", byte_idx)
		if not start_byte_idx then start_byte_idx = input_text_bytes_len + 1 end
		token_func(stream, "text", false, string.sub(input_text, byte_idx, start_byte_idx - 1))
		byte_idx = start_byte_idx + 1
		
		-- grab any available non text tokens
		if end_byte_idx then
			-- we're done
			byte_idx = end_byte_idx + 1
			local token = string.sub(input_text, start_byte_idx + 1, end_byte_idx - 1)
			
			local elements
			if token:find("%s") then
				elements = {}
				for part in string.gmatch(token, "[^%s]+") do
					table.insert(elements, part)
				end

				--collapse quoted strings
				local i = 1
				while i <= #elements do
					if elements[i]:starts_with("'") then
						if i < #elements and not elements[i]:ends_with("'") then
							elements[i] = string.format("%s %s", elements[i], elements[i + 1])
							table.remove(elements, i + 1)
						else
							if elements[i]:ends_with("'") then
								elements[i] = elements[i]:sub(2, -2)
							end
							i = i + 1
						end
					else
						i = i + 1
					end
				end
			end

			local tag = elements and elements[1] or token
			if tag == "tags" then
				tags_on = elements and elements[2] == "on"
			elseif tag == "literal" and tonumber(elements and elements[2]) then
				local offset = tonumber(elements[2])
				offset = Min(Max(0, offset), input_text_bytes_len)
				byte_idx = Max(end_byte_idx + 1, Min(input_text_bytes_len + 1, end_byte_idx + offset + 1))
				token_func(stream, "text", false, string.sub(input_text, end_byte_idx + 1, byte_idx - 1))
			elseif token == "" or not tag_processors[tag] or tag == "text" or not tags_on then
				token_func(stream, "text", false, "<" .. token .. ">")
			else
				if elements then
					table.remove(elements, 1)
				end
				token_func(stream, tag, elements, token)
			end
		end
	end

	return stream
end


local starts_with = string.starts_with
local string_gmatch = string.gmatch
function CountWords(line)
	local count = 0
	for _, span in ipairs(XTextTokenize(line)) do
		if span.type == "text" then
			local text = span.text
			if not starts_with(text, "<") then
				for word in string_gmatch(text, "[^%s]+") do
					count = count + 1
				end
			end
		end
	end
	return count
end