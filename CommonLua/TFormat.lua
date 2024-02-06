TFormat = {}
TFormatPstr = {}


local type = type
local tostring = tostring
local table = table
local string = string
local concat = string.concat
local Untranslated = Untranslated
local _InternalTranslate = _InternalTranslate

function TFormatPstr.u(_pstr, context_obj, _T)
	if IsT(_T) then return AppendTTranslate(_pstr, _T, context_obj) end
	assert(not _T or type(_T) == "string" or type(_T) == "number")
	assert(type(_T) ~= "string" or not IsLookupTag(_T), "In this case you should use TLookupTag('<tag>') instead of Untranslated('<tag>')")
	_pstr:append(tostring(_T or ""))
end

function TFormat.u(context_obj, ...)
	return Untranslated(...)
end

function TFormat.TGender(context, T)
	return GetTGender(T)
end

function TFormat.ByGender(context, T, gender)
	return GetTByGender(T, gender or context.Gender)
end

-- output a T value directly without evaluating tags & with <tags off> for XText
-- useful for EditorView of preset subitems for display in Ged
function TFormat.literal(context_obj, value, tags_on)
	local prefix, suffix = "<tags off>", "<tags on>"
	if tags_on then
		prefix, suffix = "", ""
	end
	if IsT(value) then
		value = _InternalTranslate(value, nil, false, "tags_off")
	end
	return value and (prefix .. value .. suffix) or "", true
end

function TFormat.pr(context_obj, value)
	if IsValid(value) then
		local x, y = value:GetPosXYZ()
		value = string.format("%s(%d, %d)", value.class, x, y)
	elseif type(value) == "table" then
		if not IsPoint(value[1]) then
			value = string.format("{...} #%d", #value)
		else
			local x, y, z = value[1]:xyz()
			if z then
				value = string.format("(%d, %d, %d), ... #%d", x, y, z, #value)
			else
				value = string.format("(%d, %d), ... #%d", x, y, #value)
			end
		end
	end
	return Untranslated(tostring(value))
end


----- Numbers

TFormat.FormatIndex     = function(context_obj, ...) return FormatIndex(...)   end
TFormat.FormatAsFloat   = function(context_obj, ...) return FormatAsFloat(...) end
TFormat.FormatInt       = function(context_obj, ...) return FormatInt(...)     end
TFormat.FormatSize      = function(context_obj, ...) return FormatSize(...)    end
TFormat.FormatSignInt   = function(context_obj, ...) return FormatSignInt(...) end
TFormat.FormatScale     = function(context_obj, ...) return FormatScale(...)   end
TFormat.percent         = function(...)              return FormatPercent(...) end
TFormat.percentWithSign = function(...)              return FormatPercentWithSign(...) end
TFormat.kg              = function(context_obj, ...) return FormatKg(...)      end
TFormat.roman = function(context_obj, number)
	return number and Untranslated(RomanNumeral(number)) or ""
end
TFormat.abs = function(context_obj, number)
	local n = tonumber(number)
	return n and abs(n) or number
end


----- Utilities

TFormat.def = function(context_obj, value, default) return value ~= "" and value or default end
TFormat.count = function(context_obj, value) return type(value) == "table" and #value or 0 end
TFormat.display_name = function(context_obj, presets_table, value, field)
	if type(value) ~= "string" then return "" end
	presets_table = Presets[presets_table] and Presets[presets_table].Default or rawget(_G, presets_table)
	local preset = presets_table[value]
	return preset and preset[field or "display_name"]
end
TFormat.diff = function(context_obj, amount, zero_text)
	if type(amount) ~= "number" then return "" end
	if amount <= 0 then
		if amount == 0 and zero_text then return zero_text end
		return Untranslated(amount)
	else
		return Untranslated("+" .. amount)
	end
end
TFormat.opt = function(context_obj, value, prefix, postfix)
	if value and value ~= "" then
		return T{337322950263, "<prefix><value><postfix>", prefix = prefix or "", value = value or "", postfix = postfix or ""}
	end
	return ""
end
TFormat.opt_amount = function(context_obj, amount, prefix)
	if not amount or amount == 0 then return "" end
	if type(amount) == "number" and amount < 0 then
		return Untranslated((prefix or "") .. amount)
	else
		return Untranslated((prefix or "") .. "+" .. amount)
	end
end
TFormat.opt_percent = function(context_obj, percent)
	if not percent or percent == 0 then return "" end
	local pattern = type(percent) == "number" and percent < 0 and "%s%%" or "+%s%%"
	return Untranslated(string.format(pattern, tostring(percent)))
end
TFormat.sum = function(context_obj, sum, prop, obj)
	sum = tonumber(sum) or 0
	assert(prop and prop:sub(1, 1) ~= '"') -- prop includes "" - use single quotes for literal function parameters
	for _, item in ipairs(obj or context_obj or empty_table) do
		sum = sum + (GetProperty(item, prop) or 0)
	end
	return sum
end
TFormat.get = function(context_obj, t, ...) return table.get(t, ...) end

TFormat.FormatResolution = function(context_obj, pt)
	return T{716420484706, "<arg1> x <arg2>", arg1 = pt:x(), arg2 = pt:y()}
end

---- In-game menu

TFormat.RestartMapText = function(context_obj)
	return T(1136, "Restart Map")
end

----- Conditional

TFormat.cut_if_platform = function(context_obj, platform)
	if Platform[platform] then
		return false
	end
	return ""
end
TFormat.cut_if_not_platform = function(context_obj, platform)
	if not Platform[platform] then
		return false
	end
	return ""
end	

local function is_true(cond)
	return cond and cond ~= ""
end
TFormat["not"]   = function(context_obj, value)          return not is_true(value) end

TFormat.eq       = function(context_obj, value1, value2) return value1 == value2 end
TFormat.not_eq   = function(context_obj, value1, value2) return value1 ~= value2 end
TFormat.less     = function(context_obj, value1, value2) return value1 < value2 end
TFormat.has_dlc  = function(context_obj, dlc)            return IsDlcAvailable(dlc) end
TFormat.platform = function(context_obj, platform)       return Platform[platform] and true end
TFormat.select = function(context_obj, index, ...) -- <select(index, value1, value2, ...)>
	if type(index) ~= "number" then
		index = is_true(index) and 2 or 1
	end
	return select(index, ...) or ""
end

const.TagLookupTable["/if"] = "</hide>"
TFormat["if"] = function(context_obj, cond) -- <if(cond)> true </if>
	return is_true(cond) and "" or "<hide>"
end
TFormat.if_all = function(context_obj, ...) -- <if_all(A, B, ...)> all </if>
	for i = 1, select("#", ...) do
		local cond = select(i, ...)
		if not is_true(cond) then
			return "<hide>"
		end
	end
	return ""
end
TFormat.if_any = function(context_obj, ...) -- <if_any(A, B, ...)> any </if>
	for i = 1, select("#", ...) do
		local cond = select(i, ...)
		if is_true(cond) then
			return ""
		end
	end
	return "<hide>"
end
TFormat["or"] = function(context_obj, ...)
	local cond
	for i = 1, select("#", ...) do
		cond = select(i, ...)
		if is_true(cond) then
			return cond
		end
	end
	return cond
end
TFormat["and"] = function(context_obj, ...)
	local cond
	for i = 1, select("#", ...) do
		cond = select(i, ...)
		if not is_true(cond) then
			return cond
		end
	end
	return cond
end

TFormat.os_date = function(context_obj, time, format)
	return os.date(format or "!%Y-%m-%d", time)
end

TFormat.context = function(context_obj)
	return context_obj
end

TFormat.map = function(context_obj, t, ...)
	if type(t) ~= "table" then return end
	return table.map(...)
end

TFormat.keys = function(context_obj, t, ...)
	if type(t) ~= "table" then return end
	return table.keys(...)
end

TFormat.list = function(context_obj, list, separator)
	if not list or not next(list) then return "" end
	return TList(list, separator)
end

TFormat.set = function(context_obj, set, separator)
	if not set or not next(set) then return "" end
	return TList(table.keys(set, true), separator)
end


----- Implementation

function FormatNone(value)
	return value
end

function FormatPercent(context_obj, value, max, min)
	if (max or 0) ~= 0 then
		value = MulDivRound(value, 100, max)
	end
	value = Max(value, min)
	return T{960784545354, "<number>%", number = value}
end

function FormatPercentWithSign(context_obj, value, max)
	if (max or 0) ~= 0 then
		value = MulDivRound(value, 100, max)
	end
	if value > 0 then
		return T{788023197741, "+<number>%", number = value}
	elseif value < 0 then
		return T{360627168972, "-<number>%", number = -value}
	else
		return T{960784545354, "<number>%", number = value}
	end
end

function FormatKg(value)
	if value <= 499 then
		return T{638292000495, "<weight>g", weight = value}
	elseif value < 1000 then
		local res = value/100
		return T{695159900103, "0.<res>kg", res = res}
	else
		local weight = DivRound(value, const.Scale.kg)
		return T{781395902674, "<weight>kg", weight = weight}
	end
end

function FormatInt(value, precision, size)
	assert(type(value) == "number")
	if type(value) ~= "number" then value = 0 end
	
	if value < 1000 then
		if size then
			return T{634583763636, "<value>B", value = value}
		end
		return Untranslated(value)
	end
	
	if value < 1000000 then
		local dev = 1000
		if not precision or precision == 0 then
			if size then
				return T{916707577582, "<value>kB", value = value / dev}
			end
			return T{542057749659, "<value>k", value = value / dev}
		elseif precision == 1 then
			if size then
				return T{306874811840, "<value>.<rem>kB", value = value / dev, rem = (value%dev)/(dev/10)}
			end
			return T{973255618325, "<value>.<rem>k", value = value / dev, rem = (value%dev)/(dev/10)}
		elseif precision == 2 then
			local rem = (value%dev)/(dev/100)
			if size then
				return T{306874811840, "<value>.<rem>kB", value = value / dev, rem = rem>0 and rem or Untranslated("00")}
			end
			return T{686447021725, "<value>.<rem>K", value = value / dev, rem = rem>0 and rem or Untranslated("00")}
		else
			assert(false, "FormatInt: precision not supported")
		end	
	elseif value < 1000000000 then
		local dev = 1000000
		if not precision or precision == 0 then
			if size then
				return T{777603998749, "<value>MB", value = value / dev}
			end
			return T{295351893708, "<value>M", value = value / dev}
		elseif precision == 1 then
			if size then
				return T{358890854224, "<value>.<rem>MB", value = value / dev, rem = (value%dev)/(dev/10)}
			end
			return T{372033962501, "<value>.<rem>M", value = value / dev, rem = (value%dev)/(dev/10)}
		elseif precision == 2 then
			local rem = (value%dev)/(dev/100)
			if size then
				return T{358890854224, "<value>.<rem>MB", value = value / dev, rem = rem>0 and rem or Untranslated("00")}
			end
			return T{372033962501, "<value>.<rem>M", value = value / dev, rem = rem>0 and rem or Untranslated("00")}
		else
			assert(false, "FormatInt: precision not supported")
		end		
	else
		local dev = 1000000000
		if not precision or precision == 0 then
			if size then
				return T{976112224433, "<value>GB", value = value / dev}
			end
			return T{113449998910, "<value>G", value = value / dev}
		elseif precision == 1 then
			if size then
				return T{927901310991, "<value>.<rem>GB", value = value / dev, rem = (value%dev)/(dev/10)}
			end
			return T{469760839385, "<value>.<rem>G", value = value / dev, rem = (value%dev)/(dev/10)}
		elseif precision == 2 then
			local rem = (value%dev)/(dev/100)
			if size then
				return T{927901310991, "<value>.<rem>GB", value = value / dev, rem = rem>0 and rem or Untranslated("00")}
			end
			return T{469760839385, "<value>.<rem>G", value = value / dev, rem = rem>0 and rem or Untranslated("00")}
		else
			assert(false, "FormatInt: precision not supported")
		end		
	end
end

function FormatSize(value, precision)
	return FormatInt(value, precision, true)
end

function FormatSignInt(value, precision)
	assert(type(value) == "number")
	if type(value) ~= "number" then value = 0 end
	local txt = FormatInt(abs(value), precision)
	if txt and value > 0 then
		txt = Untranslated('+') .. txt
	end
	return txt
end

function FormatScale(value, scale, precision)
	assert(type(value) == "number")
	if type(value) ~= "number" then value = 0 end
	local scale_num = tonumber(scale)
	return FormatAsFloat(value, scale_num or const.Scale[scale] or 1, precision or 3, true, scale_num and "" or scale)
end

function FormatIndex(index, context_obj)
	return T{288776973737, "#<index>", index = index, context_obj}
end

function TruncateToPrecision(value, scale, precision)
	for i = 1, precision or 0 do
		if scale >= 10 then
			scale = scale / 10
		end
	end
	return (value > 0 and value / scale or -(abs(value) / scale)) * scale
end

function FormatAsFloat(v, scale, precision, skip_nonsignificant, extra)
	local sep = _InternalTranslate(T(175637758479, --[[decimal separator]] "."))

	local sign = ""
	if v < 0 then
		if TruncateToPrecision(v, scale, precision) < 0 then
			sign = "-"
		end
		v = -v
	end
	scale = scale or 1
	precision = precision or 0
	if skip_nonsignificant then
		if precision == 3 and MulDivTrunc(v, 1000, scale) % 10 == 0 then precision = 2 end
		if precision == 2 and MulDivTrunc(v,  100, scale) % 10 == 0 then precision = 1 end
		if precision == 1 and MulDivTrunc(v,   10, scale) % 10 == 0 then precision = 0 end
	end
	assert(precision >= 0 and precision <= 3, "FormatAsFloat: precision not supported")
	if precision == 0 then
		return Untranslated(concat("", sign, v / scale, extra or ""))
	elseif precision == 1 then
		return Untranslated(concat("", sign, v / scale, sep, MulDivTrunc(v, 10, scale) % 10, extra or ""))
	elseif precision == 2 then
		return Untranslated(concat("", sign, v / scale, sep, MulDivTrunc(v, 10, scale) % 10, MulDivTrunc(v, 100, scale) % 10, extra or ""))
	else
		return Untranslated(concat("", sign, v / scale, sep, MulDivTrunc(v, 10, scale) % 10, MulDivTrunc(v, 100, scale) % 10, MulDivTrunc(v, 1000, scale) % 10, extra or ""))
	end
end

function RomanNumeral(number)
	-- GRATIA STACCVM SVPERFLVVM
    if number < 1 then return "" end
    if number >= 1000 then return "M" .. RomanNumeral(number - 1000) end
    if number >= 900 then return "CM" .. RomanNumeral(number - 900) end
    if number >= 500 then return "D" .. RomanNumeral(number - 500) end
    if number >= 400 then return "CD" .. RomanNumeral(number - 400) end
    if number >= 100 then return "C" .. RomanNumeral(number - 100) end
    if number >= 90 then return "XC" .. RomanNumeral(number - 90) end
    if number >= 50 then return "L" .. RomanNumeral(number - 50) end
    if number >= 40 then return "XL" .. RomanNumeral(number - 40) end
    if number >= 10 then return "X" .. RomanNumeral(number - 10) end
    if number >= 9 then return "IX" .. RomanNumeral(number - 9) end
    if number >= 5 then return "V" .. RomanNumeral(number - 5) end
    if number >= 4 then return "IV" .. RomanNumeral(number - 4) end
    if number >= 1 then return "I" .. RomanNumeral(number - 1) end
end

TFormat.const = function(context_obj, ...) return table.get(const, ...) end

function TFormat.ImportButtonText()
	return Untranslated({"Import Directory: <if(platform('ps4'))><ProjectName>Assets/Build/<PlatformName>/AppData/ExternalSaves/</if><if(platform('ps5'))><ProjectName>Assets/Build/<PlatformName>/ExternalSaves/</if><if(platform('xbox'))>[YOUR CONSOLE IP]/SystemScratch/ExternalSaves/</if>", ProjectName = Untranslated(const.ProjectName), PlatformName = Untranslated(GetPlatformName())})
end

function TFormat.ExportButtonText()
	return Untranslated({"Export Directory: <if(platform('ps4'))><ProjectName>Assets/Build/<PlatformName>/AppData/ExportedSaves/</if><if(platform('ps5'))>[YOUR CONSOLE IP]/devlog/app/<ProjectName>/AppData/ExportedSaves/</if><if(platform('xbox'))>[YOUR CONSOLE IP]/SystemScratch/ExportedSaves/</if>", ProjectName = Untranslated(const.ProjectName), PlatformName = Untranslated(GetPlatformName())})
end