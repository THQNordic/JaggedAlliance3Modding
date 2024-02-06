local function __run(...)
	if count_params(...) == 0 then
		return
	end
	if count_params(...) == 1 then
		local f = ...
		if type(f) == "function" then
			return f()
		end
	end
	return ...
end

local function load_match(line, rules, env)
	for i = 1, #rules do
		local capture1, capture2, capture3 = string.match(line, rules[i][1])
		if capture1 then
			local func, err = load(string.format(rules[i][2], capture1, capture2, capture3), nil, nil, env)
			if not err then
				return nil, func
			end
		end
	end
	return "not understood"
end

g_ConsoleFENV = false
function OnMsg.Autorun()
	--initialization is delayed because ModEnvBlacklist doesn't exist yet
	if g_ConsoleFENV then return end
	
	g_ConsoleFENV = {
		__run = __run,
	}
	
	if Platform.asserts or Platform.cmdline then
		setmetatable(g_ConsoleFENV, {
			__index = function (_, key)
				return rawget(_G, key)
			end,
			__newindex = function(_, key, value)
				rawset(_G, key, value)
			end
		})
	elseif config.Mods then
		g_ConsoleFENV = LuaModEnv(g_ConsoleFENV)
		local console_fenv_meta = getmetatable(g_ConsoleFENV)
		local original_G = _G
		console_fenv_meta.__index = function(env, key)
			if ModEnvBlacklist[key] then return end
			return rawget(original_G, key)
		end
		console_fenv_meta.__newindex = function(env, key, value)
			if ModEnvBlacklist[key] then return end
			rawset(original_G, key, value)
		end
	end
end

function ConsoleExec(input, rules)
	local err, func = load_match(input, rules, g_ConsoleFENV)
	if err then return err end
	local success, res = pcall(func)
	if not success then return res end
	return nil, res
end